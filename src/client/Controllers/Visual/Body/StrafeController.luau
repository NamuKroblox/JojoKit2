-- Layered Strafing + Forward Lean (R6 + R15)
-- Client-only, visual-only, Shift Lock aware

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")

local player = Players.LocalPlayer
local camera = workspace.CurrentCamera

-- ========= CONFIG =========
local LEG_SIDE_TILT_MAX = math.rad(12)
local TORSO_SIDE_TILT_MAX = math.rad(5)

local LEG_FWD_TILT_MAX = math.rad(12)
local TORSO_FWD_TILT_MAX = math.rad(5)

local SMOOTHNESS = 12
local RETURN_SPEED = 14
-- ==========================

local character
local humanoid
local root

local legMotor
local torsoMotor

local legBaseC0
local torsoBaseC0

local legSideTilt = 0
local torsoSideTilt = 0
local legForwardTilt = 0
local torsoForwardTilt = 0

local owned = false

local rootStrafeMotor
local rootStrafeBaseC0
local rootStrafeOffset = 0

local ROOT_STRAFE_MAX = 0.8 -- studs of lateral shift

local StrafeController = {
	Name = "StrafeController",
}

----------------------------------------------------

local function setupCharacter(char)
	character = char
	humanoid = char:WaitForChild("Humanoid")
	root = char:WaitForChild("HumanoidRootPart")

	if humanoid.RigType == Enum.HumanoidRigType.R15 then
		local lowerTorso = char:WaitForChild("LowerTorso")
		local upperTorso = char:WaitForChild("UpperTorso")

		legMotor = lowerTorso:WaitForChild("Waist")
		torsoMotor = upperTorso:WaitForChild("Waist")
	else
		local torso = char:WaitForChild("Torso")

		legMotor = root:WaitForChild("RootJoint")
		torsoMotor = torso:WaitForChild("Neck")
	end

	legBaseC0 = legMotor.C0
	torsoBaseC0 = torsoMotor.C0

	legSideTilt = 0
	torsoSideTilt = 0
	legForwardTilt = 0
	torsoForwardTilt = 0
end

----------------------------------------------------

function StrafeController:KnitStart()
	player.CharacterAdded:Connect(setupCharacter)
	if player.Character then
		setupCharacter(player.Character)
	end

	
	RunService.RenderStepped:Connect(function(dt)
		if not character or not humanoid or not legMotor or not torsoMotor then
			return
		end

		local shiftLocked = UserInputService.MouseBehavior == Enum.MouseBehavior.LockCenter

		local targetLegSide = 0
		local targetTorsoSide = 0
		local targetLegForward = 0
		local targetTorsoForward = 0
		local targetRootOffset = 0

		if shiftLocked then
			local moveDir = humanoid.MoveDirection

			if moveDir.Magnitude > 0.01 then
				local camCF = camera.CFrame

				local right = Vector3.new(camCF.RightVector.X, 0, camCF.RightVector.Z).Unit
				local forward = Vector3.new(camCF.LookVector.X, 0, camCF.LookVector.Z).Unit

				local strafe = right:Dot(moveDir)
				local advance = forward:Dot(moveDir)

				targetLegSide = math.clamp(strafe, -1, 1) * LEG_SIDE_TILT_MAX
				targetTorsoSide = math.clamp(strafe, -1, 1) * TORSO_SIDE_TILT_MAX

				targetLegForward = math.clamp(advance, -1, 1) * LEG_FWD_TILT_MAX
				targetTorsoForward = math.clamp(advance, -1, 1) * TORSO_FWD_TILT_MAX

				
			end
		end

		-- Smooth tilt
		local sideSpeed = targetLegSide == 0 and RETURN_SPEED or SMOOTHNESS
		local forwardSpeed = targetLegForward == 0 and RETURN_SPEED or SMOOTHNESS
		local rootSpeed = targetRootOffset == 0 and RETURN_SPEED or SMOOTHNESS

		legSideTilt += (targetLegSide - legSideTilt) * math.clamp(dt * sideSpeed, 0, 1)
		torsoSideTilt += (targetTorsoSide - torsoSideTilt) * math.clamp(dt * sideSpeed, 0, 1)

		legForwardTilt += (targetLegForward - legForwardTilt) * math.clamp(dt * forwardSpeed, 0, 1)
		torsoForwardTilt += (targetTorsoForward - torsoForwardTilt) * math.clamp(dt * forwardSpeed, 0, 1)

		rootStrafeOffset += (targetRootOffset - rootStrafeOffset) * math.clamp(dt * rootSpeed, 0, 1)

		-- Apply leg + torso tilt
		legMotor.C0 = legBaseC0 * CFrame.Angles(legForwardTilt, 0, -legSideTilt)
		torsoMotor.C0 = torsoBaseC0 * CFrame.Angles(torsoForwardTilt, 0, torsoSideTilt)

	end)
end

return StrafeController
