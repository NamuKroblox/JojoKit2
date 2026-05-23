local AnimationPlayer = {}
AnimationPlayer.__index = AnimationPlayer

local LAYER = {
	Locomotion = 0,
	State = 1,
	Action = 2,
	Override = 3,
}

AnimationPlayer.LAYER = LAYER

function AnimationPlayer.new(animator: Animator, profile: { [string]: any })
	local self = setmetatable({}, AnimationPlayer)
	self._animator = animator
	self._tracks = {}
	self._active = {}
	self._profile = profile
	self:_load()
	return self
end

function AnimationPlayer:_load()
	for name, data in self._profile do
		local anim = Instance.new("Animation")
		anim.AnimationId = data.id
		local track = self._animator:LoadAnimation(anim)
		track.Looped = data.loop
		self._tracks[name] = track
	end
end

function AnimationPlayer:Play(name: string, overrides: { speed: number?, blend: number? }?)
	local track = self._tracks[name]
	local data = self._profile[name]
	if not track or not data then
		warn(`[AnimationPlayer] Unknown animation: {name}`)
		return
	end

	local blend = (overrides and overrides.blend) or data.blend
	local speed = (overrides and overrides.speed) or data.speed

	for activeName, activeTrack in self._active do
		if activeName == name then
			continue
		end
		local activeData = self._profile[activeName]
		if not activeData then
			continue
		end
		if activeData.priority == data.priority or activeData.priority < data.priority then
			activeTrack:Stop(blend)
			self._active[activeName] = nil
		end
	end

	track:AdjustSpeed(speed)
	track:Play(blend)
	self._active[name] = track

	if not data.loop then
		local connection
		connection = track.Stopped:Connect(function()
			connection:Disconnect()
			if self._active[name] == track then
				self._active[name] = nil
			end
		end)
	end
end

function AnimationPlayer:Stop(name: string, blendOverride: number?)
	local track = self._tracks[name]
	local data = self._profile[name]
	if not track then
		return
	end
	track:Stop(blendOverride or (data and data.blend) or 0.15)
	self._active[name] = nil
end

function AnimationPlayer:StopAll(blendOverride: number?)
	for name, track in self._active do
		local data = self._profile[name]
		track:Stop(blendOverride or (data and data.blend) or 0.15)
	end
	table.clear(self._active)
end

function AnimationPlayer:SetSpeed(name: string, speed: number)
	local track = self._tracks[name]
	if not track then
		return
	end
	track:AdjustSpeed(speed)
end

function AnimationPlayer:IsPlaying(name: string): boolean
	local track = self._active[name]
	return track ~= nil and track.IsPlaying
end

function AnimationPlayer:Destroy()
	self:StopAll(0)
	for _, track in self._tracks do
		track:Destroy()
	end
	table.clear(self._tracks)
	table.clear(self._active)
end

return AnimationPlayer
