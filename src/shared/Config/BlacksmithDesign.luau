--!strict
--[[
	The Blacksmith, measured off its reference sheet (owner's standing
	rule, CLAUDE.md 13: "if it does not match 1 to 1 then redo it").

	Its sheet is `assets/concepts/blocky/lobby/ref4_blacksmith.png`, which
	the owner sent on 2026-11-02 to replace the BLACKSMITH panel of
	`ref_main.png` entirely. It is a different building: not a grey stone
	forge open to a lawn, but a **timber-fronted forge house cut into a
	purple rock**, with a lava fall down one side and the shop's three
	chests out on the other.

	What the sheet shows, piece by piece:

	  * A **forge house** of purple-grey block with a heavy **timber
	    front**: two corner posts, a lintel across, and a gable over it
	    carrying a huge **gold hammer**. Gold brackets at every joint of
	    the timber.
	  * A **red banner** with a gold hammer on it hanging from the lintel
	    each side of the gable.
	  * The front is open: inside, a **hearth full of fire** behind a long
	    timber counter, a tool rack to the left, a bench to the right, and
	    chains hanging from the lintel.
	  * A small **chimney** on the roof with a lit window in it.
	  * On the LEFT, a stepped outcrop of the same purple rock with a
	    **lava fall** pouring down it, and a timber rail along the top.
	  * On the RIGHT, the shop's **three chests**, each on its own stone
	    pedestal under a red shield: a **bow**, a **wand** and a **sword**,
	    with that weapon standing over the chest.
	  * Out front, a single huge **anvil** on a stone block, lit from
	    under by the forge.
	  * The whole thing stands on grey **paving slabs**.

	The sheet is drawn in isometric. Horizontal readings are taken across
	the drawing and scaled from **the whole diorama's width** -- 1430 px on
	the sheet cropped to the build -- against a width of 32 studs, which
	gives 44.7 px to the stud; heights are read with the same scale,
	because the drawing's vertical axis is true vertical:

	    diorama width          1430 px   1.00   ->  32      `across`
	    forge house front       770 px   0.54   ->  17.5    `house.across`
	    house, floor to lintel  360 px   0.25   ->  8       `house.tall`
	    gable over the lintel   205 px   0.14   ->  4.6     `house.gable`
	    timber post thickness    75 px   0.052  ->  1.7     `house.post`
	    lintel depth             70 px   0.049  ->  1.6     `house.lintel`
	    gold hammer, head        230 px   0.16   ->  5.2     `hammer.head`
	    gold hammer, handle      250 px   0.175  ->  5.6     `hammer.haft`
	    banner cloth length      200 px   0.14   ->  4.5     `banner.long`
	    banner cloth width       110 px   0.077  ->  2.5     `banner.wide`
	    hearth opening width     230 px   0.16   ->  5.2     `hearth.across`
	    hearth opening height    150 px   0.105  ->  3.4     `hearth.tall`
	    counter height          ~120 px   0.084  ->  2.7     `counter.tall`
	    anvil length            330 px   0.23   ->  7.4      `anvil.long`
	    anvil height            200 px   0.14   ->  4.5      `anvil.tall`
	    chest width             130 px   0.091  ->  2.9      `chest.across`
	    chest pedestal height   130 px   0.091  ->  2.9      `chest.plinth`
	    lava fall width         110 px   0.077  ->  2.5      `lava.wide`
	    rock outcrop width      380 px   0.27   ->  8.5      `rock.across`

	The sheet is drawn from the front-left, so what reads as the LEFT of
	the drawing is the building's **negative X**: a station faces +Z, you
	look at it down -Z, and +X is then the right of the screen -- checked
	in Studio on 2026-11-02 against the forge fire's own glow. So the rock
	and its lava are at negative X and the three chests at positive X.

	Offsets are in the building's own frame: +Z is the way it faces (toward
	the middle of the clearing, `Config/Lobby.facing`), +X to the right of
	a player standing in front of it, and y is height above the lawn.
]]

local BlacksmithDesign = {
	--[[ The whole diorama's footprint. `Config/Lobby.buildings.Blacksmith`
	     declares the same two, and `Lobby.spec` holds them equal: the
	     spacing between stations is measured off that declaration. ]]
	across = 32,
	deep = 20,

	--[[ The forge house: the opening's width, the height to the lintel,
	     the gable over it, and the timber it is framed in. `side` is
	     studs right of the middle and `back` studs behind it. ]]
	house = {
		across = 17.5,
		deep = 9,
		tall = 8,
		gable = 4.6,
		post = 1.7,
		lintel = 1.6,
		side = -1,
		back = 4,
	},
	--[[ The purple block the house is cut into: how far the stone runs
	     past the timber each side, how far it rises over the lintel, and
	     how many courses go up it. ]]
	shell = { out = 3.4, rise = 2.2, courses = 6, joint = 0.2 },

	--[[ The gold hammer on the gable: its head, its handle, and how far
	     the handle leans over. ]]
	hammer = { head = 5.2, haft = 5.6, thick = 2, lean = 0.5 },

	--[[ A red banner each side of the gable, hanging off the lintel. ]]
	banner = { long = 4.5, wide = 2.5, out = 6.4, mark = 0.5 },

	--[[ The hearth inside, and the light it throws over the whole shop --
	     it is the only thing lighting this corner of the lobby. ]]
	hearth = { across = 5.2, tall = 3.4, base = 1.2, range = 34, brightness = 1.6 },
	--[[ The timber counter across the front of the opening. ]]
	counter = { tall = 2.7, thick = 1.4 },
	--[[ The rack of tools to the left of the hearth and the bench to its
	     right, inside the house. ]]
	rack = { across = 4, tall = 4.6, side = -5.6 },
	bench = { long = 4.4, tall = 2.6, side = 5.6 },
	--[[ The chains hanging off the lintel. ]]
	chains = { count = 3, long = 2.4 },

	--[[ The chimney on the roof, with its lit window. ]]
	chimney = { across = 2.6, rise = 3.4, side = -4, back = 2 },

	--[[ The rock outcrop on the left, with the lava fall down its face
	     and a timber rail along its top. `steps` is how many blocks it
	     steps down in. ]]
	rock = { across = 8.5, tall = 9, steps = 4, side = -12, block = 2.6 },
	lava = { wide = 2.5, range = 20, brightness = 1.4 },
	rail = { tall = 2.6, posts = 3 },

	--[[ The one anvil out on the floor, on its stone block, lit from
	     under by the forge. ]]
	anvil = { long = 7.4, tall = 4.5, wide = 3, side = -8, forward = 15 },

	--[[ The shop's three chests on the right, each on its stone pedestal
	     under a red shield, with its weapon standing over it. The marks
	     are the three classes, in the sheet's own order. ]]
	chest = { across = 2.9, plinth = 2.9, apart = 4.4, side = 11.5, forward = 10 },
	marks = { "bow", "wand", "sword" },

	--[[ The paving the whole thing stands on, and how big one slab is. ]]
	apron = Vector2.new(32, 20),
	flag = 4,

	--[[ The sheet's palette, set on the parts outright, as the Dex Hall's
	     is. Nothing here is generated or tinted. ]]
	colours = {
		rock = Color3.fromRGB(104, 94, 120),
		rockLight = Color3.fromRGB(126, 116, 142),
		rockDark = Color3.fromRGB(84, 74, 100),
		floor = Color3.fromRGB(150, 146, 158),
		floorLight = Color3.fromRGB(168, 164, 176),
		floorDark = Color3.fromRGB(132, 128, 140),
		timber = Color3.fromRGB(168, 98, 46),
		timberLight = Color3.fromRGB(196, 121, 58),
		timberDark = Color3.fromRGB(124, 70, 32),
		gold = Color3.fromRGB(250, 170, 45),
		goldLight = Color3.fromRGB(255, 200, 84),
		banner = Color3.fromRGB(204, 34, 34),
		bannerDark = Color3.fromRGB(162, 22, 22),
		fire = Color3.fromRGB(255, 170, 40),
		lava = Color3.fromRGB(255, 150, 0),
		lavaLight = Color3.fromRGB(255, 216, 77),
		anvil = Color3.fromRGB(128, 124, 146),
		anvilDark = Color3.fromRGB(96, 92, 114),
		steel = Color3.fromRGB(226, 228, 236),
		chest = Color3.fromRGB(150, 60, 190),
		crystal = Color3.fromRGB(233, 90, 220),
	},
}

return table.freeze(BlacksmithDesign)
