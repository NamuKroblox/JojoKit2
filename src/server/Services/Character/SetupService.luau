

local SetupService = {
	Name = "SetupService",
	Client = {}
}

function SetupService:SetupCollisions(character : Model)
	
	for _, part in character:GetDescendants() do
				if part:IsA("BasePart") then
					part.CollisionGroup = "Character"
				end
			end
	
end


function SetupService:KnitStart()
	game.Players.PlayerAdded:Connect(function(player: Player)
		player.CharacterAdded:Connect(function(Character: Model)
			self:SetupCollisions(Character)
		end)
	end)
end

return SetupService
