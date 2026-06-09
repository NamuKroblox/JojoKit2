local UserInputService = game:GetService("UserInputService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Knit = require(ReplicatedStorage.Packages.knit)
local InputRegistry = require(ReplicatedStorage.Shared.Registration.Registries.InputRegistry)
local _InputBindings = require(script.Parent.InputBindings)

local InputController = { Name = "InputController" }

local contextStack = { "character" }
local ReplicationController = nil
local activeHeld = {}

local function currentContext()
	return contextStack[#contextStack] or "any"
end

function InputController:PushContext(context: string)
	table.insert(contextStack, context)
end

function InputController:PopContext(context: string)
	for i = #contextStack, 1, -1 do
		if contextStack[i] == context then
			table.remove(contextStack, i)
			return
		end
	end
end

function InputController:KnitStart()
	ReplicationController = Knit.GetController("ReplicationController")

	UserInputService.InputBegan:Connect(function(input, gameProcessed)
		if gameProcessed then
			return
		end

		local key = input.KeyCode ~= Enum.KeyCode.Unknown and input.KeyCode or input.UserInputType

		local context = currentContext()
		local binding = InputRegistry:resolve(key, context)

		if not binding then
			return
		end

		if binding.mode == "hold" then
			activeHeld[key] = binding
		end

		local payload = binding.payload and binding.payload() or {}
		ReplicationController:Dispatch(binding.action, payload)
	end)

	UserInputService.InputEnded:Connect(function(input)
		local key = input.KeyCode ~= Enum.KeyCode.Unknown and input.KeyCode or input.UserInputType

		local binding = activeHeld[key]

		if not binding then
			return
		end

		activeHeld[key] = nil

		if binding.releaseAction then
			local payload = binding.releasePayload and binding.releasePayload() or {}

			ReplicationController:Dispatch(binding.releaseAction, payload)
		end
	end)
end

return InputController
