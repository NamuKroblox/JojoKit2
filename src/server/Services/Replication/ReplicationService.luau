-- ReplicationService (Server)
-- Authoritative action dispatcher with rate limiting, validation, and replication
-- Handles dispatch queuing, reconciliation, and broadcasting to all clients

local RunService = game:GetService("RunService")
local Knit = require(game:GetService("ReplicatedStorage").Packages.knit)
local Registry = require(game:GetService("ReplicatedStorage").Shared.Modules.Replication.ReplicationRegistry)

local DISPATCH_RATE_LIMIT = 60 -- actions per heartbeat per player
local MAX_SEQUENCE = 1e6
local MAX_ACTION_NAME_LEN = 64

local ReplicationService = {
	Name = "ReplicationService",
	Client = {
		Reconcile = Knit.CreateSignal(),
		Broadcast = Knit.CreateSignal(),
	},
}

local dispatchCounts = {} -- [userId] = count; cleared each heartbeat

function ReplicationService:KnitInit()
	RunService.Heartbeat:Connect(function()
		table.clear(dispatchCounts)
	end)
end

-- Validate incoming action dispatch
local function validateDispatch(actionType: string, clientSeq: number): (boolean, string?)
	if type(actionType) ~= "string" or #actionType == 0 or #actionType > MAX_ACTION_NAME_LEN then
		return false, "invalid_action_type"
	end

	if type(clientSeq) ~= "number" or clientSeq <= 0 or clientSeq > MAX_SEQUENCE then
		return false, "invalid_sequence"
	end

	return true, nil
end

function ReplicationService.Client:DispatchAction(sender: Player, actionType: string, payload: any, clientSeq: number)
	-- Validate basic dispatch parameters
	local validParams, paramErr = validateDispatch(actionType, clientSeq)
	if not validParams then
		warn("[Replication] Invalid dispatch:", paramErr, "from", sender.Name)
		return
	end

	-- Rate limit per player
	local userId = sender.UserId
	dispatchCounts[userId] = (dispatchCounts[userId] or 0) + 1
	if dispatchCounts[userId] > DISPATCH_RATE_LIMIT then
		warn("[Replication] Rate limit exceeded:", sender.Name)
		self.Reconcile:Fire(sender, actionType, clientSeq, false, nil, "rate_limit")
		return
	end

	-- Get action handler
	local handler = Registry.get(actionType)
	if not handler then
		warn("[Replication] Unknown action:", actionType)
		self.Reconcile:Fire(sender, actionType, clientSeq, false, nil, "unknown_action")
		return
	end

	-- Validate action on server
	local valid, validErr = handler.validate(sender, payload, clientSeq)
	if not valid then
		self.Reconcile:Fire(sender, actionType, clientSeq, false, nil, validErr)
		return
	end

	-- Execute action and get result state
	local resultState = handler.Execute(sender, payload, clientSeq)

	-- Send reconciliation to sender
	self.Reconcile:Fire(sender, actionType, clientSeq, true, resultState, nil)

	-- Broadcast result to all other players
	self.Broadcast:FireAll(userId, actionType, resultState)
end

return ReplicationService
