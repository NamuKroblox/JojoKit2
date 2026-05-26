local Players = game:GetService("Players")
local Knit = require(game:GetService("ReplicatedStorage").Packages.knit)

local AnimationPlayer = require(game.StarterPlayer.StarterPlayerScripts.Client.Modules.Animation.AnimationPlayer)
local State = require(game:GetService("ReplicatedStorage").Shared.Modules.State.State)
local Meta = require(game:GetService("ReplicatedStorage").Shared.Modules.State.Meta)

local ANIMS = game:GetService("ReplicatedStorage"):WaitForChild("Animations")

local byUserId = setmetatable({}, { __mode = "v" })

local AnimationController = { Name = "AnimationController" }
AnimationController.__index = AnimationController

local function resolveAnimator(entity: Instance): Animator?
	local humanoid = entity:FindFirstChildOfClass("Humanoid") or entity:FindFirstChildOfClass("AnimationController")
	return humanoid and humanoid:FindFirstChildOfClass("Animator")
end

function AnimationController.new(player: Player)
	local self = setmetatable({}, AnimationController)
	self._player = player
	self._isLocal = player == Players.LocalPlayer
	self._animPlayers = {}
	self._listeners = {}
	self._slotOwners = {}
	self._attachCbs = {}
	self._charConn = nil

	byUserId[player.UserId] = self

	self:_attachCharacter()
	self._charConn = player.CharacterAdded:Connect(function()
		self:_detachAll()
		self:_attachCharacter()
	end)

	return self
end

function AnimationController.getByUserId(userId: number)
	return byUserId[userId]
end

function AnimationController:_attachCharacter()
	local character = self._player.Character
	if not character then
		return
	end
	local animator = resolveAnimator(character)
	if not animator then
		return
	end
	local folder = ANIMS:FindFirstChild("Characters")
	if not folder then
		return
	end
	self._animPlayers.character = AnimationPlayer.new(animator, folder)
end

function AnimationController:attach(key: string, entity: Instance, folderPath: string)
	if self._animPlayers[key] then
		self._animPlayers[key]:Destroy()
	end
	local animator = resolveAnimator(entity)
	if not animator then
		warn("[AnimationController] No animator on entity for key:", key)
		return
	end
	local folder = ANIMS
	for part in folderPath:gmatch("[^.]+") do
		folder = folder:FindFirstChild(part)
		if not folder then
			warn("[AnimationController] Folder path not found:", folderPath)
			return
		end
	end
	self._animPlayers[key] = AnimationPlayer.new(animator, folder)

	local cbs = self._attachCbs[key]
	if cbs then
		for _, cb in cbs do
			task.spawn(cb, key)
		end
	end
end

function AnimationController:onAttach(key: string, cb: (key: string) -> ())
	if not self._attachCbs[key] then
		self._attachCbs[key] = {}
	end
	table.insert(self._attachCbs[key], cb)

	if self._animPlayers[key] then
		task.spawn(cb, key)
	end
end

function AnimationController:offAttach(key: string, cb: (key: string) -> ())
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
	if self._animPlayers[key] then
		self._animPlayers[key]:Destroy()
		self._animPlayers[key] = nil
	end
	self._slotOwners[key] = nil
end

function AnimationController:_detachAll()
	for key, ap in self._animPlayers do
		ap:Destroy()
		self._animPlayers[key] = nil
	end
	table.clear(self._slotOwners)
end

function AnimationController:play(label: string, key: string, slot: number, name: string, overrides: { [string]: any }?)
	local ap = self._animPlayers[key]
	if not ap then
		return
	end
	ap:Play(slot, name, overrides)

	if not self._slotOwners[key] then
		self._slotOwners[key] = {}
	end
	self._slotOwners[key][slot] = label

	if key ~= "character" and self._isLocal then
		Knit.GetController("ReplicationController"):Dispatch("PlayAnimation", {
			key = key,
			slot = slot,
			name = name,
			overrides = overrides,
		})
	end
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
	if key ~= "character" and self._isLocal then
		Knit.GetController("ReplicationController"):Dispatch("StopAnimation", {
			key = key,
			slot = slot,
			blend = blend,
		})
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
	if key ~= "character" and self._isLocal then
		Knit.GetController("ReplicationController"):Dispatch("StopAllAnimation", {
			key = key,
			blend = blend,
		})
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

function AnimationController:listen(label: string, stateKey: any, handler: (value: any, old: any) -> ())
	self:unlisten(label)
	local disconnect = State.listen(stateKey, function(p, value, old, isReplay)
		if p ~= self._player or isReplay then
			return
		end
		handler(value, old)
	end)
	self._listeners[label] = disconnect
end

function AnimationController:unlisten(label: string)
	local d = self._listeners[label]
	if d then
		d()
		self._listeners[label] = nil
	end
end

function AnimationController:unlistenAll()
	for label in self._listeners do
		self:unlisten(label)
	end
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

function AnimationController:KnitStart()
	local localPlayer = Players.LocalPlayer
	local instance = AnimationController.new(localPlayer)

	instance:listen("sprint", Meta.StateKeys.Sprinting, function(value, old)
		if value == old then
			return
		end
		local character = localPlayer.Character
		if not character then
			return
		end
		local humanoid = character:FindFirstChildOfClass("Humanoid")
		if not humanoid then
			return
		end
		if value and humanoid:GetState() == Enum.HumanoidStateType.Running then
			instance:play("sprint", "character", 0, "Movement.Run")
		else
			instance:stopAnimations("sprint")
		end
	end)

	instance:listen("standEquipped", Meta.StateKeys.StandEquipped, function(value, old)
		if value == old then
			return
		end
		if value then
			instance:onAttach("stand", function()
				instance:play("standIdle", "stand", 0, "Idle")
			end)
		else
			instance:stopAnimations("standIdle")
			instance:offAttach("stand", instance._attachCbs["stand"] and instance._attachCbs["stand"][1])
		end
	end)

	Players.PlayerRemoving:Connect(function(player)
		if player ~= localPlayer then
			return
		end
		instance:_destroy()
	end)
end

return AnimationController
