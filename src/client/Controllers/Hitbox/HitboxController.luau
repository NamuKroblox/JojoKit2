local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Knit = require(ReplicatedStorage.Packages.knit)
local Hitbox = require(ReplicatedStorage:WaitForChild("Libraries").Hitbox)

local localPlayer = Players.LocalPlayer
local _hitboxService = nil
local _replicationController = nil
local activeHitboxes = {}

local HitboxController = { Name = "HitboxController" }

function HitboxController:KnitInit()
	_hitboxService = Knit.GetService("HitboxService")
end

function HitboxController:KnitStart()
	_replicationController = Knit.GetController("ReplicationController")

	localPlayer.CharacterRemoving:Connect(function()
		self:DestroyAll()
	end)
end

function HitboxController:Create(config: {
	userId: number,
	size: Vector3,
	cframe: CFrame,
	offset: CFrame?,
	lifetime: number?,
	Combo: number?,
	overlapParams: OverlapParams?,
	Data: { StandName: string? }?,
})
	local hitId = tostring(config.userId) .. "_" .. tostring(os.clock())
	local fired = false
	local finalCFrame = config.offset and (config.cframe * config.offset) or config.cframe

	_hitboxService:Register(finalCFrame, config.size)

	local hb = Hitbox.CreateHitbox()
	activeHitboxes[hitId] = { hb = hb, registered = true, userId = config.userId }

	hb.Size = config.size
	hb.CFrame = finalCFrame
	hb.DetectionMode = "Default"
	hb.Visualizer = false

	if config.overlapParams then
		hb.OverlapParams = config.overlapParams
	end

	hb.Touched:Connect(function(_, humanoid: Humanoid)
		if fired then
			return
		end

		local character = humanoid and humanoid.Parent :: Model?
		if not character or character == localPlayer.Character or character:GetAttribute("IgnoreHits") == true then
			return
		end
		if not humanoid or humanoid.Health <= 0 then
			return
		end

		fired = true

		local hitPlayer = Players:GetPlayerFromCharacter(character)
		local isPlayer = hitPlayer ~= nil
		local targetKey = isPlayer and tostring(hitPlayer.UserId) or character.Name

		_replicationController:Dispatch("Hit", {
			targetKey = targetKey,
			isPlayer = isPlayer,
			TargetCharacter = character,
			Humanoid = humanoid,
			Combo = config.Combo,
			StandName = config.Data and config.Data.StandName,
		})
	end)

	hb:Start()

	task.delay(config.lifetime or 0.5, function()
		self:_destroyById(hitId)
	end)

	return hitId
end

function HitboxController:_destroyById(hitId: string)
	local entry = activeHitboxes[hitId]
	if not entry then
		return
	end

	entry.hb:Stop()

	if entry.registered then
		_hitboxService:Unregister(entry.userId)
		entry.registered = false
	end

	activeHitboxes[hitId] = nil
end

function HitboxController:DestroyAll()
	local ids = {}
	for id in activeHitboxes do
		table.insert(ids, id)
	end
	for _, id in ids do
		self:_destroyById(id)
	end
end

return HitboxController
