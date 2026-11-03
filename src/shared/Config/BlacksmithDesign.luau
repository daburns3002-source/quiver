--!strict
--[[
	The Blacksmith, measured off its reference sheet (owner's standing
	rule, CLAUDE.md 13: "if it does not match 1 to 1 then redo it").

	Its sheet is the BLACKSMITH panel of
	`assets/concepts/blocky/lobby/ref_main.png`, with
	`assets/concepts/blocky/lobby/ref_blacksmith.png` and
	`ref3_blacksmith.png` as closeups of the same build. All three were
	drawn by Codex and approved by the owner.

	Read again on 2026-11-02 at the sheet's own resolution, after the first
	rebuild was looked at lit in Studio beside it (owner: "these need to be
	redone heavily, if it is not 1 to 1 exactly try again"). What the first
	pass got wrong, and this one carries:

	  * The shop is an **L of stone**: the back wall, and a side wall down
	    the left with a **round-headed arch** cut through it. The first pass
	    had one flat wall and two stubs, which read as a fence.
	  * There is **one big anvil** out on the floor, not a matched pair.
	    The sheet's single anvil is the thing the eye lands on.
	  * The stones are laid in **three close greys picked at random**. Two
	    alternating greys read as a checkerboard from the lobby's own
	    distance, which is exactly what the first build did.
	  * The nameboard is a **dark board with white letters** in a timber
	    frame, big and high on the wall.
	  * The chimney is a **stepped stack** of three blocks narrowing as it
	    rises, not one plain column.
	  * The hearth has a **stone hood** over its arch and a raised stone
	    base under it.
	  * A **red cloth** hangs in the side arch and a **lantern** burns on
	    the left pillar, which is what lights that corner on the sheet.

	Every measurement below is read off the panel as a fraction of **the
	back wall's width** -- 700 px on the panel enlarged four times -- and
	then set against a width of 32 studs:

	    back wall width         700 px   1.00   ->  32      `across`
	    depth, front to back    480 px   0.69   ->  22      `deep`
	    wall height             340 px   0.49   ->  20 *    `wallTall`
	    wall thickness           35 px   0.05   ->  1.8     `wallThick`
	    chimney, front face     170 px   0.24   ->  8       `chimney.across`
	    chimney over the wall   285 px   0.41   ->  13      `chimney.rise`
	    sign board width        320 px   0.46   ->  15      `sign.across`
	    sign board height       125 px   0.18   ->  5.6     `sign.tall`
	    hearth arch width       190 px   0.27   ->  8.6     `hearth.across`
	    hearth opening height   100 px   0.14   ->  4.6     `hearth.tall`
	    hearth hood height       70 px   0.10   ->  3.2     `hearth.hood`
	    side arch width         150 px   0.21   ->  7       `arch.across`
	    side wall, how far out  350 px   0.50   ->  16      `side.long`
	    side arch height        230 px   0.33   ->  10.5    `arch.tall`
	    anvil length            190 px   0.27   ->  8       `anvil.long`
	    anvil height            120 px   0.17   ->  5.4     `anvil.tall`
	    bench length            150 px   0.21   ->  7       `bench.long`
	    banner cloth length     210 px   0.30   ->  9.6     `banner.long`

	  * the wall is built 20 studs high rather than the 15.7 its reading
	    gives. The panel is drawn in isometric, which foreshortens
	    everything vertical: taken flat the shop came out in game as a low
	    garden wall with the board nearly off the top of it, where the
	    sheet's wall is the tallest thing in the shop but the chimney. 20
	    is what puts the board back where the sheet hangs it, clear above
	    the hearth's hood.

	The hearth and the chimney over it are on the viewer's RIGHT, which is
	the building's own **positive X**: a station faces +Z, you look at it
	down -Z, and its +X is then the right of the screen -- checked in
	Studio on 2026-11-02 against the fire's own glow, because the first
	rebuild had it the other way round and came out mirrored. Two of the
	three sheets put the fire and the stack on the right, with the arch,
	the racks and the board to their left, so every `side` below reads
	that way.

	Offsets are in the building's own frame: +Z is the way it faces (toward
	the middle of the clearing, `Config/Lobby.facing`), +X to that way's
	right, and y is height above the lawn.
]]

local BlacksmithDesign = {
	--[[ The shop's footprint. `Config/Lobby.buildings.Blacksmith` declares
	     the same two, and `Lobby.spec` holds them equal: the spacing
	     between stations is measured off that declaration. ]]
	across = 32,
	deep = 22,

	--[[ The stonework: how high the walls stand, how thick they are, and
	     how many courses and columns of blocks the back wall is laid in. ]]
	wallTall = 20,
	wallThick = 1.8,
	courses = 6,
	columns = 11,
	joint = 0.2,
	--[[ The shelf of stone capping a wall, lapped out past its face. ]]
	cap = { tall = 1.3, out = 1.1 },

	--[[ The side wall down the LEFT (+X), which is what turns one wall
	     into a shop: it runs `long` studs forward of the back wall. ]]
	side = { long = 16 },
	--[[ The round-headed arch cut through that side wall, `forward` studs
	     ahead of the back wall's face. The head is drawn as `steps` courses
	     of stone stepping in over the opening. ]]
	arch = { across = 7, tall = 12, forward = 7.5, steps = 3 },

	--[[ The chimney: a stepped stack behind the hearth, three blocks
	     narrowing as they rise. `back` is how far its own back face stands
	     behind the wall's -- the stack is entirely BEHIND the wall, bitten
	     one stud into it so the two read as one piece of stone. Standing it
	     on the wall line put three studs of chimney inside the shop, in
	     front of the hearth, which from the lobby's own angle hid the fire
	     completely. ]]
	chimney = { across = 8, rise = 13, back = 7.5, side = 8, mouth = 4.2 },

	--[[ The nameboard, high on the back wall, left of the hearth: its
	     size, how far its face stands proud of the stone, and how far its
	     top is below the wall's cap. ]]
	sign = { across = 15, tall = 6, out = 0.9, below = 2.6 },

	--[[ The hearth arch cut into the wall under the chimney: the opening,
	     the stone hood over it, the raised base under it, how far right of
	     the middle it is cut, and the light the fire throws. ]]
	hearth = {
		across = 8.6,
		tall = 6,
		hood = 3.2,
		base = 1.8,
		side = 8,
		range = 22,
		brightness = 0.8,
	},

	--[[ The one anvil out on the floor, on its dark stone block.
	     `forward` is studs in front of the wall's face. ]]
	anvil = { long = 8, tall = 5.4, wide = 3, side = -2, forward = 11 },

	--[[ The two work tables against the back wall, left of the hearth, and
	     the weapon table standing out in front of them. ]]
	bench = { long = 7, tall = 3.4, wide = 2.6, side = -9, forward = 3.4, apart = 8 },
	table_ = { long = 6.4, tall = 3.2, wide = 2.8, side = 2.5, forward = 9 },

	--[[ The A-frame sword rack at the far left, outside the side wall. ]]
	rack = { across = 6, tall = 5.4, blades = 3, blade = 4.4, side = -19, forward = 7 },

	--[[ The blue banner on its pole at the right, and the red cloth
	     hanging in the side arch. ]]
	banner = { long = 9.6, wide = 5, out = 17.5, top = 15, forward = 7 },
	cloth = { long = 7, wide = 4.6, top = 10 },

	--[[ The lantern on the left pillar, which is what lights that corner
	     on the sheet. ]]
	lantern = { tall = 2.6, at = -10.5, forward = 2.2, range = 14, brightness = 0.7 },

	--[[ The paved floor: how far across it reaches, and how big one
	     flagstone is. The sheet runs it out well past the anvil. ]]
	apron = Vector2.new(36, 24),
	flag = 4.5,

	--[[ The sheet's palette, set on the parts outright, as the Dex Hall's
	     is. Nothing here is generated or tinted. The three greys are what
	     every wall stone is picked from. ]]
	colours = {
		stone = Color3.fromRGB(104, 106, 114),
		stoneLight = Color3.fromRGB(126, 128, 136),
		stoneDark = Color3.fromRGB(86, 88, 96),
		timber = Color3.fromRGB(138, 86, 44),
		timberDark = Color3.fromRGB(88, 52, 28),
		board = Color3.fromRGB(34, 30, 28),
		ink = Color3.fromRGB(248, 246, 240),
		floor = Color3.fromRGB(170, 142, 108),
		floorLight = Color3.fromRGB(188, 160, 126),
		floorDark = Color3.fromRGB(150, 122, 92),
		anvil = Color3.fromRGB(72, 80, 96),
		anvilDark = Color3.fromRGB(52, 58, 70),
		steel = Color3.fromRGB(198, 206, 218),
		brick = Color3.fromRGB(150, 92, 72),
		fire = Color3.fromRGB(255, 140, 40),
		ember = Color3.fromRGB(236, 74, 30),
		banner = Color3.fromRGB(48, 92, 176),
		cloth = Color3.fromRGB(186, 54, 40),
		gold = Color3.fromRGB(244, 196, 64),
		lantern = Color3.fromRGB(255, 186, 96),
		iron = Color3.fromRGB(42, 40, 38),
	},
}

return table.freeze(BlacksmithDesign)
