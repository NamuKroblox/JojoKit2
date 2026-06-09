-- SprintAction.lua  (ReplicationRegistry — Actor)
-- Pure state manager. No WalkSpeed, no animation — those live in SprintReaction.
--
-- Server  → validate eligibility, write Sprinting state, return snapshot.
-- Client  → predict state locally, reconcile against server truth,
--           broadcast state to remote characters.
--
-- Every mechanical/visual consequence is handled by SprintReaction.

local Players           = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService        = game:GetService("RunService")

local Registry       = require(ReplicatedStorage.Shared.Registration.Registries.ReplicationRegistry)
local ActionTemplate = require(ReplicatedStorage.Shared.Helper.Replication.ActionTemplate)
local State          = require(ReplicatedStorage.Shared.State.State)
local Meta           = require(ReplicatedStorage.Shared.State.Meta)
local SprintShared   = require(script.Parent.Parent.Shared.SprintShared)  -- adjust to your layout

local IS_SERVER = RunService:IsServer()
local ACTION    = "Sprint"

--------------------------------------------------------------------------------
-- SERVER
--------------------------------------------------------------------------------
if IS_SERVER then

	local t = ActionTemplate.server()

	local function validate(player: Player, payload: { enabled: boolean })
		if not State.get(Meta.StateKeys.CharacterAlive, player) then
			return false, "dead"
		end
		local humanoid = player.Character
			and player.Character:FindFirstChildOfClass("Humanoid")
		if not humanoid then
			return false, "no_humanoid"
		end
		-- Anti-exploit: WalkSpeed must not already exceed the sprint cap.
		if payload.enabled and humanoid.WalkSpeed > SprintShared.SPRINT_SPEED then
			return false, "exploit_speed"
		end
		return true, nil
	end

	Players.PlayerRemoving:Connect(function(player)
		t:cleanup(player)
	end)

	Registry:register(ACTION, {

		validate = function(player, payload, clientSeq)
			return t:validate(player, clientSeq, function()
				return validate(player, payload)
			end)
		end,

		Execute = function(player, payload, clientSeq)
			t:advance(player, clientSeq)
			local snapshot = SprintShared.buildSnapshot(payload.enabled == true)
			SprintShared.applySprintState(player, snapshot)
			snapshot.consequences = {
				{
					type   = "reaction",
					target = "observers",   -- source already handled via onPredict
					id     = "SprintReact",
					payload = {
						senderUserId = player.UserId,
						targetKey    = tostring(player.UserId),
						isPlayer     = true,
						enabled = payload.enabled
					},
				}
			}
			return snapshot
		end,
	})

	--------------------------------------------------------------------------------
	-- CLIENT
	--------------------------------------------------------------------------------
else

	local t           = ActionTemplate.client()
	local localPlayer = Players.LocalPlayer

	-- Tracks in-flight predictions so reconciliation doesn't clobber state
	-- while newer inputs are already predicted ahead of the server.
	local pending: { [number]: boolean } = {}
	local sprintMemory = false

	local function canSprint(): boolean
		return State.get(Meta.StateKeys.CharacterAlive, localPlayer) == true
	end

	Registry:register(ACTION, {

		-- State only. WalkSpeed + animation are applied by SprintReaction.onPredict,
		-- which fires the same frame as this callback.
		onPredict = function(payload: { enabled: boolean }, clientSeq: number)
			if not canSprint() then
				return false
			end
			local snapshot    = SprintShared.buildSnapshot(payload.enabled == true)
			pending[clientSeq] = snapshot.enabled
			sprintMemory       = snapshot.enabled
			SprintShared.applySprintState(localPlayer, snapshot)
			
			snapshot.consequences = {
				{
					type = "reaction",
					target = "source",
					id = "SprintReact",
					payload = {
						senderUserId = localPlayer.UserId,
						targetKey    = tostring(localPlayer.UserId),
						isPlayer     = true,
						enabled = sprintMemory
					}
				},
				
			}
			return snapshot
		end,

		onReconcile = function(
			state:     { enabled: boolean }?,
			reason:    string?,
			clientSeq: number
		)
			pending[clientSeq] = nil

			if not state then
				-- Server rejected entirely. Reset if no newer predictions remain.
				if next(pending) == nil then
					sprintMemory = false
					SprintShared.resetSprintState(localPlayer)
				end
				return
			end

			t:reconcile(clientSeq, state,
				function(serverState)
					-- A newer prediction is still in flight — let it resolve first.
					if next(pending) ~= nil then return end
					if not SprintShared.semanticMatch({ enabled = sprintMemory }, serverState) then
						sprintMemory = serverState.enabled
						SprintShared.applySprintState(localPlayer, serverState)
					end
				end,
				function()
					if next(pending) == nil then
						sprintMemory = false
						SprintShared.resetSprintState(localPlayer)
					end
				end
			)
		end,

		-- Replicates state to remote characters.
		-- WalkSpeed for these characters is applied by SprintReaction.onObserver.
		onBroadcast = function(senderUserId: number, state: { enabled: boolean })
			local sender = Players:GetPlayerByUserId(senderUserId)
			if not sender or sender == localPlayer then return end
			SprintShared.applySprintState(sender, state)
		end,
	})

end

return {}