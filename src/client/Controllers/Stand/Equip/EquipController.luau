-- StandEquipController (ModuleScript — StarterPlayerScripts/Controllers)

local Knit = require(game:GetService("ReplicatedStorage").Packages.knit)
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local InputBind = require(ReplicatedStorage.Shared.Modules.Helper.InputBind)
local State = require(ReplicatedStorage.Shared.Modules.State.State)
local StateMeta = require(ReplicatedStorage.Shared.Modules.State.Meta)
local Constants = require(ReplicatedStorage.Shared.Features.StandEquip.Constants)

local EquipController = { Name = "EquipController" }

function EquipController:KnitInit()
	State.enable(StateMeta.StateKeys.StandEquipped)
	State.enable(StateMeta.StateKeys.CharacterAlive)
	State.enable(StateMeta.StateKeys.InGame)
	State.start()
end

function EquipController:KnitStart()
	local ReplicationController = Knit.GetController("ReplicationController")
	print("KnitStart fired, ReplicationController:", ReplicationController)
	InputBind.key("StandToggle", Enum.KeyCode.Q, function()
		if not State.get(StateMeta.StateKeys.CharacterAlive) then
			return
		end
		ReplicationController:Dispatch(Constants.ACTION, {})
		print("Q pressed, alive:", State.get(StateMeta.StateKeys.CharacterAlive))
	end, "character")
end

return EquipController
