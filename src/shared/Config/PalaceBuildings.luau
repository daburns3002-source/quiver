--!strict
--[[
	The four lobby buildings as the owner imported them (2026-11-04), from the
	sheets `assets/concepts/blocky/lobby/palace/building_*_detailed.png`:
	"i want lobby b, weapon shop a, eggs c, gear a", then "the dex hall looks
	way too low poly".

	The source is `assets/models/lobby/palace/<name>_roblox.glb`, made from the
	Claude Design export by `bake_buildings.py`. Each `offset` is the part's
	centre from the import's pivot, read in Studio: the pivot is on the ground
	in the building's middle and its front is +Z, which is how `Run/Lobby` frames
	a building, so no part needs turning. Re-import and these ids change.

	A building's colours are on its mesh's vertices, so a part stays white.
	`glow` is a part drawn Neon. `bob` floats up and down.
	`front` is how far its steps reach and `top` its highest point, both studs.
]]

export type Piece = {
	name: string,
	mesh: string,
	size: Vector3,
	offset: Vector3,
	glow: boolean?,
	bob: boolean?,
}

export type Building = {
	front: number,
	top: number,
	pieces: { Piece },
}

local PalaceBuildings: { [string]: Building } = {
	Blacksmith = {
		front = 18.2,
		top = 41.6,
		pieces = {
			{
				name = "Body",
				mesh = "rbxassetid://93409852368886",
				size = Vector3.new(37.933, 19.709, 32.133),
				offset = Vector3.new(0.003, 9.855, 2.108),
			},
			{
				name = "Roof",
				mesh = "rbxassetid://72052554441689",
				size = Vector3.new(39.318, 9.534, 29.305),
				offset = Vector3.new(-0.005, 16.667, 0.005),
			},
			{
				name = "Landmark",
				mesh = "rbxassetid://103722706250654",
				size = Vector3.new(27.584, 36.789, 16.626),
				offset = Vector3.new(-4.442, 23.195, 0.963),
			},
			{
				name = "GlowGem",
				mesh = "rbxassetid://93714652179656",
				size = Vector3.new(2.358, 2.722, 4.621),
				offset = Vector3.new(-10.513, 29.37, 4.208),
				glow = true,
			},
			{
				name = "GlowForge",
				mesh = "rbxassetid://85941049986681",
				size = Vector3.new(7.4, 28.61, 11.5),
				offset = Vector3.new(5.5, 16.455, -1.45),
				glow = true,
			},
			{
				name = "GlowWindows",
				mesh = "rbxassetid://119471862182304",
				size = Vector3.new(35.85, 4.44, 27.175),
				offset = Vector3.new(0, 6.22, 0.663),
				glow = true,
			},
		},
	},
	EggHatchery = {
		front = 17.1,
		top = 40,
		pieces = {
			{
				name = "Body",
				mesh = "rbxassetid://140170286002338",
				size = Vector3.new(38, 21.105, 31.075),
				offset = Vector3.new(0, 10.553, 1.537),
			},
			{
				name = "Roof",
				mesh = "rbxassetid://84570380613239",
				size = Vector3.new(40.56, 9.457, 30.56),
				offset = Vector3.new(0, 16.778, 0),
			},
			{
				name = "Landmark",
				mesh = "rbxassetid://88662549935143",
				size = Vector3.new(26.717, 16.802, 8.869),
				offset = Vector3.new(-0.04, 24.001, 0),
			},
			{
				name = "FloatingEgg",
				mesh = "rbxassetid://124135185322273",
				size = Vector3.new(9.675, 11, 9.74),
				offset = Vector3.new(-0.049, 34.5, 0),
				bob = true,
			},
			{
				name = "GlowWindows",
				mesh = "rbxassetid://96618017234343",
				size = Vector3.new(35.44, 5.96, 25.693),
				offset = Vector3.new(0, 5.98, 0.126),
				glow = true,
			},
			{
				name = "GlowStand",
				mesh = "rbxassetid://79433966828094",
				size = Vector3.new(7.8, 0.08, 7.8),
				offset = Vector3.new(0, 26.673, 0),
				glow = true,
			},
		},
	},
	GearStation = {
		front = 21.8,
		top = 42,
		pieces = {
			{
				name = "Body",
				mesh = "rbxassetid://101375615143075",
				size = Vector3.new(38, 21.486, 35.8),
				offset = Vector3.new(0, 10.717, 3.9),
			},
			{
				name = "Roof",
				mesh = "rbxassetid://97115893844062",
				size = Vector3.new(38.827, 19.183, 28.827),
				offset = Vector3.new(0, 11.591, 0),
			},
			{
				name = "Landmark",
				mesh = "rbxassetid://80010390299015",
				size = Vector3.new(29.658, 26.532, 19.297),
				offset = Vector3.new(1.629, 28.766, -1.527),
			},
			{
				name = "GlowWindows",
				mesh = "rbxassetid://100087568884479",
				size = Vector3.new(36.5, 3.5, 26.5),
				offset = Vector3.new(0, 6.35, 0),
				glow = true,
			},
			{
				name = "GlowLanterns",
				mesh = "rbxassetid://103808052388668",
				size = Vector3.new(20.756, 3.422, 4.837),
				offset = Vector3.new(0, 7.665, 12.483),
				glow = true,
			},
		},
	},
	DexHall = {
		front = 18,
		top = 19,
		pieces = {
			{
				name = "Body",
				mesh = "rbxassetid://102478661659040",
				size = Vector3.new(38, 19, 32),
				offset = Vector3.new(0, 9.5, 2),
			},
			{
				name = "Roof",
				mesh = "rbxassetid://76998618169622",
				size = Vector3.new(37.94, 17.6, 27.94),
				offset = Vector3.new(0, 10.2, 0),
			},
			{
				name = "GlowWindows",
				mesh = "rbxassetid://92448982006597",
				size = Vector3.new(35.4, 4.5, 25.4),
				offset = Vector3.new(0, 5.65, 0),
				glow = true,
			},
			{
				name = "GlowLanterns",
				mesh = "rbxassetid://81914285026127",
				size = Vector3.new(20.598, 2.612, 9.171),
				offset = Vector3.new(0, 6.681, 10.126),
				glow = true,
			},
		},
	},
}

return table.freeze(PalaceBuildings)
