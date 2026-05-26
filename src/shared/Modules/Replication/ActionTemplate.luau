local RunService = game:GetService("RunService")

local IS_SERVER = RunService:IsServer()

local ServerTemplate = {}
ServerTemplate.__index = ServerTemplate

function ServerTemplate.new(config: {
	cooldown: number?,
})
	config = config or {}

	return setmetatable({
		_cooldown = config.cooldown or 0,
		_data = {},
	}, ServerTemplate)
end

function ServerTemplate:_get(player)
	local d = self._data[player]

	if not d then
		d = {
			lastTime = 0,
			locks = {},
			lastSeq = 0,
		}

		self._data[player] = d
	end

	return d
end

function ServerTemplate:cleanup(player)
	self._data[player] = nil
end

function ServerTemplate:_pruneLocks(d, now)
	for key, expiry in pairs(d.locks) do
		if now >= expiry then
			d.locks[key] = nil
		end
	end
end

function ServerTemplate:validate(player, clientSeq: number, extra)
	if type(clientSeq) ~= "number" then
		return false, "bad_seq"
	end

	local now = workspace:GetServerTimeNow()
	local d = self:_get(player)

	self:_pruneLocks(d, now)

	if clientSeq <= d.lastSeq then
		return false, "stale_seq"
	end

	if (now - d.lastTime) < self._cooldown then
		return false, "cooldown"
	end

	for key, expiry in pairs(d.locks) do
		if now < expiry then
			return false, "locked:" .. key
		end
	end

	if extra then
		local ok, reason = extra(player, d, now)
		if not ok then
			return false, reason
		end
	end

	return true, nil
end

function ServerTemplate:advance(player, clientSeq: number)
	local now = workspace:GetServerTimeNow()
	local d = self:_get(player)

	d.lastTime = now
	d.lastSeq = clientSeq

	return now
end

function ServerTemplate:lock(player, key, duration)
	self:_get(player).locks[key] = workspace:GetServerTimeNow() + duration
end

function ServerTemplate:getLastSeq(player)
	return self:_get(player).lastSeq
end

local ClientTemplate = {}
ClientTemplate.__index = ClientTemplate

function ClientTemplate.new(config: {
	cooldown: number?,
})
	config = config or {}

	return setmetatable({
		_cooldown = config.cooldown or 0,

		_seq = 0,
		_reconciledSeq = 0,

		_lastTime = 0,
		_locks = {},
	}, ClientTemplate)
end

function ClientTemplate:cleanup()
	self._seq = 0
	self._reconciledSeq = 0
	self._lastTime = 0
	table.clear(self._locks)
end

function ClientTemplate:_pruneLocks(now)
	for key, expiry in pairs(self._locks) do
		if now >= expiry then
			self._locks[key] = nil
		end
	end
end

function ClientTemplate:canAct(now)
	if (now - self._lastTime) < self._cooldown then
		return false, "cooldown"
	end

	self:_pruneLocks(now)

	for key, expiry in pairs(self._locks) do
		if now < expiry then
			return false, "locked:" .. key
		end
	end

	return true
end

function ClientTemplate:advance(now)
	self._lastTime = now
	self._seq += 1

	return self._seq
end

function ClientTemplate:reconcile(clientSeq, state, onSuccess, onReject)
	if type(clientSeq) ~= "number" then
		return
	end

	if clientSeq <= self._reconciledSeq then
		return
	end

	self._reconciledSeq = clientSeq

	if not state then
		self:cleanup()

		if onReject then
			onReject(clientSeq)
		end

		return
	end

	for key, expiry in pairs(state._locks or {}) do
		self._locks[key] = expiry
	end

	if onSuccess then
		onSuccess(state, clientSeq)
	end
end

function ClientTemplate:lock(key, duration)
	self._locks[key] = workspace:GetServerTimeNow() + duration
end

function ClientTemplate:getSeq()
	return self._seq
end

function ClientTemplate:getReconciledSeq()
	return self._reconciledSeq
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
