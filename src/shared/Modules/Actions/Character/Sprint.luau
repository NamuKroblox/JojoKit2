local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Registry = require(ReplicatedStorage.Shared.Modules.Replication.ReplicationRegistry)
local ActionTemplate = require(ReplicatedStorage.Shared.Modules.Replication.ActionTemplate)
local State = require(ReplicatedStorage.Shared.Modules.State.State)
local Meta = require(ReplicatedStorage.Shared.Modules.State.Meta)

local IS_SERVER = RunService:IsServer()

local ACTION = "Sprint"

local WALK_SPEED = 16
local SPRINT_SPEED = 26

local DEBUG = true

local function log(tag, ...)
	if DEBUG then
		print(("[SPRINT:%s]"):format(tag), ...)
	end
end

if IS_SERVER then
	local t = ActionTemplate.server()

	local sprintMemory = {}

	local function validate(player: Player)
		if not State.get(Meta.StateKeys.CharacterAlive, player) then
			return false, "dead"
		end

		if player.Character.Humanoid.WalkSpeed > SPRINT_SPEED and State.get(Meta.StateKeys.Sprinting, player) then
			return false, "Exploit Sprint"
		end

		return true
	end

	Players.PlayerRemoving:Connect(function(player)
		t:cleanup(player)
		sprintMemory[player] = nil
	end)

	Registry.register(ACTION, {

		validate = function(player, payload, clientSeq)
			return t:validate(player, clientSeq, function()
				return validate(player)
			end)
		end,

		Execute = function(player, payload, clientSeq)
			t:advance(player, clientSeq)

			local current = sprintMemory[player] == true

			current = not current

			sprintMemory[player] = current

			local enabled = current

			log("EXECUTE", player.Name, enabled)

			State.set(Meta.StateKeys.Sprinting, player, enabled)

			return {
				enabled = enabled,
			}
		end,
	})
else
	local t = ActionTemplate.client()

	local localPlayer = Players.LocalPlayer

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
		return State.get(Meta.StateKeys.CharacterAlive, localPlayer)
	end

	Registry.register(ACTION, {

		onPredict = function(payload, clientSeq)
			if not canSprint() then
				return false
			end

			sprintMemory = not sprintMemory

			local enabled = sprintMemory

			log("PREDICT", enabled)

			apply(enabled)

			return true
		end,

		onReconcile = function(state, reason, clientSeq)
			log("RECONCILE", reason)

			if not state then
				apply(false)
				return
			end

			t:reconcile(clientSeq, state, function(serverState)
				local current = State.get(Meta.StateKeys.Sprinting, localPlayer)

				if current ~= serverState.enabled then
					log("CORRECTION")
					apply(serverState.enabled)
				end
			end, function()
				log("RESET")
				apply(false)
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
end

return {}
