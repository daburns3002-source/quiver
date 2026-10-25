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

	`benched` takes a card out of rotation: never dealt, its effect left in
	place so un-benching brings it back whole.
]]

local Rarities = require(script.Parent.Rarities)

export type Category = "Count" | "Pattern" | "Flight" | "OnHit" | "OnKill" | "Stats" | "Defensive"
export type Group = "arrow" | "power" | "element" | "mobility" | "vital" | "blade" | "spell"

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
	benched: boolean?,
	excludes: { string }?,
	--[[ The classes that can be dealt it; every class when absent. Each
	     class has its own Mythic (owner, 2026-10-22): the Ranger's is Dual
	     Bows, the Arcanist's homing (Tracking Eye, to become Homing Orbs
	     with the class). ]]
	classes: { string }?,
	--[[ A `Config/Weapons` entry held in place of the class's own while this
	     is drafted: the Dual Bows Mythic puts a bow in each hand. ]]
	weapon: string?,
}

--[[ Who a class card belongs to (`Ability.classes`). ]]
local RANGER = { "Ranger" }
local WARDEN = { "Warden" }
local ARCANIST = { "Arcanist" }

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
		classes = RANGER,
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
		classes = RANGER,
	},
	{
		id = "FrontArrow",
		name = "Front Arrow",
		description = "Fire another arrow.",
		category = "Count",
		group = "arrow",
		rarity = "Epic",
		--[[ Extra arrows beside the first, in a lane. ]]
		levels = { 1, 2, 3 },
		stats = { "+1 front", "+2 front", "+3 front" },
		icon = "front-arrow",
		classes = RANGER,
	},
	{
		id = "DoubleShot",
		name = "Double Shot",
		description = "Fire another arrow in a narrow spread.",
		category = "Pattern",
		group = "arrow",
		rarity = "Rare",
		--[[ Arrows in the fan. ]]
		levels = { 2, 3 },
		stats = { "2-way spread", "3-way spread" },
		icon = "double-shot",
		classes = RANGER,
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
		classes = RANGER,
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
		classes = RANGER,
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
		classes = RANGER,
	},
	{
		--[[ The Arcanist's Diagonal Arrows (owner, 2026-10-25): its level adds
		     to Diagonal Arrows' in `AbilityEffects`. ]]
		id = "DiagonalOrbs",
		name = "Diagonal Orbs",
		description = "Also cast orbs at diagonal angles.",
		category = "Pattern",
		group = "spell",
		rarity = "Rare",
		levels = { 2, 4 },
		stats = { "+2 diagonal", "+4 diagonal" },
		icon = "diagonal-orbs",
		classes = ARCANIST,
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
		classes = RANGER,
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
		classes = RANGER,
		--[[ Out of rotation (owner, 2026-10-25: cut after the class run-throughs). ]]
		benched = true,
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
		classes = RANGER,
		--[[ Out of rotation (owner, 2026-10-25: cut after the class run-throughs). ]]
		benched = true,
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
		classes = RANGER,
	},
	--[[ Turn rate in degrees a second: enough to bend a shot onto a target
	     that stepped aside, not enough to turn one round. Excludes Bouncy
	     Wall — a homing arrow curves back at the wall it just left. ]]
	{
		id = "TrackingEye",
		name = "Homing Orbs",
		description = "Orbs curve toward the nearest enemy.",
		category = "Flight",
		group = "spell",
		rarity = "Legendary",
		levels = { 540 },
		stats = { "Homing" },
		icon = "homing-orbs",
		excludes = { "BouncyWall" },
		--[[ The Arcanist's, as "Homing Orbs" (2026-10-23); its id stays
		     Tracking Eye's, the mechanic it always was. Legendary since
		     Meteor became his Mythic. ]]
		classes = { "Arcanist" },
	},
	--[[ The Ranger's Mythic: a second bow, so twice the shots. The level is
	     the extra attack speed as a fraction — 1 halves the cooldown. ]]
	{
		id = "DualBows",
		name = "Dual Bows",
		description = "A second bow. Twice the attack speed.",
		category = "Stats",
		group = "arrow",
		rarity = "Mythic",
		levels = { 1 },
		stats = { "x2 atk spd" },
		icon = "dual-bows",
		classes = { "Ranger" },
		--[[ A Twig Bow in each hand, firing in turn, from the owner's Dual
		     Bows kit (2026-10-23). ]]
		weapon = "TwigBowDual",
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
		classes = RANGER,
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
		--[[ The Arcanist draws Intellect, the same card under its own name. ]]
		classes = { "Ranger", "Warden" },
	},
	{
		--[[ The Arcanist's Strength (owner, 2026-10-25: "make the arcanist
		     class have intellect instead of strength, it will function the
		     same way"): its level adds to Strength's in `AbilityEffects`. ]]
		id = "Intellect",
		name = "Intellect",
		description = "Raise spell damage.",
		category = "Stats",
		group = "power",
		rarity = "Common",
		levels = { 0.1, 0.2, 0.3, 0.4, 0.5 },
		stats = { "+10% ATK", "+20% ATK", "+30% ATK", "+40% ATK", "+50% ATK" },
		icon = "intellect",
		classes = ARCANIST,
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
		classes = RANGER,
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
		--[[ Every class (owner, 2026-10-25): a melee blow links as an arrow does
		     (`Combat/SoulLink`). ]]
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
		--[[ Out of rotation (owner, 2026-10-24: "take the momentum upgrade
		     out of rotation"). ]]
		benched = true,
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
		--[[ Out of rotation (owner, 2026-10-25: cut after the class run-throughs). ]]
		benched = true,
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
		--[[ Out of rotation (owner, 2026-10-25: cut after the class run-throughs). ]]
		benched = true,
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
		icon = "heal",
		instant = true,
		filler = true,
	},

	--[[ The Warden's cards (docs/CLASS-CARDS.md, 2026-10-23): its greatsword
	     and its guard. Built on `Combat/MeleeSystem`. ]]
	{
		id = "QuickHands",
		name = "Quick Hands",
		description = "Swing faster.",
		category = "Stats",
		group = "blade",
		rarity = "Common",
		levels = { 0.1, 0.2, 0.3 },
		stats = { "+10% atk spd", "+20% atk spd", "+30% atk spd" },
		icon = "quick-hands",
		classes = WARDEN,
	},
	{
		id = "IronSkin",
		name = "Iron Skin",
		description = "Take less damage.",
		category = "Defensive",
		group = "vital",
		rarity = "Common",
		levels = { 0.08, 0.16, 0.24 },
		stats = { "-8% dmg taken", "-16% dmg taken", "-24% dmg taken" },
		icon = "iron-skin",
		classes = WARDEN,
		--[[ Out of rotation (owner, 2026-10-25: cut after the class run-throughs). ]]
		benched = true,
	},
	{
		id = "Cleave",
		name = "Cleave",
		description = "Your swing is wider.",
		category = "Stats",
		group = "blade",
		rarity = "Uncommon",
		levels = { 0.15, 0.3, 0.45 },
		stats = { "+15% width", "+30% width", "+45% width" },
		icon = "cleave",
		classes = WARDEN,
	},
	{
		id = "LongReach",
		name = "Long Reach",
		description = "Strike from further away.",
		category = "Stats",
		group = "blade",
		rarity = "Uncommon",
		levels = { 1.5, 3, 4.5 },
		stats = { "+1.5 reach", "+3 reach", "+4.5 reach" },
		icon = "long-reach",
		classes = WARDEN,
	},
	{
		id = "Steadfast",
		name = "Steadfast",
		description = "Your guard lingers after each swing.",
		category = "Defensive",
		group = "vital",
		rarity = "Uncommon",
		levels = { 0.3, 0.6 },
		stats = { "+0.3s guard", "+0.6s guard" },
		icon = "steadfast",
		classes = WARDEN,
		--[[ Out of rotation (owner, 2026-10-25: cut after the class run-throughs). ]]
		benched = true,
	},
	{
		id = "HeavyBlade",
		name = "Heavy Blade",
		description = "Your slam, the third blow, hits harder.",
		category = "Stats",
		group = "blade",
		rarity = "Rare",
		levels = { 0.4, 0.8, 1.2 },
		stats = { "+40% slam", "+80% slam", "+120% slam" },
		icon = "heavy-blade",
		classes = WARDEN,
	},
	{
		id = "Bloodletting",
		name = "Bloodletting",
		description = "Your blows heal you.",
		category = "Defensive",
		group = "vital",
		rarity = "Rare",
		levels = { 0.03, 0.06, 0.09 },
		stats = { "3% lifesteal", "6% lifesteal", "9% lifesteal" },
		icon = "bloodletting",
		classes = WARDEN,
		--[[ Out of rotation (owner, 2026-10-25: cut after the class run-throughs). ]]
		benched = true,
	},
	{
		id = "Execute",
		name = "Execute",
		description = "Blows hit harder on badly hurt enemies.",
		category = "Stats",
		group = "blade",
		rarity = "Legendary",
		levels = { 0.5, 1 },
		stats = { "+50% under 30% HP", "+100% under 30% HP" },
		icon = "execute",
		classes = WARDEN,
	},

	--[[ The Arcanist's cards (docs/CLASS-CARDS.md, 2026-10-23): its orbs.
	     Several are a Ranger mechanic under a spell's name. ]]
	{
		id = "BiggerOrbs",
		name = "Bigger Orbs",
		description = "Your orbs' blast is larger.",
		category = "OnHit",
		group = "spell",
		rarity = "Common",
		levels = { 0.15, 0.3, 0.45 },
		stats = { "+15% blast", "+30% blast", "+45% blast" },
		icon = "bigger-orbs",
		classes = ARCANIST,
	},
	{
		id = "ManaFlow",
		name = "Mana Flow",
		description = "Cast faster.",
		category = "Stats",
		group = "spell",
		rarity = "Common",
		levels = { 0.1, 0.2, 0.3 },
		stats = { "+10% atk spd", "+20% atk spd", "+30% atk spd" },
		icon = "mana-flow",
		classes = ARCANIST,
	},
	{
		id = "TwinCast",
		name = "Twin Cast",
		description = "An extra orb beside each cast.",
		category = "Count",
		group = "spell",
		rarity = "Rare",
		levels = { 1, 2 },
		stats = { "+1 orb", "+2 orbs" },
		icon = "twin-cast",
		classes = ARCANIST,
	},
	{
		id = "ArcaneEcho",
		name = "Arcane Echo",
		description = "Each cast repeats a moment later.",
		category = "Count",
		group = "spell",
		rarity = "Rare",
		levels = { 1, 2 },
		stats = { "+1 echo", "+2 echoes" },
		icon = "arcane-echo",
		classes = ARCANIST,
	},
	{
		id = "SpellPierce",
		name = "Spell Pierce",
		description = "Orbs pass through enemies.",
		category = "Flight",
		group = "spell",
		rarity = "Rare",
		levels = { 1, 2 },
		stats = { "Pierce 1", "Pierce 2" },
		icon = "spell-pierce",
		classes = ARCANIST,
	},
	{
		id = "ChainLightning",
		name = "Chain Lightning",
		description = "A hit arcs on to the next enemy.",
		category = "OnHit",
		group = "spell",
		rarity = "Epic",
		levels = { 2, 3 },
		stats = { "Arcs to 2", "Arcs to 3" },
		icon = "chain-lightning",
		classes = ARCANIST,
	},
	--[[ The Arcanist's Mythic (owner, 2026-10-23): every fifth cast also
	     calls a meteor down on its target (`Balance.Player.meteor`,
	     `Combat/AreaStrikes`). ]]
	{
		id = "Meteor",
		name = "Meteor",
		description = "Every 5th cast calls down a meteor on the target.",
		category = "OnHit",
		group = "spell",
		rarity = "Mythic",
		levels = { 1 },
		stats = { "Meteor every 5th cast" },
		icon = "meteor",
		classes = ARCANIST,
	},
	--[[ The Warden's Mythic (owner, 2026-10-23: "Your dash ends in a
	     leaping slam that leaves cracked ground, which erupts for damage
	     for 3s"; `Balance.Player.earthbreaker`). ]]
	{
		id = "Earthbreaker",
		name = "Earthbreaker",
		description = "Your dash ends in a leaping slam; the cracked ground erupts for 3s.",
		category = "Defensive",
		group = "blade",
		rarity = "Mythic",
		levels = { 1 },
		stats = { "Dash slam + cracks" },
		icon = "earthbreaker",
		classes = WARDEN,
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
