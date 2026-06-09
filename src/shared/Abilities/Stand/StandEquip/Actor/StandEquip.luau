local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Registry = require(ReplicatedStorage.Shared.Registration.Registries.ReplicationRegistry)
local ActionTemplate = require(ReplicatedStorage.Shared.Helper.Replication.ActionTemplate)
local State = require(ReplicatedStorage.Shared.State.State)
local Meta = require(ReplicatedStorage.Shared.State.Meta)
local StandEquipManager = require(script.Parent.Parent.Shared.EquipManager)


local Constants = {
	ACTION = "StandEquip",	
}

local IS_SERVER = RunService:IsServer()
local COOLDOWN = 0.5

if IS_SERVER then

	local t = ActionTemplate.server({ cooldown = COOLDOWN })
	
	Players.PlayerAdded:Connect(function(player)
		StandEquipManager.Init(player)
	end)

	Registry:register(Constants.ACTION, {

		validate = function(player, payload, clientSeq)
			return t:validate(player, clientSeq, function()
				if not State.get(Meta.StateKeys.CharacterAlive, player) then
					return false, "dead"
				end

				--local StatusService = Knit.GetService("StatusService")
				--if StatusService:IsBlocked(player, Constants.ACTION) then
				--	return false, "blocked"
				--end

				return true, nil
			end)
		end,

		Execute = function(player, payload, clientSeq)
			t:advance(player, clientSeq)
			local equipped = StandEquipManager.Toggle(player)
			return { equipped = equipped, _count = 1 }
		end,
	})

	State.listen(Meta.StateKeys.CharacterAlive, function(player, alive)
		if not alive then
			State.set(Meta.StateKeys.StandEquipped, player, false)
			t:cleanup(player)
		end
	end)

	State.listen(Meta.StateKeys.InGame, function(player, inGame)
		if not inGame then
			t:cleanup(player)
		end
	end)
	
	
	
else
	
	local DataService = require(game.ReplicatedStorage.Packages.DataService).client
	local t = ActionTemplate.client({ cooldown = COOLDOWN })
	local StandVisual = require(script.Parent.Parent.Shared.StandVisual)
	local AttachModel = require(script.Parent.Parent.Shared.AttachModel)
	local localPlayer = Players.LocalPlayer

	Registry:register(Constants.ACTION, {

		onPredict = function()
			local now = os.clock()
			if not t:canAct(now) then
				return false
			end
			t:advance(now)
			local next = not (State.get(Meta.StateKeys.StandEquipped, localPlayer) == true)
			State.set(Meta.StateKeys.StandEquipped, localPlayer, next)
			return true
		end,

		onReconcile = function(state, reason, clientSeq)
			t:reconcile(clientSeq, state, function(s)
				State.set(Meta.StateKeys.StandEquipped, localPlayer, s.equipped)
			end, function()
				State.set(Meta.StateKeys.StandEquipped, localPlayer, false)
			end)
		end,

		onBroadcast = function(senderUserId, state)
			local sender = Players:GetPlayerByUserId(senderUserId)
			if not sender then
				return
			end
			State.set(Meta.StateKeys.StandEquipped, sender, state.equipped)
		end,

		public = {
			RetrieveStandInfo = function(player: Player)
				return AttachModel.HasAttachment(player)
			end,
		},
	})

	State.listen(Meta.StateKeys.StandEquipped, function(player, equipped, _, isReplay)
		if isReplay then
			return
		end
		StandVisual.sync(player, equipped)
	end)

	State.listen(Meta.StateKeys.CharacterAlive, function(player, alive, _, isReplay)
		if isReplay or alive then
			return
		end
		StandVisual.hide(player)
		t:cleanup(player)
	end)

	State.listen(Meta.StateKeys.InGame, function(player, inGame, _, isReplay)
		if isReplay or inGame then
			return
		end
		StandVisual.cleanup(player)
		t:cleanup(player)
	end)
	
	DataService:getChangedSignal("Stand"):Connect(function(Stand)
		warn(Stand)
			
	end)
	
end

return {}