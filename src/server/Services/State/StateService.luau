local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local State = require(ReplicatedStorage.Shared.Modules.State.State)
local StateMeta = require(ReplicatedStorage.Shared.Modules.State.Meta)

local StateService = {
	Name = "StateService",
}

local playerConnections = {} -- [userId] = { RBXScriptConnection }

local function cleanupPlayerById(userId)
	local conns = playerConnections[userId]

	if not conns then
		return
	end

	for _, conn in pairs(conns) do
		if conn then
			conn:Disconnect()
		end
	end

	playerConnections[userId] = nil
end

local function cleanupPlayer(player)
	if not player then
		return
	end

	cleanupPlayerById(player.UserId)
end

function StateService:KnitInit()
	for _, key in StateMeta.StateKeys do
		State.enable(key)
	end

	Players.PlayerAdded:Connect(function(player)
		cleanupPlayer(player)

		playerConnections[player.UserId] = {}

		for _, key in StateMeta.StateKeys do
			State.set(key, player, StateMeta.StateDefs[key].default)
		end

		State.set("InGame", player, true)

		local characterConn
		local diedConn

		characterConn = player.CharacterAdded:Connect(function(character)
			if diedConn then
				diedConn:Disconnect()
				diedConn = nil
			end

			State.set("CharacterAlive", player, true)

			local humanoid = character:WaitForChild("Humanoid")

			diedConn = humanoid.Died:Connect(function()
				State.set("CharacterAlive", player, false)
				State.set("Punching", player, false)
			end)

			table.insert(playerConnections[player.UserId], diedConn)
		end)

		table.insert(playerConnections[player.UserId], characterConn)
	end)

	Players.PlayerRemoving:Connect(function(player)
		State.set("InGame", player, false)
		cleanupPlayer(player)
	end)

	State.start()
end

return StateService
