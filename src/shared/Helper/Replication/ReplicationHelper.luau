-- ReplicatedStorage/Shared/Replication/ReplicationHelper.lua
-- Helper module for replication logic to reduce complexity in ReplicationController

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local ConsequenceRouter = require(ReplicatedStorage.Shared.Helper.Replication.ConsequenceRouter)
local ReactionRegistry = require(ReplicatedStorage.Shared.Registration.Registries.ReactionRegistry)

local ReplicationHelper = {}

export type Role = "source" | "target" | "observer"

-- ─────────────────────────────────────────────────────────────────
-- ROLE DETERMINATION
-- ─────────────────────────────────────────────────────────────────

--- Determines what role this client plays in the reaction
function ReplicationHelper.determineRole(
	senderUserId: number,
	broadcastState: { [string]: any }?,
	localUserId: number
): Role
	if senderUserId == localUserId then
		return "source"
	end

	if broadcastState and broadcastState.isPlayer and broadcastState.targetKey == tostring(localUserId) then
		return "target"
	end

	return "observer"
end

-- ─────────────────────────────────────────────────────────────────
-- CONTEXT BUILDING
-- ─────────────────────────────────────────────────────────────────

--- Builds standard context for consequence routing
function ReplicationHelper.buildContext(
	senderUserId: number,
	state: { [string]: any }?,
	payload: { [string]: any }?
): { senderUserId: number, targetKey: string?, isPlayer: boolean?, targetCharacter: Model? }
	local s = state or {}
	local p = payload or {}
	return {
		senderUserId = senderUserId,
		targetKey = s.targetKey or p.targetKey,
		isPlayer = s.isPlayer ~= nil and s.isPlayer or p.isPlayer,
		targetCharacter = p.TargetCharacter,
	}
end

--- Builds reaction context for role-based callbacks
function ReplicationHelper.buildReactionContext(
	senderUserId: number,
	broadcastState: { [string]: any }?,
	payload: { [string]: any }?
): ReactionRegistry.ReactionContext
	local p = broadcastState or {}
	return {
		senderUserId = senderUserId,
		targetKey = p.targetKey or (payload and payload.targetKey),
		isPlayer = p.isPlayer ~= nil and p.isPlayer or (payload and payload.isPlayer),
		targetCharacter = p.targetCharacter,
		payload = p,
	}
end

-- ─────────────────────────────────────────────────────────────────
-- CONSEQUENCE PROCESSING
-- ─────────────────────────────────────────────────────────────────

--- Flushes consequences with smart role-based handling
-- Source players skip consequences (already predicted)
-- Others process normally
function ReplicationHelper.processConsequences(
	broadcastState: { [string]: any }?,
	ctx: { [string]: any },
	role: Role,
	isPrediction: boolean?
): boolean
	print("[ReplicationHelper] processConsequences")
	print("Role:", role)
	print("Prediction:", isPrediction)

	if not broadcastState then
		warn("[ReplicationHelper] No broadcastState")
		return true
	end

	local consequences = broadcastState.consequences

	if not consequences then
		warn("[ReplicationHelper] No consequences")
		return true
	end

	if #consequences == 0 then
		warn("[ReplicationHelper] Empty consequences")
		return true
	end

	-- Skip ONLY server-confirmed broadcast for source
	if role == "source" and not isPrediction then
		warn("[ReplicationHelper] Skipping broadcast consequences")
		return true
	end

	print("[ReplicationHelper] Flushing consequences")

	local success =
		ConsequenceRouter.flush(
			consequences,
			ctx
		)

	print("[ReplicationHelper] Result =", success)

	return success
end


-- ─────────────────────────────────────────────────────────────────
-- CALLBACK INVOCATION
-- ─────────────────────────────────────────────────────────────────

--- Invokes the appropriate role-based callback
function ReplicationHelper.invokeRoleCallback(
	handlers: { [string]: any },
	role: Role,
	reactionCtx: ReactionRegistry.ReactionContext,
	state: any
): boolean
	if role == "source" and handlers.onSource then
		handlers.onSource(reactionCtx, state)
		return true
	elseif role == "target" and handlers.onTarget then
		handlers.onTarget(reactionCtx, state)
		return true
	elseif role == "observer" and handlers.onObserver then
		handlers.onObserver(reactionCtx, state)
		return true
	end

	return false
end

-- ─────────────────────────────────────────────────────────────────
-- RECONCILIATION HANDLING
-- ─────────────────────────────────────────────────────────────────

--- Processes reconciliation for a reaction
function ReplicationHelper.processReconcile(
	handlers: { [string]: any },
	success: boolean,
	reconcileState: any,
	reason: string?,
	clientSeq: number
): boolean
	if not handlers.onReconcile then
		return false
	end

	if success then
		handlers.onReconcile(reconcileState, nil, clientSeq)
	else
		handlers.onReconcile(nil, reason, clientSeq)
	end

	return true
end

-- ─────────────────────────────────────────────────────────────────
-- HANDLER DETECTION
-- ─────────────────────────────────────────────────────────────────

--- Detects if a handler is a reaction (vs action)
function ReplicationHelper.isReaction(
	actionHandlers: any,
	reactionHandlers: any
): boolean
	return reactionHandlers ~= nil and actionHandlers == nil
end

--- Detects if a handler is an action (vs reaction)
function ReplicationHelper.isAction(
	actionHandlers: any,
	reactionHandlers: any
): boolean
	return actionHandlers ~= nil and reactionHandlers == nil
end

return ReplicationHelper