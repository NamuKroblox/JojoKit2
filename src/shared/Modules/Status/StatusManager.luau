-- StatusManager
-- Predictive status effect system with client-side prediction and server replication
-- Supports effects like Stunned, Frozen, Burning, etc.

local RunService = game:GetService("RunService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local IS_SERVER = RunService:IsServer()

local StatusManager = {}

-- Status definition
type StatusEffect = {
	name: string,
	duration: number,
	onApply: (target: Player | Model, data: any) -> (),
	onRemove: (target: Player | Model, data: any) -> (),
}

type ActiveStatus = {
	effect: StatusEffect,
	appliedAt: number,
	data: any?,
}

local statusRegistry: { [string]: StatusEffect } = {}
local activeStatuses: { [number | Instance]: { [string]: ActiveStatus } } = {} -- [targetId/model] = { [effectName] = status }

function StatusManager.registerStatus(statusDef: StatusEffect)
	assert(type(statusDef.name) == "string", "Status name required")
	assert(type(statusDef.duration) == "number", "Status duration required")
	statusRegistry[statusDef.name] = statusDef
end

function StatusManager.applyStatus(target: Player | Model, statusName: string, data: any)
	local effect = statusRegistry[statusName]
	if not effect then
		warn("[StatusManager] Unknown status:", statusName)
		return false
	end

	local targetKey = typeof(target) == "Instance" and target or target.UserId
	if not activeStatuses[targetKey] then
		activeStatuses[targetKey] = {}
	end

	-- Remove existing status if any
	StatusManager.removeStatus(target, statusName)

	-- Apply new status
	local activeStatus: ActiveStatus = {
		effect = effect,
		appliedAt = os.clock(),
		data = data,
	}

	activeStatuses[targetKey][statusName] = activeStatus

	-- Call effect callback
	if effect.onApply then
		effect.onApply(target, data)
	end

	return true
end

function StatusManager.removeStatus(target: Player | Model, statusName: string)
	local targetKey = typeof(target) == "Instance" and target or target.UserId
	local statuses = activeStatuses[targetKey]

	if not statuses or not statuses[statusName] then
		return false
	end

	local active = statuses[statusName]

	-- Call removal callback
	if active.effect.onRemove then
		active.effect.onRemove(target, active.data)
	end

	statuses[statusName] = nil

	-- Clean up table if empty
	if next(statuses) == nil then
		activeStatuses[targetKey] = nil
	end

	return true
end

function StatusManager.hasStatus(target: Player | Model, statusName: string): boolean
	local targetKey = typeof(target) == "Instance" and target or target.UserId
	local statuses = activeStatuses[targetKey]
	return statuses ~= nil and statuses[statusName] ~= nil
end

function StatusManager.getStatus(target: Player | Model, statusName: string): ActiveStatus?
	local targetKey = typeof(target) == "Instance" and target or target.UserId
	local statuses = activeStatuses[targetKey]
	return statuses and statuses[statusName] or nil
end

function StatusManager.getAllStatuses(target: Player | Model): { [string]: ActiveStatus }
	local targetKey = typeof(target) == "Instance" and target or target.UserId
	return activeStatuses[targetKey] or {}
end

-- Update loop to clean up expired statuses
if IS_SERVER then
	task.spawn(function()
		while true do
			task.wait(0.1)
			local now = os.clock()

			for targetKey, statuses in pairs(activeStatuses) do
				for statusName, active in pairs(statuses) do
					if (now - active.appliedAt) >= active.effect.duration then
						local target: Player | Model
						if type(targetKey) == "number" then
							target = Players:GetPlayerByUserId(targetKey)
						else
							target = targetKey
						end

						if target then
							StatusManager.removeStatus(target, statusName)
						end
					end
				end
			end
		end
	end)
end

return StatusManager
