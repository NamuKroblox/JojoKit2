-- Bootstrapper (ModuleScript — ReplicatedStorage/Shared/Modules)

local Bootstrapper = {}

local function scanActions(dir: Instance)
	for _, module in dir:GetDescendants() do
		if not module:IsA("ModuleScript") then
			continue
		end
		local ok, err = pcall(require, module)
		if not ok then
			warn("[Bootstrapper] Action failed:", module:GetFullName(), "-", err)
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

function Bootstrapper.start(config: {
	actions: { Instance }?,
	services: { Instance }?,
	controllers: { Instance }?,
	knit: any,
	chrono: any,
})
	if config.actions then
		for _, dir in config.actions do
			scanActions(dir)
		end
	end

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
end

return Bootstrapper
