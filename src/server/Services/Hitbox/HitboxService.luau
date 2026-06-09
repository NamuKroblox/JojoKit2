-- ServerScriptService/Services/HitboxService.lua
-- Server-side hitbox management and validation

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local HitboxConfig = require(ReplicatedStorage.Shared.Data.Configs.HitboxConfig)
local HitboxUtil = require(ReplicatedStorage.Shared.Helper.Hitbox.HitboxUtil)

local HitboxService = {
	Name = "HitboxService",
	Client = {},
}

export type HitboxData = {
	ownerId: number,
	cframe: CFrame,
	size: Vector3,
	hits: { [string]: boolean },
	hitCount: number,
	createdAt: number,
}

local activeHitboxes: { [number]: HitboxData } = {}

-- ─────────────────────────────────────────────────────────────────
-- HITBOX REGISTRATION
-- ─────────────────────────────────────────────────────────────────

--- Registers a hitbox on the server
function HitboxService.Client:Register(sender: Player, cframe: CFrame, size: Vector3): boolean
	local userId = sender.UserId

	-- Validate inputs
	local valid, err = HitboxConfig.isValidCFrame(cframe)
	if not valid then
		warn("[HitboxService] Register failed for", sender.Name, ":", err)
		return false
	end

	valid, err = HitboxConfig.isValidSize(size)
	if not valid then
		warn("[HitboxService] Register failed for", sender.Name, ":", err)
		return false
	end

	-- Clear previous hitbox if it exists (should not happen, but safety)
	if activeHitboxes[userId] then
		HitboxUtil.logHitboxDestroyed(tostring(userId) .. "_prev", "replaced")
		activeHitboxes[userId] = nil
	end

	-- Register new hitbox
	activeHitboxes[userId] = {
		ownerId = userId,
		cframe = cframe,
		size = size,
		hits = {},
		hitCount = 0,
		createdAt = os.clock(),
	}

	if HitboxConfig.DEBUG then
		print("[HitboxService] Registered hitbox for", sender.Name, "size:", size)
	end

	return true
end

--- Unregisters a hitbox
function HitboxService.Client:Unregister(sender: Player): boolean
	local userId = sender.UserId

	if not activeHitboxes[userId] then
		return false
	end

	activeHitboxes[userId] = nil

	if HitboxConfig.DEBUG then
		print("[HitboxService] Unregistered hitbox for", sender.Name)
	end

	return true
end

-- ─────────────────────────────────────────────────────────────────
-- HIT DETECTION
-- ─────────────────────────────────────────────────────────────────

--- Gets hitbox data for a user
function HitboxService:GetHitbox(userId: number): HitboxData?
	return activeHitboxes[userId]
end

--- Records a hit against a target (prevents duplicates)
function HitboxService:RecordHit(userId: number, targetKey: string): boolean
	local data = activeHitboxes[userId]

	if not data then
		if HitboxConfig.DEBUG then
			print("[HitboxService] No hitbox for userId:", userId)
		end
		return false
	end

	-- Check hit limit
	if data.hitCount >= HitboxConfig.MAX_HITS_PER_HITBOX then
		if HitboxConfig.DEBUG then
			print("[HitboxService] Hit limit reached for userId:", userId)
		end
		return false
	end

	-- Check if target already hit
	if data.hits[targetKey] then
		if HitboxConfig.DEBUG then
			print("[HitboxService] Target already hit:", targetKey)
		end
		return false
	end

	-- Record hit
	data.hits[targetKey] = true
	data.hitCount += 1

	HitboxUtil.logHitDetected(tostring(userId), targetKey, false)

	return true
end

--- Validates if a target is within hitbox bounds
function HitboxService:ValidateHit(userId: number, targetRoot: BasePart): boolean
	local data = activeHitboxes[userId]

	if not data then
		return false
	end

	return HitboxUtil.isInHitbox(data.cframe, data.size, targetRoot.Position, HitboxConfig.LATENCY_TOLERANCE)
end

-- ─────────────────────────────────────────────────────────────────
-- DEBUGGING & MONITORING
-- ─────────────────────────────────────────────────────────────────

--- Returns info about all active hitboxes (for debugging)
function HitboxService:GetActiveHitboxes(): { [number]: { userId: number, hits: number, age: number } }
	local result = {}
	local now = os.clock()

	for userId, data in activeHitboxes do
		result[userId] = {
			userId = userId,
			hits = data.hitCount,
			age = now - data.createdAt,
		}
	end

	return result
end

--- Gets hitbox count
function HitboxService:GetHitboxCount(): number
	local count = 0
	for _ in activeHitboxes do
		count += 1
	end
	return count
end

-- ─────────────────────────────────────────────────────────────────
-- INITIALIZATION
-- ─────────────────────────────────────────────────────────────────

function HitboxService:KnitInit()
	-- Clean up hitboxes when player leaves
	Players.PlayerRemoving:Connect(function(player)
		if activeHitboxes[player.UserId] then
			activeHitboxes[player.UserId] = nil
			if HitboxConfig.DEBUG then
				print("[HitboxService] Cleaned up hitbox for", player.Name)
			end
		end
	end)
end

return HitboxService