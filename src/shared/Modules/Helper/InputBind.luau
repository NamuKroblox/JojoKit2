-- InputBind.lua
-- Public face: one module, one require.
-- Internally delegates character lifecycle to a private scope manager
-- so responsibilities stay separated without burdening the caller.

local InputBind = {}
local UIS = game:GetService("UserInputService")
local Players = game:GetService("Players")
local player = Players.LocalPlayer

type BindingEntry = { key: Enum.KeyCode, handler: () -> () }
type RegistryEntry = { action: string, fn: () -> () }
type Factory = () -> () -> ()

local downRegistry: { [number]: { RegistryEntry } } = {}
local upRegistry: { [number]: { RegistryEntry } } = {}
local heldActive: { [string]: boolean } = {}

-- ── private scope manager ────────────────────────────────────────────────────
-- This is CharacterScope, but private. The caller never touches it.
-- It manages the factory/cleanup lifecycle for character-scoped bindings.

local factories: { Factory } = {}
local currentCleanups: { () -> () } = {}

local function teardown()
	for _, cleanup in currentCleanups do
		pcall(cleanup)
	end
	table.clear(currentCleanups)
end

local function rebuild()
	teardown()
	for _, factory in factories do
		table.insert(currentCleanups, factory())
	end
end

player.CharacterAdded:Connect(rebuild)
player.CharacterRemoving:Connect(teardown)

if player.Character then
	rebuild()
end

-- ── shared internals ─────────────────────────────────────────────────────────

local function safeCleanup(fns: { () -> () }): () -> ()
	local done = false
	return function()
		if done then
			return
		end
		done = true
		for _, fn in fns do
			local ok, err = pcall(fn)
			if not ok then
				warn("[InputBind] cleanup error:", err)
			end
		end
	end
end

local function register(registry: { [number]: { RegistryEntry } }, keyCode: Enum.KeyCode, action: string, fn: () -> ())
	local code = keyCode.Value
	if not registry[code] then
		registry[code] = {}
	end
	table.insert(registry[code], { action = action, fn = fn })
end

local function unregister(registry: { [number]: { RegistryEntry } }, keyCode: Enum.KeyCode, action: string)
	local code = keyCode.Value
	local list = registry[code]
	if not list then
		return
	end
	for i = #list, 1, -1 do
		if list[i].action == action then
			table.remove(list, i)
		end
	end
end

local beganConn = UIS.InputBegan:Connect(function(input, processed)
	if processed then
		return
	end
	local list = downRegistry[input.KeyCode.Value]
	if not list then
		return
	end
	for _, entry in list do
		local ok, err = pcall(entry.fn)
		if not ok then
			warn("[InputBind] handler error in", entry.action, ":", err)
		end
	end
end)

local endedConn = UIS.InputEnded:Connect(function(input)
	local list = upRegistry[input.KeyCode.Value]
	if not list then
		return
	end
	for _, entry in list do
		if heldActive[entry.action] then
			heldActive[entry.action] = false
			local ok, err = pcall(entry.fn)
			if not ok then
				warn("[InputBind] handler error in", entry.action, ":", err)
			end
		end
	end
end)

-- ── internal registration with optional character scope ──────────────────────
-- When scope is "character", the factory is stored and replayed each respawn.
-- When scope is "permanent" (or omitted), the binding runs once and stays.

type Scope = "permanent" | "character"

local function bindWithScope(scope: Scope, factory: Factory): () -> ()
	if scope == "character" then
		table.insert(factories, factory)
		-- Run immediately if a character is already alive.
		if player.Character then
			table.insert(currentCleanups, factory())
		end
		-- Cancellation removes the factory so it won't replay on future spawns.
		return function()
			for i = #factories, 1, -1 do
				if factories[i] == factory then
					table.remove(factories, i)
				end
			end
		end
	else
		return factory()
	end
end

-- ── public API ───────────────────────────────────────────────────────────────
-- scope is optional and defaults to "permanent" so existing call sites
-- that don't care about lifecycle don't need to change at all.

function InputBind.key(action: string, keyCode: Enum.KeyCode, handler: () -> (), scope: Scope?): () -> ()
	return bindWithScope(scope or "permanent", function()
		register(downRegistry, keyCode, action, handler)
		return function()
			unregister(downRegistry, keyCode, action)
		end
	end)
end

function InputBind.keys(bindings: { [string]: BindingEntry }, scope: Scope?): () -> ()
	return bindWithScope(scope or "permanent", function()
		local cleanups = {}
		for action, entry in pairs(bindings) do
			register(downRegistry, entry.key, action, entry.handler)
			table.insert(cleanups, function()
				unregister(downRegistry, entry.key, action)
			end)
		end
		return safeCleanup(cleanups)
	end)
end

function InputBind.held(
	action: string,
	keyCode: Enum.KeyCode,
	onDown: () -> (),
	onUp: () -> (),
	scope: Scope?
): () -> ()
	return bindWithScope(scope or "permanent", function()
		register(downRegistry, keyCode, action, function()
			heldActive[action] = true
			onDown()
		end)
		register(upRegistry, keyCode, action, onUp)
		return safeCleanup({
			function()
				unregister(downRegistry, keyCode, action)
			end,
			function()
				unregister(upRegistry, keyCode, action)
			end,
			function()
				heldActive[action] = nil
			end,
		})
	end)
end

function InputBind.destroy()
	teardown()
	beganConn:Disconnect()
	endedConn:Disconnect()
	table.clear(downRegistry)
	table.clear(upRegistry)
	table.clear(heldActive)
	table.clear(factories)
end

return InputBind
