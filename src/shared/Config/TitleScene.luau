--!strict
--[[
	The title screen's picture: "The World Tree at night" (owner, 2026-11-12,
	picked as Dark 1 from drawn references after "for the title screen take
	inspiration from elden ring and dark souls": the feeling only, dark, quiet
	and grand, nothing copied). Drawn by `UI/TitleScene`, laid out by
	`Util/TitleLayout`, pinned by `tests/TitleScene.spec`.

	**No painted or generated picture** (owner, of the old title painting:
	"looks AI"): every shape here is a flat block, a Frame, placed by hand.
	The only image is the soft round glow the game already had
	(`GearAssets.fx.glow`).

	Two layouts in points, as the reference drew them: `portrait` for a
	screen taller than wide (a phone held upright, 390 x 844) and `landscape`
	for one wider than tall (844 x 390). On any other screen the layout is
	scaled until its `safe` box fills the screen, and the sky, the ground and
	the ridge run on to the screen's edges (`TitleLayout.fit`).

	The tree is teal with mint lanterns and warm windows on purpose: it must
	not read as a glowing golden tree.
]]

local function hex(value: number): Color3
	return Color3.fromRGB(
		bit32.band(bit32.rshift(value, 16), 255),
		bit32.band(bit32.rshift(value, 8), 255),
		bit32.band(value, 255)
	)
end

--[[ A block: left, top, width, height, in the units of whatever it is
     part of. ]]
export type Block = { number }

export type Design = {
	width: number,
	height: number,
	--[[ The middle box that always shows; the layout is scaled until this
	     fills the screen, so a narrower or squatter screen crops only sky,
	     far hills and ridge. ]]
	safe: { width: number, height: number },
	--[[ Where the sky is at its brightest, a share of the height. ]]
	horizon: number,
	stars: { count: number, seed: number, below: number },
	moon: { x: number, y: number },
	--[[ The trunk's foot (`x`, `y`) and how many points a tree unit is. ]]
	tree: { x: number, y: number, unit: number },
	hills: { Block },
	groundTall: number,
	--[[ The near ridge, back to front; the first is its base, which runs to
	     the bottom of the screen. ]]
	ridge: { Block },
	--[[ Where the hero's feet and the pet's stand, and their size. ]]
	hero: { x: number, y: number, unit: number },
	pet: { x: number, y: number, unit: number },
	motes: { count: number, seed: number, box: Block },
	--[[ The logo's top, the width it is centred in and its size. ]]
	logo: { y: number, width: number, unit: number },
	--[[ BEGIN ADVENTURE: its size, the gap under it and its words' size. ]]
	button: { width: number, height: number, gap: number, words: number },
}

local TitleScene = {
	--[[ The sky, top to bottom: the stops are at 0, 40%, the layout's
	     `horizon` and 100%. ]]
	sky = { hex(0x040B16), hex(0x0A2233), hex(0x1A5A5E), hex(0x0B2A33) },
	skyMid = 0.4,

	star = hex(0xDDF6F0),
	--[[ A star is 2 points square, one in four is 3; each as see-through as
	     its own draw says, between these. ]]
	starFaint = 0.2,
	starBright = 0.8,
	moon = { colour = hex(0xEAF7E6), size = 26, corner = 5, alpha = 0.92 },

	--[[ The soft round light behind the crown, in tree units: how far above
	     the trunk's foot its middle is, how far it reaches, and how strong
	     it is at its middle. ]]
	glow = { colour = hex(0x3FE0C0), rise = 250, radius = 260, alpha = 0.5 },

	hill = { colour = hex(0x082630), tall = 90 },
	--[[ The far ground, from a little above the trunk's foot. ]]
	ground = { colour = hex(0x061E27), above = 8 },
	ridge = hex(0x02070C),

	--[[ The World Tree, in tree units from the trunk's foot (x right, y down,
	     so every y is negative). ]]
	tree = {
		trunkColour = hex(0x061C22),
		--[[ Roots, two steps of trunk, the top of the trunk, then two
		     branches, each an arm and an upright. ]]
		trunk = {
			{ -56, -14, 112, 14 },
			{ -36, -44, 72, 44 },
			{ -26, -150, 52, 110 },
			{ -19, -236, 38, 90 },
			{ -96, -204, 74, 15 },
			{ -96, -246, 15, 46 },
			{ 22, -190, 80, 15 },
			{ 88, -232, 15, 46 },
		} :: { Block },
		--[[ The crown: nine squares (left, top, side), in turn the darker
		     and the lighter teal, each with a lit strip along its top and a
		     small lit patch. ]]
		crown = {
			{ -196, -262, 74 },
			{ -158, -304, 112 },
			{ -74, -344, 144 },
			{ 60, -312, 124 },
			{ 150, -258, 84 },
			{ -112, -372, 84 },
			{ -36, -398, 100 },
			{ 36, -378, 84 },
			{ -8, -290, 90 },
		},
		crownColours = { hex(0x0B3136), hex(0x0E3A3E) },
		crownLit = hex(0x1C6A63),
		--[[ The strip is this share of the square's side deep; the patch
		     sits this far in and down, this wide and tall, this solid. ]]
		crownStrip = 0.12,
		crownPatch = { x = 0.14, y = 0.2, w = 0.3, h = 0.22, alpha = 0.6 },
		--[[ Lanterns hanging under the crown (left, top, side): each a pale
		     mint square on a faint one three times its size. ]]
		lanterns = {
			{ -170, -180, 4 },
			{ -140, -184, 5 },
			{ -104, -176, 4 },
			{ -66, -190, 4 },
			{ -40, -182, 5 },
			{ 44, -180, 4 },
			{ 80, -178, 5 },
			{ 116, -182, 4 },
			{ 160, -166, 4 },
			{ 198, -168, 4 },
			{ -186, -178, 4 },
			{ -120, -262, 3 },
			{ -20, -332, 3 },
			{ 92, -270, 3 },
			{ 14, -252, 3 },
		},
		lantern = hex(0xC9FFF0),
		lanternHalo = hex(0x7FF5D6),
		lanternHaloAlpha = 0.22,
		--[[ Lit windows on the trunk (left, top), 8 by 10, each on a faint
		     warm block 14 by 16. ]]
		windows = { { -12, -120 }, { 8, -96 }, { -14, -70 }, { 8, -150 }, { -5, -178 } },
		window = hex(0xFFD98A),
		windowHalo = hex(0xFFC76A),
		windowHaloAlpha = 0.2,
	},

	--[[ The hero seen from behind and the pet at their heel: near-black
	     blocks with a thin mint rim of light, in their own units from where
	     they stand. A plain silhouette, never the player's avatar. ]]
	figure = hex(0x02060B),
	rim = hex(0x58D8BC),
	hero = {
		--[[ The bow across the back: a curve from above the left shoulder,
		     bowed out to the right, down to the right hip. ]]
		bow = { from = { -15, -54 }, bend = { 8, -36 }, to = { 15, -8 }, thick = 2.8, pieces = 7 },
		--[[ The tunic, wider at its hem than at the shoulders, in steps. ]]
		body = {
			{ -10, -40, 20, 8 },
			{ -11, -32, 22, 8 },
			{ -12, -24, 24, 7 },
			{ -13, -17, 26, 7 },
			-- legs, arms, head
			{ -8, -16, 6, 16 },
			{ 2, -16, 6, 16 },
			{ -14, -39, 4, 17 },
			{ 10, -39, 4, 17 },
			{ -8, -57, 16, 16 },
		} :: { Block },
		--[[ The light catching the head and the shoulders; the fifth number
		     is how solid. ]]
		rims = {
			{ -8, -57, 16, 1.6, 0.85 },
			{ -14, -39, 4, 1.3, 0.7 },
			{ 10, -39, 4, 1.3, 0.7 },
			{ -10, -41, 20, 1.3, 0.45 },
		} :: { Block },
	},
	pet = {
		-- body, head, two ears, tail
		body = {
			{ 0, -10, 18, 10 },
			{ 13, -18, 11, 10 },
			{ 13, -22, 3, 5 },
			{ 21, -22, 3, 5 },
			{ -4, -16, 4, 9 },
		} :: { Block },
		rims = { { 13, -18, 11, 1.3, 0.8 }, { 0, -10, 13, 1.2, 0.6 } } :: { Block },
	},

	--[[ Small square motes that drift up and to the right and fade, each on
	     its own loop. Under Roblox's reduced motion they stand still. ]]
	mote = {
		colour = hex(0x8FF5D8),
		small = 3,
		large = 5,
		--[[ One in this share is the large one. ]]
		largeShare = 0.3,
		drift = { x = 14, y = -70 },
		--[[ A loop is between these seconds long. ]]
		loop = { 7, 12 },
		--[[ How solid one is through its loop: up by 15%, easing off to
		     80%, gone at the end. ]]
		rise = 0.15,
		peak = 0.9,
		ease = 0.8,
		settled = 0.7,
		--[[ The faint square round each, this many times its size. ]]
		haloSize = 3,
		haloAlpha = 0.18,
	},

	--[[ The logo: ARROW over BORNE in the one font, pale gold from top to
	     bottom inside a thick near-black outline with a hard shadow under it
	     and a soft gold glow round it. Sizes are points at a logo unit of 1. ]]
	logo = {
		words = { "ARROW", "BORNE" },
		sizes = { 46, 82 },
		--[[ A line is this share of its letters' size tall. ]]
		line = 0.92,
		--[[ The gold runs over the letters' own box, this share of their
		     size tall, with these stops. ]]
		box = 1.21,
		gold = {
			{ at = 0, colour = hex(0xFFFBE6) },
			{ at = 0.08, colour = hex(0xFFFBE6) },
			{ at = 0.55, colour = hex(0xFFE49C) },
			{ at = 1, colour = hex(0xE6AE48) },
		},
		outline = hex(0x03080D),
		outlineThick = 4.5,
		shadowDrop = 5,
		--[[ The glow: a ring round the letters (how far past them it reaches
		     and how see-through it is) over a wide soft haze (the round glow
		     picture, this many times the logo's width and the words' height,
		     this solid at its middle; faint, so the tree under it stays teal). ]]
		glow = hex(0xFFCE6E),
		glowRing = { reach = 8, clear = 0.82 },
		haze = { wide = 1.15, tall = 2, alpha = 0.22 },
		--[[ The streak of light under the words: this share of the logo's
		     width, this far under them, fading in from the left and ending
		     in a small arrowhead that overhangs its right end. ]]
		streak = {
			width = 0.86,
			gap = 13,
			thick = 3,
			from = hex(0xFFF0BE),
			mid = hex(0xFFE9A8),
			to = hex(0xFFFFFF),
			midAt = 0.55,
			glow = hex(0xFFD678),
			head = { long = 14, tall = 15, overhang = 10 },
		},
	},

	--[[ BEGIN ADVENTURE is the kit's green "go" button with a small play
	     triangle, gently pulsing. It grows with the picture, but no further
	     than this (a desktop's would be a third of the screen). ]]
	button = {
		pulse = 0.05,
		pulseEvery = 1.4,
		most = 1.5,
		--[[ The triangle: this share of the words' size across and tall. ]]
		icon = { wide = 0.56, tall = 0.68, gap = 0.3 },
	},

	portrait = {
		width = 390,
		height = 844,
		safe = { width = 390, height = 760 },
		horizon = 0.71,
		stars = { count = 70, seed = 7, below = 450 },
		moon = { x = 312, y = 262 },
		tree = { x = 195, y = 612, unit = 0.9 },
		hills = {
			{ 0, 566, 70 },
			{ 60, 580, 64 },
			{ 112, 572, 50 },
			{ 250, 576, 70 },
			{ 312, 562, 80 },
		},
		groundTall = 260,
		ridge = {
			{ 0, 660, 390, 184 },
			{ 0, 636, 270, 28 },
			{ 14, 616, 190, 24 },
			{ 50, 600, 104, 20 },
			{ 300, 644, 90, 20 },
		},
		hero = { x = 100, y = 600, unit = 1.05 },
		pet = { x = 128, y = 600, unit = 1.05 },
		motes = { count = 12, seed = 3, box = { 40, 300, 310, 270 } },
		logo = { y = 78, width = 390, unit = 1.14 },
		button = { width = 358, height = 84, gap = 22, words = 29 },
	} :: Design,

	landscape = {
		width = 844,
		height = 390,
		safe = { width = 640, height = 390 },
		horizon = 0.76,
		stars = { count = 80, seed = 7, below = 230 },
		moon = { x = 704, y = 52 },
		tree = { x = 422, y = 334, unit = 0.78 },
		hills = {
			{ 0, 290, 90 },
			{ 80, 300, 110 },
			{ 180, 296, 70 },
			{ 560, 298, 90 },
			{ 640, 288, 110 },
			{ 740, 300, 104 },
		},
		groundTall = 90,
		ridge = {
			{ 0, 340, 844, 50 },
			{ 40, 318, 300, 26 },
			{ 96, 300, 150, 22 },
			{ 560, 330, 284, 20 },
		},
		hero = { x = 166, y = 300, unit = 0.95 },
		pet = { x = 196, y = 300, unit = 0.95 },
		motes = { count = 14, seed = 3, box = { 250, 100, 360, 190 } },
		logo = { y = 16, width = 430, unit = 0.84 },
		button = { width = 380, height = 72, gap = 14, words = 29 },
	} :: Design,
}

return table.freeze(TitleScene)
