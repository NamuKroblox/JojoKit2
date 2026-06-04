-- KnitServer (Script — ServerScriptService)

local Knit = require(game.ReplicatedStorage.Packages.knit)
local Chrono = require(game.ReplicatedStorage.Packages.chrono)
local Bootstrapper = require(game.ReplicatedStorage.Shared.Bootstrapper)
local ReplicatedStorage = game:GetService("ReplicatedStorage")

Bootstrapper.start({
	knit = Knit,
	chrono = Chrono,
	actions = { ReplicatedStorage.Shared.Actions },
	services = { script.Parent.Services },
})
