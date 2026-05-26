local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Registry = require(ReplicatedStorage.Shared.Modules.Replication.ReplicationRegistry)
local State = require(ReplicatedStorage.Shared.Modules.State.State)
local Meta = require(ReplicatedStorage.Shared.Modules.State.Meta)
local Knit = require(game.ReplicatedStorage.Packages.knit)

local IS_SERVER = RunService:IsServer()

local ACTION = "Hit"
local DAMAGE = 3
local LATENCY_TOL = 2
local MAX_SIZE = Vector3.new(12, 12, 12)

local function inBox(cf: CFrame, half: Vector3, pos: Vector3): boolean
	local lp = cf:PointToObjectSpace(pos)

	return math.abs(lp.X) <= half.X and math.abs(lp.Y) <= half.Y and math.abs(lp.Z) <= half.Z
end

if IS_SERVER then
	Registry.register(ACTION, {

		validate = function(sender: Player, payload)
			if type(payload) ~= "table" then
				return false, "bad_payload"
			end

			if type(payload.targetKey) ~= "string" then
				return false, "bad_target"
			end

			local HitboxService = Knit.GetService("HitboxService")
			local data = HitboxService:GetHitbox(sender.UserId)

			if not data then
				return false, "no_hitbox"
			end

			if data.size.X > MAX_SIZE.X or data.size.Y > MAX_SIZE.Y or data.size.Z > MAX_SIZE.Z then
				return false, "bad_size"
			end

			if not State.get(Meta.StateKeys.CharacterAlive, sender) then
				return false, "dead"
			end

			return true
		end,

		Execute = function(sender: Player, payload)
			local HitboxService = Knit.GetService("HitboxService")
			local data = HitboxService:GetHitbox(sender.UserId)

			if not data then
				return nil
			end

			local target: Model?
			local root: BasePart?

			if payload.isPlayer then
				local p = Players:GetPlayerByUserId(tonumber(payload.targetKey))
				target = p and p.Character
			else
				target = workspace:FindFirstChild(payload.targetKey)
			end

			root = target and target:FindFirstChild("HumanoidRootPart")

			if not target or not root then
				return nil
			end

			local half = data.size * 0.5 + Vector3.new(LATENCY_TOL, LATENCY_TOL, LATENCY_TOL)

			if not inBox(data.cframe, half, root.Position) then
				return nil
			end

			if not HitboxService:RecordHit(sender.UserId, payload.targetKey) then
				return nil
			end

			local humanoid = target:FindFirstChildOfClass("Humanoid")

			if humanoid and humanoid.Health > 0 then
				humanoid.Health -= DAMAGE
			end

			return {
				targetKey = payload.targetKey,
				isPlayer = payload.isPlayer,
				damage = DAMAGE,
			}
		end,
	})
else
	local VfxManager = require(ReplicatedStorage.Shared.Modules.Helper.VfxManager)

	local localPlayer = Players.LocalPlayer

	local function playHitVfx(character: Model)
		local root = character:FindFirstChild("HumanoidRootPart")

		if not root then
			return
		end

		VfxManager.attach("Punch_Vfx", {
			parent = root,
			template = ReplicatedStorage.Vfx.Stand.Attack.Melee.Main,
			cleanup = 1,
		})
	end

	local function resolveCharacter(targetKey: string, isPlayer: boolean): Model?
		if isPlayer then
			local p = Players:GetPlayerByUserId(tonumber(targetKey))
			return p and p.Character
		end

		return workspace:FindFirstChild(targetKey)
	end

	Registry.register(ACTION, {

		onPredict = function(payload)
			local character = resolveCharacter(payload.targetKey, payload.isPlayer)

			if character then
				playHitVfx(character)
			end

			return true
		end,

		onReconcile = function(state, reason, clientSeq) end,

		onBroadcast = function(senderUserId, state)
			if senderUserId == localPlayer.UserId then
				return
			end

			if not state then
				return
			end

			local character = resolveCharacter(state.targetKey, state.isPlayer)

			if character then
				playHitVfx(character)
			end
		end,
	})
end

return {}
