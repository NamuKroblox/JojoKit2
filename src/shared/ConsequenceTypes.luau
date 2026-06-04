export type ConsequenceTarget = "attacker" | "victim" | "all"

export type StatusConsequence = {
	type: "status",
	target: ConsequenceTarget,
	id: string,
	duration: number?,
	data: { [string]: any }?,
}

export type PhysicsConsequence = {
	type: "physics",
	target: ConsequenceTarget,
	subtype: "knockback",
	data: {
		x: number,
		y: number,
		z: number,
		force: number,
		duration: number,
	},
}

export type EffectConsequence = {
	type: "effect",
	target: ConsequenceTarget,
	id: string,
	payload: { [string]: any }?,
}

export type Consequence = StatusConsequence | PhysicsConsequence | EffectConsequence

export type ConsequenceContext = {
	senderUserId: number,
	targetKey: string?,
	isPlayer: boolean?,
	targetCharacter: Model?,
}

return {}
