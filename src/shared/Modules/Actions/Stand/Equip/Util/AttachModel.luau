local Players = game:GetService("Players")
local TweenService = game:GetService("TweenService")

local AttachModel = {}

local WELD_NAME = "AttachModelWeld"

type Record = {
	character: Model,
	clone: Model,
	connections: { RBXScriptConnection }?,
}

type Entry = {
	records: { Record },
	boundCharacter: Model?,
}

-- key by userId to avoid storing Player objects as keys
local registry: { [number]: Entry } = {}

local function destroyRecord(record: Record)
	if record.connections then
		for _, c in pairs(record.connections) do
			if c then
				c:Disconnect()
			end
		end
		record.connections = nil
	end

	if record.clone and record.clone.Parent then
		-- clean up Motor6D if created
		local root = record.character and record.character:FindFirstChild("HumanoidRootPart")
		if root then
			local weld = root:FindFirstChild(WELD_NAME)
			if weld then
				weld:Destroy()
			end
		end
		record.clone:Destroy()
	end
end

local function bindCharacter(userId: number, playerCharacter: Model)
	local entry = registry[userId]
	if not entry then
		return
	end
	if entry.boundCharacter == playerCharacter then
		return
	end
	entry.boundCharacter = playerCharacter

	local conn = playerCharacter.AncestryChanged:Connect(function(_, parent)
		if parent then
			return
		end
		AttachModel.DetachByUserId(userId)
	end)

	table.insert(entry.records, { character = playerCharacter, clone = nil, connections = { conn } })

	local humanoid = playerCharacter:FindFirstChildOfClass("Humanoid")
	if humanoid then
		table.insert(entry.records, {
			character = playerCharacter,
			clone = nil,
			connections = { humanoid.Died:Connect(function()
				AttachModel.DetachByUserId(userId)
			end) },
		})
	end
end

function AttachModel.Attach(character: Model, template: Model, offset: CFrame?): Model?
	local root = character:FindFirstChild("HumanoidRootPart")
	local player = Players:GetPlayerFromCharacter(character)

	if not root or not player then
		return nil
	end

	local userId = player.UserId
	if not registry[userId] then
		registry[userId] = { records = {} }
	end

	bindCharacter(userId, character)

	local clone = template:Clone()
	local cloneRoot = clone.PrimaryPart

	if not cloneRoot then
		clone:Destroy()
		warn("[AttachModel] Template has no PrimaryPart:", template.Name)
		return nil
	end

	for _, descendant in clone:GetDescendants() do
		if descendant:IsA("BasePart") then
			descendant.Anchored = false
			descendant.Massless = true
			descendant.CanCollide = false
			descendant.CanTouch = false
			descendant.CanQuery = false

			if descendant.Name == "HumanoidRootPart" then
				continue
			end
			descendant.Transparency = 1

			TweenService:Create(descendant, TweenInfo.new(0.3, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
				Transparency = 0,
			}):Play()
		end
	end

	clone.Parent = character
	clone:PivotTo(root.CFrame)

	task.spawn(function()
		local success, VFX = pcall(function()
			return game.ReplicatedStorage.Vfx.Stand.Summon:FindFirstChild(clone.Name).Main
		end)
		if not success or not VFX then
			return
		end
		local NEW_VFX = VFX:Clone()
		NEW_VFX.Parent = cloneRoot

		for _, emitter in NEW_VFX:GetDescendants() do
			if emitter:IsA("ParticleEmitter") then
				emitter.Enabled = true
				emitter:Emit(emitter:GetAttribute("EmitCount") or 1)
			end
		end

		task.delay(1, function()
			if NEW_VFX and NEW_VFX.Parent then
				NEW_VFX:Destroy()
			end
		end)
	end)

	local motor = Instance.new("Motor6D")
	motor.Name = WELD_NAME
	motor.Part0 = root
	motor.Part1 = cloneRoot
	motor.C0 = offset
	motor.Parent = root

	local record = { character = character, clone = clone, connections = {} }
	table.insert(registry[userId].records, record)

	return clone
end

function AttachModel.DetachByUserId(userId: number)
	local entry = registry[userId]
	if not entry then
		return
	end
	for _, record in entry.records do
		destroyRecord(record)
	end
	registry[userId] = nil
end

function AttachModel.Detach(player: Player)
	if not player then
		return
	end
	AttachModel.DetachByUserId(player.UserId)
end

function AttachModel.HasAttachment(player: Player): boolean
	local entry = registry[player.UserId]
	if not entry then
		return false
	end
	for _, record in entry.records do
		if record.clone and record.clone.Parent then
			return true
		end
	end
	return false
end

function AttachModel.GetRecords(player: Player): { Record }?
	local entry = registry[player.UserId]
	return entry and entry.records or nil
end

return AttachModel
