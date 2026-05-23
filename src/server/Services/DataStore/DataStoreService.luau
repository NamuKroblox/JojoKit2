-- DataStoreService.lua

local Players = game:GetService("Players")
local DataStoreServiceAPI = game:GetService("DataStoreService")

local DataManager = require(game.ServerScriptService.Server.Modules.Data.DataManager)
local ServerStore = require(game.ServerScriptService.Server.Modules.Data.ServerStore)

local DATASTORE = DataStoreServiceAPI:GetDataStore("PLAYER_DATA_V1")

local SAVE_INTERVAL = 60 -- seconds between autosaves
local MAX_LOAD_ATTEMPTS = 3
local MAX_SAVE_ATTEMPTS = 5
local INITIAL_BACKOFF = 1

local Dirty = {}

local DataStoreService = {
	Name = "DataStoreService",
	Client = {},
}

local function getKey(player: Player)
	return tostring(player.UserId) .. "_DATA"
end

local function loadPlayer(player: Player)
	local attempts = 0
	local success, result
	while attempts < MAX_LOAD_ATTEMPTS do
		attempts = attempts + 1
		success, result = pcall(function()
			return DATASTORE:GetAsync(getKey(player))
		end)
		if success then
			break
		end
		warn(
			string.format(
				"[DataStore] Failed loading %s (attempt %d): %s",
				tostring(player.Name),
				attempts,
				tostring(result)
			)
		)
		wait(INITIAL_BACKOFF * attempts)
	end

	if not success then
		warn(
			string.format(
				"[DataStore] Failed loading %s after %d attempts, kicking",
				tostring(player.Name),
				MAX_LOAD_ATTEMPTS
			)
		)
		if player and player:IsDescendantOf(Players) then
			player:Kick("Data failed to load. Rejoin to try again.")
		end
		return
	end

	local deserialized = DataManager.Deserialize(result)
	if not deserialized then
		-- fallback to empty structure if DataManager doesn't provide a default creator
		local defaultCreator = rawget(DataManager, "Default")
		deserialized = typeof(defaultCreator) == "function" and defaultCreator() or {}
	end

	ServerStore[player.UserId] = deserialized
end

local function savePlayer(player: Player, providedData)
	local data = providedData or ServerStore[player.UserId]
	if not data then
		return
	end

	-- Mark as clean immediately to avoid duplicate saves; will be re-marked dirty if modified again.
	Dirty[player.UserId] = nil

	local serialized = DataManager.Serialize(data)
	local attempts = 0
	local success, err
	local key = getKey(player)
	while attempts < MAX_SAVE_ATTEMPTS do
		attempts = attempts + 1
		success, err = pcall(function()
			DATASTORE:UpdateAsync(key, function()
				return serialized
			end)
		end)
		if success then
			break
		end
		warn(
			string.format(
				"[DataStore] Failed saving %s (attempt %d): %s",
				tostring(player.Name),
				attempts,
				tostring(err)
			)
		)
		task.wait(INITIAL_BACKOFF * attempts)
	end

	if not success then
		warn(string.format("[DataStore] Failed saving %s after %d attempts", tostring(player.Name), MAX_SAVE_ATTEMPTS))
	end
end

function DataStoreService:GetBuffer(player: Player): buffer?
	return ServerStore[player.UserId]
end

function DataStoreService:Set(player: Player, key: string, value: number)
	local Buffer = self:GetBuffer(player)

	if not Buffer then
		return
	end

	DataManager.Set(Buffer, key, value)
	-- mark dirty for autosave
	Dirty[player.UserId] = true
end

function DataStoreService:Get(player: Player, key: string): number
	local Buffer = self:GetBuffer(player)

	if not Buffer then
		return 0
	end

	return DataManager.Get(Buffer, key)
end

function DataStoreService:KnitInit()
	Players.PlayerAdded:Connect(function(player)
		-- load in a separate thread to avoid blocking
		task.spawn(function()
			loadPlayer(player)
		end)
	end)

	Players.PlayerRemoving:Connect(function(player)
		-- ensure we save player's data before removing from memory
		local data = ServerStore[player.UserId]
		if data then
			savePlayer(player, data)
		end
		ServerStore[player.UserId] = nil
		Dirty[player.UserId] = nil
	end)

	-- Autosave loop for dirty buffers to reduce churn and throttling
	task.spawn(function()
		while true do
			task.wait(SAVE_INTERVAL)
			for userId, _ in pairs(Dirty) do
				local player = Players:GetPlayerByUserId(userId)
				if player and ServerStore[userId] then
					-- save in a safe thread
					task.spawn(function()
						savePlayer(player, ServerStore[userId])
					end)
				end
			end
		end
	end)

	game:BindToClose(function()
		local pending = Players:GetPlayers()
		for _, player in ipairs(pending) do
			local data = ServerStore[player.UserId]
			if data then
				savePlayer(player, data)
				-- clear to allow GC
				ServerStore[player.UserId] = nil
			end
		end
	end)
end

return DataStoreService
