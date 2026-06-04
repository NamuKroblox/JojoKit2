local UserInputService = game:GetService("UserInputService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Knit = require(ReplicatedStorage.Packages.knit)
local InputBind = require(ReplicatedStorage.Shared.Modules.Helper.InputBind)
local State = require(ReplicatedStorage.Shared.Modules.State.State)
local Meta = require(ReplicatedStorage.Shared.Modules.State.Meta)

-- Input action bindings
local INPUT_BINDINGS = {
	{
		id = "EquipStand",
		input = Enum.KeyCode.Q,
		action = "StandEquip",
		context = "character",
		canExecute = function()
			return State.get(Meta.StateKeys.CharacterAlive) == true
		end,
	},
}

local InputController = { Name = "InputController" }

function InputController:KnitStart()
	local replicationController = Knit.GetController("ReplicationController")

	for _, binding in ipairs(INPUT_BINDINGS) do
		InputBind.input(binding.id, binding.input, function()
			if binding.canExecute and not binding.canExecute() then
				return
			end
			replicationController:Dispatch(binding.action, {})
		end, binding.context)
	end
end

return InputController
