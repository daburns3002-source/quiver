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
}

local ArenaKits: { [string]: Kit } = {
	Mossy = {
		scale = 3.2,
		pieces = {
			WallBlock = {
				meshId = "rbxassetid://133735089173602",
				size = Vector3.new(1.104, 0.722, 0.492),
				centre = Vector3.new(0, 0.361, 0),
			},
			CornerPillar = {
				meshId = "rbxassetid://95109128405834",
				size = Vector3.new(0.86, 1.02, 0.77),
				centre = Vector3.new(0, 0.51, 0),
			},
			FallenLog = {
				meshId = "rbxassetid://83798974084855",
				size = Vector3.new(2.48, 0.8165, 1),
				centre = Vector3.new(0, 0.4083, 0),
			},
			TreeStump = {
				meshId = "rbxassetid://118180618895571",
				size = Vector3.new(1.18, 0.75, 1.115),
				centre = Vector3.new(0, 0.375, 0),
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
			},
			FlowerTuft = {
				meshId = "rbxassetid://77682975928453",
				size = Vector3.new(0.5506, 0.48, 0.4644),
				centre = Vector3.new(0, 0.24, 0),
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
		lawn = {
			Color3.fromRGB(106, 176, 64),
			Color3.fromRGB(96, 166, 58),
			Color3.fromRGB(116, 186, 70),
		},
		water = Color3.fromRGB(70, 150, 190),
		bank = Color3.fromRGB(70, 120, 48),
		pathSpacing = 3.6,
		pathSway = 2.2,
		edgeDepth = 2.6,
		plants = { FernBush = 5, FlowerTuft = 5, GlowMushroom = 2 },
		thicketSpacing = 2.4,
	},
}

return table.freeze(ArenaKits)
