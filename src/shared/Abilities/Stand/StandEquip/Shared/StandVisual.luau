local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Knit = require(ReplicatedStorage.Packages.knit)
local AttachModel = require(script.Parent.AttachModel)

local StandConfig = require(ReplicatedStorage.Shared.Data.Configs.StandConfig)
local DataService = require(game.ReplicatedStorage.Packages.DataService).client

local STAND_MODELS = ReplicatedStorage.Visual.SMODELS
local ATTACH_OFFSET = StandConfig.ATTACH_OFFSET
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
	controller:play("standIdle", "standIdle", 0, "Stands." .. clone.Name .. ".Idle", {
		loop = true,
		priority = Enum.AnimationPriority.Idle,
	})
end

local idleCallbackRefs: { [Player]: (key: string, entity: Instance) -> () } = {}

local function show(player: Player, character: Model)
	local Stand_Model = STAND_MODELS:FindFirstChild(DataService:get("Stand"))
	warn(Stand_Model.Name)
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

		local clone = AttachModel.Attach(character, Stand_Model, ATTACH_OFFSET)
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

		controller:onAttach("standIdle", cb)
		controller:attach("standPunch", clone, "Stands." .. clone.Name .. ".Melee")
		controller:attach("standIdle", clone, "")
		controller:attach("standHit", character, "Combat.MeleeHit")
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
		controller:detach("standHit")
		controller:detach("standIdle")
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
		controller:detach("standIdle")
		controller:detach("standPunch")
		controller:detach("standHit")
	end

	AttachModel.Detach(player)
end

return StandVisual
