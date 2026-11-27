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
	Bow, Branch Staff, Timber Blade, Splinter Daggers) are Common.
]]

export type Rarity = "Common" | "Uncommon" | "Rare" | "Epic" | "Legendary" | "Mythic"

export type Stats = {
	rarity: Rarity,
	area: number,
	--[[ The Legendary's or Mythic's extra effect: cards by id, at a level. ]]
	innate: { [string]: number }?,
	--[[ What that effect says, for a card or a menu. ]]
	effect: string?,
	--[[ Earned, never sold and never rolled from a crate (`Util/ShopRules`):
	     the golden weapons, a class's level 10 (`Config/ClassLevels`), and
	     any weapon only Endless gives once one is built. There is only ever
	     one copy, so it has no merge tier (owner, 2026-11-14: "for weapons
	     with no duplicates such as these and the weapons that you get for
	     endless, there should not be a merge tier"): no badge, no MERGE, no
	     tier in its damage (`ShopRules.merges`). ]]
	earned: boolean?,
	--[[ For an earned weapon that is not a golden one: what its Gear card
	     says gets it while it is not held ("CLEAR ENDLESS ROOM 100"). A
	     golden one says its class level instead. ]]
	howEarned: string?,
	--[[ The themed set it belongs to (`Config/Shop.sets`, docs/WEAPONS-THEMED.md):
	     a weapon of no area, sold from the store's SETS shelf and in no
	     crate. Its `area` is then only its scale's, and always 1 (owner,
	     2026-11-18: the Mossy Glade's scale, as the golden weapons have). ]]
	set: string?,
}

local WeaponStats = {
	--[[ Raised from the owner's first ladder above (+5 / +15 / +25 / +40 /
	     +70%) on 2026-11-13 (balance review item 4, approved): next to the
	     merge tiers' x2.16 for C to S, rarity was flat -- an S-tier Acorn
	     Bow (about 23,000 coins of crates) out-hit a fresh Mythic, a 1%
	     pull. A Mythic is now x2.2 on its own. ]]
	bonus = {
		Common = 0,
		Uncommon = 0.1,
		Rare = 0.25,
		Epic = 0.45,
		Legendary = 0.75,
		Mythic = 1.2,
	} :: { [Rarity]: number },

	--[[
		Each area's weapons against its enemies' health, the first area's
		being 1. One step an area, 1.125, compounded: 1, 1.125, 1.266 ->
		1.25 rounded. It is no longer called provisional (owner, 2026-11-02:
		"do the weapons"). The Drowned Village still has no stages, so there
		is no area-3 enemy health to divide by and there may never be an
		exact number to find; the series is the rule instead, and it is the
		same step `Shared/Util/PetPower` walks each egg's bands up by.

		**This puts the whole of area 3 above the whole of area 1** -- an
		area-3 Rare (143.8) beats an area-1 Epic (125), an area-3 Legendary
		(175) an area-1 Mythic (170). That is the design, not a fault
		(`docs/BALANCE-REPORT.md`, finding 1): the owner asked for it in so
		many words, and no area step bigger than 1.05 can leave the rarity
		order whole, since Common to Uncommon is only 1.05 itself. What
		keeps it from biting is that an area's weapons are for sale only
		once that area is `stocked` (`Config/Shop`), which
		`tests/ConfigConsistency.spec` now holds to areas that have stages
		to earn them in.
	]]
	areaScale = { 1, 1.125, 1.25, 1.375, 1.5 } :: { number },

	weapons = {
		-- The classes' own (area 1, Common).
		TwigBow = { rarity = "Common", area = 1 },
		BranchStaff = { rarity = "Common", area = 1 },
		TimberBlade = { rarity = "Common", area = 1 },
		SplinterDaggers = { rarity = "Common", area = 1 },

		--[[ The golden weapons (owner, 2026-11-14): a class's level 10
		     (`Config/ClassLevels`). Legendary strength with a gold glow,
		     `earned` only. Area 1's scale, the area a class is levelled
		     from; each carries the one Legendary card of its class that no
		     other weapon does. ]]
		GoldenBow = {
			rarity = "Legendary",
			area = 1,
			earned = true,
			innate = { Multishot = 1 },
			effect = "Golden volley: a second arrow follows every shot.",
		},
		GoldenStaff = {
			rarity = "Legendary",
			area = 1,
			earned = true,
			innate = { TrackingEye = 1 },
			effect = "Golden sight: every orb curves toward the nearest enemy.",
		},
		GoldenBlade = {
			rarity = "Legendary",
			area = 1,
			earned = true,
			innate = { BattleCry = 1 },
			effect = "Golden cry: each kill quickens your swings.",
		},
		GoldenDaggers = {
			rarity = "Legendary",
			area = 1,
			earned = true,
			innate = { DeathMark = 1 },
			effect = "Golden mark: the toughest enemy takes more from you.",
		},

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

		--[[ The Assassin's (owner, 2026-11-16 and 17: every pair remade or
		     made in Tripo as one dagger, imported 2026-11-17). Each effect
		     is a card the Assassin draws, and no two of its weapons carry
		     the same one. ]]
		BrambleShivs = { rarity = "Uncommon", area = 1 },
		FireflyFangs = { rarity = "Rare", area = 1 },
		GladeFoxClaws = { rarity = "Epic", area = 1 },
		EmberWilfFangs = {
			rarity = "Legendary",
			area = 1,
			innate = { Blaze = 1 },
			effect = "Ember fangs: every strike sets the enemy burning.",
		},
		GlimmerhornDaggers = {
			rarity = "Mythic",
			area = 1,
			innate = { ThousandCuts = 1 },
			effect = "Glimmer shadows: every ten seconds, shadows cut every enemy.",
		},

		--[[ Area 2, Thornwood (docs/WEAPONS-THORNWOOD.md): the Assassin's
		     daggers (2026-11-17) and the bows, staffs and blades, Tripo models
		     imported 2026-11-26. Its Legendaries and Mythics carry the six
		     cards built for them ("Build the six new", owner 2026-11-18;
		     docs/CLASS-CARDS.md). Stocked since 2026-11-26 (`Config/Shop`). ]]
		HedgePrickers = { rarity = "Uncommon", area = 2 },
		TuskKnives = { rarity = "Rare", area = 2 },
		BurrfangDaggers = { rarity = "Epic", area = 2 },
		SilkfangDaggers = {
			rarity = "Legendary",
			area = 2,
			innate = { PoisonTrail = 1 },
			effect = "Silk venom: your dash leaves a cloud of poison behind.",
		},
		LurkerClaws = {
			rarity = "Mythic",
			area = 2,
			innate = { FanOfKnives = 1 },
			effect = "Lurker's thorns: a fan of thorns flies with your strikes.",
		},

		BoarTuskBow = { rarity = "Uncommon", area = 2 },
		PlumBurrBow = { rarity = "Rare", area = 2 },
		LurkerVineBow = { rarity = "Epic", area = 2 },
		SilkweaverBow = {
			rarity = "Legendary",
			area = 2,
			innate = { WebSnare = 1 },
			effect = "Silk arrows: every hit tangles the enemy in slowing webs.",
		},
		NightbarbBow = {
			rarity = "Mythic",
			area = 2,
			innate = { ThornBurst = 1 },
			effect = "Thistle arrows: every third volley erupts in thorns round its marks.",
		},

		HedgeBulbStaff = { rarity = "Uncommon", area = 2 },
		BurrTotemStaff = { rarity = "Rare", area = 2 },
		LurkerCrestStaff = { rarity = "Epic", area = 2 },
		SilkDiademStaff = {
			rarity = "Legendary",
			area = 2,
			innate = { RootHold = 1 },
			effect = "Diadem roots: every fourth cast roots what it hits in place.",
		},
		BlackspineStaff = {
			rarity = "Mythic",
			area = 2,
			innate = { BurrBlight = 1 },
			effect = "Burr blight: every orb poisons its target, stacking with repeated hits.",
		},

		BoarbackBlade = { rarity = "Uncommon", area = 2 },
		PlumguardBlade = { rarity = "Rare", area = 2 },
		BurrcrestBlade = { rarity = "Epic", area = 2 },
		SilkboundBlade = {
			rarity = "Legendary",
			area = 2,
			innate = { BoarRush = 1 },
			effect = "Boar rush: the slam shoves what it hits far away from you.",
		},
		BriarbreakerBlade = {
			rarity = "Mythic",
			area = 2,
			innate = { RuinCracks = 1 },
			effect = "Ruin cracks: the slam makes struck enemies take more damage.",
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

		--[[ The Assassin's (2026-11-17), the Drowned Village's first daggers. ]]
		DriftwoodDirks = { rarity = "Uncommon", area = 3 },
		BarnacleKnives = { rarity = "Rare", area = 3 },
		EeltoothDaggers = { rarity = "Epic", area = 3 },
		TollbellDaggers = {
			rarity = "Legendary",
			area = 3,
			innate = { SerratedEdge = 1 },
			effect = "Toll's edge: a critical strike leaves its mark taking more.",
		},
		RiptideFangs = {
			rarity = "Mythic",
			area = 3,
			innate = { Bleed = 1 },
			effect = "Riptide: every strike leaves the enemy bleeding.",
		},

		--[[ Area 4, Bogheart Caverns (docs/WEAPONS-BOGHEART.md), the low-poly
		     Tripo set imported 2026-11-06. Not stocked yet, like area 3
		     (`Config/Shop`): held and fought with in the sandbox until the
		     area has its enemies, its stages behind a portal and an
		     `Config/Economy` entry. The five daggers were remade as one
		     dagger each and wired 2026-11-17.
		     Each effect is a card its own class can draw. ]]
		PeatwoodBow = { rarity = "Uncommon", area = 4 },
		SporestringBow = { rarity = "Rare", area = 4 },
		GlowcapLongbow = { rarity = "Epic", area = 4 },
		GulpstringBow = {
			rarity = "Legendary",
			area = 4,
			innate = { PiercingShot = 1 },
			effect = "Gulp's tongue: the shot runs on through everything in line.",
		},
		LumenveilBow = {
			rarity = "Mythic",
			area = 4,
			innate = { RainOfArrows = 1 },
			effect = "Lumenveil: light rains down in arrows round the mark.",
		},

		LichenStaff = { rarity = "Uncommon", area = 4 },
		PuffballStaff = { rarity = "Rare", area = 4 },
		VentstoneStaff = { rarity = "Epic", area = 4 },
		GrandmothersStaff = {
			rarity = "Legendary",
			area = 4,
			innate = { ArcaneEcho = 1 },
			effect = "Grandmother's echo: every spell is croaked once more.",
		},
		MyceliadStaff = {
			rarity = "Mythic",
			area = 4,
			innate = { BlackHole = 1 },
			effect = "Myceliad: the roots drag the crowd into the glowing core.",
		},

		BogironBlade = { rarity = "Uncommon", area = 4 },
		ShellbackCleaver = { rarity = "Rare", area = 4 },
		CaplightBlade = { rarity = "Epic", area = 4 },
		GulpfangBlade = {
			rarity = "Legendary",
			area = 4,
			innate = { CounterStrike = 1 },
			effect = "Gulpfang: a blow taken is snapped straight back.",
		},
		DeepglowBlade = {
			rarity = "Mythic",
			area = 4,
			innate = { Earthbreaker = 1 },
			effect = "Deepglow: the lake crystal splits the cavern floor.",
		},

		MossShivs = { rarity = "Uncommon", area = 4 },
		SporeFangs = { rarity = "Rare", area = 4 },
		GlowcapKris = { rarity = "Epic", area = 4 },
		ToadtongueDaggers = {
			rarity = "Legendary",
			area = 4,
			innate = { Backstab = 1 },
			effect = "Toad's ambush: a strike from behind lands harder.",
		},
		PrismStingers = {
			rarity = "Mythic",
			area = 4,
			innate = { PhantomBlades = 1 },
			effect = "Prism shards: two ghost daggers circle you and cut what they touch.",
		},

		--[[ The Windswept Cliffs, area 5 (docs/WINDSWEPT-CLIFFS.md, owner's
		     go 2026-11-26): Tripo models of Codex's front views
		     (`assets/concepts/blocky/weapons/skins/windswept/`), one dagger
		     each. Each Legendary's and Mythic's effect is a card its own
		     class can draw; Wind Arrows, Phoenix Arrow, Arcane Shield, Shield
		     Throw and Quickstep were no weapon's before. ]]
		SlatewoodBow = { rarity = "Uncommon", area = 5 },
		HarpyBow = { rarity = "Rare", area = 5 },
		GalestringLongbow = { rarity = "Epic", area = 5 },
		RocsWingBow = {
			rarity = "Legendary",
			area = 5,
			innate = { WindArrows = 1 },
			effect = "Roc's wing: arrows knock enemies twice as far and blow their shots away.",
		},
		SkyrenderBow = {
			rarity = "Mythic",
			area = 5,
			innate = { PhoenixArrow = 1 },
			effect = "Skyrender: every 8th arrow is a thunderbird that tears through everything.",
		},

		CloudspunStaff = { rarity = "Uncommon", area = 5 },
		GustcallerStaff = { rarity = "Rare", area = 5 },
		PrayerflagStaff = { rarity = "Epic", area = 5 },
		TempestStaff = {
			rarity = "Legendary",
			area = 5,
			innate = { ArcaneShield = 1 },
			effect = "Tempest ward: a wall of wind blocks one hit, then comes back.",
		},
		EyeOfTheStorm = {
			rarity = "Mythic",
			area = 5,
			innate = { ChainLightning = 1 },
			effect = "Eye of the storm: every orb arcs on to two more.",
		},

		LedgestoneBlade = { rarity = "Uncommon", area = 5 },
		RamhornCleaver = { rarity = "Rare", area = 5 },
		WindcutterBlade = { rarity = "Epic", area = 5 },
		StormtalonBlade = {
			rarity = "Legendary",
			area = 5,
			innate = { ShieldThrow = 1 },
			effect = "Stormtalon: your dash flings a talon that bounces between three enemies.",
		},
		ThunderheadBlade = {
			rarity = "Mythic",
			area = 5,
			innate = { BladeStorm = 1 },
			effect = "Thunderhead: every fifth swing throws a thundercloud sword out and back.",
		},

		FlintTalon = { rarity = "Uncommon", area = 5 },
		HarpyClaw = { rarity = "Rare", area = 5 },
		StormQuill = { rarity = "Epic", area = 5 },
		ThunderbeakDagger = {
			rarity = "Legendary",
			area = 5,
			innate = { Quickstep = 1 },
			effect = "Tailwind: a kill brings your dash back sooner.",
		},
		ZephyrFang = {
			rarity = "Mythic",
			area = 5,
			innate = { VengefulSpirit = 1 },
			effect = "Zephyr: a fan of feathers flies with your strikes.",
		},

		--[[ Neon Circuit (owner, 2026-11-18; docs/WEAPONS-THEMED.md): a themed
		     set, one Legendary for every class, of no area (`set`), sold on
		     the shop's SETS shelf for coins and gems and in no crate. ]]
		LivewireBow = {
			rarity = "Legendary",
			area = 1,
			set = "NeonCircuit",
			innate = { SplitShot = 1 },
			effect = "Livewire: a shot that kills sparks off into three more.",
		},
		MainframeStaff = {
			rarity = "Legendary",
			area = 1,
			set = "NeonCircuit",
			innate = { ArcaneTurret = 1 },
			effect = "Mainframe: every ten seconds a crystal boots up beside you and casts orbs.",
		},
		OverclockBlade = {
			rarity = "Legendary",
			area = 1,
			set = "NeonCircuit",
			innate = { BladeStorm = 1 },
			effect = "Overclock: every fifth swing throws a spinning blade out and back.",
		},
		GlitchDaggers = {
			rarity = "Legendary",
			area = 1,
			set = "NeonCircuit",
			innate = { Execute = 1 },
			effect = "Glitch: blows hit harder on a badly hurt enemy.",
		},
		-- THEMED SETS BEGIN (assets/models/weapons/blocky/themed_sets/sets.py; regenerate, never hand-edit)
		WishbrightBow = {
			rarity = "Legendary",
			area = 1,
			set = "Starwish",
			innate = { BlastArrows = 1 },
			effect = "Wishbright: arrows burst like shooting stars where they land.",
		},
		DreamdropStaff = {
			rarity = "Legendary",
			area = 1,
			set = "Starwish",
			innate = { ElementalOrbs = 1 },
			effect = "Dreamdrop: each wish flies out as fire, ice or lightning in turn.",
		},
		--[[ Season 1's free reward (owner, 2026-11-19: "the wishcutter blade
		     should be the legendary that goes in the free battle pass for
		     tier 30"): earned, so off the SETS shelf (`Config/Season`). ]]
		WishcutterBlade = {
			rarity = "Legendary",
			area = 1,
			set = "Starwish",
			earned = true,
			howEarned = "SEASON 1 PASS, TIER 30",
			innate = { Whirlwind = 1 },
			effect = "Wishcutter: every few swings you spin in a ring of stars.",
		},
		TwinkleDaggers = {
			rarity = "Legendary",
			area = 1,
			set = "Starwish",
			innate = { WishingStar = 1 },
			effect = "Twinkle: every fifth strike drops a wishing star that bursts round the enemy.",
		},
		SaddlehornBow = {
			rarity = "Legendary",
			area = 1,
			set = "Tumbleweed",
			innate = { Ricochet = 1 },
			effect = "Saddlehorn: a trick shot bounces on to the next enemy.",
		},
		WagonwheelStaff = {
			rarity = "Legendary",
			area = 1,
			set = "Tumbleweed",
			innate = { ChainLightning = 1 },
			effect = "Wagonwheel: a hit lassoes on to the next enemy.",
		},
		TrailbossBlade = {
			rarity = "Legendary",
			area = 1,
			set = "Tumbleweed",
			innate = { BattleCry = 1 },
			effect = "Trailboss: each kill quickens your swings, stacking.",
		},
		SpurDaggers = {
			rarity = "Legendary",
			area = 1,
			set = "Tumbleweed",
			innate = { SpurRowel = 1 },
			effect = "Spur: the double stab flings a spinning spur that bounces between three enemies.",
		},
		NoodleBow = {
			rarity = "Legendary",
			area = 1,
			set = "SplashDay",
			innate = { PiercingShot = 1 },
			effect = "Noodle: the water jet runs on through everything in line.",
		},
		SplashringStaff = {
			rarity = "Legendary",
			area = 1,
			set = "SplashDay",
			innate = { SpellPierce = 1 },
			effect = "Splashring: the splash runs on through every enemy in line.",
		},
		BreakerBlade = {
			rarity = "Legendary",
			area = 1,
			set = "SplashDay",
			innate = { Shockwave = 1 },
			effect = "Breaker: your slam sends a wave rolling forward along the ground.",
		},
		SquirtDaggers = {
			rarity = "Legendary",
			area = 1,
			set = "SplashDay",
			innate = { SplashWave = 1 },
			effect = "Squirt: every third strike splashes the enemies round it and slows them down.",
		},
		HighscoreBow = {
			rarity = "Legendary",
			area = 1,
			set = "CoinOp",
			innate = { FrontArrow = 1 },
			effect = "Highscore: power-up! Extra arrows fly beside the first.",
		},
		JoystickStaff = {
			rarity = "Legendary",
			area = 1,
			set = "CoinOp",
			innate = { TwinCast = 1 },
			effect = "Joystick: two-player mode, an extra orb flies beside each one.",
		},
		PixelBlade = {
			rarity = "Legendary",
			area = 1,
			set = "CoinOp",
			innate = { CounterStrike = 1 },
			effect = "Pixel: getting hit powers up your next swing to triple damage.",
		},
		TokenDaggers = {
			rarity = "Legendary",
			area = 1,
			set = "CoinOp",
			innate = { ComboCounter = 1 },
			effect = "Token: every strike that lands adds to your combo, up to +30% damage, until you are hit.",
		},
		OrbitBow = {
			rarity = "Legendary",
			area = 1,
			set = "Voidglass",
			innate = { RainOfArrows = 1 },
			effect = "Orbit: every sixth shot calls a shower of falling stars onto the target.",
		},
		StarwellStaff = {
			rarity = "Legendary",
			area = 1,
			set = "Voidglass",
			innate = { TrackingEye = 1 },
			effect = "Starwell: orbs fall into orbit round the nearest enemy.",
		},
		--[[ Mythic, Endless room 100's (owner, 2026-11-19: "nebula blade and
		     petalfall blade should be mythics", "Nebula: Endless 100"):
		     earned there once, never sold (`Balance.endless.milestones`). ]]
		NebulaBlade = {
			rarity = "Mythic",
			area = 1,
			set = "Voidglass",
			earned = true,
			howEarned = "CLEAR ENDLESS ROOM 100",
			innate = { Parry = 1 },
			effect = "Nebula: your swings knock enemy shots out of the air.",
		},
		CometDaggers = {
			rarity = "Legendary",
			area = 1,
			set = "Voidglass",
			innate = { CometCrash = 1 },
			effect = "Comet: a strike calls down a comet that crashes onto the enemy a moment later.",
		},
		BlossomBow = {
			rarity = "Legendary",
			area = 1,
			set = "LanternBloom",
			innate = { Multishot = 1 },
			effect = "Blossom: each shot is followed by a flurry of petal arrows.",
		},
		PaperglowStaff = {
			rarity = "Legendary",
			area = 1,
			set = "LanternBloom",
			innate = { ArcaneTurret = 1 },
			effect = "Paperglow: every ten seconds a paper lantern floats up beside you and casts orbs.",
		},
		--[[ Mythic, Season 1's premium reward at tier 30 (owner, 2026-11-19:
		     the end of the battle pass, "Premium"): earned, never sold
		     (`Config/Season`). ]]
		PetalfallBlade = {
			rarity = "Mythic",
			area = 1,
			set = "LanternBloom",
			earned = true,
			howEarned = "SEASON 1 PREMIUM PASS, TIER 30",
			innate = { Sunder = 1 },
			effect = "Petalfall: petals settle on what you strike, and it takes more damage from everything for 3s.",
		},
		BellchimeDaggers = {
			rarity = "Legendary",
			area = 1,
			set = "LanternBloom",
			innate = { BellChime = 1 },
			effect = "Bellchime: every sixth strike rings a bell that holds the enemies near you still.",
		},
		CinderstringBow = {
			rarity = "Legendary",
			area = 1,
			set = "Cinderforge",
			innate = { SniperShot = 1 },
			effect = "Cinderstring: stand still and the string heats a red-hot arrow that pierces all and crits.",
		},
		ForgeheartStaff = {
			rarity = "Legendary",
			area = 1,
			set = "Cinderforge",
			innate = { ManaSurge = 1 },
			effect = "Forgeheart: a kill stokes the forge, and the next cast is bigger and harder.",
		},
		MoltenBlade = {
			rarity = "Legendary",
			area = 1,
			set = "Cinderforge",
			innate = { HeavyBlade = 1 },
			effect = "Molten: your third blow lands like a hammer on an anvil.",
		},
		EmbershardDaggers = {
			rarity = "Legendary",
			area = 1,
			set = "Cinderforge",
			innate = { LavaBurst = 1 },
			effect = "Embershard: the double stab sends lava bursting along the ground, setting enemies burning.",
		},
		-- THEMED SETS END
	} :: { [string]: Stats },
}

return table.freeze(WeaponStats)
