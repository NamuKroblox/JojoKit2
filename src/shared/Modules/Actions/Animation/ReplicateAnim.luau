local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Registry = require(ReplicatedStorage.Shared.Modules.Replication.ReplicationRegistry)
local ActionTemplate = require(ReplicatedStorage.Shared.Modules.Replication.ActionTemplate)
local State = require(ReplicatedStorage.Shared.Modules.State.State)
local Meta = require(ReplicatedStorage.Shared.Modules.State.Meta)

local IS_SERVER = RunService:IsServer()

local ACTION = "ReplicateAnim"

local DEBUG = true

local function log(tag, ...)
	if DEBUG then
		print(("[SPRINT:%s]"):format(tag), ...)
	end
end

if IS_SERVER then
	Players.PlayerRemoving:Connect(function(player) end)

	Registry.register(ACTION, {

		validate = function(player, payload, clientSeq) end,

		Execute = function(player, payload, clientSeq) end,
	})
else
	local localPlayer = Players.LocalPlayer

	Registry.register(ACTION, {

		onPredict = function(payload, clientSeq) end,

		onReconcile = function(state, reason, clientSeq) end,

		onBroadcast = function(senderUserId, state) end,
	})
end

return {}
