--[[
	Reactor
	
	Responsible for consuming intents emitted by the Actor and performing
	the corresponding reactions. A reaction is any operation that fulfills an intent.
	
	Does not generate gameplay decisions. Reacts to decisions already made by the Actor.
]]

local Reactor = {}
Reactor.__index = Reactor

export type ReactorConfig = {
	dataUnit: any,
	stateBus: any,
	name: string,
}

function Reactor.new(config: ReactorConfig)
	local self = setmetatable({}, Reactor)
	
	self.name = config.name
	self.dataUnit = config.dataUnit
	self.stateBus = config.stateBus
	
	self._lifecycle = "Idle"
	self._subscriptions: { () -> () } = {}
	
	return self
end

--[[
	Predict stage: React to intents emitted during client prediction.
]]
function Reactor:predict()
	self._lifecycle = "Predict"
	-- Override in subclass
end

--[[
	Reconcile stage: React to reconciliation intents.
]]
function Reactor:reconcile()
	self._lifecycle = "Reconcile"
	-- Override in subclass
end

--[[
	Validate stage: React to intents during server validation.
]]
function Reactor:validate()
	self._lifecycle = "Validate"
	-- Override in subclass
end

--[[
	Execute stage: React to intents during server execution.
]]
function Reactor:execute()
	self._lifecycle = "Execute"
	-- Override in subclass
end

--[[
	Subscribe to an intent on the StateBus.
]]
function Reactor:subscribe(intentName: string, callback: (intent: any) -> ())
	local unsubscribe = self.stateBus:subscribe(intentName, callback)
	table.insert(self._subscriptions, unsubscribe)
	return unsubscribe
end

--[[
	Get current lifecycle stage.
]]
function Reactor:getLifecycle(): string
	return self._lifecycle
end

--[[
	Reset reactor state and unsubscribe from all intents.
]]
function Reactor:reset()
	self._lifecycle = "Idle"
	
	for _, unsubscribe in ipairs(self._subscriptions) do
		unsubscribe()
	end
	self._subscriptions = {}
end

return Reactor
