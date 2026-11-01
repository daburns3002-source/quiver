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
	in the blocky font. The one exception is the Dex Hall's two books
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
}

--[[ A station's building: a cottage `size` studs (walls `size.Y` tall),
     its roof `rise` studs above the walls, and its colours; `sign` is the
     words on the board over its door. `chimney` adds a stone chimney,
     `columns` a row of pillars along its front. What it is for shows three
     ways (owner, 2026-10-27: "you still have to have some attributes to the
     gear station, blacksmith, and egg hatchery that lets players know what
     they are"): `title`, big words floating over it in `titleColour`, as
     the reference clip floats "Eggs" over its eggs; `emblem`, a giant sign
     of its trade on its ridge ("egg", "sword" or "shield"); and its props
     out front, by `emblem` too (`Run/Lobby` `building`). ]]
export type Building = {
	size: Vector3,
	rise: number,
	walls: Color3,
	roof: Color3,
	sign: string,
	chimney: boolean?,
	columns: boolean?,
	title: string?,
	titleColour: Color3?,
	emblem: string?,
}

--[[
	Which way a building at `at` is turned: toward the middle of the
	clearing (owner, 2026-11-01), as radians about Y.

	A building is modelled facing +Z, which `CFrame.Angles(0, y, 0)` sends
	to (sin y, cos y), so the turn that points its front at the origin is
	the bearing of -`at`. One function because three places need to agree
	about it -- the builder, the stands it puts out front, and the spec
	that measures the footprints -- and a building facing a way its own
	eggs do not is the bug this exists to make impossible.

	A station standing dead in the middle has no bearing to face, and is
	left unturned.
]]
local function facingMiddle(at: Vector2): number
	if at.Magnitude < 1e-3 then
		return 0
	end
	return math.atan2(-at.X, -at.Y)
end

--[[ Where a point `offset` studs from a building's own middle lands once
     that building is turned to face the middle: its local +Z is the way it
     faces, its +X to that way's right. The egg and crate stands are placed
     with this, so they stay out front whichever corner their station is
     on. ]]
local function turnedOffset(at: Vector2, offset: Vector2): Vector2
	local yaw = facingMiddle(at)
	local s, c = math.sin(yaw), math.cos(yaw)
	return Vector2.new(offset.X * c + offset.Y * s, -offset.X * s + offset.Y * c)
end

local GREEN = Color3.fromRGB(80, 230, 70)
local PURPLE = Color3.fromRGB(140, 60, 235)
local CYAN = Color3.fromRGB(70, 220, 224)

local Lobby = {
	--[[ Which way a building faces, and where a thing placed in front of
	     it lands once it is turned. See `facingMiddle` above. ]]
	facing = facingMiddle,
	turnedOffset = turnedOffset,

	--[[ Where the lobby's centre stands in the world: well away from the
	     arena at the origin. ]]
	origin = Vector3.new(0, 0, 1000),
	--[[ The walkable clearing, studs across (X) and deep (Z). ]]
	size = Vector2.new(220, 192),
	--[[ Where a player appears: south of the fountain. ]]
	spawn = Vector2.new(-8, 50),

	--[[ The portal terraces across the north edge: two rows of arches
	     (owner, 2026-10-25: "make sure there are 2 rows of portals"), each
	     on a grass ledge with a cliff face and wide wooden steps up its
	     front. `terrace` is the front row's centre; the back row stands
	     `rowDepth` studs behind it and `rowRise` higher. `ledge` is the
	     front row's height above the lawn. ]]
	terrace = Vector2.new(0, -60),
	rowDepth = 19.2,
	rowRise = 3,
	ledge = 2.4,
	--[[ Six to a row since 2026-10-27, so the eleventh arch (Endless) joins
	     the areas without opening a third row — the owner's "make sure there
	     are 2 rows of portals" stands. ]]
	perRow = 6,
	archSpacing = 18,
	--[[ The arches, front row west to east, then the back row: the two
	     areas built so far, then eight locked, and Endless last. ]]
	portals = {
		{
			name = "Mossy Glade",
			--[[ Mossy Glade 1-1..1-10 (owner, 2026-10-26), each opened by
			     beating the one before (`Util/LevelUnlocks`). ]]
			levels = { 7, 8, 9, 10, 11, 12, 13, 14, 15, 16 },
			tint = GREEN,
		},
		{ name = "Thornwood", levels = { 4 }, tint = PURPLE },
		{ name = "Drowned Village" },
		{ name = "Bogheart Caverns" },
		{ name = "Windswept Cliffs" },
		{ name = "Frostpeak Pass" },
		{ name = "Ember Mines" },
		{ name = "Obsidian Forge" },
		{ name = "Shattered Kingdom" },
		{ name = "Void Rift" },
		--[[ Endless (`docs/ENDLESS.md`, `Balance.endlessStage`): one
		     "level", opened by beating Mossy Glade 1-10 (`requires`). Last
		     of the arches so the ten areas keep their order in the rows. ]]
		--[[ Open to everyone while the game is in playtest (owner,
		     2026-10-28: "since its still in playtest phase, that should
		     just be unlocked for now"). Before launch this takes
		     `requires = "1-10"` back: with no cards and no gear Endless
		     is a death at floor 6 (`docs/ENDLESS.md`). ]]
		{ name = "Endless", levels = { 17 }, tint = CYAN },
	} :: { Portal },
	--[[ Studs from an active arch's mouth a player must come within for its
	     screen to open (`UI/PortalScreen`), and how much further the server
	     still grants START from, for the time the press takes to arrive. ]]
	portalReach = 7,
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
	--[[ An arch's ring, studs across its outside, and how high its centre
	     stands above the ledge. ]]
	archSize = 14,
	archRise = 8,

	--[[
		The stations, one to each corner of the clearing (owner,
		2026-11-01: "every building should be either northwest,
		northeast, southwest, or southeast ... the dex hall is in the
		southwest, the gear station is in the northwest, the blacksmith
		is in the northeast, and the egg hatchery is in the southeast,
		and then the portals are at the north").

		North is -Z and west is -X, so a corner is a sign on each. They
		were strung along the east side before, which left the west half
		of the lawn empty and the player walking a line rather than a
		circuit; a corner each puts the fountain in the middle of four
		and the portals beyond it.

		The two northern ones stand clear of the portal terraces, whose
		front ledge reaches z = -50.4: turned to face the middle they
		reach z = -43, which leaves seven studs of lawn between.

		The spawn's fountain keeps its old name `SpawnCampfire`, for the
		screens that look it up. `Lobby.spec` keeps every footprint apart,
		measured as each one is actually turned.
	]]
	stations = {
		{ piece = "GearStation", at = Vector2.new(-66, -24) },
		{ piece = "Blacksmith", at = Vector2.new(66, -24) },
		{ piece = "DexHall", at = Vector2.new(-66, 36) },
		{ piece = "EggHatchery", at = Vector2.new(66, 36) },
		{ piece = "SpawnCampfire", at = Vector2.new(-8, 28) },
	} :: { Placed },

	buildings = {
		Blacksmith = {
			size = Vector3.new(32, 13, 22),
			rise = 9,
			walls = Color3.fromRGB(186, 178, 168),
			roof = Color3.fromRGB(204, 70, 58),
			sign = "BLACKSMITH",
			chimney = true,
			title = "WEAPON SHOP",
			titleColour = Color3.fromRGB(255, 150, 60),
			emblem = "sword",
		},
		EggHatchery = {
			size = Vector3.new(28, 12, 20),
			rise = 9,
			walls = Color3.fromRGB(248, 236, 208),
			roof = Color3.fromRGB(236, 120, 170),
			sign = "EGG HATCHERY",
			title = "HATCH EGGS",
			titleColour = Color3.fromRGB(255, 214, 72),
			emblem = "egg",
		},
		GearStation = {
			size = Vector3.new(32, 12, 22),
			rise = 9,
			walls = Color3.fromRGB(248, 236, 208),
			roof = Color3.fromRGB(66, 124, 214),
			sign = "GEAR STATION",
			title = "YOUR GEAR",
			titleColour = Color3.fromRGB(110, 200, 255),
			emblem = "shield",
		},
		--[[ Colours off the owner's sheet (2026-11-01, front and back): a
		     vivid violet roof with gold corner caps, brown timber over warm
		     cream panels, and a pale stone base. The old roof was a muted
		     lilac and the panels nearly white. ]]
		--[[ The import's own size, so the spacing is measured against
		     what actually stands there (`dex.hall`: 38 across, 28 deep,
		     its ridge 14.28 up). ]]
		DexHall = {
			size = Vector3.new(38, 16.3, 28),
			rise = 10,
			walls = Color3.fromRGB(238, 226, 196),
			roof = Color3.fromRGB(124, 44, 230),
			sign = "DEX HALL",
			columns = true,
		},
	} :: { [string]: Building },

	--[[
		The Dex Hall, which is the owner's own model rather than parts
		(2026-11-01: "ok i imported the dex hall i want you to use", and
		"put the book on top and the book stands on the sides where they
		belong"). Three imports: the hall itself, the open book that sits
		astride its roof, and the stand that goes on each of the two stone
		pads out front -- the hall mesh carries those pads, its porch
		columns, its wall lanterns, its steps, its carpet and its shelves,
		so nothing here draws them again.

		Everything below is measured off the hall mesh itself, by raycast
		against its own collision shape at the size it is drawn
		(`across` = 38): the ridge stands 14.28 studs over its floor, and
		the two pads are 0.9 studs high, 7 wide, centred 13 studs either
		side of the middle and 11 studs forward.

		The hall's front faces -Z as it was modelled, and a lobby building
		faces south, so the whole assembly is turned by `turn` -- and
		because the books are placed in the hall's own frame before that
		turn, they come round with it.
	]]
	--[[
		The Dex Hall, built from Roblox parts (owner, 2026-11-01: "the dex
		hall needs to be remade, use the book stands and the book on the
		top but make a whole new building", then "i want you to just use
		parts already in roblox").

		The import it replaces could never be textured -- it came out of
		Tripo with no UVs at all -- and the generated stand-in texture was
		never the sheet. Parts have no such problem: every colour here is
		set outright, so the hall is the sheet's by construction rather
		than by a generator's guess. It is also how every other station in
		this lobby is built, and it lives in the repo rather than in the
		place file, which a model left in the Workspace would not.

		What stays imported are the two the owner modelled: the open book
		on the roof and the stand on each pad.

		The hall is built facing +Z, like every other station, and the
		whole thing is then turned to face the middle (`facing`). `turn`
		is the extra half-turn the two book imports need on top of that,
		since they were modelled facing -Z.
	]]
	dex = {
		turn = math.pi,
		--[[ `across` and `deep` are the plinth's footprint; `ridge` is the
		     flat top of the roof over the lawn, which the book rests on. ]]
		hall = { across = 38, deep = 28, ridge = 16.3 },
		--[[
			The open book on the roof.

			`seat` is how far below the ridge its foot goes. Its own
			bounding box reaches well below its covers -- down to the tip
			of the ribbon -- so sitting that box on the roof leaves the
			book hanging in the air above it, which is what it did at
			first. Measured instead: the covers' underside is 2.35 studs
			above the box's bottom where they meet the flat of the roof,
			so that is the drop that puts them on it.
		]]
		roofBook = {
			mesh = "rbxassetid://132359194018769",
			texture = "rbxassetid://75292294805929",
			native = Vector3.new(0.9995, 0.5698, 0.5864),
			across = 16,
			seat = 2.35,
			--[[ Forward of the middle, over the gable. ]]
			forward = 4,
		},
		--[[ The stand on each pad. ]]
		standBook = {
			mesh = "rbxassetid://111083341429927",
			texture = "rbxassetid://105823115455072",
			native = Vector3.new(0.9995, 0.8843, 0.6723),
			across = 5.5,
		},
		--[[ The two stone pads the stands go on, built with the hall:
		     outside the steps and a little forward of its front. ]]
		pads = { out = 14, forward = 15, top = 1.2, size = Vector3.new(7, 1.2, 6) },
		--[[
			Its nameboard, on the gable over the entrance.

			It hung out in front of the porch at first, as the other
			stations' do, and at this building's width that put a board
			twenty studs across squarely over the whole front: the
			columns, the opening and the lanterns all disappeared behind
			it. On the gable it reads from the lawn and leaves the
			building visible, which is what the sheet shows.
		]]
		sign = { height = 10.7, forward = 11.15, across = 11.5, tall = 2 },
		--[[ The lanterns either side of the porch, and the light each
		     casts on the lawn. ]]
		lanterns = { out = 9.55, height = 6.5, forward = 12, range = 16, brightness = 1.2 },
		--[[ The sheet's palette, set on the parts outright. ]]
		colours = {
			roof = Color3.fromRGB(140, 40, 220),
			gold = Color3.fromRGB(255, 215, 0),
			timber = Color3.fromRGB(130, 80, 40),
			panel = Color3.fromRGB(255, 248, 220),
			stone = Color3.fromRGB(240, 235, 205),
			column = Color3.fromRGB(255, 255, 255),
			red = Color3.fromRGB(220, 30, 40),
			lantern = Color3.fromRGB(255, 200, 50),
			iron = Color3.fromRGB(30, 30, 30),
			books = {
				Color3.fromRGB(138, 43, 226),
				Color3.fromRGB(220, 30, 40),
				Color3.fromRGB(255, 215, 0),
			},
		},
	},

	--[[ The fountain at the spawn: its basin, studs across, and the paved
	     ring round it. A player cannot walk into the basin. ]]
	fountain = 16,
	plaza = 40,

	--[[ The FARTHEST ADVENTURERS board (`Run/StoryLeaderboard`) beside the
	     path north of the fountain: its face, studs from the board's foot,
	     where the names are written. ]]
	leaderboard = {
		at = Vector2.new(-36, -4),
		face = { centre = Vector3.new(0, 10, 0.9), size = Vector2.new(16.8, 11.4) },
	},

	--[[ The DEEPEST DELVERS board (`Run/EndlessLeaderboard`) facing it
	     across the path, so the two boards flank the walk up to the
	     portals. Same build and same face as the story's. ]]
	endlessLeaderboard = {
		at = Vector2.new(30, -4),
		face = { centre = Vector3.new(0, 10, 0.9), size = Vector2.new(16.8, 11.4) },
	},

	--[[ The sandy paths, as runs of points: the spawn up to the portals, and
	     out to each station. ]]
	paths = {
		{
			Vector2.new(-8, 92),
			Vector2.new(-8, 48),
			Vector2.new(-4, 0),
			Vector2.new(0, -36),
			Vector2.new(0, -48),
		},
		{ Vector2.new(-16, 16), Vector2.new(-40, 0), Vector2.new(-62, 2) },
		{ Vector2.new(0, 8), Vector2.new(24, -12), Vector2.new(50, -12) },
		{ Vector2.new(4, 20), Vector2.new(40, 20), Vector2.new(78, 24) },
		{ Vector2.new(4, 28), Vector2.new(32, 44), Vector2.new(44, 30) },
	} :: { { Vector2 } },
	pathWidth = 11,

	--[[ The look, after the owner's reference clip: flat, bright, smooth. ]]
	colours = {
		grass = Color3.fromRGB(104, 206, 72),
		grassDark = Color3.fromRGB(80, 178, 58),
		sand = Color3.fromRGB(238, 182, 118),
		sandEdge = Color3.fromRGB(198, 130, 76),
		cliff = Color3.fromRGB(204, 116, 70),
		cliffDark = Color3.fromRGB(168, 90, 56),
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
		water = Color3.fromRGB(78, 178, 244),
		foam = Color3.fromRGB(236, 248, 255),
		gold = Color3.fromRGB(250, 202, 60),
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
		Vector2.new(-96, -76),
		Vector2.new(96, -76),
		Vector2.new(-100, 72),
		Vector2.new(100, 72),
	},
	scatter = {
		Tree = 3,
		Bush = 4,
		Boulder = 2,
		Flowers = 4,
		Mushroom = 2,
	} :: { [string]: number },
	scatterCell = 14,
	scatterFill = 0.6,

	--[[ The eggs and weapon crates out in the open, as Tap Simulator Reborn
	     stands its eggs (owner, 2026-10-27): smooth models on round wooden
	     platforms (`Run/Lobby` `standOut`), with their name and price above.
	     `at` is in studs from the station's centre. ]]
	stands = {
		EggHatchery = {
			{ kind = "egg", key = "MossyEgg", at = Vector2.new(-6, 21) },
			{ kind = "egg", key = "ThornwoodEgg", at = Vector2.new(12, 21) },
		},
		Blacksmith = {
			{ kind = "crate", key = "MossyGlade", at = Vector2.new(-14, 22) },
			{ kind = "crate", key = "Thornwood", at = Vector2.new(4, 22) },
		},
	} :: { [string]: { { kind: string, key: string, at: Vector2 } } },
	--[[ A stand's platform, studs across. ]]
	standSize = 10,
}

return table.freeze(Lobby)
