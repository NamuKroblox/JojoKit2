-- State (ModuleScript — ReplicatedStorage/Shared/Modules/State)

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")

local Meta = require(script.Parent.Meta)
local IS_SERVER = RunService:IsServer()
local HRP_TIMEOUT = 10

export type ChangedCallback = (player: Player, value: any, oldValue: any, isReplay: boolean) -> ()

local State = {}

local enabledKeys = {}
local values = {}
local listeners = {}
local trackedPlayers = {}
local playerConns = {}
local spawnTokens = {}

local started = false

local function ensureBucket(player: Player)
	if not values[player] then
		values[player] = {}
	end
end

local function getDef(key: Meta.Key)
	local def = Meta.StateDefs[key]
	if not def then
		warn("[State] Unknown key:", key)
	end
	return def
end

local function validate(key: Meta.Key, value: any): boolean
	local def = getDef(key)
	if not def then
		return false
	end

	if def.validator then
		return def.validator(value)
	end

	if def.type and typeof(value) ~= def.type then
		warn(string.format("[State] '%s' expected %s got %s", key, def.type, typeof(value)))
		return false
	end

	return true
end

local function emit(key: Meta.Key, player: Player, value: any, oldValue: any, isReplay: boolean)
	if not enabledKeys[key] then
		return
	end

	local bucket = listeners[key]
	if not bucket then
		return
	end

	for _, cb in bucket do
		task.spawn(cb, player, value, oldValue, isReplay)
	end
end

local function assign(key: Meta.Key, player: Player, value: any, fire: boolean, isReplay: boolean?)
	ensureBucket(player)

	local store = values[player]
	local old = store[key]

	if old == value then
		return
	end

	store[key] = value

	if fire then
		emit(key, player, value, old, isReplay == true)
	end
end

local function disconnectHumanoid(player: Player)
	local conns = playerConns[player]
	if not conns then
		return
	end

	if conns.humanoidDied then
		conns.humanoidDied:Disconnect()
		conns.humanoidDied = nil
	end
end

local function bindCharacterServer(player: Player, character: Model)
	if not enabledKeys[Meta.StateKeys.CharacterAlive] then
		return
	end

	assign(Meta.StateKeys.CharacterAlive, player, false, true)

	local humanoid = character:FindFirstChildOfClass("Humanoid")
	if not humanoid then
		return
	end

	if humanoid.Health > 0 and player.Character == character then
		assign(Meta.StateKeys.CharacterAlive, player, true, true)
	end

	disconnectHumanoid(player)

	playerConns[player].humanoidDied = humanoid.Died:Connect(function()
		if player.Character ~= character then
			return
		end
		assign(Meta.StateKeys.CharacterAlive, player, false, true)
	end)
end

local function bindCharacterClient(player: Player, character: Model)
	if not enabledKeys[Meta.StateKeys.CharacterAlive] then
		return
	end

	assign(Meta.StateKeys.CharacterAlive, player, false, true)

	spawnTokens[player] = (spawnTokens[player] or 0) + 1
	local token = spawnTokens[player]

	task.spawn(function()
		local humanoid = character:WaitForChild("Humanoid", HRP_TIMEOUT)
		if not humanoid or spawnTokens[player] ~= token or player.Character ~= character then
			return
		end

		local hrp = character:WaitForChild("HumanoidRootPart", HRP_TIMEOUT)
		if not hrp or spawnTokens[player] ~= token or player.Character ~= character then
			return
		end

		if humanoid.Health > 0 then
			assign(Meta.StateKeys.CharacterAlive, player, true, true)
		end

		disconnectHumanoid(player)

		playerConns[player].humanoidDied = humanoid.Died:Connect(function()
			if player.Character ~= character then
				return
			end
			assign(Meta.StateKeys.CharacterAlive, player, false, true)
		end)
	end)
end

local bindCharacter = IS_SERVER and bindCharacterServer or bindCharacterClient

local function trackPlayer(player: Player)
	if trackedPlayers[player] then
		return
	end

	trackedPlayers[player] = true
	playerConns[player] = {}

	assign(Meta.StateKeys.InGame, player, true, enabledKeys[Meta.StateKeys.InGame] == true)

	playerConns[player].characterAdded = player.CharacterAdded:Connect(function(character)
		bindCharacter(player, character)
	end)

	playerConns[player].characterRemoving = player.CharacterRemoving:Connect(function()
		disconnectHumanoid(player)

		if enabledKeys[Meta.StateKeys.CharacterAlive] then
			assign(Meta.StateKeys.CharacterAlive, player, false, true)
		end
	end)

	if player.Character then
		bindCharacter(player, player.Character)
	end
end

local function untrackPlayer(player: Player)
	if not trackedPlayers[player] then
		return
	end

	trackedPlayers[player] = nil
	spawnTokens[player] = nil

	local conns = playerConns[player]
	if conns then
		for _, c in conns do
			if c then
				c:Disconnect()
			end
		end
	end

	playerConns[player] = nil

	local store = values[player]
	if store then
		for key, old in store do
			if enabledKeys[key] then
				local def = Meta.StateDefs[key]
				if def then
					emit(key, player, def.default, old, false)
				end
			end
		end
	end

	values[player] = nil
end

local function replayToCallback(key: Meta.Key, cb: ChangedCallback)
	for player in trackedPlayers do
		local value = State.get(key, player)
		task.spawn(cb, player, value, nil, true)
	end
end

function State.enable(key: Meta.Key)
	if enabledKeys[key] then
		return
	end
	if not getDef(key) then
		return
	end

	enabledKeys[key] = true

	if key == Meta.StateKeys.InGame then
		for player in trackedPlayers do
			assign(key, player, true, false)
		end
	end
end

function State.listen(key: Meta.Key, cb: ChangedCallback)
	State.enable(key)

	listeners[key] = listeners[key] or {}
	table.insert(listeners[key], cb)

	replayToCallback(key, cb)
end

function State.get(key: Meta.Key, player: Player?)
	local target = player or (not IS_SERVER and Players.LocalPlayer or nil)
	if not target then
		return nil
	end

	ensureBucket(target)

	local v = values[target][key]
	if v ~= nil then
		return v
	end

	local def = Meta.StateDefs[key]
	return def and def.default
end

function State.set(key: Meta.Key, player: Player, value: any)
	if not getDef(key) then
		warn(("[State.set] Unknown state key '%s' for player %s"):format(tostring(key), player.Name))
		return
	end

	if not validate(key, value) then
		warn(
			("[State.set] Validation failed for key '%s' on player %s | Value: %s"):format(
				tostring(key),
				player.Name,
				tostring(value)
			)
		)
		return
	end

	assign(key, player, value, true)
end

function State.isEnabled(key: Meta.Key): boolean
	return enabledKeys[key] == true
end

function State.start()
	if started then
		return
	end
	started = true

	Players.PlayerAdded:Connect(trackPlayer)
	Players.PlayerRemoving:Connect(untrackPlayer)

	for _, p in Players:GetPlayers() do
		trackPlayer(p)
	end
end

return State
