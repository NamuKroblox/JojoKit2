local AnimationPlayer = {}
AnimationPlayer.__index = AnimationPlayer

local DEFAULT_BLEND = 0.15
local DEFAULT_SPEED = 1

function AnimationPlayer.new(animator: Animator, folder: Folder)
	local self = setmetatable({}, AnimationPlayer)
	self._animator = animator
	self._tracks = {}
	self._slots = {}
	self._tokens = {}
	self:_load(folder, nil)
	return self
end

function AnimationPlayer:_load(folder: Instance, prefix: string?)
	for _, child in folder:GetChildren() do
		local path = prefix and (prefix .. "." .. child.Name) or child.Name
		if child:IsA("Animation") then
			local track = self._animator:LoadAnimation(child)
			self._tracks[path] = track
		elseif child:IsA("Folder") then
			self:_load(child, path)
		end
	end
end

function AnimationPlayer:_stopSlot(slot: number, blend: number)
	local entry = self._slots[slot]
	if not entry then
		return
	end
	self._tokens[slot] = (self._tokens[slot] or 0) + 1
	if entry.conn then
		entry.conn:Disconnect()
		entry.conn = nil
	end
	entry.track:Stop(blend)
	self._slots[slot] = nil
end

function AnimationPlayer:Play(slot: number, name: string, overrides: { [string]: any }?)
	local track = self._tracks[name]
	if not track then
		warn("[AnimationPlayer] Unknown animation:", name)
		return
	end

	local blend = (overrides and overrides.blend) or DEFAULT_BLEND
	local speed = (overrides and overrides.speed) or DEFAULT_SPEED
	local loop = (overrides and overrides.loop) or track.Looped
	local priority = overrides and overrides.priority

	self:_stopSlot(slot, blend)
	self._tokens[slot] = (self._tokens[slot] or 0) + 1
	local token = self._tokens[slot]

	track.Looped = loop
	if priority ~= nil then
		track.Priority = priority
	end
	track.TimePosition = 0
	track:AdjustSpeed(speed)
	track:Play(blend)

	local entry = { track = track, name = name, conn = nil }

	if not loop then
		entry.conn = track.Stopped:Connect(function()
			if entry.conn then
				entry.conn:Disconnect()
				entry.conn = nil
			end
			if self._tokens[slot] == token and self._slots[slot] == entry then
				self._slots[slot] = nil
			end
		end)
	end

	self._slots[slot] = entry

	return track
end

function AnimationPlayer:Stop(slot: number, blend: number?)
	local entry = self._slots[slot]
	if not entry then
		return
	end
	self:_stopSlot(slot, blend or DEFAULT_BLEND)
end

function AnimationPlayer:StopAll(blend: number?)
	for slot in self._slots do
		self:_stopSlot(slot, blend or DEFAULT_BLEND)
	end
end

function AnimationPlayer:IsPlaying(name: string): boolean
	for _, entry in self._slots do
		if entry.name == name then
			return entry.track.IsPlaying
		end
	end
	return false
end

function AnimationPlayer:Length(name: string): number?
	local track = self._tracks[name]
	return track and track.Length > 0 and track.Length or nil
end

function AnimationPlayer:Destroy()
	for slot, entry in self._slots do
		self._tokens[slot] = (self._tokens[slot] or 0) + 1
		if entry.conn then
			entry.conn:Disconnect()
		end
		entry.track:Stop(0)
	end
	for _, track in self._tracks do
		track:Destroy()
	end
	table.clear(self._slots)
	table.clear(self._tracks)
	table.clear(self._tokens)
end

function AnimationPlayer:GetTrack(name: string): AnimationTrack?
	return self._tracks[name]
end

function AnimationPlayer:GetCurrent(slot: number): string?
	local entry = self._slots[slot]
	return entry and entry.name or nil
end

function AnimationPlayer:IsSlotPlaying(slot: number): boolean
	local entry = self._slots[slot]

	if not entry then
		return false
	end

	return entry.track.IsPlaying
end

function AnimationPlayer:GetProgress(slot: number): number?
	local entry = self._slots[slot]

	if not entry then
		return nil
	end

	local track = entry.track

	if track.Length <= 0 then
		return nil
	end

	return track.TimePosition / track.Length
end

function AnimationPlayer:SetSpeed(slot: number, speed: number)
	local entry = self._slots[slot]

	if not entry then
		return
	end

	entry.track:AdjustSpeed(speed)
end

function AnimationPlayer:GetTimePosition(slot: number): number?
	local entry = self._slots[slot]

	if not entry then
		return nil
	end

	return entry.track.TimePosition
end

function AnimationPlayer:GetLength(name: string): number?
	local track = self._tracks[name]

	if not track then
		return nil
	end

	return track.Length > 0 and track.Length or nil
end

function AnimationPlayer:OnMarker(name: string, marker: string, callback)
	local track = self._tracks[name]

	if not track then
		return nil
	end

	return track:GetMarkerReachedSignal(marker):Connect(callback)
end

function AnimationPlayer:OnStopped(name: string, callback)
	local track = self._tracks[name]

	if not track then
		return nil
	end

	return track.Stopped:Connect(callback)
end

function AnimationPlayer:WaitForEnd(name: string)
	local track = self._tracks[name]

	if not track then
		return
	end

	if track.IsPlaying then
		track.Stopped:Wait()
	end
end

return AnimationPlayer
