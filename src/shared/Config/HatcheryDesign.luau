--!strict
--[[
	The Egg Hatchery, measured off its reference sheet (owner's standing
	rule, CLAUDE.md 13: "if it does not match 1 to 1 then redo it").

	Its sheet is the EGG HATCHERY panel of
	`assets/concepts/blocky/lobby/ref_main.png`, with
	`assets/concepts/blocky/lobby/ref_hatchery.png` as the closeup of the
	same build. Both were drawn by Codex and approved by the owner.

	What the sheet actually shows, which the cottage standing here before
	did not:

	  * It is **an open pavilion, not a cottage**. Four timber posts, a
	    front beam, and a FLAT roof deck of grey stone slabs. No walls, no
	    door, no windows, no gable, and no giant egg on a ridge -- the
	    whole front is open and you look straight in at the eggs.
	  * The eggs stand in **one round stone nest ring** that fills nearly
	    the whole width of the pavilion and spills forward past its posts,
	    not in two straw nests set either side of a doorway.
	  * There are **three eggs, of two sizes**: a tall one at the middle,
	    set back, and a shorter one either side of it, each sitting in a
	    gold collar.
	  * The nameboard **hangs from the front beam**, dark-faced in a timber
	    frame, two thirds of the building's width.
	  * A lantern hangs on the beam at each end, and vines trail off the
	    front edge of the deck.

	Every measurement below is read off the sheet as a fraction of **the
	pavilion's width** -- the run between the outer faces of the two front
	posts, 185 px on `ref_main.png` -- and then set against a width of 30
	studs. The fraction is given beside each so a later pass can check the
	reading rather than the result:

	    pavilion width          185 px   1.00   ->  30      `across`
	    depth, front to back     85 px   0.46   ->  14      `deep`
	    post, ground to beam    130 px   0.70   ->  21      `postTall`
	    post thickness           13 px   0.07   ->  2       `postThick`
	    beam depth               12 px   0.065  ->  2       `beam`
	    roof slab thickness      10 px   0.054  ->  1.6     `slab`
	    sign board width        122 px   0.66   ->  20      `sign.across`
	    sign board height        32 px   0.17   ->  5       `sign.tall`
	    nest ring, outer        177 px   0.96   ->  28      `ring.across`
	    nest ring height         32 px   0.17   ->  5       `ring.tall`
	    nest centres apart       46 px   0.25   ->  8.5 *   `nestApart`
	    middle egg height        62 px   0.335  ->  10      `eggs[2].tall`
	    outer egg height         45 px   0.24   ->  7       `eggs[1].tall`
	    lanterns apart          145 px   0.78   ->  ±11.5   `lantern.out`
	    front pedestal height    38 px   0.21   ->  6       `pedestal.tall`

	  * the eggs are set 8.5 apart rather than the sheet's 7.5, because
	    this build's middle egg is a solid 8.4 wide where the sheet's is a
	    painted oval: at 7.5 the three ran into one white mass with the
	    outer two hidden behind the middle, which is the one thing the
	    sheet's clutch never does.

	**The post height was read wrong the first time**, at 0.49, because
	the sheet hides the posts' feet behind the nest ring and the first
	reading took the apron in front of the ring for the ground. Drawn flat
	(`tools/lobby_views.py`) that pavilion was a slab of roof with the
	eggs lost under it. On the sheet the sign's bottom edge is level with
	the tallest egg's top, which only comes out if the beam is 0.70 of the
	width up -- so that is the reading, and the eggs stand clear under it
	as they do on the sheet.

	Offsets are in the building's own frame: +Z is the way it faces (toward
	the middle of the clearing, `Config/Lobby.facing`), +X to that way's
	right, and y is height above the lawn.
]]

local HatcheryDesign = {
	--[[ The pavilion's footprint. `Config/Lobby.buildings.EggHatchery`
	     declares the same two, and `Lobby.spec` holds them equal: the
	     spacing between stations is measured off that declaration, so a
	     building wider than it says would be spaced as if it were not. ]]
	across = 30,
	deep = 14,

	--[[ The four posts and what they hold up. `postTall` is the ground to
	     the beam's underside, so the deck's top is
	     `postTall + beam + slab`. ]]
	postTall = 21,
	postThick = 2,
	beam = 2,
	slab = 1.6,
	--[[ How far the deck reaches past the posts on every side. The sheet
	     laps it over the front beam by about a third of a post. ]]
	eaves = 1.2,

	--[[ The nameboard hanging from the front beam, and how far its face
	     stands proud of the beam. ]]
	sign = { across = 20, tall = 5, out = 0.9 },

	--[[ The round stone nest ring: `across` outside, `tall` above the
	     lawn, its wall `thick`, and `forward` studs in front of the
	     building's middle, which is what puts it under the open front
	     rather than back among the posts. The sheet's ring is drawn as a
	     course of blocks, so `blocks` of them go round it. ]]
	ring = { across = 28, tall = 5, thick = 3.2, forward = 2, blocks = 22 },

	--[[ The three eggs, west to east, each in its gold collar. `tall` and
	     `wide` are the egg; `collar` is the gold ring round its foot;
	     `back` is how far behind the ring's middle it sits -- the sheet
	     sets the tall middle egg back and brings the two outer ones
	     forward, which is what makes three eggs read as a clutch rather
	     than a row. ]]
	nestApart = 8.5,
	eggs = {
		{ tall = 7, wide = 5.9, collar = 7, back = -1.6 },
		{ tall = 10, wide = 8.4, collar = 8.4, back = 2.2 },
		{ tall = 7, wide = 5.9, collar = 7, back = -1.6 },
	},
	--[[ How many spots a shell carries, and how big each is against the
	     egg's width. ]]
	spots = { count = 11, size = 0.19 },

	--[[ A lantern on the beam at each end: `out` studs either side of the
	     middle, its glass `tall`, hung `drop` below the beam. The light is
	     the Dex Hall's, which the owner already turned down once
	     (2026-11-01: "the lighting is too strong"). ]]
	lantern = { out = 11.5, tall = 3.4, drop = 3, range = 9, brightness = 0.34 },

	--[[ The vines trailing off the deck: this many down EACH SIDE, where
	     the sheet hangs them, each between these lengths. They used to
	     hang across the front, where they fell over the nameboard. ]]
	vines = { count = 3, long = NumberRange.new(2.5, 6) },

	--[[ The little stone pedestal with a green stone on it, out front of
	     the ring on the apron. ]]
	pedestal = { across = 4, tall = 6, forward = 19 },

	--[[ The paved apron the whole station stands on, studs across. The
	     sheet runs it out past the ring on every side. ]]
	apron = 46,

	--[[ The sheet's palette, set on the parts outright, as the Dex Hall's
	     is. Nothing here is generated or tinted. ]]
	colours = {
		slab = Color3.fromRGB(176, 174, 166),
		slabDark = Color3.fromRGB(160, 158, 151),
		timber = Color3.fromRGB(150, 96, 52),
		timberDark = Color3.fromRGB(110, 68, 38),
		board = Color3.fromRGB(62, 40, 26),
		stone = Color3.fromRGB(140, 142, 146),
		stoneLight = Color3.fromRGB(170, 172, 176),
		gold = Color3.fromRGB(240, 198, 52),
		shell = Color3.fromRGB(248, 246, 232),
		--[[ The sheet spots its shells in two blues, not one. ]]
		spotA = Color3.fromRGB(74, 162, 226),
		spotB = Color3.fromRGB(86, 206, 196),
		moss = Color3.fromRGB(150, 200, 50),
		vine = Color3.fromRGB(108, 180, 60),
		apron = Color3.fromRGB(198, 186, 170),
		lantern = Color3.fromRGB(255, 186, 96),
		iron = Color3.fromRGB(42, 40, 38),
		gem = Color3.fromRGB(126, 206, 72),
	},
}

return table.freeze(HatcheryDesign)
