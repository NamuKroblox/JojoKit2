--[[
	Client Input Handler
	
	Integrates with the Combat Framework to handle player input
	and trigger ability execution on the client.
]]

local UserInputService = game:GetService("UserInputService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Framework = require(ReplicatedStorage.Shared.Framework)

local InputHandler = {}
InputHandler.__index = InputHandler

function InputHandler.new(combatLayer: any, controlBus: any)
	local self = setmetatable({}, InputHandler)
	
	self.combatLayer = combatLayer
	self.controlBus = controlBus
	self.abilityBindings = {}
	
	return self
end

--[[
	Bind a keyboard key to an ability.
]]
function InputHandler:bindAbilityToKey(key: Enum.KeyCode, abilityName: string)
	self.abilityBindings[key] = abilityName
end

--[[
	Initialize input handling.
]]
function InputHandler:initialize()
	UserInputService.InputBegan:Connect(function(input, gameProcessed)
		if gameProcessed then
			return
		end
		
		local abilityName = self.abilityBindings[input.KeyCode]
		if abilityName then
			local success, reason = self.combatLayer:executeAbility(abilityName)
			if not success then
				print(`Failed to execute {abilityName}: {reason}`)
			end
		end
	end)
end

return InputHandler
