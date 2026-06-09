local DataService = require(game.ReplicatedStorage.Packages.DataService).server

local DataStoreService = {
	Name = "DataStoreService",
	Client = {},
	ValidKeys = {
		"Money",
		"Kills",
		"Stand"
	},
}


function DataStoreService:KnitStart()
	
	game.Players.PlayerAdded:Connect(function(player)
		local leaderstats = Instance.new("Folder")
		leaderstats.Name = "leaderstats"
		leaderstats.Parent = player
		
		DataService:waitForData(player)
		
		local kills = Instance.new("IntValue")
		kills.Name = "Kills"
		kills.Parent = leaderstats
		kills.Value = DataService:get(player,"Kills")
		
		local money = Instance.new("IntValue")
		money.Name = "Money"
		money.Parent = leaderstats
		money.Value = DataService:get(player,"Money")
	end)
	

end


function DataStoreService.Client:SetData(player,path,value)
	DataService:set(player,path,value)
end



return DataStoreService