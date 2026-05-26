local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local Knit = require(game:GetService("ReplicatedStorage").Packages.knit)
local Registry = require(game:GetService("ReplicatedStorage").Shared.Modules.Replication.ReplicationRegistry)

local PENDING_TIMEOUT = 5

local ReplicationController = { Name = "ReplicationController" }

local ReplicationService
local seq = 0
local pendingAcks = {}

local function nextSeq()
	seq += 1
	return seq
end

function ReplicationController:KnitInit()
	ReplicationService = Knit.GetService("ReplicationService")
end

function ReplicationController:KnitStart()
	ReplicationService.Reconcile:Connect(function(actionType, clientSeq, success, reconcileState, reason)
		pendingAcks[clientSeq] = nil
		local handlers = Registry.get(actionType)
		if not handlers then
			return
		end
		if success then
			handlers.onReconcile(reconcileState, nil, clientSeq)
		else
			handlers.onReconcile(nil, reason, clientSeq)
		end
	end)

	ReplicationService.Broadcast:Connect(function(senderUserId, actionType, broadcastState)
		if senderUserId == Players.LocalPlayer.UserId then
			return
		end
		local handlers = Registry.get(actionType)
		if not handlers then
			return
		end
		handlers.onBroadcast(senderUserId, broadcastState)
	end)

	RunService.Heartbeat:Connect(function()
		local now = os.clock()
		for s, entry in pendingAcks do
			if (now - entry.sentAt) > PENDING_TIMEOUT then
				warn("[Replication] Timeout seq", s, entry.action)
				local handlers = Registry.get(entry.action)
				if handlers then
					handlers.onReconcile(nil, "timeout", s)
				end
				pendingAcks[s] = nil
			end
		end
	end)
end

function ReplicationController:Dispatch(actionType: string, payload: any): boolean
	local handlers = Registry.get(actionType)
	if not handlers then
		warn("[Replication] No handler for:", actionType)
		return false
	end
	local s = nextSeq()
	local success = handlers.onPredict(payload, s)
	if not success then
		return false
	end
	pendingAcks[s] = { action = actionType, sentAt = os.clock() }
	ReplicationService:DispatchAction(actionType, payload, s)
	return true
end

function ReplicationController:Call(actionType: string, fnName: string, ...: any): ...any
	return Registry.call(actionType, fnName, ...)
end

return ReplicationController
