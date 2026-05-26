-- StateService (Server)
-- Enables all state keys and starts the shared State tracker.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local State = require(ReplicatedStorage.Shared.Modules.State.State)
local Meta = require(ReplicatedStorage.Shared.Modules.State.Meta)

local StateService = { Name = "StateService" }

function StateService:KnitInit()
	for _, key in Meta.StateKeys do
		State.enable(key)
	end

	State.start()
end

return StateService
