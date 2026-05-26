export type Def = {
	default: any,
	type: string?,
	validator: ((any) -> boolean)?,
}

export type Key =
	"InGame"
	| "CharacterAlive"
	| "StandEquipped"
	| "Stunned"
	| "Punching"
	| "Combo"
	| "LastPunch"
	| "AttackId"
	| "Sprinting"

local StateKeys = {
	InGame = "InGame",
	CharacterAlive = "CharacterAlive",
	StandEquipped = "StandEquipped",
	Stunned = "Stunned",
	Punching = "Punching",
	Combo = "Combo",
	LastPunch = "LastPunch",
	AttackId = "AttackId",
	Sprinting = "Sprinting",
}

local StateDefs: { [Key]: Def } = {
	[StateKeys.InGame] = {
		default = false,
		type = "boolean",
	},

	[StateKeys.CharacterAlive] = {
		default = false,
		type = "boolean",
	},

	[StateKeys.StandEquipped] = {
		default = false,
		type = "boolean",
	},

	[StateKeys.Stunned] = {
		default = false,
		type = "boolean",
	},

	[StateKeys.Punching] = {
		default = false,
		type = "boolean",
	},

	[StateKeys.Combo] = {
		default = 0,
		type = "number",
	},

	[StateKeys.LastPunch] = {
		default = 0,
		type = "number",
	},

	[StateKeys.AttackId] = {
		default = 0,
		type = "number",
	},

	[StateKeys.Sprinting] = {
		default = false,
		type = "boolean",
	},
}

local Meta = {
	StateKeys = StateKeys,
	StateDefs = StateDefs,
}

return Meta
