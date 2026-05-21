export type Def = {
	default: any,
	type: string?,
	validator: ((any) -> boolean)?,
}

export type Key = "InGame" | "CharacterAlive" | "StandEquipped"

local StateKeys = {
	InGame = "InGame",
	CharacterAlive = "CharacterAlive",
	StandEquipped = "StandEquipped",
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
}

local Meta = {
	StateKeys = StateKeys,
	StateDefs = StateDefs,
}

return Meta
