--!strict
--[[
	The lobby (owner, 2026-10-25: "this lobby needs to be created in the same
	top down way the gameplay is ... it should also have area portals that
	players are able to go into that will launch them into the specific
	areas").

	Rebuilt from scratch on 2026-10-27 (owner: "scrap this lobby and make one
	from scratch. i dont want it to have the pixely texture. just make it look
	like a normal lobby. the only pixely part should be the text font"), after
	the owner's reference clip of a bright simulator lobby: flat green lawn,
	sandy paths with darker edges, raised grass ledges on orange-brown cliff
	sides, round grey boulders, puffy round trees, waterfalls, cottages with
	coloured roofs, wooden signs and round wooden egg platforms. Everything is
	built at boot from plain smooth parts (`Run/Lobby`); the words alone are
	in the game's font. The one exception is the Dex Hall's two books
	(`dex` below), which the owner modelled and imported himself
	(2026-11-01: "i made the book that goes on the roof and also the book
	stand that is on the ground in front of it") -- an open book's pages
	are not a shape a few boxes make well, and they are the thing the hall
	is named for.

	A clearing beside the arena, far enough away that neither is ever on
	screen with the other. Players arrive at the fountain after BEGIN
	ADVENTURE, walk between the stations, and step into an active portal to
	start that area's run (`Run/RoomController.beginStage`).

	Positions are studs from the lobby's centre on its floor; north is −Z,
	as in the arena, so the portals stand at the top of the screen. Buildings
	face south (+Z), towards the spawn.
]]

export type Placed = { piece: string, at: Vector2 }

--[[ One of the Dex Hall's imported models (`dex` below), as much of it as
     every one of them has: `Run/Lobby` reads these four to clone and size
     a piece, and each piece adds whatever else its own placing needs. ]]
export type DexPiece = {
	mesh: string,
	texture: string,
	native: Vector3,
	across: number,
}

--[[ One mesh of a portal built from a Claude Design bundle: its size in studs,
     and its middle from the middle of the portal's foot, as the bundle
     prints them. A `neon` one is drawn Neon, its colours in the mesh. ]]
export type PortalPart = {
	mesh: string,
	size: Vector3,
	middle: Vector3,
	neon: boolean?,
}

--[[ An area's portal as its doorway is built from the area itself: the frame's
     import, and its vortex's sheet (`portalVortex`). A Claude Design build
     comes as `parts` in its own vertex colours (no `texture`): `mesh` is then
     its first part's, and `size` the whole portal's. `vortexFoot` stands its
     vortex at another height than `portalVortex.foot`, for a taller doorway,
     and `vortexForward` further forward than `portalVortex.forward`, in front
     of a dark slab the build fills its door with. `signLift` raises the name
     sign over something that stands on the doorway's top. ]]
export type PortalModel = {
	mesh: string,
	texture: string,
	size: Vector3,
	vortex: string,
	glow: Color3,
	parts: { PortalPart }?,
	vortexFoot: number?,
	vortexForward: number?,
	signLift: number?,
}

export type Portal = {
	--[[ The area's name on its sign, and its levels: the `Balance.Stages`
	     index each plays, in order, offered on the portal's screen
	     (`UI/PortalScreen`); nil for a locked arch (an area not built yet). ]]
	name: string?,
	levels: { number }?,
	--[[ The swirl's colour. ]]
	tint: Color3?,
	--[[ A level (`StageConfig.level`, "1-10") that must be beaten before
	     this portal opens at all, on top of its own levels' unlocking
	     (`Util/LevelUnlocks.portalOpen`). Endless has one: it is a death at
	     floor 6 with no cards and no gear, so clearing the first area's
	     boss is the proof the mode is worth opening (`docs/ENDLESS.md`).
	     Nil for a portal that needs nothing. ]]
	requires: string?,
	--[[ What this portal waits on once the game is locked for launch
	     (`Config/Launch.locks`, read through `Util/LaunchLocks`): a level
	     that must be beaten, as `requires`, or an area whose boss must be.
	     Nil for the first area, which nothing gates. While the switch is
	     off this is not read, and the portal is as open as it is today. ]]
	atLaunch: { requires: string?, boss: string? }?,
	--[[ A portal that stands apart from the areas' two rows (Endless, owner,
	     2026-11-19: "endless should be off to the side"): the middle of its
	     foot on the courtyard floor, in plan studs, and how far it is turned
	     from facing south, radians about Y (negative turns its front west).
	     Nil for an area's arch, which stands in its row on the terrace. ]]
	aside: { at: Vector2, turn: number }?,
}

--[[ A station's footprint and height, which the spacing between stations is
     measured against, and the big words floating over it. Its model is in
     `Config/PalaceBuildings`. ]]
export type Building = {
	size: Vector3,
	title: string,
	titleColour: Color3,
}

--[[
	Which way a building at `at` is turned, as radians about Y: south, towards
	the camera, and `TURN_IN` towards the middle line, as the layout sheet draws
	all four with their doors in view (owner, 2026-11-05: make it look like the
	reference). This replaces "every one facing the middle" of 2026-11-01, which
	showed the camera the backs of the southern two.

	A building is modelled facing +Z, which `CFrame.Angles(0, y, 0)` sends
	to (sin y, cos y). One function because three places need to agree
	about it -- the builder, the stands it puts out front, and the spec
	that measures the footprints -- and a building facing a way its own
	eggs do not is the bug this exists to make impossible.

	A station standing on the middle line is left unturned.
]]
--[[
	How far the plan is spread out (owner, 2026-11-12: "i want the lobby to be
	a little bigger and more spread out"). Every place on the courtyard below
	is written in the plan's studs, as the layout sheet measured them, through
	`plan`, which spreads it from the lobby's centre; the things themselves
	(the buildings, the fountain, the arches, the circles) keep their size.
	The terrace's front and its corners are worked out from the terrace rather
	than spread, since its depth is the steps' and does not grow. Past the
	balustrade the wood and the cliffs move out by what the clearing grew
	(`OUTWARD`), so the forest round it keeps its depth.
]]
--[[ `count` stages from `first` on, in order: an area's levels
     (`Balance.Stages`, `tools/area_levels.py`). ]]
local function stageRun(first: number, count: number): { number }
	local list = {}
	for index = first, first + count - 1 do
		table.insert(list, index)
	end
	return list
end

local SPREAD = 1.3
local function plan(x: number, z: number): Vector2
	return Vector2.new(x, z) * SPREAD
end
local OUTWARD = 110 * (SPREAD - 1)
local function pushed(range: NumberRange): NumberRange
	return NumberRange.new(range.Min + OUTWARD, range.Max + OUTWARD)
end

local MIDDLE = plan(0, 6)
local SPAWN = plan(0, 54)
local TERRACE = plan(0, -66)
local ROW_DEPTH = 19.2
local PER_ROW = 5
local ARCH_SPACING = 18 * SPREAD
--[[ The portal terraces' width, the arches and a margin either side, and the
     line of its front, where the courtyard's floor meets it. It keeps the
     width it had at six to a row, one arch more than a row holds now, so
     the courtyard's outline is unchanged and the back row's stairs have
     room beyond the ends of the front row's wall. ]]
local TERRACE_ACROSS = (PER_ROW + 1) * ARCH_SPACING + 24 * SPREAD
local TERRACE_FRONT = TERRACE.Y + ROW_DEPTH / 2
local TURN_IN = 0.25

local function facingSouth(at: Vector2): number
	if math.abs(at.X) < 1e-3 then
		return 0
	end
	return -math.sign(at.X) * TURN_IN
end

--[[ Where a point `offset` studs from a building's own middle lands once
     that building is turned: its local +Z is the way it
     faces, its +X to that way's right. The egg and crate stands are placed
     with this, so they stay out front whichever corner their station is
     on. ]]
local function turnedOffset(at: Vector2, offset: Vector2): Vector2
	local yaw = facingSouth(at)
	local s, c = math.sin(yaw), math.cos(yaw)
	return Vector2.new(offset.X * c + offset.Y * s, -offset.X * s + offset.Y * c)
end

local GREEN = Color3.fromRGB(80, 230, 70)
local PURPLE = Color3.fromRGB(140, 60, 235)
local CYAN = Color3.fromRGB(70, 220, 224)
local BLUE = Color3.fromRGB(60, 150, 235)

local Lobby = {
	--[[ Which way a building faces, and where a thing placed in front of
	     it lands once it is turned. See `facingSouth` above. ]]
	facing = facingSouth,
	turnedOffset = turnedOffset,
	--[[ How far the plan is spread out. See `SPREAD` above. ]]
	spread = SPREAD,

	--[[ Where the lobby's centre stands in the world: well away from the
	     arena at the origin. ]]
	origin = Vector3.new(0, 0, 1000),
	--[[ The walkable clearing, studs across (X) and deep (Z). ]]
	size = plan(220, 192),
	--[[ The fountain, which all four buildings face, halfway between their
	     rows. ]]
	middle = MIDDLE,
	--[[ Where a player appears: the middle of the arrival circle. ]]
	spawn = SPAWN,

	--[[ The portal terraces across the north edge: two rows of arches
	     (owner, 2026-10-25: "make sure there are 2 rows of portals"), each
	     on a marble ledge with broad marble steps up its front. `terrace` is the front row's centre; the back row stands
	     `rowDepth` studs behind it and `rowRise` higher. `ledge` is the
	     front row's height above the lawn. The back row stands clear above
	     the front row's wall, its cornice and the leaves on it (owner,
	     2026-11-19: "the second 5 area portals should be raised so they are
	     all visible"), and its stairs climb at the ends of the front ledge,
	     steeper than the front's (`backStep`, the most a step rises) so they
	     fit its depth. ]]
	terrace = TERRACE,
	rowDepth = ROW_DEPTH,
	rowRise = 22,
	ledge = 9,
	backStep = 1.1,
	--[[ Five to a row (owner, 2026-11-19: "make the first 5 areas on the
	     bottom row, then the next 5 in the next row"): areas 1-5 in front,
	     6-10 behind and above. Endless is in neither (its `aside`). ]]
	perRow = PER_ROW,
	archSpacing = ARCH_SPACING,
	--[[ The terraces' width, which the courtyard's corners at their front
	     meet, and the front row's broad steps up the middle. ]]
	terraceAcross = TERRACE_ACROSS,
	terraceSteps = 52 * SPREAD,
	--[[ The arches, front row west to east, then the back row, the areas in
	     order, then Endless, which stands aside. The index is what
	     `Remotes.PortalStart` carries, so Endless stays 11. ]]
	portals = {
		{
			name = "Mossy Glade",
			--[[ Mossy Glade 1-1..1-10 (owner, 2026-10-26), each opened by
			     beating the one before (`Util/LevelUnlocks`). ]]
			levels = { 7, 8, 9, 10, 11, 12, 13, 14, 15, 16 },
			tint = GREEN,
		},
		--[[ Thornwood 2-1..2-10 (owner, 2026-11-13: "there is 10 levels for
		     area 1, there should also be 10 for area 2, 15 for 3, 15 for 4"),
		     the Broodmother only at the end of 2-10. Each area's levels are
		     `Balance.Stages` in a run (`tools/area_levels.py`). ]]
		{
			name = "Thornwood",
			levels = stageRun(20, 10),
			tint = PURPLE,
			atLaunch = { requires = "1-10" },
		},
		--[[ The Drowned Village (2026-11-07, owner: "MAKE SURE ARENA 3 AND 4
		     ARE PLAYABLE"): 3-1..3-15 since 2026-11-13, the Old Tollcrab only
		     at the end of 3-15. ]]
		{
			name = "Drowned Village",
			levels = stageRun(30, 15),
			tint = BLUE,
			atLaunch = { boss = "Thornwood" },
		},
		--[[ Bogheart Caverns (2026-11-06): 4-1..4-15 since 2026-11-13,
		     Grandmother Gulp only at the end of 4-15. ]]
		{
			name = "Bogheart Caverns",
			levels = stageRun(45, 15),
			tint = CYAN,
			atLaunch = { boss = "DrownedVillage" },
		},
		{ name = "Windswept Cliffs" },
		{ name = "Frostpeak Pass" },
		{ name = "Ember Mines" },
		{ name = "Obsidian Forge" },
		{ name = "Shattered Kingdom" },
		{ name = "Void Rift" },
		--[[ Endless (`docs/ENDLESS.md`, `Balance.endlessStage`): one
		     "level", opened by beating Mossy Glade 1-10 (`requires`). Last
		     of the arches so the ten areas keep their order in the rows.
		     It stands apart (owner, 2026-11-19: "endless should be off to
		     the side"): on the courtyard floor by the east balustrade, in
		     the open gap between the Hatch Eggs and the Dex Hall, turned
		     toward the fountain, so it shows from the spawn when a player
		     turns east. (Tucked behind the Hatch Eggs at first, its door
		     faced that building's back wall and only its sign showed.) ]]
		--[[ Open to everyone while the game is in playtest (owner,
		     2026-10-28: "since its still in playtest phase, that should
		     just be unlocked for now"). At launch (`Config/Launch.locks`)
		     it waits on 1-10 again: with no cards and no gear Endless is
		     a death at floor 6 (`docs/ENDLESS.md`). ]]
		{
			name = "Endless",
			levels = { 17 },
			tint = CYAN,
			atLaunch = { requires = "1-10" },
			aside = { at = plan(61.5, 4.6), turn = -1.65 },
		},
	} :: { Portal },
	--[[
		The owner's imported lobby models (2026-11-01). `native` is each
		import's own size, kept here so the placing maths never waits on a
		fetch; everything is scaled off it.
	]]
	--[[ The lobby's tree, built in code from a trunk and three round leaf
	     clusters in the layout sheet's colours (owner, 2026-11-05: "make a
	     new tree model then", built rather than generated). It replaces the
	     blocky import of 2026-11-01, whose bright lime texture could not be
	     tinted to the sheet's olive and yellow-green leaves. `tall` is the
	     studs a tree of `grow` 1 stands, so the scatter's spacing still holds;
	     `crown` is the leaves' width against that height, and `trunk` how much
	     of the height is bare trunk. ]]
	tree = {
		tall = 14,
		crown = 0.78,
		trunk = 0.4,
		--[[ Shadow side, body and the sunlit top, the fresh greens of the
		     enemy spotlight loading screens' voxel trees (owner, 2026-11-05:
		     the round-blob tree "look[s] terrible"). ]]
		leaves = {
			Color3.fromRGB(46, 100, 38),
			Color3.fromRGB(78, 146, 48),
			Color3.fromRGB(134, 190, 66),
		},
		bark = Color3.fromRGB(104, 72, 46),
		barkDark = Color3.fromRGB(78, 52, 34),
		--[[ How far a tree's height is stretched on its own, apart from
		     how wide it is (owner, 2026-11-01: "make the trees different
		     heights").

		     The scatter already grew each tree between 0.72 and 1.08, but
		     that scales a single mesh evenly, which only makes it look
		     nearer or further away -- the trunk and crown keep exactly
		     the same proportions. The built trees it replaced hid this by
		     randomising their crowns as well. Stretching the height by
		     itself is what actually reads as a taller or squatter tree.

		     With the scatter's own range that puts the lawn's trees
		     between about 8 and 21 studs. ]]
		stretch = NumberRange.new(0.8, 1.4),
	},
	--[[ The owner's blocky tree, a few of them on the lawn past the
	     balustrade among the built trees (owner, 2026-11-27: the lobby only,
	     not Mossy Glade's round trees). One textured MeshPart each, from
	     `assets/models/lobby/imports/blocky_tree/blocky_tree.glb`; these
	     are its ids from its import of 2026-11-01. `native` is the import's
	     own size, so a spot's `tall` scales it evenly. The lawn lies
	     `courtyard.drop` (18) below the floor, so each is tall enough for its
	     crown to show over the balustrade, like the tallest trees round it.
	     `turn` is its yaw, radians. ]]
	blockyTree = {
		mesh = "rbxassetid://139262265934696",
		texture = "rbxassetid://93690388231604",
		native = Vector3.new(2.54, 4.6, 2.49),
		spots = {
			{ at = plan(-101, 4), tall = 30, turn = 0.4 },
			{ at = plan(-99, 46), tall = 26, turn = 2.1 },
			{ at = plan(101, 22), tall = 31, turn = 4.0 },
			{ at = plan(99, 58), tall = 27, turn = 5.3 },
			{ at = plan(-38, 97), tall = 28, turn = 1.2 },
			{ at = plan(42, 97), tall = 25, turn = 3.1 },
		},
	} :: {
		mesh: string,
		texture: string,
		native: Vector3,
		spots: { { at: Vector2, tall: number, turn: number } },
	},
	--[[ An arch's opening, studs across and how high its straight sides go
	     before the round top, and the height of the stone wall it is set in.
	     Every arch is built alike, as the sheet draws them: the swirl where
	     an area is open, the dark and a gold padlock where it is not. ]]
	archWidth = 11,
	archSides = 7.5,
	archWall = 19,
	--[[ The first six areas' portals (owner, 2026-11-09: "these portals should
	     make the player want to go into them"), built in Claude Design from
	     `assets/concepts/blocky/lobby/portals/all_portals_sheet.png`. An area
	     with none here, or whose mesh fails to load, keeps the stone arch. ]]
	portalModels = {
		["Mossy Glade"] = {
			mesh = "rbxassetid://138140072246137",
			texture = "rbxassetid://85684207475910",
			size = Vector3.new(14, 16, 4.11),
			vortex = "rbxassetid://115423428634010",
			glow = Color3.fromRGB(98, 255, 82),
		},
		["Thornwood"] = {
			mesh = "rbxassetid://84206817791982",
			texture = "rbxassetid://100841004022404",
			size = Vector3.new(14, 16, 4),
			vortex = "rbxassetid://127070896945127",
			glow = Color3.fromRGB(255, 92, 240),
		},
		["Drowned Village"] = {
			mesh = "rbxassetid://88110060463725",
			texture = "rbxassetid://98345996998810",
			size = Vector3.new(14, 16, 4),
			vortex = "rbxassetid://121845901049381",
			glow = Color3.fromRGB(82, 255, 216),
		},
		["Bogheart Caverns"] = {
			mesh = "rbxassetid://108435223996759",
			texture = "rbxassetid://103828695589809",
			size = Vector3.new(14, 16, 4),
			vortex = "rbxassetid://85884628214680",
			glow = Color3.fromRGB(82, 243, 255),
		},
		["Windswept Cliffs"] = {
			mesh = "rbxassetid://132513326915749",
			texture = "rbxassetid://105533971775105",
			size = Vector3.new(14, 16, 4),
			vortex = "rbxassetid://93801931241590",
			glow = Color3.fromRGB(92, 176, 255),
		},
		["Frostpeak Pass"] = {
			mesh = "rbxassetid://132514192792899",
			texture = "rbxassetid://73042383764143",
			size = Vector3.new(14, 15.9, 4),
			vortex = "rbxassetid://89240563088907",
			glow = Color3.fromRGB(154, 223, 255),
		},
		--[[ The Endless Rift Gate (owner, 2026-11-19: "make the portal for
		     endless look cooler"), Claude Design v2 bundled by
		     `assets/models/lobby/gate_bundle.py`: its stone, and its runes,
		     crystals and Soulstone glowing. Its vortex is Design's colours on
		     the shared sheet, its heart 5.5 studs up as in the build. ]]
		["Endless"] = {
			mesh = "rbxassetid://103147511344651",
			texture = "",
			size = Vector3.new(18.087, 20, 5.024),
			vortex = "rbxassetid://71023668996508",
			glow = Color3.fromRGB(154, 77, 255),
			parts = {
				{
					mesh = "rbxassetid://103147511344651",
					size = Vector3.new(18.087, 16.077, 5.024),
					middle = Vector3.new(0, 8.039, 0),
				},
				-- runes, the infinity sign, the crystals
				{
					mesh = "rbxassetid://97862318394495",
					size = Vector3.new(18.087, 15.072, 5.024),
					middle = Vector3.new(0, 8.039, 0),
					neon = true,
				},
				--[[ The floating Soulstone, apart and not Neon: Neon drew its
				     lilac white and its purple pink or blue under any tint
				     (seen in Studio, 2026-11-19). Plain, in the lobby's light,
				     it reads as the build's lilac top and purple middle, as
				     the gate's own lilac trim does. ]]
				{
					mesh = "rbxassetid://92473744736948",
					size = Vector3.new(7.536, 3.768, 5.024),
					middle = Vector3.new(0, 18.116, 0),
				},
			},
			vortexFoot = 1.4,
			--[[ The build's door is a near-black slab (`Abyss`) a stud thick
			     through the middle, which its 3D vortex reached through; the
			     sheet stands just in front of it. ]]
			vortexForward = 0.75,
			--[[ Clear of the floating Soulstone, which reaches the top. ]]
			signLift = 1.5,
		},
	} :: { [string]: PortalModel },
	--[[ Every portal's vortex is Bogheart Caverns's, cell for cell, recoloured
	     (owner, 2026-11-09: "take the exact inner portal for bogheart and put
	     it into the rest"): `assets/ui/portals/`, four rows of four frames of
	     its stepped spin. Studs across and high, its foot above the portal's,
	     how far forward of the portal's middle it stands, and the height of
	     the spiral's heart, which pulses. `step` is seconds a frame. ]]
	portalVortex = {
		size = Vector2.new(7, 8),
		foot = 1,
		forward = 0.2,
		heart = 5.1,
		cell = Vector2.new(224, 256),
		columns = 4,
		frames = 16,
		step = 0.11,
		pulse = "rbxassetid://72053512669132",
		tag = "PortalVortex",
	},
	--[[ The dark of a locked arch, and each open arch's plaque, by its name. ]]
	archDark = Color3.fromRGB(32, 26, 34),
	plaques = {
		["Mossy Glade"] = Color3.fromRGB(38, 92, 40),
		["Thornwood"] = Color3.fromRGB(70, 34, 112),
		["Endless"] = Color3.fromRGB(20, 88, 92),
	} :: { [string]: Color3 },

	--[[ Studs from an active arch's mouth a player must come within for its
	     screen to open (`UI/PortalScreen`), and how much further the server
	     still grants START from, for the time the press takes to arrive. ]]
	portalReach = 8.5,
	startSlack = 4,
	--[[ The level selector's slots per area: its levels, then locked ones
	     (COMING SOON) up to this many. ]]
	levelSlots = 3,
	--[[ A portal with more levels than `levelSlots` shows them as a grid of
	     numbered buttons instead, this many to a row. ]]
	levelColumns = 5,

	--[[ Moving round the lobby (owner, 2026-10-26): Shift, a gamepad's X or
	     the phone's SPRINT button runs this many times walking speed; Space,
	     A or JUMP jumps this high (studs). Runs keep the dash and never jump. ]]
	sprint = 1.7,
	jumpHeight = 7.2,
	--[[ Studs in front of an arch where its mouth is. ]]
	mouthAhead = 4,
	--[[
		The stations, one to each corner of the clearing (owner,
		2026-11-01: "every building should be either northwest,
		northeast, southwest, or southeast ... and then the portals are at
		the north"). Which goes where is the layout the owner chose on
		2026-11-04 (`lobby_layout_reference.png`): weapons northwest, eggs
		northeast, gear southwest, dexes southeast.

		North is -Z and west is -X, so a corner is a sign on each. They
		were strung along the east side before, which left the west half
		of the lawn empty and the player walking a line rather than a
		circuit; a corner each puts the fountain in the middle of four
		and the portals beyond it.

		The two northern ones stand clear of the portal terraces, whose
		front ledge reaches z = -76.2: grown by `buildingScale` and turned in,
		they reach about z = -59. The rows stand 68 plan studs apart (88 once
		spread), so a northern building is not hidden behind a southern one's
		roof from the camera, and x = 51 north and 56 south keeps their outer
		corners inside the balustrade, whose northern corners are cut on the
		slant.

		The spawn's fountain keeps its old name `SpawnCampfire`, for the
		screens that look it up. `Lobby.spec` keeps every footprint apart,
		measured as each one is actually turned.
	]]
	stations = {
		{ piece = "Blacksmith", at = plan(-51, -28) },
		{ piece = "EggHatchery", at = plan(51, -28) },
		{ piece = "GearStation", at = plan(-56, 40) },
		{ piece = "DexHall", at = plan(56, 40) },
		{ piece = "SpawnCampfire", at = MIDDLE },
	} :: { Placed },

	--[[ How much larger than its export each building stands: the sheet's are
	     nearly a third of the courtyard's width. `buildings[...].size` is the
	     export's own, so a footprint is that times this. ]]
	buildingScale = 1.25,

	buildings = {
		Blacksmith = {
			size = Vector3.new(38, 41.6, 28),
			title = "WEAPON SHOP",
			titleColour = Color3.fromRGB(255, 150, 60),
		},
		EggHatchery = {
			size = Vector3.new(38, 40, 28),
			title = "HATCH EGGS",
			titleColour = Color3.fromRGB(255, 214, 72),
		},
		GearStation = {
			size = Vector3.new(38, 42, 28),
			title = "YOUR GEAR",
			titleColour = Color3.fromRGB(110, 200, 255),
		},
		DexHall = {
			size = Vector3.new(38, 19, 28),
			title = "THE DEXES",
			titleColour = Color3.fromRGB(196, 150, 255),
		},
	} :: { [string]: Building },

	--[[
		The Dex Hall's two books, the owner's own models, which stay as they
		are whatever hall they sit on (2026-11-04: "dont remake the book on the
		roof and the book stands"). The hall itself is in
		`Config/PalaceBuildings`, and these numbers are its flat roof deck and
		its two pads, measured off its export. `turn` is the half-turn the
		books need, modelled facing -Z where a building faces +Z.
	]]
	dex = {
		turn = math.pi,
		hall = { across = 38, deep = 28, ridge = 19 },
		--[[ `seat` is how far below the deck the book's foot goes: its box
		     reaches down past its covers to the tip of the ribbon, and the
		     covers' underside is 2.35 studs above the box's bottom. ]]
		roofBook = {
			mesh = "rbxassetid://132359194018769",
			texture = "rbxassetid://75292294805929",
			native = Vector3.new(0.9995, 0.5698, 0.5864),
			across = 16,
			seat = 2.35,
			forward = 0,
		},
		standBook = {
			mesh = "rbxassetid://111083341429927",
			texture = "rbxassetid://105823115455072",
			native = Vector3.new(0.9995, 0.8843, 0.6723),
			across = 5.5,
		},
		pads = { out = 14, forward = 15, top = 1.2, size = Vector3.new(7, 1.2, 6) },
	},

	--[[ The fountain: its basin, studs across, and the outer gold ring round
	     it. A player cannot walk into the basin. ]]
	fountain = 26,
	plaza = 44,

	--[[
		Lobby B's ground and ruins (`Run/LobbyCourtyard`), measured off the
		sheet's plan: the outline the balustrade follows, clockwise from the
		terrace's south-west corner, its corners cut as the plan cuts them.
		The first and last points are the terrace's front corners.
	]]
	courtyard = {
		outline = {
			Vector2.new(-TERRACE_ACROSS / 2, TERRACE_FRONT),
			plan(-86, -36),
			plan(-86, 58),
			plan(-58, 88),
			plan(-14, 88),
			plan(14, 88),
			plan(58, 88),
			plan(86, 58),
			plan(86, -36),
			Vector2.new(TERRACE_ACROSS / 2, TERRACE_FRONT),
		},
		--[[ Which edges have no balustrade: the south stairs' top (5) and the
		     terrace's foot (10, which also has no wall: players walk onto it). ]]
		openEdges = { 5, 10 },
		terraceEdge = 10,
		--[[ How far the ground past the balustrade lies below the floor. ]]
		drop = 18,
		tile = Vector2.new(10, 7.5),
		joint = 0.35,
		--[[ The share of flagstones with moss along a joint, then how many
		     long veins of moss and cracks wander over the floor. ]]
		mossShare = 0.3,
		mossVeins = 16,
		cracks = 14,
		carpetWidth = 7,
		carpetEdge = 0.7,
		--[[ The carpets on the middle line: to the portals and between the
		     leaderboards. ]]
		walkWidth = 9,
		--[[ The fountain's inner gold ring, its lilies and the leaves round it. ]]
		plazaInner = 33,
		lilies = 9,
		hedge = 22,
		arrival = { at = SPAWN, across = 30, inner = 17, walk = 6 },
		southGap = 14,
		balustrade = { bay = 11, tall = 5.2, balusters = 3, broken = 0.2, rubble = 0.08 },
		--[[ Each column stands about as far in from the balustrade as it
		     did before the plan was spread, so it stays at the wall. ]]
		columns = {
			{ at = plan(-86, -34) + Vector2.new(4, 0), tall = 18 },
			{ at = plan(86, -34) - Vector2.new(4, 0), tall = 15 },
			{ at = plan(-86, 2) + Vector2.new(3, 0), tall = 13 },
			{ at = plan(86, 8) - Vector2.new(3, 0), tall = 20 },
			{ at = plan(-86, 44) + Vector2.new(3, 0), tall = 21 },
			{ at = plan(86, 42) - Vector2.new(3, 0), tall = 14 },
			{ at = plan(-56, 88) - Vector2.new(0, 4), tall = 12 },
			{ at = plan(56, 88) - Vector2.new(0, 4), tall = 16 },
			{ at = Vector2.new(-TERRACE_ACROSS / 2 + 4, TERRACE_FRONT + 3.4), tall = 11 },
			{ at = Vector2.new(TERRACE_ACROSS / 2 - 4, TERRACE_FRONT + 3.4), tall = 10 },
		} :: { { at: Vector2, tall: number } },
		ruinArch = {
			at = { plan(-88, -70), plan(88, -70) },
			across = 16,
			tall = 30,
		},
	},

	--[[ Golden hour, with the low sun in the north-east over the portals as
	     the sheet draws it, so the long shadows fall towards the player. A
	     negative latitude is what puts Roblox's sun north. These are the
	     fields of `Balance.Lighting`, for `Arena/Atmosphere`. ]]
	light = {
		--[[ The owner's lighting, set by hand in Studio (2026-11-08): these
		     two ambients, the brightness, the shadow softness, the grade's
		     brightness and the three `glow`, `colour` and `sunRays` effects. ]]
		--[[ Then about a quarter off (owner, 2026-11-08: "take some lighting
		     off of the objects"): was 124/155/184, 157/178/255 and 4. ]]
		ambient = Color3.fromRGB(99, 124, 147),
		outdoorAmbient = Color3.fromRGB(126, 142, 204),
		brightness = 3,
		clockTime = 9.5,
		geographicLatitude = -20,
		sunTint = Color3.fromRGB(255, 186, 128),
		shadowSoftness = 1,
		environmentDiffuse = 0.8,
		environmentSpecular = 0.2,
		bloomIntensity = 0.3,
		bloomSize = 10,
		bloomThreshold = 1.6,
		saturation = 0.08,
		contrast = 0.08,
		gradeBrightness = -0.06,
		gradeTint = Color3.fromRGB(255, 238, 226),
		--[[ On top of the bloom and grade above, in the lobby only. ]]
		glow = { intensity = 1, size = 56, threshold = 2 },
		--[[ 0.5 and 0.5 until 2026-11-15: the floor was nearly white and the
		     colours shouted (the run-through, 2026-11-14). ]]
		colour = {
			saturation = 0.2,
			contrast = 0.15,
			brightness = 0,
			tint = Color3.fromRGB(243, 234, 255),
		},
		sunRays = { intensity = 0.01, spread = 0.1 },
		--[[ Thin and blue: the warm haze this used to be turned the whole sky
		     grey, and its glare whitened the trees towards the sun. ]]
		hazeDensity = 0.1,
		hazeColor = Color3.fromRGB(190, 222, 255),
		hazeDecay = Color3.fromRGB(110, 170, 255),
		hazeGlare = 0,
		haze = 0.6,
	},

	--[[ The sky stays blue, with clouds and a sun (owner, 2026-11-05: "make
	     sure the sky is blue still with clouds and a sun"), over the sheet's
	     warm floor. No moon: at this hour it would hang beside the sun. ]]
	--[[ The picture on the sky is the owner's Toolbox pick (2026-11-08, "Anime
	     Sky", asset 72835926026092). It has its clouds painted on, so the
	     3D ones are off: at this cover they would hide it. ]]
	sky = {
		cloudsShown = false,
		cloudCover = 0.62,
		cloudDensity = 0.72,
		sunSize = 16,
		skybox = {
			SkyboxBk = "rbxassetid://18351376859",
			SkyboxDn = "rbxassetid://18351374919",
			SkyboxFt = "rbxassetid://18351376800",
			SkyboxLf = "rbxassetid://18351376469",
			SkyboxRt = "rbxassetid://18351376457",
			SkyboxUp = "rbxassetid://18351377189",
		},
	},

	--[[ The life in the air (`Fx/LobbyMotes`), each scaled by the device's
	     `ambienceShare`: gold motes drifting over the courtyard, and mist at
	     the foot of each waterfall. The motes' rate grows with the floor they
	     drift over, so the air is as full as it was before the spread. ]]
	motes = {
		rate = 26 * SPREAD * SPREAD,
		lifetime = NumberRange.new(5, 9),
		size = 0.32,
		high = 22,
	},
	mist = { rate = 5, lifetime = NumberRange.new(3, 5), size = 9 },

	--[[ The FARTHEST ADVENTURERS board (`Run/StoryLeaderboard`), south of
	     the spawn at (0, 54) and turned to read north (owner, 2026-11-01:
	     "move the leaderboards to behind the player south of the spawn").
	     A player arrives facing the fountain and the portals, so the boards
	     are behind them and read when they turn round; they used to flank
	     the path north of the fountain, where the walk up to the portals
	     went past their faces. 26 studs back rather than 13, so both sit
	     within view at once instead of 59 degrees out to either side.

	     `face` is studs from the board's foot to where the names are
	     written, and `turn` how far the whole board is turned about Y. With
	     no turn a board reads south, towards the camera, as the layout sheet
	     draws them (owner, 2026-11-05); they read north from 2026-11-01, which
	     showed the camera their backs. ]]
	leaderboard = {
		at = plan(-22, 78),
		turn = 0,
		face = { centre = Vector3.new(0, 10, 0.9), size = Vector2.new(16.8, 11.4) },
	},

	--[[ The DEEPEST DELVERS board (`Run/EndlessLeaderboard`) the other side
	     of the path south from the spawn, so the two still flank a walk and
	     a player sees both at once. Same build, same face, same turn. ]]
	endlessLeaderboard = {
		at = plan(22, 78),
		turn = 0,
		face = { centre = Vector3.new(0, 10, 0.9), size = Vector2.new(16.8, 11.4) },
	},

	--[[ The THIS WEEK'S DELVERS board (`Run/WeeklyTournament`, the weekly
	     Endless tournament, 2026-11-18) past DEEPEST DELVERS on the same
	     side, so the two Endless boards stand together: all time, then this
	     week. Same build, same face, same turn. ]]
	weeklyLeaderboard = {
		at = plan(52, 78),
		turn = 0,
		face = { centre = Vector3.new(0, 10, 0.9), size = Vector2.new(16.8, 11.4) },
	},

	--[[ The look, off the layout sheet's swatches: flat, warm, smooth. ]]
	--[[ The far scenery (`Run/LobbyBackdrop`), after the enemy spotlight
	     loading screens: `cliffs` stepped stone cliffs in a ring `reach` studs
	     from the middle, `tall` high (half as much again behind the portals)
	     and `wide` across, `treesOnTop` trees and pines on each, `falls` of
	     them with a stepped fall cascading down the face, and `shrooms`
	     glowing mushrooms on the forest floor `shroomReach` from the middle.
	     The ruined tower and aqueduct that stood on the highest cliff are
	     gone (owner, 2026-11-05: "get rid of the castle looking object
	     completely"). ]]
	backdrop = {
		cliffs = 18,
		reach = pushed(NumberRange.new(235, 300)),
		tall = NumberRange.new(60, 105),
		wide = NumberRange.new(90, 130),
		--[[ A second ring past the first, bare and taller, that fills the
		     horizon between the near cliffs. ]]
		far = {
			cliffs = 14,
			reach = pushed(NumberRange.new(400, 470)),
			tall = NumberRange.new(90, 140),
			wide = NumberRange.new(150, 210),
		},
		treesOnTop = 4,
		falls = 4,
		shrooms = 28,
		shroomReach = pushed(NumberRange.new(110, 190)),
		stone = Color3.fromRGB(112, 126, 128),
		stoneDark = Color3.fromRGB(88, 100, 104),
		grass = Color3.fromRGB(104, 160, 58),
		mossDark = Color3.fromRGB(62, 112, 44),
		pine = Color3.fromRGB(38, 92, 54),
		pineLight = Color3.fromRGB(58, 120, 66),
		pineTrunk = Color3.fromRGB(96, 66, 44),
		--[[ A fall's width in studs, and how many particles a second stream
		     down each drop and puff as mist off its pool. ]]
		fallWide = NumberRange.new(24, 34),
		fallStreaks = 18,
		fallMist = 6,
		water = Color3.fromRGB(196, 232, 250),
		waterDeep = Color3.fromRGB(150, 210, 238),
		rock = Color3.fromRGB(96, 104, 108),
		foam = Color3.fromRGB(240, 250, 255),
		pool = Color3.fromRGB(70, 176, 196),
		shroomStem = Color3.fromRGB(196, 230, 240),
		shroomGlow = Color3.fromRGB(80, 220, 255),
	},

	--[[ The ground below the balustrade, a deeper green than the lawn ledges
	     were, so the wood round the courtyard reads as the sheet's shaded
	     forest floor rather than a bright field. ]]
	forestFloor = Color3.fromRGB(82, 140, 56),

	colours = {
		marble = {
			Color3.fromRGB(251, 226, 198),
			Color3.fromRGB(247, 219, 190),
			Color3.fromRGB(243, 212, 186),
		},
		joint = Color3.fromRGB(196, 158, 134),
		crack = Color3.fromRGB(176, 136, 124),
		moss = Color3.fromRGB(134, 176, 44),
		mossDark = Color3.fromRGB(110, 156, 44),
		stone = Color3.fromRGB(246, 226, 200),
		stoneShade = Color3.fromRGB(214, 186, 164),
		carpet = Color3.fromRGB(232, 62, 70),
		lily = Color3.fromRGB(248, 121, 152),
		grass = Color3.fromRGB(104, 176, 66),
		cliff = Color3.fromRGB(142, 112, 92),
		cliffDark = Color3.fromRGB(112, 88, 76),
		rock = Color3.fromRGB(152, 158, 168),
		rockLight = Color3.fromRGB(182, 188, 196),
		trunk = Color3.fromRGB(130, 86, 54),
		leaves = {
			Color3.fromRGB(72, 172, 62),
			Color3.fromRGB(98, 196, 74),
			Color3.fromRGB(58, 150, 54),
		},
		wood = Color3.fromRGB(176, 116, 68),
		woodDark = Color3.fromRGB(118, 74, 44),
		water = Color3.fromRGB(72, 186, 205),
		foam = Color3.fromRGB(236, 248, 255),
		gold = Color3.fromRGB(252, 190, 36),
		glass = Color3.fromRGB(160, 216, 255),
		flowers = {
			Color3.fromRGB(250, 96, 120),
			Color3.fromRGB(255, 214, 72),
			Color3.fromRGB(176, 120, 250),
			Color3.fromRGB(255, 255, 255),
		},
		mushroom = Color3.fromRGB(226, 60, 56),
		text = Color3.fromRGB(255, 244, 214),
	},

	--[[ The forest round the clearing: cliffs and trees every `ringSpacing`
	     studs, waterfalls at the four corners, and a scatter of trees,
	     bushes, boulders, flowers and mushrooms on the lawn, one per
	     `scatterCell` studs square (`scatterFill` of the cells filled),
	     each kind as likely as its weight. ]]
	ringSpacing = 16,
	waterfalls = {
		plan(-102, -40),
		plan(102, -40),
		plan(-90, 84),
		plan(90, 84),
	},
	--[[ All of it past the balustrade now (the sheet's floor is open marble):
	     chunky green trees and bushes, a few boulders. ]]
	scatter = {
		Tree = 9,
		Bush = 4,
		Boulder = 2,
		Flowers = 4,
		Mushroom = 2,
	} :: { [string]: number },
	scatterCell = 10,
	scatterFill = 0.9,

	--[[ The eggs and weapon crates out in the open, as Tap Simulator Reborn
	     stands its eggs (owner, 2026-10-27): smooth models on round wooden
	     platforms (`Run/Lobby` `standOut`), with their name and price above.
	     `at` is in studs from the station's centre. None stands now: the
	     layout sheet leaves the floor open and carries the eggs on the Hatch
	     Eggs' roof. An entry here puts one back. ]]
	stands = {} :: { [string]: { { kind: string, key: string, at: Vector2 } } },
	--[[ A stand's platform, studs across. ]]
	standSize = 10,
}

--[[
	Where the portals stand, shared by the lobby's builder (`Run/Lobby`), its
	specs and the Studio bots, so the sums are written once. The areas'
	arches fill the rows in order, `perRow` to a row, front row west to
	east, then the back, each row centred on the carpet however many it
	holds; a portal with an `aside` stands where that says, in no row.
]]
local function inRows(): number
	local count = 0
	for _, portal in Lobby.portals do
		if not portal.aside then
			count += 1
		end
	end
	return count
end

--[[ Which row arch `index` stands in, 1 the front and 2 the back, and its
     place along it, counted west to east; 0, 0 for a portal set aside. ]]
function Lobby.slotOf(index: number): (number, number)
	if Lobby.portals[index].aside then
		return 0, 0
	end
	local count = 0
	for k = 1, index do
		if not Lobby.portals[k].aside then
			count += 1
		end
	end
	return math.ceil(count / PER_ROW), (count - 1) % PER_ROW + 1
end

--[[ How many rows of arches there are. ]]
function Lobby.rows(): number
	return math.ceil(inRows() / PER_ROW)
end

--[[ How many arches stand in row `row`. ]]
function Lobby.rowCount(row: number): number
	return math.clamp(inRows() - (row - 1) * PER_ROW, 0, PER_ROW)
end

--[[ The centre of row `row`'s ledge, and how high its top stands. ]]
function Lobby.rowCentre(row: number): (Vector2, number)
	return TERRACE - Vector2.new(0, (row - 1) * ROW_DEPTH), Lobby.ledge + (row - 1) * Lobby.rowRise
end

--[[ The middle of arch `index`'s foot, in the lobby's plan. ]]
function Lobby.archAt(index: number): Vector2
	local aside = Lobby.portals[index].aside
	if aside then
		return aside.at
	end
	local row, column = Lobby.slotOf(index)
	local centre = Lobby.rowCentre(row)
	return centre + Vector2.new((column - (Lobby.rowCount(row) + 1) / 2) * ARCH_SPACING, 0)
end

--[[ How high above the lawn arch `index`'s foot stands: its row's ledge, or
     the courtyard floor for one set aside. ]]
function Lobby.archFoot(index: number): number
	local row = Lobby.slotOf(index)
	if row == 0 then
		return 0
	end
	local _, height = Lobby.rowCentre(row)
	return height
end

--[[ How far arch `index` is turned from facing south, radians about Y. ]]
function Lobby.archTurn(index: number): number
	local aside = Lobby.portals[index].aside
	return if aside then aside.turn else 0
end

--[[ Where arch `index`'s mouth is: `mouthAhead` in front of it, whichever
     way it is turned. ]]
function Lobby.mouthAt(index: number): Vector2
	local turn = Lobby.archTurn(index)
	return Lobby.archAt(index) + Vector2.new(math.sin(turn), math.cos(turn)) * Lobby.mouthAhead
end

return table.freeze(Lobby)
