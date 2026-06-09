local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Knit = require(ReplicatedStorage.Packages.knit)
local Registry = require(ReplicatedStorage.Shared.Registration.Registries.ReplicationRegistry)
local ActionTemplate = require(ReplicatedStorage.Shared.Helper.Replication.ActionTemplate)

local State = require(ReplicatedStorage.Shared.State.State)
local Meta = require(ReplicatedStorage.Shared.State.Meta)

local PunchShared = require(script.Parent.Parent.Shared.PunchShared)
local PunchConfig = require(game.ReplicatedStorage.Shared.Data.Configs.PunchConfig)

local Linker = require(game.ReplicatedStorage.Shared.Helper.Linker)

local IS_SERVER = RunService:IsServer()

local ACTION = "Punch"

function ServerStartup()
	
	local t = ActionTemplate.server({ cooldown = PunchConfig.Cooldown })

	local function validate(player: Player)
		if not State.get(Meta.StateKeys.CharacterAlive, player) then
			return false, "dead"
		end
		if not State.get(Meta.StateKeys.StandEquipped, player) then
			return false, "no_stand"
		end
	--	local StatusService = Knit.GetService("StatusService")
		--if StatusService:IsBlocked(player, ACTION) then
		--	return false, "blocked"
	--	end
		return true, nil
	end

	Players.PlayerRemoving:Connect(function(player)
		t:cleanup(player)
	end)

	Registry:register(ACTION, {

		validate = function(player, payload, clientSeq)
			return t:validate(player, clientSeq, function()
				return validate(player)
			end)
		end,

		Execute = function(player, payload, clientSeq)
			local now = t:advance(player, clientSeq)

			local combo = State.get(Meta.StateKeys.Combo, player) or 0
			local lastPunch = State.get(Meta.StateKeys.LastPunch, player) or 0

			if PunchShared.shouldResetCombo(combo, lastPunch, now) then
				combo = 0
			end

			local snapshot = PunchShared.buildSnapshot(combo, clientSeq, now)

			if snapshot.finisher then
				t:lock(player, "finisher", PunchConfig.FinisherLock)
			end

			PunchShared.applyCombatState(player, snapshot)


			return snapshot
		end,
	})
end

function ClientStartup()
	
	local S_AttachModel
	
	Linker.when("AttachModel",function(AttachModel)
		S_AttachModel = AttachModel
	end)
	
	local t = ActionTemplate.client({ cooldown = PunchConfig.Cooldown })
	local localPlayer = Players.LocalPlayer

	local pending = {}
	local combat = {
		combo = 0, 
		punching = false,
		finisher = false,
		attackId = 0,
		lastPunch = 0
	}

	local AnimationController = nil
	local function getAnimationController()
		if not AnimationController then
			AnimationController = Knit.GetController("AnimationController")
		end
		return AnimationController
	end

	local function canPunch()
		return State.get(Meta.StateKeys.CharacterAlive, localPlayer)
			and State.get(Meta.StateKeys.StandEquipped, localPlayer)
	end

	local function buildOverlapParams()
		local params = OverlapParams.new()
		params.FilterType = Enum.RaycastFilterType.Exclude
		local excluded = {}
		if localPlayer.Character then
			table.insert(excluded, localPlayer.Character)
		end
		local hasModel, standModel = S_AttachModel.GetStand(localPlayer)
		if hasModel and standModel then
			table.insert(excluded, standModel)
		end
		params.FilterDescendantsInstances = excluded
		return params
	end

	local function spawnHitbox(snapshot)
		local HitboxController = Knit.GetController("HitboxController")
		local character = localPlayer.Character
		if not character or not HitboxController then
			return
		end
		
		Linker.get("AttachModel")

		local StandName = S_AttachModel.GetStandName(localPlayer)
		HitboxController:Create({
			userId = localPlayer.UserId,
			size = Vector3.new(4, 4, 4),
			cframe = character:GetPivot(),
			offset = CFrame.new(0, 0, -5),
			lifetime = 0.3,
			overlapParams = buildOverlapParams(),
			Combo = snapshot.displayCombo,
			Data = { StandName = StandName },
		})
	end

	local function applyCombat(snapshot)
		combat.combo = snapshot.combo or 0
		combat.punching = snapshot.punching and true or false
		combat.finisher = snapshot.finisher and true or false
		combat.attackId = snapshot.attackId or 0
		combat.lastPunch = snapshot.lastPunch or 0
	end

	local function hardReset()
		table.clear(pending)
		combat.combo = 0
		combat.punching = false
		combat.finisher = false
		combat.attackId = 0
		combat.lastPunch = 0
		PunchShared.resetCombatState(localPlayer)
	end
	
	
	local function playPunchAnimation(player: Player, displayCombo: number)
		local ac = getAnimationController()
		if not ac then
			return
		end

		local controller = ac.getOrCreate(player)

		local track = controller:play(
			"standPunch",
			"standPunch",
			1,
			"Punch" .. tostring(displayCombo),
			{
				loop = false,
				priority = Enum.AnimationPriority.Action,
			}
		)

		if not track then
			return
		end

		S_AttachModel.MoveStand(player, CFrame.new(0, 0, -4), track.Length)
	end


	local function predict(now, attackId,clientSeq)
		local combo = combat.combo

		if PunchShared.shouldResetCombo(combo, combat.lastPunch, now) then
			combo = 0
		end

		local snapshot = PunchShared.buildSnapshot(combo, attackId, now)

		if snapshot.finisher then
			t:lock("finisher", PunchConfig.FinisherLock)
		end

		pending[attackId] = snapshot
		applyCombat(snapshot)
		PunchShared.applyCombatState(localPlayer, snapshot)
		playPunchAnimation(localPlayer, snapshot.displayCombo)
		spawnHitbox(snapshot)
		
	

		return snapshot
	end

	Registry:register(ACTION, {

		onPredict = function(_, clientSeq)
			local now = PunchShared.getNow()
			if not t:canAct(now) then
				return false
			end
			if not canPunch() then
				return false
			end
			local attackId = t:advance(now)
			return predict(now, attackId,clientSeq)
		end,

		onReconcile = function(state, reason, clientSeq)

				t:reconcile(clientSeq, state, function(serverState)
				local predicted = pending[clientSeq]
				pending[clientSeq] = nil


			
				if not predicted then
					PunchShared.applyCombatState(localPlayer, serverState)
					return
				end

				if not PunchShared.semanticMatch(predicted, serverState) then
					PunchShared.applyCombatState(localPlayer, serverState)
				else
					State.set(Meta.StateKeys.LastPunch, localPlayer, serverState.lastPunch)
				end
				end
				,
				
				
				function()
					
					hardReset()
					
				end)
		end,

		onBroadcast = function(senderUserId, state)
			local sender = Players:GetPlayerByUserId(senderUserId)
			if not sender or sender == localPlayer then
				return
			end
			PunchShared.applyCombatState(sender, state)
			playPunchAnimation(sender, state.displayCombo)
		end,
	})

end

if IS_SERVER then
	ServerStartup()
else
	ClientStartup()
end

return {}