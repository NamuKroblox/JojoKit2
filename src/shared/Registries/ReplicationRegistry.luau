local RunService = game:GetService("RunService")
local IS_SERVER = RunService:IsServer()

type ServerFields = {
	validate: (sender: Player, payload: any, seq: number) -> (boolean, string?),
	Execute: (sender: Player, payload: any, seq: number) -> any,
}

type ClientFields = {
	onPredict: (payload: any, seq: number) -> boolean,
	onReconcile: (state: any?, reason: string?, seq: number) -> (),
	onBroadcast: (senderUserId: number, state: any) -> (),
}

-- Define handler unions so server and client registrations are type-safe
type ServerHandler = ServerFields & { public: { [string]: (...any) -> ...any }? }
type ClientHandler = ClientFields & { public: { [string]: (...any) -> ...any }? }

type Handler = ServerHandler | ClientHandler

local registry: { [string]: Handler } = {}

local ReplicationRegistry = {}

function ReplicationRegistry.register(actionType: string, handler: Handler)
	assert(type(actionType) == "string" and #actionType > 0, "actionType must be a non-empty string")
	if IS_SERVER then
		local serverHandler = handler :: any
		assert(type(serverHandler.validate) == "function", "handler.validate required on server")
		assert(type(serverHandler.Execute) == "function", "handler.Execute required on server")
	else
		local clientHandler = handler :: any
		assert(type(clientHandler.onPredict) == "function", "handler.onPredict required on client")
		assert(type(clientHandler.onReconcile) == "function", "handler.onReconcile required on client")
		assert(type(clientHandler.onBroadcast) == "function", "handler.onBroadcast required on client")
	end
	registry[actionType] = handler
end

function ReplicationRegistry.get(actionType: string): Handler?
	return registry[actionType]
end

function ReplicationRegistry.call(actionType: string, fnName: string, ...: any): ...any
	print("[ReplicationRegistry] call invoked")
	print("[ReplicationRegistry] actionType:", actionType)
	print("[ReplicationRegistry] fnName:", fnName)

	local handler = registry[actionType]

	if not handler then
		warn("[ReplicationRegistry] No handler found for:", actionType)
		return
	end

	print("[ReplicationRegistry] Handler found")

	if not handler.public then
		warn("[ReplicationRegistry] Handler has no public table:", actionType)
		return
	end

	print("[ReplicationRegistry] Public table found")

	local fn = handler.public[fnName]

	if type(fn) ~= "function" then
		warn("[ReplicationRegistry] No public function:", actionType, "->", fnName)

		print("[ReplicationRegistry] Existing public entries:")

		for key, value in handler.public do
			print("  ", key, typeof(value))
		end

		return
	end

	print("[ReplicationRegistry] Function found, executing")

	local packed = table.pack(pcall(fn, ...))

	if not packed[1] then
		warn("[ReplicationRegistry] Function execution failed:", packed[2])
		return
	end

	table.remove(packed, 1) -- remove success flag

	print("[ReplicationRegistry] Function executed successfully")

	return table.unpack(packed)
end

return ReplicationRegistry
