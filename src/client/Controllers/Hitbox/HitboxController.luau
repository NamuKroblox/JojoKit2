local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Knit = require(ReplicatedStorage.Packages.knit)
local Hitbox = require(ReplicatedStorage.Shared.Modules.Helper.Hitbox)

local HitboxController = { Name = "HitboxController" }

local _hitboxService = nil
local _replicationController = nil
local localPlayer = Players.LocalPlayer

local currentHitbox = nil
local fired = false

function HitboxController:KnitInit()
	_hitboxService = Knit.GetService("HitboxService")
end

function HitboxController:KnitStart()
	_replicationController = Knit.GetController("ReplicationController")

	localPlayer.CharacterRemoving:Connect(function()
		self:Destroy()
	end)
end

function HitboxController:Create(config: {
	size: Vector3,
	cframe: CFrame,
	offset: CFrame?,
	lifetime: number?,
	onLocalHit: ((Model, Humanoid) -> ())?,
})
	self:Destroy()

	local finalCFrame = config.offset and (config.cframe * config.offset) or config.cframe

	fired = false

	_hitboxService:Register(finalCFrame, config.size)

	local hb = Hitbox.CreateHitbox()
	currentHitbox = hb

	hb.Size = config.size
	hb.CFrame = finalCFrame
	hb.DetectionMode = "Default"

	hb.Touched:Connect(function(_, humanoid: Humanoid)
		if fired then
			return
		end

		local character = humanoid and humanoid.Parent :: Model?
		if not character or character == localPlayer.Character then
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
		})

		if config.onLocalHit then
			config.onLocalHit(character, humanoid)
		end
	end)

	hb:Start()

	task.delay(config.lifetime or 0.5, function()
		self:Destroy()
	end)

	return true
end

function HitboxController:Destroy()
	if currentHitbox then
		currentHitbox:Stop()

		currentHitbox = nil
	end

	_hitboxService:Unregister()
	fired = false
end

return HitboxController
