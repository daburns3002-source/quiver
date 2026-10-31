--!strict
--[[
	What a weapon is worth in a fight (owner, 2026-10-25): "the common
	weapons will be unchanged in power, the uncommon weapons of every area
	will have a 5% damage buff, the rare weapons will all have a 15% damage
	buff, the epics will have a 25% damage buff, the legendary weapons will
	have a 40% damage buff and an extra effect depending on the weapon, the
	mythics will have a 70% damage buff and an extra effect. every stage
	will get harder with enemies having more health so the weapons will
	scale accordingly."

	A weapon's damage is the player's, times (1 + its rarity's `bonus`),
	times its area's `areaScale`: each area's weapons keep up with that
	area's tougher enemies (Level 2's enemies have 0.9 health against Level
	1's 0.8, so area 2's weapons hit 1.125 times as hard). Pets and weapons
	are what grow a player's power; the run's cards stay modest.

	A Legendary's or a Mythic's extra effect is `innate`: cards it carries
	built in, at these levels, added to any drafted copy as a class's own
	innate skills are (`Combat/AbilityEffects`). The class weapons (Twig
	Bow, Branch Staff, Timber Blade) are Common.
]]

export type Rarity = "Common" | "Uncommon" | "Rare" | "Epic" | "Legendary" | "Mythic"

export type Stats = {
	rarity: Rarity,
	area: number,
	--[[ The Legendary's or Mythic's extra effect: cards by id, at a level. ]]
	innate: { [string]: number }?,
	--[[ What that effect says, for a card or a menu. ]]
	effect: string?,
}

local WeaponStats = {
	bonus = {
		Common = 0,
		Uncommon = 0.05,
		Rare = 0.15,
		Epic = 0.25,
		Legendary = 0.4,
		Mythic = 0.7,
	} :: { [Rarity]: number },

	--[[ Each area's weapons against its enemies' health, the first area's
	     being 1. ]]
	--[[ Area 3's 1.25 is provisional: the Drowned Village has no stages in
	     `Balance.Stages` yet, so there is no enemy health to divide by. It
	     follows the step area 1 to 2 made (0.8 to 0.9 health, 1 to 1.125) on
	     the assumption area 3 lands near 1.0, and should be re-derived once
	     its stages exist. ]]
	areaScale = { 1, 1.125, 1.25 } :: { number },

	weapons = {
		-- The classes' own (area 1, Common).
		TwigBow = { rarity = "Common", area = 1 },
		BranchStaff = { rarity = "Common", area = 1 },
		TimberBlade = { rarity = "Common", area = 1 },

		-- Area 1, the Mossy Glade's skins (docs/PETS-FOREST.md).
		AcornBow = { rarity = "Uncommon", area = 1 },
		FireflyBow = { rarity = "Rare", area = 1 },
		MossSlimeBow = { rarity = "Epic", area = 1 },
		EmberFangBow = {
			rarity = "Legendary",
			area = 1,
			innate = { Blaze = 1 },
			effect = "Ember arrows: every hit sets the enemy burning.",
		},
		GladeSpiritBow = {
			rarity = "Mythic",
			area = 1,
			innate = { TrackingEye = 1 },
			effect = "Spirit arrows: every arrow homes in on its target.",
		},

		ToadstoolStaff = { rarity = "Uncommon", area = 1 },
		LanternStaff = { rarity = "Rare", area = 1 },
		HootmossStaff = { rarity = "Epic", area = 1 },
		SlimeCrownStaff = {
			rarity = "Legendary",
			area = 1,
			innate = { SpellPierce = 1 },
			effect = "Royal orbs: every orb pierces one enemy.",
		},
		WorldrootStaff = {
			rarity = "Mythic",
			area = 1,
			innate = { ChainLightning = 1 },
			effect = "Root lightning: every orb arcs on to two more enemies.",
		},

		MossstoneBlade = { rarity = "Uncommon", area = 1 },
		ThornBlade = { rarity = "Rare", area = 1 },
		BroodsplitBlade = { rarity = "Epic", area = 1 },
		EmberfangBlade = {
			rarity = "Legendary",
			area = 1,
			innate = { Shockwave = 1 },
			effect = "Ember wave: the slam sends a wave of fire forward.",
		},
		GladeheartBlade = {
			rarity = "Mythic",
			area = 1,
			innate = { Whirlwind = 1 },
			effect = "Heartwood whirl: every fourth swing spins all around you.",
		},

		--[[ Area 3, the Drowned Village (docs/WEAPONS-DROWNED.md). Tiers read
		     off Codex's sheets; there is no Uncommon bow at all.

		     The area is not stocked yet (`Config/Shop`'s `stocked`), so none
		     of these can be bought: they have no 2D icons and the area has no
		     `Config/Economy` entry to price a Legendary against. They are
		     held and fought with in the sandbox, and the three toll weapons
		     and three Mythics carry their effects so the ladder is whole when
		     the area opens.

		     Each effect is a card its own class can draw: a bow's is the
		     Ranger's, a staff's the Arcanist's, a blade's the Warden's. ]]
		SlatefinBow = { rarity = "Rare", area = 3 },
		EelcrestBow = { rarity = "Epic", area = 3 },
		TollstringBow = {
			rarity = "Legendary",
			area = 3,
			innate = { Ricochet = 1 },
			effect = "Toll's echo: the shot rings off its mark on to another.",
		},

		ReedStaff = { rarity = "Uncommon", area = 3 },
		WellpearlStaff = { rarity = "Epic", area = 3 },
		TollkeeperStaff = {
			rarity = "Legendary",
			area = 3,
			innate = { TwinCast = 1 },
			effect = "Keeper's second strike: the bell is rung twice.",
		},

		TidewoodBlade = { rarity = "Uncommon", area = 3 },
		TidehookBlade = { rarity = "Rare", area = 3 },
		CausewayBlade = { rarity = "Epic", area = 3 },
		TollguardBlade = {
			rarity = "Legendary",
			area = 3,
			innate = { Parry = 1 },
			effect = "Guard's answer: a blow turned aside is turned back.",
		},

		--[[ The four imported 2026-10-31, completing the ladder. ]]
		BuoyStaff = { rarity = "Rare", area = 3 },
		EventideBow = {
			rarity = "Mythic",
			area = 3,
			innate = { SoulChain = 1 },
			effect = "Eventide: a drowned soul leaps from the dead to the living.",
		},
		MaelstromStaff = {
			rarity = "Mythic",
			area = 3,
			innate = { Meteor = 1 },
			effect = "Maelstrom: the sea falls in where the spell lands.",
		},
		StormglassBlade = {
			rarity = "Mythic",
			area = 3,
			innate = { Execute = 1 },
			effect = "Stormglass: a wounded enemy is sheared clean through.",
		},
	} :: { [string]: Stats },
}

return table.freeze(WeaponStats)
