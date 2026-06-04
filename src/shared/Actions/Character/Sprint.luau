local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Registry = require(ReplicatedStorage.Shared.Registries.ReplicationRegistry)
local ActionTemplate = require(ReplicatedStorage.Shared.Replication.ActionTemplate)
local State = require(ReplicatedStorage.Shared.State.State)
local Meta = require(ReplicatedStorage.Shared.State.Meta)

local IS_SERVER = RunService:IsServer()

local ACTION = "Sprint"
local WALK_SPEED = 16
local SPRINT_SPEED = 26

if IS_SERVER then
	local Knit = require(ReplicatedStorage.Packages.knit)
	local t = ActionTemplate.server()

	local function validate(player: Player, payload)
		if not State.get(Meta.StateKeys.CharacterAlive, player) then
			return false, "dead"
		end

		local humanoid = player.Character and player.Character:FindFirstChildOfClass("Humanoid")
		if not humanoid then
			return false, "no_humanoid"
		end

		if payload.enabled and humanoid.WalkSpeed > SPRINT_SPEED then
			return false, "exploit_speed"
		end

		--local StatusService = Knit.GetService("StatusService")
		--if payload.enabled and StatusService:IsBlocked(player, ACTION) then
		--	return false, "blocked"
		--end

		return true, nil
	end

	Players.PlayerRemoving:Connect(function(player)
		t:cleanup(player)
	end)

	Registry.register(ACTION, {

		validate = function(player, payload, clientSeq)
			return t:validate(player, clientSeq, function()
				return validate(player, payload)
			end)
		end,

		Execute = function(player, payload, clientSeq)
			t:advance(player, clientSeq)

			local enabled = payload.enabled == true

			State.set(Meta.StateKeys.Sprinting, player, enabled)

			return { enabled = enabled }
		end,
	})
else
	local t = ActionTemplate.client()
	local localPlayer = Players.LocalPlayer
	local EventBus = require(game.ReplicatedStorage.Shared.Buses.EventBus)
	local pending: { [number]: boolean } = {}
	local sprintMemory = false

	local function apply(enabled: boolean)
		local character = localPlayer.Character
		if not character then
			return
		end
		local humanoid = character:FindFirstChildOfClass("Humanoid")
		if not humanoid then
			return
		end
		State.set(Meta.StateKeys.Sprinting, localPlayer, enabled)
		humanoid.WalkSpeed = enabled and SPRINT_SPEED or WALK_SPEED
	end

	local function canSprint()
		return State.get(Meta.StateKeys.CharacterAlive, localPlayer) == true
	end

	Registry.register(ACTION, {

		onPredict = function(payload, clientSeq)
			if not canSprint() then
				return false
			end

			local enabled = payload.enabled == true
			pending[clientSeq] = enabled
			sprintMemory = enabled
			apply(enabled)

			return true
		end,

		onReconcile = function(state, reason, clientSeq)
			pending[clientSeq] = nil

			if not state then
				if next(pending) == nil then
					sprintMemory = false
					apply(false)
				end
				return
			end

			t:reconcile(clientSeq, state, function(serverState)
				if next(pending) ~= nil then
					return
				end
				if State.get(Meta.StateKeys.Sprinting, localPlayer) ~= serverState.enabled then
					sprintMemory = serverState.enabled
					apply(serverState.enabled)
				end
			end, function()
				if next(pending) == nil then
					sprintMemory = false
					apply(false)
				end
			end)
		end,

		onBroadcast = function(senderUserId, state)
			local sender = Players:GetPlayerByUserId(senderUserId)
			if not sender or sender == localPlayer then
				return
			end

			State.set(Meta.StateKeys.Sprinting, sender, state.enabled)

			local character = sender.Character
			if not character then
				return
			end
			local humanoid = character:FindFirstChildOfClass("Humanoid")
			if humanoid then
				humanoid.WalkSpeed = state.enabled and SPRINT_SPEED or WALK_SPEED
			end
		end,
	})
	
	
	EventBus.on("ClientStatusApplied", function(player, id)
		if id == "PunchLag" or id == "Stun" then
			apply(false)
			warn("sprint stopped")
		end
	end)
	
	
end

return {}