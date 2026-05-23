local AnimationPlayer = require(game.ReplicatedStorage.Shared.Modules.Animation.AnimationPlayer)

local AnimationController = {
	Name = "AnimationController",
}

-- use weak keys so entity references do not prevent GC
local players = setmetatable({}, { __mode = "k" }) -- [entity] = AnimationPlayer

function AnimationController.Attach(entity: Instance, animator: Animator, profile)
	if players[entity] then
		players[entity]:Destroy()
	end

	local controller = AnimationPlayer.new(animator, profile)
	players[entity] = controller

	return controller
end

function AnimationController.Get(entity: Instance)
	return players[entity]
end

function AnimationController.Play(entity: Instance, name: string, opts)
	local controller = players[entity]
	if not controller then
		return
	end

	controller:Play(name, opts)
end

function AnimationController.Destroy(entity: Instance)
	local controller = players[entity]
	if controller then
		controller:Destroy()
		players[entity] = nil
	end
end

function AnimationController.ClearAll()
	for entity, controller in pairs(players) do
		controller:Destroy()
		players[entity] = nil
	end
end

return AnimationController
