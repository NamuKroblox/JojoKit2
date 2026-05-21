-- ReplicationRegistry (ModuleScript — ReplicatedStorage/Shared/Modules/Replication)

local NOOP = function() end
local NOOP_VALIDATE = function(_, _)
	return true, nil
end

local registry = {}

local Registry = {}

function Registry.register(actionType, handlers)
	assert(type(actionType) == "string" and #actionType > 0)
	registry[actionType] = {
		validate = handlers.validate or NOOP_VALIDATE,
		predict = handlers.predict or NOOP,
		onPredict = handlers.onPredict or NOOP,
		onReconcile = handlers.onReconcile or NOOP,
		onBroadcast = handlers.onBroadcast or NOOP,
	}
end

function Registry.get(actionType)
	return registry[actionType]
end

return Registry
