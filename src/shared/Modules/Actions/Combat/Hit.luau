-- Hit.luau
-- Server-authoritative hitbox validation with client-side prediction
-- Handles damage dealing, hit recording, and network validation

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Registry = require(ReplicatedStorage.Shared.Modules.Replication.ReplicationRegistry)
local State = require(ReplicatedStorage.Shared.Modules.State.State)
local Meta = require(ReplicatedStorage.Shared.Modules.State.Meta)
local Knit = require(game.ReplicatedStorage.Packages.knit)

local IS_SERVER = RunService:IsServer()

local ACTION_NAME = "Hit"
local DAMAGE_AMOUNT = 3
local LATENCY_TOLERANCE = 2
local MAX_HITBOX_SIZE = Vector3.new(12, 12, 12)

local function pointInBox(boxCFrame: CFrame, halfSize: Vector3, point: Vector3): boolean
	local localPoint = boxCFrame:PointToObjectSpace(point)
	return math.abs(localPoint.X) <= halfSize.X
		and math.abs(localPoint.Y) <= halfSize.Y
		and math.abs(localPoint.Z) <= halfSize.Z
end

local function safeGetHumanoidRoot(target: Model): BasePart?
	if not target then
		return nil
	end

	local candidate = target:FindFirstChild("HumanoidRootPart")
	if candidate and candidate:IsA("BasePart") then
		return candidate :: BasePart
	end
	return nil
end

if IS_SERVER then
	Registry.register(ACTION_NAME, {

		validate = function(sender: Player, payload: any)
			if type(payload) ~= "table" then
				return false, "invalid_payload"
			end

			if type(payload.targetKey) ~= "string" then
				return false, "invalid_target"
			end

			if not State.get(Meta.StateKeys.CharacterAlive, sender) then
				return false, "sender_dead"
			end

			local HitboxService = Knit.GetService("HitboxService")
			local hitboxData = HitboxService:GetHitbox(sender.UserId)

			if not hitboxData then
				return false, "no_hitbox"
			end

			-- Validate hitbox size to prevent exploits
			if
				hitboxData.size.X > MAX_HITBOX_SIZE.X
				or hitboxData.size.Y > MAX_HITBOX_SIZE.Y
				or hitboxData.size.Z > MAX_HITBOX_SIZE.Z
			then
				return false, "hitbox_too_large"
			end

			return true
		end,

		Execute = function(sender: Player, payload: any)
			local HitboxService = Knit.GetService("HitboxService")
			local hitboxData = HitboxService:GetHitbox(sender.UserId)

			if not hitboxData then
				return nil
			end

			-- Resolve target (player or dummy)
			local targetModel: Model?
			if payload.isPlayer then
				local targetPlayer = Players:GetPlayerByUserId(tonumber(payload.targetKey))
				targetModel = targetPlayer and targetPlayer.Character
			else
				local dummiesFolder = workspace:FindFirstChild("Dummies")
				targetModel = dummiesFolder and dummiesFolder:FindFirstChild(payload.targetKey)
			end

			local rootPart = safeGetHumanoidRoot(targetModel)
			if not targetModel or not rootPart then
				return nil
			end

			-- Validate hit with latency tolerance
			local tolerance = Vector3.new(LATENCY_TOLERANCE, LATENCY_TOLERANCE, LATENCY_TOLERANCE)
			local halfSize = hitboxData.size * 0.5 + tolerance

			if not pointInBox(hitboxData.cframe, halfSize, rootPart.Position) then
				return nil
			end

			-- Record hit to prevent duplicates
			if not HitboxService:RecordHit(sender.UserId, payload.targetKey) then
				return nil
			end

			-- Apply damage
			local humanoid = targetModel:FindFirstChildOfClass("Humanoid")
			if humanoid and humanoid.Health > 0 then
				humanoid:TakeDamage(DAMAGE_AMOUNT)
			end

			return {
				targetKey = payload.targetKey,
				isPlayer = payload.isPlayer,
				damage = DAMAGE_AMOUNT,
			}
		end,
	})
else
	local localPlayer = Players.LocalPlayer

	local function playHitReaction(
		targetModel: Model,
		isPlayer: boolean,
		targetKey: string,
		comboNumber: number,
		onHit: (any) -> ()
	)
		if onHit then
			onHit(targetModel)
		end

		if isPlayer then
			local targetPlayer = Players:GetPlayerByUserId(tonumber(targetKey))
			if not targetPlayer then
				return
			end

			local AnimationController = Knit.GetController("AnimationController")
			local controller = AnimationController.getOrCreate(targetPlayer)

			controller:play("hitReaction", "character", 1, ".Combat.MeleeHit", {
				loop = false,
				priority = Enum.AnimationPriority.Action,
			})
			return
		end

		-- Play animation on dummy
		local animator = targetModel:FindFirstChildWhichIsA("Animator", true)
		if not animator then
			return
		end

		local animationPath = ReplicatedStorage:WaitForChild("Animations")
			:WaitForChild("Combat")
			:WaitForChild("MeleeHit")
			:FindFirstChild("Hit" .. tostring(comboNumber))

		if not animationPath then
			return
		end

		local track = animator:LoadAnimation(animationPath :: Animation)
		track:Play()

		track.Stopped:Once(function()
			track:Destroy()
		end)
	end

	Registry.register(ACTION_NAME, {

		onPredict = function(payload: any)
			if payload and payload.Character and payload.onHit then
				playHitReaction(
					payload.Character,
					payload.isPlayer,
					payload.targetKey,
					payload.Combo or 1,
					payload.onHit
				)
			end
			return true
		end,

		onReconcile = function(_state: any, _reason: string?, _clientSeq: number) end,

		onBroadcast = function(senderUserId: number, state: any)
			if senderUserId == localPlayer.UserId then
				return
			end

			if not state then
				return
			end

			local targetModel: Model?
			if state.isPlayer then
				local targetPlayer = Players:GetPlayerByUserId(tonumber(state.targetKey))
				targetModel = targetPlayer and targetPlayer.Character
			else
				local dummiesFolder = workspace:FindFirstChild("Dummies")
				targetModel = dummiesFolder and dummiesFolder:FindFirstChild(state.targetKey)
			end

			if targetModel then
				playHitReaction(targetModel, state.isPlayer, state.targetKey, 1, nil)
			end
		end,
	})
end

return {}
