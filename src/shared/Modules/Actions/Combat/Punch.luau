local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Registry = require(ReplicatedStorage.Shared.Modules.Replication.ReplicationRegistry)
local ActionTemplate = require(ReplicatedStorage.Shared.Modules.Replication.ActionTemplate)
local State = require(ReplicatedStorage.Shared.Modules.State.State)
local Meta = require(ReplicatedStorage.Shared.Modules.State.Meta)
local PunchShared = require(script.Parent.Util.PunchShared)

local IS_SERVER = RunService:IsServer()

local ACTION = "Punch"
local PUNCH_COOLDOWN = 0.4
local FINISHER_LOCK = 1.5

local DEBUG = true

local function log(tag, ...)
	if DEBUG then
		print(("[PUNCH:%s]"):format(tag), ...)
	end
end

local function _warnlog(tag, ...)
	warn(("[PUNCH:%s]"):format(tag), ...)
end

if IS_SERVER then
	local t = ActionTemplate.server({ cooldown = PUNCH_COOLDOWN })

	local function validate(player: Player)
		log("VALIDATE_CHECK", player.Name)

		if not State.get(Meta.StateKeys.CharacterAlive, player) then
			log("VALIDATE_FAIL_DEAD")
			return false, "dead"
		end

		if not State.get(Meta.StateKeys.StandEquipped, player) then
			log("VALIDATE_FAIL_NO_STAND")
			return false, "no_stand"
		end

		log("VALIDATE_PASS")
		return true, nil
	end

	Players.PlayerRemoving:Connect(function(player)
		log("CLEANUP_PLAYER", player.Name)
		t:cleanup(player)
	end)

	Registry.register(ACTION, {

		validate = function(player, payload, clientSeq)
			log("VALIDATE_ENTRY", player.Name, clientSeq)
			return t:validate(player, clientSeq, function()
				return validate(player)
			end)
		end,

		Execute = function(player, payload, clientSeq)
			local now = t:advance(player, clientSeq)

			log("EXECUTE", {
				player = player.Name,
				clientSeq = clientSeq,
				now = now,
			})

			local combo = State.get(Meta.StateKeys.Combo, player) or 0
			local lastPunch = State.get(Meta.StateKeys.LastPunch, player) or 0

			if PunchShared.shouldResetCombo(combo, lastPunch, now) then
				log("COMBO_RESET_SERVER")
				combo = 0
			end

			local snapshot = PunchShared.buildSnapshot(combo, clientSeq, now)

			log("SNAPSHOT_SERVER", snapshot)

			if snapshot.finisher then
				log("FINISHER_LOCK")
				t:lock(player, "finisher", FINISHER_LOCK)
			end

			PunchShared.applyCombatState(player, snapshot)

			log("STATE_APPLIED_SERVER")

			return snapshot
		end,
	})
else
	local Knit = require(ReplicatedStorage.Packages.knit)

	local PunchPrediction = require(script.Parent.Client.PunchPrediction)
	local PunchEffects = require(script.Parent.Client.PunchEffects)

	local AnimationQueue = require(ReplicatedStorage.Shared.Modules.Animation.AnimationQueue)

	local t = ActionTemplate.client({ cooldown = PUNCH_COOLDOWN })
	local localPlayer = Players.LocalPlayer
	local prediction = PunchPrediction.new()
	local HitboxController = nil
	local animQueue = nil

	local function canPunch()
		return State.get(Meta.StateKeys.CharacterAlive, localPlayer)
			and State.get(Meta.StateKeys.StandEquipped, localPlayer)
	end

	local function hardReset()
		log("HARD_RESET")

		t:cleanup()
		prediction:reset()
		PunchShared.resetCombatState(localPlayer)

		--local animator = AnimatorRegistry.get(localPlayer)
		--if animator then
		--	animator:cancelAttack()
		--end
	end

	local function predict(now, attackId)
		log("PREDICT_START", {
			now = now,
			attackId = attackId,
			canAct = t:canAct(now),
		})

		local combat = prediction:get()
		local combo = combat.combo

		if PunchShared.shouldResetCombo(combo, combat.lastPunch, now) then
			log("COMBO_RESET")
			combo = 0
		end

		local snapshot = PunchShared.buildSnapshot(combo, attackId, now)

		log("SNAPSHOT", snapshot)

		if snapshot.finisher then
			t:lock("finisher", FINISHER_LOCK)
		end

		prediction:push(snapshot)
		PunchShared.applyCombatState(localPlayer, snapshot)

		log("STATE_APPLIED")

		if animQueue then
			animQueue:push({
				combo = snapshot.displayCombo,
				attackId = snapshot.attackId,
				serverTime = snapshot.serverTime,
				duration = 0.25,
				isPredicted = true,
			})

			log("ANIM_QUEUED", snapshot.displayCombo, snapshot.attackId)
		end

		PunchEffects.play(localPlayer, snapshot, HitboxController)
	end

	Registry.register(ACTION, {

		onPredict = function(_, clientSeq)
			local now = PunchShared.getNow()

			log("PREDICT_EVENT", {
				now = now,
				canAct = t:canAct(now),
			})

			if not t:canAct(now) then
				return false
			end
			if not canPunch() then
				return false
			end

			local attackId = t:advance(now)

			log("ATTACK_ID", attackId)

			predict(now, attackId)

			return true
		end,

		onReconcile = function(state, reason, clientSeq)
			log("RECONCILE", {
				reason = reason,
				clientSeq = clientSeq,
			})

			t:reconcile(clientSeq, state, function(serverState)
				local predicted = prediction:pop(clientSeq)

				if not predicted then
					log("NO_PREDICTED_STATE")
					PunchShared.applyCombatState(localPlayer, serverState)
					return
				end

				local match = PunchShared.semanticMatch(predicted, serverState)

				log("SEMANTIC_MATCH", match)

				if not match then
					log("CORRECTION_APPLY")
					PunchShared.applyCombatState(localPlayer, serverState)
				else
					State.set(Meta.StateKeys.LastPunch, localPlayer, serverState.lastPunch)
				end
			end, function()
				log("HARD_RESET_RECONCILE")
				hardReset()
			end)
		end,

		onBroadcast = function(senderUserId, state)
			local sender = Players:GetPlayerByUserId(senderUserId)
			if not sender or sender == localPlayer then
				return
			end

			log("BROADCAST", sender.Name)

			PunchShared.applyCombatState(sender, state)
			PunchEffects.play(sender, state, nil)
		end,
	})

	task.defer(function()
		HitboxController = Knit.GetController("HitboxController")
		log("HITBOX_CONTROLLER_READY")

		--local animator = AnimatorRegistry.get(localPlayer)
		--if animator then
		--	animQueue = AnimationQueue.new(animator)
		--	log("ANIMATION_QUEUE_READY")
		--end
	end)
end

return {}
