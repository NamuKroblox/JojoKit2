local Players           = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService        = game:GetService("RunService")

local Registry       = require(ReplicatedStorage.Shared.Modules.Replication.ReplicationRegistry)
local ActionTemplate = require(ReplicatedStorage.Shared.Modules.Replication.ActionTemplate)
local State          = require(ReplicatedStorage.Shared.Modules.State.State)
local Meta           = require(ReplicatedStorage.Shared.Modules.State.Meta)
local Constants      = require(ReplicatedStorage.Shared.Features.StandEquip.Constants)

local IS_SERVER = RunService:IsServer()

if IS_SERVER then
	local t                 = ActionTemplate.server({ cooldown = 0.5 })
	local StandEquipManager = require(game:GetService("ServerScriptService").Server.Modules.Stand.Equip.Manager)
	
	Players.PlayerAdded:Connect(function(player)
		StandEquipManager.Init(player)

	end)

	Players.PlayerRemoving:Connect(function(player)
		t:cleanup(player)
	end)

	Registry.register(Constants.ACTION, {
		validate = function(player)
			return t:validate(player, function(p)
				if not State.get(Meta.StateKeys.CharacterAlive, p) then
					return false, "dead"
				end
				return true, nil
			end)
		end,

		Execute = function(player)
			t:advance(player)
			local equipped = StandEquipManager.Toggle(player)
			return { equipped = equipped, _count = 1 }
		end,
	})

else
	local t            = ActionTemplate.client({ cooldown = 0.5 })
	local StandVisual  = require(script.Parent.Util.StandVisual)
	local localPlayer  = Players.LocalPlayer

	Registry.register(Constants.ACTION, {
		onPredict = function()
			local now = os.clock()
			local ok  = t:canAct(now)
			if not ok then return false end
			t:advance(now)
			local next = not (State.get(Meta.StateKeys.StandEquipped, localPlayer) == true)
			State.set(Meta.StateKeys.StandEquipped, localPlayer, next)
			return true
		end,

		onReconcile = function(state, reason, clientSeq)
			t:reconcile(clientSeq, state,
				function(s)
					State.set(Meta.StateKeys.StandEquipped, localPlayer, s.equipped)
				end,
				function()
					State.set(Meta.StateKeys.StandEquipped, localPlayer, false)
				end
			)
		end,

		onBroadcast = function(senderUserId, state)
			local sender = Players:GetPlayerByUserId(senderUserId)
			if not sender then return end
			State.set(Meta.StateKeys.StandEquipped, sender, state.equipped)
			StandVisual.sync(sender, state.equipped)
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