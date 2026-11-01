--!strict
--[[
	Enemies on fire, and the damage it does them.

	Blaze sets a burn at the moment an arrow lands, which `ProjectileSystem`
	resolves; the burn then outlives the arrow, so it needs somewhere to live
	that is not a projectile. This is that place. Everything about it is
	server-side: the client is told an enemy is burning (an attribute on the
	model, for the flame) and is shown the ticks as ordinary hits, and decides
	nothing.

	Kills by fire credit the run of whoever lit it, through the same
	`RunSession.creditKill` an arrow kill uses — a burn ticking down an enemy
	the player is no longer shooting is still that player's kill.

	A pet's bleed (`Shared/Combat/Bleed`, the Bramble Wilf's thorns) lives
	here too: it is the same damage on the same clock, and only the
	arithmetic of a second one landing differs — a burn keeps the stronger
	rate, a thorn adds to the stack. Side by side means an enemy both
	bleeding and on fire takes both, which is right: they are two sources,
	not two helpings of one.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Balance = require(ReplicatedStorage.Shared.Config.Balance)
local Bleed = require(ReplicatedStorage.Shared.Combat.Bleed)
local EnemyManager = require(script.Parent.Parent.Enemies.EnemyManager)
local RunSession = require(script.Parent.Parent.Run.RunSession)

--[[ Set on a burning enemy's model, for the client's flame. ]]
local ATTRIBUTE = "Burning"
--[[ Set on a bleeding enemy's model to the thorns it carries, for art that
     comes to show the stack. ]]
local BLEED_ATTRIBUTE = "Bleeding"

type Burn = {
	--[[ Damage per second. ]]
	rate: number,
	expiresAt: number,
	nextTickAt: number,
	owner: Player?,
}

type Thorns = {
	--[[ Thorns carried, and the damage a second they come to between
	     them. ]]
	stacks: number,
	rate: number,
	expiresAt: number,
	nextTickAt: number,
	owner: Player?,
}

local Burning = {}

local burns: { [Model]: Burn } = {}
local bleeds: { [Model]: Thorns } = {}

--[[
	Sets `model` burning at `rate` damage a second, or refreshes a burn already
	there.

	A refresh keeps the stronger rate and restarts the clock; it never adds the
	two. Otherwise every arrow of a Front Arrow lane, or both halves of a
	Double Shot, would stack its own burn and Blaze would become a second weapon
	rather than a bonus on the first.
]]
function Burning.ignite(model: Model, rate: number, duration: number, owner: Player?, now: number)
	if rate <= 0 or duration <= 0 then
		return
	end

	local existing = burns[model]

	if existing then
		existing.rate = math.max(existing.rate, rate)
		existing.expiresAt = math.max(existing.expiresAt, now + duration)
		existing.owner = owner or existing.owner
		return
	end

	burns[model] = {
		rate = rate,
		expiresAt = now + duration,
		nextTickAt = now + Balance.Burn.tick,
		owner = owner,
	}
	model:SetAttribute(ATTRIBUTE, true)
end

--[[
	Drives another thorn into `model` (`Shared/Combat/Bleed`).

	Where a refreshed burn keeps the stronger of the two rates, a thorn adds
	to what is already there, up to the bleed's cap, and the whole stack then
	runs from this moment: the pet is paid for staying on one enemy and loses
	the lot when it looks away. The tick clock is kept, so a thorn landing
	between ticks does not restart the damage.
]]
function Burning.bleed(model: Model, bleed: Bleed.Bleed, owner: Player?, now: number)
	if bleed.rate <= 0 or bleed.duration <= 0 then
		return
	end

	local held = bleeds[model]
	local stacks = Bleed.stack(bleed, if held then held.stacks else 0)

	bleeds[model] = {
		stacks = stacks,
		rate = Bleed.rate(bleed, stacks),
		expiresAt = now + bleed.duration,
		nextTickAt = if held then held.nextTickAt else now + Balance.Burn.tick,
		owner = owner or (if held then held.owner else nil),
	}
	model:SetAttribute(BLEED_ATTRIBUTE, stacks)
end

local function extinguish(model: Model)
	burns[model] = nil
	if model.Parent then
		model:SetAttribute(ATTRIBUTE, nil)
	end
end

local function stanch(model: Model)
	bleeds[model] = nil
	if model.Parent then
		model:SetAttribute(BLEED_ATTRIBUTE, nil)
	end
end

--[[
	Ticks every burn that is due. A tick does the damage of `tick` seconds at
	the burn's rate, with no knockback — fire does not push.

	A burn that has run out, or whose enemy is no longer a live one, is put out
	rather than ticked: `EnemyManager.damage` declining the hit is how a burn
	learns its enemy died to something else.
]]
function Burning.step(now: number)
	for model, burn in burns do
		if now >= burn.expiresAt then
			extinguish(model)
			continue
		end

		if now < burn.nextTickAt then
			continue
		end

		burn.nextTickAt += Balance.Burn.tick

		local landed, xp, fell =
			EnemyManager.damage(model, burn.rate * Balance.Burn.tick, nil, "Burn")

		if not landed then
			extinguish(model)
			continue
		end

		if xp > 0 then
			burns[model] = nil
			RunSession.creditKill(burn.owner, xp, fell)
		end
	end

	--[[ The thorns, on the same clock and with the same ending: a bleed
	     that has run out, or whose enemy died to something else, is stanched
	     rather than ticked. ]]
	for model, thorns in bleeds do
		if now >= thorns.expiresAt then
			stanch(model)
			continue
		end

		if now < thorns.nextTickAt then
			continue
		end

		thorns.nextTickAt += Balance.Burn.tick

		local landed, xp, fell =
			EnemyManager.damage(model, thorns.rate * Balance.Burn.tick, nil, "Burn")

		if not landed then
			stanch(model)
			continue
		end

		if xp > 0 then
			bleeds[model] = nil
			RunSession.creditKill(thorns.owner, xp, fell)
		end
	end
end

--[[ Puts everything out. Called when a room is torn down, alongside the
     projectiles, so nothing from the last room burns into the next. ]]
function Burning.clear()
	for model in burns do
		extinguish(model)
	end
	for model in bleeds do
		stanch(model)
	end
end

return Burning
