local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local Knit = require(game:GetService("ReplicatedStorage").Packages.knit)
local Registry = require(game:GetService("ReplicatedStorage").Shared.Modules.Replication.ReplicationRegistry)

local DISPATCH_TIMEOUT = 5
local MAX_PENDING_ACTIONS = 100

local ReplicationController = {
	Name = "ReplicationController",
}

local replicationService = nil
local sequenceCounter = 0
local pendingActions = {} -- [seq] = { actionType, sentAt, handlers }

local function nextSequence(): number
	sequenceCounter += 1
	return sequenceCounter
end

local function handleReconcile(
	actionType: string,
	clientSeq: number,
	success: boolean,
	resultState: any,
	reason: string?
)
	local pending = pendingActions[clientSeq]
	if not pending then
		return
	end

	local handlers = pending.handlers
	pendingActions[clientSeq] = nil

	if success then
		handlers.onReconcile(resultState, nil, clientSeq)
	else
		handlers.onReconcile(nil, reason, clientSeq)
	end
end

local function handleBroadcast(senderUserId: number, actionType: string, resultState: any)
	-- Ignore broadcasts from self
	if senderUserId == Players.LocalPlayer.UserId then
		return
	end

	local handler = Registry.get(actionType)
	if not handler then
		return
	end

	handler.onBroadcast(senderUserId, resultState)
end

function ReplicationController:KnitInit()
	replicationService = Knit.GetService("ReplicationService")
end

function ReplicationController:KnitStart()
	-- Listen for reconciliation responses
	replicationService.Reconcile:Connect(function(actionType, clientSeq, success, resultState, reason)
		handleReconcile(actionType, clientSeq, success, resultState, reason)
	end)

	-- Listen for broadcasts from other players
	replicationService.Broadcast:Connect(function(senderUserId, actionType, resultState)
		handleBroadcast(senderUserId, actionType, resultState)
	end)

	-- Timeout checker for pending actions
	RunService.Heartbeat:Connect(function()
		local now = os.clock()
		local toRemove = {}

		for seq, pending in pairs(pendingActions) do
			if (now - pending.sentAt) > DISPATCH_TIMEOUT then
				local handlers = pending.handlers
				handlers.onReconcile(nil, "timeout", seq)
				table.insert(toRemove, seq)
			end
		end

		for _, seq in ipairs(toRemove) do
			pendingActions[seq] = nil
		end
	end)
end

function ReplicationController:Predict(actionType: string, payload: any)
	local handler = Registry.get(actionType)
	if not handler then
		warn("[Replication] No handler for:", actionType)
		return false
	end

	-- Call client-side predict
	local ok = handler.onPredict(payload)
	return ok
end

function ReplicationController:Dispatch(actionType: string, payload: any)
	local handler = Registry.get(actionType)
	if not handler then
		warn("[Replication] No handler for:", actionType)
		return false
	end

	-- Client-side prediction first
	if not self:Predict(actionType, payload) then
		return false
	end

	-- Check max pending to prevent queue overflow
	if #pendingActions >= MAX_PENDING_ACTIONS then
		warn("[Replication] Too many pending actions")
		return false
	end

	-- Generate sequence and send to server
	local seq = nextSequence()
	pendingActions[seq] = {
		actionType = actionType,
		sentAt = os.clock(),
		handlers = handler,
	}

	replicationService:DispatchAction(actionType, payload, seq)
	return true
end

return ReplicationController
