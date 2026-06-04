local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local EffectRegistry = require(ReplicatedStorage.Shared.Registries.EffectRegistry)

local VfxFolder: Folder = game.ReplicatedStorage:WaitForChild("Vfx")
local VfxManager = require(game.ReplicatedStorage.Shared.Helper.VfxManager)

export type EffectEntry = {
	id: string,
	payload: EffectRegistry.EffectPayload,
}

type Handle = {
	id: string,
	effectId: string,
	cancel: (() -> ())?,
	cancelled: boolean,
}

local EffectController = {
	Name = "EffectController",
}

local localPlayer = Players.LocalPlayer
local activeHandles: { [string]: Handle } = {}
local handleCounter = 0

local function nextHandleId(): string
	handleCounter += 1
	return "eff_" .. handleCounter
end

local function resolveCharacter(payload: EffectRegistry.EffectPayload): Model?
	if not payload.targetKey then
		return nil
	end
	if payload.isPlayer then
		local p = Players:GetPlayerByUserId(tonumber(payload.targetKey))
		return p and p.Character
	end
	local dummies = workspace:FindFirstChild("Dummies")
	return dummies and dummies:FindFirstChild(payload.targetKey) :: Model?
end

local function resolvePerspective(
	sourceUserId: number?,
	payload: EffectRegistry.EffectPayload
): EffectRegistry.EffectPerspective
	if payload.isPlayer and payload.targetKey == tostring(localPlayer.UserId) then
		return "self"
	end
	if sourceUserId and sourceUserId == localPlayer.UserId then
		return "attacker"
	end
	return "observer"
end

local function perspectiveAllowed(def: EffectRegistry.EffectDef, perspective: EffectRegistry.EffectPerspective): boolean
	if not def.perspectives then
		return true
	end
	for _, p in def.perspectives do
		if p == perspective then
			return true
		end
	end
	return false
end

local function playOne(effectId: string, payload: EffectRegistry.EffectPayload, sourceUserId: number?): string?
	local def = EffectRegistry.get(effectId)
	if not def then
		warn("[EffectController] Unknown effect:", effectId)
		return nil
	end

	local perspective = resolvePerspective(sourceUserId, payload)
	if not perspectiveAllowed(def, perspective) then
		return nil
	end

	local resolved = table.clone(payload)
	if not resolved.targetCharacter and payload.targetKey then
		resolved.targetCharacter = resolveCharacter(payload)
	end

	local handleId = nextHandleId()
	local handle: Handle = {
		id = handleId,
		effectId = effectId,
		cancel = nil,
		cancelled = false,
	}
	activeHandles[handleId] = handle

	task.spawn(function()
		if handle.cancelled then
			activeHandles[handleId] = nil
			return
		end

		local ok, result = pcall(def.play, resolved, perspective)
		if not ok then
			warn("[EffectController] Effect '" .. effectId .. "' error:", result)
			activeHandles[handleId] = nil
			return
		end

		if type(result) == "function" then
			handle.cancel = result
		end

		if handle.cancelled then
			if handle.cancel then
				pcall(handle.cancel)
			end
			activeHandles[handleId] = nil
		end
	end)

	return handleId
end

function EffectController:PlayMany(effects: { EffectEntry }, sourceUserId: number?): { string }
	local handles = {}
	for _, entry in effects do
		local h = playOne(entry.id, entry.payload, sourceUserId)
		if h then
			table.insert(handles, h)
		end
	end
	return handles
end

function EffectController:Play(effectId: string, payload: EffectRegistry.EffectPayload, sourceUserId: number?): string?
	return playOne(effectId, payload, sourceUserId)
end

function EffectController:Cancel(handleId: string)
	local handle = activeHandles[handleId]
	if not handle then
		return
	end
	handle.cancelled = true
	if handle.cancel then
		pcall(handle.cancel)
	end
	activeHandles[handleId] = nil
end

function EffectController:CancelAll()
	local ids = {}
	for id in activeHandles do
		table.insert(ids, id)
	end
	for _, id in ids do
		self:Cancel(id)
	end
end

function EffectController:KnitInit()
	EffectRegistry.register({

		id = "PunchImpact",

		perspectives = { "attacker", "observer" },

		play = function(payload, _)
			local targetCharacter = payload.targetCharacter

			if not targetCharacter then
				return
			end

			local root = targetCharacter:FindFirstChild("HumanoidRootPart")

			if not root then
				return
			end

			local standName = payload.standName

			if not standName then
				return
			end

			local standFolder = VfxFolder:FindFirstChild("Stand")
				:FindFirstChild("Attack")
				:FindFirstChild("Melee")
				:FindFirstChild(standName)

			if not standFolder then
				return
			end

			local mainTemplate = standFolder:FindFirstChild("Main")

			if not mainTemplate then
				warn("didnt found template")
				return
			end

			VfxManager.attach("PunchImpact_" .. tostring(payload.combo or 1), {
				template = mainTemplate,
				parent = root,
				cleanup = 0.5,
			})
		end,
	})
end

return EffectController
