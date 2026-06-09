-- ReplicatedStorage/Shared/Util/HitboxUtil.lua
-- Shared utilities for hitbox detection and validation

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local HitboxConfig = require(ReplicatedStorage.Shared.Data.Configs.HitboxConfig)

local HitboxUtil = {}

-- ─────────────────────────────────────────────────────────────────
-- COLLISION DETECTION
-- ─────────────────────────────────────────────────────────────────

--- Checks if a point is inside an axis-aligned box
-- Uses local space for rotation-independent detection
function HitboxUtil.pointInBox(boxCFrame: CFrame, boxHalfSize: Vector3, point: Vector3): boolean
	local localPoint = boxCFrame:PointToObjectSpace(point)
	return math.abs(localPoint.X) <= boxHalfSize.X
		and math.abs(localPoint.Y) <= boxHalfSize.Y
		and math.abs(localPoint.Z) <= boxHalfSize.Z
end

--- Checks if a position is in hitbox with latency tolerance
function HitboxUtil.isInHitbox(
	hitboxCFrame: CFrame,
	hitboxSize: Vector3,
	position: Vector3,
	tolerance: number?
): boolean
	local tol = tolerance or HitboxConfig.LATENCY_TOLERANCE
	local halfSize = hitboxSize * 0.5 + Vector3.new(tol, tol, tol)
	return HitboxUtil.pointInBox(hitboxCFrame, halfSize, position)
end

-- ─────────────────────────────────────────────────────────────────
-- VALIDATION
-- ─────────────────────────────────────────────────────────────────

--- Validates complete hitbox configuration
function HitboxUtil.validateConfig(config: { [string]: any }): (boolean, string?)
	if not config.userId or type(config.userId) ~= "number" then
		return false, "userId is required and must be a number"
	end

	local sizeValid, sizeErr = HitboxConfig.isValidSize(config.size)
	if not sizeValid then
		return false, "Invalid size: " .. sizeErr
	end

	local cfValid, cfErr = HitboxConfig.isValidCFrame(config.cframe)
	if not cfValid then
		return false, "Invalid cframe: " .. cfErr
	end

	if config.lifetime then
		local lifeValid, lifeErr = HitboxConfig.isValidLifetime(config.lifetime)
		if not lifeValid then
			return false, "Invalid lifetime: " .. lifeErr
		end
	end

	return true
end

-- ─────────────────────────────────────────────────────────────────
-- ID GENERATION
-- ─────────────────────────────────────────────────────────────────

--- Generates a unique hitbox ID
function HitboxUtil.generateHitboxId(userId: number): string
	return tostring(userId) .. "_" .. tostring(os.clock()) .. "_" .. tostring(math.random(1, 1000))
end

-- ─────────────────────────────────────────────────────────────────
-- DEBUGGING
-- ─────────────────────────────────────────────────────────────────

--- Logs hitbox creation (debug only)
function HitboxUtil.logHitboxCreated(hitboxId: string, config: { [string]: any })
	if not HitboxConfig.DEBUG_HITBOX then
		return
	end

	print(string.format(
		"[Hitbox] Created: %s | userId: %d | size: %.1f,%.1f,%.1f | lifetime: %.2fs",
		hitboxId,
		config.userId,
		config.size.X,
		config.size.Y,
		config.size.Z,
		config.lifetime or HitboxConfig.DEFAULT_LIFETIME
		))
end

--- Logs hit detection (debug only)
function HitboxUtil.logHitDetected(hitboxId: string, targetKey: string, isPlayer: boolean)
	if not HitboxConfig.DEBUG_HITS then
		return
	end

	print(string.format(
		"[Hitbox] Hit detected: %s | target: %s | isPlayer: %s",
		hitboxId,
		targetKey,
		tostring(isPlayer)
		))
end

--- Logs hitbox destroyed (debug only)
function HitboxUtil.logHitboxDestroyed(hitboxId: string, reason: string?)
	if not HitboxConfig.DEBUG_HITBOX then
		return
	end

	print(string.format(
		"[Hitbox] Destroyed: %s%s",
		hitboxId,
		reason and (" (" .. reason .. ")") or ""
		))
end

return HitboxUtil