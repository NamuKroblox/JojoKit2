local ReplicatedStorage = game:GetService("ReplicatedStorage")

local AttachModel = require(script.Parent.AttachModel)
local Constants = require(ReplicatedStorage.Shared.Features.StandEquip.Constants)

local STAND_MODELS = ReplicatedStorage.StandModels
local ATTACH_OFFSET = CFrame.new(2, 1.5, 2.5)
local HRP_TIMEOUT = 10

local StandVisual = {}

local attachTokens: { [Player]: number } = {}

local function nextToken(player: Player): number
	attachTokens[player] = (attachTokens[player] or 0) + 1
	return attachTokens[player]
end

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

		if not hrp then
			return
		end
		if attachTokens[player] ~= token then
			return
		end
		if AttachModel.HasAttachment(player) then
			return
		end

		AttachModel.Attach(character, template, ATTACH_OFFSET)
	end)
end

local function hide(player: Player)
	nextToken(player)
	AttachModel.Detach(player)
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
	AttachModel.Detach(player)
end

return StandVisual
