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
	     late room straight from Play; nil starts at the first. Room 40 is the
	     Broodmother (owner, 2026-10-25: "take me to room 40 and let me test
	     it myself"). Never honoured in a live server. ]]
	startRoom = 40 :: number?,
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
