export type EffectPerspective = "self" | "attacker" | "observer"

export type EffectPayload = {
	targetKey: string?,
	isPlayer: boolean?,
	standName: string?,
	combo: number?,
	duration: number?,
	cframe: CFrame?,
	[string]: any,
}

export type EffectDef = {
	id: string,
	perspectives: { EffectPerspective }?,
	play: (payload: EffectPayload, perspective: EffectPerspective) -> (() -> ())?,
}

local registry: { [string]: EffectDef } = {}

local EffectRegistry = {}

function EffectRegistry.register(def: EffectDef)
	if registry[def.id] then
		warn("[EffectRegistry] Duplicate effect id:", def.id, "— overwriting")
	end
	registry[def.id] = def
end

function EffectRegistry.get(id: string): EffectDef?
	return registry[id]
end

return EffectRegistry
