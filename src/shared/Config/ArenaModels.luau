--!strict
--[[
	Arena models: a room's look, built from the owner's Claude Design models
	in place of the grey-box dressing (`Arena.build`).

	Presentation only. A room with a model keeps the same invisible floor,
	walls and obstacle boxes as every other room — those are what collide
	and stop arrows — and draws the model over them. Cover in the model
	(a log, a stump) is cover because the room lists an obstacle box where
	it stands, not because of the mesh.

	Pipeline as for enemies: GLB from Claude Design →
	`assets/models/arenas/optimise_arena.py` → the owner imports it in Studio
	→ the mesh ids and sizes go here, scaled into the room and turned to face
	the way Claude Design shows it (the importer turns models 180°).
]]

export type ArenaPart = {
	name: string,
	meshId: string,
	--[[ Size and offset from the room's centre on the floor (y = 0), already
	     scaled and turned. ]]
	size: Vector3,
	offset: Vector3,
	--[[ Drawn Neon, for glowing mushrooms and the like. ]]
	glow: boolean?,
	--[[ Drawn matte. The glades' ground needs it: as plastic, its dark outer
	     grass caught the light and read pale grey (owner, 2026-10-22). Its
	     bright lawn keeps its own colour either way. ]]
	matte: boolean?,
	--[[ Drawn as a flat ellipse of water this size, at this place on the
	     lawn, not as its mesh: the pond's water is a single sheet with no
	     thickness, which Roblox does not draw (the pond showed as a dark
	     hole). ]]
	water: Color3?,
	--[[ For water: the darker lawn the model paints in a ring round it, in
	     low-poly steps. Drawn as a smooth ellipse instead, so the pond's
	     edge is round (owner, 2026-10-23). ]]
	bank: Color3?,
}

export type ArenaModel = {
	parts: { ArenaPart },
	--[[
		What fills the screen past the model's edges, so the camera never
		sees the grey void (owner, 2026-10-22). The model is about 81 studs
		wide and a desktop screen sees about 124: `surround` is parts (trees,
		bushes, grass) drawn again `surroundSpacing` studs to either side,
		and `outsideColor` is a forest floor laid under everything, the
		model's own outer ground colour.
	]]
	surround: { ArenaPart }?,
	surroundSpacing: number?,
	outsideColor: Color3?,
	--[[ The life drawn in the scenery past the walls, a `Balance.Ambience`
	     entry (`Fx/ForestAmbience`): leaves, fireflies, mist, birds. ]]
	ambience: string?,
	--[[ An `ArenaKits` entry the room is built from, in place of `parts`'
	     ground, walls and cover (`Shared/Util/KitLayout`), and what its
	     flat, low cover is: water or a thicket. ]]
	kit: string?,
	lowCover: ("Water" | "Thicket")?,
}

--[[
	Act 1, area 1: the Mossy Glade, five arenas for Level 1's rooms (owner,
	2026-10-22): logs, hollow, boulders, thorns, boss. Since 2026-10-24 every
	one is built from the owner's blocky kit (`Config/ArenaKits`), laid out
	to the room's own cover boxes in `Balance`; the forest round it is still
	the round models' until a blocky forest exists.
]]

--[[ Every glade's outer ground, exactly its vertex colour, so the forest
     floor past the model's edge is the same green as the model's own ground
     (owner, 2026-10-22: "it should not be two different shades of green").
     Both are drawn matte, so the same colour reads the same. ]]
local GLADE_FLOOR = Color3.fromRGB(53, 88, 41)

--[[ The boss arena's own bushes and trees. Squeezed to fit the room, they
     stand right up against its walls, a dense shaded forest the owner chose
     for every glade (2026-10-22: "copy that to the rest"). ]]
local BOSS_FOREST: { ArenaPart } = {
	{
		name = "Bushes",
		meshId = "rbxassetid://80762864267370",
		size = Vector3.new(65.941, 4.088, 101.221),
		offset = Vector3.new(-0.031, 1.658, -7.685),
	},
	{
		name = "Trees",
		meshId = "rbxassetid://82996110055874",
		size = Vector3.new(74.834, 13.063, 114.270),
		offset = Vector3.new(-0.561, 6.966, -6.824),
	},
}

--[[ The log glade's wider forest and grass, drawn again either side past the
     boss forest so the screen's edges are trees too. ]]
local WIDE_FOREST: { ArenaPart } = {
	{
		name = "Trees",
		meshId = "rbxassetid://104769390455997",
		size = Vector3.new(96.184, 15.779, 128.239),
		offset = Vector3.new(0.250, 8.306, -6.803),
	},
	{
		name = "Bushes",
		meshId = "rbxassetid://129899405699443",
		size = Vector3.new(81.689, 4.153, 115.584),
		offset = Vector3.new(1.126, 1.498, -5.756),
	},
	{
		name = "Grass",
		meshId = "rbxassetid://114418367398398",
		size = Vector3.new(80.737, 1.773, 115.843),
		offset = Vector3.new(-0.200, 0.859, -7.078),
	},
}

--[[ A blocky glade (the owner's Mossy Glade kit, 2026-10-24): every room
     built from the kit to its own size and cover (`Config/ArenaKits`),
     inside the boss arena's forest, with the wide forest either side. The
     round glade variants this replaces, one model per room, are in the
     history (before #193). ]]
local function glade(lowCover: "Water" | "Thicket"): ArenaModel
	return {
		parts = BOSS_FOREST,
		surround = WIDE_FOREST,
		surroundSpacing = 81,
		outsideColor = GLADE_FLOOR,
		ambience = "Forest",
		kit = "Mossy",
		lowCover = lowCover,
	}
end

local ArenaModels = {
	GladeLogs = glade("Thicket"),
	--[[ Was the pond, until the owner took the water out of the Mossy Glade
	     (2026-10-24). The room keeps its shape — the wide low patch is now a
	     bramble hollow, which blocks walking and lets arrows over exactly as
	     the water did. `glade("Water")` still works and area 3, the Drowned
	     Village, will want it. ]]
	GladeHollow = glade("Thicket"),
	GladeBoulders = glade("Thicket"),
	GladeThorns = glade("Thicket"),
	GladeBoss = glade("Thicket"),
}

return table.freeze(ArenaModels)
