local EventBus = require(game.ReplicatedStorage.Shared.Helper.Buses.EventBus)

export type DamageContext = {
	source: Player?,
	target: Model,
	humanoid: Humanoid,
	damage: number,
	tags: { [string]: boolean },
	cancelled: boolean,
	absorbed: number,
	raw: number,
}

type Modifier = {
	id: string,
	priority: number,
	fn: (ctx: DamageContext) -> (),
}

local modifiers: { Modifier } = {}
local sorted = false

local DamageHandler = {}

local function ensureSorted()
	if sorted then
		return
	end
	table.sort(modifiers, function(a, b)
		if a.priority == b.priority then
			return a.id < b.id
		end
		return a.priority > b.priority
	end)
	sorted = true
end

function DamageHandler.registerModifier(id: string, priority: number, fn: (ctx: DamageContext) -> ())
	for _, m in modifiers do
		if m.id == id then
			warn("[DamagePipeline] Duplicate modifier id:", id, "— skipping")
			return
		end
	end
	table.insert(modifiers, { id = id, priority = priority, fn = fn })
	sorted = false
end

function DamageHandler.unregisterModifier(id: string)
	for i, m in modifiers do
		if m.id == id then
			table.remove(modifiers, i)
			sorted = false
			return
		end
	end
end

function DamageHandler.apply(params: {
	source: Player?,
	target: Model,
	damage: number,
	tags: { [string]: boolean }?,
	}): DamageContext?
	
	
	local humanoid = params.target:FindFirstChildOfClass("Humanoid")
	if not humanoid or humanoid.Health <= 0 then
		return nil
	end

	local ctx: DamageContext = {
		source = params.source,
		target = params.target,
		humanoid = humanoid,
		damage = params.damage,
		tags = params.tags or {},
		cancelled = false,
		absorbed = 0,
		raw = params.damage,
	}

	ensureSorted()

	for _, modifier in modifiers do
		if ctx.cancelled then
			break
		end
		local ok, err = pcall(modifier.fn, ctx)
		if not ok then
			warn("[DamagePipeline] Modifier '" .. modifier.id .. "' error:", err)
		end
	end

	if ctx.cancelled then
		EventBus.fire("DamageCancelled", ctx)
		return ctx
	end

	local finalDamage = math.max(0, ctx.damage)
	humanoid.Health -= finalDamage
	ctx.damage = finalDamage

	EventBus.fire("DamageApplied", ctx)

	if humanoid.Health <= 0 then
		EventBus.fire("TargetKilled", ctx)
	end

	return ctx
end

return DamageHandler