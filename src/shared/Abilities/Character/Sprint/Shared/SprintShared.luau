-- SprintShared.lua
-- Shared constants and utilities for the Sprint action.
-- Mirrors PunchShared: pure data, no side-effects.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local State = require(ReplicatedStorage.Shared.State.State)
local Meta  = require(ReplicatedStorage.Shared.State.Meta)

local SprintShared = {}

SprintShared.WALK_SPEED   = 16
SprintShared.SPRINT_SPEED = 23

--------------------------------------------------------------------------------
-- buildSnapshot
-- Constructs the canonical sprint state object passed through the pipeline.
--------------------------------------------------------------------------------
function SprintShared.buildSnapshot(enabled: boolean): { enabled: boolean }
	return { enabled = enabled }
end

--------------------------------------------------------------------------------
-- semanticMatch
-- True when two snapshots resolve to the same logical outcome.
-- Used by onReconcile to decide whether a correction is needed.
--------------------------------------------------------------------------------
function SprintShared.semanticMatch(
	a: { enabled: boolean },
	b: { enabled: boolean }
): boolean
	return a.enabled == b.enabled
end

--------------------------------------------------------------------------------
-- applySprintState
-- Writes sprint enabled flag into the shared State system.
--------------------------------------------------------------------------------
function SprintShared.applySprintState(player: Player, snapshot: { enabled: boolean })
	State.set(Meta.StateKeys.Sprinting, player, snapshot.enabled)
end

--------------------------------------------------------------------------------
-- resetSprintState
-- Forces sprint off. Called on hard resets and reconcile failures.
--------------------------------------------------------------------------------
function SprintShared.resetSprintState(player: Player)
	SprintShared.applySprintState(player, { enabled = false })
end

return SprintShared