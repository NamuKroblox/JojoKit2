local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Registry = require(ReplicatedStorage.Shared.Modules.Replication.ReplicationRegistry)
local State = require(ReplicatedStorage.Shared.Modules.State.State)
local Meta = require(ReplicatedStorage.Shared.Modules.State.Meta)
local Constants = require(ReplicatedStorage.Shared.Features.StandEquip.Constants)

local IS_SERVER = RunService:IsServer()

local TOGGLE_DEBOUNCE = 0.3
local lastToggleTime = 0

if IS_SERVER then
	local StandEquipManager = require(game:GetService("ServerScriptService").Server.Modules.Stand.Equip.Manager)

	Registry.register(Constants.ACTION, {

		validate = function(player, _payload)
			if not State.get(Meta.StateKeys.CharacterAlive, player) then
				return false, StandEquipManager.IsEquipped(player)
			end
			return true, nil
		end,

		predict = function(player, _payload)
			local fn = StandEquipManager.Toggle(player)
			if fn then
				return true
			else
				return false
			end
		end,
	})
else
	local StandVisual = require(script.Parent.Util.StandVisual)
	local localPlayer = Players.LocalPlayer
	local pendingToggle: boolean? = nil

	Registry.register(Constants.ACTION, {

		onPredict = function(_payload)
			local now = os.clock()
			if (now - lastToggleTime) < TOGGLE_DEBOUNCE then
				return false
			end
			lastToggleTime = now

			local next = not (State.get(Meta.StateKeys.StandEquipped, localPlayer) == true)
			pendingToggle = next
			State.set(Meta.StateKeys.StandEquipped, localPlayer, next)
			return true
		end,

		onReconcile = function(reconcileState)
			pendingToggle = nil
			if reconcileState ~= nil then
				State.set(Meta.StateKeys.StandEquipped, localPlayer, reconcileState)
			end
		end,

		onBroadcast = function(senderUserId, _payload, authoritativeState)
			local sender = Players:GetPlayerByUserId(senderUserId)
			if not sender then
				return
			end
			State.set(Meta.StateKeys.StandEquipped, sender, authoritativeState)
			StandVisual.sync(sender, authoritativeState)
		end,
	})

	State.listen(Meta.StateKeys.StandEquipped, function(player, equipped)
		StandVisual.sync(player, equipped)
	end)

	State.listen(Meta.StateKeys.CharacterAlive, function(player, alive)
		if alive then
			if State.get(Meta.StateKeys.StandEquipped, player) == true then
				StandVisual.sync(player, true)
			end
		else
			StandVisual.hide(player)
		end
	end)

	State.listen(Meta.StateKeys.InGame, function(player, inGame)
		if not inGame then
			StandVisual.cleanup(player)
		end
	end)
end

return {}
