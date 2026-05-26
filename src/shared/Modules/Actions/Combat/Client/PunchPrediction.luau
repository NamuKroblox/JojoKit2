local PunchPrediction = {}
PunchPrediction.__index = PunchPrediction

function PunchPrediction.new()
	return setmetatable({
		combat = {
			combo = 0,
			punching = false,
			finisher = false,
			attackId = 0,
			lastPunch = 0,
		},

		pending = {},
	}, PunchPrediction)
end

function PunchPrediction:get()
	return self.combat
end

function PunchPrediction:apply(snapshot)
	self.combat.combo = snapshot.combo or 0
	self.combat.punching = snapshot.punching and true or false
	self.combat.finisher = snapshot.finisher and true or false
	self.combat.attackId = snapshot.attackId or 0
	self.combat.lastPunch = snapshot.lastPunch or 0
end

function PunchPrediction:push(snapshot)
	self.pending[snapshot.attackId] = snapshot
	self:apply(snapshot)
end

function PunchPrediction:pop(attackId: number)
	local snapshot = self.pending[attackId]

	self.pending[attackId] = nil

	return snapshot
end

function PunchPrediction:reset()
	table.clear(self.pending)

	self.combat.combo = 0
	self.combat.punching = false
	self.combat.finisher = false
	self.combat.attackId = 0
	self.combat.lastPunch = 0
end

return PunchPrediction
