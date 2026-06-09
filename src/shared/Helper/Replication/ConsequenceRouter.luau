local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Knit = require(ReplicatedStorage.Packages.knit)

local ReactionRegistry = require(game.ReplicatedStorage.Shared.Registration.Registries.ReactionRegistry)

type Ctx = {
	senderUserId    : number,
	targetKey       : string?,
	isPlayer        : boolean?,
	targetCharacter : Model?,
}

local ConsequenceRouter = {}

local EffectController
--local PhysicsController
--local StatusController

local DEBUG = false -- Set to true for debugging

local function ensureControllers()
	if not EffectController then
		EffectController = Knit.GetController("EffectController")
	end
	--if not PhysicsController then
	--	PhysicsController = Knit.GetController("PhysicsController")
	--end
	--if not StatusController then
	--	StatusController = Knit.GetController("StatusController")
	--end

	return EffectController 
end

local function resolveCharacter(targetKey: string?, isPlayer: boolean?): Model?
	if not targetKey then
		return nil
	end

	if isPlayer then
		local player = Players:GetPlayerByUserId(tonumber(targetKey))
		if not player then
			warn("[ConsequenceRouter] Player not found:", targetKey)
			return nil
		end
		if not player.Character then
			warn("[ConsequenceRouter] Player character not loaded:", player.Name)
			return nil
		end
		return player.Character
	end

	local dummies = workspace:FindFirstChild("Dummies")
	if not dummies then
		warn("[ConsequenceRouter] Dummies folder not found")
		return nil
	end

	local dummy = dummies:FindFirstChild(targetKey)
	if not dummy then
		warn("[ConsequenceRouter] Dummy not found:", targetKey)
		return nil
	end

	return dummy :: Model
end

local function resolveTarget(
	target: string,
	ctx: {
		senderUserId: number,
		targetKey: string?,
		isPlayer: boolean?,
		targetCharacter: Model?,
	}
): Model?
	if target == "attacker" then
		local sender = Players:GetPlayerByUserId(ctx.senderUserId)
		if not sender or not sender.Character then
			warn("[ConsequenceRouter] Attacker not found:", ctx.senderUserId)
			return nil
		end
		return sender.Character
	end

	if target == "victim" then
		if ctx.targetCharacter then
			return ctx.targetCharacter
		end
		return resolveCharacter(ctx.targetKey, ctx.isPlayer)
	end

	warn("[ConsequenceRouter] Unknown target:", target)
	return nil
end

local function isLocalCharacter(character: Model?): boolean
	if not character then
		return false
	end
	local localPlayer = Players.LocalPlayer
	if not localPlayer.Character then
		return false
	end
	return character == localPlayer.Character
end

local function processEffectConsequence(consequence, ctx)
	local ec = EffectController
	if not ec then
		warn("[ConsequenceRouter] EffectController not available")
		return false
	end

	local ctarget = consequence.target

	if ctarget == "all" then
		local payload = consequence.payload or {}
		if not payload.targetCharacter and ctx.targetKey then
			payload = table.clone(payload)
			payload.targetCharacter = resolveCharacter(ctx.targetKey, ctx.isPlayer)
		end
		ec:Play(consequence.id, payload, ctx.senderUserId)
		return true

	elseif ctarget == "attacker" or ctarget == "victim" then
		local character = resolveTarget(ctarget, ctx)
		if not character then
			return false
		end

		local payload = consequence.payload and table.clone(consequence.payload) or {}
		payload.targetCharacter = character

		ec:Play(consequence.id, payload, ctx.senderUserId)
		return true
	end

	return false
end


local function resolveRole(
	ctx         : Ctx,
	consequence : { [string]: any }
): "source" | "target" | "observer"
	local localId = Players.LocalPlayer.UserId
	if ctx.senderUserId == localId then
		return "source"
	end
	local p = consequence.payload
	if p and p.isPlayer and p.targetKey == tostring(localId) then
		return "target"
	end
	return "observer"
end

-- Builds the ReactionContext passed into role callbacks.
local function buildReactionCtx(ctx: Ctx, consequence: { [string]: any }): ReactionRegistry.ReactionContext
	local p = consequence.payload or {}
	return {
		senderUserId    = ctx.senderUserId,
		targetKey       = p.targetKey       or ctx.targetKey,
		isPlayer        = p.isPlayer        ~= nil and p.isPlayer or ctx.isPlayer,
		targetCharacter = p.targetCharacter or ctx.targetCharacter,
		payload         = p,
	}
end

function ConsequenceRouter.flush(consequences, ctx)
	if not consequences or #consequences == 0 then
		return true
	end

	-- Ensure all controllers are loaded
	if not ensureControllers() then
		warn("[ConsequenceRouter] Not all controllers available yet")
		return false
	end

	local success = true

	for index, consequence in ipairs(consequences) do
		if not consequence.type then
			warn("[ConsequenceRouter] Consequence missing type at index", index)
			success = false
			continue
		end

		local ctype = consequence.type
		local processed = false

		if ctype == "effect" then
			processed = processEffectConsequence(consequence, ctx)

		elseif ctype == "reaction" then
			if DEBUG then print("[ConsequenceRouter] --- reaction start ---") end
			if DEBUG then print("[ConsequenceRouter] consequenceId:", consequence.id) end

			local handler = ReactionRegistry:get(consequence.id)
			if not handler then
				warn("[ConsequenceRouter] missing handler:", consequence.id)
				continue
			end

			if DEBUG then print("[ConsequenceRouter] handler found:", consequence.id) end

			local role = resolveRole(ctx, consequence)
			if DEBUG then print("[ConsequenceRouter] resolved role:", role) end

			local target = consequence.target or "all"
			if DEBUG then print("[ConsequenceRouter] target rule:", target) end

			local skip =
				(target == "source" and role ~= "source")
				or (target == "target" and role ~= "target")
				or (target == "observers" and (role == "source" or role == "target"))

			if skip then
				if DEBUG then print("[ConsequenceRouter] skipped role=", role, "target=", target) end
				continue
			end

			if DEBUG then print("[ConsequenceRouter] processing reaction for role:", role) end

			local rctx = buildReactionCtx(ctx, consequence)
			if DEBUG then print("[ConsequenceRouter] reaction context built") end

			if role == "source" and handler.onSource then
				if DEBUG then print("[ConsequenceRouter] calling onSource") end
				handler.onSource(rctx, consequence.payload)

			elseif role == "target" and handler.onTarget then
				if DEBUG then print("[ConsequenceRouter] calling onTarget") end
				handler.onTarget(rctx, consequence.payload)

			elseif role == "observer" and handler.onObserver then
				if DEBUG then print("[ConsequenceRouter] calling onObserver") end
				handler.onObserver(rctx, consequence.payload)

			else
				warn("[ConsequenceRouter] no handler for role:", role, "reaction:", consequence.id)
			end

			processed = true
			if DEBUG then print("[ConsequenceRouter] --- reaction end ---") end

		else
			warn("[ConsequenceRouter] Unknown consequence type:", ctype)
			success = false
			continue
		end

		if not processed then
			warn("[ConsequenceRouter] Failed to process", ctype, "consequence at index", index)
			success = false
		end
	end

	return success
end

return ConsequenceRouter