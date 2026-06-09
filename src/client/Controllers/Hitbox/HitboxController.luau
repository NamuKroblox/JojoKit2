-- ReplicatedStorage/Client/Controllers/HitboxController.lua
-- Client-side hitbox creation and management

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Knit = require(ReplicatedStorage.Packages.knit)
local Hitbox = require(ReplicatedStorage.Hitbox)

local HitboxConfig = require(ReplicatedStorage.Shared.Data.Configs.HitboxConfig)
local HitboxUtil = require(ReplicatedStorage.Shared.Helper.Hitbox.HitboxUtil)

local localPlayer = Players.LocalPlayer
local _hitboxService = nil
local _replicationController = nil
local activeHitboxes = {}

local HitboxController = { Name = "HitboxController" }

-- ─────────────────────────────────────────────────────────────────
-- INITIALIZATION
-- ─────────────────────────────────────────────────────────────────

function HitboxController:KnitInit()
	_hitboxService = Knit.GetService("HitboxService")
	if not _hitboxService then
		error("[HitboxController] HitboxService not found")
	end
end

function HitboxController:KnitStart()
	_replicationController = Knit.GetController("ReplicationController")
	if not _replicationController then
		error("[HitboxController] ReplicationController not found")
	end

	-- Clean up when character dies
	localPlayer.CharacterRemoving:Connect(function()
		self:DestroyAll()
	end)

	-- Also clean up if player leaves
	Players.PlayerRemoving:Connect(function(player)
		if player == localPlayer then
			self:DestroyAll()
		end
	end)
end

-- ─────────────────────────────────────────────────────────────────
-- HITBOX CREATION
-- ─────────────────────────────────────────────────────────────────

function HitboxController:Create(config: {
	userId: number,
	size: Vector3,
	cframe: CFrame,
	offset: CFrame?,
	lifetime: number?,
	Combo: number?,
	overlapParams: OverlapParams?,
	Data: { StandName: string? }?,
}): string?
	-- Validate configuration
	local valid, err = HitboxUtil.validateConfig(config)
	if not valid then
		warn("[HitboxController] Invalid config:", err)
		return nil
	end

	-- Validate lifetime
	local lifetime = config.lifetime or HitboxConfig.DEFAULT_LIFETIME
	if lifetime <= 0 then
		warn("[HitboxController] Lifetime must be positive")
		return nil
	end

	-- Calculate final CFrame with offset
	local finalCFrame = config.offset and (config.cframe * config.offset) or config.cframe

	-- Generate unique ID
	local hitboxId = HitboxUtil.generateHitboxId(config.userId)

	-- Register on server
	local registered = false
	local success, result = pcall(function()
		registered = _hitboxService:Register(finalCFrame, config.size)
	end)

	if not success then
		warn("[HitboxController] Failed to register on server:", result)
		return nil
	end

	if not registered then
		warn("[HitboxController] Server rejected registration")
		return nil
	end

	-- Create visual hitbox
	local hb = Hitbox.CreateHitbox()
	if not hb then
		warn("[HitboxController] Failed to create hitbox visual")
		_hitboxService:Unregister()
		return nil
	end

	-- Configure visual hitbox
	hb.Size = config.size
	hb.CFrame = finalCFrame
	hb.DetectionMode = "Default"
	hb.Visualizer = HitboxConfig.SHOW_HITBOX_VISUALS

	--VoxManager:voxelize(hb,4,4,false,true,6,{hb})

	if config.overlapParams then
		hb.OverlapParams = config.overlapParams
	end

	-- Track this hitbox
	activeHitboxes[hitboxId] = {
		hb = hb,
		registered = true,
		userId = config.userId,
		fired = false, -- Prevent duplicate hits
	}

	HitboxUtil.logHitboxCreated(hitboxId, config)

	-- Connect hit detection
	hb.Touched:Connect(function(_, humanoid: Humanoid)
		self:_onHitboxTouched(hitboxId, humanoid, config)
	end)

	-- Start the visual hitbox
	hb:Start()

	-- Schedule cleanup
	task.delay(lifetime, function()
		self:_destroyById(hitboxId, "timeout")
	end)

	return hitboxId
end

-- ─────────────────────────────────────────────────────────────────
-- HIT DETECTION
-- ─────────────────────────────────────────────────────────────────

function HitboxController:_onHitboxTouched(hitboxId: string, humanoid: Humanoid, config: any)
	local entry = activeHitboxes[hitboxId]

	if not entry or entry.fired then
		return
	end

	-- Validate target
	local character = humanoid and humanoid.Parent :: Model?

	if not character then
		return
	end

	if character == localPlayer.Character then
		return -- Don't hit yourself
	end

	if character:GetAttribute("IgnoreHits") == true then
		return -- Target is marked as ignore
	end

	if not humanoid or humanoid.Health <= 0 then
		return -- Target is already dead
	end

	-- Mark as fired to prevent duplicate hits in one frame
	entry.fired = true

	-- Determine target info
	local hitPlayer = Players:GetPlayerFromCharacter(character)
	local isPlayer = hitPlayer ~= nil
	local targetKey = isPlayer and tostring(hitPlayer.UserId) or character.Name

	HitboxUtil.logHitDetected(hitboxId, targetKey, isPlayer)

	-- Dispatch reaction to server
	local dispatchSuccess = _replicationController:DispatchReaction("PunchLanded", {
		targetKey = targetKey,
		isPlayer = isPlayer,
		TargetCharacter = character,
		Humanoid = humanoid,
		Combo = config.Combo,
		StandName = config.Data and config.Data.StandName,
	})

	if not dispatchSuccess then
		warn("[HitboxController] Failed to dispatch reaction for", targetKey)
		entry.fired = false -- Reset so we can try again
	end
end

-- ─────────────────────────────────────────────────────────────────
-- CLEANUP
-- ─────────────────────────────────────────────────────────────────

function HitboxController:_destroyById(hitboxId: string, reason: string?)
	local entry = activeHitboxes[hitboxId]

	if not entry then
		return
	end

	-- Stop visual hitbox
	if entry.hb then
		pcall(function()
			entry.hb:Stop()
		end)
	end

	-- Unregister from server
	if entry.registered then
		pcall(function()
			_hitboxService:Unregister()
		end)
		entry.registered = false
	end

	HitboxUtil.logHitboxDestroyed(hitboxId, reason)

	activeHitboxes[hitboxId] = nil
end

function HitboxController:DestroyAll()
	local ids = {}
	for id in activeHitboxes do
		table.insert(ids, id)
	end

	for _, id in ids do
		self:_destroyById(id, "destroy_all")
	end
end

return HitboxController
