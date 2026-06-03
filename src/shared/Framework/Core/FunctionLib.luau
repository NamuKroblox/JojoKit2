--[[
	FunctionLib
	
	A collection of reusable functions used by Actors and Reactors.
	Contains internal logic for calculations, reactions, and utility operations.
]]

local FunctionLib = {}
FunctionLib.__index = FunctionLib

function FunctionLib.new()
	local self = setmetatable({}, FunctionLib)
	
	self._functions: { [string]: (...any) -> ...any } = {}
	
	return self
end

--[[
	Register a reusable function.
]]
function FunctionLib:register(name: string, fn: (...any) -> ...any)
	if self._functions[name] then
		warn(`Function '{name}' is already registered. Overwriting.`)
	end
	self._functions[name] = fn
end

--[[
	Call a registered function.
]]
function FunctionLib:call(name: string, ...: any): ...any
	local fn = self._functions[name]
	if not fn then
		error(`Function '{name}' is not registered.`)
	end
	return fn(...)
end

--[[
	Check if a function is registered.
]]
function FunctionLib:exists(name: string): boolean
	return self._functions[name] ~= nil
end

--[[
	Unregister a function.
]]
function FunctionLib:unregister(name: string)
	self._functions[name] = nil
end

return FunctionLib
