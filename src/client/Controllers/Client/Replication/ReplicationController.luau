-- ReplicatedStorage/Shared/Replication/ReplicationController.lua
-- Client-side controller for managing action/reaction dispatch and reconciliation
-- Uses ReplicationHelper for cleaner separation of concerns

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Knit = require(ReplicatedStorage.Packages.knit)

local ReplicaionRegistry = require(ReplicatedStorage.Shared.Registration.Registries.ReplicationRegistry)
local ReactionRegistry = require(ReplicatedStorage.Shared.Registration.Registries.ReactionRegistry)
local ReplicationHelper = require(ReplicatedStorage.Shared.Helper.Replication.ReplicationHelper)

local PENDING_TIMEOUT = 5

local ReplicationController = { Name = "ReplicationController" }

local ReplicationService
local seq = 0
local pendingAcks = {}

-- ─────────────────────────────────────────────────────────────────
-- INITIALIZATION
-- ─────────────────────────────────────────────────────────────────

function ReplicationController:KnitInit()
	ReplicationService = Knit.GetService("ReplicationService")
end

-- ─────────────────────────────────────────────────────────────────
-- SIGNAL CONNECTIONS
-- ─────────────────────────────────────────────────────────────────

function ReplicationController:KnitStart()
	self:_connectReconcile()
	self:_connectBroadcast()
	self:_connectCleanup()
end

function ReplicationController:_connectReconcile()
	ReplicationService.Reconcile:Connect(function(handlerType, clientSeq, success, reconcileState, reason)
		local entry = pendingAcks[clientSeq]
		pendingAcks[clientSeq] = nil

		if not entry then
			return
		end

		local kind = entry.kind
		local registry = kind == "reaction" and ReactionRegistry or ReplicaionRegistry
		local handlers = registry:get(handlerType)

		if not handlers then
			warn("[ReplicationController] No handlers for:", handlerType, "kind:", kind)
			return
		end

		if handlers.onReconcile then
			ReplicationHelper.processReconcile(handlers, success, reconcileState, reason, clientSeq)
		end
	end)
end

function ReplicationController:_connectBroadcast()
	ReplicationService.Broadcast:Connect(function(senderUserId, handlerType, broadcastState, payload)
		local actionHandlers = ReplicaionRegistry:get(handlerType)
		local reactionHandlers = ReactionRegistry:get(handlerType)

		-- Handle actions
		if ReplicationHelper.isAction(actionHandlers, reactionHandlers) then
			if senderUserId == Players.LocalPlayer.UserId then
				return -- We predicted already
			end
			if actionHandlers.onBroadcast then
				actionHandlers.onBroadcast(senderUserId, broadcastState, payload)
			end
		end

		-- Handle reactions
		if ReplicationHelper.isReaction(actionHandlers, reactionHandlers) then
			self:_processReactionBroadcast(senderUserId, handlerType, broadcastState, payload, reactionHandlers)
		end
	end)
end

function ReplicationController:_connectCleanup()
	RunService.Heartbeat:Connect(function()
		local now = os.clock()
		for s, entry in pendingAcks do
			if now - entry.sentAt > PENDING_TIMEOUT then
				pendingAcks[s] = nil
			end
		end
	end)
end

-- ─────────────────────────────────────────────────────────────────
-- REACTION BROADCAST PROCESSING
-- ─────────────────────────────────────────────────────────────────

function ReplicationController:_processReactionBroadcast(
	senderUserId: number,
	handlerType: string,
	broadcastState: { [string]: any },
	payload: { [string]: any },
	reactionHandlers: any
)
	-- Build contexts
	local ctx = ReplicationHelper.buildContext(senderUserId, broadcastState, payload)
	local localUserId = Players.LocalPlayer.UserId
	local role = ReplicationHelper.determineRole(senderUserId, broadcastState, localUserId)

	-- Process consequences (smart role-based handling)
	ReplicationHelper.processConsequences(broadcastState, ctx, role)

	-- Build and invoke role-based callback
	local reactionCtx = ReplicationHelper.buildReactionContext(senderUserId, broadcastState, payload)
	ReplicationHelper.invokeRoleCallback(reactionHandlers, role, reactionCtx, broadcastState)
end

-- ─────────────────────────────────────────────────────────────────
-- DISPATCH LOGIC
-- ─────────────────────────────────────────────────────────────────

local function nextSeq(): number
	seq += 1
	return seq
end

local function dispatch(self, kind: string, id: string, payload: any): boolean
	local registry = kind == "reaction" and ReactionRegistry or ReplicaionRegistry
	local handlers = registry:get(id)

	if not handlers then
		warn("[ReplicationController] No handler:", id)
		return false
	end

	local s = nextSeq()

	-- Try to predict
	local predictedState = handlers.onPredict and handlers.onPredict(payload, s)

	if predictedState == false then
		return false
	end

	-- Flush predicted consequences
	if type(predictedState) == "table" then
		local ctx = ReplicationHelper.buildContext(Players.LocalPlayer.UserId, predictedState, payload)
		local predicted = table.clone(predictedState)

		if predicted.consequences then
			for _, consequence in predicted.consequences do
				consequence.clientSeq = s
			end
		end

		ReplicationHelper.processConsequences(predicted, ctx, "source", true)
	end

	-- Record pending
	pendingAcks[s] = {
		action = id,
		sentAt = os.clock(),
		kind = kind,
	}

	-- Send to server
	if kind == "reaction" then
		ReplicationService:DispatchReaction(id, payload, s)
	else
		ReplicationService:DispatchAction(id, payload, s)
	end

	return true
end

-- ─────────────────────────────────────────────────────────────────
-- PUBLIC API
-- ─────────────────────────────────────────────────────────────────

function ReplicationController:Dispatch(actionType: string, payload: any): boolean
	return dispatch(self, "action", actionType, payload)
end

function ReplicationController:DispatchReaction(reactionId: string, payload: any): boolean
	return dispatch(self, "reaction", reactionId, payload)
end

function ReplicationController:Call(actionType: string, fnName: string, ...: any): ...any
	return ReplicaionRegistry:call(actionType, fnName, ...)
end

return ReplicationController
