export type StatusDef = {
	id: string,
	layer: number,
	stackable: boolean,
	predictable: boolean,
	blockedActions: { [string]: boolean }?,
	onApply: ((player: Player, data: { [string]: any }) -> ())?,
	onRemove: ((player: Player, data: { [string]: any }) -> ())?,
	onApplyClient: ((player: Player, data: { [string]: any }) -> ())?,
	onRemoveClient: ((player: Player, data: { [string]: any }) -> ())?,
}

local registry: { [string]: StatusDef } = {}

local StatusRegistry = {}

function StatusRegistry.register(def: StatusDef)
	if registry[def.id] then
		warn("[StatusRegistry] Duplicate status id:", def.id, "— overwriting")
	end
	registry[def.id] = def
end

function StatusRegistry.get(id: string): StatusDef?
	return registry[id]
end

return StatusRegistry
