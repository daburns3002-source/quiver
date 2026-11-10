--!strict
--[[
	How the story cutscene moves (owner, 2026-11-10: "have claude make an
	animated clip off of the reference images that codex has created already
	in claude design"; approved: "ok i like this cutscene"). Drawn by
	`UI/StoryCutscene` through `Util/StoryMotion`.

	Ported number for number from the approved Claude Design project "King
	Bloblin's Roar" (`cutscene.jsx` landscape, `cutscene-mobile.jsx` portrait),
	so the game draws what its exported videos show, from the frames already
	uploaded (`Config/Story.pictures`) instead of a paid video upload. The
	frames are only scaled and moved, never redrawn.

	Coordinates are the Design stage's pixels: every frame is 1280 x 720
	(`image`); the stage is `landscape.stage` or `portrait.stage`, fitted to
	the screen. Time is seconds from the first frame (`Story.lead` after the
	cutscene starts).

	A group is frames that share one camera move and dissolve into each
	other (`f`: frame numbers in show order, 1 to 38):
	- `s` scale from and to, `c` the stage point the camera centres on from
	  and to, eased by `e` (`ec` eases the centre separately, portrait only);
	- `dIn` the dissolve in from the group before (0.14 when nil; 0 is a hard
	  cut), `dPair` the dissolve between its own frames (0.3 when nil);
	- `shakes` {frame, amplitude px, decay /s}, `kicks` {frame, zoom}, a
	  steady `rumble`;
	- overlays: `ff` fireflies, `fall` falling leaves, `wind` blown leaves
	  (its strength), `speed` lines, `zoomLines`, `sparkle`, `rustle` (leaves
	  out of the bush at a point), `steam` puffs {x, y, side}, `roar`
	  droplets and rings from a point, `wave` rings, `flash` at a frame.
]]

export type Group = {
	f: { number },
	s: { number },
	c: { { number } },
	e: string,
	ec: string?,
	dIn: number?,
	dPair: number?,
	ff: boolean?,
	fall: boolean?,
	wind: number?,
	speed: boolean?,
	zoomLines: boolean?,
	sparkle: boolean?,
	rustle: { number }?,
	steam: { { number } }?,
	bigSteamAt: number?,
	roar: { number }?,
	wave: boolean?,
	flash: number?,
	shakes: { { number } }?,
	kicks: { { number } }?,
	rumble: number?,
}

export type Layout = {
	stage: Vector2,
	--[[ The camera's scale is multiplied by this: a portrait stage is taller
	     than a frame, so the frame is drawn at least that much larger. ]]
	base: number,
	groups: { Group },
	--[[ Where the screen-space overlays sit on this stage. ]]
	fireflies: { count: number, x: number, w: number, h: number },
	fallX: { number },
	speed: { x: number, span: number, y: number, h: number, fade: number },
	zoomFrom: Vector2,
}

local LANDSCAPE: { Group } = {
	{
		f = { 1 },
		s = { 1.0, 1.16 },
		c = { { 640, 360 }, { 615, 335 } },
		e = "drift",
		dIn = 0,
		ff = true,
		fall = true,
	},
	{
		f = { 2, 3 },
		s = { 1.1, 1.22 },
		c = { { 640, 340 }, { 600, 290 } },
		e = "drift",
		dPair = 0.5,
		ff = true,
	},
	{
		f = { 4 },
		s = { 1.04, 1.14 },
		c = { { 640, 320 }, { 690, 300 } },
		e = "drift",
		ff = true,
		sparkle = true,
	},
	{ f = { 5 }, s = { 1.05, 1.15 }, c = { { 620, 300 }, { 620, 260 } }, e = "drift", ff = true },
	{ f = { 6 }, s = { 1.02, 1.12 }, c = { { 640, 330 }, { 640, 300 } }, e = "snap", ff = true },
	{
		f = { 7, 8 },
		s = { 1.04, 1.18 },
		c = { { 760, 360 }, { 830, 320 } },
		e = "drift",
		dPair = 0.3,
		shakes = { { 8, 3, 3 } },
		rustle = { 850, 170 },
	},
	{
		f = { 9, 10, 11 },
		s = { 1.14, 1.14 },
		c = { { 720, 360 }, { 540, 360 } },
		e = "glide",
		dIn = 0.1,
		dPair = 0.08,
		speed = true,
	},
	{
		f = { 12, 13 },
		s = { 1.04, 1.15 },
		c = { { 520, 420 }, { 560, 380 } },
		e = "drift",
		dPair = 0.3,
		ff = true,
	},
	{
		f = { 14, 15 },
		s = { 1.06, 1.16 },
		c = { { 560, 400 }, { 560, 370 } },
		e = "drift",
		dPair = 0.3,
		ff = true,
		shakes = { { 15, 2.5, 0.8 } },
	},
	{ f = { 16 }, s = { 1.0, 1.14 }, c = { { 560, 300 }, { 580, 270 } }, e = "snap", ff = true },
	{
		f = { 17, 18 },
		s = { 1.04, 1.14 },
		c = { { 640, 320 }, { 640, 270 } },
		e = "drift",
		dPair = 0.3,
		ff = true,
	},
	{
		f = { 19, 20 },
		s = { 1.02, 1.12 },
		c = { { 640, 360 }, { 640, 320 } },
		e = "drift",
		dPair = 0.25,
		kicks = { { 20, 0.04 } },
	},
	{
		f = { 21, 22 },
		s = { 1.04, 1.16 },
		c = { { 640, 330 }, { 640, 290 } },
		e = "drift",
		dPair = 0.4,
		ff = true,
		steam = { { 455, 105, -1 }, { 830, 105, 1 } },
		bigSteamAt = 22,
		shakes = { { 22, 3, 0.2 } },
	},
	{
		f = { 23, 24 },
		s = { 1.14, 1.2 },
		c = { { 560, 400 }, { 530, 420 } },
		e = "drift",
		dPair = 0.25,
		shakes = { { 23, 6, 6 }, { 24, 3, 5 } },
	},
	{
		f = { 25, 26 },
		s = { 1.3, 1.32 },
		c = { { 620, 445 }, { 620, 275 } },
		e = "drift",
		dPair = 0.3,
		rumble = 2,
	},
	{
		f = { 27, 28 },
		s = { 1.04, 1.16 },
		c = { { 640, 360 }, { 640, 320 } },
		e = "drift",
		dPair = 0.3,
		steam = { { 370, 125, -1 }, { 890, 125, 1 } },
		shakes = { { 28, 2.5, 0.1 } },
	},
	{
		f = { 29, 30 },
		s = { 1.32, 1.1 },
		c = { { 640, 330 }, { 640, 360 } },
		e = "snap",
		dIn = 0,
		dPair = 0.15,
		shakes = { { 29, 16, 2.2 }, { 30, 10, 2.5 } },
		kicks = { { 30, 0.07 } },
		roar = { 640, 300 },
		flash = 29,
	},
	{
		f = { 31, 32 },
		s = { 1.3, 1.1 },
		c = { { 520, 300 }, { 600, 360 } },
		e = "snap",
		dIn = 0.08,
		dPair = 0.2,
		shakes = { { 31, 12, 2 }, { 32, 7, 2.5 } },
		kicks = { { 32, 0.05 } },
		roar = { 515, 280 },
		flash = 31,
		wind = 1,
	},
	{
		f = { 33 },
		s = { 1.37, 1.4 },
		c = { { 470, 360 }, { 810, 360 } },
		e = "drift",
		dIn = 0.15,
		rumble = 2,
		wave = true,
		wind = 1,
	},
	{
		f = { 34, 35 },
		s = { 1.04, 1.14 },
		c = { { 640, 380 }, { 640, 340 } },
		e = "drift",
		dPair = 0.3,
		ff = true,
		wind = 0.35,
	},
	{
		f = { 36 },
		s = { 1.18, 1.05 },
		c = { { 640, 380 }, { 640, 360 } },
		e = "snap",
		ff = true,
		wind = 0.35,
	},
	{
		f = { 37, 38 },
		s = { 1.0, 1.22 },
		c = { { 640, 380 }, { 640, 320 } },
		e = "drift",
		dPair = 0.3,
		zoomLines = true,
		wind = 0.35,
	},
}

--[[ The portrait groups: the landscape ones with their own camera (and a
     few gentler pushes and moved steam), as `cutscene-mobile.jsx` has them. ]]
local PORTRAIT_CAMERA: { [number]: { [string]: any } } = {
	[2] = { c = { { 620, 330 }, { 595, 280 } } },
	[3] = { c = { { 680, 380 }, { 705, 420 } } },
	[4] = { c = { { 600, 300 }, { 600, 260 } } },
	[5] = { c = { { 670, 330 }, { 690, 300 } }, ec = "drift" },
	[6] = { c = { { 800, 360 }, { 850, 300 } } },
	[7] = { c = { { 590, 370 }, { 330, 380 } } },
	[8] = { c = { { 300, 420 }, { 770, 260 } } },
	[9] = { c = { { 520, 380 }, { 610, 330 } } },
	[10] = { c = { { 590, 300 }, { 640, 280 } }, ec = "drift" },
	[11] = { c = { { 680, 320 }, { 680, 270 } } },
	[12] = { s = { 1.0, 1.06 }, c = { { 630, 380 }, { 630, 350 } }, kicks = { { 20, 0.03 } } },
	[13] = { steam = { { 525, 105, -1 }, { 755, 105, 1 } } },
	[14] = { c = { { 480, 360 }, { 520, 380 } } },
	[15] = { c = { { 900, 445 }, { 600, 275 } } },
	[16] = { steam = { { 480, 125, -1 }, { 800, 125, 1 } } },
	[19] = { c = { { 150, 360 }, { 1045, 360 } } },
	[20] = { c = { { 200, 360 }, { 900, 340 } } },
	[21] = { c = { { 350, 390 }, { 820, 380 } }, ec = "drift" },
	[22] = { s = { 1.0, 1.1 }, c = { { 620, 400 }, { 615, 360 } } },
}

local function portraitGroups(): { Group }
	local out = {}
	for i, group in LANDSCAPE do
		local copy = table.clone(group) :: any
		local changes: { [string]: any } = PORTRAIT_CAMERA[i] or {}
		for key, value in changes do
			copy[key] = value
		end
		out[i] = copy
	end
	return out
end

local LEAF_A = { "...oo.", "..olko", ".olldo", "oldddo", "odoo..", "o....." }

--[[ A sprite flipped left to right. ]]
local function mirror(rows: { string }): { string }
	local out = {}
	for i, row in rows do
		out[i] = row:reverse()
	end
	return out
end

local StoryMotion = {
	--[[ Every frame's size on the stage. ]]
	image = Vector2.new(1280, 720),

	landscape = {
		stage = Vector2.new(1280, 720),
		base = 1,
		groups = LANDSCAPE,
		fireflies = { count = 14, x = 60, w = 1160, h = 560 },
		fallX = { 100, 1080 },
		speed = { x = 480, span = 900, y = 170, h = 400, fade = 120 },
		zoomFrom = Vector2.new(640, 300),
	} :: Layout,

	portrait = {
		stage = Vector2.new(720, 1280),
		base = 1280 / 720,
		groups = portraitGroups(),
		fireflies = { count = 16, x = 40, w = 640, h = 1160 },
		fallX = { 60, 600 },
		speed = { x = 380, span = 460, y = 380, h = 520, fade = 100 },
		zoomFrom = Vector2.new(360, 560),
	} :: Layout,

	--[[ The fade in from black at the start, the fade out into the closing
	     black, and the roar's flash (seconds). ]]
	fadeIn = 0.5,
	fadeOut = 0.25,
	flashFor = 0.18,
	flashPeak = 0.45,
	flashColour = Color3.fromRGB(255, 251, 230),
	ringColour = Color3.fromRGB(244, 250, 210),

	--[[ The pixel sprites: each character is a block of that palette colour
	     (`.` is empty; `h` is a dim `y`, the firefly's glow). ]]
	palette = {
		o = Color3.fromRGB(29, 53, 16),
		l = Color3.fromRGB(143, 214, 58),
		d = Color3.fromRGB(76, 154, 32),
		k = Color3.fromRGB(212, 245, 122),
		w = Color3.fromRGB(255, 255, 255),
		g = Color3.fromRGB(230, 224, 214),
		s = Color3.fromRGB(179, 171, 159),
		y = Color3.fromRGB(255, 210, 63),
		Y = Color3.fromRGB(255, 246, 184),
		h = Color3.fromRGB(255, 210, 63),
	} :: { [string]: Color3 },
	dim = { h = 0.35 } :: { [string]: number },
	sprites = {
		leafA = LEAF_A,
		leafB = mirror(LEAF_A),
		leafC = { ".oooo.", "olllko", "oddddo", ".oooo." },
		puff = {
			"..ssss..",
			".swwwws.",
			"swwwwwws",
			"swwwwgws",
			"swwwgggs",
			".sggggs.",
			"..ssss..",
		},
		fly = { "..h..", ".hyh.", "hyYyh", ".hyh.", "..h.." },
		drop = { ".oo..", "olko.", "olllo", "oddlo", ".ooo." },
		spark = { "..Y..", "..y..", "YyYyY", "..y..", "..Y.." },
	} :: { [string]: { string } },
	sparks = { { 560, 250 }, { 760, 230 }, { 470, 420 }, { 880, 330 }, { 640, 560 }, { 990, 420 } },
}

return table.freeze(StoryMotion)
