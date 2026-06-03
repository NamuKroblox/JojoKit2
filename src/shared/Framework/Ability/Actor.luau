--[[
	Actor
	
	Responsible for gameplay logic. Evaluates state, performs calculations,
	and emits intents that describe what should happen.
	
	Does not directly perform reactions. Emits informed intents based on
	available data and current game state.
]]

local Actor = {}
Actor.__index = Actor

export type ActorConfig = {
	dataUnit: any,
	stateBus: any,
	name: string,
}

function Actor.new(config: ActorConfig)
	local self = setmetatable({}, Actor)
	
	self.name = config.name
	self.dataUnit = config.dataUnit
	self.stateBus = config.stateBus
	
	self._lifecycle = "Idle"
	
	return self
end

--[[
	Predict stage: Client-side prediction of ability execution.
]]
function Actor:predict()
	self._lifecycle = "Predict"
	-- Override in subclass
end

--[[
	Reconcile stage: Correct state based on server authority.
]]
function Actor:reconcile()
	self._lifecycle = "Reconcile"
	-- Override in subclass
end

--[[
	Validate stage: Server-side validation before execution.
]]
function Actor:validate()
	self._lifecycle = "Validate"
	-- Override in subclass
	return true  -- Return success/failure
end

--[[
	Execute stage: Server-side execution of ability.
]]
function Actor:execute()
	self._lifecycle = "Execute"
	-- Override in subclass
end

--[[
	Emit an intent onto the StateBus.
]]
function Actor:emit(intentName: string, data: any?)
	self.stateBus:emit(intentName, data)
end

--[[
	Get current lifecycle stage.
]]
function Actor:getLifecycle(): string
	return self._lifecycle
end

--[[
	Reset actor state.
]]
function Actor:reset()
	self._lifecycle = "Idle"
end

return Actor
