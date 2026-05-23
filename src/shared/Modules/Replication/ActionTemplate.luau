local RunService = game:GetService("RunService")
local IS_SERVER = RunService:IsServer()

local ServerTemplate = {}
ServerTemplate.__index = ServerTemplate

function ServerTemplate.new(config: {
	cooldown: number?,
	resetAfter: number?,
	maxCount: number?,
})
	return setmetatable({
		_cooldown = config.cooldown or 0,
		_resetAfter = config.resetAfter or math.huge,
		_maxCount = config.maxCount or math.huge,
		_data = {},
	}, ServerTemplate)
end

function ServerTemplate:_get(player)
	local d = self._data[player]
	if not d then
		d = { lastTime = 0, count = 0, locks = {} }
		self._data[player] = d
	end
	return d
end

function ServerTemplate:cleanup(player)
	self._data[player] = nil
end

function ServerTemplate:validate(player, extra)
	local now = os.clock()
	local d = self:_get(player)

	if (now - d.lastTime) < self._cooldown then
		return false, "cooldown"
	end

	for key, expiry in d.locks do
		if now < expiry then
			return false, "locked:" .. key
		end
		d.locks[key] = nil
	end

	if extra then
		return extra(player, d, now)
	end

	return true, nil
end

function ServerTemplate:advance(player)
	local now = os.clock()
	local d = self:_get(player)

	if (now - d.lastTime) > self._resetAfter then
		d.count = 0
	end

	d.count = (d.count % self._maxCount) + 1
	d.lastTime = now

	return d.count, now
end

function ServerTemplate:lock(player, key, duration)
	self:_get(player).locks[key] = os.clock() + duration
end

function ServerTemplate:getCount(player)
	return self:_get(player).count
end

local ClientTemplate = {}
ClientTemplate.__index = ClientTemplate

function ClientTemplate.new(config: {
	cooldown: number?,
	resetAfter: number?,
	maxCount: number?,
})
	return setmetatable({
		_cooldown = config.cooldown or 0,
		_resetAfter = config.resetAfter or math.huge,
		_maxCount = config.maxCount or math.huge,
		_seq = 0,
		_reconciledSeq = 0,
		_lastTime = 0,
		_count = 0,
		_locks = {},
	}, ClientTemplate)
end

function ClientTemplate:canAct(now)
	if (now - self._lastTime) < self._cooldown then
		return false, "cooldown"
	end
	for key, expiry in self._locks do
		if now < expiry then
			return false, "locked:" .. key
		end
		self._locks[key] = nil
	end
	return true, nil
end

function ClientTemplate:advance(now)
	if (now - self._lastTime) > self._resetAfter then
		self._count = 0
	end

	self._count = (self._count % self._maxCount) + 1
	self._lastTime = now
	self._seq += 1

	return self._count, self._seq
end

function ClientTemplate:reconcile(clientSeq, state, onSuccess, onReject)
	if clientSeq <= self._reconciledSeq then
		return
	end
	self._reconciledSeq = clientSeq

	if not state then
		self._count = 0
		self._lastTime = 0
		table.clear(self._locks)
		if onReject then
			onReject()
		end
		return
	end

	for key, ttl in state._locks or {} do
		self._locks[key] = os.clock() + ttl
	end

	local mispredicted = self._count ~= state._count
	self._count = state._count

	if onSuccess then
		onSuccess(state, mispredicted)
	end
end

function ClientTemplate:lock(key, duration)
	self._locks[key] = os.clock() + duration
end

function ClientTemplate:getCount()
	return self._count
end

function ClientTemplate:getSeq()
	return self._seq
end

local ActionTemplate = {}

function ActionTemplate.server(config)
	assert(IS_SERVER, "ActionTemplate.server() called on client")
	return ServerTemplate.new(config)
end

function ActionTemplate.client(config)
	assert(not IS_SERVER, "ActionTemplate.client() called on server")
	return ClientTemplate.new(config)
end

return ActionTemplate
