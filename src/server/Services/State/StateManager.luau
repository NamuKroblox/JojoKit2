-- StateManager (Server)
-- Centralized state lifecycle management for players
-- Handles initialization, synchronization, and cleanup

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local State = require(ReplicatedStorage.Shared.Modules.State.State)
local StateMeta = require(ReplicatedStorage.Shared.Modules.State.Meta)

local StateManager = { Name = "StateManager" }

-- Connection registry: [userId] = { characterAdded, humanoidDied }
local playerConnections: { [number]: { characterAdded: RBXScriptConnection?, humanoidDied: RBXScriptConnection? } } = {}

local function disconnectPlayerConnections(userId: number)
	local conns = playerConnections[userId]
	if not conns then
		return
	end

	if conns.characterAdded ~= nil then
		conns.characterAdded:Disconnect()
	end
	if conns.humanoidDied ~= nil then
		conns.humanoidDied:Disconnect()
	end

	playerConnections[userId] = nil
end

local function resetPlayerState(player: Player)
	for _, key in pairs(StateMeta.StateKeys) do
		State.set(key, player, StateMeta.StateDefs[key].default)
	end
	State.set(StateMeta.StateKeys.InGame, player, true)
end

local function setupCharacterLifecycle(player: Player)
	local userId = player.UserId

	if not playerConnections[userId] then
		playerConnections[userId] = {}
	end

	local characterConn = player.CharacterAdded:Connect(function(character)
		State.set(StateMeta.StateKeys.CharacterAlive, player, true)

		local humanoid = character:WaitForChild("Humanoid")

		local humanoidDiedConn
		humanoidDiedConn = humanoid.Died:Connect(function()
			if player.Character ~= character then
				return
			end

			State.setBatch(player, {
				[StateMeta.StateKeys.CharacterAlive] = false,
				[StateMeta.StateKeys.StandEquipped] = false,
				[StateMeta.StateKeys.Punching] = false,
				[StateMeta.StateKeys.Combo] = 0,
				[StateMeta.StateKeys.LastPunch] = 0,
				[StateMeta.StateKeys.AttackId] = 0,
				[StateMeta.StateKeys.Sprinting] = false,
				[StateMeta.StateKeys.Stunned] = false,
			})

			humanoidDiedConn:Disconnect()
			if playerConnections[userId] then
				playerConnections[userId].humanoidDied = nil
			end
		end)

		if playerConnections[userId] then
			playerConnections[userId].humanoidDied = humanoidDiedConn
		end
	end)

	if playerConnections[userId] then
		playerConnections[userId].characterAdded = characterConn
	end
end

function StateManager:KnitInit()
	-- Enable all state keys
	for _, key in pairs(StateMeta.StateKeys) do
		State.enable(key)
	end

	Players.PlayerAdded:Connect(function(player)
		disconnectPlayerConnections(player.UserId)
		resetPlayerState(player)
		setupCharacterLifecycle(player)
	end)

	Players.PlayerRemoving:Connect(function(player)
		State.set(StateMeta.StateKeys.InGame, player, false)
		disconnectPlayerConnections(player.UserId)
	end)

	State.start()
end

return StateManager
