-- KnitServer (Script — ServerScriptService)

local Knit = require(game.ReplicatedStorage.Packages.knit)
local Bootstrapper = require(game.ReplicatedStorage.Shared.Modules.Bootstrapper)
local ReplicatedStorage = game:GetService("ReplicatedStorage")

Bootstrapper.start({
	knit = Knit,
	actions = { ReplicatedStorage.Shared.Modules.Actions },
	services = { script.Parent.Services },
})
