
local HitboxConfig = {

	MAX_HITS_PER_HITBOX = 1,
	LATENCY_TOLERANCE = 2,


	MAX_SIZE = Vector3.new(12, 12, 12),
	MIN_SIZE = Vector3.new(0.5, 0.5, 0.5),

	DEFAULT_LIFETIME = 0.3,
	PENDING_ACK_TIMEOUT = 5,


	SHOW_HITBOX_VISUALS = false,

	DEBUG = false,
	DEBUG_HITBOX = false,
	DEBUG_HITS = false,
}

--- Validates hitbox size
function HitboxConfig.isValidSize(size: Vector3): (boolean, string?)
	if not size then
		return false, "Size is required"
	end

	if size.X < HitboxConfig.MIN_SIZE.X or size.Y < HitboxConfig.MIN_SIZE.Y or size.Z < HitboxConfig.MIN_SIZE.Z then
		return false, "Size too small"
	end

	if size.X > HitboxConfig.MAX_SIZE.X or size.Y > HitboxConfig.MAX_SIZE.Y or size.Z > HitboxConfig.MAX_SIZE.Z then
		return false, "Size too large"
	end

	return true
end

--- Validates lifetime
function HitboxConfig.isValidLifetime(lifetime: number): (boolean, string?)
	if not lifetime or lifetime <= 0 then
		return false, "Lifetime must be positive"
	end

	if lifetime > 10 then
		return false, "Lifetime too long (max 10s)"
	end

	return true
end

--- Validates CFrame
function HitboxConfig.isValidCFrame(cf: CFrame): (boolean, string?)
	if not cf then
		return false, "CFrame is required"
	end

	local pos = cf.Position
	if math.abs(pos.X) > 1e6 or math.abs(pos.Y) > 1e6 or math.abs(pos.Z) > 1e6 then
		return false, "CFrame position out of bounds"
	end

	return true
end

return HitboxConfig