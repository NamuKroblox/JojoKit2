local RegistryManager = require(script.Parent.Parent.RegistryManager)

export type StatusDef = {
	id             : string,
	layer          : number,
	stackable      : boolean,
	predictable    : boolean,
	blockedActions : { [string]: boolean }?,
	onApply        : ((player: Player, data: { [string]: any }) -> ())?,
	onRemove       : ((player: Player, data: { [string]: any }) -> ())?,
	onApplyClient  : ((player: Player, data: { [string]: any }) -> ())?,
	onRemoveClient : ((player: Player, data: { [string]: any }) -> ())?,
}

return RegistryManager.create({
	name        = "StatusRegistry",
	onDuplicate = "warn",
	-- keyExtractor defaults to entry.id ✓
})