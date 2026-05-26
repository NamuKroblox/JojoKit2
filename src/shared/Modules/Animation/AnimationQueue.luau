local AnimationQueue = {}
AnimationQueue.__index = AnimationQueue

function AnimationQueue.new(animator)
	return setmetatable({
		_animator = animator,
		_queue = {},
		_running = false,
		_token = 0,
	}, AnimationQueue)
end

function AnimationQueue:push(entry)
	table.insert(self._queue, entry)
	self:_start()
end

function AnimationQueue:clear()
	self._token += 1
	table.clear(self._queue)
end

function AnimationQueue:_start()
	if self._running then
		return
	end
	self._running = true

	task.spawn(function()
		while #self._queue > 0 do
			local entry = table.remove(self._queue, 1)

			-- new token per sequence step (cancels stale loops)
			self._token += 1
			local currentToken = self._token

			self:_play(entry)

			-- wait duration safely
			task.wait(entry.duration or 0.25)

			-- if something cleared/replaced queue, stop immediately
			if currentToken ~= self._token then
				break
			end
		end

		self._running = false
	end)
end

function AnimationQueue:_play(entry)
	if not self._animator then
		return
	end

	self._animator:playAttack(entry.combo, entry.attackId, entry.serverTime, entry.isPredicted)
end

function AnimationQueue:isEmpty()
	return #self._queue == 0
end

return AnimationQueue
