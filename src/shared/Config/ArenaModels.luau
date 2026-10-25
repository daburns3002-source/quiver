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
	--[[ The part's colour, in place of white (which shows the mesh's own
	     vertex colours). For glow whose colour was a material, which the
	     importer drops: the outer forest's cyan mushroom caps. ]]
	tint: Color3?,
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
	to the room's own cover boxes in `Balance`; the forest round it is the
	blocky outer forest.
]]

local GladeForest = require(script.Parent.GladeForest)

local GLADE_FOREST: { ArenaPart } = GladeForest

--[[ The forest floor past the outer forest's own edge (75 studs out to
     either side, 60 north and south): its ground's darkest green
     (docs/arenas/mossy-glade-outer.md), so the two read as one floor
     (owner, 2026-10-22: "it should not be two different shades of green").
     Both are drawn matte, so the same colour reads the same. ]]
local GLADE_FLOOR = Color3.fromRGB(63, 107, 42)

--[[ A blocky glade (the owner's Mossy Glade kit, 2026-10-24): every room
     built from the kit to its own size and cover (`Config/ArenaKits`),
     inside the blocky outer forest (`Config/GladeForest`, 2026-10-24),
     which reaches past every screen's edges on its own. The round forest
     it replaces, drawn again either side as `surround`, is in the history
     (before the outer forest's PR). ]]
local function glade(lowCover: "Water" | "Thicket"): ArenaModel
	return {
		parts = GLADE_FOREST,
		outsideColor = GLADE_FLOOR,
		ambience = "Forest",
		kit = "Mossy",
		lowCover = lowCover,
	}
end

local ThornwoodForest = require(script.Parent.ThornwoodForest)

local THORNWOOD_FOREST: { ArenaPart } = ThornwoodForest

--[[ Past the wood's own edge, its ground's darkest green, as the glade's. ]]
local THORNWOOD_FLOOR = Color3.fromRGB(55, 105, 31)

--[[ Act 1, area 2: Thornwood (Level 2), built from the owner's blocky
     Thornwood kit the same way, inside its own outer wood
     (`Config/ThornwoodForest`, 2026-10-25): the room's thorn trees,
     bramble banks, bone spikes and dead snags with crows, with its own life
     (`Balance.Ambience.Thornwood`). Thickets are thorn bushes. ]]
local function thornwood(): ArenaModel
	return {
		parts = THORNWOOD_FOREST,
		outsideColor = THORNWOOD_FLOOR,
		ambience = "Thornwood",
		kit = "Thornwood",
		lowCover = "Thicket",
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
	ThornHedges = thornwood(),
	ThornHollow = thornwood(),
	ThornBoulders = thornwood(),
	ThornBrambles = thornwood(),
	ThornBoss = thornwood(),
}

return table.freeze(ArenaModels)
