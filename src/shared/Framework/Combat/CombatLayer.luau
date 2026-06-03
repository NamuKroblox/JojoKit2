--[[
	CombatLayer
	
	Manages interactions between multiple active abilities.
	Individual abilities are isolated and not responsible for coordinating with other abilities.
	
	Responsibilities include:
	- Ability interruption
	- Ability cancellation
	- Ability priority resolution
	- Ability chaining and combo transitions
	- Cooldown arbitration
	- Status effect conflicts
	- Global combat state management
]]

local CombatLayer = {}
CombatLayer.__index = CombatLayer

export type AbilitySlot = {
	name: string,
	controlUnit: any,
	priority: number,
	cooldown: number,
	lastExecuted: number?,
}

export type CombatState = {
	activeAbilities: { [string]: AbilitySlot },
	abilityQueue: { string },
	globalState: { [string]: any },
	statusEffects: { [string]: { [string]: any } },
}

function CombatLayer.new()
	local self = setmetatable({}, CombatLayer)
	
	self._activeAbilities: { [string]: AbilitySlot } = {}
	self._abilityQueue: { string } = {}
	self._globalState: { [string]: any } = {}
	self._statusEffects: { [string]: { [string]: any } } = {}
	self._cooldowns: { [string]: number } = {}
	
	return self
end

--[[
	Register an ability with the combat layer.
]]
function CombatLayer:registerAbility(name: string, controlUnit: any, priority: number, cooldown: number)
	self._activeAbilities[name] = {
		name = name,
		controlUnit = controlUnit,
		priority = priority,
		cooldown = cooldown,
		lastExecuted = nil,
	}
end

--[[
	Request ability execution. Returns success or reason for rejection.
]]
function CombatLayer:executeAbility(name: string): (boolean, string?)
	local slot = self._activeAbilities[name]
	
	if not slot then
		return false, `Ability '{name}' not registered`
	end
	
	-- Check cooldown
	if slot.lastExecuted then
		local elapsed = tick() - slot.lastExecuted
		if elapsed < slot.cooldown then
			return false, `Ability '{name}' on cooldown for {slot.cooldown - elapsed:.2f}s`
		end
	end
	
	-- Check priority conflicts
	local blockedBy = self:_findBlockingAbility(name, slot.priority)
	if blockedBy then
		return false, `Ability '{name}' blocked by higher priority ability '{blockedBy}'`
	end
	
	-- Check status effect conflicts
	if self:_hasConflictingStatusEffect(name) then
		return false, `Ability '{name}' blocked by status effect`
	end
	
	-- Start the ability
	if not slot.controlUnit:start() then
		return false, `Failed to start ability '{name}'`
	end
	
	slot.lastExecuted = tick()
	
	return true
end

--[[
	Interrupt an active ability.
]]
function CombatLayer:interruptAbility(name: string)
	local slot = self._activeAbilities[name]
	
	if not slot or not slot.controlUnit:isActive() then
		return false
	end
	
	slot.controlUnit:cancel()
	return true
end

--[[
	Add a status effect that blocks certain abilities.
]]
function CombatLayer:applyStatusEffect(abilityName: string, effectName: string, data: any?)
	if not self._statusEffects[abilityName] then
		self._statusEffects[abilityName] = {}
	end
	
	self._statusEffects[abilityName][effectName] = data or true
end

--[[
	Remove a status effect.
]]
function CombatLayer:removeStatusEffect(abilityName: string, effectName: string)
	if self._statusEffects[abilityName] then
		self._statusEffects[abilityName][effectName] = nil
	end
end

--[[
	Set global combat state (e.g., stun, freeze, sleep).
]]
function CombatLayer:setGlobalState(key: string, value: any)
	self._globalState[key] = value
end

--[[
	Get global combat state.
]]
function CombatLayer:getGlobalState(key: string): any
	return self._globalState[key]
end

--[[
	Chain ability to another (combo transition).
]]
function CombatLayer:chainAbility(fromAbility: string, toAbility: string): boolean
	local fromSlot = self._activeAbilities[fromAbility]
	local toSlot = self._activeAbilities[toAbility]
	
	if not fromSlot or not toSlot then
		return false
	end
	
	-- End the source ability
	if fromSlot.controlUnit:isActive() then
		fromSlot.controlUnit:stop("Completed")
	end
	
	-- Execute chained ability
	local success, reason = self:executeAbility(toAbility)
	if not success then
		warn(`Failed to chain ability: {reason}`)
	end
	
	return success
end

--[[
	Get all active abilities.
]]
function CombatLayer:getActiveAbilities(): { [string]: AbilitySlot }
	return self._activeAbilities
end

--[[
	Get combat state snapshot.
]]
function CombatLayer:getState(): CombatState
	return {
		activeAbilities = self._activeAbilities,
		abilityQueue = self._abilityQueue,
		globalState = self._globalState,
		statusEffects = self._statusEffects,
	}
end

--[[
	Internal: Find if an ability is blocked by another.
]]
function CombatLayer:_findBlockingAbility(targetName: string, targetPriority: number): string?
	for name, slot in pairs(self._activeAbilities) do
		if slot.controlUnit:isActive() and slot.priority > targetPriority and name ~= targetName then
			return name
		end
	end
	return nil
end

--[[
	Internal: Check if status effects block an ability.
]]
function CombatLayer:_hasConflictingStatusEffect(abilityName: string): boolean
	local effects = self._statusEffects[abilityName]
	if not effects or next(effects) == nil then
		return false
	end
	
	-- If any status effect exists, it blocks the ability
	return true
end

--[[
	Reset combat layer state.
]]
function CombatLayer:reset()
	for name, slot in pairs(self._activeAbilities) do
		if slot.controlUnit:isActive() then
			slot.controlUnit:stop()
		end
	end
	
	self._abilityQueue = {}
	self._globalState = {}
	self._statusEffects = {}
	self._cooldowns = {}
end

return CombatLayer
