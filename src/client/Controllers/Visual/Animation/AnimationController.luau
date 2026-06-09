local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local AnimationPlayer = require(game.ReplicatedStorage.Shared.Helper.Visual.AnimationPlayer)

local ANIMS = ReplicatedStorage:WaitForChild("Visual"):WaitForChild("ANIMATIONS")

local byUserId = {}
--local ActiveListeners = {}

local AnimationController = { Name = "AnimationController" }
AnimationController.__index = AnimationController

local function resolveFolderPath(root: Instance, path: string): Instance?
	local current = root

	for segment in string.gmatch(path, "[^%.]+") do
		current = current:FindFirstChild(segment)

		if not current then
			return nil
		end
	end

	return current
end

local function resolveAnimator(entity: Instance): Animator?
	local humanoid = entity:FindFirstChildOfClass("Humanoid") or entity:FindFirstChildOfClass("AnimationController")

	if not humanoid then
		return nil
	end

	return humanoid:FindFirstChildOfClass("Animator")
end

function AnimationController.new(player: Player)
	local self = setmetatable({}, AnimationController)

	self._player = player
	self._isLocal = player == Players.LocalPlayer
	self._animPlayers = {}
	self._slotOwners = {}
	self._attachCbs = {}
	self._listeners = {}
	self._charConn = nil

	byUserId[player.UserId] = self

	self._charConn = player.CharacterAdded:Connect(function(character)
		self:_detachAll()
		self:_attachCharacter(character)
	end)

	if player.Character then
		task.spawn(function()
			self:_attachCharacter(player.Character)
		end)
	end

	return self
end

function AnimationController.getByUserId(userId: number)
	return byUserId[userId]
end

function AnimationController.getOrCreate(player: Player)
	return byUserId[player.UserId] or AnimationController.new(player)
end

function AnimationController:_attachCharacter(character: Model?)
	if not character then
		warn("[AnimationController] Missing character")
		return
	end

	local humanoid = character:WaitForChild("Humanoid")
	local animator = humanoid:WaitForChild("Animator")

	self._animPlayers.character = AnimationPlayer.new(animator, ANIMS)

	local cbs = self._attachCbs.character

	if cbs then
		for _, cb in cbs do

			task.spawn(cb, "character", character)
		end
	end
end

function AnimationController:attach(key: string, entity: Instance, folderPath: string)
	if self._animPlayers[key] then
		self._animPlayers[key]:Destroy()
	end

	local animator = resolveAnimator(entity)

	if not animator then
		warn("[AnimationController] No animator:", key)
		return
	end

	local directory

	if folderPath ~= "" then
		directory = resolveFolderPath(ANIMS, folderPath)

		if not directory then
			warn("[AnimationController] Invalid folder path:", folderPath)
			return
		end
	else
		directory = ANIMS
	end

	self._animPlayers[key] = AnimationPlayer.new(animator, directory)

	local cbs = self._attachCbs[key]

	if cbs then
		for _, cb in cbs do
			task.spawn(cb, key, entity)
		end
	end
end

function AnimationController:onAttach(key: string, cb: (key: string, entity: Instance) -> ())
	if not self._attachCbs[key] then
		self._attachCbs[key] = {}
	end

	table.insert(self._attachCbs[key], cb)

	local ap = self._animPlayers[key]
	if not ap then
		return
	end

	local animator = ap.Animator
	if not animator then
		return
	end

	local entity = animator.Parent
	if not entity then
		return
	end

	task.spawn(cb, key, entity)
end

function AnimationController:offAttach(key: string, cb: (key: string, entity: Instance) -> ())
	local cbs = self._attachCbs[key]

	if not cbs then
		return
	end

	for i, stored in cbs do
		if stored == cb then
			table.remove(cbs, i)
			return
		end
	end
end

function AnimationController:detach(key: string)
	local ap = self._animPlayers[key]

	if ap then
		ap:Destroy()
		self._animPlayers[key] = nil
	end

	self._slotOwners[key] = nil
end

function AnimationController:_detachAll()
	-- FIX 6: collect keys first, then destroy — avoids nil-during-iteration
	local keys = {}

	for key in self._animPlayers do
		keys[#keys + 1] = key
	end

	for _, key in keys do
		self._animPlayers[key]:Destroy()
		self._animPlayers[key] = nil
	end

	table.clear(self._slotOwners)
end

function AnimationController:play(label: string, key: string, slot: number, name: string, overrides: { [string]: any }?)
	local ap = self._animPlayers[key]

	if not ap then
		return
	end

	local track = ap:Play(slot, name, overrides)

	if not self._slotOwners[key] then
		self._slotOwners[key] = {}
	end

	self._slotOwners[key][slot] = label
	
	return track
end

function AnimationController:stop(key: string, slot: number, blend: number?)
	local ap = self._animPlayers[key]

	if not ap then
		return
	end

	ap:Stop(slot, blend)

	if self._slotOwners[key] then
		self._slotOwners[key][slot] = nil
	end
end

function AnimationController:stopAll(key: string, blend: number?)
	local ap = self._animPlayers[key]

	if not ap then
		return
	end

	ap:StopAll(blend)

	if self._slotOwners[key] then
		table.clear(self._slotOwners[key])
	end
end

function AnimationController:stopAnimations(label: string, blend: number?)
	for key, slots in self._slotOwners do
		for slot, owner in slots do
			if owner == label then
				self:stop(key, slot, blend)
			end
		end
	end
end

function AnimationController:listen(label: string, disconnect: () -> ())
	self:unlisten(label)
	self._listeners[label] = disconnect
end

function AnimationController:unlisten(label: string)
	local disconnect = self._listeners[label]

	if disconnect then
		disconnect()
		self._listeners[label] = nil
	end
end

function AnimationController:unlistenAll()
	for label in self._listeners do
		self:unlisten(label)
	end
end

function AnimationController:has(key: string): boolean
	return self._animPlayers[key] ~= nil
end

function AnimationController:_destroy()
	if self._charConn then
		self._charConn:Disconnect()
	end

	self:unlistenAll()
	self:_detachAll()
	table.clear(self._attachCbs)

	byUserId[self._player.UserId] = nil
end

function AnimationController:getTrack(key: string, animationName: string)
	local ap = self._animPlayers[key]

	if not ap then
		return nil
	end

	return ap:GetTrack(animationName)
end

function AnimationController:length(key: string, animationName: string)
	local ap = self._animPlayers[key]

	if not ap then
		return nil
	end

	return ap:GetLength(animationName)
end

function AnimationController:getCurrent(key: string, slot: number)
	local ap = self._animPlayers[key]

	if not ap then
		return nil
	end

	return ap:GetCurrent(slot)
end

function AnimationController:isSlotPlaying(key: string, slot: number)
	local ap = self._animPlayers[key]

	if not ap then
		return false
	end

	return ap:IsSlotPlaying(slot)
end

function AnimationController:getProgress(key: string, slot: number)
	local ap = self._animPlayers[key]

	if not ap then
		return nil
	end

	return ap:GetProgress(slot)
end

function AnimationController:setSpeed(key: string, slot: number, speed: number)
	local ap = self._animPlayers[key]

	if not ap then
		return
	end

	ap:SetSpeed(slot, speed)
end

function AnimationController:getTimePosition(key: string, slot: number)
	local ap = self._animPlayers[key]

	if not ap then
		return nil
	end

	return ap:GetTimePosition(slot)
end

function AnimationController:onMarker(
	key: string,
	animationName: string,
	marker: string,
	callback
)
	local ap = self._animPlayers[key]

	if not ap then
		return nil
	end

	return ap:OnMarker(animationName, marker, callback)
end

function AnimationController:onStopped(
	key: string,
	animationName: string,
	callback
)
	local ap = self._animPlayers[key]

	if not ap then
		return nil
	end

	return ap:OnStopped(animationName, callback)
end

function AnimationController:waitForEnd(
	key: string,
	animationName: string
)
	local ap = self._animPlayers[key]

	if not ap then
		return
	end

	ap:WaitForEnd(animationName)
end

function AnimationController:KnitStart()
	local localPlayer = Players.LocalPlayer

	local selfController = AnimationController.getOrCreate(localPlayer)

	-- FIX 5: bootstrap character that already exists before KnitStart ran
	if localPlayer.Character then
		selfController:_attachCharacter(localPlayer.Character)
	end

	for _, Dummy in Workspace:FindFirstChild("Dummies"):GetChildren() do
		if Dummy:IsA("Model") then
			selfController:attach("NPC"..Dummy.Name, Dummy, "")
		end
	end

	--[[for _, listenerModule in ListenersFolder:GetChildren() do
		if listenerModule:IsA("ModuleScript") then
			local listener = require(listenerModule)

			if type(listener.start) == "function" then
				ActiveListeners[listenerModule.Name] = listener
				task.spawn(listener.start, selfController)
			end
		end
	end--]]

	Players.PlayerRemoving:Connect(function(player)
		local controller = AnimationController.getByUserId(player.UserId)

		if controller then
			controller:_destroy()
		end
	end)
end

return AnimationController
