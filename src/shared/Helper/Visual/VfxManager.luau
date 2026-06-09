local TweenService = game:GetService("TweenService")

local VfxManager = {}

type EmitConfig = {
	count: number?,
	enable: boolean?,
	duration: number?,
}

type AttachConfig = {
	parent: BasePart,
	template: Instance,
	emit: EmitConfig?,
	cleanup: number?,
}

local active: { [string]: { Instance } } = {}

local function getEmitters(instance: Instance): { ParticleEmitter }
	local emitters = {}
	for _, d in instance:GetDescendants() do
		if d:IsA("ParticleEmitter") then
			table.insert(emitters, d)
		end
	end
	return emitters
end

local function applyEmit(emitters: { ParticleEmitter }, config: EmitConfig)
	for _, emitter in emitters do
		if config.enable ~= nil then
			emitter.Enabled = config.enable
		end
		if config.count then
			emitter:Emit(config.count)
		else
			emitter:Emit(emitter:GetAttribute("EmitCount"))
		end
	end
end

local function track(id: string, instance: Instance)
	if not active[id] then
		active[id] = {}
	end
	table.insert(active[id], instance)
end

function VfxManager.attach(id: string, config: AttachConfig): Instance

	if not config then
		warn("[VfxManager.attach] Missing config for:", id)
	end

	if not config.template then
		warn("[VfxManager.attach] Missing template for:", id)
	end

	if not config.parent then
		warn("[VfxManager.attach] Missing parent for:", id)
	end

	local clone = config.template:Clone()


	clone.Parent = config.parent


	local emitters = getEmitters(clone)


	if config.emit then
	

		applyEmit(emitters, config.emit)
	else
		

		applyEmit(emitters, {
			count = nil,
			enable = false,
		})
	end


	track(id, clone)

	local cleanupTime = config.cleanup or 5


	task.delay(cleanupTime, function()
		

		VfxManager.remove(id, clone)
	end)


	return clone
end

function VfxManager.emit(id: string, config: EmitConfig)
	local instances = active[id]
	if not instances then
		return
	end
	for _, instance in instances do
		local emitters = getEmitters(instance)
		applyEmit(emitters, config)
	end
end

function VfxManager.tween(id: string, props: { [string]: any }, info: TweenInfo?)
	local instances = active[id]
	if not instances then
		return
	end
	local tweenInfo = info or TweenInfo.new(0.3, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
	for _, instance in instances do
		for _, d in instance:GetDescendants() do
			local filtered = {}
			for prop, val in props do
				if pcall(function()
					return (d :: any)[prop]
				end) then
					filtered[prop] = val
				end
			end
			if next(filtered) then
				TweenService:Create(d, tweenInfo, filtered):Play()
			end
		end
		local selfFiltered = {}
		for prop, val in props do
			if pcall(function()
				return (instance :: any)[prop]
			end) then
				selfFiltered[prop] = val
			end
		end
		if next(selfFiltered) then
			TweenService:Create(instance, tweenInfo, selfFiltered):Play()
		end
	end
end

function VfxManager.remove(id: string, target: Instance?)
	local instances = active[id]
	if not instances then
		return
	end

	if target then
		for i = #instances, 1, -1 do
			if instances[i] == target then
				if instances[i].Parent then
					instances[i]:Destroy()
				end
				table.remove(instances, i)
			end
		end
		if #instances == 0 then
			active[id] = nil
		end
	else
		for _, instance in instances do
			if instance.Parent then
				instance:Destroy()
			end
		end
		active[id] = nil
	end
end

function VfxManager.clear(id: string, fadeTime: number?)
	local instances = active[id]
	if not instances then
		return
	end

	if not fadeTime then
		VfxManager.remove(id)
		return
	end

	for _, instance in instances do
		local emitters = getEmitters(instance)
		for _, emitter in emitters do
			emitter.Enabled = false
		end
		task.delay(fadeTime, function()
			if instance.Parent then
				instance:Destroy()
			end
		end)
	end

	active[id] = nil
end

function VfxManager.get(id: string): { Instance }?
	return active[id]
end

return VfxManager
