local Registry = {}

Registry.Characters = {
	Default = {
		Idle = { id = "rbxassetid://0", priority = 0, loop = true, speed = 1, blend = 0.15 },
		Walk = { id = "rbxassetid://0", priority = 0, loop = true, speed = 1, blend = 0.15 },
		Run = { id = "rbxassetid://0", priority = 0, loop = true, speed = 1, blend = 0.15 },
		Jump = { id = "rbxassetid://0", priority = 1, loop = false, speed = 1, blend = 0.1 },
		Fall = { id = "rbxassetid://0", priority = 1, loop = true, speed = 1, blend = 0.2 },
		Sit = { id = "rbxassetid://0", priority = 1, loop = true, speed = 1, blend = 0.2 },
		Climb = { id = "rbxassetid://0", priority = 1, loop = true, speed = 1, blend = 0.1 },
	},
	Combat = {
		M1 = { id = "rbxassetid://99191336327451", priority = 2, loop = false, speed = 1, blend = 0.1 },
		M2 = { id = "rbxassetid://98854414567067", priority = 2, loop = false, speed = 1, blend = 0.1 },
		M3 = { id = "rbxassetid://109868848657984", priority = 2, loop = false, speed = 1, blend = 0.1 },
		M4 = { id = "rbxassetid://137240283554699", priority = 2, loop = false, speed = 1, blend = 0.1 },
	},
}

Registry.NPCs = {
	StarPlatinum = {
		Idle = { id = "rbxassetid://115688478831279", priority = 0, loop = true, speed = 1, blend = 0.2 },
	},
}

return Registry
