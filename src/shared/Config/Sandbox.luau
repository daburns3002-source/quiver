--!strict
--[[
	The playtest sandbox (owner, 2026-10-24: "make a playtest environment
	with a menu where i can select my weapon and pet so i can see those
	models"). Studio only: the menu (`UI/SandboxMenu`, the O key) swaps the
	room's fight for training dummies that never die or hit back, and puts
	any weapon in hand and any imported pet at heel.

	Which weapons the menu lists, and the class each is held as: a weapon
	plays its class's attack (a bow shoots arrows, a blade swings). Every
	`Config/Weapons` entry belongs here; `tests/Sandbox.spec` fails when a
	new one is missing, so a new weapon can always be looked at.
]]

export type Entry = { weapon: string, class: string, label: string }

local Sandbox = {
	--[[ Studio only: the room of a Rooms stage a run starts in, to test a
	     late room straight from Play; nil starts at the first. Back to the
	     first for the run-throughs (owner, 2026-10-25: "start it at room 1
	     not 20"); it was 40 for the Broodmother. Never honoured in a live
	     server. ]]
	startRoom = nil :: number?,
	--[[ Studio only: the Blacksmith's shop opens by itself on arriving in
	     the lobby, with this much in the wallet to try it (owner,
	     2026-10-25: "let me see the shop ui when i load the playtest"). nil
	     leaves it shut: off for the run-through from the intro to the
	     lobby (owner, 2026-10-26). Never honoured in a live server. ]]
	openShop = nil :: { coins: number, gems: number, items: number }?,
	--[[ Studio only: on joining, this much in the wallet and these areas'
	     bosses counted as beaten, so every egg and crate can be tried
	     (owner, 2026-10-26: "unlock both eggs so i can test them"). nil for
	     a run-through as a new player. Never honoured in a live server. ]]
	--[[ Studio only: the tutorial plays even though `testUnlock` counts 1-1
	     as beaten. The playtest wants the intro, the title and the tutorial
	     AND the areas open (owner, 2026-10-28), and those pull against each
	     other: opening 1-2 needs 1-1 beaten, and 1-1 beaten is the very flag
	     `Util/LevelUnlocks.tutorialOwed` reads to decide the tutorial is
	     done. This overrides it. nil leaves the tutorial to the profile, as
	     a live server always does. ]]
	forceTutorial = true :: boolean?,
	--[[ `levels` counts those levels beaten too (`SaveSchema.levelsBeaten`),
	     so what waits on one can be reached from Play. All ten of Mossy
	     Glade for the playtest (owner, 2026-10-28: "the mossy glade areas
	     and thornwood areas are unlocked"), because a level only opens once
	     the one before it is beaten (`LevelUnlocks.isUnlocked`) — 1-10 alone
	     left 1-2..1-9 shut. Thornwood's levels are all beaten too; its boss is in `bosses` so what that gates can
	     be tried too. ]]
	testUnlock = {
		coins = 50000,
		gems = 2000,
		bosses = { "MossyGlade", "Thornwood" },
		--[[ Thornwood's ten too, since it became 2-1..2-10 (2026-11-13). ]]
		levels = {
			"1-1",
			"1-2",
			"1-3",
			"1-4",
			"1-5",
			"1-6",
			"1-7",
			"1-8",
			"1-9",
			"1-10",
			"2-1",
			"2-2",
			"2-3",
			"2-4",
			"2-5",
			"2-6",
			"2-7",
			"2-8",
			"2-9",
			"2-10",
		},
	} :: {
		coins: number,
		gems: number,
		bosses: { string },
		levels: { string },
	}?,
	weapons = {
		{ weapon = "TwigBow", class = "Ranger", label = "TWIG BOW" },
		{ weapon = "TwigBowDual", class = "Ranger", label = "DUAL TWIG BOWS" },
		{ weapon = "BranchStaff", class = "Arcanist", label = "BRANCH STAFF" },
		{ weapon = "TimberBlade", class = "Warden", label = "TIMBER BLADE" },
		{ weapon = "SplinterDaggers", class = "Assassin", label = "SPLINTER DAGGERS" },
		-- SKINS BEGIN (assets/models/weapons/skins_to_luau.py; regenerate, never hand-edit)
		{ weapon = "AcornBow", class = "Ranger", label = "ACORN BOW" },
		{ weapon = "FireflyBow", class = "Ranger", label = "FIREFLY BOW" },
		{ weapon = "MossSlimeBow", class = "Ranger", label = "MOSS SLIME BOW" },
		{ weapon = "EmberFangBow", class = "Ranger", label = "EMBER FANG BOW" },
		{ weapon = "GladeSpiritBow", class = "Ranger", label = "GLADE SPIRIT BOW" },
		{ weapon = "ToadstoolStaff", class = "Arcanist", label = "TOADSTOOL STAFF" },
		{ weapon = "LanternStaff", class = "Arcanist", label = "LANTERN STAFF" },
		{ weapon = "HootmossStaff", class = "Arcanist", label = "HOOTMOSS STAFF" },
		{ weapon = "SlimeCrownStaff", class = "Arcanist", label = "SLIME CROWN STAFF" },
		{ weapon = "WorldrootStaff", class = "Arcanist", label = "WORLDROOT STAFF" },
		{ weapon = "MossstoneBlade", class = "Warden", label = "MOSSSTONE BLADE" },
		{ weapon = "ThornBlade", class = "Warden", label = "THORN BLADE" },
		{ weapon = "BroodsplitBlade", class = "Warden", label = "BROODSPLIT BLADE" },
		{ weapon = "EmberfangBlade", class = "Warden", label = "EMBERFANG BLADE" },
		{ weapon = "GladeheartBlade", class = "Warden", label = "GLADEHEART BLADE" },
		{ weapon = "ReedStaff", class = "Arcanist", label = "REED STAFF" },
		{ weapon = "TidewoodBlade", class = "Warden", label = "TIDEWOOD BLADE" },
		{ weapon = "SlatefinBow", class = "Ranger", label = "SLATEFIN BOW" },
		{ weapon = "TidehookBlade", class = "Warden", label = "TIDEHOOK BLADE" },
		{ weapon = "EelcrestBow", class = "Ranger", label = "EELCREST BOW" },
		{ weapon = "WellpearlStaff", class = "Arcanist", label = "WELLPEARL STAFF" },
		{ weapon = "CausewayBlade", class = "Warden", label = "CAUSEWAY BLADE" },
		{ weapon = "TollstringBow", class = "Ranger", label = "TOLLSTRING BOW" },
		{ weapon = "TollkeeperStaff", class = "Arcanist", label = "TOLLKEEPER STAFF" },
		{ weapon = "TollguardBlade", class = "Warden", label = "TOLLGUARD BLADE" },
		{ weapon = "BuoyStaff", class = "Arcanist", label = "BUOY STAFF" },
		{ weapon = "EventideBow", class = "Ranger", label = "EVENTIDE BOW" },
		{ weapon = "MaelstromStaff", class = "Arcanist", label = "MAELSTROM STAFF" },
		{ weapon = "StormglassBlade", class = "Warden", label = "STORMGLASS BLADE" },
		{ weapon = "PeatwoodBow", class = "Ranger", label = "PEATWOOD BOW" },
		{ weapon = "SporestringBow", class = "Ranger", label = "SPORESTRING BOW" },
		{ weapon = "GlowcapLongbow", class = "Ranger", label = "GLOWCAP LONGBOW" },
		{ weapon = "GulpstringBow", class = "Ranger", label = "GULPSTRING BOW" },
		{ weapon = "LumenveilBow", class = "Ranger", label = "LUMENVEIL BOW" },
		{ weapon = "LichenStaff", class = "Arcanist", label = "LICHEN STAFF" },
		{ weapon = "PuffballStaff", class = "Arcanist", label = "PUFFBALL STAFF" },
		{ weapon = "VentstoneStaff", class = "Arcanist", label = "VENTSTONE STAFF" },
		{ weapon = "GrandmothersStaff", class = "Arcanist", label = "GRANDMOTHER'S STAFF" },
		{ weapon = "MyceliadStaff", class = "Arcanist", label = "MYCELIAD STAFF" },
		{ weapon = "BogironBlade", class = "Warden", label = "BOGIRON BLADE" },
		{ weapon = "ShellbackCleaver", class = "Warden", label = "SHELLBACK CLEAVER" },
		{ weapon = "CaplightBlade", class = "Warden", label = "CAPLIGHT BLADE" },
		{ weapon = "GulpfangBlade", class = "Warden", label = "GULPFANG BLADE" },
		{ weapon = "DeepglowBlade", class = "Warden", label = "DEEPGLOW BLADE" },
		{ weapon = "GoldenBow", class = "Ranger", label = "GOLDEN BOW" },
		{ weapon = "GoldenStaff", class = "Arcanist", label = "GOLDEN STAFF" },
		{ weapon = "GoldenBlade", class = "Warden", label = "GOLDEN BLADE" },
		{ weapon = "BrambleShivs", class = "Assassin", label = "BRAMBLE SHIVS" },
		{ weapon = "FireflyFangs", class = "Assassin", label = "FIREFLY FANGS" },
		{ weapon = "GladeFoxClaws", class = "Assassin", label = "GLADE FOX CLAWS" },
		{ weapon = "EmberWilfFangs", class = "Assassin", label = "EMBER WILF FANGS" },
		{ weapon = "GlimmerhornDaggers", class = "Assassin", label = "GLIMMERHORN DAGGERS" },
		{ weapon = "HedgePrickers", class = "Assassin", label = "HEDGE PRICKERS" },
		{ weapon = "TuskKnives", class = "Assassin", label = "TUSK KNIVES" },
		{ weapon = "BurrfangDaggers", class = "Assassin", label = "BURRFANG DAGGERS" },
		{ weapon = "SilkfangDaggers", class = "Assassin", label = "SILKFANG DAGGERS" },
		{ weapon = "LurkerClaws", class = "Assassin", label = "LURKER CLAWS" },
		{ weapon = "DriftwoodDirks", class = "Assassin", label = "DRIFTWOOD DIRKS" },
		{ weapon = "BarnacleKnives", class = "Assassin", label = "BARNACLE KNIVES" },
		{ weapon = "EeltoothDaggers", class = "Assassin", label = "EELTOOTH DAGGERS" },
		{ weapon = "TollbellDaggers", class = "Assassin", label = "TOLLBELL DAGGERS" },
		{ weapon = "RiptideFangs", class = "Assassin", label = "RIPTIDE FANGS" },
		{ weapon = "MossShivs", class = "Assassin", label = "MOSS SHIVS" },
		{ weapon = "SporeFangs", class = "Assassin", label = "SPORE FANGS" },
		{ weapon = "GlowcapKris", class = "Assassin", label = "GLOWCAP KRIS" },
		{ weapon = "ToadtongueDaggers", class = "Assassin", label = "TOADTONGUE DAGGERS" },
		{ weapon = "PrismStingers", class = "Assassin", label = "PRISM STINGERS" },
		{ weapon = "GoldenDaggers", class = "Assassin", label = "GOLDEN DAGGERS" },
		{ weapon = "LivewireBow", class = "Ranger", label = "LIVEWIRE BOW" },
		{ weapon = "MainframeStaff", class = "Arcanist", label = "MAINFRAME STAFF" },
		{ weapon = "OverclockBlade", class = "Warden", label = "OVERCLOCK BLADE" },
		{ weapon = "GlitchDaggers", class = "Assassin", label = "GLITCH DAGGERS" },
		{ weapon = "WishbrightBow", class = "Ranger", label = "WISHBRIGHT BOW" },
		{ weapon = "DreamdropStaff", class = "Arcanist", label = "DREAMDROP STAFF" },
		{ weapon = "WishcutterBlade", class = "Warden", label = "WISHCUTTER BLADE" },
		{ weapon = "TwinkleDaggers", class = "Assassin", label = "TWINKLE DAGGERS" },
		{ weapon = "SaddlehornBow", class = "Ranger", label = "SADDLEHORN BOW" },
		{ weapon = "WagonwheelStaff", class = "Arcanist", label = "WAGONWHEEL STAFF" },
		{ weapon = "TrailbossBlade", class = "Warden", label = "TRAILBOSS BLADE" },
		{ weapon = "SpurDaggers", class = "Assassin", label = "SPUR DAGGERS" },
		{ weapon = "NoodleBow", class = "Ranger", label = "NOODLE BOW" },
		{ weapon = "SplashringStaff", class = "Arcanist", label = "SPLASHRING STAFF" },
		{ weapon = "BreakerBlade", class = "Warden", label = "BREAKER BLADE" },
		{ weapon = "SquirtDaggers", class = "Assassin", label = "SQUIRT DAGGERS" },
		{ weapon = "HighscoreBow", class = "Ranger", label = "HIGHSCORE BOW" },
		{ weapon = "JoystickStaff", class = "Arcanist", label = "JOYSTICK STAFF" },
		{ weapon = "PixelBlade", class = "Warden", label = "PIXEL BLADE" },
		{ weapon = "TokenDaggers", class = "Assassin", label = "TOKEN DAGGERS" },
		{ weapon = "OrbitBow", class = "Ranger", label = "ORBIT BOW" },
		{ weapon = "StarwellStaff", class = "Arcanist", label = "STARWELL STAFF" },
		{ weapon = "NebulaBlade", class = "Warden", label = "NEBULA BLADE" },
		{ weapon = "CometDaggers", class = "Assassin", label = "COMET DAGGERS" },
		{ weapon = "BlossomBow", class = "Ranger", label = "BLOSSOM BOW" },
		{ weapon = "PaperglowStaff", class = "Arcanist", label = "PAPERGLOW STAFF" },
		{ weapon = "PetalfallBlade", class = "Warden", label = "PETALFALL BLADE" },
		{ weapon = "BellchimeDaggers", class = "Assassin", label = "BELLCHIME DAGGERS" },
		{ weapon = "CinderstringBow", class = "Ranger", label = "CINDERSTRING BOW" },
		{ weapon = "ForgeheartStaff", class = "Arcanist", label = "FORGEHEART STAFF" },
		{ weapon = "MoltenBlade", class = "Warden", label = "MOLTEN BLADE" },
		{ weapon = "EmbershardDaggers", class = "Assassin", label = "EMBERSHARD DAGGERS" },
		-- SKINS END
	} :: { Entry },

	--[[ The training dummies: copies of a `Balance.Enemies` archetype (its
	     look and hitbox) that stand still, never attack and refill their
	     health on every hit (`EnemyConfig.dummy`), at XZ offsets from the
	     arena's centre, between the player's spawn and the middle. ]]
	dummy = {
		archetype = "MeleeCharger",
		health = 1e6,
		spots = {
			Vector3.new(-7, 0, 7),
			Vector3.new(0, 0, 3),
			Vector3.new(7, 0, 7),
		},
	},
}

return table.freeze(Sandbox)
