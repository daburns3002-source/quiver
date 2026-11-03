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
	--[[
		The owner's imported lobby models (2026-11-01). `native` is each
		import's own size, kept here so the placing maths never waits on a
		fetch; everything is scaled off it.
	]]
	--[[ The blocky tree, which replaced the lawn's built trunk and blobs
	     ("use the tree import and replace the existing trees in the game
	     with it"). `tall` is the studs a tree of `grow` 1 stands, matched
	     to what the built one was so the scatter's spacing still holds. ]]
	treeModel = {
		mesh = "rbxassetid://139262265934696",
		texture = "rbxassetid://93690388231604",
		native = Vector3.new(2.54, 4.6, 2.49),
		tall = 14,
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
	--[[ Each area's arch, by portal index, as the owner imports them. Only
	     the Mossy Glade's exists so far; Thornwood's and the Drowned
	     Village's are modelled and come tomorrow, and keep the built stone
	     ring until they do. ]]
	archModels = {
		[1] = {
			mesh = "rbxassetid://89518626870205",
			texture = "rbxassetid://122345112819768",
			native = Vector3.new(0.85, 1, 0.59),
		},
	} :: { [number]: { mesh: string, texture: string, native: Vector3 } },
	--[[ From this portal on there is no arch of its own and none coming
	     soon, so each stands as a black silhouette of the first area's
	     (owner, 2026-11-01: "replace every portal past 4 with a silhouette
	     of the arena 1 portal until portals are made for them"). Give a
	     portal its own entry in `archModels` and it stops being one. ]]
	archSilhouetteFrom = 5,
	archSilhouette = Color3.fromRGB(18, 16, 24),
	--[[ How tall an imported arch stands above its ledge, and how far it is
	     turned about Y. The built ring's top sat 14 up, so 15 keeps the
	     rows reading the same from the lawn. ]]
	archTall = 15,
	archTurn = 0,

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
		--[[ Rebuilt from its sheet on 2026-11-02 (`Config/BlacksmithDesign`,
		     where every measurement is written down): the sheet's shop is
		     a stone forge open to the front under a chimney stack, not the
		     red-roofed cottage with a sword on its ridge that stood here.
		     `size` is what that build comes to -- the wall's width, its
		     height, and the depth of the apron it stands on -- so the
		     spacing between stations is measured against what is actually
		     there. It carries no `rise`, `roof`, `chimney` or `emblem`:
		     nothing of the cottage runs for it. ]]
		Blacksmith = {
			size = Vector3.new(32, 17, 22),
			rise = 0,
			walls = Color3.fromRGB(150, 152, 158),
			roof = Color3.fromRGB(150, 152, 158),
			sign = "BLACKSMITH",
			title = "WEAPON SHOP",
			titleColour = Color3.fromRGB(255, 150, 60),
		},
		--[[ Rebuilt from its sheet on 2026-11-02
		     (`Config/HatcheryDesign`): an open timber pavilion under a
		     flat stone deck, with the three eggs in one round nest ring
		     under it. `size` is the pavilion's width, the top of its deck
		     and its depth. As with the Blacksmith, no `rise`, `roof` or
		     `emblem`. ]]
		EggHatchery = {
			size = Vector3.new(30, 24.6, 14),
			rise = 0,
			walls = Color3.fromRGB(150, 96, 52),
			roof = Color3.fromRGB(176, 174, 166),
			sign = "EGG HATCHERY",
			title = "HATCH EGGS",
			titleColour = Color3.fromRGB(255, 214, 72),
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
		--[[ Its size is what `dex.hall` builds, so the spacing between
		     stations is measured against what actually stands there. It
		     carries **no `sign`**: every other station hangs a wooden
		     board, and on this one it covered the gable whatever size it
		     was (owner, 2026-11-01: "i want the sign to disappear
		     completely and the text to be above like the rest of the
		     buildings"). Its name floats over it instead, as theirs do.
		     Its walls and roof colours live in `dex.colours`; these two
		     are here only because every building has them. ]]
		DexHall = {
			size = Vector3.new(38, 13.71, 28),
			rise = 10,
			walls = Color3.fromRGB(238, 226, 196),
			roof = Color3.fromRGB(124, 44, 230),
			sign = "",
			title = "THE DEXES",
			titleColour = Color3.fromRGB(196, 150, 255),
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
		--[[ `ridge` is the flat top of the roof over the lawn, which the
		     book rests on. It came down from 16.3 with the pitch: the
		     sheet's roof is long and low, and an 18.6 degree slope made
		     a steep A of it (owner, 2026-11-01: "gable and roof"). ]]
		--[[ `ridge` is where a slope of this pitch gets to over the
		     middle, which is what the roof's cap is set to and what the
		     book rests on; `Run/Lobby` works it out from `pitch` and
		     uses its own, so this is the declared copy the spec checks
		     the building's height against. ]]
		hall = { across = 38, deep = 28, ridge = 13.71, pitch = 12 },
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
		--[[ The lanterns either side of the porch, and the light each
		     casts on the lawn. ]]
		--[[ Turned down from 16 studs at 1.2 (owner, 2026-11-01: "the
		     lighting is too strong"): at that strength the pair washed
		     the whole front of the building out and the glass read as a
		     flat yellow blob rather than a lamp. ]]
		lanterns = { out = 9.55, height = 6.5, forward = 12, range = 8, brightness = 0.32 },
		--[[ The sheet's palette, set on the parts outright. ]]
		colours = {
			roof = Color3.fromRGB(140, 40, 220),
			gold = Color3.fromRGB(255, 215, 0),
			timber = Color3.fromRGB(130, 80, 40),
			panel = Color3.fromRGB(255, 248, 220),
			stone = Color3.fromRGB(240, 235, 205),
			column = Color3.fromRGB(255, 255, 255),
			red = Color3.fromRGB(220, 30, 40),
			--[[ Warmer and less blinding than the 255,200,50 it was. ]]
			lantern = Color3.fromRGB(255, 186, 96),
			iron = Color3.fromRGB(30, 30, 30),
			--[[ The windows behind the shelves. ]]
			glass = Color3.fromRGB(176, 222, 255),
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

	--[[ The FARTHEST ADVENTURERS board (`Run/StoryLeaderboard`), south of
	     the spawn at (-8, 50) and turned to read north (owner, 2026-11-01:
	     "move the leaderboards to behind the player south of the spawn").
	     A player arrives facing the fountain and the portals, so the boards
	     are behind them and read when they turn round; they used to flank
	     the path north of the fountain, where the walk up to the portals
	     went past their faces. 26 studs back rather than 13, so both sit
	     within view at once instead of 59 degrees out to either side.

	     `face` is studs from the board's foot to where the names are
	     written, and `turn` how far the whole board is turned about Y. With
	     no turn a board reads south, which is what both did before. ]]
	leaderboard = {
		at = Vector2.new(-28, 76),
		turn = math.pi,
		face = { centre = Vector3.new(0, 10, 0.9), size = Vector2.new(16.8, 11.4) },
	},

	--[[ The DEEPEST DELVERS board (`Run/EndlessLeaderboard`) the other side
	     of the path south from the spawn, so the two still flank a walk and
	     a player sees both at once. Same build, same face, same turn. ]]
	endlessLeaderboard = {
		at = Vector2.new(12, 76),
		turn = math.pi,
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
	--[[ Trees weigh more than the rest together now the lawn has a real
	     one to plant (owner, 2026-11-01: "add more around the lobby"): 3
	     of 15 was a tree every few cells, which read as a lawn with a
	     couple of trees on it rather than a clearing in a wood. The cells
	     also fill a little fuller, so the edges thicken without crowding
	     the walk between the stations -- `keep` still clears a radius
	     round every building, stand, arch and board. ]]
	scatter = {
		Tree = 9,
		Bush = 4,
		Boulder = 2,
		Flowers = 4,
		Mushroom = 2,
	} :: { [string]: number },
	--[[ A smaller cell and nearly every one tried, because only about a
	     quarter of tries can land: the paths, the terrace and the ring
	     `keep` round every building, stand, arch and board reserve most
	     of the lawn, and at 14 studs with 0.6 filled that left 37 things
	     scattered over the whole clearing, fifteen of them trees. The
	     space test is unchanged, so nothing gets any closer to a building
	     or a path than before -- there are simply more places tried. ]]
	scatterCell = 10,
	scatterFill = 0.9,

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
