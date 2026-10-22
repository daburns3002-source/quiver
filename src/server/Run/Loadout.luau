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
local Progression = require(ReplicatedStorage.Shared.Config.Progression)

type Ability = Abilities.Ability

local Loadout = {}

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
	--[[ Levels gained but not yet offered. A player who levels twice from one
	     kill gets two cards in sequence, not one card and a lost level. ]]
	pendingLevels: number,
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
		pendingLevels = 0,
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

--[[ How many more copies of an ability this run may still take. ]]
function Loadout.remaining(state: State, ability: Ability): number
	return ability.maxStacks - (state.counts[ability.id] or 0)
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
	The abilities that may legally be offered right now.

	`atFullHealth` suppresses the pure heal. A card that does nothing is worse
	than a card that is merely bad — it makes the draft feel like it is not
	paying attention, which is exactly when a player stops reading it.
]]
local function candidates(state: State, atFullHealth: boolean): { Ability }
	local out: { Ability } = {}

	for _, ability in Abilities.all do
		if Loadout.remaining(state, ability) <= 0 then
			continue
		end

		if ability.instant and atFullHealth then
			continue
		end

		if Loadout.excluded(state, ability) then
			continue
		end

		table.insert(out, ability)
	end

	return out
end

--[[
	Rolls the cards for one level.

	Variety is preferred but never enforced: the roll takes one ability per
	category first, and only then fills from whatever is left. A hard rule
	would be worse — late in a run most categories are capped out, and refusing
	to offer anything is a far bigger failure than offering two of a kind.

	Returns an empty list when nothing can legally be offered, which the caller
	must treat as "no card this level" rather than as an error.
]]
function Loadout.rollOffer(state: State, atFullHealth: boolean, random: Random): { string }
	local pool = candidates(state, atFullHealth)

	if #pool == 0 then
		return {}
	end

	--[[ Shuffled once, then read in order. Drawing randomly with retries can
	     loop for a long time when the pool is nearly exhausted. ]]
	for index = #pool, 2, -1 do
		local swap = random:NextInteger(1, index)
		pool[index], pool[swap] = pool[swap], pool[index]
	end

	local picked: { string } = {}
	local usedCategory: { [string]: boolean } = {}

	for _, ability in pool do
		if #picked >= Progression.offerCount then
			break
		end
		if usedCategory[ability.category] then
			continue
		end

		usedCategory[ability.category] = true
		table.insert(picked, ability.id)
	end

	for _, ability in pool do
		if #picked >= Progression.offerCount then
			break
		end
		if table.find(picked, ability.id) then
			continue
		end

		table.insert(picked, ability.id)
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
	return offer
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
	state.offer = nil
	state.pendingLevels -= 1

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
