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
	--[[ `levels` counts those levels beaten too (`SaveSchema.levelsBeaten`),
	     so what waits on one can be reached from Play: 1-10 opens the
	     Endless portal (`docs/ENDLESS.md`), which otherwise needs the whole
	     of Mossy Glade played first. ]]
	testUnlock = {
		coins = 50000,
		gems = 2000,
		bosses = { "MossyGlade" },
		levels = { "1-10" },
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
