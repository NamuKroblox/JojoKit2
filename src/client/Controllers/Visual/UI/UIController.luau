local Icon = require(game.ReplicatedStorage.Packages.topbarplus)
local Knit = require(game.ReplicatedStorage.Packages.knit)

local UIController = {
	Name = "UIController"
}



function UIController:KnitStart()
	local Stand_Select_Icon = Icon.new() 
	Stand_Select_Icon:setName("Stand_Select_Icon")
	Stand_Select_Icon:setLabel("Stands")
	Stand_Select_Icon:setImage(18854794412)
	Stand_Select_Icon:setCaption("View Stands to Select")
	Stand_Select_Icon:modifyChildTheme({
		"Widget","DesiredWidth",100
	},
	
	{
		"Widget","DesiredHeight",100
	})

	local DataStoreService = Knit.GetService("DataStoreService")
	
	Stand_Select_Icon:setDropdown({
		Stand_SP = Icon.new() 
	
		:setName("Stand_SP")
		
		:setLabel("Star Platinum")
		:bindEvent("selected",function()
				DataStoreService:SetData("Stand","StarPlatinum")
		end),
		
		
		Stand_KC = Icon.new() 
		:setName("Stand_KC")
		:setLabel("King Crimson")
			:bindEvent("selected",function()
				DataStoreService:SetData("Stand","KingCrimson")
			end),
		
		Stand_TW = Icon.new() 
		:setName("Stand_TW")
		:setLabel("The World")
			:bindEvent("selected",function()
				DataStoreService:SetData("Stand","TheWorld")
			end),
	
		Stand_CD = Icon.new() 
			:setName("Stand_CD")
			:setLabel("Crazy Diamond")
			:bindEvent("selected",function()
				DataStoreService:SetData("Stand","CrazyDiamond")
			end),
		
		Stand_WR = Icon.new() 
			:setName("Stand_WR")
			:setLabel("Weather Report")
			:bindEvent("selected",function()
				DataStoreService:SetData("Stand","WeatherReport")
			end),
		
	})
	
end

return UIController
