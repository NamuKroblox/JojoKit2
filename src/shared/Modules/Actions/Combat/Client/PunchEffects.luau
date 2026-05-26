local ReplicatedStorage = game:GetService("ReplicatedStorage")

local VfxManager = require(ReplicatedStorage.Shared.Modules.Helper.VfxManager)
local AttachModel = require(ReplicatedStorage.Shared.Modules.Actions.Stand.Equip.Util.AttachModel)

local PunchEffects = {}

function PunchEffects.buildOverlapParams(player: Player)
	local params = OverlapParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude

	local excluded = {}

	if player.Character then
		table.insert(excluded, player.Character)
	end

	local hasModel, standModel = AttachModel.HasAttachment(player)
	if hasModel and standModel then
		table.insert(excluded, standModel)
	end

	params.FilterDescendantsInstances = excluded
	return params
end

function PunchEffects.play(player: Player, snapshot, HitboxController)
	local character = player.Character
	if not character or not HitboxController then
		return
	end

	HitboxController:Create({
		userId = player.UserId,
		size = Vector3.new(4, 4, 4),
		cframe = character:GetPivot(),
		offset = CFrame.new(0, 0, -5),
		lifetime = 0.3,
		overlapParams = PunchEffects.buildOverlapParams(player),
		onHit = function(targetCharacter)
			local root = targetCharacter and targetCharacter:FindFirstChild("HumanoidRootPart")
			if not root then
				return
			end
			VfxManager.attach("Punch_Vfx", {
				parent = root,
				template = ReplicatedStorage.Vfx.Stand.Attack.Melee.Main,
				cleanup = 1,
			})
		end,
	})
end

return PunchEffects
