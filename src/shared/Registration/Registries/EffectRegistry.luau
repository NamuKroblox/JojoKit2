local RegistryManager = require(script.Parent.Parent.RegistryManager)

export type EffectPerspective = "self" | "attacker" | "observer"
export type EffectPayload = {
	targetKey : string?,
	isPlayer  : boolean?,
	standName : string?,
	combo     : number?,
	duration  : number?,
	cframe    : CFrame?,
	[string]  : any,
}
export type EffectDef = {
	id           : string,
	perspectives : { EffectPerspective }?,
	play         : (payload: EffectPayload, perspective: EffectPerspective) -> (() -> ())?,
}

return RegistryManager.create({
	name        = "EffectRegistry",
	onDuplicate = "warn",
})