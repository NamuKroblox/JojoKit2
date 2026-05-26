local Knit = require(game:GetService("ReplicatedStorage").Packages.knit)
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local InputBind = require(ReplicatedStorage.Shared.Modules.Helper.InputBind)
local State = require(ReplicatedStorage.Shared.Modules.State.State)

local Meta = require(ReplicatedStorage.Shared.Modules.State.Meta)

local BINDINGS = {
	{
		id = "StandEquip",
		input = Enum.KeyCode.Q,
		action = "StandEquip",
		context = "character",
		guard = function()
			return State.get(Meta.StateKeys.CharacterAlive) == true
		end,
	},

	{
		id = "Punch",
		input = Enum.UserInputType.MouseButton1,
		action = "Punch",
		context = "character",
		guard = function()
			return State.get(Meta.StateKeys.CharacterAlive) == true and State.get(Meta.StateKeys.StandEquipped) == true
		end,
	},

	{
		id = "Sprint",
		input = Enum.KeyCode.LeftControl,
		action = "Sprint",
		context = "character",
		guard = function()
			return State.get(Meta.StateKeys.CharacterAlive) == true
		end,
	},
}

local InputController = { Name = "InputController" }

function InputController:KnitStart()
	local ReplicationController = Knit.GetController("ReplicationController")
	warn("started [INPUT]")
	for _, binding in BINDINGS do
		InputBind.input(binding.id, binding.input, function()
			if binding.guard and not binding.guard() then
				return
			end
			ReplicationController:Dispatch(binding.action, {})
		end, binding.context)
	end
end

return InputController
