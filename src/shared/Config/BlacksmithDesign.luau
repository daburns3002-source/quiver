--!strict
--[[
	The Blacksmith, measured off its reference sheet (owner's standing
	rule, CLAUDE.md 13: "if it does not match 1 to 1 then redo it").

	Its sheet is the BLACKSMITH panel of
	`assets/concepts/blocky/lobby/ref_main.png`, with
	`assets/concepts/blocky/lobby/ref_blacksmith.png` and
	`ref3_blacksmith.png` as closeups of the same build. All three were
	drawn by Codex and approved by the owner.

	What the sheet actually shows, which the cottage standing here before
	did not:

	  * It is **a stone forge open to the front**, not a plastered cottage
	    with a red gabled roof. One tall back wall of grey blocks, a timber
	    frame post at each end, a flat stone shelf along the top, and no
	    front wall at all.
	  * The **chimney is a stack of stone at the back**, rising half again
	    the wall's height with a dark open mouth -- not a pipe poking out
	    of a roof slope.
	  * The **hearth is an arch cut into the wall**, full of fire, with a
	    brick lip and coals; it is the only light source in the panel and
	    it throws orange over everything near it.
	  * The nameboard is **mounted flat on the wall**, dark-faced in a
	    timber frame, over the weapon racks rather than over a door.
	  * **Two anvils** stand out on the paved apron in front, a workbench
	    and a sword rack stand against the wall, and **a blue banner with
	    a gold emblem** hangs from a cross pole at each end.
	  * There is no giant sword on a ridge: the shop says what it is with
	    its sign, its fire and its racks.

	Every measurement below is read off the sheet as a fraction of **the
	back wall's width** -- 172 px on `ref_main.png` -- and then set against
	a width of 32 studs:

	    back wall width         172 px   1.00   ->  32      `across`
	    depth, front to back    ~120 px  0.69   ->  22      `deep`
	    wall height              94 px   0.55   ->  17      `wallTall`
	    wall thickness           11 px   0.06   ->  2       `wallThick`
	    chimney, front face      50 px   0.29   ->  9       `chimney.across`
	    chimney over the wall    53 px   0.31   ->  10      `chimney.rise`
	    sign board width        100 px   0.58   ->  18      `sign.across`
	    sign board height        34 px   0.20   ->  6       `sign.tall`
	    hearth arch width        72 px   0.42   ->  12 *    `hearth.across`
	    hearth opening height    40 px   0.23   ->  7.5     `hearth.tall`
	    anvil length             54 px   0.31   ->  7 *     `anvil.long`
	    anvil height             36 px   0.21   ->  4.5 *   `anvil.tall`
	    sword rack width         37 px   0.21   ->  7       `rack.across`
	    banner cloth length      60 px   0.35   ->  11      `banner.long`

	  * the arch is cut 12 wide and 7.5 from the middle rather than 13
	    wide and 10 out, so a pier of stone is left between it and the
	    end of the wall: at the sheet's own reading the opening ran half
	    a stud PAST the wall's corner and the forge opened onto nothing
	    (`Lobby.spec`, "the hearth is cut through the end of the wall").

	  * the two anvils sit at the front of the panel, nearest the camera,
	    so the sheet draws them larger than their place in the shop: taken
	    straight they would be 10 studs long, twice a player's height. They
	    are set at the proportion the panel's OWN far anvil reads at, which
	    still leaves them chunky beside a 5-stud character.

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

	--[[ The back wall: how high it stands, how thick it is, and the stone
	     shelf that caps it. The sheet lays its blocks in courses, so
	     `courses` of them go up the face. ]]
	wallTall = 17,
	wallThick = 2,
	courses = 6,
	cap = { tall = 1.4, out = 1.2 },
	--[[ The timber post at each end of the opening. There is no beam
	     across the front: the sheet's top edge is the wall's own stone
	     shelf, and a full-width timber header drawn there hung six studs
	     forward of the sign and, from the angle a player sees the lobby
	     from, covered it. ]]
	post = { thick = 2.2, out = 15 },
	--[[ The two short return walls down the sides, which is what makes the
	     front read as an opening rather than a free-standing wall. They
	     reach this far forward of the back wall. ]]
	returns = 5,

	--[[ The stone stack at the back, `across` studs square, rising this
	     far over the wall, set `back` behind the wall's face and `side`
	     studs right of the middle -- the sheet stands it over the hearth,
	     which is on the right of the panel. ]]
	--[[ `back` is how far its own back face stands behind the wall's: the
	     stack is entirely BEHIND the wall, bitten one stud into it so the
	     two read as one piece of stone. Standing it on the wall line put
	     three studs of chimney inside the shop, in front of the hearth,
	     which from the lobby's own angle hid the fire completely. ]]
	chimney = { across = 9, rise = 10, back = 8, side = -7.5, mouth = 4.6 },

	--[[ The nameboard on the wall: its size, how far its face stands proud
	     of the stone, and how far its top is below the wall's cap. ]]
	sign = { across = 18, tall = 6, out = 0.8, below = 2.6 },

	--[[ The hearth arch cut into the wall under the chimney: its opening,
	     how far right of the middle it is cut, the brick lip across its
	     foot, and the light the fire throws. ]]
	--[[ `side` is NEGATIVE, which is the viewer's right: a building faces
	     +Z and its +X is the viewer's left, and two of the three sheets
	     (`ref_main`, `ref3_blacksmith`) put the fire and the stack over
	     it on the right, with the racks and the board to their left. ]]
	hearth = {
		across = 12,
		tall = 7.5,
		side = -7.5,
		lip = 1.6,
		range = 26,
		brightness = 2.2,
	},

	--[[ The two anvils out on the apron. `apart` is between their middles
	     and `forward` is studs in front of the wall's face. ]]
	anvil = { long = 7, tall = 4.5, wide = 2.6, apart = 11, forward = 11 },

	--[[ The sword rack against the wall, left of the hearth: its frame,
	     how many blades stand in it and how long each is. ]]
	rack = { across = 7, tall = 5.4, blades = 4, blade = 4.6, side = 2, forward = 4 },
	--[[ The workbench further left, with hammers and tongs laid on it. ]]
	bench = { long = 8, tall = 3.4, wide = 2.6, side = 11, forward = 4 },

	--[[ A banner at each end: a cross pole out past the frame post, and
	     the cloth hanging from it, with the gold emblem on its face. ]]
	banner = { long = 11, wide = 3.2, out = 17.5, top = 14, forward = 3 },

	--[[ The paved apron the shop stands on, studs across and deep. The
	     sheet runs it out well past the anvils. ]]
	apron = Vector2.new(36, 24),

	--[[ The sheet's palette, set on the parts outright, as the Dex Hall's
	     is. Nothing here is generated or tinted. ]]
	colours = {
		stone = Color3.fromRGB(150, 152, 158),
		stoneLight = Color3.fromRGB(176, 178, 184),
		stoneDark = Color3.fromRGB(136, 138, 145),
		timber = Color3.fromRGB(150, 96, 52),
		timberDark = Color3.fromRGB(104, 64, 36),
		board = Color3.fromRGB(40, 34, 32),
		floor = Color3.fromRGB(216, 166, 118),
		floorEdge = Color3.fromRGB(186, 134, 92),
		anvil = Color3.fromRGB(72, 80, 96),
		steel = Color3.fromRGB(198, 206, 218),
		brick = Color3.fromRGB(150, 92, 72),
		fire = Color3.fromRGB(255, 140, 40),
		ember = Color3.fromRGB(236, 74, 30),
		banner = Color3.fromRGB(48, 92, 176),
		gold = Color3.fromRGB(244, 196, 64),
	},
}

return table.freeze(BlacksmithDesign)
