-- StandEquipManager (ModuleScript — Server/Modules/StandEquip)

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local State = require(ReplicatedStorage.Shared.State.State)
local Meta = require(ReplicatedStorage.Shared.State.Meta)

local Manager = {}

local initialized: { [Player]: boolean } = {}

function Manager.Init(player: Player)
	if initialized[player] then
		return
	end
	initialized[player] = true
	State.set(Meta.StateKeys.StandEquipped, player, false)
end

function Manager.Cleanup(player: Player)
	initialized[player] = nil
end

function Manager.IsEquipped(player: Player): boolean
	return State.get(Meta.StateKeys.StandEquipped, player) == true
end

function Manager.Toggle(player: Player): boolean
	local current = Manager.IsEquipped(player)
	local next = not current
	State.set(Meta.StateKeys.StandEquipped, player, next)
	print("State.get after set:", State.get(Meta.StateKeys.StandEquipped, player))
	return next
end

function Manager.Set(player: Player, Value)
	State.set(Meta.StateKeys.StandEquipped, player, Value)
end

return Manager
