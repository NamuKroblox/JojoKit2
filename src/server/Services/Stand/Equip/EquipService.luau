-- StandEquipService (ModuleScript — ServerStorage/Services)

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Knit = require(ReplicatedStorage.Packages.knit)

local State = require(ReplicatedStorage.Shared.Modules.State.State)
local StandEquipManager = require(script.Parent.Parent.Parent.Parent.Modules.Stand.Equip.Manager)
local StateMeta = require(ReplicatedStorage.Shared.Modules.State.Meta)
local Registry = require(game.ReplicatedStorage.Shared.Modules.Replication.ReplicationRegistry)

local EquipService = { Name = "EquipService" }

function EquipService:KnitStart()
	State.listen(StateMeta.StateKeys.InGame, function(player, inGame)
		print("[StandEquipService] InGame fired:", player.Name, inGame)
		if inGame then
			StandEquipManager.Init(player)
			print("[StandEquipService] Init done, equipped:", StandEquipManager.IsEquipped(player))
		end
	end)
	Players.PlayerRemoving:Connect(function(player)
		StandEquipManager.Cleanup(player)
	end)
end

return EquipService
