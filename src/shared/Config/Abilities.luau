--!strict
--[[
	Every ability a run can draft.

	Pure data, and deliberately so: an ability is a row in this table plus one
	entry in `Combat/AbilityEffects`, never a branch anywhere in the firing
	code. See CLAUDE.md, non-negotiable 1. If an ability needs an `if` in
	`FiringSystem` to work, the pipeline is missing a stage and that is the
	thing to fix.

	**The cards are the spec.** Names, descriptions, rarities, level counts and
	the stat line for each level come from the upgrade card design
	(design_handoff_upgrade_cards, data/skills.json), which the owner chose
	over the game's earlier abilities on 2026-10-22. `levels[n]` is the
	number that stat line describes — the *total* at level n, not the step —
	and the effect is the only thing that knows its units.

	`category` is the pipeline bucket an ability acts on, or `Stats` and
	`Defensive` for those that change the player rather than the shot. `group`
	is the card's own category ("arrow skill", "vital skill"), for display.

	An ability's cap is its last level: at the top it stops being dealt.
	`excludes` is for two abilities that fight each other rather than stack —
	holding either stops the other being dealt. It is read both ways.

	`filler` marks a card that is not a skill: never dealt by rarity, only to
	fill an Angel's offer or a hand the pool cannot fill. `instant` ones are
	resolved on the spot and never held.
]]

local Rarities = require(script.Parent.Rarities)

export type Category = "Count" | "Pattern" | "Flight" | "OnHit" | "OnKill" | "Stats" | "Defensive"
export type Group = "arrow" | "power" | "element" | "mobility" | "vital"

export type Ability = {
	id: string,
	name: string,
	description: string,
	category: Category,
	group: Group,
	rarity: Rarities.Name,
	--[[ The effect's total at each level; `#levels` is the cap. ]]
	levels: { number },
	--[[ What each level says on the card. ]]
	stats: { string },
	--[[ The icon's file name in the design's icon set. ]]
	icon: string,
	instant: boolean?,
	filler: boolean?,
	excludes: { string }?,
}

local abilities: { Ability } = {
	--[[ Arrow skills: how many arrows, where they go, how they fly. ]]
	{
		id = "Multishot",
		name = "Multishot",
		description = "Fire an extra arrow after each shot.",
		category = "Count",
		group = "arrow",
		rarity = "Legendary",
		--[[ Extra volleys, each a beat behind the last along the same aim. ]]
		levels = { 1, 2, 3 },
		stats = { "+1 arrow", "+2 arrows", "+3 arrows" },
		icon = "multishot",
	},
	{
		id = "Ricochet",
		name = "Ricochet",
		description = "Arrows bounce to a nearby enemy.",
		category = "OnHit",
		group = "arrow",
		rarity = "Epic",
		levels = { 2, 3, 4 },
		stats = { "2 bounces", "3 bounces", "4 bounces" },
		icon = "ricochet",
	},
	{
		id = "FrontArrow",
		name = "Front Arrow",
		description = "Add a parallel arrow to your volley.",
		category = "Count",
		group = "arrow",
		rarity = "Epic",
		--[[ Extra arrows beside the first, in a lane. ]]
		levels = { 1, 2, 3 },
		stats = { "+1 front", "+2 front", "+3 front" },
		icon = "front-arrow",
	},
	{
		id = "DoubleShot",
		name = "Double Shot",
		description = "Fire arrows in a narrow spread.",
		category = "Pattern",
		group = "arrow",
		rarity = "Rare",
		--[[ Arrows in the fan. ]]
		levels = { 2, 3 },
		stats = { "2-way spread", "3-way spread" },
		icon = "double-shot",
	},
	{
		id = "RearArrow",
		name = "Rear Arrow",
		description = "Also fire an arrow behind you.",
		category = "Pattern",
		group = "arrow",
		rarity = "Uncommon",
		levels = { 1, 2 },
		stats = { "+1 rear", "+2 rear" },
		icon = "rear-arrow",
	},
	{
		id = "SideArrows",
		name = "Side Arrow",
		description = "Also fire arrows to your left and right.",
		category = "Pattern",
		group = "arrow",
		rarity = "Uncommon",
		--[[ Arrows to each side. ]]
		levels = { 1, 2 },
		stats = { "+1 each side", "+2 each side" },
		icon = "side-arrow",
	},
	{
		id = "DiagonalArrows",
		name = "Diagonal Arrows",
		--[[ The design says 45°. The first pair stays at the footage's
		     measured 30° (`Balance.Projectile.diagonalAngle`); the second
		     level's pair flies at 45°. ]]
		description = "Also fire arrows at diagonal angles.",
		category = "Pattern",
		group = "arrow",
		rarity = "Rare",
		levels = { 2, 4 },
		stats = { "+2 diagonal", "+4 diagonal" },
		icon = "diagonal-arrows",
	},
	{
		id = "PiercingShot",
		name = "Piercing Shot",
		description = "Arrows pass through enemies.",
		category = "Flight",
		group = "arrow",
		rarity = "Epic",
		--[[ Enemies passed through. "All" is any number a room can hold. ]]
		levels = { 1, 2, 99 },
		stats = { "Pierce 1", "Pierce 2", "Pierce all" },
		icon = "piercing-shot",
	},
	{
		id = "SwiftArrows",
		name = "Swift Arrows",
		description = "Arrows travel faster.",
		category = "Flight",
		group = "arrow",
		rarity = "Common",
		levels = { 0.15, 0.3, 0.45, 0.6, 0.75 },
		stats = { "+15% speed", "+30% speed", "+45% speed", "+60% speed", "+75% speed" },
		icon = "swift-arrows",
	},
	{
		id = "LongShot",
		name = "Long Shot",
		description = "Damage rises with distance travelled.",
		category = "OnHit",
		group = "arrow",
		rarity = "Uncommon",
		--[[ Extra damage at `Balance.Projectile.farRange` and beyond, rising
		     evenly from nothing at point blank. ]]
		levels = { 0.08, 0.16, 0.24 },
		stats = { "+8% far dmg", "+16% far dmg", "+24% far dmg" },
		icon = "long-shot",
	},
	{
		id = "BouncyWall",
		name = "Bouncy Wall",
		description = "Arrows bounce off walls.",
		category = "Flight",
		group = "arrow",
		rarity = "Uncommon",
		levels = { 1, 2 },
		stats = { "1 wall bounce", "2 wall bounces" },
		icon = "bouncy-wall",
	},
	--[[ Turn rate in degrees a second: enough to bend a shot onto a target
	     that stepped aside, not enough to turn one round. Excludes Bouncy
	     Wall — a homing arrow curves back at the wall it just left. ]]
	{
		id = "TrackingEye",
		name = "Tracking Eye",
		description = "Arrows curve toward the nearest enemy.",
		category = "Flight",
		group = "arrow",
		rarity = "Mythic",
		levels = { 540 },
		stats = { "Homing" },
		icon = "tracking-eye",
		excludes = { "BouncyWall" },
	},

	--[[ Power skills. ]]
	{
		id = "DeadlyStrike",
		name = "Deadly Strike",
		description = "Critical hits deal more damage.",
		category = "OnHit",
		group = "power",
		rarity = "Rare",
		--[[ Added to the crit multiplier, `Balance.Player.critMultiplier`. ]]
		levels = { 0.2, 0.4, 0.6, 0.8, 1.0 },
		stats = {
			"+20% crit dmg",
			"+40% crit dmg",
			"+60% crit dmg",
			"+80% crit dmg",
			"+100% crit dmg",
		},
		icon = "deadly-strike",
	},
	{
		id = "Overdraw",
		name = "Overdraw",
		description = "Stand still to charge a stronger shot.",
		category = "Stats",
		group = "power",
		rarity = "Epic",
		--[[ Extra damage once fully charged; the charge builds over
		     `Balance.Player.overdrawRamp` seconds of standing still. ]]
		levels = { 0.35, 0.7, 1.05 },
		stats = { "+35% charged", "+70% charged", "+105% charged" },
		icon = "overdraw",
	},
	{
		id = "Strength",
		name = "Strength",
		description = "Raise attack damage.",
		category = "Stats",
		group = "power",
		rarity = "Common",
		levels = { 0.1, 0.2, 0.3, 0.4, 0.5 },
		stats = { "+10% ATK", "+20% ATK", "+30% ATK", "+40% ATK", "+50% ATK" },
		icon = "strength",
	},
	{
		id = "Precision",
		name = "Precision",
		description = "Raise critical hit chance.",
		category = "Stats",
		group = "power",
		rarity = "Uncommon",
		--[[ Added to the base crit chance, `Balance.Player.critChance`. ]]
		levels = { 0.05, 0.1, 0.15, 0.2, 0.25 },
		stats = { "+5% crit", "+10% crit", "+15% crit", "+20% crit", "+25% crit" },
		icon = "precision",
	},

	--[[ Element skills: what a hit does beyond its damage. ]]
	{
		id = "Blaze",
		name = "Blaze",
		description = "Arrows set enemies on fire.",
		category = "OnHit",
		group = "element",
		rarity = "Rare",
		--[[ Seconds a burn lasts. How hard it burns is `Balance.Burn.rate`. ]]
		levels = { 2, 3, 4 },
		stats = { "Burn 2s", "Burn 3s", "Burn 4s" },
		icon = "blaze",
	},
	{
		id = "BlastArrows",
		name = "Blast Arrows",
		description = "Arrows explode on impact.",
		category = "OnHit",
		group = "element",
		rarity = "Epic",
		--[[ Blast radius in studs, at half the arrow's damage. ]]
		levels = { 3, 4.5, 6 },
		stats = { "Small blast", "Medium blast", "Large blast" },
		icon = "blast-arrows",
	},
	{
		id = "SoulChain",
		name = "Soul Chain",
		description = "Hits link nearby enemies to share damage.",
		category = "OnHit",
		group = "element",
		rarity = "Legendary",
		--[[ Enemies in the link, counting the one hit. The others take
		     `Balance.Projectile.linkShare` of the hit. ]]
		levels = { 2, 3, 4 },
		stats = { "Link 2", "Link 3", "Link 4" },
		icon = "soul-chain",
	},

	--[[ Mobility skills. ]]
	{
		id = "Momentum",
		name = "Momentum",
		--[[ Move-or-shoot means nothing fires on the move, so the speed is
		     banked by moving and spent on the shots after you stop: see
		     `Balance.Player.momentum`. ]]
		description = "Attack speed rises while moving.",
		category = "Stats",
		group = "mobility",
		rarity = "Rare",
		levels = { 0.1, 0.2, 0.3 },
		stats = { "+10% atk spd", "+20% atk spd", "+30% atk spd" },
		icon = "momentum",
	},
	{
		id = "Agility",
		name = "Agility",
		description = "Chance to dodge attacks.",
		category = "Defensive",
		group = "mobility",
		rarity = "Uncommon",
		levels = { 0.04, 0.08, 0.12, 0.16, 0.2 },
		stats = { "+4% dodge", "+8% dodge", "+12% dodge", "+16% dodge", "+20% dodge" },
		icon = "agility",
	},
	{
		id = "Lightfoot",
		name = "Lightfoot",
		description = "Move faster.",
		category = "Defensive",
		group = "mobility",
		rarity = "Common",
		levels = { 0.08, 0.16, 0.24 },
		stats = { "+8% move spd", "+16% move spd", "+24% move spd" },
		icon = "lightfoot",
	},

	--[[ Vital skills. ]]
	{
		id = "Vitality",
		name = "Vitality",
		description = "Raise max HP.",
		category = "Defensive",
		group = "vital",
		rarity = "Common",
		levels = { 0.1, 0.2, 0.3, 0.4, 0.5 },
		stats = { "+10% max HP", "+20% max HP", "+30% max HP", "+40% max HP", "+50% max HP" },
		icon = "vitality",
	},
	{
		id = "Mending",
		name = "Mending",
		description = "Regenerate HP over time.",
		category = "Defensive",
		group = "vital",
		rarity = "Uncommon",
		--[[ Share of max health a second. ]]
		levels = { 0.01, 0.02, 0.03 },
		stats = { "1% HP/s", "2% HP/s", "3% HP/s" },
		icon = "mending",
	},
	{
		id = "Bloodthirst",
		name = "Bloodthirst",
		description = "Heal a little on every kill.",
		category = "Defensive",
		group = "vital",
		rarity = "Rare",
		--[[ Share of max health per kill. ]]
		levels = { 0.02, 0.04, 0.06 },
		stats = { "Heal 2%", "Heal 4%", "Heal 6%" },
		icon = "bloodthirst",
	},
	{
		id = "SecondWind",
		name = "Second Wind",
		description = "Revive once with half your HP.",
		category = "Defensive",
		group = "vital",
		rarity = "Mythic",
		--[[ Share of max health it revives with. Once per run; a second copy
		     would make death optional. ]]
		levels = { 0.5 },
		stats = { "1 revive" },
		icon = "second-wind",
	},

	--[[ Not a skill: the heal an Angel offers, and what fills a hand when
	     the pool runs short. Never dealt by rarity. ]]
	{
		id = "Heal",
		name = "Heal",
		description = "Restore some of your health now.",
		category = "Defensive",
		group = "vital",
		rarity = "Common",
		levels = { 0.3 },
		stats = { "Heal 30%" },
		icon = "mending",
		instant = true,
		filler = true,
	},
}

--[[ Indexed as well as listed: dealing wants the list, and validating a
     client's choice wants the lookup. ]]
local byId: { [string]: Ability } = {}
for _, ability in abilities do
	byId[ability.id] = ability
end

local Abilities = {
	all = abilities,
	byId = byId,
}

return table.freeze(Abilities)
