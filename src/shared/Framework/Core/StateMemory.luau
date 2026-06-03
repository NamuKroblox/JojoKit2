--[[
	StateMemory
	
	Stores intermediate state produced during an ability's lifecycle.
	Segmented by execution stage (Predict, Reconcile, Validate, Execute).
]]

local StateMemory = {}
StateMemory.__index = StateMemory

export type Stage = "Predict" | "Reconcile" | "Validate" | "Execute"

function StateMemory.new()
	local self = setmetatable({}, StateMemory)
	
	self._stages: { [Stage]: { [string]: any } } = {
		Predict = {},
		Reconcile = {},
		Validate = {},
		Execute = {},
	}
	
	return self
end

--[[
	Set state for a specific stage.
]]
function StateMemory:set(stage: Stage, key: string, value: any)
	if not self._stages[stage] then
		error(`Unknown stage: {stage}`)
	end
	self._stages[stage][key] = value
end

--[[
	Get state from a specific stage.
]]
function StateMemory:get(stage: Stage, key: string): any
	if not self._stages[stage] then
		error(`Unknown stage: {stage}`)
	end
	return self._stages[stage][key]
end

--[[
	Check if a key exists in a stage.
]]
function StateMemory:has(stage: Stage, key: string): boolean
	if not self._stages[stage] then
		error(`Unknown stage: {stage}`)
	end
	return self._stages[stage][key] ~= nil
end

--[[
	Get all state for a stage.
]]
function StateMemory:getStage(stage: Stage): { [string]: any }
	if not self._stages[stage] then
		error(`Unknown stage: {stage}`)
	end
	return self._stages[stage]
end

--[[
	Clear all state for a specific stage.
]]
function StateMemory:clearStage(stage: Stage)
	if not self._stages[stage] then
		error(`Unknown stage: {stage}`)
	end
	self._stages[stage] = {}
end

--[[
	Clear all state for all stages.
]]
function StateMemory:reset()
	for stage in self._stages do
		self._stages[stage] = {}
	end
end

return StateMemory
