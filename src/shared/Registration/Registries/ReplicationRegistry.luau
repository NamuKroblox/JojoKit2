local RunService  = game:GetService("RunService")
local IS_SERVER   = RunService:IsServer()
local RegistryManager = require(script.Parent.Parent.RegistryManager)

type ServerFields = {
	validate : (sender: Player, payload: any, seq: number) -> (boolean, string?),
	Execute  : (sender: Player, payload: any, seq: number) -> any,
}
type ClientFields = {
	onPredict   : (payload: any, seq: number) -> boolean,
	onReconcile : (state: any?, reason: string?, seq: number) -> (),
	onBroadcast : (senderUserId: number, state: any) -> (),
}
export type ServerHandler = ServerFields & { public: { [string]: (...any) -> ...any }? }
export type ClientHandler = ClientFields & { public: { [string]: (...any) -> ...any }? }
export type Handler = ServerHandler | ClientHandler

-- Usage: ReplicationRegistry:register(actionType, handler)
--        ReplicationRegistry:call(actionType, fnName, ...)
return RegistryManager.create({
	name        = "ReplicationRegistry",
	onDuplicate = "warn",

	validate = function(handler: any): (boolean, string?)
		if IS_SERVER then
			if type(handler.validate) ~= "function" then return false, "handler.validate required on server" end
			if type(handler.Execute)  ~= "function" then return false, "handler.Execute required on server"  end
		else
			if type(handler.onPredict)   ~= "function" then return false, "handler.onPredict required on client"   end
			if type(handler.onReconcile) ~= "function" then return false, "handler.onReconcile required on client" end
			if type(handler.onBroadcast) ~= "function" then return false, "handler.onBroadcast required on client" end
		end
		return true
	end,

	methods = {
		call = function(self, actionType: string, fnName: string, ...: any): ...any
			local handler = self:get(actionType)
			if not handler then
				warn("[ReplicationRegistry] No handler for:", actionType)
				return
			end
			if not handler.public then
				warn("[ReplicationRegistry] No public table on handler:", actionType)
				return
			end
			local fn = handler.public[fnName]
			if type(fn) ~= "function" then
				warn("[ReplicationRegistry] No public function:", actionType, "->", fnName)
				return
			end
			local packed = table.pack(pcall(fn, ...))
			if not packed[1] then
				warn("[ReplicationRegistry] pcall failed:", packed[2])
				return
			end
			table.remove(packed, 1)
			return table.unpack(packed, 1, packed.n - 1)
		end,
	},
})