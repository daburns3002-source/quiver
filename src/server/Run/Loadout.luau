--!strict
--[[
	What a run has drafted, and what it is owed.

	Deliberately knows nothing about `RunSession`, characters or remotes: it is
	counts, a level, and the rules for turning XP into an offer. That keeps the
	whole of the draft testable without a running game, which matters because
	the parts most likely to be wrong here — a cap that is off by one, an offer
	that can repeat itself, XP that is credited to the wrong run — are all
	invisible to the type checker and all ruin a run quietly.

	One of these per player. Never shared, never global: the project is
	co-op-shaped from the first line, and an ability pool two players drew from
	at once would be the first thing to break when a second player arrives.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Abilities = require(ReplicatedStorage.Shared.Config.Abilities)
local Balance = require(ReplicatedStorage.Shared.Config.Balance)
local Progression = require(ReplicatedStorage.Shared.Config.Progression)
local Rarities = require(ReplicatedStorage.Shared.Config.Rarities)

type Ability = Abilities.Ability

local Loadout = {}

--[[ Who is offering the cards on screen. A level-up spends a level it was
     owed; a Valkyrie or an Angel is a gift, and spends nothing. ]]
export type OfferSource = "Level" | "Valkyrie" | "Angel"

export type State = {
	--[[ Ability id to how many copies have been taken. Instant abilities are
	     counted too, purely so the offer roll can respect their cap. ]]
	counts: { [string]: number },
	level: number,
	xp: number,
	--[[ XP still owed before the next level. Stored rather than recomputed so
	     a mid-run change to the curve cannot retroactively level a player. ]]
	xpToNext: number,
	--[[ The ability ids currently on offer, or nil when nothing is pending.
	     Its presence is what pauses the run, and what makes a client's choice
	     verifiable rather than trusted. ]]
	offer: { string }?,
	offerSource: OfferSource?,
	--[[ Levels gained but not yet offered. A player who levels twice from one
	     kill gets two cards in sequence, not one card and a lost level. ]]
	pendingLevels: number,
	--[[ Redeals left this run. ]]
	rerolls: number,
	--[[ A rarity the next hand must include, once. Testing only: set by the
	     Studio-only "show me a Mythic" key, never in a live game. ]]
	forceRarity: string?,
}

local function costForLevel(level: number): number
	return math.floor(Progression.baseLevelCost * Progression.levelCostGrowth ^ (level - 1) + 0.5)
end

function Loadout.new(): State
	return {
		counts = {},
		level = 1,
		xp = 0,
		xpToNext = costForLevel(1),
		offer = nil,
		offerSource = nil,
		pendingLevels = 0,
		rerolls = Balance.Draft.rerollsPerRun,
		forceRarity = nil,
	}
end

--[[
	Whether `ability` fights something already held. Read both ways — an
	exclusion written on either ability counts — so a pair is declared once
	and cannot be half-declared.
]]
function Loadout.excluded(state: State, ability: Ability): boolean
	for id, count in state.counts do
		if count <= 0 then
			continue
		end

		local held = Abilities.byId[id]
		if not held then
			continue
		end

		if ability.excludes and table.find(ability.excludes, id) then
			return true
		end

		if held.excludes and table.find(held.excludes, ability.id) then
			return true
		end
	end

	return false
end

--[[ How many more levels of an ability this run may still take. ]]
function Loadout.remaining(state: State, ability: Ability): number
	return #ability.levels - (state.counts[ability.id] or 0)
end

--[[
	Credits XP and banks any levels it bought.

	Returns the number of levels gained, so the caller knows whether to open a
	card screen without having to compare before and after.
]]
function Loadout.addXp(state: State, amount: number): number
	if amount <= 0 or state.level >= Progression.maxLevel then
		return 0
	end

	state.xp += amount
	local gained = 0

	--[[ A loop, not an `if`: one kill at a high area can be worth more than a
	     whole level, and swallowing the remainder would quietly cost the
	     player a card. ]]
	while state.xp >= state.xpToNext and state.level + gained < Progression.maxLevel do
		state.xp -= state.xpToNext
		gained += 1
		state.xpToNext = costForLevel(state.level + gained)
	end

	if gained > 0 then
		state.level += gained
		state.pendingLevels += gained
	end

	return gained
end

--[[
	The skills that may legally be dealt right now: under their cap, not
	excluded by something held, and not a filler card.
]]
local function candidates(state: State): { Ability }
	local out: { Ability } = {}

	for _, ability in Abilities.all do
		if ability.filler then
			continue
		end

		if Loadout.remaining(state, ability) <= 0 then
			continue
		end

		if Loadout.excluded(state, ability) then
			continue
		end

		table.insert(out, ability)
	end

	return out
end

--[[ A card's chance of being dealt, relative to the others: its rarity's
     weight. ]]
function Loadout.weight(ability: Ability): number
	local rarity = Rarities.byName[ability.rarity]
	return if rarity then rarity.weight else 0
end

--[[
	Deals the cards for one hand: `size` different skills, each drawn with a
	chance in proportion to its rarity's weight, so Commons come up most and
	a Mythic rarely.

	A hand the pool cannot fill is topped up with the Heal card, unless the
	player is at full health — a card that does nothing is worse than a
	smaller hand. Returns an empty list when nothing at all can be dealt,
	which the caller treats as "no card this level", not as an error.
]]
function Loadout.rollOffer(
	state: State,
	atFullHealth: boolean,
	random: Random,
	size: number?
): { string }
	local wanted = size or Progression.offerCount
	local pool = candidates(state)
	local picked: { string } = {}

	while #picked < wanted and #pool > 0 do
		local total = 0
		for _, ability in pool do
			total += Loadout.weight(ability)
		end

		local roll = random:NextNumber() * total
		local chosen = #pool
		for index, ability in pool do
			roll -= Loadout.weight(ability)
			if roll <= 0 then
				chosen = index
				break
			end
		end

		table.insert(picked, pool[chosen].id)
		table.remove(pool, chosen)
	end

	--[[ A hand asked to include a rarity (testing only) puts one first, if
	     any skill of it can still be dealt. Asked for once, then forgotten. ]]
	local forced = state.forceRarity
	if forced then
		state.forceRarity = nil
		for _, ability in candidates(state) do
			if ability.rarity == forced and not table.find(picked, ability.id) then
				if #picked >= wanted then
					picked[1] = ability.id
				else
					table.insert(picked, 1, ability.id)
				end
				break
			end
		end
	end

	if #picked < wanted and not atFullHealth then
		table.insert(picked, Abilities.byId.Heal.id)
	end

	return picked
end

--[[ Opens a card screen if one is owed and none is already open. Returns the
     offer, or nil when there is nothing to show. ]]
function Loadout.openOffer(state: State, atFullHealth: boolean, random: Random): { string }?
	if state.offer or state.pendingLevels <= 0 then
		return nil
	end

	local offer = Loadout.rollOffer(state, atFullHealth, random)

	--[[ Nothing legal to offer still consumes the level. Holding it back would
	     re-roll the same empty pool on every kill for the rest of the run. ]]
	if #offer == 0 then
		state.pendingLevels -= 1
		return nil
	end

	state.offer = offer
	state.offerSource = "Level"
	return offer
end

--[[
	A Valkyrie's offer: `size` cards from the ordinary pool, chosen the same
	way as a level-up's. Opens nothing if a screen is already up or nothing
	can be offered.
]]
function Loadout.openValkyrie(
	state: State,
	atFullHealth: boolean,
	random: Random,
	size: number
): { string }?
	if state.offer then
		return nil
	end

	local offer = Loadout.rollOffer(state, atFullHealth, random, size)
	if #offer == 0 then
		return nil
	end

	state.offer = offer
	state.offerSource = "Valkyrie"
	return offer
end

--[[
	An Angel's offer, as Archero 2 has it: a minor stat boost or a heal. The
	stat is any Stats ability still under its cap and not excluded; the heal
	is the Heal card. The stat may be missing late in a run — the heal is
	still offered alone rather than nothing at all.
]]
function Loadout.openAngel(state: State, random: Random): { string }?
	if state.offer then
		return nil
	end

	local stats: { string } = {}
	for _, ability in Abilities.all do
		if ability.category == "Stats" and Loadout.remaining(state, ability) > 0 then
			if not Loadout.excluded(state, ability) then
				table.insert(stats, ability.id)
			end
		end
	end

	local offer: { string } = {}
	if #stats > 0 then
		table.insert(offer, stats[random:NextInteger(1, #stats)])
	end

	table.insert(offer, Abilities.byId.Heal.id)

	if #offer == 0 then
		return nil
	end

	state.offer = offer
	state.offerSource = "Angel"
	return offer
end

--[[
	Redeals the open hand, spending one of the run's rerolls. Returns the new
	hand, or nil when there is no hand open or no reroll left — the client
	asks, and this is where the asking stops.

	Only a dealt hand redeals. An Angel's stat-or-heal is a fixed choice, so
	it stays what it is.
]]
function Loadout.reroll(state: State, atFullHealth: boolean, random: Random): { string }?
	local offer = state.offer
	if not offer or state.rerolls <= 0 or state.offerSource == "Angel" then
		return nil
	end

	local hand = Loadout.rollOffer(state, atFullHealth, random, #offer)
	if #hand == 0 then
		return nil
	end

	state.rerolls -= 1
	state.offer = hand
	return hand
end

--[[
	Takes the card at `index` from the open offer.

	**This is the validation boundary.** The client sends an index and nothing
	else — not an ability id, and certainly not a stat — so the worst a lying
	client can do is pick a different one of the three cards the server already
	decided to show it.

	Returns the granted ability, or nil if the choice was not legal.
]]
function Loadout.choose(state: State, index: number): Ability?
	local offer = state.offer
	if not offer then
		return nil
	end

	if index ~= math.floor(index) or index < 1 or index > #offer then
		return nil
	end

	local ability = Abilities.byId[offer[index]]
	if not ability then
		return nil
	end

	--[[ Instant abilities are resolved by the caller and never recorded as
	     held, but they still count towards their own cap. ]]
	state.counts[ability.id] = (state.counts[ability.id] or 0) + 1
	--[[ Only a level-up spends a level. A Valkyrie's or an Angel's card is
	     a gift, and charging it to a level would quietly cost the player
	     their next draft. ]]
	if state.offerSource == "Level" then
		state.pendingLevels -= 1
	end
	state.offer = nil
	state.offerSource = nil

	return ability
end

--[[ The abilities actually held, for the run summary and the HUD. Instant
     ones are excluded: a heal you drank is not part of your build. ]]
function Loadout.held(state: State): { [string]: number }
	local out: { [string]: number } = {}

	for id, count in state.counts do
		local ability = Abilities.byId[id]
		if ability and not ability.instant then
			out[id] = count
		end
	end

	return out
end

return Loadout
