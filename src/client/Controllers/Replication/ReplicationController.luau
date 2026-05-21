-- ReplicationController (ModuleScript — StarterPlayerScripts/Controllers)
-- Replaces: OrderedActionBus

local Knit = require(game:GetService("ReplicatedStorage").Packages.knit)

local Registry = require(game:GetService("ReplicatedStorage").Shared.Modules.Replication.ReplicationRegistry)

local ReplicationController = { Name = "ReplicationController" }

local _service = nil
local seq = 0
local pendingAcks = {}

local function nextSeq()
	seq += 1
	return seq
end

function ReplicationController:KnitInit()
	_service = Knit.GetService("ReplicationService")
end

function ReplicationController:KnitStart()
	_service.Reconcile:Connect(function(actionType, reconcileState, clientSeq)
		pendingAcks[clientSeq] = nil

		local handlers = Registry.get(actionType)
		if not handlers then
			return
		end

		handlers.onReconcile(reconcileState)
	end)

	_service.Broadcast:Connect(function(senderUserId, actionType, payload, authoritativeState)
		local handlers = Registry.get(actionType)
		if not handlers then
			return
		end

		handlers.onBroadcast(senderUserId, payload, authoritativeState)
	end)
end

function ReplicationController:Dispatch(actionType, payload)
	local handlers = Registry.get(actionType)
	if not handlers then
		warn("ReplicationController: no handler for", actionType)
		return false
	end

	local s = nextSeq()
	pendingAcks[s] = actionType

	handlers.onPredict(payload)

	_service:DispatchAction(actionType, payload, s)

	return true
end

return ReplicationController
