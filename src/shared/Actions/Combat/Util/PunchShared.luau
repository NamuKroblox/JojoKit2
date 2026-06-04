-- PunchShared (unchanged except: snapshot no longer carries displayCombo)

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local State = require(ReplicatedStorage.Shared.State.State)
local Meta = require(ReplicatedStorage.Shared.State.Meta)
local PunchConfig = require(script.Parent.PunchConfig)

local PunchShared = {}

function PunchShared.getNow(): number
	return workspace:GetServerTimeNow()
end

function PunchShared.getNextCombo(combo: number): (number, boolean)
	local next = (combo % PunchConfig.MaxCombo) + 1
	local finisher = next == PunchConfig.MaxCombo
	return next, finisher
end

function PunchShared.shouldResetCombo(combo: number, lastPunch: number, now: number): boolean
	return combo > 0 and (now - lastPunch) > PunchConfig.RhythmWindow
end

-- Returns displayCombo separately so callers that need it (client prediction)
-- never have to read it back from state after a potential finisher reset.
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
