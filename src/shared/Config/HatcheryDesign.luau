--!strict
--[[
	The Egg Hatchery, measured off its reference sheet (owner's standing
	rule, CLAUDE.md 13: "if it does not match 1 to 1 then redo it").

	Its sheet is `assets/concepts/blocky/lobby/ref4_hatchery.png`, which the
	owner sent on 2026-11-02 to replace the EGG HATCHERY panel of
	`ref_main.png` entirely. It is a different building: not a timber
	shelter over a clutch of nests, but a **raised cream stone plaza** with
	a giant pink crystal bloom standing in a pool of glowing water, an egg
	on its own lit pedestal either side, and a vined balustrade round the
	back.

	What the sheet shows, piece by piece, front to back:

	  * Three broad **steps** up the middle of the front, into a tiled
	    cream deck. The deck's front corners are cut off, and a block of
	    cyan light is set into the stone each side of the steps.
	  * A low **parapet** round the deck's edge, and behind it a shallow
	    **pool of cyan water** that glows, with short falls down its back.
	  * Dead centre, a **crystal bloom**: a tall pale-pink spire with a
	    deep-pink diamond on its face, six magenta petals leaning out round
	    it, and six big green leaves curling up from its foot.
	  * Left and right, a **round cream pedestal** banded twice in cyan
	    light with a magenta diamond on its face, green leaves round its
	    head, and a cream **egg** standing on it -- the left egg spotted
	    pink, the right purple, in flat angular spots.
	  * Two capped **pillars** at the back corners, and a **balustrade** of
	    capped posts and rails running round behind, both carrying green
	    vines, pink flowers and white daisies.

	Every measurement below is read off the sheet as a fraction of **the
	whole plaza's width** -- 1140 px on the sheet cropped to the build --
	and then set against a width of 30 studs:

	    plaza width, end to end 1140 px   1.00   ->  30      `across`
	    deck, front to back      530 px   0.47   ->  14      `plaza.deep`
	    deck above the lawn      210 px   0.184  ->  5.4     `plaza.tall`
	    one step's rise           70 px   0.061  ->  1.8     `steps.rise`
	    the steps' span          850 px   0.75   ->  22.5    `steps.across`
	    parapet height            95 px   0.083  ->  2.5     `parapet.tall`
	    pedestal width           260 px   0.228  ->  6.8     `pedestal.across`
	    pedestal height          105 px   0.092  ->  2.8     `pedestal.tall`
	    egg width                210 px   0.184  ->  5.5     `egg.wide`
	    egg height               200 px   0.175  ->  5.3     `egg.tall`
	    bloom width              435 px   0.38   ->  11.4    `bloom.across`
	    bloom height             485 px   0.425  ->  12.8    `bloom.tall`
	    leaf fan width           530 px   0.465  ->  14      `leaves.across`
	    pillar cap width         135 px   0.118  ->  3.5     `pillar.cap`
	    pillar height            435 px   0.38   ->  11.4    `pillar.tall`
	    balustrade post width    110 px   0.096  ->  2.9     `fence.post`

	The sheet is drawn square on, so nothing here needed the correction the
	isometric Blacksmith panel did.

	Offsets are in the building's own frame: +Z is the way it faces (toward
	the middle of the clearing, `Config/Lobby.facing`), +X is the RIGHT of
	the screen as a player stands in front of it, and y is height above the
	lawn.
]]

local HatcheryDesign = {
	--[[ The whole station's footprint -- the deck, the pool behind it and
	     the balustrade behind that. `Config/Lobby.buildings.EggHatchery`
	     declares the same two, and `Lobby.spec` holds them equal: the
	     spacing between stations is measured off that declaration. ]]
	across = 30,
	deep = 24,

	--[[ The raised deck: how high it stands, how big one of its tiles is,
	     and how far the front corners are cut off. ]]
	plaza = { tall = 5.4, deep = 14, tile = 3.6, chamfer = 4 },

	--[[ The three steps up the middle of the front. ]]
	steps = { count = 3, rise = 1.8, tread = 2.4, across = 22.5 },

	--[[ The low wall round the deck's edge, and the block of cyan light
	     set into the stone each side of the steps. ]]
	parapet = { tall = 2.5, thick = 1.6 },
	glow = { long = 5, tall = 1.2, out = 1.8 },

	--[[ The pool of water behind the parapet: how far back it reaches
	     from the parapet's inner face, how deep it sits below the deck,
	     and how many short falls run down its back. ]]
	pool = { reach = 7, drop = 1.2, falls = 6, range = 18, brightness = 0.7 },

	--[[ The crystal bloom in the middle of the pool. `spire` is the pale
	     centre, `petals` the magenta shards leaning out round it, and
	     `leaves` the green fan at its foot. ]]
	--[[ `tall` is the whole bloom, foot to point: the base, the spire and
	     the point it is capped with add up to it. ]]
	bloom = { across = 11.4, tall = 12.8, back = 5, base = 2.2 },
	spire = { wide = 4.6, tall = 8.2, point = 2.4 },
	petals = { count = 6, wide = 2.2, tall = 7, lean = 0.22, out = 3.2 },
	leaves = { count = 6, across = 14, long = 5.3, thick = 1.1 },

	--[[ The two egg pedestals. `out` is studs either side of the middle,
	     `forward` studs in front of the plaza's own line. ]]
	pedestal = { across = 6.8, tall = 2.8, out = 10, forward = 3, bands = 2 },
	egg = { wide = 5.5, tall = 5.3, spots = 6, spot = 0.3, leaves = 6 },

	--[[ The two capped pillars at the back corners. ]]
	pillar = { cap = 3.5, shaft = 2.6, tall = 11.4, out = 11.5, back = 5 },

	--[[ The balustrade of capped posts and rails behind the pool, and the
	     wings that carry it out past the pillars. `span` is how far round
	     the back it reaches, in radians, and `radius` how far out. ]]
	fence = { post = 2.9, tall = 4.2, rail = 0.6, posts = 9, radius = 14, centre = 4, span = 2.6 },

	--[[ The greenery on the stonework: how many vine blocks a pillar or a
	     post carries, and how many of them are flowers instead. ]]
	vines = { perPost = 4, thick = 1.1, flowers = 2 },

	--[[ The sheet's palette, set on the parts outright, as the Dex Hall's
	     is. Nothing here is generated or tinted. ]]
	colours = {
		stone = Color3.fromRGB(233, 221, 196),
		stoneLight = Color3.fromRGB(244, 235, 215),
		stoneDark = Color3.fromRGB(210, 194, 164),
		water = Color3.fromRGB(64, 214, 245),
		waterDeep = Color3.fromRGB(28, 182, 226),
		glow = Color3.fromRGB(96, 226, 255),
		spire = Color3.fromRGB(246, 172, 208),
		spireLight = Color3.fromRGB(252, 206, 228),
		petal = Color3.fromRGB(232, 51, 143),
		petalDeep = Color3.fromRGB(206, 24, 118),
		leaf = Color3.fromRGB(76, 175, 44),
		leafLight = Color3.fromRGB(122, 205, 60),
		leafDark = Color3.fromRGB(52, 138, 30),
		shell = Color3.fromRGB(240, 232, 214),
		spotA = Color3.fromRGB(232, 51, 143),
		spotB = Color3.fromRGB(158, 68, 230),
		flower = Color3.fromRGB(240, 90, 160),
		daisy = Color3.fromRGB(250, 250, 242),
		pollen = Color3.fromRGB(255, 210, 60),
	},
}

return table.freeze(HatcheryDesign)
