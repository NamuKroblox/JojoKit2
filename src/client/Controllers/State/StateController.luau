local ReplicatedStorage = game:GetService("ReplicatedStorage")

local State = require(ReplicatedStorage.Shared.Modules.State.State)
local StateMeta = require(ReplicatedStorage.Shared.Modules.State.Meta)

local StateController = {
	Name = "StateController",
}

function StateController:KnitInit()
	for _, key in StateMeta.StateKeys do
		State.enable(key)
	end

	State.start()
end

return StateController
