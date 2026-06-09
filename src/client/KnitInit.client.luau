-- KnitClient (LocalScript — StarterPlayerScripts)

local Knit = require(game.ReplicatedStorage.Packages.knit)
local Chrono = require(game.ReplicatedStorage.Packages.chrono)

local Bootstrapper = require(game.ReplicatedStorage.Shared.Bootstrapper)
local ReplicatedStorage = game:GetService("ReplicatedStorage")

Bootstrapper.start({
	knit = Knit,
	chrono = Chrono,
	abilities = ReplicatedStorage.Shared.Abilities,
	Registries = ReplicatedStorage.Shared.Registration.Registries,
	isClient = true,
	controllers = { script.Parent.Controllers },
})
