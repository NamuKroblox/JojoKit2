export type InputContext = "character" | "menu" | "cutscene" | "any"

export type InputMode = "press" | "hold"

export type InputBinding = {
	id: string,
	input: Enum.KeyCode | Enum.UserInputType,
	action: string,

	releaseAction: string?,

	mode: InputMode?,

	context: InputContext,
	priority: number,

	guard: (() -> boolean)?,
	payload: (() -> { [string]: any })?,
	releasePayload: (() -> { [string]: any })?,

	scope: "permanent" | "character"?,
}

local registry: { [string]: InputBinding } = {}
local byInput: { [string]: { InputBinding } } = {}
local sorted: { [string]: boolean } = {}

local InputRegistry = {}

local function inputKey(input: Enum.KeyCode | Enum.UserInputType): string
	return tostring(input)
end

function InputRegistry.register(binding: InputBinding)
	if registry[binding.id] then
		warn("[InputRegistry] Duplicate binding id:", binding.id, "— overwriting")
		InputRegistry.unregister(binding.id)
	end

	registry[binding.id] = binding

	local key = inputKey(binding.input)
	if not byInput[key] then
		byInput[key] = {}
	end
	table.insert(byInput[key], binding)
	sorted[key] = false

	return function()
		InputRegistry.unregister(binding.id)
	end
end

function InputRegistry.unregister(id: string)
	local binding = registry[id]
	if not binding then
		return
	end

	registry[id] = nil

	local key = inputKey(binding.input)
	local list = byInput[key]
	if not list then
		return
	end

	for i, b in list do
		if b.id == id then
			table.remove(list, i)
			break
		end
	end
end

function InputRegistry.resolve(input: Enum.KeyCode | Enum.UserInputType, context: InputContext): InputBinding?
	local key = inputKey(input)
	local list = byInput[key]
	if not list or #list == 0 then
		return nil
	end

	if not sorted[key] then
		table.sort(list, function(a, b)
			if a.priority == b.priority then
				return a.id < b.id
			end
			return a.priority > b.priority
		end)
		sorted[key] = true
	end

	for _, binding in list do
		if binding.context ~= "any" and binding.context ~= context then
			continue
		end
		if binding.guard and not binding.guard() then
			continue
		end
		return binding
	end

	return nil
end

function InputRegistry.getAll(): { [string]: InputBinding }
	return registry
end

return InputRegistry
