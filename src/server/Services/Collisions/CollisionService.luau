local CollisionService = {
	Name = "CollisioNService",
	Client = {},
}

function CollisionService:KnitStart()
	game.Players.PlayerAdded:Connect(function(player: Player)
		player.CharacterAdded:Connect(function(Character: Model)
			for _, part in Character:GetDescendants() do
				if part:IsA("BasePart") then
					part.CollisionGroup = "Character"
				end
			end
		end)
	end)
end

return CollisionService
