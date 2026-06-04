local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")

local InputRegistry = require(ReplicatedStorage.Shared.Registries.InputRegistry)
local State = require(ReplicatedStorage.Shared.State.State)
local Meta = require(ReplicatedStorage.Shared.State.Meta)

local localPlayer = Players.LocalPlayer

InputRegistry.register({
	id = "StandEquip",
	input = Enum.KeyCode.Q,
	action = "StandEquip",
	context = "character",
	priority = 10,
	guard = function()
		return State.get(Meta.StateKeys.CharacterAlive) == true
	end,
})

InputRegistry.register({
	id = "Punch",
	input = Enum.UserInputType.MouseButton1,
	action = "Punch",
	context = "character",
	priority = 10,
	guard = function()
		return State.get(Meta.StateKeys.CharacterAlive) == true and State.get(Meta.StateKeys.StandEquipped) == true
	end,
})

InputRegistry.register({
	id = "Sprint",
	input = Enum.KeyCode.LeftControl,
	action = "Sprint",
	context = "character",
	priority = 5,
	guard = function()
		return State.get(Meta.StateKeys.CharacterAlive) == true
	end,
	payload = function()
		local current = State.get(Meta.StateKeys.Sprinting, localPlayer) == true
		return { enabled = not current }
	end,
})

return {}
