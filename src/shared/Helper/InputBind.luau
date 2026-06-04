local InputBind = {}

local UIS = game:GetService("UserInputService")
local Players = game:GetService("Players")

local player = Players.LocalPlayer

type InputToken = Enum.KeyCode | Enum.UserInputType

type BindingEntry = {
	input: InputToken,
	handler: () -> (),
}

type RegistryEntry = {
	action: string,
	fn: () -> (),
}

type Factory = () -> () -> ()
type Scope = "permanent" | "character"

local downRegistry: { [string]: { RegistryEntry } } = {}
local upRegistry: { [string]: { RegistryEntry } } = {}

local heldActive: { [string]: boolean } = {}

local factories: { Factory } = {}
local currentCleanups: { () -> () } = {}

local function getInputId(input: InputToken): string
	return tostring(input.EnumType) .. ":" .. tostring(input.Value)
end

local function resolveInput(inputObject: InputObject): string?
	if inputObject.KeyCode ~= Enum.KeyCode.Unknown then
		return getInputId(inputObject.KeyCode)
	end

	return getInputId(inputObject.UserInputType)
end

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

local function register(registry: { [string]: { RegistryEntry } }, input: InputToken, action: string, fn: () -> ())
	local id = getInputId(input)

	registry[id] = registry[id] or {}

	table.insert(registry[id], {
		action = action,
		fn = fn,
	})
end

local function unregister(registry: { [string]: { RegistryEntry } }, input: InputToken, action: string)
	local id = getInputId(input)

	local list = registry[id]

	if not list then
		return
	end

	for i = #list, 1, -1 do
		if list[i].action == action then
			table.remove(list, i)
		end
	end

	if #list == 0 then
		registry[id] = nil
	end
end

local function bindWithScope(scope: Scope, factory: Factory): () -> ()
	if scope == "character" then
		table.insert(factories, factory)

		if player.Character then
			table.insert(currentCleanups, factory())
		end

		return function()
			for i = #factories, 1, -1 do
				if factories[i] == factory then
					table.remove(factories, i)
				end
			end
		end
	end

	return factory()
end

local beganConn = UIS.InputBegan:Connect(function(input, processed)
	if processed then
		return
	end

	local id = resolveInput(input)

	if not id then
		return
	end

	local list = downRegistry[id]

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
	local id = resolveInput(input)

	if not id then
		return
	end

	local list = upRegistry[id]

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

function InputBind.input(action: string, input: InputToken, handler: () -> (), scope: Scope?): () -> ()
	return bindWithScope(scope or "permanent", function()
		register(downRegistry, input, action, handler)

		return function()
			unregister(downRegistry, input, action)
		end
	end)
end

function InputBind.inputs(bindings: { [string]: BindingEntry }, scope: Scope?): () -> ()
	return bindWithScope(scope or "permanent", function()
		local cleanups = {}

		for action, entry in pairs(bindings) do
			register(downRegistry, entry.input, action, entry.handler)

			table.insert(cleanups, function()
				unregister(downRegistry, entry.input, action)
			end)
		end

		return safeCleanup(cleanups)
	end)
end

function InputBind.held(action: string, input: InputToken, onDown: () -> (), onUp: () -> (), scope: Scope?): () -> ()
	return bindWithScope(scope or "permanent", function()
		register(downRegistry, input, action, function()
			heldActive[action] = true
			onDown()
		end)

		register(upRegistry, input, action, onUp)

		return safeCleanup({
			function()
				unregister(downRegistry, input, action)
			end,

			function()
				unregister(upRegistry, input, action)
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
