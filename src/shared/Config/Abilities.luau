--!strict
--[[
	Every ability a run can draft.

	Pure data, and deliberately so: an ability is a row in this table plus one
	entry in `Combat/AbilityEffects`, never a branch anywhere in the firing
	code. See CLAUDE.md, non-negotiable 1. If an ability needs an `if` in
	`FiringSystem` to work, the pipeline is missing a stage and that is the
	thing to fix.

	`category` is the pipeline bucket an ability acts on, or `Stats` and
	`Defensive` for the two that change the player rather than the shot. It is
	used for colour on the card and for keeping an offer varied, not for
	behaviour.

	**`value` means whatever the effect says it means.** Resist the urge to
	give it units here — a multiplier, a count and a flat heal are all one
	number, and the effect is the only thing that should know which. What this
	table owns is *how much*, so a balance pass is a readable diff.

	`maxStacks` is the only exclusion rule there is so far. It is enough: an
	ability at its cap stops being offered, so a run cannot pour every card
	into one stat and the draft keeps presenting new decisions. Genuine
	mutual exclusions (two incompatible flight behaviours, say) arrive with the
	abilities that need them.
]]

export type Category = "Count" | "Pattern" | "Flight" | "OnHit" | "Stats" | "Defensive"

export type Ability = {
	id: string,
	name: string,
	--[[ Shown on the card. Written as what it does to the player's shot, in
	     the second person, because that is how a player reads a draft under
	     pressure — not as a stat line. ]]
	description: string,
	category: Category,
	value: number,
	maxStacks: number,
	--[[ Whether taking it again does anything. A one-shot ability like a heal
	     is consumed rather than kept, so it never appears in the run summary
	     as a thing you "have". ]]
	instant: boolean?,
}

local abilities: { Ability } = {
	--[[ Count. The single most valuable thing in Archero's draft, and
	     deliberately capped low: arrows multiply with every pattern ability,
	     so this compounds faster than anything else here. ]]
	{
		id = "FrontArrow",
		name = "Front Arrow",
		description = "One more arrow in every volley.",
		category = "Count",
		value = 1,
		maxStacks = 4,
	},

	--[[ Pattern. Each of these is a pure positional change: same arrows,
	     aimed elsewhere. They are what turn standing still from a cost into a
	     choice about which way to face. ]]
	{
		id = "RearArrow",
		name = "Rear Arrow",
		description = "You also fire behind you.",
		category = "Pattern",
		value = 1,
		maxStacks = 1,
	},
	{
		id = "SideArrows",
		name = "Side Arrows",
		description = "You also fire to both sides.",
		category = "Pattern",
		value = 1,
		maxStacks = 1,
	},
	{
		id = "DiagonalArrows",
		name = "Diagonal Arrows",
		description = "You also fire at both diagonals.",
		category = "Pattern",
		value = 1,
		maxStacks = 1,
	},

	--[[ Flight. How an arrow travels once it exists. ]]
	{
		id = "PiercingShot",
		name = "Piercing Shot",
		description = "Arrows pass through one more enemy.",
		category = "Flight",
		value = 1,
		maxStacks = 3,
	},
	{
		id = "SwiftArrows",
		name = "Swift Arrows",
		description = "Arrows fly 25% faster.",
		category = "Flight",
		value = 0.25,
		maxStacks = 3,
	},
	{
		id = "LongShot",
		name = "Long Shot",
		description = "Arrows travel 30% further before fading.",
		category = "Flight",
		value = 0.3,
		maxStacks = 3,
	},

	--[[ On hit. The only bucket that resolves at the moment of contact rather
	     than at the moment of firing, which is why crit lives on the spec and
	     is rolled by the server per hit. ]]
	{
		id = "DeadlyStrike",
		name = "Deadly Strike",
		description = "15% chance to strike for double damage.",
		category = "OnHit",
		value = 0.15,
		maxStacks = 4,
	},
	{
		id = "Overdraw",
		name = "Overdraw",
		description = "Critical strikes hit 50% harder.",
		category = "OnHit",
		value = 0.5,
		maxStacks = 3,
	},

	--[[ Stats. Change the archer rather than the arrow. ]]
	{
		id = "Strength",
		name = "Strength",
		description = "20% more damage.",
		category = "Stats",
		value = 0.2,
		maxStacks = 5,
	},
	{
		id = "Precision",
		name = "Precision",
		description = "You fire 15% faster.",
		category = "Stats",
		value = 0.15,
		maxStacks = 4,
	},

	--[[ Defensive. The bucket that decides whether a run survives a mistake,
	     which matters more here than in Archero because there is no energy
	     gate — a death costs the whole run and nothing else. ]]
	{
		id = "Vitality",
		name = "Vitality",
		description = "25 more health, and heal it now.",
		category = "Defensive",
		value = 25,
		maxStacks = 4,
	},
	{
		id = "Mending",
		name = "Mending",
		description = "Heal a third of your health.",
		category = "Defensive",
		value = 0.33,
		maxStacks = 99,
		--[[ Consumed on the spot. Capped high rather than at 1 because a heal
		     is always a legitimate thing to want again, and the cap exists
		     only to stop it being offered to a player at full health — which
		     is the offer roll's job, not this number's. ]]
		instant = true,
	},
	{
		id = "Agility",
		name = "Agility",
		description = "Move 12% faster.",
		category = "Defensive",
		value = 0.12,
		maxStacks = 4,
	},
	{
		id = "Lightfoot",
		name = "Lightfoot",
		description = "Dash recharges 20% sooner.",
		category = "Defensive",
		value = 0.2,
		maxStacks = 3,
	},
}

--[[ Indexed as well as listed: the offer roll wants the list, and validating
     a client's choice wants the lookup. ]]
local byId: { [string]: Ability } = {}
for _, ability in abilities do
	byId[ability.id] = ability
end

local Abilities = {
	all = abilities,
	byId = byId,
}

return table.freeze(Abilities)
