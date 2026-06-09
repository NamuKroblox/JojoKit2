-- OOP base class. Every registry is an instance of this.

export type RegistryConfig = {
	name         : string,
	-- How to pull the key out of an entry. Defaults to `entry.id`.
	keyExtractor : ((entry: any) -> string)?,
	-- What to do when the same key is registered twice.
	onDuplicate  : ("warn" | "error" | "ignore")?,
	-- Validate the key itself (e.g. length limits). Return false + reason to reject.
	keyValidator : ((key: string) -> (boolean, string?))?,
	-- Validate the entry before it is stored. Return false + reason to reject.
	validate     : ((entry: any) -> (boolean, string?))?,
	-- Hook: called after a successful register. Receives (self, key, entry).
	onRegister   : ((registry: any, key: string, entry: any) -> ())?,
	-- Hook: called after a successful unregister. Receives (self, key, entry).
	onUnregister : ((registry: any, key: string, entry: any) -> ())?,
	-- Extra methods injected into the instance. Each fn receives (self, ...) via `:` call.
	methods      : { [string]: (registry: any, ...any) -> ...any }?,
}

local Registry = {}
Registry.__index = Registry

function Registry.new(config: RegistryConfig): any
	local self = setmetatable({}, Registry)

	self._name         = config.name
	self._keyExtractor = config.keyExtractor or function(e: any): string return e.id end
	self._onDuplicate  = config.onDuplicate  or "warn"
	self._keyValidator = config.keyValidator
	self._validate     = config.validate
	self._onRegister   = config.onRegister
	self._onUnregister = config.onUnregister
	self._data         = {} :: { [string]: any }
	-- Free-form bag for hooks/methods to stash secondary state (e.g. byInput).
	self._store        = {} :: { [string]: any }

	if config.methods then
		for name, fn in config.methods do
			-- fn(self, ...) — called with `:` notation, self arrives as first arg.
			self[name] = fn
		end
	end

	return self
end

--[[
    Two call signatures:
        registry:register(entry)          – key extracted via keyExtractor(entry)
        registry:register("myKey", value) – explicit string key + separate value

    Returns a cleanup function: calling it unregisters the key.
]]
function Registry:register(keyOrEntry: any, value: any?): () -> ()
	local key   : string
	local entry : any

	if type(keyOrEntry) == "string" and value ~= nil then
		key   = keyOrEntry
		entry = value
	else
		entry = keyOrEntry
		key   = self._keyExtractor(entry)
	end

	assert(
		type(key) == "string" and #key > 0,
		("[%s] register: key must be a non-empty string"):format(self._name)
	)

	if self._keyValidator then
		local ok, reason = self._keyValidator(key)
		assert(ok, ("[%s] Invalid key '%s': %s"):format(self._name, key, reason or ""))
	end

	if self._data[key] then
		local dup = self._onDuplicate
		if dup == "warn" then
			warn(("[%s] Duplicate key '%s' — overwriting"):format(self._name, key))
			self:unregister(key)
		elseif dup == "error" then
			error(("[%s] Duplicate key '%s'"):format(self._name, key), 2)
		elseif dup == "ignore" then
			return function() end
		end
	end

	if self._validate then
		local ok, reason = self._validate(entry)
		assert(ok, ("[%s] Validation failed for '%s': %s"):format(
			self._name, key, reason or "unknown"
			))
	end

	self._data[key] = entry

	if self._onRegister then
		self._onRegister(self, key, entry)
	end

	return function()
		self:unregister(key)
	end
end

function Registry:unregister(key: string)
	local entry = self._data[key]
	if not entry then return end
	self._data[key] = nil
	if self._onUnregister then
		self._onUnregister(self, key, entry)
	end
end

function Registry:get(key: string): any
	return self._data[key]
end

function Registry:getAll(): { [string]: any }
	return self._data
end

return Registry