--[[
	ControlUnit
	
	Responsible for orchestration and lifecycle management.
	Central coordinator for all components that belong to an ability.
	
	Contains no gameplay-specific logic. Purpose is coordination rather than execution.
]]

local ControlUnit = {}
ControlUnit.__index = ControlUnit

export type ControlUnitConfig = {
	actor: any,
	reactor: any,
	dataUnit: any,
	controlBus: any,
	stateBus: any,
	name: string,
}

export type AbilityOutcome = "Completed" | "Cancelled" | "Rejected" | "Failed"

function ControlUnit.new(config: ControlUnitConfig)
	local self = setmetatable({}, ControlUnit)
	
	self.name = config.name
	self.actor = config.actor
	self.reactor = config.reactor
	self.dataUnit = config.dataUnit
	self.controlBus = config.controlBus
	self.stateBus = config.stateBus
	
	self._state = "Idle"
	self._outcome: AbilityOutcome? = nil
	
	return self
end

--[[
	Start the ability. Initialize and prepare for execution.
]]
function ControlUnit:start()
	if self._state ~= "Idle" then
		warn(`Cannot start ability {self.name}: already in state {self._state}`)
		return false
	end
	
	self._state = "Active"
	self._outcome = nil
	
	-- Notify via control bus
	self.controlBus:broadcast("AbilityStarted", {
		name = self.name,
		timestamp = tick(),
	})
	
	return true
end

--[[
	Execute the Predict stage on client.
]]
function ControlUnit:predict()
	if self._state ~= "Active" then
		return false
	end
	
	self.stateBus:processStage("Predict")
	self.actor:predict()
	self.reactor:predict()
	
	return true
end

--[[
	Execute the Reconcile stage on client.
]]
function ControlUnit:reconcile()
	if self._state ~= "Active" then
		return false
	end
	
	self.stateBus:processStage("Reconcile")
	self.actor:reconcile()
	self.reactor:reconcile()
	
	return true
end

--[[
	Execute the Validate stage on server.
]]
function ControlUnit:validate(): boolean
	if self._state ~= "Active" then
		return false
	end
	
	self.stateBus:processStage("Validate")
	local isValid = self.actor:validate()
	
	if not isValid then
		self._outcome = "Rejected"
		self:stop()
		return false
	end
	
	self.reactor:validate()
	return true
end

--[[
	Execute the Execute stage on server.
]]
function ControlUnit:execute()
	if self._state ~= "Active" then
		return false
	end
	
	self.stateBus:processStage("Execute")
	self.actor:execute()
	self.reactor:execute()
	
	self._outcome = "Completed"
	self:stop()
	
	return true
end

--[[
	Stop the ability. Handle termination and cleanup.
]]
function ControlUnit:stop(outcome: AbilityOutcome?)
	if self._state == "Idle" then
		return
	end
	
	self._state = "Idle"
	
	if outcome then
		self._outcome = outcome
	elseif not self._outcome then
		self._outcome = "Completed"
	end
	
	-- Reset all components
	self:reset()
	
	-- Notify via control bus
	self.controlBus:broadcast("AbilityStopped", {
		name = self.name,
		outcome = self._outcome,
		timestamp = tick(),
	})
end

--[[
	Cancel the ability.
]]
function ControlUnit:cancel()
	self:stop("Cancelled")
end

--[[
	Reset all component state.
]]
function ControlUnit:reset()
	self.actor:reset()
	self.reactor:reset()
	self.dataUnit:reset()
	self.stateBus:reset()
end

--[[
	Check if ability is currently active.
]]
function ControlUnit:isActive(): boolean
	return self._state == "Active"
end

--[[
	Get current state.
]]
function ControlUnit:getState(): string
	return self._state
end

--[[
	Get last outcome.
]]
function ControlUnit:getOutcome(): AbilityOutcome?
	return self._outcome
end

--[[
	Detect and handle desynchronization.
]]
function ControlUnit:handleDesync(stage: string)
	warn(`Desync detected in {self.name} at stage {stage}`)
	
	-- Correct state
	if stage == "Predict" then
		self.dataUnit.stateMemory:clearStage("Predict")
	elseif stage == "Reconcile" then
		self:reconcile()
	end
	
	-- Trigger reconciliation if needed
	self.controlBus:broadcast("DesyncDetected", {
		ability = self.name,
		stage = stage,
		timestamp = tick(),
	})
end

return ControlUnit
