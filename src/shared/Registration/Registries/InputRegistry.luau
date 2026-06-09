local RegistryManager = require(script.Parent.Parent.RegistryManager)

export type InputContext  = "character" | "menu" | "cutscene" | "any"
export type InputMode    = "press" | "hold"
export type InputBinding = {
	id             : string,
	input          : Enum.KeyCode | Enum.UserInputType,
	action         : string,
	releaseAction  : string?,
	mode           : InputMode?,
	context        : InputContext,
	priority       : number,
	guard          : (() -> boolean)?,
	payload        : (() -> { [string]: any })?,
	releasePayload : (() -> { [string]: any })?,
	scope          : ("permanent" | "character")?,
}

local function inputKey(input: Enum.KeyCode | Enum.UserInputType): string
	return tostring(input)
end

return RegistryManager.create({
	name        = "InputRegistry",
	onDuplicate = "warn",

	onRegister = function(registry: any, _key: string, binding: InputBinding)
		local store = registry._store
		store.byInput = store.byInput or {}
		store.sorted  = store.sorted  or {}
		local iKey = inputKey(binding.input)
		store.byInput[iKey] = store.byInput[iKey] or {}
		table.insert(store.byInput[iKey], binding)
		store.sorted[iKey] = false
	end,

	onUnregister = function(registry: any, key: string, binding: InputBinding)
		local byInput = registry._store.byInput
		if not byInput then return end
		local list = byInput[inputKey(binding.input)]
		if not list then return end
		for i, b in list do
			if b.id == key then table.remove(list, i) break end
		end
	end,

	methods = {
		resolve = function(
			self    : any,
			input   : Enum.KeyCode | Enum.UserInputType,
			context : InputContext
		): InputBinding?
			local store = self._store
			local iKey  = inputKey(input)
			local list  = store.byInput and store.byInput[iKey]
			if not list or #list == 0 then return nil end

			if not store.sorted[iKey] then
				table.sort(list, function(a, b)
					return if a.priority == b.priority then a.id < b.id else a.priority > b.priority
				end)
				store.sorted[iKey] = true
			end

			for _, binding in list do
				if binding.context ~= "any" and binding.context ~= context then continue end
				if binding.guard and not binding.guard() then continue end
				return binding
			end
			return nil
		end,
	},
})