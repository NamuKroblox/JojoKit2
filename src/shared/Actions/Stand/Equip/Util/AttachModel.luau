-- AttachModel
-- Fixed: bindCharacter previously inserted bare sentinel records (clone=nil) into
-- the same records array that destroyRecord iterates. destroyRecord would then
-- look up the live character's HumanoidRootPart and destroy the active Motor6D
-- weld on the next Detach call. Records are now separated into lifecycle
-- connections (entry.conns) vs clone records (entry.records).

local Players = game:GetService("Players")
local TweenService = game:GetService("TweenService")

local WELD_NAME = "AttachModelWeld"
local SUMMON_TIME = 0.2

type CloneRecord = {
	character: Model,
	clone: Model,
}

type Entry = {
	records: { CloneRecord },
	conns: { RBXScriptConnection },
	boundCharacter: Model?,
	baseC0: CFrame?,
	moveToken: number?,
	moveTween: Tween?,
	resetTween: Tween?,
}

local registry: { [number]: Entry } = {}

local AttachModel = {}

-- ── internals ─────────────────────────────────────────────────────────────────

local function tweenMotorOffset(motor: Motor6D, target: CFrame, duration: number, easingDirection: Enum.EasingDirection)
	local tween = TweenService:Create(motor, TweenInfo.new(duration, Enum.EasingStyle.Back, easingDirection), {
		C0 = target,
	})

	tween:Play()
	return tween
end

local function destroyCloneRecord(record: CloneRecord)
	local root = record.character:FindFirstChild("HumanoidRootPart")
	local clone = record.clone

	if not clone then
		return
	end

	clone:SetAttribute("Attached", false)

	if not root then
		clone:Destroy()
		return
	end

	local weld = root:FindFirstChild(WELD_NAME)

	if not weld then
		clone:Destroy()
		return
	end

	local tween = tweenMotorOffset(weld, CFrame.identity, SUMMON_TIME, Enum.EasingDirection.In)

	tween.Completed:Once(function()
		if weld and weld.Parent then
			weld:Destroy()
		end

		if clone and clone.Parent then
			clone:Destroy()
		end
	end)
end

local function destroyEntry(entry: Entry)
	for _, conn in entry.conns do
		if conn then
			conn:Disconnect()
		end
	end
	for _, record in entry.records do
		destroyCloneRecord(record)
	end
end

-- bindCharacter now stores lifecycle connections separately from clone records
-- so destroyCloneRecord never accidentally touches a weld it didn't create.
local function bindCharacter(userId: number, character: Model)
	local entry = registry[userId]
	if not entry or entry.boundCharacter == character then
		return
	end
	entry.boundCharacter = character

	local ancConn = character.AncestryChanged:Connect(function(_, parent)
		if parent then
			return
		end
		AttachModel.DetachByUserId(userId)
	end)
	table.insert(entry.conns, ancConn)

	local humanoid = character:FindFirstChildOfClass("Humanoid")
	if humanoid then
		local diedConn = humanoid.Died:Connect(function()
			AttachModel.DetachByUserId(userId)
		end)
		table.insert(entry.conns, diedConn)
	end
end

local function applyClonePhysics(clone: Model)
	for _, desc in clone:GetDescendants() do
		if desc:IsA("BasePart") then
			desc.Anchored = false
			desc.Massless = true
			desc.CanCollide = false
			desc.CanTouch = false
			desc.CanQuery = false
		end
	end
end

local function playSpawnVfx(clone: Model, cloneRoot: BasePart)
	local ok, vfxTemplate = pcall(function()
		return game.ReplicatedStorage.Vfx.Stand.Summon:FindFirstChild(clone.Name)
	end)
	if not ok or not vfxTemplate then
		return
	end

	for _, vfx in vfxTemplate:GetDescendants() do
		if vfx:IsA("ParticleEmitter") then
			local ClonedVfx = vfx:Clone()
			ClonedVfx.Parent = cloneRoot:FindFirstChild("RootAttachment")

			ClonedVfx.Enabled = true
			ClonedVfx:Emit(ClonedVfx:GetAttribute("EmitCount") or 1)
			task.delay(1, function()
				if ClonedVfx and ClonedVfx.Parent then
					ClonedVfx:Destroy()
				end
			end)
		end
	end
end

-- ── public API ────────────────────────────────────────────────────────────────

function AttachModel.Attach(character: Model, template: Model, offset: CFrame?): Model?
	local root = character:FindFirstChild("HumanoidRootPart")
	local player = Players:GetPlayerFromCharacter(character)
	if not root or not player then
		return nil
	end

	local userId = player.UserId
	if not registry[userId] then
		registry[userId] = { records = {}, conns = {} }
	end

	bindCharacter(userId, character)

	local clone = template:Clone()
	local cloneRoot = clone.PrimaryPart
	if not cloneRoot then
		clone:Destroy()
		warn("[AttachModel] Template has no PrimaryPart:", template.Name)
		return nil
	end

	-- Physics and VFX can run concurrently; neither blocks the weld creation.
	task.spawn(applyClonePhysics, clone)
	clone.Parent = character
	clone:SetAttribute("Attached", true)
	clone:PivotTo(root.CFrame)
	task.spawn(playSpawnVfx, clone, cloneRoot)

	local targetOffset = offset or CFrame.identity

	local motor = Instance.new("Motor6D")
	motor.Name = WELD_NAME
	motor.Part0 = root
	motor.Part1 = cloneRoot
	motor.C0 = CFrame.identity
	motor.Parent = root

	local entry = registry[userId]
	entry.baseC0 = targetOffset

	tweenMotorOffset(motor, targetOffset, SUMMON_TIME, Enum.EasingDirection.Out)

	table.insert(registry[userId].records, { character = character, clone = clone })
	return clone
end

function AttachModel.MoveModel(player: Player, offset: CFrame, returnDuration: number)
	local entry = registry[player.UserId]
	if not entry then
		return
	end

	local character = player.Character
	if not character then
		return
	end

	local root = character:FindFirstChild("HumanoidRootPart")
	if not root then
		return
	end

	local motor = root:FindFirstChild(WELD_NAME)
	if not motor then
		return
	end

	entry.moveToken = (entry.moveToken or 0) + 1
	local token = entry.moveToken

	if entry.moveTween then
		entry.moveTween:Cancel()
	end
	if entry.resetTween then
		entry.resetTween:Cancel()
	end

	local baseC0 = entry.baseC0 or CFrame.identity

	if not registry[player.UserId] or registry[player.UserId].moveToken ~= token then
		return
	end
	if not motor.Parent then
		return
	end

	entry.moveTween = tweenMotorOffset(motor, offset, SUMMON_TIME, Enum.EasingDirection.Out)

	entry.moveTween.Completed:Once(function()
		if not registry[player.UserId] or registry[player.UserId].moveToken ~= token then
			return
		end
		if not motor.Parent then
			return
		end

		task.delay(returnDuration, function()
			if not registry[player.UserId] or registry[player.UserId].moveToken ~= token then
				return
			end
			if not motor.Parent then
				return
			end

			entry.resetTween = tweenMotorOffset(motor, baseC0, SUMMON_TIME, Enum.EasingDirection.Out)
		end)
	end)
end

function AttachModel.DetachByUserId(userId: number)
	local entry = registry[userId]
	if not entry then
		return
	end
	destroyEntry(entry)
	registry[userId] = nil
end

function AttachModel.Detach(player: Player)
	if player then
		AttachModel.DetachByUserId(player.UserId)
	end
end

function AttachModel.HasAttachment(player: Player): (boolean, Model?)
	local entry = registry[player.UserId]
	if not entry then
		return false, nil
	end
	for _, record in entry.records do
		if record.clone and record.clone.Parent and record.clone:GetAttribute("Attached") == true then
			return true, record.clone
		end
	end
	return false, nil
end

function AttachModel.GetAttachmentName(player: Player): string?
	local has, clone = AttachModel.HasAttachment(player)
	if has and clone then
		return clone.Name
	end
	return nil
end

function AttachModel.GetClone(player: Player): Model?
	local _, clone = AttachModel.HasAttachment(player)
	return clone
end

return AttachModel
