--[[
	DataLib
	
	A collection of managed data references.
	Responsibilities include:
	- Data retrieval
	- Data storage
	- Reference management
	- Shared data access
]]

local DataLib = {}
DataLib.__index = DataLib

function DataLib.new()
	local self = setmetatable({}, DataLib)
	
	self._data: { [string]: any } = {}
	self._references: { [string]: any } = {}
	
	return self
end

--[[
	Store data with a key.
]]
function DataLib:set(key: string, value: any)
	self._data[key] = value
end

--[[
	Retrieve data by key.
]]
function DataLib:get(key: string): any
	return self._data[key]
end

--[[
	Create a reference to an object that persists.
]]
function DataLib:createReference(key: string, value: any)
	self._references[key] = value
end

--[[
	Get a reference.
]]
function DataLib:getReference(key: string): any
	return self._references[key]
end

--[[
	Update a reference.
]]
function DataLib:updateReference(key: string, value: any)
	self._references[key] = value
end

--[[
	Remove a reference.
]]
function DataLib:removeReference(key: string)
	self._references[key] = nil
end

--[[
	Clear all data.
]]
function DataLib:reset()
	self._data = {}
	self._references = {}
end

return DataLib
