-- PunchShared
-- All four combat keys are now written atomically via State.setBatch so no
-- listener ever reads a half-updated snapshot (e.g. new AttackId but old Combo).

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local State = require(ReplicatedStorage.Shared.Modules.State.State)
local Meta = require(ReplicatedStorage.Shared.Modules.State.Meta)

local PunchShared = {}
PunchShared.MAX_COMBO = 4
PunchShared.RHYTHM_WINDOW = 1

function PunchShared.getNow(): number
	return workspace:GetServerTimeNow()
end

function PunchShared.getNextCombo(combo: number): (number, boolean)
	local next = (combo % PunchShared.MAX_COMBO) + 1
	local finisher = next == PunchShared.MAX_COMBO
	return next, finisher
end

function PunchShared.shouldResetCombo(combo: number, lastPunch: number, now: number): boolean
	return combo > 0 and (now - lastPunch) > PunchShared.RHYTHM_WINDOW
end

function PunchShared.buildSnapshot(currentCombo: number, attackId: number, now: number)
	local displayCombo, finisher = PunchShared.getNextCombo(currentCombo)
	return {
		displayCombo = displayCombo,
		combo = finisher and 0 or displayCombo,
		punching = true,
		finisher = finisher,
		attackId = attackId,
		lastPunch = now,
		serverTime = now,
	}
end

function PunchShared.semanticMatch(a, b): boolean
	return a.combo == b.combo and a.punching == b.punching and a.finisher == b.finisher and a.attackId == b.attackId
end

-- All four keys written atomically. Listeners will not see AttackId increment
-- while Combo still holds the old value.
function PunchShared.applyCombatState(player: Player, snapshot)
	State.setBatch(player, {
		[Meta.StateKeys.AttackId] = snapshot.attackId or 0,
		[Meta.StateKeys.Combo] = snapshot.combo or 0,
		[Meta.StateKeys.Punching] = snapshot.punching and true or false,
		[Meta.StateKeys.LastPunch] = snapshot.lastPunch or 0,
	})
end

function PunchShared.resetCombatState(player: Player)
	PunchShared.applyCombatState(player, {
		attackId = 0,
		combo = 0,
		punching = false,
		lastPunch = 0,
	})
end

return PunchShared
