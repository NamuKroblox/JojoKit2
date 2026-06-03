--[[
	ReplicationController
	
	Manages client-server synchronization of ability execution.
	Responsibilities include:
	- Client-side prediction
	- Reconciliation of divergent state
	- Broadcasting events to server
	- Server-side validation and execution
]]

local ReplicationController = {}
ReplicationController.__index = ReplicationController

export type ReplicationConfig = {
	remoteEvent: RemoteEvent?,
	remoteFunction: RemoteFunction?,
}

function ReplicationController.new(config: ReplicationConfig?)
	local self = setmetatable({}, ReplicationController)
	
	config = config or {}
	self.remoteEvent = config.remoteEvent
	self.remoteFunction = config.remoteFunction
	
	self._pending: { [string]: any } = {}
	self._confirmed: { [string]: any } = {}
	
	return self
end

--[[
	Predict on client: Execute ability logic locally before server confirmation.
]]
function ReplicationController:predictClient(abilityName: string, controlUnit: any)
	controlUnit:predict()
	
	-- Store prediction state
	self._pending[abilityName] = {
		predictedAt = tick(),
		state = controlUnit.dataUnit.stateMemory:getStage("Predict"),
	}
end

--[[
	Send ability request to server for validation and execution.
]]
function ReplicationController:executeOnServer(abilityName: string, data: any?)
	if not self.remoteFunction then
		warn("ReplicationController: No RemoteFunction configured")
		return false
	end
	
	local success, result = pcall(function()
		return self.remoteFunction:InvokeServer("ExecuteAbility", abilityName, data)
	end)
	
	if not success then
		warn(`Failed to invoke ability {abilityName}: {result}`)
		return false
	end
	
	return result
end

--[[
	Reconcile client state with server authority.
]]
function ReplicationController:reconcile(abilityName: string, authorityState: any, controlUnit: any)
	local predicted = self._pending[abilityName]
	
	if not predicted then
		return
	end
	
	-- Compare states
	local isDiverged = self:_compareStates(predicted.state, authorityState)
	
	if isDiverged then
		-- Correct state memory
		for key, value in pairs(authorityState) do
			controlUnit.dataUnit.stateMemory:set("Reconcile", key, value)
		end
		
		-- Trigger reconciliation
		controlUnit:reconcile()
	end
	
	-- Move to confirmed
	self._confirmed[abilityName] = authorityState
	self._pending[abilityName] = nil
end

--[[
	Broadcast ability event to all clients.
]]
function ReplicationController:broadcast(abilityName: string, event: string, data: any?)
	if not self.remoteEvent then
		warn("ReplicationController: No RemoteEvent configured")
		return
	end
	
	self.remoteEvent:FireAllClients(abilityName, event, data)
end

--[[
	Internal: Compare two state objects for divergence.
]]
function ReplicationController:_compareStates(state1: { [string]: any }, state2: { [string]: any }): boolean
	for key, value in pairs(state1) do
		if state2[key] ~= value then
			return true
		end
	end
	
	for key in pairs(state2) do
		if state1[key] == nil then
			return true
		end
	end
	
	return false
end

return ReplicationController
