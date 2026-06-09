local RunService  = game:GetService("RunService")
local IS_SERVER   = RunService:IsServer()
local RegistryManager = require(script.Parent.Parent.RegistryManager)

local MAX_ID_LEN = 64

export type ReactionContext = {
	senderUserId    : number,
	targetKey       : string?,
	isPlayer        : boolean?,
	targetCharacter : Model?,
	payload         : { [string]: any },
}
export type ServerReactionHandler = {
	validate : (sender: Player, payload: any, seq: number) -> (boolean, string?),
	Execute  : (sender: Player, payload: any, seq: number) -> any?,
}
export type ClientReactionHandler = {
	onPredict  : ((payload: any, seq: number) -> (boolean | { [string]: any }))?,
	onReconcile: (state: any?, reason: string?, seq: number) -> (),
	onSource   : ((ctx: ReactionContext, state: any) -> ())?,
	onTarget   : ((ctx: ReactionContext, state: any) -> ())?,
	onObserver : ((ctx: ReactionContext, state: any) -> ())?,
}

-- Usage: ReactionRegistry:register(id, handler)
return RegistryManager.create({
	name        = "ReactionRegistry",
	onDuplicate = "warn",

	keyValidator = function(key: string): (boolean, string?)
		if #key > MAX_ID_LEN then
			return false, ("id must be under %d chars"):format(MAX_ID_LEN)
		end
		return true
	end,

	validate = function(handler: any): (boolean, string?)
		if IS_SERVER then
			if type(handler.validate) ~= "function" then return false, "validate required on server" end
			if type(handler.Execute)  ~= "function" then return false, "Execute required on server"  end
		else
			if type(handler.onReconcile) ~= "function" then return false, "onReconcile required on client" end
		end
		return true
	end,
})