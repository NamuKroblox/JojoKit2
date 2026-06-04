-- Punch.luau
-- Server-authoritative punch action with client-side prediction and replication
-- Handles cooldown, combo system, and finisher locks

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Registry = require(ReplicatedStorage.Shared.Modules.Replication.ReplicationRegistry)
local ActionTemplate = require(ReplicatedStorage.Shared.Modules.Replication.ActionTemplate)
local State = require(ReplicatedStorage.Shared.Modules.State.State)
local Meta = require(ReplicatedStorage.Shared.Modules.State.Meta)
local PunchShared = require(script.Parent.Util.PunchShared)

local IS_SERVER = RunService:IsServer()

local ACTION_NAME = "Punch"
local PUNCH_COOLDOWN = 0.4
local FINISHER_LOCK_DURATION = 1.5

local DEBUG = true

local function log(tag: string, ...)
	if DEBUG then
		print(("[PUNCH:%s]"):format(tag), ...)
	end
end

if IS_SERVER then
	local actionTemplate = ActionTemplate.server({ cooldown = PUNCH_COOLDOWN })

	local function canPunch(player: Player): (boolean, string?)
		if not State.get(Meta.StateKeys.CharacterAlive, player) then
			return false, "dead"
		end

		if not State.get(Meta.StateKeys.StandEquipped, player) then
			return false, "no_stand"
		end

		return true, nil
	end

	Players.PlayerRemoving:Connect(function(player)
		log("CLEANUP", player.Name)
		actionTemplate:cleanup(player)
	end)

	Registry.register(ACTION_NAME, {

		validate = function(player: Player, payload: any, clientSeq: number)
			local ok, err = canPunch(player)
			if not ok then
				log("VALIDATE_FAIL", err)
				return false, err
			end

			return actionTemplate:validate(player, clientSeq, function()
				return true, nil
			end)
		end,

		Execute = function(player: Player, payload: any, clientSeq: number)
			log("EXECUTE", player.Name)

			local now = actionTemplate:advance(player, clientSeq)

			local combo = State.get(Meta.StateKeys.Combo, player) or 0
			local lastPunch = State.get(Meta.StateKeys.LastPunch, player) or 0

			if PunchShared.shouldResetCombo(combo, lastPunch, now) then
				combo = 0
			end

			local snapshot = PunchShared.buildSnapshot(combo, clientSeq, now)

			if snapshot.finisher then
				actionTemplate:lock(player, "finisher", FINISHER_LOCK_DURATION)
			end

			PunchShared.applyCombatState(player, snapshot)
			log("STATE_UPDATED", { combo = snapshot.displayCombo, attackId = snapshot.attackId })

			return snapshot
		end,
	})
else
	local Knit = require(ReplicatedStorage.Packages.knit)
	local PunchPrediction = require(script.Parent.Client.PunchPrediction)
	local PunchEffects = require(script.Parent.Client.PunchEffects)
	local AnimationQueue = require(ReplicatedStorage.Shared.Modules.Animation.AnimationQueue)

	local actionTemplate = ActionTemplate.client({ cooldown = PUNCH_COOLDOWN })
	local localPlayer = Players.LocalPlayer
	local prediction = PunchPrediction.new()
	local hitboxController = nil
	local animationQueue = nil

	local function canPunch(): boolean
		return State.get(Meta.StateKeys.CharacterAlive, localPlayer)
			and State.get(Meta.StateKeys.StandEquipped, localPlayer)
	end

	local function resetPrediction()
		log("RESET_PREDICTION")
		actionTemplate:cleanup()
		prediction:reset()
		PunchShared.resetCombatState(localPlayer)
	end

	local function predictPunch(now: number, attackId: number)
		log("PREDICT", attackId)

		local combatState = prediction:get()
		local combo = combatState.combo

		if PunchShared.shouldResetCombo(combo, combatState.lastPunch, now) then
			combo = 0
		end

		local snapshot = PunchShared.buildSnapshot(combo, attackId, now)

		if snapshot.finisher then
			actionTemplate:lock("finisher", FINISHER_LOCK_DURATION)
		end

		prediction:push(snapshot)
		PunchShared.applyCombatState(localPlayer, snapshot)
		log("PREDICTED", { combo = snapshot.displayCombo, attackId = snapshot.attackId })

		-- Queue animation
		if animationQueue then
			animationQueue:push({
				combo = snapshot.displayCombo,
				attackId = snapshot.attackId,
				serverTime = snapshot.serverTime,
				duration = 0.25,
				isPredicted = true,
			})
		end

		PunchEffects.play(localPlayer, snapshot, hitboxController)
	end

	Registry.register(ACTION_NAME, {

		onPredict = function(payload: any)
			if not actionTemplate:canAct(os.clock()) then
				return false
			end
			if not canPunch() then
				return false
			end

			local now = os.clock()
			local attackId = actionTemplate:advance(now)
			predictPunch(now, attackId)
			return true
		end,

		onReconcile = function(serverState: any, reason: string?, clientSeq: number)
			log("RECONCILE", reason or "success")

			actionTemplate:reconcile(clientSeq, serverState, function(state)
				local predicted = prediction:pop(clientSeq)

				if not predicted then
					log("NO_PREDICTION")
					PunchShared.applyCombatState(localPlayer, state)
					return
				end

				if not PunchShared.semanticMatch(predicted, state) then
					log("CORRECTION")
					PunchShared.applyCombatState(localPlayer, state)
				else
					State.set(Meta.StateKeys.LastPunch, localPlayer, state.lastPunch)
				end
			end, function()
				resetPrediction()
			end)
		end,

		onBroadcast = function(senderUserId: number, state: any)
			local sender = Players:GetPlayerByUserId(senderUserId)
			if not sender or sender == localPlayer then
				return
			end

			log("BROADCAST", sender.Name)
			PunchShared.applyCombatState(sender, state)
			PunchEffects.play(sender, state, nil)
		end,
	})

	-- Deferred controller initialization
	task.defer(function()
		hitboxController = Knit.GetController("HitboxController")
		log("READY")
	end)
end

return {}
