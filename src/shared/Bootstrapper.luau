-- Bootstrapper (ModuleScript — ReplicatedStorage/Shared/Modules)


local Bootstrapper = {}

local function InitDataService(isClient)
	local DataServiceMod
	local Template = require(game.ReplicatedStorage.Shared.Data.Configs.DataConfig)
	if isClient then
		 DataServiceMod = require(game.ReplicatedStorage.Packages.DataService).client
		DataServiceMod:init()
	else

		 DataServiceMod = require(game.ReplicatedStorage.Packages.DataService).server
		DataServiceMod:init({
			template = Template
		})
	end
	
	
end

local function InitStates()
	local StateModule : ModuleScript = require(game.ReplicatedStorage.Shared.State.State)
	local Meta : ModuleScript = require(game.ReplicatedStorage.Shared.State.Meta)
	
	for _, key in Meta.StateKeys do
		StateModule.enable(key)
	end

	StateModule.start()
end

local function ScanAbilities(dir: Instance)
	for _, obj in dir:GetDescendants() do
		if not obj:IsA("ModuleScript") then
			continue
		end

		local parent = obj.Parent
		if not parent then
			continue
		end

		if parent.Name == "Actor" or parent.Name == "Reactor" then
			require(obj)
		end
	end
end
local function scanKnit(dir: Instance, filter: string, create: (any) -> ())
	for _, module in dir:GetDescendants() do
		if not module:IsA("ModuleScript") then
			continue
		end
		if not module.Name:find(filter) then
			continue
		end
		local ok, result = pcall(require, module)
		if not ok then
			warn("[Bootstrapper] Failed to require:", module:GetFullName(), "-", result)
			continue
		end
		local ok2, err2 = pcall(create, result)
		if not ok2 then
			warn("[Bootstrapper] Failed to create:", module:GetFullName(), "-", err2)
		end
	end
end

local function ScanRegistries(Dir)
	for _, registry in Dir:GetChildren() do
		require(registry)
	end
end

function Bootstrapper.start(config: {
	abilities: Instance?,
	services: { Instance }?,
	controllers: { Instance }?,
	Registries: Instance?,
	isClient : boolean,
	knit: any,
	chrono: any,
	})
	

	InitDataService(config.isClient)
	InitStates()
	if config.services then
		for _, dir in config.services do
			scanKnit(dir, "Service", function(result)
				config.knit.CreateService(result)
			end)
		end
	end

	if config.controllers then
		for _, dir in config.controllers do
			scanKnit(dir, "Controller", function(result)
				config.knit.CreateController(result)
			end)
		end
	end

	config.knit.Start():catch(warn)
	config.chrono.Start()
	
	if config.Registries then
		ScanRegistries(config.Registries)
	end

	if config.abilities then
		ScanAbilities(config.abilities)
	end
end

return Bootstrapper
