local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Registry = require(ReplicatedStorage.Shared.Registries.ReplicationRegistry)
local State = require(ReplicatedStorage.Shared.State.State)
local Meta = require(ReplicatedStorage.Shared.State.Meta)
local Knit = require(ReplicatedStorage.Packages.knit)
local DamageHandler = require(ReplicatedStorage.Shared.Helper.DamageHandler)

local IS_SERVER = RunService:IsServer()

local ACTION = "Hit"
local DAMAGE = 3
local LATENCY_TOL = 2
local MAX_SIZE = Vector3.new(12, 12, 12)

local function inBox(cf: CFrame, half: Vector3, pos: Vector3): boolean
	local lp = cf:PointToObjectSpace(pos)
	return math.abs(lp.X) <= half.X and math.abs(lp.Y) <= half.Y and math.abs(lp.Z) <= half.Z
end

local function computeKnockbackDir(attackerRoot: BasePart, victimRoot: BasePart): Vector3
	local flat = (victimRoot.Position - attackerRoot.Position) * Vector3.new(1, 0, 1)
	if flat.Magnitude < 0.01 then
		flat = attackerRoot.CFrame.LookVector * Vector3.new(1, 0, 1)
	end
	return flat.Unit
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

			--local StatusService = Knit.GetService("StatusService")
			--if StatusService:IsBlocked(sender, ACTION) then
			--	return false, "blocked"
			--end

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
			--local StatusService = Knit.GetService("StatusService")
			local data = HitboxService:GetHitbox(sender.UserId)

			if not data then
				return nil
			end

			local target: Model?
			local targetPlayer: Player?

			if payload.isPlayer then
				targetPlayer = Players:GetPlayerByUserId(tonumber(payload.targetKey))
				target = targetPlayer and targetPlayer.Character
			else
				local dummies = workspace:FindFirstChild("Dummies")
				target = dummies and dummies:FindFirstChild(payload.targetKey) :: Model?
			end

			local root = target and target:FindFirstChild("HumanoidRootPart") :: BasePart?

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

			local combo = State.get(Meta.StateKeys.Combo, sender) or 0
			local isFinisher = combo == 0 and (State.get(Meta.StateKeys.AttackId, sender) or 0) > 0

			local ctx = DamagePipeline.apply({
				source = sender,
				target = target,
				damage = DAMAGE,
				tags = { finisher = isFinisher, melee = true },
			})

			if not ctx or ctx.cancelled then
				return nil
			end

			local attackerRoot = sender.Character and sender.Character:FindFirstChild("HumanoidRootPart") :: BasePart?

			local knockDir = attackerRoot and computeKnockbackDir(attackerRoot, root) or Vector3.new(0, 0, -1)

			--if targetPlayer then
			--StatusService:Apply(targetPlayer, "Stun", STUN_DURATION, {})
			--end

			return {
				targetKey = payload.targetKey,
				isPlayer = payload.isPlayer,
				damage = ctx.damage,
				consequences = {
					{
						type = "effect",
						target = "all",
						id = "PunchImpact",
						payload = {
							targetKey = payload.targetKey,
							isPlayer = payload.isPlayer,
							standName = payload.StandName,
							combo = payload.Combo,
						},
					},
				},
			}
		end,
	})
else
	local localPlayer = Players.LocalPlayer
	local activeHitTracks: { [Model]: AnimationTrack } = {}
	local predictedReactions: { [Model]: boolean } = {}

	local function playHitReaction(character: Model, combo: number)
		local animator = character:FindFirstChildWhichIsA("Animator", true)
		if not animator then
			return
		end

		local animation = ReplicatedStorage:WaitForChild("Animations")
			:WaitForChild("Combat")
			:WaitForChild("MeleeHit")
			:FindFirstChild("Hit" .. combo)
		if not animation then
			return
		end

		local existing = activeHitTracks[character]
		if existing then
			existing:Stop()
			existing:Destroy()
		end

		local track = animator:LoadAnimation(animation)
		activeHitTracks[character] = track
		track:Play()

		track.Stopped:Once(function()
			if activeHitTracks[character] == track then
				activeHitTracks[character] = nil
			end
			track:Destroy()
		end)
	end

	Registry.register(ACTION, {

		onPredict = function(payload)
			if type(payload) ~= "table" then
				return true
			end
			local character = payload.TargetCharacter
			if not character then
				return true
			end

			playHitReaction(character, payload.Combo or 1)
			predictedReactions[character] = true

			return {
				targetKey = payload.targetKey,
				isPlayer = payload.isPlayer,
				consequences = {
					{
						type = "effect",
						target = "all",
						id = "PunchImpact",
						payload = {
							targetKey = payload.targetKey,
							isPlayer = payload.isPlayer,
							targetCharacter = character,
							standName = payload.StandName,
							combo = payload.Combo,
						},
					},
				},
			}
		end,

		onReconcile = function(state, reason, clientSeq) end,

		onBroadcast = function(senderUserId, state, payload)
			if not state then
				return
			end

			local character: Model?
			if senderUserId == localPlayer.UserId then
				character = payload and payload.TargetCharacter
			elseif state.isPlayer then
				local p = Players:GetPlayerByUserId(tonumber(state.targetKey))
				character = p and p.Character
			else
				local dummies = workspace:FindFirstChild("Dummies")
				character = dummies and dummies:FindFirstChild(state.targetKey)
			end

			if not character then
				return
			end

			if predictedReactions[character] then
				predictedReactions[character] = nil
				return
			end

			playHitReaction(character, (payload and payload.Combo) or 1)
		end,
	})
end

return {}
