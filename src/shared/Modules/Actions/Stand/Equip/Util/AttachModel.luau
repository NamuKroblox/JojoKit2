local Players = game:GetService("Players")
local TweenService = game:GetService("TweenService")

local AttachModel = {}

local WELD_NAME = "AttachModelWeld"

type Record = {
	character: Model,
	clone: Model,
}

type Entry = {
	records: { Record },
	boundCharacter: Model?,
}

local registry: { [Player]: Entry } = {}

local function destroyRecord(record: Record)
	if record.clone and record.clone.Parent then
		record.clone:Destroy()
	end
end

local function bindCharacter(player: Player, character: Model)
	local entry = registry[player]
	if not entry then
		return
	end
	if entry.boundCharacter == character then
		return
	end
	entry.boundCharacter = character

	character.AncestryChanged:Connect(function(_, parent)
		if parent then
			return
		end
		AttachModel.Detach(player)
	end)

	local humanoid = character:FindFirstChildOfClass("Humanoid")
	if humanoid then
		humanoid.Died:Once(function()
			AttachModel.Detach(player)
		end)
	end
end

function AttachModel.Attach(character: Model, template: Model, offset: CFrame?): Model?
	local root = character:FindFirstChild("HumanoidRootPart")
	local player = Players:GetPlayerFromCharacter(character)

	if not root or not player then
		return nil
	end

	if not registry[player] then
		registry[player] = { records = {} }
	end

	bindCharacter(player, character)

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

	clone.Parent = workspace
	clone:PivotTo(root.CFrame)

	local motor = Instance.new("Motor6D")
	motor.Name = WELD_NAME
	motor.Part0 = root
	motor.Part1 = cloneRoot

	motor.C0 = offset

	motor.Parent = root

	table.insert(registry[player].records, {
		character = character,
		clone = clone,
	})

	return clone
end

function AttachModel.Detach(player: Player)
	local entry = registry[player]
	if not entry then
		return
	end
	for _, record in entry.records do
		destroyRecord(record)
	end
	registry[player] = nil
end

function AttachModel.HasAttachment(player: Player): boolean
	local entry = registry[player]
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
	local entry = registry[player]
	return entry and entry.records or nil
end

return AttachModel
