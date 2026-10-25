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
	glow: { meshId: string, size: Vector3, centre: Vector3 }?,
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
			BrambleHedge = {
				meshId = "rbxassetid://131412433375868",
				size = Vector3.new(2, 0.988, 0.7581),
				centre = Vector3.new(0, 0.494, 0),
			},
			ThornTree = {
				meshId = "rbxassetid://111589575242394",
				size = Vector3.new(1.6628, 2, 1.4856),
				centre = Vector3.new(0, 1, 0),
			},
			MossyBoulder = {
				meshId = "rbxassetid://140108563241728",
				size = Vector3.new(1.225, 1.07, 1.08),
				centre = Vector3.new(0, 0.535, 0),
			},
			ThornBush = {
				meshId = "rbxassetid://123520313943150",
				size = Vector3.new(1.04, 0.98, 1.04),
				centre = Vector3.new(0, 0.49, 0),
			},
			RootSprout = {
				meshId = "rbxassetid://95010626591606",
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
		--[[ A darker, browner green than the glade's, under the brambles. ]]
		lawn = {
			Color3.fromRGB(86, 116, 50),
			Color3.fromRGB(80, 108, 46),
			Color3.fromRGB(93, 123, 55),
		},
		--[[ The orange dirt of the reference sheet. ]]
		dirt = {
			Color3.fromRGB(176, 106, 54),
			Color3.fromRGB(162, 96, 48),
			Color3.fromRGB(186, 116, 60),
		},
		water = Color3.fromRGB(70, 130, 150),
		bank = Color3.fromRGB(96, 80, 46),
		pathSpacing = 3.2,
		pathSway = 2.6,
		edgeDepth = 2.8,
		plants = { ThornBush = 3, RootSprout = 4 },
		thicketSpacing = 2.6,
		southGate = true,
	},
}

return table.freeze(ArenaKits)
