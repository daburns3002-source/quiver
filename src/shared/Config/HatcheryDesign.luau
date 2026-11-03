--!strict
--[[
	The Egg Hatchery, measured off its reference sheet (owner's standing
	rule, CLAUDE.md 13: "if it does not match 1 to 1 then redo it").

	Its sheet is the EGG HATCHERY panel of
	`assets/concepts/blocky/lobby/ref_main.png`, with
	`assets/concepts/blocky/lobby/ref_hatchery.png` as a closeup of the
	same build. Both were drawn by Codex and approved by the owner.

	Read again on 2026-11-02 at the sheet's own resolution, after the first
	rebuild was looked at lit in Studio beside it (owner: "these need to be
	redone heavily, if it is not 1 to 1 exactly try again"). The first pass
	had been drawn off a thumbnail and got five things wrong, all of which
	this one carries:

	  * The eggs sit in **three separate round stone nests**, each with its
	    own gold rim and moss bed, overlapping into a clover. The first
	    pass put all three inside ONE wide ring, which read in game as a
	    smooth plastic tub with the eggs sunk in it.
	  * Behind the posts there is a **wall of stone blocks**, so you look
	    at the eggs against stone rather than straight through at the lawn.
	  * The nameboard is a **dark board with white letters** in a timber
	    frame. The shared light-brown signboard reads as a plank here.
	  * The stones are laid in **three close greys picked at random**, not
	    two alternating -- a two-colour grid reads as a checkerboard from
	    the lobby's own distance, which is exactly what the first build
	    did.
	  * The ground is **flagstone paving**, a field of separate slabs, not
	    one smooth disc, and a **timber fence** runs round the back and
	    sides.

	Every measurement below is read off the panel as a fraction of **the
	header beam's span** -- 830 px on the panel enlarged four times -- and
	then set against a span of 30 studs:

	    header beam span        830 px   1.00   ->  30      `across`
	    depth, front to back    390 px   0.47   ->  14      `deep`
	    post, ground to beam    455 px   0.55   ->  16.5    `postTall`
	    post thickness           57 px   0.069  ->  2       `postThick`
	    header beam depth        60 px   0.072  ->  2.2     `beam`
	    roof slab thickness      55 px   0.066  ->  2       `slab`
	    sign board width        420 px   0.51   ->  15      `sign.across`
	    sign board height       100 px   0.12   ->  3.6     `sign.tall`
	    nest field, end to end  595 px   0.72   ->  21.8    `nests` span
	    middle nest, outer      280 px   0.34   ->  10.4 *  `nests[2].across`
	    outer nest, outer       240 px   0.29   ->  8.6     `nests[1].across`
	    nest stone course       125 px   0.15   ->  4.5     `nestTall`
	    middle egg height       220 px   0.27   ->  8       `nests[2].tall`
	    middle egg width        195 px   0.23   ->  7       `nests[2].wide`
	    outer egg height        175 px   0.21   ->  6.3     `nests[1].tall`
	    outer egg width         150 px   0.18   ->  5.4     `nests[1].wide`
	    pedestal width           72 px   0.087  ->  2.6     `pedestal.across`
	    pedestal height          60 px   0.073  ->  2.2     `pedestal.tall`
	    lantern body             80 px   0.10   ->  3       `lantern.tall`

	  * the middle nest is drawn a shade wider than its share of the field
	    because the panel has it set back behind the other two, where
	    perspective shrinks it; taken flat it reads as the same size as the
	    outer pair, and the sheet's own closeup shows it plainly bigger.

	A nest's inner hole is narrower than the egg standing in it, in the
	sheet as here: the shell rests ON the gold rim and overhangs it, which
	is what makes an egg look heavy rather than dropped in a cup.

	Offsets are in the building's own frame: +Z is the way it faces (toward
	the middle of the clearing, `Config/Lobby.facing`), +X to that way's
	right, and y is height above the lawn.
]]

local HatcheryDesign = {
	--[[ The shelter's footprint. `Config/Lobby.buildings.EggHatchery`
	     declares the same two, and `Lobby.spec` holds them equal: the
	     spacing between stations is measured off that declaration. ]]
	across = 30,
	deep = 14,

	--[[ The timber frame: four posts under a beam round their heads, and
	     the flat deck of paving slabs they carry. `eaves` is how far the
	     deck laps past the posts on every side. ]]
	postTall = 16.5,
	postThick = 2,
	beam = 2.2,
	slab = 2,
	eaves = 2,

	--[[ The stone wall closing the back of the shelter, between the two
	     back posts. `courses` go up it and `columns` across, each block a
	     touch narrower than its cell so the joints show. ]]
	back = { thick = 1.6, courses = 5, columns = 8, joint = 0.18 },

	--[[ The nameboard hanging off the front beam: its size and how far its
	     face stands proud of the beam. ]]
	sign = { across = 15, tall = 3.6, out = 1.1 },

	--[[
		The three nests, left to right, each a ring of stone blocks with a
		gold rim and a moss bed inside, and the egg standing on it.

		`at` is studs right of the middle, `back` studs behind the nest
		field's own line, `across` the stone ring's outer width, `wide` and
		`tall` the egg's. The middle one stands back, as the sheet sets it.
	]]
	nestTall = 4.5,
	nestThick = 2.2,
	nestBlocks = 12,
	nests = {
		{ at = -7.2, back = 0, across = 8.6, wide = 5.4, tall = 6.3 },
		{ at = 0, back = 2.6, across = 10.4, wide = 7, tall = 8 },
		{ at = 7.2, back = 0, across = 8.6, wide = 5.4, tall = 6.3 },
	},
	--[[ How far the nest field stands forward of the building's middle.
	     The eggs are sized so the tallest one's top comes level with the
	     nameboard's bottom edge, which is where the sheet puts it. ]]
	nestForward = 2.5,
	--[[ The spots on a shell: how many, and each one's width as a share of
	     the egg's. The sheet dots them in two blues. ]]
	spots = { count = 11, size = 0.2 },

	--[[ A lantern hung under each end of the front beam. ]]
	lantern = { out = 12.4, tall = 1.8, drop = 2.6, range = 10, brightness = 0.5 },

	--[[ The vines trailing off the front beam, either side of the board,
	     and one down each side. ]]
	vines = { count = 5, thick = 0.5, long = NumberRange.new(2.5, 6.5) },

	--[[ The little stone pedestal with a green stone on it, out front at
	     the middle, `forward` studs ahead of the building's own line. ]]
	pedestal = { across = 2.6, tall = 2.2, forward = 12 },

	--[[ The paved ground: how far across the whole circle of flagstones
	     reaches, and how big one slab is. ]]
	apron = 36,
	flag = 3.6,

	--[[ The timber fence round the back and sides. It stops `gap` radians
	     short of the front on each side, leaving the path and the station's
	     stands their room. ]]
	fence = { radius = 17.5, posts = 18, tall = 3.8, rail = 0.5, gap = 0.7 },

	--[[ The sheet's palette, set on the parts outright, as the Dex Hall's
	     is. Nothing here is generated or tinted. The three greys are what
	     the nest and roof stones are picked from. ]]
	colours = {
		stone = Color3.fromRGB(108, 110, 118),
		stoneLight = Color3.fromRGB(130, 132, 140),
		stoneDark = Color3.fromRGB(90, 92, 100),
		slab = Color3.fromRGB(130, 128, 122),
		slabLight = Color3.fromRGB(150, 147, 140),
		slabDark = Color3.fromRGB(112, 110, 105),
		flag = Color3.fromRGB(172, 154, 130),
		flagLight = Color3.fromRGB(190, 172, 148),
		flagDark = Color3.fromRGB(152, 134, 112),
		timber = Color3.fromRGB(138, 86, 44),
		timberDark = Color3.fromRGB(92, 56, 30),
		board = Color3.fromRGB(38, 32, 30),
		ink = Color3.fromRGB(248, 246, 240),
		gold = Color3.fromRGB(240, 198, 52),
		shell = Color3.fromRGB(248, 246, 232),
		spotA = Color3.fromRGB(74, 162, 226),
		spotB = Color3.fromRGB(86, 206, 196),
		moss = Color3.fromRGB(150, 200, 50),
		vine = Color3.fromRGB(108, 180, 60),
		lantern = Color3.fromRGB(255, 186, 96),
		iron = Color3.fromRGB(42, 40, 38),
		gem = Color3.fromRGB(126, 206, 72),
	},
}

return table.freeze(HatcheryDesign)
