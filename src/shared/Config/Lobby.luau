--!strict
--[[
	The lobby (owner, 2026-10-25: "this lobby needs to be created in the same
	top down way the gameplay is. it should be in the foresty vibe like mossy
	glade is ... it should also have area portals that players are able to
	go into that will launch them into the specific areas. for now the only
	2 areas will be mossy glade and thornwood"). Its look is the owner's pick,
	layout C "Three Groves" without the egg breeder
	(`assets/concepts/blocky/lobby/lobby_three_groves.png`).

	A forest clearing beside the arena, far enough away that neither is ever
	on screen with the other. Players arrive at its campfire after BEGIN
	ADVENTURE, walk between the stations (scenery for now: each becomes
	usable as its feature is built), and step into an active portal to start
	that area's run (`Run/Lobby`, `Run/RoomController.beginStage`); from
	there NEXT LEVEL and TRY AGAIN carry on as before (`Balance.campaign`).

	Positions are studs from the lobby's centre on its floor; north is −Z,
	as in the arena, so the portals stand at the top of the screen. The
	pieces are the owner's Claude Design kit (`assets/models/lobby/
	lobby_kit/`), bundled like an arena kit (`ArenaKits.Piece`): until a
	piece's mesh is imported it is simply not drawn, and the lobby still
	works.
]]

local ArenaKits = require(script.Parent.ArenaKits)

export type Sign = {
	centre: Vector3,
	size: Vector2,
	normal: Vector3?,
	up: Vector3?,
	text: string,
	colour: Color3,
}

export type Placed = { piece: string, at: Vector2, yaw: number?, lift: number? }

export type Portal = {
	--[[ The area's name on its sign, and its levels: the `Balance.Stages`
	     index each plays, in order, offered on the portal's screen
	     (`UI/PortalScreen`); nil for a locked arch (an area not built yet). ]]
	name: string?,
	levels: { number }?,
	--[[ The swirl's colour, and the sign piece above the arch. ]]
	tint: Color3?,
	sign: string?,
	--[[ Its own arch, built in its area's look with its name on it (owner,
	     2026-10-25: "the portals also should look like their areas not all
	     look the same"); the plain `PortalArch` and `sign` until imported. ]]
	arch: string?,
}

local GREEN = Color3.fromRGB(80, 230, 70)
local PURPLE = Color3.fromRGB(140, 60, 235)

local Lobby = {
	--[[ Where the lobby's centre stands in the world: well away from the
	     arena at the origin. ]]
	origin = Vector3.new(0, 0, 1000),
	--[[ The walkable clearing, studs across (X) and deep (Z). ]]
	size = Vector2.new(220, 192),
	--[[ Studs per kit unit, as the arena kits are drawn. ]]
	scale = 6,
	--[[ Where a player appears: beside the campfire. ]]
	spawn = Vector2.new(-8, 50),

	--[[ The portal terraces across the north edge: two rows of arches
	     (owner, 2026-10-25: "make sure there are 2 rows of portals with them
	     being locked, there should be at least 10 portals for now"). `terrace`
	     is the front row's centre; the back row stands `rowDepth` studs
	     behind it and `rowRise` up, reached by steps. ]]
	terrace = Vector2.new(0, -60),
	rowDepth = 19.2,
	rowRise = 2,
	perRow = 5,
	archSpacing = 18,
	--[[ The arches, front row west to east, then the back row: the two
	     areas built so far, then eight locked. ]]
	portals = {
		{
			name = "Mossy Glade",
			levels = { 5 },
			tint = GREEN,
			sign = "PortalSignMossy",
			arch = "PortalArch_MossyGlade",
		},
		{
			name = "Thornwood",
			levels = { 4 },
			tint = PURPLE,
			sign = "PortalSignThornwood",
			arch = "PortalArch_Thornwood",
		},
		{ name = "Drowned Village", arch = "PortalArch_DrownedVillage" },
		{ name = "Bogheart Caverns", arch = "PortalArch_BogheartCaverns" },
		{ name = "Windswept Cliffs", arch = "PortalArch_WindsweptCliffs" },
		{ name = "Frostpeak Pass", arch = "PortalArch_FrostpeakPass" },
		{ name = "Ember Mines", arch = "PortalArch_EmberMines" },
		{ name = "Obsidian Forge", arch = "PortalArch_ObsidianForge" },
		{ name = "Shattered Kingdom", arch = "PortalArch_ShatteredKingdom" },
		{ name = "Void Rift", arch = "PortalArch_VoidRift" },
	} :: { Portal },
	--[[ Studs from an active arch's mouth a player must come within for its
	     screen to open (`UI/PortalScreen`), and how much further the server
	     still grants START from, for the time the press takes to arrive. ]]
	portalReach = 7,
	startSlack = 4,
	--[[ The level selector's slots per area: its levels, then locked ones
	     (COMING SOON) up to this many. ]]
	levelSlots = 3,

	--[[ Moving round the lobby (owner, 2026-10-26: "let players sprint and
	     jump in the lobby instead of dash"): Shift, a gamepad's X or the
	     phone's SPRINT button runs this many times walking speed; Space, A or
	     JUMP jumps this high (studs, Roblox's own jump). Runs keep the dash
	     and never jump. ]]
	sprint = 1.7,
	jumpHeight = 7.2,
	--[[ Studs in front of an arch where its mouth is. ]]
	mouthAhead = 4,
	--[[ How the portal pieces sit, in kit units, as the kit was drawn: the
	     arches on the terrace's 0.3-high platform, the terrace reaching
	     further forward than back; the swirl's foot 0.2 above the arch's,
	     the lock a little forward in the opening; the sign above the arch's
	     crown, in front of it. ]]
	archLift = 0.3,
	terraceAhead = 0.3,
	swirlLift = 0.2,
	lockAhead = 0.1,
	signLift = 2.75,
	signAhead = 0.55,

	--[[ The stations, as the sheet lays them out: the pet grove (the
	     hatchery) west, the gear grove (blacksmith, gear station, dex hall)
	     east, the campfire spawn in the middle. The gear station stands out
	     east of the blacksmith and below it, the dex hall further south
	     (owner, 2026-10-26: the gear area "almost overlaps with the
	     blacksmith area"); `Lobby.spec` keeps every footprint apart. ]]
	stations = {
		{ piece = "EggHatchery", at = Vector2.new(-68, -12) },
		{ piece = "Blacksmith", at = Vector2.new(60, -28) },
		{ piece = "GearStation", at = Vector2.new(86, 6) },
		{ piece = "DexHall", at = Vector2.new(54, 44) },
		{ piece = "SpawnCampfire", at = Vector2.new(-8, 28) },
	} :: { Placed },

	--[[ The lobby's characters and smaller set pieces (owner, 2026-10-25):
	     the blacksmith at his anvil before the forge ("modeled after the
	     blacksmith from elden ring"), the fairy who keeps the hatchery
	     ("modeled after the great fairy from breath of the wild"), our own
	     blocky takes (`assets/concepts/blocky/lobby/npcs/`); and the three
	     codex books on lecterns before the Dex Hall ("the books that will be
	     the enemy codex, weapon codex, and pet codex"). `lift` in studs. ]]
	props = {
		-- in the seat the forge leaves him before its anvils (0.3, 1.4 units
		-- from the Blacksmith's centre, its tiles 0.12 up)
		{ piece = "SmithNPC", at = Vector2.new(61.8, -19.6), lift = 0.72 },
		{ piece = "FairyNPC", at = Vector2.new(-70, -42) },
		{ piece = "Lectern", at = Vector2.new(40, 66) },
		{ piece = "Lectern", at = Vector2.new(54, 66) },
		{ piece = "Lectern", at = Vector2.new(68, 66) },
		{ piece = "BookEnemies", at = Vector2.new(40, 66), lift = 6.6 },
		{ piece = "BookWeapons", at = Vector2.new(54, 66), lift = 6.6 },
		{ piece = "BookPets", at = Vector2.new(68, 66), lift = 6.6 },
	} :: { Placed },

	--[[ The FARTHEST ADVENTURERS board (`Run/StoryLeaderboard`) beside the
	     path north of the campfire, as on `lobby_v3.png`. `face` is its
	     board's front, in kit units from the piece's base centre, where the
	     names are written; until the piece is imported the face alone
	     stands there on two posts' height. ]]
	leaderboard = {
		at = Vector2.new(-36, -4),
		face = { centre = Vector3.new(0, 1.65, 0.15), size = Vector2.new(2.8, 1.9) },
	},

	--[[ The dirt paths, as runs of points: the spawn up to the portals, and
	     out to each grove. ]]
	paths = {
		{
			Vector2.new(-8, 92),
			Vector2.new(-8, 48),
			Vector2.new(-4, 0),
			Vector2.new(0, -36),
			Vector2.new(0, -52),
		},
		{ Vector2.new(-16, 16), Vector2.new(-40, 0), Vector2.new(-60, -4) },
		{ Vector2.new(0, 8), Vector2.new(24, -12), Vector2.new(40, -24) },
		{ Vector2.new(4, 20), Vector2.new(40, 20), Vector2.new(72, 22) },
		{ Vector2.new(4, 28), Vector2.new(32, 44), Vector2.new(44, 44) },
	} :: { { Vector2 } },

	lawn = {
		Color3.fromRGB(141, 183, 47),
		Color3.fromRGB(117, 161, 38),
		Color3.fromRGB(152, 183, 57),
	},
	dirt = {
		Color3.fromRGB(199, 147, 71),
		Color3.fromRGB(190, 150, 71),
		Color3.fromRGB(184, 138, 64),
	},
	tile = 8,

	--[[ The forest round the clearing: a ring of trees and cliffs this many
	     studs apart, with waterfalls at the four corners as on the sheet,
	     and a scatter of bushes, rocks and glowing mushrooms on the lawn. ]]
	ringSpacing = 18,
	waterfalls = {
		Vector2.new(-96, -76),
		Vector2.new(96, -76),
		Vector2.new(-100, 72),
		Vector2.new(100, 72),
	},
	--[[ The words on the lobby's signs, written by the game in its one font
	     (owner, 2026-10-26: "make every piece of text in the lobby the same
	     font"): each piece's sign board is blank (`lobby_kit_v4`), and here is
	     where it is on the piece, in kit units from its base centre, front
	     +Z (`normal` and `up` for a tilted board), the words, and the colour
	     the carved letters had. ]]
	signs = {
		EggHatchery = {
			centre = Vector3.new(0, 2.96875, -0.3125),
			size = Vector2.new(2.375, 0.4375),
			text = "EGG HATCHERY",
			colour = Color3.fromRGB(242, 230, 196),
		},
		Blacksmith = {
			centre = Vector3.new(1.35, 3.63, 1.07),
			size = Vector2.new(2.46, 0.46),
			text = "BLACKSMITH",
			colour = Color3.fromRGB(244, 234, 208),
		},
		GearStation = {
			centre = Vector3.new(0, 2.7976, 0.9332),
			size = Vector2.new(2.459, 0.42),
			normal = Vector3.new(0, 0.343, 0.939),
			up = Vector3.new(0, 0.9394, -0.3429),
			text = "GEAR STATION",
			colour = Color3.fromRGB(244, 234, 208),
		},
		DexHall = {
			centre = Vector3.new(-0.0325, 3.1, 1.275),
			size = Vector2.new(2.18, 0.4),
			text = "DEX HALL",
			colour = Color3.fromRGB(243, 233, 203),
		},
		Leaderboard = {
			centre = Vector3.new(0, 2.885, 0.28),
			size = Vector2.new(3, 0.43),
			text = "FARTHEST ADVENTURERS",
			colour = Color3.fromRGB(244, 226, 173),
		},
		PortalArch_MossyGlade = {
			centre = Vector3.new(0, 3.2, 0.15),
			size = Vector2.new(1.6, 0.5),
			text = "MOSSY GLADE",
			colour = Color3.fromRGB(242, 234, 211),
		},
		PortalArch_Thornwood = {
			centre = Vector3.new(0, 3.2, 0.25),
			size = Vector2.new(1.6, 0.5),
			text = "THORNWOOD",
			colour = Color3.fromRGB(242, 234, 211),
		},
		PortalArch_DrownedVillage = {
			centre = Vector3.new(0, 3.16, 0.44),
			size = Vector2.new(2.12, 0.64),
			text = "DROWNED VILLAGE",
			colour = Color3.fromRGB(255, 255, 255),
		},
		PortalArch_BogheartCaverns = {
			centre = Vector3.new(0, 3.22, 0.44),
			size = Vector2.new(1.96, 0.52),
			text = "BOGHEART CAVERNS",
			colour = Color3.fromRGB(255, 255, 255),
		},
		PortalArch_WindsweptCliffs = {
			centre = Vector3.new(0, 3.1875, 0.45),
			size = Vector2.new(1.85, 0.675),
			text = "WINDSWEPT CLIFFS",
			colour = Color3.fromRGB(255, 255, 255),
		},
		PortalArch_FrostpeakPass = {
			centre = Vector3.new(0, 3.15, 0.45),
			size = Vector2.new(1.85, 0.55),
			text = "FROSTPEAK PASS",
			colour = Color3.fromRGB(255, 255, 255),
		},
		PortalArch_EmberMines = {
			centre = Vector3.new(0, 3.175, 0.075),
			size = Vector2.new(2.5, 0.65),
			text = "EMBER MINES",
			colour = Color3.fromRGB(246, 244, 238),
		},
		PortalArch_ObsidianForge = {
			centre = Vector3.new(0, 3.2, 0.075),
			size = Vector2.new(2.45, 0.55),
			text = "OBSIDIAN FORGE",
			colour = Color3.fromRGB(246, 244, 238),
		},
		PortalArch_ShatteredKingdom = {
			centre = Vector3.new(0, 3, 0.45),
			size = Vector2.new(2.2, 0.5),
			text = "SHATTERED KINGDOM",
			colour = Color3.fromRGB(255, 255, 255),
		},
		PortalArch_VoidRift = {
			centre = Vector3.new(0.0017, 3.043, 0.33),
			size = Vector2.new(1.8, 0.4),
			normal = Vector3.new(0.035, 0.0599, 0.9976),
			up = Vector3.new(0.0499, 0.9968, -0.0616),
			text = "VOID RIFT",
			colour = Color3.fromRGB(255, 255, 255),
		},
	} :: { [string]: Sign },

	--[[ The lawn's scatter: how likely each kind is, one piece per
	     `scatterCell` studs square (`scatterFill` of the cells filled). ]]
	scatter = {
		FlowerPink = 14,
		FlowerWhite = 12,
		FlowerYellow = 12,
		FlowerBlue = 10,
		Bush = 24,
		GlowMushroom = 12,
		Rock = 8,
	},
	scatterCell = 11,
	scatterFill = 0.8,

	--[[ The kit's pieces, from the owner's import (2026-10-25,
	     `kit_bundle.py --srgb` on `assets/models/lobby/lobby_kit`), in kit
	     units. The portal swirl is all glow: drawn Neon in its portal's
	     colour. ]]
	pieces = {
		BannerPole = {
			meshId = "rbxassetid://91941746392065",
			size = Vector3.new(0.6, 3, 0.3),
			centre = Vector3.new(0, 1.5, 0),
		},
		Blacksmith = {
			meshId = "rbxassetid://105766496891501",
			size = Vector3.new(6, 5, 4),
			centre = Vector3.new(0, 2.5, 0),
			glow = {
				meshId = "rbxassetid://125860799363874",
				size = Vector3.new(4.98, 1.66, 2.4584),
				centre = Vector3.new(0.11, 1.29, 0.6908),
			},
		},
		Bush = {
			meshId = "rbxassetid://103682199905716",
			size = Vector3.new(1.19, 0.9, 1.04),
			centre = Vector3.new(0, 0.45, 0),
		},
		CliffBlock = {
			meshId = "rbxassetid://137299341124009",
			size = Vector3.new(2.965, 3.16, 2.97),
			centre = Vector3.new(0, 1.58, 0),
		},
		DexHall = {
			meshId = "rbxassetid://137580120868267",
			size = Vector3.new(8.835, 3.44, 4.25),
			centre = Vector3.new(0, 1.72, 0),
			glow = {
				meshId = "rbxassetid://121084239876446",
				size = Vector3.new(6.473, 1.189, 0.798),
				centre = Vector3.new(-0.964, 1.1455, 1.044),
			},
		},
		EggHatchery = {
			meshId = "rbxassetid://140557897813184",
			size = Vector3.new(5.5, 3.25, 5.375),
			centre = Vector3.new(0, 1.625, 0),
			glow = {
				meshId = "rbxassetid://118994057166286",
				size = Vector3.new(4.4375, 1.6875, 3.25),
				centre = Vector3.new(-0.4688, 1.2187, 0.8125),
			},
		},
		GearStation = {
			meshId = "rbxassetid://121677949555244",
			size = Vector3.new(5.96, 3.38, 4.04),
			centre = Vector3.new(0, 1.69, 0),
			--[[ Its cream canvas burned white in the lobby's light; toned
			     down to the sheet's. ]]
			tint = Color3.fromRGB(222, 214, 196),
			glow = {
				meshId = "rbxassetid://79963552970577",
				size = Vector3.new(5.54, 0.2, 0.14),
				centre = Vector3.new(-0, 0.73, 0.87),
			},
		},
		GlowMushroom = {
			meshId = "rbxassetid://125768539937484",
			size = Vector3.new(0.35, 0.4, 0.4),
			centre = Vector3.new(0, 0.2, 0),
			glow = {
				meshId = "rbxassetid://112421782720303",
				size = Vector3.new(0.5, 0.5, 0.5),
				centre = Vector3.new(-0, 0.3, -0),
			},
		},
		Lantern = {
			meshId = "rbxassetid://103950658684021",
			size = Vector3.new(0.5, 1.6, 0.3),
			centre = Vector3.new(0, 0.8, 0),
			glow = {
				meshId = "rbxassetid://99627711504135",
				size = Vector3.new(0.3, 0.3, 0.3),
				centre = Vector3.new(0.1, 0.85, -0),
			},
		},
		LobbyTree = {
			meshId = "rbxassetid://101663752531516",
			size = Vector3.new(3.6085, 3.983, 3.0025),
			centre = Vector3.new(0, 1.9915, 0),
		},
		PortalArch = {
			meshId = "rbxassetid://91267461567820",
			size = Vector3.new(2.64, 3.13, 1.0182),
			centre = Vector3.new(0, 1.565, 0),
		},
		PortalLock = {
			meshId = "rbxassetid://103909347085104",
			size = Vector3.new(1.5, 2.35, 0.5),
			centre = Vector3.new(0, 1.175, 0),
		},
		PortalSignMossy = {
			meshId = "rbxassetid://118461464441348",
			size = Vector3.new(1.4, 0.4, 0.14),
			centre = Vector3.new(0, 0.2, 0),
		},
		PortalSignThornwood = {
			meshId = "rbxassetid://92864032727588",
			size = Vector3.new(1.4, 0.4, 0.14),
			centre = Vector3.new(0, 0.2, 0),
		},
		PortalSteps = {
			meshId = "rbxassetid://118112486165898",
			size = Vector3.new(3.06, 0.34, 2.0162),
			centre = Vector3.new(0, 0.17, 0),
		},
		PortalTerrace = {
			meshId = "rbxassetid://126789576323782",
			size = Vector3.new(15.16, 1.4, 3.2),
			centre = Vector3.new(0, 0.7, 0),
			glow = {
				meshId = "rbxassetid://107391526955138",
				size = Vector3.new(14.76, 0.955, 0.5),
				centre = Vector3.new(-0, 1.8575, 1),
			},
		},
		Rock = {
			meshId = "rbxassetid://95087407832478",
			size = Vector3.new(0.95, 0.75, 0.8),
			centre = Vector3.new(0, 0.375, 0),
		},
		SpawnCampfire = {
			meshId = "rbxassetid://83288016204173",
			size = Vector3.new(5.25, 2.75, 5.125),
			centre = Vector3.new(0, 1.375, 0),
			glow = {
				meshId = "rbxassetid://115260068877546",
				size = Vector3.new(4.375, 1.8125, 4.3125),
				centre = Vector3.new(-0.0625, 1.4062, -0.4063),
			},
		},
		Waterfall = {
			meshId = "rbxassetid://136320038024784",
			size = Vector3.new(2.965, 3.91, 1.98),
			centre = Vector3.new(0, 1.955, 0),
			glow = {
				meshId = "rbxassetid://86217006291524",
				size = Vector3.new(1.9, 3.37, 1.76),
				centre = Vector3.new(-0.0225, 1.685, -0.11),
			},
		},
		PortalSwirl = {
			meshId = "rbxassetid://80888581914858",
			size = Vector3.new(1.4, 2, 0.1),
			centre = Vector3.new(0, 1, 0),
		},
		-- the second import (2026-10-25: area arches, the leaderboard, flowers,
		-- the codex books, the smith and the hatchery fairy)
		BookEnemies = {
			meshId = "rbxassetid://76847797460015",
			size = Vector3.new(0.86, 1.04, 0.38),
			centre = Vector3.new(0, 0.52, 0),
			glow = {
				meshId = "rbxassetid://86536383867082",
				size = Vector3.new(0.58, 0.26, 0.28),
				centre = Vector3.new(0.15, 0.43, 0.06),
			},
		},
		BookPets = {
			meshId = "rbxassetid://79698627668218",
			size = Vector3.new(0.86, 1.04, 0.38),
			centre = Vector3.new(0, 0.52, 0),
			glow = {
				meshId = "rbxassetid://101832364438907",
				size = Vector3.new(0.16, 0.18, 0.28),
				centre = Vector3.new(0.36, 0.5501, 0.06),
			},
		},
		BookWeapons = {
			meshId = "rbxassetid://140426894819576",
			size = Vector3.new(0.86, 1.04, 0.38),
			centre = Vector3.new(0, 0.52, 0),
			glow = {
				meshId = "rbxassetid://82135615613010",
				size = Vector3.new(0.36, 0.2, 0.28),
				centre = Vector3.new(0.26, 0.56, 0.06),
			},
		},
		FairyNPC = {
			meshId = "rbxassetid://76377756194331",
			size = Vector3.new(3.5619, 4.5045, 3.3027),
			centre = Vector3.new(0, 2.2523, 0),
			glow = {
				meshId = "rbxassetid://129780618379889",
				size = Vector3.new(2.7858, 2.4507, 0.8148),
				centre = Vector3.new(0.025, 3.2347, 0.4459),
			},
		},
		FlowerBlue = {
			meshId = "rbxassetid://132057953083307",
			size = Vector3.new(0.5007, 0.3009, 0.4119),
			centre = Vector3.new(0, 0.1505, 0),
		},
		FlowerPink = {
			meshId = "rbxassetid://89286604004504",
			size = Vector3.new(0.5025, 0.2988, 0.4088),
			centre = Vector3.new(0, 0.1494, 0),
		},
		FlowerWhite = {
			meshId = "rbxassetid://140693954381199",
			size = Vector3.new(0.5143, 0.2873, 0.3554),
			centre = Vector3.new(0, 0.1436, 0),
		},
		FlowerYellow = {
			meshId = "rbxassetid://131000894240730",
			size = Vector3.new(0.5035, 0.2981, 0.4073),
			centre = Vector3.new(0, 0.149, 0),
		},
		Leaderboard = {
			meshId = "rbxassetid://76711186785426",
			size = Vector3.new(4.72, 4, 0.875),
			centre = Vector3.new(0, 2, 0),
			glow = {
				meshId = "rbxassetid://122935039138399",
				size = Vector3.new(4.63, 0.35, 0.23),
				centre = Vector3.new(-0, 2.1751, -0.0125),
			},
		},
		Lectern = {
			meshId = "rbxassetid://129185599203372",
			size = Vector3.new(0.8, 1.0984, 0.6673),
			centre = Vector3.new(0, 0.5492, 0),
		},
		PortalArch_BogheartCaverns = {
			meshId = "rbxassetid://132390011721511",
			size = Vector3.new(2.86, 3.6, 1),
			centre = Vector3.new(0, 1.8, 0),
			glow = {
				meshId = "rbxassetid://113209528822230",
				size = Vector3.new(2.7705, 3.015, 0.816),
				centre = Vector3.new(0.0113, 1.7075, 0.083),
			},
		},
		PortalArch_DrownedVillage = {
			meshId = "rbxassetid://98350397516434",
			size = Vector3.new(2.8575, 3.6, 1),
			centre = Vector3.new(0, 1.8, 0),
			glow = {
				meshId = "rbxassetid://84609529873884",
				size = Vector3.new(2.73, 2.94, 0.5),
				centre = Vector3.new(0.0013, 1.47, 0.23),
			},
		},
		PortalArch_EmberMines = {
			meshId = "rbxassetid://105349407667732",
			size = Vector3.new(2.8, 3.6, 1),
			centre = Vector3.new(0, 1.8, 0),
			glow = {
				meshId = "rbxassetid://106082737634129",
				size = Vector3.new(2.75, 2.225, 0.55),
				centre = Vector3.new(0.025, 1.2875, 0.175),
			},
		},
		PortalArch_FrostpeakPass = {
			meshId = "rbxassetid://128583531229486",
			size = Vector3.new(2.8, 3.6, 1),
			centre = Vector3.new(0, 1.8, 0),
			glow = {
				meshId = "rbxassetid://123077415228167",
				size = Vector3.new(2.8, 2.775, 1),
				centre = Vector3.new(-0, 1.6625, 0),
			},
		},
		PortalArch_MossyGlade = {
			meshId = "rbxassetid://94159909097508",
			size = Vector3.new(2.8, 3.6, 1),
			centre = Vector3.new(0, 1.8, 0),
			glow = {
				meshId = "rbxassetid://86635203505894",
				size = Vector3.new(2.35, 0.3, 0.25),
				centre = Vector3.new(0.225, 0.35, 0.375),
			},
		},
		PortalArch_ObsidianForge = {
			meshId = "rbxassetid://89838869815161",
			size = Vector3.new(2.8, 3.6, 1),
			centre = Vector3.new(0, 1.8, 0),
			glow = {
				meshId = "rbxassetid://121871008552458",
				size = Vector3.new(2.75, 2.375, 0.775),
				centre = Vector3.new(-0, 1.6126, 0.0875),
			},
		},
		PortalArch_ShatteredKingdom = {
			meshId = "rbxassetid://100410545343091",
			size = Vector3.new(2.8, 3.6, 1.0004),
			centre = Vector3.new(0, 1.8, 0),
		},
		PortalArch_Thornwood = {
			meshId = "rbxassetid://112149866406437",
			size = Vector3.new(2.8, 3.6, 1),
			centre = Vector3.new(0, 1.8, 0),
		},
		PortalArch_VoidRift = {
			meshId = "rbxassetid://108007579219396",
			size = Vector3.new(2.7902, 3.5976, 1),
			centre = Vector3.new(0, 1.7988, 0),
			glow = {
				meshId = "rbxassetid://138317700893740",
				size = Vector3.new(2.7714, 3.3953, 0.7914),
				centre = Vector3.new(0.0071, 1.8477, 0.0962),
			},
		},
		PortalArch_WindsweptCliffs = {
			meshId = "rbxassetid://124463565707165",
			size = Vector3.new(2.8, 3.6, 1),
			centre = Vector3.new(0, 1.8, 0),
		},
		SmithNPC = {
			meshId = "rbxassetid://100628589388853",
			size = Vector3.new(1.8031, 1.7278, 1.3711),
			centre = Vector3.new(0, 0.8639, 0),
			glow = {
				meshId = "rbxassetid://111148419591185",
				size = Vector3.new(0.36, 0.2533, 0.1265),
				centre = Vector3.new(-0.4515, 0.9485, 0.0934),
			},
		},
	} :: { [string]: ArenaKits.Piece },
}

return table.freeze(Lobby)
