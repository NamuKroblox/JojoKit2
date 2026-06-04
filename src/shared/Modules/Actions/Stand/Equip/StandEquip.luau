-- StandEquip.luau
-- Server-authoritative stand equip action with client-side prediction
-- Handles toggle state, visual effects, and state synchronization

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Registry = require(ReplicatedStorage.Shared.Modules.Replication.ReplicationRegistry)
local ActionTemplate = require(ReplicatedStorage.Shared.Modules.Replication.ActionTemplate)
local State = require(ReplicatedStorage.Shared.Modules.State.State)
local Meta = require(ReplicatedStorage.Shared.Modules.State.Meta)
local Constants = require(ReplicatedStorage.Shared.Features.StandEquip.Constants)

local IS_SERVER = RunService:IsServer()

local ACTION_NAME = Constants.ACTION or "StandEquip"
local EQUIP_COOLDOWN = 0.5

if IS_SERVER then
	local actionTemplate = ActionTemplate.server({ cooldown = EQUIP_COOLDOWN })
	local StandEquipManager = require(game:GetService("ServerScriptService").Server.Modules.Stand.Equip.Manager)

	Players.PlayerAdded:Connect(function(player)
		StandEquipManager.Init(player)
	end)

	Players.PlayerRemoving:Connect(function(player)
		actionTemplate:cleanup(player)
	end)

	Registry.register(ACTION_NAME, {
		validate = function(player: Player)
			if not State.get(Meta.StateKeys.CharacterAlive, player) then
				return false, "dead"
			end
			return true
		end,

		Execute = function(player: Player, _payload: any)
			actionTemplate:advance(player)
			local equipped = StandEquipManager.Toggle(player)
			return { equipped = equipped, _count = 1 }
		end,
	})
else
	local Players = game:GetService("Players")
	local actionTemplate = ActionTemplate.client({ cooldown = EQUIP_COOLDOWN })
	local StandVisual = require(script.Parent.Util.StandVisual)
	local localPlayer = Players.LocalPlayer

	Registry.register(ACTION_NAME, {
		onPredict = function()
			local now = os.clock()
			if not actionTemplate:canAct(now) then
				return false
			end

			actionTemplate:advance(now)
			local nextState = not (State.get(Meta.StateKeys.StandEquipped, localPlayer) == true)
			State.set(Meta.StateKeys.StandEquipped, localPlayer, nextState)
			return true
		end,

		onReconcile = function(serverState: any, reason: string?, clientSeq: number)
			actionTemplate:reconcile(clientSeq, serverState, function(state)
				State.set(Meta.StateKeys.StandEquipped, localPlayer, state.equipped)
			end, function()
				State.set(Meta.StateKeys.StandEquipped, localPlayer, false)
			end)
		end,

		onBroadcast = function(senderUserId: number, state: any)
			local sender = Players:GetPlayerByUserId(senderUserId)
			if not sender then
				return
			end
			State.set(Meta.StateKeys.StandEquipped, sender, state.equipped)
			StandVisual.sync(sender, state.equipped)
		end,
	})

	-- React to local state changes
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
