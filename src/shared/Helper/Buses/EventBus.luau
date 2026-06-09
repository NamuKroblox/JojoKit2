local EventBus = {}

type Listener = {
	id: number,
	fn: (...any) -> (),
	once: boolean,
}

type EventEntry = {
	listeners: { Listener },
	firing: boolean,
	pendingRemove: { [number]: boolean },
}

local events: { [string]: EventEntry } = {}
local nextId = 0

local function getEntry(name: string): EventEntry
	if not events[name] then
		events[name] = { listeners = {}, firing = false, pendingRemove = {} }
	end
	return events[name]
end

local function makeId(): number
	nextId += 1
	return nextId
end

local function connect(name: string, fn: (...any) -> (), once: boolean): () -> ()
	local entry = getEntry(name)
	local id = makeId()

	table.insert(entry.listeners, {
		id = id,
		fn = fn,
		once = once,
	})

	print(
		("[EventBus] CONNECT event=%s id=%s once=%s listeners=%d")
			:format(name, tostring(id), tostring(once), #entry.listeners)
	)

	return function()
		if entry.firing then
			entry.pendingRemove[id] = true

			print(
				("[EventBus] DEFERRED DISCONNECT event=%s id=%s")
					:format(name, tostring(id))
			)

			return
		end

		for i, listener in entry.listeners do
			if listener.id == id then
				table.remove(entry.listeners, i)

				print(
					("[EventBus] DISCONNECT event=%s id=%s listeners=%d")
						:format(name, tostring(id), #entry.listeners)
				)

				return
			end
		end

		warn(
			("[EventBus] DISCONNECT FAILED event=%s id=%s")
				:format(name, tostring(id))
		)
	end
end

function EventBus.on(name: string, fn: (...any) -> ()): () -> ()
	return connect(name, fn, false)
end

function EventBus.once(name: string, fn: (...any) -> ()): () -> ()
	return connect(name, fn, true)
end

function EventBus.fire(name: string, ...: any)
	local entry = events[name]
	if not entry or #entry.listeners == 0 then
		return
	end

	print(
		("[EventBus] FIRE event=%s listeners=%d")
			:format(name, #entry.listeners)
	)
	
	entry.firing = true

	local snapshot = table.clone(entry.listeners)
	local toRemoveAfter: { number } = {}

	for _, listener in snapshot do
		if entry.pendingRemove[listener.id] then
			continue
		end
		
		print("LISTENER HIT", name)

		local ok, err = pcall(listener.fn, ...)
		if not ok then
			warn("[EventBus] Listener error on event '" .. name .. "':", err)
		end

		if listener.once then
			table.insert(toRemoveAfter, listener.id)
		end
	end

	entry.firing = false

	for id in entry.pendingRemove do
		table.insert(toRemoveAfter, id)
	end
	
	
	table.clear(entry.pendingRemove)

	for _, id in toRemoveAfter do
		for i, listener in entry.listeners do
			if listener.id == id then
				table.remove(entry.listeners, i)
				break
			end
		end
	end
end

function EventBus.clear(name: string)
	events[name] = nil
end

return EventBus