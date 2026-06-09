-- ReplicatedStorage/Shared/Actions/Combat/AttackLandedReaction_Updated.lua
-- Updated to use HitboxUtil and HitboxConfig

local DEBUG_REACTION = true

local function D(...)
	if DEBUG_REACTION then
		print(...)
	end
end

local function W(...)
	warn(...)
end


local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local ReactionRegistry = require(ReplicatedStorage.Shared.Registration.Registries.ReactionRegistry)
local DamageHandler = require(ReplicatedStorage.Shared.Helper.Hitbox.DamageHandler)

local State = require(ReplicatedStorage.Shared.State.State)
local Meta = require(ReplicatedStorage.Shared.State.Meta)
local Knit = require(ReplicatedStorage.Packages.knit)

local HitboxConfig = require(ReplicatedStorage.Shared.Data.Configs.HitboxConfig)
local HitboxUtil = require(ReplicatedStorage.Shared.Helper.Hitbox.HitboxUtil)

local IS_SERVER = RunService:IsServer()

local REACTION = "PunchLanded"
local DAMAGE = 3

-- ─────────────────────────────────────────────────────────────────
-- HELPERS
-- ─────────────────────────────────────────────────────────────────

local function computeKnockbackDir(attackerRoot: BasePart, victimRoot: BasePart): Vector3
	local flat = (victimRoot.Position - attackerRoot.Position) * Vector3.new(1, 0, 1)
	if flat.Magnitude < 0.01 then
		flat = attackerRoot.CFrame.LookVector * Vector3.new(1, 0, 1)
	end
	return flat.Unit
end

local function resolveTarget(payload)
	if payload.isPlayer then
		local p = Players:GetPlayerByUserId(tonumber(payload.targetKey))
		return p and p.Character, p
	else
		local dummies = workspace:FindFirstChild("Dummies")
		return dummies and dummies:FindFirstChild(payload.targetKey) :: Model?, nil
	end
end

-- ─────────────────────────────────────────────────────────────────
-- SERVER
-- ─────────────────────────────────────────────────────────────────

if IS_SERVER then

	ReactionRegistry:register(REACTION, {
		validate = function(sender: Player, payload: any, seq: number)
			D("[PunchLanded][Validate] START")
			D("[PunchLanded][Validate] Sender:", sender.Name)
			D("[PunchLanded][Validate] Seq:", seq)
			D("[PunchLanded][Validate] Payload:", payload)

			if type(payload) ~= "table" then
				W("[PunchLanded][Validate] bad_payload")
				return false, "bad_payload"
			end

			if type(payload.targetKey) ~= "string" then
				W("[PunchLanded][Validate] bad_target")
				return false, "bad_target"
			end

			local alive = State.get(Meta.StateKeys.CharacterAlive, sender)

			D("[PunchLanded][Validate] Alive =", alive)

			if not alive then
				W("[PunchLanded][Validate] dead")
				return false, "dead"
			end

			local HitboxService = Knit.GetService("HitboxService")
			local data = HitboxService:GetHitbox(sender.UserId)

			D("[PunchLanded][Validate] HitboxData =", data)

			if not data then
				W("[PunchLanded][Validate] no_hitbox")
				return false, "no_hitbox"
			end

			local valid, err = HitboxConfig.isValidSize(data.size)

			D("[PunchLanded][Validate] SizeValid =", valid)

			if not valid then
				W("[PunchLanded][Validate] bad_size", err)
				return false, "bad_size"
			end

			D("[PunchLanded][Validate] SUCCESS")

			return true
		end,
		

		Execute = function(sender: Player, payload: any, seq: number)
			D("[PunchLanded][Execute] START")
			D("[PunchLanded][Execute] Sender =", sender.Name)
			D("[PunchLanded][Execute] Target =", payload.targetKey)

			local HitboxService = Knit.GetService("HitboxService")
			local data = HitboxService:GetHitbox(sender.UserId)

			D("[PunchLanded][Execute] HitboxData =", data)

			if not data then
				W("[PunchLanded][Execute] Missing hitbox")
				return nil
			end

			local target, targetPlayer = resolveTarget(payload)

			D("[PunchLanded][Execute] TargetResolved =", target)
			D("[PunchLanded][Execute] TargetPlayer =", targetPlayer)

			local root = target and target:FindFirstChild("HumanoidRootPart")

			if not target then
				W("[PunchLanded][Execute] Target missing")
				return nil
			end

			if not root then
				W("[PunchLanded][Execute] Root missing")
				return nil
			end

			local inside = HitboxUtil.isInHitbox(
				data.cframe,
				data.size,
				root.Position,
				HitboxConfig.LATENCY_TOLERANCE
			)

			D("[PunchLanded][Execute] InHitbox =", inside)
			D("[PunchLanded][Execute] TargetPosition =", root.Position)

			if not inside then
				W("[PunchLanded][Execute] Outside hitbox")
				return nil
			end

			local recorded =
				HitboxService:RecordHit(sender.UserId, payload.targetKey)

			D("[PunchLanded][Execute] RecordHit =", recorded)

			if not recorded then
				W("[PunchLanded][Execute] RecordHit failed")
				return nil
			end

			local ctx = DamageHandler.apply({
				source = sender,
				target = target,
				damage = DAMAGE,
				tags = { melee = true },
			})

			D("[PunchLanded][Execute] DamageContext =", ctx)

			if not ctx then
				W("[PunchLanded][Execute] Damage returned nil")
				return nil
			end

			if ctx.cancelled then
				W("[PunchLanded][Execute] Damage cancelled")
				return nil
			end

			local attackerRoot =
				sender.Character and
				sender.Character:FindFirstChild("HumanoidRootPart")

			local knockDir =
				attackerRoot and
				computeKnockbackDir(attackerRoot, root)
				or Vector3.new(0,0,-1)

			D("[PunchLanded][Execute] Damage =", ctx.damage)
			D("[PunchLanded][Execute] Combo =", payload.Combo)
			D("[PunchLanded][Execute] SUCCESS")

			local consequences = {
				{
					type = "effect",
					id = "PunchImpact",
					target = "all",
					payload = {
						targetKey = payload.targetKey,
						isPlayer = payload.isPlayer,
						standName = payload.StandName,
						combo = payload.Combo,
					},
				},
			}

			return {
				targetKey = payload.targetKey,
				isPlayer = payload.isPlayer,
				damage = ctx.damage,
				combo = payload.Combo,
				knockDir = knockDir,
				consequences = consequences,
			}
		end,
	})

	-- ─────────────────────────────────────────────────────────────────
	-- CLIENT
	-- ─────────────────────────────────────────────────────────────────

else

	local localPlayer = Players.LocalPlayer
	local AnimationController = nil

	local function getAnimationController()
		if not AnimationController then
			AnimationController = Knit.GetController("AnimationController")
		end
		return AnimationController
	end

	local activeHitTracks: { [Model]: AnimationTrack } = {}

	local function playHitReaction(isPlayer: boolean, character: Model?, combo: number)
		print("[HitReaction] START", isPlayer, character and character.Name, combo)

		if not character then
			warn("[HitReaction] character is nil")
			return
		end

		local ac = getAnimationController()
		if not ac then
			warn("[HitReaction] AnimationController not available")
			return
		end

		if isPlayer then
			print("[HitReaction] Player branch")

			local player = Players:GetPlayerFromCharacter(character)
			if not player then
				warn("[HitReaction] No player found for character:", character.Name)
				return
			end

			print("[HitReaction] Player found:", player.Name)

			local controller = ac.getOrCreate(player)
			if not controller then
				warn("[HitReaction] Failed to get controller for:", player.Name)
				return
			end

			local animName = "Hit" .. combo
			print("[HitReaction] Playing standHit:", animName)

			controller:play("standHit", "standHit", 1, animName, {
				loop = false,
				priority = Enum.AnimationPriority.Action,
			})

			print("[HitReaction] standHit play requested")
		else
			print("[HitReaction] NPC branch")

			local animator = character:FindFirstChildWhichIsA("Animator", true)
			if not animator then
				warn("[HitReaction] No Animator found in:", character:GetFullName())
				return
			end

			print("[HitReaction] Animator found:", animator:GetFullName())

			local combatFolder = ReplicatedStorage
				:WaitForChild("Visual")
				:WaitForChild("ANIMATIONS")
				:WaitForChild("Combat")
				:WaitForChild("MeleeHit")

			local animName = "Hit" .. combo
			local anim = combatFolder:FindFirstChild(animName)

			print("[HitReaction] Looking for animation:", animName)

			if not anim then
				warn("[HitReaction] Animation not found:", animName)

				print("[HitReaction] Available animations:")
				for _, child in combatFolder:GetChildren() do
					print(" -", child.Name)
				end

				return
			end

			print("[HitReaction] Animation found:", anim.Name)

			local existing = activeHitTracks[character]
			if existing then
				print("[HitReaction] Stopping existing track")
				existing:Stop()
				existing:Destroy()
			end

			print("[HitReaction] Loading animation")

			local track = animator:LoadAnimation(anim)
			activeHitTracks[character] = track

			print("[HitReaction] Playing track")
			track:Play()

			track.Stopped:Once(function()
				print("[HitReaction] Track stopped:", animName)

				if activeHitTracks[character] == track then
					activeHitTracks[character] = nil
				end

				track:Destroy()
				print("[HitReaction] Track destroyed")
			end)
		end

		print("[HitReaction] END")
	end

	ReactionRegistry:register(REACTION, {

		onPredict = function(payload, seq)
			D("[PunchLanded][Predict]", payload.targetKey, seq)
			
			playHitReaction(payload.isPlayer,payload.TargetCharacter,payload.Combo)
			
			return {
				targetKey = payload.targetKey,
				isPlayer = payload.isPlayer,
				consequences = {
					{
						type = "effect",
						id = "PunchImpact",
						target = "all",
						payload = {
							targetKey = payload.targetKey,
							isPlayer = payload.isPlayer,
							targetCharacter = payload.TargetCharacter,
							standName = payload.StandName,
							combo = payload.Combo,
						},
					},
				},
			}
		end,

		onReconcile = function(state, reason, seq)
			D("[PunchLanded][Reconcile]")
			D("[PunchLanded][Reconcile] State =", state)
			D("[PunchLanded][Reconcile] Reason =", reason)
			D("[PunchLanded][Reconcile] Seq =", seq)

			if reason then
				W("[PunchLanded][Reconcile] REJECTED:", reason)
				return
			end

			D("[PunchLanded][Reconcile] CONFIRMED")
		end,

		onSource = function(ctx, state)
			D("[PunchLanded][Source]")
			D("[PunchLanded][Source] Ctx =", ctx)
			D("[PunchLanded][Source] State =", state)
		end,

		onTarget = function(ctx, state)
			D("[PunchLanded][Target]")
			D("[PunchLanded][Target] Ctx =", ctx)
			D("[PunchLanded][Target] State =", state)
			
		end,

		onObserver = function(ctx, state)
			D("[PunchLanded][Observer]")
			D("[PunchLanded][Observer] Ctx =", ctx)
			D("[PunchLanded][Observer] State =", state)
		end,
	})

end

return {}