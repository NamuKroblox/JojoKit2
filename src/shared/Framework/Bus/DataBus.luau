--[[
	DataBus
	
	Transfers data between components with full-duplex communication.
	Supports data references and values for reading and writing shared information.
]]

local DataBus = {}
DataBus.__index = DataBus

function DataBus.new()
	local self = setmetatable({}, DataBus)
	
	self._data: { [string]: any } = {}
	self._observers: { [string]: { (key: string, value: any) -> () } } = {}
	self._hooks: { [string]: (key: string, value: any) -> () } = {}
	
	return self
end

--[[
	Set a data value.
]]
function DataBus:set(key: string, value: any)
	local oldValue = self._data[key]
	self._data[key] = value
	
	-- Call observability hooks
	if self._hooks.beforeSet then
		self._hooks.beforeSet(key, value, oldValue)
	end
	
	-- Notify observers
	if self._observers[key] then
		for _, observer in ipairs(self._observers[key]) do
			observer(key, value)
		end
	end
	
	-- Call observability hooks
	if self._hooks.afterSet then
		self._hooks.afterSet(key, value, oldValue)
	end
end

--[[
	Get a data value.
]]
function DataBus:get(key: string): any
	return self._data[key]
end

--[[
	Check if a key exists.
]]
function DataBus:has(key: string): boolean
	return self._data[key] ~= nil
end

--[[
	Subscribe to changes on a specific key.
]]
function DataBus:subscribe(key: string, observer: (key: string, value: any) -> ()): () -> ()
	if not self._observers[key] then
		self._observers[key] = {}
	end
	
	table.insert(self._observers[key], observer)
	
	-- Return unsubscribe function
	return function()
		local observers = self._observers[key]
		for i, obs in ipairs(observers) do
			if obs == observer then
				table.remove(observers, i)
				break
			end
		end
	end
end

--[[
	Register observability hooks for debugging.
]]
function DataBus:setHook(hookName: string, callback: (key: string, value: any, oldValue: any?) -> ())
	self._hooks[hookName] = callback
end

--[[
	Clear all data.
]]
function DataBus:reset()
	self._data = {}
end

return DataBus
