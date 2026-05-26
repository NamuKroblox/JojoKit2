local RunService = game:GetService("RunService")
local Knit = require(game:GetService("ReplicatedStorage").Packages.knit)
local Registry = require(game:GetService("ReplicatedStorage").Shared.Modules.Replication.ReplicationRegistry)

local GLOBAL_RATE = 60
local MAX_SEQ = 1e6
local MAX_ACTION_LEN = 64

local ReplicationService = {
	Name = "ReplicationService",
	Client = {
		Reconcile = Knit.CreateSignal(),
		Broadcast = Knit.CreateSignal(),
	},
}

local dispatchCount = {} -- keyed by userId

function ReplicationService:KnitInit()
	RunService.Heartbeat:Connect(function()
		table.clear(dispatchCount)
	end)
end

function ReplicationService.Client:DispatchAction(
	sender: Player,
	actionType: string,
	payload: any,
	clientSeq: number
): boolean?
	if type(actionType) ~= "string" or #actionType == 0 or #actionType > MAX_ACTION_LEN then
		return false
	end

	if type(clientSeq) ~= "number" or clientSeq <= 0 or clientSeq > MAX_SEQ then
		return false
	end

	local userId = sender and sender.UserId
	if not userId then
		return false
	end

	dispatchCount[userId] = (dispatchCount[userId] or 0) + 1
	if dispatchCount[userId] > GLOBAL_RATE then
		warn("[Replication] Rate limit:", sender.Name)
		return false
	end

	local handlers = Registry.get(actionType)
	if not handlers then
		warn("[Replication] No handler for:", actionType)
		return false
	end

	local ok, reason = handlers.validate(sender, payload, clientSeq)
	if not ok then
		self.Reconcile:Fire(sender, actionType, clientSeq, false, nil, reason)
		return false
	end

	local broadcastState = handlers.Execute(sender, payload, clientSeq)
	self.Reconcile:Fire(sender, actionType, clientSeq, true, broadcastState, nil)
	self.Broadcast:FireAll(sender.UserId, actionType, broadcastState)

	return true
end

return ReplicationService
