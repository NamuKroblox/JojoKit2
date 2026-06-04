local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local State = require(ReplicatedStorage.Shared.State.State)
local Meta = require(ReplicatedStorage.Shared.State.Meta)

local SprintListener = {}

local MOVE_THRESHOLD = 0.1

local function shouldSprint(sprinting: boolean, humanoid: Humanoid): boolean
	if not sprinting then
		return false
	end

	if humanoid.MoveDirection.Magnitude <= MOVE_THRESHOLD then
		return false
	end

	if humanoid.FloorMaterial == Enum.Material.Air then
		return false
	end

	return true
end

function SprintListener.start(controller)
	local player = Players.LocalPlayer

	local humanoidConn
	local stateConn
	local sprintConn
	local renderConn

	local lastActive = nil
	local currentHumanoid = nil

	local function cleanupConnections()
		if humanoidConn then
			humanoidConn:Disconnect()
			humanoidConn = nil
		end

		if stateConn then
			stateConn:Disconnect()
			stateConn = nil
		end

		if sprintConn then
			sprintConn()
			sprintConn = nil
		end

		if renderConn then
			renderConn:Disconnect()
			renderConn = nil
		end

		currentHumanoid = nil
		lastActive = nil
	end

	local function stopSprint()
		controller:stop("character", 0, 0.15)
	end

	local function playSprint()
		controller:play("sprint", "character", 0, "Character.Sprint", {
			loop = true,
			priority = Enum.AnimationPriority.Movement,
		})
	end

	local function bindCharacter(_, character: Model)
		cleanupConnections()

		if not character then
			return
		end

		local humanoid = character:FindFirstChildOfClass("Humanoid")

		if not humanoid then
			warn("[SprintListener] Missing humanoid")
			return
		end

		currentHumanoid = humanoid

		local sprinting = State.get(Meta.StateKeys.Sprinting, player) == true

		local function update()
			if currentHumanoid ~= humanoid then
				return
			end

			if humanoid.Health <= 0 then
				if lastActive ~= false then
					lastActive = false
					stopSprint()
				end

				return
			end

			local active = shouldSprint(sprinting, humanoid)

			if active == lastActive then
				return
			end

			lastActive = active

			if active then
				playSprint()
			else
				stopSprint()
			end
		end

		humanoidConn = humanoid.Running:Connect(function()
			update()
		end)

		stateConn = humanoid:GetPropertyChangedSignal("FloorMaterial"):Connect(function()
			update()
		end)

		sprintConn = State.listen(Meta.StateKeys.Sprinting, function(targetPlayer, value, _, isReplay)
			if isReplay then
				return
			end

			if targetPlayer ~= player then
				return
			end

			sprinting = value == true

			update()
		end)

		renderConn = RunService.RenderStepped:Connect(function()
			update()
		end)

		update()
	end

	controller:onAttach("character", bindCharacter)

	controller:listen("sprint_listener_cleanup", function()
		cleanupConnections()
		stopSprint()
	end)
end

return SprintListener
