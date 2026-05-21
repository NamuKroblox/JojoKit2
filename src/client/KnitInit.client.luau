-- KnitClient (LocalScript — StarterPlayerScripts)

local Knit = require(game.ReplicatedStorage.Packages.knit)
local Bootstrapper = require(game.ReplicatedStorage.Shared.Modules.Bootstrapper)
local ReplicatedStorage = game:GetService("ReplicatedStorage")

Bootstrapper.start({
	knit = Knit,
	actions = { ReplicatedStorage.Shared.Modules.Actions },
	controllers = { script.Parent.Controllers },
})
