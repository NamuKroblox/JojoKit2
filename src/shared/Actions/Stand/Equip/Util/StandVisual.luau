local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Knit = require(ReplicatedStorage.Packages.knit)
local AttachModel = require(script.Parent.AttachModel)
local Constants = {
	DEFAULT_STAND = "StarPlatinum",
}

local STAND_MODELS = ReplicatedStorage.StandModels
local ATTACH_OFFSET = CFrame.new(-2, 1.5, 2)
local HRP_TIMEOUT = 10

local StandVisual = {}

local attachTokens: { [Player]: number } = {}

local function nextToken(player: Player): number
	attachTokens[player] = (attachTokens[player] or 0) + 1
	return attachTokens[player]
end

local function idleCallback(player: Player, clone: Instance)
	local AC = Knit.GetController("AnimationController")
	if not AC then
		return
	end
	local controller = AC.getOrCreate(player)
	controller:play("standIdle", "stand", 0, "Stands." .. clone.Name .. ".Idle", {
		loop = true,
		priority = Enum.AnimationPriority.Idle,
	})
end

local idleCallbackRefs: { [Player]: (key: string, entity: Instance) -> () } = {}

local function show(player: Player, character: Model)
	local template = STAND_MODELS:FindFirstChild(Constants.DEFAULT_STAND)
	if not template then
		warn("[StandVisual] Missing stand model:", Constants.DEFAULT_STAND)
		return
	end

	local token = nextToken(player)

	task.spawn(function()
		local hrp = character:FindFirstChild("HumanoidRootPart")
			or character:WaitForChild("HumanoidRootPart", HRP_TIMEOUT)

		if not hrp or attachTokens[player] ~= token then
			return
		end
		if AttachModel.HasAttachment(player) then
			return
		end

		local clone = AttachModel.Attach(character, template, ATTACH_OFFSET)
		if not clone then
			return
		end

		local AC = Knit.GetController("AnimationController")
		if not AC then
			return
		end

		local controller = AC.getOrCreate(player)

		local cb = function(_, attachedClone: Instance)
			idleCallback(player, attachedClone)
		end
		idleCallbackRefs[player] = cb

		controller:onAttach("stand", cb)
		controller:attach("standPunch", clone, "Stands." .. clone.Name .. ".Melee")
		controller:attach("stand", clone, "")
	end)
end

local function hide(player: Player)
	nextToken(player)

	local AC = Knit.GetController("AnimationController")
	if not AC then
		return
	end

	local controller = AC.getByUserId(player.UserId)
	if controller then
		local cb = idleCallbackRefs[player]
		if cb then
			controller:offAttach("stand", cb)
			idleCallbackRefs[player] = nil
		end

		controller:detach("stand")
		controller:detach("standPunch")
	end

	if AttachModel.HasAttachment(player) then
		AttachModel.Detach(player)
	end
end

function StandVisual.sync(player: Player, equipped: boolean)
	local hasVisual = AttachModel.HasAttachment(player)
	if equipped == hasVisual then
		return
	end
	if equipped then
		local character = player.Character
		if character then
			show(player, character)
		end
	else
		hide(player)
	end
end

function StandVisual.hide(player: Player)
	hide(player)
end

function StandVisual.cleanup(player: Player)
	attachTokens[player] = nil
	idleCallbackRefs[player] = nil

	local AC = Knit.GetController("AnimationController")
	if not AC then
		return
	end

	local controller = AC.getByUserId(player.UserId)
	if controller then
		controller:detach("stand")
		controller:detach("standPunch")
	end

	AttachModel.Detach(player)
end

return StandVisual
