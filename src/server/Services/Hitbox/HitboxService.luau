local Players = game:GetService("Players")

local HitboxService = {
	Name = "HitboxService",
	Client = {},
}

local MAX_HITS_PER_HITBOX = 1
local LATENCY_TOL = 2

export type HitboxData = {
	ownerId: number,
	cframe: CFrame,
	size: Vector3,
	hits: { [string]: boolean },
	hitCount: number,
}

local activeHitboxes: { [number]: HitboxData } = {}

local function inBox(cf: CFrame, half: Vector3, pos: Vector3): boolean
	local lp = cf:PointToObjectSpace(pos)
	return math.abs(lp.X) <= half.X and math.abs(lp.Y) <= half.Y and math.abs(lp.Z) <= half.Z
end

function HitboxService:GetHitbox(userId: number): HitboxData?
	return activeHitboxes[userId]
end

function HitboxService.Client:Register(sender: Player, cframe: CFrame, size: Vector3)
	activeHitboxes[sender.UserId] = {
		ownerId = sender.UserId,
		cframe = cframe,
		size = size,
		hits = {},
		hitCount = 0,
	}
end

function HitboxService.Client:Unregister(sender: Player)
	activeHitboxes[sender.UserId] = nil
end

function HitboxService:RecordHit(userId: number, targetKey: string): boolean
	local data = activeHitboxes[userId]
	if not data then
		return false
	end

	if data.hitCount >= MAX_HITS_PER_HITBOX then
		return false
	end
	if data.hits[targetKey] then
		return false
	end

	data.hits[targetKey] = true
	data.hitCount += 1

	return true
end

function HitboxService:ValidateHit(userId: number, targetRoot: BasePart): boolean
	local data = activeHitboxes[userId]
	if not data then
		return false
	end

	local half = data.size * 0.5 + Vector3.new(LATENCY_TOL, LATENCY_TOL, LATENCY_TOL)

	return inBox(data.cframe, half, targetRoot.Position)
end

function HitboxService:KnitInit()
	Players.PlayerRemoving:Connect(function(player)
		activeHitboxes[player.UserId] = nil
	end)
end

return HitboxService
