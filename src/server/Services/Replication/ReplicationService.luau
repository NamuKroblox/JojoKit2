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

function ReplicationService.Client:DispatchAction(sender, actionType, payload, clientSeq)
	if type(actionType) ~= "string" or #actionType == 0 or #actionType > MAX_ACTION_LEN then
		return
	end

	if type(clientSeq) ~= "number" or clientSeq <= 0 or clientSeq > MAX_SEQ then
		return
	end

	local userId = sender and sender.UserId
	if not userId then
		return
	end

	dispatchCount[userId] = (dispatchCount[userId] or 0) + 1
	if dispatchCount[userId] > GLOBAL_RATE then
		warn("[Replication] Rate limit:", sender.Name)
		return
	end

	local handlers = Registry.get(actionType)
	if not handlers then
		warn("[Replication] No handler for:", actionType)
		return
	end

	local ok, reason = handlers.validate(sender, payload)
	if not ok then
		self.Reconcile:Fire(sender, actionType, clientSeq, false, nil, reason)
		return
	end

	local broadcastState = handlers.Execute(sender, payload)
	self.Reconcile:Fire(sender, actionType, clientSeq, true, broadcastState, nil)
	self.Broadcast:FireAll(sender.UserId, actionType, broadcastState)
end

return ReplicationService
