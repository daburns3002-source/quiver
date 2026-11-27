--!strict
--[[
	Arena kits: a room built from a few pieces instead of one model (the
	owner's blocky Mossy Glade kit, Claude Design, 2026-10-24; bundled for
	one import by `assets/models/arenas/kit_bundle.py`). `Shared/Util/
	KitLayout` lays the pieces out to each room's own size and cover, and
	`Arena.build` draws them; an `ArenaModels` entry asks for a kit with
	`kit`.

	Each piece is its imported mesh: `size` is the mesh's own size, its base
	on the floor at its centre (`centre` is its middle above that base, so
	`centre.Y` is half its height), all in the kit's units; every piece is
	drawn `scale` times that. A piece with `glow` has a second mesh drawn
	Neon at `glow.centre`. Like every arena mesh, each is turned back 180°
	about Y (the importer turns it); offsets keep their own signs.
]]

export type Piece = {
	meshId: string,
	size: Vector3,
	centre: Vector3,
	glow: {
		meshId: string,
		size: Vector3,
		centre: Vector3,
		--[[ A light in the glow, this colour, this many studs across: a
		     lantern's pool on the water. ]]
		light: Color3?,
		lightRange: number?,
		--[[ The glow's colour in place of white, which dims Neon: the
		     caverns' glow is most of each mushroom, and at full white it
		     bloomed into white blobs where the sheet's caps read cyan. ]]
		tint: Color3?,
	}?,
	--[[ The whole piece drawn Neon: a mesh that is all glow, as the
	     cavern's stream. ]]
	neon: boolean?,
	--[[ The piece's colour in place of white, which multiplies its vertex
	     colours: a deeper, cooler green on the mossy and grassy pieces, so
	     they part from the lawn (owner, 2026-10-24: "make the objects that
	     have grass or moss a different color than the floor"). ]]
	tint: Color3?,
}

export type Kit = {
	pieces: { [string]: Piece },
	--[[ Studs per kit unit. ]]
	scale: number,
	--[[ The lawn inside the walls: square tiles this many studs across in
	     a few shades, and the forest floor outside. ]]
	tile: number,
	lawn: { Color3 },
	water: Color3,
	bank: Color3,
	--[[ Stepping stones up the middle from the start to the gate, this far
	     apart, swaying this far either side. ]]
	pathSpacing: number,
	pathSway: number,
	--[[ Plants along the inside of the walls, this far in at most, and
	     how many of each per side of the room. ]]
	edgeDepth: number,
	plants: { [string]: number },
	--[[ Studs of a flat low cover box per fern bush when it is a thicket. ]]
	thicketSpacing: number,
	--[[ Which piece draws each of `Shared/Util/KitLayout`'s roles, where
	     it is not the piece of that name: WallBlock, FallenLog,
	     CornerPillar, TreeStump, TallCover (a tall box; the corner pillar
	     where the kit has none), FernBush (a thicket), SteppingStone. ]]
	roles: { [string]: string }?,
	--[[ A kit with no stepping stones paths the room in dirt, in these
	     shades. ]]
	dirt: { Color3 }?,
	--[[ A gap in the south wall too, for the door the player comes in by
	     (owner, 2026-10-24: Thornwood). ]]
	southGate: boolean?,
	--[[ A corner pillar halfway along the west and east walls as well. ]]
	midPillars: boolean?,
	--[[ Every wall piece and corner pillar turned to face into the room
	     (the front the kit draws is its +Z): the cavern's walls have their
	     glowing mushrooms at their feet on that side. ]]
	wallsFaceIn: boolean?,
	--[[ Houses set into each side wall, this many, evenly spaced, with a
	     lantern by each (roles SideHouse, Lantern; the Drowned Village). ]]
	sideHouses: number?,
	--[[ A causeway of PathTile pieces up the middle, flattened to this
	     share of their height. ]]
	causeway: number?,
	--[[ The roles drawn evenly scaled to their box rather than stretched
	     to it (a giant mushroom keeps its shape). ]]
	keepShape: { [string]: boolean }?,
	--[[ The stream's water (role StreamTile) and its bridge flattened to
	     these shares of their height, as they are walked over. ]]
	streamFlatten: number?,
	bridgeFlatten: number?,
	--[[ The floor shines a little, as water does. ]]
	wetFloor: boolean?,
	--[[ Moss in staircase runs of squares this many studs across. ]]
	moss: { colours: { Color3 }, count: number, size: number }?,
	--[[ Reed clumps at the corners, and this many more along the side
	     walls, blades up to `height` studs. ]]
	reeds: { colours: { Color3 }, clumps: number, height: number }?,
}

--[[ Mossy Glade tints (see `Piece.tint`): stone and wood keep most of their
     own colour; ferns and tufts, all green, go deepest. ]]
local MOSS_STONE = Color3.fromRGB(150, 185, 150)
local MOSS_WOOD = Color3.fromRGB(170, 195, 165)
local FERN = Color3.fromRGB(110, 160, 120)
local TUFT = Color3.fromRGB(130, 175, 135)

local ArenaKits: { [string]: Kit } = {
	Mossy = {
		scale = 3.2,
		pieces = {
			WallBlock = {
				meshId = "rbxassetid://133735089173602",
				size = Vector3.new(1.104, 0.722, 0.492),
				centre = Vector3.new(0, 0.361, 0),
				tint = MOSS_STONE,
			},
			CornerPillar = {
				meshId = "rbxassetid://95109128405834",
				size = Vector3.new(0.86, 1.02, 0.77),
				centre = Vector3.new(0, 0.51, 0),
				tint = MOSS_STONE,
			},
			FallenLog = {
				meshId = "rbxassetid://83798974084855",
				size = Vector3.new(2.48, 0.8165, 1),
				centre = Vector3.new(0, 0.4083, 0),
				tint = MOSS_WOOD,
			},
			TreeStump = {
				meshId = "rbxassetid://118180618895571",
				size = Vector3.new(1.18, 0.75, 1.115),
				centre = Vector3.new(0, 0.375, 0),
				tint = MOSS_WOOD,
			},
			SteppingStone = {
				meshId = "rbxassetid://109662616490392",
				size = Vector3.new(0.901, 0.265, 0.9),
				centre = Vector3.new(0, 0.1325, 0),
			},
			FernBush = {
				meshId = "rbxassetid://124658136550762",
				size = Vector3.new(0.82, 0.75, 0.7754),
				centre = Vector3.new(0, 0.375, 0),
				tint = FERN,
			},
			FlowerTuft = {
				meshId = "rbxassetid://77682975928453",
				size = Vector3.new(0.5506, 0.48, 0.4644),
				centre = Vector3.new(0, 0.24, 0),
				tint = TUFT,
			},
			GlowMushroom = {
				meshId = "rbxassetid://134249505947377",
				size = Vector3.new(0.89, 0.21, 0.7),
				centre = Vector3.new(0, 0.105, 0),
				glow = {
					meshId = "rbxassetid://135449130063569",
					size = Vector3.new(0.643, 0.704, 0.483),
					centre = Vector3.new(0.0525, 0.352, 0.0675),
				},
			},
		},
		tile = 3.5,
		--[[ A warm yellow-green, after the reference sheet, apart from the
		     cooler, deeper moss on the pieces standing on it; darkened two
		     steps (owner, 2026-10-24: "a little darker but still not as dark
		     as the forest floor outside", which is (63, 107, 42); then "a
		     bit darker still"). Was
		     (106, 176, 64) and its neighbours, the same green as the moss. ]]
		lawn = {
			Color3.fromRGB(106, 146, 56),
			Color3.fromRGB(99, 139, 52),
			Color3.fromRGB(113, 153, 60),
		},
		water = Color3.fromRGB(70, 150, 190),
		bank = Color3.fromRGB(70, 120, 48),
		pathSpacing = 3.6,
		pathSway = 2.2,
		edgeDepth = 2.6,
		plants = { FernBush = 5, FlowerTuft = 5, GlowMushroom = 2 },
		thicketSpacing = 2.4,
	},
	--[[ Act 1, area 2: the owner's blocky Thornwood (Claude Design,
	     2026-10-24), five pieces drawn with their own vertex colours. The
	     bramble hedge is both the wall and long cover, thorn trees stand at
	     the corners, mossy boulders are the squat and tall cover, thorn
	     bushes the thickets (which block walking, not arrows); a dirt trail
	     runs to the gate, and both the north and south walls are open for
	     their doors. ]]
	Thornwood = {
		scale = 2.6,
		pieces = {
			--[[ Redrawn with looping thorny vines in place of the X (owner,
			     2026-10-25: "the new bramble hedge with looping thorn vines
			     should replace the previous hedges";
			     assets/concepts/blocky/arenas/kit/thornwood_bramble_hedge_v2_views.png).
			     Its end loops rise above the leaf top, so `size.Y` is the
			     loops' height; the leaves stop at 0.78. ]]
			BrambleHedge = {
				meshId = "rbxassetid://124031014884732",
				size = Vector3.new(3.1237, 1.1661, 0.754),
				centre = Vector3.new(0, 0.58305, 0),
			},
			ThornTree = {
				meshId = "rbxassetid://114102878041804",
				size = Vector3.new(1.6628, 2, 1.4856),
				centre = Vector3.new(0, 1, 0),
			},
			MossyBoulder = {
				meshId = "rbxassetid://78499581487276",
				size = Vector3.new(1.225, 1.07, 1.08),
				centre = Vector3.new(0, 0.535, 0),
			},
			ThornBush = {
				meshId = "rbxassetid://137379320911418",
				size = Vector3.new(1.04, 0.98, 1.04),
				centre = Vector3.new(0, 0.49, 0),
			},
			RootSprout = {
				meshId = "rbxassetid://82229134586267",
				size = Vector3.new(0.9089, 1.05, 0.784),
				centre = Vector3.new(0, 0.525, 0),
			},
		},
		roles = {
			WallBlock = "BrambleHedge",
			FallenLog = "BrambleHedge",
			CornerPillar = "ThornTree",
			TreeStump = "MossyBoulder",
			TallCover = "MossyBoulder",
			FernBush = "ThornBush",
		},
		tile = 3.5,
		--[[ Sampled from the reference sheet's lawn and ground tile
		     (`assets/concepts/blocky/arenas/area02_thornwood_views.png`),
		     to match it 1:1 (owner, 2026-10-25: "if the arena does not
		     match 1 to 1 then redo it"); the first pass was two steps
		     darker. ]]
		lawn = {
			Color3.fromRGB(141, 183, 47),
			Color3.fromRGB(117, 161, 38),
			Color3.fromRGB(152, 183, 57),
			Color3.fromRGB(156, 195, 59),
		},
		--[[ The sheet's dirt, in blocks like its pixels. ]]
		dirt = {
			Color3.fromRGB(199, 147, 71),
			Color3.fromRGB(190, 150, 71),
			Color3.fromRGB(184, 138, 64),
		},
		water = Color3.fromRGB(70, 130, 150),
		bank = Color3.fromRGB(96, 80, 46),
		pathSpacing = 3.2,
		pathSway = 2.6,
		edgeDepth = 2.8,
		--[[ Only a few sprouts along the walls: the sheet's thorn bushes are
		     cover, never decoration. ]]
		plants = { RootSprout = 2 },
		thicketSpacing = 2.6,
		southGate = true,
		midPillars = true,
	},
	--[[ Act 1, area 3: the Drowned Village (the owner's kit, Claude Design,
	     2026-11-05; `assets/concepts/blocky/arenas/area03_drowned_village_v2.png`,
	     approved). Open turquoise flood water, a cobble causeway up the
	     middle, the stone well at the centre, broken stone walls and
	     crate-and-barrel stacks as the only other cover, three sunken houses
	     set into each side wall with a lit lantern by each, reeds at the
	     edges and a wooden dock gate top and bottom. Bundled `--srgb`. ]]
	Drowned = {
		scale = 3.2,
		pieces = {
			Stone_Wall = {
				meshId = "rbxassetid://78590167217162",
				size = Vector3.new(3.95, 0.9455, 0.896),
				centre = Vector3.new(0, 0.473, 0),
			},
			Corner_Pillar = {
				meshId = "rbxassetid://117895656820805",
				size = Vector3.new(1.875, 1.6, 1.725),
				centre = Vector3.new(0, 0.8, 0),
			},
			Crate_Barrel = {
				meshId = "rbxassetid://96597292420512",
				size = Vector3.new(1.926, 0.95, 0.9715),
				centre = Vector3.new(0, 0.475, 0),
			},
			--[[ The sunken houses set into the side walls: the whole house,
			     whose roof with its dark dormer is what the sheet shows from
			     above (the facade alone reads as a bare slope). ]]
			House_Corner = {
				meshId = "rbxassetid://75935102435337",
				size = Vector3.new(2.82, 3.28, 3.234),
				centre = Vector3.new(0, 1.64, 0),
			},
			Lantern_Post = {
				meshId = "rbxassetid://120651899990838",
				size = Vector3.new(1.6365, 2.87, 1.2171),
				centre = Vector3.new(0, 1.435, 0),
				glow = {
					meshId = "rbxassetid://94776385033367",
					size = Vector3.new(0.28, 0.4, 0.28),
					centre = Vector3.new(0.608, 1.92, 0.009),
					light = Color3.fromRGB(255, 196, 110),
					lightRange = 18,
				},
			},
			Stone_Ruins = {
				meshId = "rbxassetid://119895228839446",
				size = Vector3.new(2.1427, 1.15, 1.4947),
				centre = Vector3.new(0, 0.575, 0),
			},
			Stone_Well = {
				meshId = "rbxassetid://74734368596452",
				size = Vector3.new(2.8115, 0.97, 2.5598),
				centre = Vector3.new(0, 0.485, 0),
			},
			Water_Path_Tile = {
				meshId = "rbxassetid://123015666819274",
				size = Vector3.new(4, 0.4669, 4),
				centre = Vector3.new(0, 0.2335, 0),
			},
			Wooden_Gate = {
				meshId = "rbxassetid://100810743311418",
				size = Vector3.new(3, 1.77, 1.8096),
				centre = Vector3.new(0, 0.885, 0),
			},
		},
		roles = {
			WallBlock = "Stone_Wall",
			CornerPillar = "Corner_Pillar",
			FallenLog = "Crate_Barrel",
			TreeStump = "Stone_Ruins",
			TallCover = "Stone_Ruins",
			Centrepiece = "Stone_Well",
			SideHouse = "House_Corner",
			Lantern = "Lantern_Post",
			PathTile = "Water_Path_Tile",
			Door = "Wooden_Gate",
		},
		sideHouses = 3,
		wallsFaceIn = true,
		causeway = 0.3,
		wetFloor = true,
		tile = 3.5,
		--[[ The sheet's flood water, sampled from its open floor. ]]
		lawn = {
			Color3.fromRGB(0, 186, 186),
			Color3.fromRGB(0, 180, 186),
			Color3.fromRGB(6, 186, 192),
			Color3.fromRGB(0, 174, 180),
		},
		water = Color3.fromRGB(0, 160, 170),
		bank = Color3.fromRGB(96, 150, 150),
		pathSpacing = 3.6,
		pathSway = 0,
		edgeDepth = 2.6,
		--[[ Nothing grows on the open water: reeds only, at the edges. ]]
		plants = {},
		reeds = {
			colours = {
				Color3.fromRGB(98, 196, 58),
				Color3.fromRGB(74, 166, 44),
				Color3.fromRGB(122, 208, 70),
			},
			clumps = 4,
			height = 2.6,
		},
		thicketSpacing = 2.4,
		southGate = true,
	},
	--[[ Act 2, area 4: Bogheart Caverns (the owner's kit, Claude Design,
	     2026-11-05; `area04_bogheart_caverns_v2.png` and, without the
	     stream, `area04_bogheart_caverns_open.png`, both approved). Dark
	     slate floor with moss, tall rock walls with glowing mushrooms at
	     their feet, a glowing stream across the middle (its water boxes)
	     with a plank bridge in the centre and stepping stones near each
	     side wall, four giant glowing mushrooms as the tall cover, and a cave
	     mouth top and bottom. Bundled `--srgb`. ]]
	Bogheart = {
		scale = 2.6,
		pieces = {
			RockWall = {
				meshId = "rbxassetid://97199530932564",
				size = Vector3.new(3.3, 3.55, 1.71),
				centre = Vector3.new(0, 1.775, 0),
				glow = {
					meshId = "rbxassetid://103494967975245",
					tint = Color3.fromRGB(140, 165, 170),
					size = Vector3.new(0.5325, 0.536, 0.54),
					centre = Vector3.new(0.551, 0.268, 0.721),
				},
			},
			CornerPillar = {
				meshId = "rbxassetid://128583604961643",
				size = Vector3.new(1.985, 4.59, 1.94),
				centre = Vector3.new(0, 2.295, 0),
				glow = {
					meshId = "rbxassetid://74452419705745",
					tint = Color3.fromRGB(140, 165, 170),
					size = Vector3.new(0.4994, 0.4304, 0.442),
					centre = Vector3.new(1.147, 0.215, 0.981),
				},
			},
			GiantMushroom = {
				meshId = "rbxassetid://126662517601951",
				size = Vector3.new(2.2, 0.58, 2.08),
				centre = Vector3.new(0, 0.29, 0),
				glow = {
					meshId = "rbxassetid://131336008136990",
					tint = Color3.fromRGB(150, 175, 180),
					size = Vector3.new(2.325, 3.06, 2.325),
					centre = Vector3.new(0.013, 1.83, -0.027),
					light = Color3.fromRGB(90, 230, 240),
					lightRange = 16,
				},
			},
			MushroomCluster = {
				meshId = "rbxassetid://136429125582027",
				size = Vector3.new(0.93, 0.26, 0.81),
				centre = Vector3.new(0, 0.13, 0),
				glow = {
					meshId = "rbxassetid://72038696504520",
					tint = Color3.fromRGB(140, 165, 170),
					size = Vector3.new(0.9125, 1.0645, 0.93),
					centre = Vector3.new(-0.009, 0.532, 0.08),
				},
			},
			BogSprout = {
				meshId = "rbxassetid://108944304765500",
				size = Vector3.new(1.72, 0.61, 1.485),
				centre = Vector3.new(0, 0.305, 0),
				glow = {
					meshId = "rbxassetid://120204995344659",
					tint = Color3.fromRGB(170, 175, 150),
					size = Vector3.new(0.81, 1.6, 0.43),
					centre = Vector3.new(0.105, 1.4, -0.213),
				},
			},
			--[[ The stream: the floor tile's water alone, drawn Neon; the
			     tile's own rock half is the floor round it. ]]
			StreamWater = {
				meshId = "rbxassetid://78413137800924",
				size = Vector3.new(3, 0.527, 1.258),
				centre = Vector3.new(0, 0.2635, 0),
				neon = true,
			},
			Bridge = {
				meshId = "rbxassetid://77612682999317",
				size = Vector3.new(1.7, 0.82, 3.6),
				centre = Vector3.new(0, 0.41, 0),
			},
			SteppingStones = {
				meshId = "rbxassetid://91173923281191",
				size = Vector3.new(4.2682, 0.29, 1.0767),
				centre = Vector3.new(0, 0.145, 0),
			},
			CaveGate = {
				meshId = "rbxassetid://70893093665645",
				size = Vector3.new(3.5, 3.18, 1.5),
				centre = Vector3.new(0, 1.59, 0),
				glow = {
					meshId = "rbxassetid://103423189831517",
					size = Vector3.new(2.5525, 0.302, 0.32),
					centre = Vector3.new(0.291, 0.401, 0.508),
				},
			},
		},
		roles = {
			WallBlock = "RockWall",
			TallCover = "GiantMushroom",
			TreeStump = "GiantMushroom",
			FallenLog = "GiantMushroom",
			FernBush = "MushroomCluster",
			StreamTile = "StreamWater",
			StreamStones = "SteppingStones",
			Door = "CaveGate",
		},
		keepShape = { TallCover = true },
		wallsFaceIn = true,
		streamFlatten = 0.4,
		bridgeFlatten = 0.6,
		tile = 3.5,
		--[[ The sheet's slate floor, sampled from its open middle. ]]
		lawn = {
			Color3.fromRGB(96, 102, 126),
			Color3.fromRGB(102, 108, 132),
			Color3.fromRGB(90, 102, 120),
			Color3.fromRGB(102, 108, 138),
		},
		moss = {
			colours = { Color3.fromRGB(102, 144, 54), Color3.fromRGB(110, 150, 50) },
			count = 22,
			size = 2,
		},
		water = Color3.fromRGB(0, 204, 222),
		bank = Color3.fromRGB(84, 90, 114),
		pathSpacing = 3.6,
		pathSway = 0,
		edgeDepth = 2.4,
		plants = { MushroomCluster = 3, BogSprout = 1 },
		thicketSpacing = 2.4,
		southGate = true,
	},
}

return table.freeze(ArenaKits)
