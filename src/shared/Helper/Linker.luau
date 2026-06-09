-- Linker.lua
-- Sits at: ReplicatedStorage.Shared.Linker
--
-- Purpose:
--   Abilities must NOT require each other's Shared modules directly.
--   Instead, each ability exposes a controlled public interface by registering
--   a "link" here. Other abilities consume that link through Linker.
--
-- Pattern:
--   Producer  →  Linker.register("Punch",  { ... })
--   Consumer  →  Linker.get("Punch")           -- sync  (load order guaranteed)
--             →  Linker.when("Punch", fn)       -- deferred (load order uncertain)

local Linker = {}

-- ── Types ─────────────────────────────────────────────────────────────────────

export type LinkDef = { [string]: (...any) -> ...any }

-- ── Internal ──────────────────────────────────────────────────────────────────

-- name → public interface table
local _registry: { [string]: LinkDef } = {}

-- name → list of callbacks waiting for that link to be registered
local _deferred: { [string]: { (LinkDef) -> () } } = {}

-- ── Registration ──────────────────────────────────────────────────────────────

--[[
    Register an ability's public interface.

    Call this exactly once per ability, from its Shared module.
    Flushes any deferred consumers that were already waiting.

    @param name   Unique key, e.g. "Punch", "Sprint", "StandEquip"
    @param link   Table of public functions this ability exposes
--]]
function Linker.register(name: string, link: LinkDef)
	assert(type(name) == "string", "Linker.register: `name` must be a string")
	assert(type(link) == "table",  "Linker.register: `link` must be a table")
	assert(
		not _registry[name],
		("Linker: '%s' is already registered. Each ability registers once."):format(name)
	)

	_registry[name] = link

	-- Wake up any consumers that called Linker.when() before we loaded
	local waiting = _deferred[name]
	if waiting then
		_deferred[name] = nil
		for _, callback in waiting do
			task.spawn(callback, link)
		end
	end
end

-- ── Consumption ───────────────────────────────────────────────────────────────

--[[
    Synchronous get.

    Returns the link immediately, or nil if not yet registered.
    Only use this when you are certain the producer loaded first
    (e.g. both are required at top-level before any runtime code runs).

    @param name   Ability key
    @return       LinkDef | nil
--]]
function Linker.get(name: string): LinkDef?
	return _registry[name]
end

--[[
    Deferred get.

    Fires `callback(link)` as soon as the link is available — immediately if
    it's already registered, or queued until it registers. Prefer this when
    load order between two abilities is uncertain.

    @param name       Ability key to wait for
    @param callback   Receives the LinkDef once available
--]]
function Linker.when(name: string, callback: (LinkDef) -> ())
	assert(type(name)     == "string",   "Linker.when: `name` must be a string")
	assert(type(callback) == "function", "Linker.when: `callback` must be a function")

	local link = _registry[name]
	if link then
		-- Already registered; fire now on a fresh thread so callers never block
		task.spawn(callback, link)
		return
	end

	-- Not yet registered; queue for when the producer loads
	if not _deferred[name] then
		_deferred[name] = {}
	end
	table.insert(_deferred[name], callback)
end

-- ── Utility ───────────────────────────────────────────────────────────────────

--[[
    Returns true if the ability has already registered a link.
    Useful for optional integrations ("use Punch data if available").
--]]
function Linker.has(name: string): boolean
	return _registry[name] ~= nil
end

--[[
    Remove a link from the registry.
    Intended for testing teardown or hot-reload scenarios — not normal gameplay.
--]]
function Linker.unregister(name: string)
	_registry[name] = nil
end

return Linker


