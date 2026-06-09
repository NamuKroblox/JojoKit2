-- Factory + global name-based lookup for every Registry instance.

local Registry_Class = require(script.Parent.RegistryClass)

local _all: { [string]: any } = {}

local RegistryManager = {}

function RegistryManager.create(config: any): any
	assert(
		type(config) == "table"
			and type(config.name) == "string"
			and #config.name > 0,
		"[RegistryManager] config.name must be a non-empty string"
	)
	assert(
		not _all[config.name],
		"[RegistryManager] Registry '" .. config.name .. "' already exists"
	)
	local reg = Registry_Class.new(config)
	_all[config.name] = reg
	return reg
end

-- Retrieve any registry by name (e.g. from a system that only knows the name).
function RegistryManager.get(name: string): any
	return _all[name]
end

function RegistryManager.getAll(): { [string]: any }
	return _all
end

return RegistryManager