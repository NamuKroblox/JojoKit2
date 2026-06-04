-- StandVisual.luau
-- Client-side visual management for stand models
-- Handles attachment, animation, and cleanup

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local AttachModel = require(script.Parent.AttachModel)
local Constants = require(ReplicatedStorage.Shared.Features.StandEquip.Constants)
local AnimationController = require(game.ReplicatedStorage.Shared.Modules.Animation.AnimationController)

local STAND_MODELS = ReplicatedStorage.StandModels
local ATTACH_OFFSET = CFrame.new(2, 1.5, 2.5)
local HRP_WAIT_TIMEOUT = 10

local StandVisual = {}

local attachmentTokens: { [number]: number } = {}
local attachedModels: { [number]: Model } = {}

local function nextToken(userId: number): number
	attachmentTokens[userId] = (attachmentTokens[userId] or 0) + 1
	return attachmentTokens[userId]
end

local function showStand(player, character: Model)
	local template = STAND_MODELS:FindFirstChild(Constants.DEFAULT_STAND)
	if not template then
		warn("[StandVisual] Missing stand model:", Constants.DEFAULT_STAND)
		return
	end

	local userId = player.UserId
	local token = nextToken(userId)

	task.spawn(function()
		local hrp = character:FindFirstChild("HumanoidRootPart")
			or character:WaitForChild("HumanoidRootPart", HRP_WAIT_TIMEOUT)

		if not hrp then
			return
		end

		-- Check if token was invalidated or stand already attached
		if attachmentTokens[userId] ~= token or AttachModel.HasAttachment(player) then
			return
		end

		local standModel = AttachModel.Attach(character, template, ATTACH_OFFSET)
		if not standModel then
			return
		end

		-- Store reference for cleanup
		attachedModels[userId] = standModel

		-- Attach animator and play idle
		local profile =
			require(game.ReplicatedStorage.Shared.Modules.Animation.AnimationRegistry).NPCs[Constants.DEFAULT_STAND]
		local animController = AnimationController.Attach(standModel, standModel.Humanoid.Animator, profile)
		animController:Play("Idle", { blend = 0.2, speed = 1 })
	end)
end

local function hideStand(player)
	local userId = player.UserId
	nextToken(userId) -- invalidate pending attach

	if attachedModels[userId] then
		AnimationController.Destroy(attachedModels[userId])
		attachedModels[userId] = nil
	end

	AttachModel.Detach(player)
end

function StandVisual.sync(player, equipped: boolean)
	if not player or not player.Character then
		return
	end

	local hasAttachment = AttachModel.HasAttachment(player)

	if equipped == hasAttachment then
		return -- Already in correct state
	end

	if equipped then
		showStand(player, player.Character)
	else
		hideStand(player)
	end
end

function StandVisual.hide(player)
	hideStand(player)
end

function StandVisual.cleanup(player)
	local userId = player.UserId
	attachmentTokens[userId] = nil
	AttachModel.Detach(player)

	if attachedModels[userId] then
		AnimationController.Destroy(attachedModels[userId])
		attachedModels[userId] = nil
	end
end

return StandVisual
