-- ReplicationService (ModuleScript — ServerStorage/Services)
-- Replaces: ValidatedRemoteAction, BroadcastEvent, ReconcileEvent, AckEvent

local Players = game:GetService("Players")
local Knit = require(game:GetService("ReplicatedStorage").Packages.knit)

local Registry = require(game:GetService("ReplicatedStorage").Shared.Modules.Replication.ReplicationRegistry)

local ReplicationService = {
	Name = "ReplicationService",
	Client = {
		Reconcile = Knit.CreateSignal(),
		Broadcast = Knit.CreateSignal(),
	},
}

function ReplicationService:KnitInit() end

function ReplicationService.Client:DispatchAction(sender, actionType, payload, clientSeq)
	local handlers = Registry.get(actionType)

	if not handlers then
		warn(("[Replication] No handlers registered for action '%s'"):format(tostring(actionType)))
		return
	end

	local ok, reason = handlers.validate(sender, payload)

	if not ok then
		warn(
			("[Replication] Validation failed | Player=%s | Action=%s | Reason=%s"):format(
				sender.Name,
				tostring(actionType),
				tostring(reason)
			)
		)

		self.Reconcile:Fire(sender, actionType, reason, clientSeq)
		return
	end

	local broadcastState = handlers.predict(sender, payload)

	self.Reconcile:Fire(sender, actionType, nil, clientSeq)

	local all = Players:GetPlayers()

	for i = 1, #all do
		local other = all[i]

		if other ~= sender then
			print(
				("[Replication] Broadcasting '%s' from %s -> %s"):format(tostring(actionType), sender.Name, other.Name)
			)

			self.Broadcast:Fire(other, sender.UserId, actionType, payload, broadcastState)
		end
	end
end

return ReplicationService
