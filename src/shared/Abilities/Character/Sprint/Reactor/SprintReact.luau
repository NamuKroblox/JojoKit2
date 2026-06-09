-- SprintReaction.lua  (ReactionRegistry — Reactor)
-- Owns every mechanical and visual consequence of sprint state changes.
--
-- Server  → authoritative WalkSpeed; the server always owns this value.
--           Prevents exploits where the client writes an arbitrary speed.
--
-- Client  → local player: drives WalkSpeed + AnimDriver (event-based, no polling).
--           remote players: drives WalkSpeed; animation auto-replicates via Roblox.
--
-- Replaces SprintListener.lua entirely — delete that file.

local Players           = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService        = game:GetService("RunService")

local ReactionRegistry = require(ReplicatedStorage.Shared.Registration.Registries.ReactionRegistry)
local State            = require(ReplicatedStorage.Shared.State.State)
local Meta             = require(ReplicatedStorage.Shared.State.Meta)
local SprintShared     = require(script.Parent.Parent.Shared.SprintShared)  -- adjust to your layout

local IS_SERVER = RunService:IsServer()
local REACTION  = "SprintReact"

--------------------------------------------------------------------------------
-- SHARED HELPER
--------------------------------------------------------------------------------

local function applyWalkSpeed(character: Model?, enabled: boolean)
	if not character then return end
	local humanoid = character:FindFirstChildOfClass("Humanoid")
	if not humanoid then return end
	humanoid.WalkSpeed = enabled and SprintShared.SPRINT_SPEED or SprintShared.WALK_SPEED
end

--------------------------------------------------------------------------------
-- SERVER
-- validate  — re-checks eligibility at the moment of server execution.
-- Execute   — sets WalkSpeed authoritatively; returns snapshot for broadcast.
--------------------------------------------------------------------------------
if IS_SERVER then

	ReactionRegistry:register(REACTION, {

		validate = function(sender: Player, payload: any, seq: number)
			if not State.get(Meta.StateKeys.CharacterAlive, sender) then
				return false, "dead"
			end
			if not sender.Character then
				return false, "no_character"
			end
			local humanoid = sender.Character:FindFirstChildOfClass("Humanoid")
			if not humanoid then
				return false, "no_humanoid"
			end
			return true
		end,

		Execute = function(sender: Player, payload: any, seq: number)
			local enabled = payload and payload.enabled == true
			applyWalkSpeed(sender.Character, enabled)
			return SprintShared.buildSnapshot(enabled)
		end,
	})

	--------------------------------------------------------------------------------
	-- CLIENT
	--------------------------------------------------------------------------------
else

	local Knit        = require(ReplicatedStorage.Packages.knit)
	local localPlayer = Players.LocalPlayer

	-- ──────────────────────────────────────────────────────────────────────────
	-- AnimDriver
	-- Event-driven: reacts to the exact three signals that change sprint
	-- animation eligibility. Replaces the RenderStepped loop in SprintListener.
	--
	--   Running         → velocity started / stopped
	--   FloorMaterial   → landed / left ground
	--   Health          → died mid-sprint
	--
	-- Evaluates immediately on construction so the visual is instant.
	-- destroy() disconnects all signals and issues a clean blend-out.
	-- ──────────────────────────────────────────────────────────────────────────

	local ANIM_KEY    = "character"
	local ANIM_SLOT   = 0
	local ANIM_NAME   = "Character.Sprint"
	local BLEND_OUT   = 0.15
	local MOVE_THRESH = 0.1

	local function shouldAnimate(h: Humanoid): boolean
		return h.Health > 0
			and h.MoveDirection.Magnitude > MOVE_THRESH
			and h.FloorMaterial ~= Enum.Material.Air
	end

	local AnimDriver   = {}
	AnimDriver.__index = AnimDriver

	function AnimDriver.new(humanoid: Humanoid, ctrl: any)
		local self  = setmetatable({}, AnimDriver)
		self._h       = humanoid
		self._ctrl    = ctrl
		self._conns   = {}
		self._playing = false   -- ← new: track play state locally

		local function update()
			if shouldAnimate(humanoid) then
				if not self._playing then          -- ← only start when actually stopped
					self._playing = true
					ctrl:play("sprint", ANIM_KEY, ANIM_SLOT, ANIM_NAME, {
						loop     = true,
						priority = Enum.AnimationPriority.Movement,
					})
				end
				-- already playing → leave it running, no restart
			else
				if self._playing then              -- ← only stop when actually playing
					self._playing = false
					ctrl:stop(ANIM_KEY, ANIM_SLOT, BLEND_OUT)
				end
			end
		end

		self._conns[1] = humanoid.Running:Connect(update)
		self._conns[2] = humanoid:GetPropertyChangedSignal("FloorMaterial"):Connect(update)
		self._conns[3] = humanoid:GetPropertyChangedSignal("Health"):Connect(update)

		update()
		return self
	end

	function AnimDriver:destroy()
		for _, c in self._conns do c:Disconnect() end
		table.clear(self._conns)
		self._playing = false
		self._ctrl:stop(ANIM_KEY, ANIM_SLOT, BLEND_OUT)
	end
	
	

	-- ──────────────────────────────────────────────────────────────────────────
	-- Local state
	-- Single entry-point for all local transitions. Always tears down the
	-- existing driver first — no partial cleanup, no state races.
	-- ──────────────────────────────────────────────────────────────────────────

	local currentDriver: typeof(AnimDriver.new(nil :: any, nil :: any))? = nil

	local function applyLocalState(enabled: boolean)
		-- 1. WalkSpeed — synchronous, no frame delay
		applyWalkSpeed(localPlayer.Character, enabled)

		-- 2. AnimDriver — destroy first, then recreate if enabling
		if currentDriver then
			currentDriver:destroy()
			currentDriver = nil
		end

		if not enabled then return end

		local AnimationController = Knit.GetController("AnimationController")
		local ctrl = AnimationController
			and AnimationController.getByUserId(localPlayer.UserId)
		if not ctrl then
			warn("[SprintReaction] AnimationController not ready")
			return
		end

		local char = localPlayer.Character
		if not char then return end

		local h = char:FindFirstChildOfClass("Humanoid")
		if not h or h.Health <= 0 then return end

		currentDriver = AnimDriver.new(h, ctrl)
	end

	-- ──────────────────────────────────────────────────────────────────────────
	-- Reaction handlers
	-- ──────────────────────────────────────────────────────────────────────────

	ReactionRegistry:register(REACTION, {

		-- Fires the frame the player presses/releases sprint — zero-latency.
		-- Drives WalkSpeed + animation optimistically before the server responds.
		onPredict = function(payload: { enabled: boolean }, _seq: number): boolean
			applyLocalState(payload.enabled == true)
			return true
		end,

		-- Fires after the server confirms. Re-applies to sync the driver with
		-- ground truth — e.g. the character respawned between predict and confirm.
		-- Cheap: AnimDriver construction is O(1) and safe to recreate.
		onSource = function(
			_ctx: ReactionRegistry.ReactionContext,
			state: { enabled: boolean }
		)
			applyLocalState(state.enabled == true)
		end,

		-- Server rejected (dead, exploit, blocked status, etc).
		-- Tears down the driver and reverts WalkSpeed.
		onReconcile = function(
			state:   { enabled: boolean }?,
			_reason: string?,
			_seq:    number
		)
			if not state then
				applyLocalState(false)
			end
		end,

		-- Fires on all clients observing another player's sprint state change.
		-- Roblox replicates AnimationTracks from the owning client automatically,
		-- so only WalkSpeed needs to be applied here.
		--
		-- NOTE: ctx.player is the player whose sprint changed. Adjust the field
		-- name if your ReactionContext exposes it differently (e.g. ctx.sender).
		onObserver = function(
			ctx:   ReactionRegistry.ReactionContext,
			state: { enabled: boolean }
		)
			local sender = ctx and ctx.player
			if not sender or sender == localPlayer then return end
			applyWalkSpeed(sender.Character, state.enabled == true)
		end,
	})

end

return {}