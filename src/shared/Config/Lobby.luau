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

export type Placed = { piece: string, at: Vector2, yaw: number? }

export type Portal = {
	--[[ The area's name on its sign, and the `Balance.Stages` index its
	     run plays; nil for a locked arch (an area not built yet). ]]
	name: string?,
	stage: number?,
	--[[ The swirl's colour, and the sign piece above the arch. ]]
	tint: Color3?,
	sign: string?,
}

local GREEN = Color3.fromRGB(80, 230, 70)
local PURPLE = Color3.fromRGB(190, 70, 235)

local Lobby = {
	--[[ Where the lobby's centre stands in the world: well away from the
	     arena at the origin. ]]
	origin = Vector3.new(0, 0, 1000),
	--[[ The walkable clearing, studs across (X) and deep (Z). ]]
	size = Vector2.new(110, 96),
	--[[ Studs per kit unit, as the arena kits are drawn. ]]
	scale = 3,
	--[[ Where a player appears: beside the campfire. ]]
	spawn = Vector2.new(-4, 25),

	--[[ The portal terraces across the north edge: two rows of arches
	     (owner, 2026-10-25: "make sure there are 2 rows of portals with them
	     being locked, there should be at least 10 portals for now"). `terrace`
	     is the front row's centre; the back row stands `rowDepth` studs
	     behind it and `rowRise` up, reached by steps. ]]
	terrace = Vector2.new(0, -30),
	rowDepth = 12,
	rowRise = 1,
	perRow = 5,
	archSpacing = 9,
	--[[ The arches, front row west to east, then the back row: the two
	     areas built so far, then eight locked. ]]
	portals = {
		{ name = "Mossy Glade", stage = 5, tint = GREEN, sign = "PortalSignMossy" },
		{ name = "Thornwood", stage = 4, tint = PURPLE, sign = "PortalSignThornwood" },
		{},
		{},
		{},
		{},
		{},
		{},
		{},
		{},
	} :: { Portal },
	--[[ Studs in front of an active arch a player must come within to go
	     through it. ]]
	portalReach = 3.5,

	--[[ The stations, as the sheet lays them out: the pet grove (the
	     hatchery) west, the gear grove (blacksmith, gear station, dex hall)
	     east, the campfire spawn in the middle. ]]
	stations = {
		{ piece = "EggHatchery", at = Vector2.new(-34, -6) },
		{ piece = "Blacksmith", at = Vector2.new(22, -18) },
		{ piece = "GearStation", at = Vector2.new(37, 0) },
		{ piece = "DexHall", at = Vector2.new(27, 18) },
		{ piece = "SpawnCampfire", at = Vector2.new(-4, 14) },
	} :: { Placed },

	--[[ The dirt paths, as runs of points: the spawn up to the portals, and
	     out to each grove. ]]
	paths = {
		{
			Vector2.new(-4, 46),
			Vector2.new(-4, 24),
			Vector2.new(-2, 0),
			Vector2.new(0, -18),
			Vector2.new(0, -26),
		},
		{ Vector2.new(-8, 8), Vector2.new(-20, 0), Vector2.new(-30, -2) },
		{ Vector2.new(0, 4), Vector2.new(12, -6), Vector2.new(20, -12) },
		{ Vector2.new(2, 10), Vector2.new(18, 10), Vector2.new(30, 4) },
		{ Vector2.new(2, 14), Vector2.new(16, 18), Vector2.new(22, 18) },
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
	tile = 4,

	--[[ The forest round the clearing: a ring of trees and cliffs this many
	     studs apart, with waterfalls at the four corners as on the sheet,
	     and a scatter of bushes, rocks and glowing mushrooms on the lawn. ]]
	ringSpacing = 9,
	waterfalls = {
		Vector2.new(-48, -38),
		Vector2.new(48, -38),
		Vector2.new(-50, 36),
		Vector2.new(50, 36),
	},
	scatter = { Bush = 22, Rock = 10, GlowMushroom = 14 },

	--[[ The kit's pieces, from the owner's import (`kit_bundle.py --srgb`
	     on `assets/models/lobby/lobby_kit`); empty until it is imported. ]]
	pieces = {} :: { [string]: ArenaKits.Piece },
}

return table.freeze(Lobby)
