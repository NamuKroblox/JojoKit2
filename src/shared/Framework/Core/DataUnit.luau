--[[
	DataUnit
	
	Serves as the shared resource layer for an ability.
	Composed of FunctionLibs, DataLibs, and StateMemory.
]]

local FunctionLib = require(script.Parent.FunctionLib)
local DataLib = require(script.Parent.DataLib)
local StateMemory = require(script.Parent.StateMemory)

local DataUnit = {}
DataUnit.__index = DataUnit

function DataUnit.new()
	local self = setmetatable({}, DataUnit)
	
	self.functionLib = FunctionLib.new()
	self.dataLib = DataLib.new()
	self.stateMemory = StateMemory.new()
	
	return self
end

--[[
	Reset all data and state.
]]
function DataUnit:reset()
	self.dataLib:reset()
	self.stateMemory:reset()
end

return DataUnit
