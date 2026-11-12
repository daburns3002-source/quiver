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
	--[[ The second pass of detail (owner, 2026-11-12: "a little bit more
	     detailed, i like the minimalist approach but still needs a little bit
	     more to it"): thin cloud bands (left, top, width), a few large stars,
	     a farther row of hills (left, top, width), small pines on the near
	     hills (middle, foot, height), village lights, grass on the ridge
	     (left, foot) and one lantern post (foot). ]]
	clouds: { Block },
	bigStars: { Block },
	farHills: { Block },
	pines: { Block },
	village: { Block },
	tufts: { Block },
	post: { x: number, y: number },
	--[[ The third pass (owner, 2026-11-12: "a little bit more detail still"):
	     a few far birds (middle, height, span), glowing mushrooms on the
	     ridge (left, foot, size), a signpost pointing to the tree (foot), and
	     where a shooting star crosses now and then. ]]
	birds: { Block },
	glowcaps: { Block },
	sign: { x: number, y: number },
	shooting: { from: { number }, to: { number } },
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
	--[[ Every letter size here is the drawing's: the size of the letters
	     themselves. Roblox's TextSize is the font's whole line instead, and
	     Fredoka One's line is this many times its letters' size, so a size
	     here is multiplied by it on its way to the screen. ]]
	letterLine = 1.21,

	--[[ The sky, top to bottom: the stops are at 0, 40%, the layout's
	     `horizon` and 100%. ]]
	sky = {
		Color3.fromHex("#040B16"),
		Color3.fromHex("#0A2233"),
		Color3.fromHex("#1A5A5E"),
		Color3.fromHex("#0B2A33"),
	},
	skyMid = 0.4,

	star = Color3.fromHex("#DDF6F0"),
	--[[ A star is 2 points square, one in four is 3; each as see-through as
	     its own draw says, between these. ]]
	starFaint = 0.2,
	starBright = 0.8,
	moon = { colour = Color3.fromHex("#EAF7E6"), size = 26, corner = 5, alpha = 0.92 },
	--[[ A faint square of light round the moon, this much larger each side,
	     and three shallow craters on it (left, top, side). ]]
	moonHalo = { grow = 8, alpha = 0.1 },
	moonCraters = { { 5, 6, 5 }, { 14, 15, 6 }, { 17, 5, 3 } },
	moonCrater = Color3.fromHex("#C9DDD2"),
	--[[ One star in this many twinkles: it dims by this share and back, this
	     many times a second (stilled under reduced motion). ]]
	twinkle = { every = 5, depth = 0.6, speed = 0.14 },
	--[[ A large star is a small plus: this long and this thick. ]]
	bigStar = { long = 7, thick = 1.6, alpha = 0.85 },
	--[[ A cloud is a thin band with a shorter step above and below it. ]]
	cloud = { colour = Color3.fromHex("#16434C"), alpha = 0.45, tall = 5 },

	--[[ The soft round light behind the crown, in tree units: how far above
	     the trunk's foot its middle is, how far it reaches, and how strong
	     it is at its middle. ]]
	glow = { colour = Color3.fromHex("#3FE0C0"), rise = 250, radius = 260, alpha = 0.5 },

	hill = { colour = Color3.fromHex("#082630"), tall = 90 },
	--[[ The farther hills, paler, behind the near ones; the village's lit
	     windows on the near hills. ]]
	farHill = { colour = Color3.fromHex("#0F3B44"), tall = 120 },
	villageLight = { colour = Color3.fromHex("#FFD98A"), size = 2.5, alpha = 0.85 },
	--[[ The far ground, from a little above the trunk's foot. ]]
	ground = { colour = Color3.fromHex("#061E27"), above = 8 },
	ridge = Color3.fromHex("#02070C"),
	--[[ A far bird is two short strokes, a shallow V, pale and faint. ]]
	bird = { thick = 1.2, tilt = 24, alpha = 0.5 },
	--[[ A glowing mushroom: a pale stem under a mint cap, on a faint square
	     of light this many times its size. ]]
	glowcap = { stem = Color3.fromHex("#BFEFE0"), halo = 2.6, haloAlpha = 0.16 },
	--[[ The signpost: a post this tall with a board this wide and tall near
	     its top, and a small step for the board's point. ]]
	sign = { tall = 18, wide = 12, board = 6 },
	--[[ A shooting star: every so many seconds one crosses in this long, a
	     streak this long and thick, the first this soon after the title
	     appears (none under reduced motion). ]]
	shooting = { every = 13, lasts = 0.9, long = 30, thick = 1.6, first = 4 },
	--[[ Grass on the ridge: three blades (left, height) two points wide. ]]
	tuft = { { 0, 4 }, { 3, 7 }, { 6, 3 } },
	--[[ The lantern post on the ridge: a post, an arm and a mint lantern
	     hanging from it. ]]
	post = { tall = 24, arm = 9, lantern = 5 },

	--[[ The World Tree, in tree units from the trunk's foot (x right, y down,
	     so every y is negative). ]]
	tree = {
		trunkColour = Color3.fromHex("#061C22"),
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
		--[[ Roots stepping out from the trunk's foot, and smaller leaf blocks
		     (left, top, side) round the crown's edge, so its outline is less
		     square; they are drawn behind the crown. ]]
		roots = {
			{ -74, -8, 22, 8 },
			{ -64, -14, 10, 8 },
			{ 52, -8, 22, 8 },
			{ 54, -14, 10, 8 },
		} :: { Block },
		leaves = {
			{ -216, -240, 32 },
			{ -178, -326, 36 },
			{ -104, -394, 30 },
			{ 118, -346, 36 },
			{ 214, -236, 32 },
			{ 86, -400, 30 },
			{ -58, -404, 28 },
			{ 6, -404, 26 },
			{ -140, -214, 26 },
			{ 120, -206, 28 },
		},
		--[[ Vines hanging under the crown (left, top, length), two units wide,
		     and a few small warm windows up in it (left, top), 5 by 6. ]]
		vines = {
			{ -186, -190, 22 },
			{ -150, -194, 30 },
			{ -118, -194, 18 },
			{ -58, -202, 34 },
			{ -22, -202, 20 },
			{ 38, -202, 28 },
			{ 96, -190, 36 },
			{ 134, -190, 16 },
			{ 176, -176, 26 },
			{ 212, -176, 14 },
		},
		crownWindows = { { -150, -250 }, { -52, -318 }, { 104, -290 } },
		--[[ The first of the lanterns hang on strings this long. ]]
		strings = { count = 11, long = 12 },
		--[[ A lit doorway at the trunk's foot: its dark frame and the warm
		     light in it. ]]
		door = { frame = { -8, -30, 16, 30 }, light = { -5, -25, 10, 25 } },
		doorFrame = Color3.fromHex("#03121A"),
		crownColours = { Color3.fromHex("#0B3136"), Color3.fromHex("#0E3A3E") },
		crownLit = Color3.fromHex("#1C6A63"),
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
		lantern = Color3.fromHex("#C9FFF0"),
		lanternHalo = Color3.fromHex("#7FF5D6"),
		lanternHaloAlpha = 0.22,
		--[[ Lit windows on the trunk (left, top), 8 by 10, each on a faint
		     warm block 14 by 16. ]]
		windows = { { -12, -120 }, { 8, -96 }, { -14, -70 }, { 8, -150 }, { -5, -178 } },
		window = Color3.fromHex("#FFD98A"),
		windowHalo = Color3.fromHex("#FFC76A"),
		windowHaloAlpha = 0.2,
	},

	--[[ The hero seen from behind and the pet at their heel: near-black
	     blocks with a thin mint rim of light, in their own units from where
	     they stand. A plain silhouette, never the player's avatar. ]]
	figure = Color3.fromHex("#02060B"),
	rim = Color3.fromHex("#58D8BC"),
	hero = {
		--[[ The bow across the back: a curve from above the left shoulder,
		     bowed out to the right, down past the right hip, its ends
		     standing clear of the body. A thin line of light runs along it
		     and along its string, so it reads on the dark back. ]]
		bow = { from = { -19, -60 }, bend = { 12, -36 }, to = { 19, -4 }, thick = 3, pieces = 9 },
		bowRim = { thick = 1, alpha = 0.5 },
		bowString = { thick = 0.8, alpha = 0.3 },
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
			-- a hood's fall behind the neck, boots, and three arrows in a quiver
			{ -9, -45, 18, 6 },
			{ -9, -3, 8, 3 },
			{ 1, -3, 8, 3 },
			{ 7, -53, 2, 10 },
			{ 10, -55, 2, 11 },
			{ 13, -52, 2, 9 },
		} :: { Block },
		--[[ The light catching the head and the shoulders, then the side that
		     faces the tree (head, arm, hem, leg) and the arrows' tips; the
		     fifth number is how solid. ]]
		rims = {
			{ -8, -57, 16, 1.6, 0.85 },
			{ -14, -39, 4, 1.3, 0.7 },
			{ 10, -39, 4, 1.3, 0.7 },
			{ -10, -41, 20, 1.3, 0.45 },
			{ 7, -57, 1.2, 16, 0.6 },
			{ 13, -39, 1.2, 17, 0.5 },
			{ 11, -22, 1.2, 5, 0.5 },
			{ 12, -17, 1.2, 7, 0.5 },
			{ 7, -16, 1.2, 13, 0.4 },
			{ 7, -53, 2, 1.2, 0.7 },
			{ 10, -55, 2, 1.2, 0.8 },
			{ 13, -52, 2, 1.2, 0.7 },
		} :: { Block },
		--[[ A scarf trailing from the neck (owner, 2026-11-12: the hero "should
		     be a little bit more noticeable"). It is the hero's own dark colour
		     with a line of light along its top (owner, of an amber one: "the
		     color of the scarf should match the player still"). It sways: its
		     end moves this many units up and down, this many times a second. ]]
		scarf = {
			rim = 1.2,
			rimAlpha = 0.6,
			pieces = { { -16, -44, 9, 4 }, { -23, -42, 8, 4 }, { -29, -39, 7, 3 } },
			sway = 1.6,
			speed = 0.3,
		},
		--[[ A pool of the tree's light behind the hero: this far above their
		     feet, this wide, this solid at its middle. ]]
		glow = { rise = 30, radius = 64, alpha = 0.24 },
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
		-- the light on its head and back, and one bright eye
		rims = {
			{ 13, -18, 11, 1.3, 0.8 },
			{ 0, -10, 13, 1.2, 0.6 },
			{ 20.5, -15.5, 1.6, 1.6, 0.9 },
		} :: { Block },
	},

	--[[ Small square motes that drift up and to the right and fade, each on
	     its own loop. Under Roblox's reduced motion they stand still. ]]
	mote = {
		colour = Color3.fromHex("#8FF5D8"),
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
		--[[ The gold runs over the letters' own box (`letterLine`), with
		     these stops. ]]
		gold = {
			{ at = 0, colour = Color3.fromHex("#FFFBE6") },
			{ at = 0.08, colour = Color3.fromHex("#FFFBE6") },
			{ at = 0.55, colour = Color3.fromHex("#FFE49C") },
			{ at = 1, colour = Color3.fromHex("#E6AE48") },
		},
		outline = Color3.fromHex("#03080D"),
		outlineThick = 4.5,
		shadowDrop = 5,
		--[[ The glow: soft rings round the letters (how far past the outline
		     each reaches; each is this see-through, so they add up towards
		     the letters) over a wide faint haze (the round glow picture, this
		     many times the logo's width and the words' height, this solid at
		     its middle; faint, so the tree under it stays teal). ]]
		glow = Color3.fromHex("#FFCE6E"),
		glowRings = { 5, 10, 16 },
		glowRingClear = 0.9,
		haze = { wide = 1.15, tall = 2, alpha = 0.22 },
		--[[ The streak of light under the words: this share of the logo's
		     width, this far under them, fading in from the left and ending
		     in a small arrowhead that overhangs its right end. ]]
		streak = {
			width = 0.86,
			gap = 13,
			thick = 3,
			from = Color3.fromHex("#FFF0BE"),
			mid = Color3.fromHex("#FFE9A8"),
			to = Color3.fromHex("#FFFFFF"),
			midAt = 0.55,
			glow = Color3.fromHex("#FFD678"),
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
		clouds = { { 236, 36, 150 }, { -24, 268, 120 }, { 290, 500, 120 } },
		bigStars = { { 34, 52 }, { 350, 150 }, { 22, 330 }, { 368, 420 } },
		farHills = {
			{ -6, 548, 52 },
			{ 36, 556, 40 },
			{ 96, 560, 44 },
			{ 236, 558, 50 },
			{ 296, 548, 46 },
			{ 350, 540, 50 },
		},
		pines = {
			{ 16, 566, 12 },
			{ 40, 566, 9 },
			{ 92, 580, 10 },
			{ 136, 572, 11 },
			{ 268, 576, 10 },
			{ 296, 576, 8 },
			{ 330, 562, 12 },
			{ 368, 562, 9 },
		},
		village = { { 346, 570 }, { 356, 576 }, { 338, 578 }, { 24, 574 }, { 34, 580 } },
		tufts = {
			{ 56, 600 },
			{ 20, 616 },
			{ 172, 616 },
			{ 192, 616 },
			{ 216, 636 },
			{ 250, 636 },
			{ 306, 644 },
			{ 372, 644 },
		},
		post = { x = 340, y = 644 },
		birds = { { 58, 50, 7 }, { 76, 42, 6 }, { 92, 54, 5 } },
		glowcaps = {
			{ 66, 600, 4 },
			{ 183, 616, 5 },
			{ 232, 636, 6 },
			{ 262, 636, 4 },
			{ 324, 644, 5 },
			{ 358, 644, 4 },
		},
		sign = { x = 36, y = 616 },
		shooting = { from = { 330, 14 }, to = { 262, 52 } },
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
		hero = { x = 96, y = 600, unit = 1.5 },
		pet = { x = 122, y = 600, unit = 1.25 },
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
		clouds = { { 40, 70, 170 }, { 590, 120, 190 }, { 150, 190, 120 } },
		bigStars = { { 120, 36 }, { 300, 96 }, { 566, 44 }, { 800, 150 } },
		farHills = {
			{ -10, 272, 70 },
			{ 50, 282, 60 },
			{ 150, 280, 60 },
			{ 230, 290, 50 },
			{ 520, 288, 60 },
			{ 600, 272, 60 },
			{ 690, 278, 70 },
			{ 780, 284, 70 },
		},
		pines = {
			{ 20, 290, 11 },
			{ 56, 290, 9 },
			{ 110, 300, 10 },
			{ 150, 300, 8 },
			{ 210, 296, 10 },
			{ 590, 298, 10 },
			{ 668, 288, 12 },
			{ 706, 288, 9 },
			{ 770, 300, 10 },
			{ 812, 300, 8 },
		},
		village = { { 676, 296 }, { 688, 302 }, { 700, 298 }, { 34, 300 }, { 46, 306 } },
		tufts = {
			{ 104, 300 },
			{ 234, 300 },
			{ 50, 318 },
			{ 72, 318 },
			{ 272, 318 },
			{ 322, 318 },
			{ 580, 330 },
			{ 650, 330 },
			{ 790, 330 },
		},
		post = { x = 716, y = 330 },
		birds = { { 640, 200, 7 }, { 660, 190, 6 }, { 676, 204, 5 } },
		glowcaps = {
			{ 114, 300, 4 },
			{ 62, 318, 5 },
			{ 290, 318, 5 },
			{ 334, 318, 4 },
			{ 600, 330, 5 },
			{ 668, 330, 4 },
			{ 742, 330, 5 },
			{ 820, 330, 4 },
		},
		sign = { x = 86, y = 318 },
		shooting = { from = { 760, 40 }, to = { 690, 84 } },
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
		hero = { x = 160, y = 300, unit = 1.35 },
		pet = { x = 188, y = 300, unit = 1.15 },
		motes = { count = 14, seed = 3, box = { 250, 100, 360, 190 } },
		logo = { y = 16, width = 430, unit = 0.84 },
		button = { width = 380, height = 72, gap = 14, words = 29 },
	} :: Design,
}

return table.freeze(TitleScene)
