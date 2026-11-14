--!strict
--[[
	The trails (owner, 2026-11-13: "ANOTHER FOR CREATING THE TRAILS"; the
	roster and Starfall picked from Codex's sheets in
	`assets/concepts/blocky/ui/trails/`): what goes in the Gear sheet's TRAIL
	slot. Looks only -- a trail adds no power (player power is pets and
	weapons).

	Each look is its Claude Design build's, number for number (owner,
	2026-11-13: "start making the trails in design that were agreed upon
	earlier"): every build was made from its Codex panel, and its project
	is named on its entry (`design`). `Fx/PlayerTrails` draws them. A
	build's numbers are in its own units; here they are in tiles (one cube
	of the build's ribbon, `tile` studs) and rows (one tile of ribbon, run
	past at `pace` rows a second), so a still of the game is a still of
	the build. Times are seconds.

	Each area has three, earned three ways (`earn`):
	- `Gems`: bought on the Gear sheet's TRAILS tab for `gemPrices[rarity]`
	  times the area's number (the weapon store's numbers, `Config/Shop`).
	- `Boss`: given the first time the area's boss falls, and to anyone
	  who had already beaten it before trails existed.
	- `Endless`: Starfall, the one Mythic (owner: "should be a reward for
	  getting to a certain floor on endless with all 3 classes"), given once
	  `endless.floor` has been reached in Endless as each of
	  `endless.classes`.

	Every Legendary and Mythic glows (rule 12): `glow` and a `light`, and
	Neon in its ribbon or pieces, pinned by `tests/Trails.spec`. One
	picture an item: `icon` is the only one, on every screen (Codex's, cut
	by `assets/ui/trails/cutout.py`).
]]

--[[ One column of the ribbon, across it from the left. ]]
export type Column = {
	colour: Color3,
	--[[ Some tiles are this colour instead, this share of them. ]]
	streak: Color3?,
	streaks: number?,
	--[[ The colour of a tile its first `freshRows` rows (a hot head). ]]
	fresh: Color3?,
	freshRows: number?,
	--[[ Tiles tall; a `tallShare` of them `tall` instead (heaps). ]]
	height: number,
	tall: number?,
	tallShare: number?,
	--[[ Times the ribbon's opacity. ]]
	alpha: number?,
	neon: boolean?,
	--[[ Rows old over which this column fades out early: the ribbon
	     narrowing from the outside in. ]]
	gone: { number }?,
	--[[ Each tile goes at its own row between these (the ribbon
	     dissolving, edges first), shrinking away if the ribbon `shrink`s. ]]
	dissolve: { number }?,
	--[[ The share of squares this column covers at all (lumps). ]]
	chance: number?,
	--[[ Rows old before it shows (the head held clear of the feet). ]]
	from: number?,
}

--[[ A silk thread: a strip a tile long laid every tile run, `width`
     tiles across and `lift` tiles up, weaving `amp` tiles either side
     once every `wave` tiles (never past `limit`). ]]
export type Thread = {
	colour: Color3,
	height: number,
	neon: boolean?,
	alpha: number?,
	gone: { number }?,
	amp: number,
	wave: number,
	phase: number,
	limit: number,
	lift: number,
	width: number,
}

export type Ribbon = {
	columns: { Column },
	threads: { Thread }?,
	--[[ Rows old over which it fades out; `curve` its power (none: eased). ]]
	fade: { number },
	curve: number?,
	alpha: number,
	--[[ Each tile's brightness, from to. ]]
	jitter: { number },
	--[[ Rows a tile takes to grow in, and to shrink away, in `steps`. ]]
	grow: number?,
	shrink: number?,
	steps: number?,
}

--[[ One block of a piece, in tiles at size 1, from the piece's origin. ]]
export type Block = {
	size: Vector3,
	at: Vector3?,
	--[[ Degrees about the piece's up. ]]
	turn: number?,
	--[[ Times the piece's colour; or its own `colour`. ]]
	shade: number?,
	colour: Color3?,
	--[[ Its colour while the piece is blinked off (it lights to `colour`). ]]
	dim: Color3?,
	neon: boolean?,
	alpha: number?,
	--[[ A glow round the piece: shows only while it blinks on. ]]
	shell: boolean?,
}

--[[ A piece the trail throws: what it is and how it moves. Ranges are
     {from, to}, picked for each piece; shares are of its life. ]]
export type Piece = {
	blocks: { Block },
	colours: { Color3 },
	jitter: { number }?,
	size: { number },
	--[[ Thrown a second while running (`Trails.idle` of it standing). ]]
	rate: number,
	life: { number },
	--[[ Rides along behind the player (a swarm), not left where thrown. ]]
	follow: boolean?,
	--[[ Rows back along the ribbon it starts, and tiles from its middle
	     (either side; `sides = 1`: the right only). ]]
	back: { number }?,
	side: { number }?,
	sides: number?,
	--[[ Tiles further out it goes, between these shares. ]]
	out: { number }?,
	outAt: { number }?,
	--[[ Tiles up: where it starts, its `peak` by `peakAt`, then where it
	     `settle`s by `settleAt` (eased). ]]
	height: { number }?,
	peak: { number }?,
	peakAt: { number }?,
	settle: { number }?,
	--[[ The share it starts settling at (default: its peak's). ]]
	settleFrom: number?,
	settleAt: { number }?,
	--[[ Tiles it sways side to side, `swayTurns` times a life. ]]
	sway: { number }?,
	swayTurns: number?,
	--[[ A `follow` piece: tiles it slides back as it is left behind, and
	     tiles a second it keeps creeping back. ]]
	slide: number?,
	creep: { number }?,
	--[[ Bobbing: tiles up and down, once in `bobPeriod` seconds. ]]
	bob: number?,
	bobPeriod: number?,
	--[[ Turning: whole tumbles about a slant (done by `turnEnd`), whole
	     turns about its up over its life, degrees a second either way,
	     and a rocking tilt in radians. ]]
	turns: { number }?,
	turnEnd: number?,
	yawTurns: { number }?,
	spin: number?,
	tilt: { number }?,
	--[[ Shares of its life it grows in and shrinks away over, in `steps`. ]]
	grow: number?,
	shrink: number?,
	steps: number?,
	--[[ The share of its life it starts fading at. ]]
	fadeFrom: number?,
	--[[ Blinking: seconds a blink (one picked), lit `duty` of each, and
	     how much bigger it is lit. ]]
	blink: { number }?,
	duty: number?,
	pulse: number?,
}

export type Trail = {
	name: string,
	rarity: string,
	--[[ The area it belongs to, by `Config/Economy` key. ]]
	area: string,
	earn: string,
	--[[ Its Claude Design project. ]]
	design: string,
	ribbon: Ribbon,
	pieces: { Piece },
	--[[ Glowing: a light rides with it and breathes. ]]
	glow: boolean,
	light: Color3?,
	lightRange: number?,
	lightBrightness: number?,
	icon: string,
}

local function rgb(r: number, g: number, b: number): Color3
	return Color3.fromRGB(r, g, b)
end

local function hex(code: string): Color3
	return Color3.fromHex(code)
end

local V = Vector3.new

local Trails = {
	--[[ The order the TRAILS tab lists them in (areas in order, then
	     rarity), and every trail there is. ]]
	order = {
		"LeafDrift",
		"FireflyWake",
		"RoyalGoo",
		"BramblePollen",
		"CrowFeathers",
		"BroodSilk",
		"BubbleStream",
		"SplashWake",
		"TideBell",
		"BogSpores",
		"GlowcapPath",
		"GulpsBubbles",
		"Starfall",
	},

	--[[ Starfall's: this floor of Endless, reached as each of these
	     classes (counted from the first run after trails came in). ]]
	endless = {
		floor = 50,
		classes = { "Ranger", "Arcanist", "Warden" },
	},

	--[[ A bought trail's price in gems, times its area's number (Mossy
	     Glade 1, Thornwood 2, the Drowned Village 3, Bogheart Caverns 4). ]]
	gemPrices = { Rare = 180, Epic = 450 } :: { [string]: number },

	--[[ The areas in order, for that number (`Config/Shop.crates`). ]]
	areas = { "MossyGlade", "Thornwood", "DrownedVillage", "BogheartCaverns" },

	--[[ Studs a tile: four tiles are a player's shoulders. ]]
	tile = 0.55,
	--[[ Rows a second a ribbon ages: a player running (`Balance.Player.
	     moveSpeed`, 6.9) passes this many tiles a second. ]]
	pace = 12.5,

	--[[ What standing still throws of a trail's pieces: a little, so a
	     glowing trail still shines, not a heap at the player's feet. ]]
	idle = 0.15,

	--[[ A dash (moving faster than `speed` studs a second) or putting the
	     trail on throws `count` of its pieces out all round, at most once
	     in `gap` seconds; a glowing trail's light breathes, `depth` either
	     side, `rate` times a second. ]]
	burst = { speed = 30, count = 16, gap = 0.5 },
	pulse = { rate = 0.8, depth = 0.3 },

	trails = {
		-- Mossy Glade
		LeafDrift = {
			name = "LEAF DRIFT",
			rarity = "Rare",
			area = "MossyGlade",
			earn = "Gems",
			design = "https://claude.ai/design/p/51937c46-883a-4029-8b0b-eb1f528bd40d",
			-- four tiles across, the middle two a lighter, taller stripe;
			-- it narrows to one (left edge at row 20, right 27, stripe 32)
			ribbon = {
				columns = {
					{ colour = hex("6cc94a"), height = 0.1, gone = { 19.5, 20.5 } },
					{ colour = hex("b2ec6a"), height = 0.16, gone = { 31.5, 32.5 } },
					{ colour = hex("b2ec6a"), height = 0.16 },
					{ colour = hex("6cc94a"), height = 0.1, gone = { 26.5, 27.5 } },
				},
				fade = { 6, 37 },
				curve = 1.3,
				alpha = 0.92,
				jitter = { 0.94, 1.04 },
			},
			pieces = {
				-- a square leaf with a darker stripe corner to corner
				-- (both faces), off the ribbon's edge: it tumbles once or
				-- twice falling, lands flat beside it, lies, and fades
				{
					blocks = {
						{ size = V(1.1, 0.11, 1.1) },
						{ size = V(1.36, 0.02, 0.2), at = V(0, 0.065, 0), turn = 45, shade = 0.53 },
						{
							size = V(1.36, 0.02, 0.2),
							at = V(0, -0.065, 0),
							turn = 45,
							shade = 0.53,
						},
					},
					colours = { hex("cde63a"), hex("6fcb3f") },
					jitter = { 0.95, 1.05 },
					size = { 1, 1 },
					rate = 5.1,
					life = { 2.72, 2.72 },
					back = { 0, 0.5 },
					side = { 2.2, 2.2 },
					out = { 0.3, 4.2 },
					outAt = { 0, 0.2 },
					height = { 1.4, 3 },
					settle = { 0.055, 0.055 },
					settleAt = { 0.18, 0.41 },
					turns = { 1, 2 },
					turnEnd = 0.25,
					grow = 0.03,
					fadeFrom = 0.53,
				},
			},
			glow = false,
			icon = "rbxassetid://83559446857743",
		},
		FireflyWake = {
			name = "FIREFLY WAKE",
			rarity = "Epic",
			area = "MossyGlade",
			earn = "Gems",
			design = "https://claude.ai/design/p/7b366239-2a49-4460-b08e-14d3a91660ad",
			-- dark edges, a green band with brighter streaks; the right
			-- edge goes first, then the left, then the right of the band
			ribbon = {
				columns = {
					{ colour = hex("1b5321"), height = 0.1, gone = { 15.6, 19.7 } },
					{ colour = hex("2a7029"), streak = hex("3a8a32"), streaks = 0.2, height = 0.1 },
					{
						colour = hex("2a7029"),
						streak = hex("3a8a32"),
						streaks = 0.2,
						height = 0.1,
						gone = { 19.7, 24.4 },
					},
					{ colour = hex("1b5321"), height = 0.1, gone = { 10.9, 15.6 } },
				},
				fade = { 7.8, 26 },
				alpha = 1,
				jitter = { 0.9, 1.08 },
			},
			pieces = {
				-- small fireflies all along it, and a few big ones near the
				-- front: a yellow core in three glows, blinking, rising and
				-- drifting out while they keep up with the player (cores
				-- about twice the build's, whose tiny ones read through its
				-- bloom and close camera but vanished in Play)
				{
					blocks = {
						{
							size = V(1, 1, 1),
							colour = hex("ffda36"),
							dim = hex("5e500c"),
							neon = true,
						},
						{
							size = V(1.6, 1.6, 1.6),
							colour = hex("ffdc45"),
							neon = true,
							alpha = 0.62,
							shell = true,
						},
						{
							size = V(2.3, 2.3, 2.3),
							colour = hex("ffdc45"),
							neon = true,
							alpha = 0.3,
							shell = true,
						},
						{
							size = V(3.1, 3.1, 3.1),
							colour = hex("ffbf2a"),
							neon = true,
							alpha = 0.13,
							shell = true,
						},
					},
					colours = { hex("ffda36") },
					size = { 0.22, 0.32 },
					rate = 4.8,
					life = { 2, 3 },
					follow = true,
					back = { 1, 16 },
					slide = 1.38,
					creep = { 0.1, 0.5 },
					side = { 0, 1 },
					out = { 0.5, 4.7 },
					outAt = { 0, 0.3 },
					height = { 0.4, 0.5 },
					settle = { 1.6, 5 },
					sway = { 0.14, 0.14 },
					swayTurns = 1.2,
					grow = 0.12,
					shrink = 0.2,
					blink = { 0.75, 1, 1.5, 2, 3 },
					duty = 0.62,
				},
				{
					blocks = {
						{
							size = V(1, 1, 1),
							colour = hex("ffda36"),
							dim = hex("5e500c"),
							neon = true,
						},
						{
							size = V(1.6, 1.6, 1.6),
							colour = hex("ffdc45"),
							neon = true,
							alpha = 0.62,
							shell = true,
						},
						{
							size = V(2.3, 2.3, 2.3),
							colour = hex("ffdc45"),
							neon = true,
							alpha = 0.3,
							shell = true,
						},
						{
							size = V(3.1, 3.1, 3.1),
							colour = hex("ffbf2a"),
							neon = true,
							alpha = 0.13,
							shell = true,
						},
					},
					colours = { hex("ffda36") },
					size = { 0.45, 0.6 },
					rate = 1.6,
					life = { 2, 3 },
					follow = true,
					back = { 0.5, 4.5 },
					slide = 1.38,
					creep = { 0.1, 0.5 },
					side = { 0, 1 },
					out = { 0.5, 4.7 },
					outAt = { 0, 0.3 },
					height = { 0.7, 0.8 },
					settle = { 1.9, 5.3 },
					sway = { 0.14, 0.14 },
					swayTurns = 1.2,
					grow = 0.12,
					shrink = 0.2,
					blink = { 0.75, 1, 1.5, 2, 3 },
					duty = 0.62,
				},
			},
			glow = false,
			icon = "rbxassetid://98989425582849",
		},
		RoyalGoo = {
			name = "ROYAL GOO",
			rarity = "Legendary",
			area = "MossyGlade",
			earn = "Boss",
			design = "https://claude.ai/design/p/6cf664c1-451a-4c28-9251-c339baf79599",
			-- a cube-tall jelly, five across and lumpy at both edges, lime
			-- brightest in its core; held clear of the feet, it grows up
			-- in steps from the core out and dissolves edges first
			ribbon = {
				columns = {
					{
						colour = hex("5fbf15"),
						height = 1,
						chance = 0.38,
						from = 4.8,
						dissolve = { 27.85, 29.05 },
					},
					{
						colour = hex("78d81e"),
						height = 1,
						chance = 0.82,
						from = 4.45,
						dissolve = { 29.35, 30.55 },
					},
					{
						colour = hex("a8f536"),
						height = 1,
						from = 4.1,
						dissolve = { 30.85, 32.05 },
					},
					{
						colour = hex("7fd424"),
						height = 1,
						neon = true,
						from = 3.75,
						dissolve = { 32.35, 33.55 },
					},
					{
						colour = hex("a8f536"),
						height = 1,
						from = 4.1,
						dissolve = { 30.85, 32.05 },
					},
					{
						colour = hex("78d81e"),
						height = 1,
						chance = 0.82,
						from = 4.45,
						dissolve = { 29.35, 30.55 },
					},
					{
						colour = hex("5fbf15"),
						height = 1,
						chance = 0.38,
						from = 4.8,
						dissolve = { 27.85, 29.05 },
					},
				},
				fade = { 36, 36.5 },
				alpha = 0.74,
				jitter = { 0.9, 1.08 },
				grow = 1.6,
				shrink = 1.5,
				steps = 3,
			},
			pieces = {
				-- a goo cube with a lighter top: it swells out of the
				-- ribbon's side, runs down it, oozes out on the floor,
				-- sits, and shrinks away in steps
				{
					blocks = {
						{
							size = V(1, 0.85, 1),
							at = V(0, 0.425, 0),
							colour = hex("8fe82a"),
							neon = true,
							alpha = 0.74,
						},
						{
							size = V(1, 0.15, 1),
							at = V(0, 0.925, 0),
							colour = hex("e6ffa0"),
							neon = true,
							alpha = 0.74,
						},
					},
					colours = { hex("8fe82a") },
					size = { 0.35, 0.6 },
					rate = 2.8,
					life = { 1.05, 1.6 },
					back = { 6.6, 9.5 },
					side = { 2.7, 3.6 },
					out = { 0.6, 1.5 },
					outAt = { 0.27, 0.45 },
					height = { 0.5, 0.6 },
					peakAt = { 0.09, 0.09 },
					settle = { 0, 0 },
					settleAt = { 0.27, 0.27 },
					grow = 0.09,
					shrink = 0.09,
					steps = 3,
				},
				-- a gold crown with a lime gem, hovering over and beside the
				-- ribbon, bobbing; every second it flashes bright and big
				{
					blocks = {
						{
							size = V(5, 2, 2),
							at = V(0, 1, 0),
							colour = hex("ffe680"),
							dim = hex("f5b820"),
						},
						{
							size = V(1, 1, 2),
							at = V(-2, 2.5, 0),
							colour = hex("fff3a6"),
							dim = hex("f7c22a"),
						},
						{
							size = V(1, 1, 2),
							at = V(2, 2.5, 0),
							colour = hex("fff3a6"),
							dim = hex("f7c22a"),
						},
						{
							size = V(1, 2, 2),
							at = V(0, 3, 0),
							colour = hex("fff3a6"),
							dim = hex("f7c22a"),
						},
						{
							size = V(1, 1, 0.4),
							at = V(0, 1, 1.2),
							colour = hex("9cf531"),
							neon = true,
						},
					},
					colours = { hex("f5b820") },
					size = { 0.3, 0.3 },
					rate = 2.4,
					life = { 1.8, 2 },
					back = { 6.5, 7.6 },
					side = { 0, 5.2 },
					height = { 1.45, 1.75 },
					bob = 0.125,
					bobPeriod = 0.96,
					tilt = { 0, 0 },
					grow = 0.05,
					shrink = 0.05,
					steps = 3,
					blink = { 0.96 },
					duty = 0.14,
					pulse = 0.25,
				},
			},
			glow = true,
			light = hex("9dff3a"),
			icon = "rbxassetid://73952091491527",
		},
		-- Thornwood
		BramblePollen = {
			name = "BRAMBLE POLLEN",
			rarity = "Rare",
			area = "Thornwood",
			earn = "Gems",
			design = "https://claude.ai/design/p/cad2a5c9-093c-4b18-8242-7626fc0b1151",
			-- a hot magenta ribbon three across, its middle pale pink; the
			-- sides thin away towards its end
			ribbon = {
				columns = {
					{ colour = hex("d60acf"), height = 0.18, neon = true, gone = { 12, 34 } },
					{ colour = hex("e070e0"), height = 0.18, neon = true },
					{ colour = hex("d60acf"), height = 0.18, neon = true, gone = { 12, 34 } },
				},
				fade = { 9.4, 36 },
				alpha = 0.85,
				jitter = { 0.88, 1.08 },
			},
			pieces = {
				-- a glowing pollen cube sitting on the ribbon: it grows,
				-- lifts off, drifts out, tilts and turns, and shrinks away
				{
					blocks = {
						{ size = V(1, 1, 1), colour = hex("d42cbc"), neon = true },
					},
					colours = { hex("d42cbc") },
					size = { 0.88, 1.08 },
					rate = 3.5,
					life = { 2.8, 4.2 },
					back = { 2, 23 },
					side = { 0.2, 1 },
					out = { 0.8, 1.8 },
					outAt = { 0.1, 1 },
					height = { 0.68, 0.72 },
					settle = { 1.4, 2 },
					settleAt = { 1, 1 },
					sway = { 0.06, 0.16 },
					swayTurns = 0.7,
					spin = 80,
					tilt = { 0.25, 0.6 },
					grow = 0.13,
					shrink = 0.26,
				},
				{
					blocks = {
						{ size = V(1, 1, 1), colour = hex("d42cbc"), neon = true },
					},
					colours = { hex("d42cbc") },
					size = { 1.4, 1.56 },
					rate = 1.4,
					life = { 2.6, 3.3 },
					back = { 1.4, 4.6 },
					side = { 0.2, 0.5 },
					out = { 0.8, 1.4 },
					outAt = { 0.1, 1 },
					height = { 0.9, 0.96 },
					settle = { 1.5, 1.9 },
					settleAt = { 1, 1 },
					sway = { 0.06, 0.16 },
					swayTurns = 0.7,
					spin = 80,
					tilt = { 0.25, 0.6 },
					grow = 0.15,
					shrink = 0.3,
				},
			},
			glow = false,
			icon = "rbxassetid://95388423540752",
		},
		CrowFeathers = {
			name = "CROW FEATHERS",
			rarity = "Epic",
			area = "Thornwood",
			earn = "Gems",
			design = "https://claude.ai/design/p/5bebf579-3ccb-473e-bd8c-1d5c058c1c69",
			-- smoky: dark violet edges, a violet core white-hot at its
			-- head, faint wisps beside it; edges dissolve first
			ribbon = {
				columns = {
					{
						colour = hex("4a1f80"),
						height = 0.08,
						alpha = 0.5,
						chance = 0.275,
						from = 3.2,
					},
					{
						colour = hex("4a1f80"),
						height = 0.12,
						alpha = 0.78,
						dissolve = { 13.4, 34.8 },
					},
					{
						colour = hex("8a3ad6"),
						fresh = hex("d9a6ff"),
						freshRows = 2.4,
						height = 0.2,
						dissolve = { 22.4, 36.9 },
					},
					{
						colour = hex("8a3ad6"),
						fresh = hex("d9a6ff"),
						freshRows = 2.4,
						height = 0.2,
						dissolve = { 22.4, 36.9 },
					},
					{
						colour = hex("4a1f80"),
						height = 0.12,
						alpha = 0.78,
						dissolve = { 13.4, 34.8 },
					},
					{
						colour = hex("4a1f80"),
						height = 0.08,
						alpha = 0.5,
						chance = 0.275,
						from = 3.2,
					},
				},
				fade = { 0, 32 },
				curve = 1.2,
				alpha = 1,
				jitter = { 1, 1 },
			},
			pieces = {
				-- a black feather on a violet rim: it lifts off the edge,
				-- drifts out, flutters down turning and tilting, and lands
				{
					blocks = {
						{ size = V(1, 0.08, 1), at = V(0, -0.04, 0), colour = hex("4e3372") },
						{ size = V(0.76, 0.08, 0.76), at = V(0, 0.04, 0), colour = hex("170d23") },
					},
					colours = { hex("170d23") },
					size = { 0.64, 1.12 },
					rate = 12.5,
					life = { 2.56, 2.56 },
					back = { 0.4, 0.4 },
					side = { 2.56, 2.56 },
					out = { 0.6, 3.4 },
					height = { 0.48, 0.72 },
					peak = { 1.28, 3.28 },
					peakAt = { 0.22, 0.22 },
					settle = { 0.2, 0.52 },
					settleAt = { 0.86, 0.86 },
					sway = { 0.2, 0.52 },
					swayTurns = 2,
					yawTurns = { 1, 3 },
					tilt = { 0.35, 0.8 },
					grow = 0.05,
					shrink = 0.13,
				},
			},
			glow = false,
			icon = "rbxassetid://105803115814322",
		},
		BroodSilk = {
			name = "BROOD SILK",
			rarity = "Legendary",
			area = "Thornwood",
			earn = "Boss",
			design = "https://claude.ai/design/p/e75231af-7c5d-4312-94b5-3b59be877948",
			-- no tiles: five glowing silk threads, half a tile wide, each
			-- at its own height so none passes through another, weaving
			-- across each other in long and short waves
			ribbon = {
				columns = {},
				threads = {
					{
						colour = hex("8a4fe0"),
						height = 0.06,
						neon = true,
						amp = 1.15,
						wave = 16,
						phase = 0,
						limit = 1.65,
						lift = 0.12,
						width = 0.5,
					},
					{
						colour = hex("7e43d8"),
						height = 0.06,
						neon = true,
						amp = 0.75,
						wave = 8,
						phase = 1.3,
						limit = 1.65,
						lift = 0.25,
						width = 0.5,
					},
					{
						colour = hex("8a4adf"),
						height = 0.06,
						neon = true,
						amp = 1.25,
						wave = 16,
						phase = 2.4,
						limit = 1.65,
						lift = 0.38,
						width = 0.5,
					},
					{
						colour = hex("7647d6"),
						height = 0.06,
						neon = true,
						amp = 0.8,
						wave = 8,
						phase = 4.4,
						limit = 1.65,
						lift = 0.51,
						width = 0.5,
					},
					{
						colour = hex("8a45dc"),
						height = 0.06,
						neon = true,
						amp = 1.1,
						wave = 16,
						phase = 4,
						limit = 1.65,
						lift = 0.64,
						width = 0.5,
					},
				},
				fade = { 10.5, 16 },
				alpha = 1,
				jitter = { 1, 1 },
			},
			pieces = {
				-- blue-white eye-sparks beside the threads and above them,
				-- turning slowly and flashing white now and then
				{
					blocks = {
						{
							size = V(1, 1, 1),
							colour = hex("ffffff"),
							dim = hex("8befff"),
							neon = true,
						},
					},
					colours = { hex("8befff") },
					size = { 0.29, 0.39 },
					rate = 3.9,
					life = { 1.2, 1.2 },
					back = { 0.6, 0.6 },
					side = { 2.2, 2.4 },
					height = { 0.45, 1.05 },
					bob = 0.08,
					bobPeriod = 2.5,
					yawTurns = { 0, 0 },
					spin = 25,
					grow = 0.07,
					shrink = 0.12,
					blink = { 1, 1.25, 1.67, 2.5 },
					duty = 0.3,
					pulse = 0.35,
				},
				{
					blocks = {
						{
							size = V(1, 1, 1),
							colour = hex("ffffff"),
							dim = hex("8befff"),
							neon = true,
						},
					},
					colours = { hex("8befff") },
					size = { 0.29, 0.36 },
					rate = 3.9,
					life = { 1.2, 1.2 },
					back = { 0.6, 0.6 },
					side = { 0.2, 1.2 },
					height = { 1.1, 1.5 },
					bob = 0.08,
					bobPeriod = 2.5,
					spin = 25,
					grow = 0.07,
					shrink = 0.12,
					blink = { 1, 1.25, 1.67, 2.5 },
					duty = 0.3,
					pulse = 0.35,
				},
				-- a violet crystal of three stacked blocks, each narrower,
				-- that rises out of the floor beside the threads, stands,
				-- and sinks back
				{
					blocks = {
						{
							size = V(0.8, 1.1, 0.8),
							at = V(0, 0.55, 0),
							colour = hex("5b24c4"),
							neon = true,
						},
						{
							size = V(0.54, 0.85, 0.54),
							at = V(0, 1.525, 0),
							colour = hex("9452ff"),
							neon = true,
						},
						{
							size = V(0.28, 0.6, 0.28),
							at = V(0, 2.25, 0),
							colour = hex("e6ccff"),
							neon = true,
						},
					},
					colours = { hex("9452ff") },
					size = { 0.8, 1.1 },
					rate = 6.25,
					life = { 1.05, 1.05 },
					back = { 0.6, 0.6 },
					side = { 3.45, 3.7 },
					height = { -2.85, -2.85 },
					peak = { 0, 0 },
					peakAt = { 0.15, 0.15 },
					settle = { -2.85, -2.85 },
					settleFrom = 0.78,
					settleAt = { 1, 1 },
				},
			},
			glow = true,
			light = rgb(172, 112, 255),
			icon = "rbxassetid://119075661571853",
		},
		-- Drowned Village
		BubbleStream = {
			name = "BUBBLE STREAM",
			rarity = "Rare",
			area = "DrownedVillage",
			earn = "Gems",
			design = "https://claude.ai/design/p/e8b89a0f-e2ed-47dc-b60b-e658d5b38228",
			-- see-through sky-blue edges round a pale core with white
			-- glints; it narrows four, three, two, one, fading in steps,
			-- and breaks into loose chips at its end
			ribbon = {
				columns = {
					{ colour = hex("86cdf2"), height = 0.133, gone = { 21.8, 22.8 } },
					{
						colour = hex("cfeeff"),
						streak = hex("f3fbff"),
						streaks = 0.33,
						height = 0.133,
						gone = { 31.2, 32.2 },
					},
					{
						colour = hex("cfeeff"),
						streak = hex("f3fbff"),
						streaks = 0.17,
						height = 0.133,
						gone = { 35.5, 36.5 },
					},
					{ colour = hex("86cdf2"), height = 0.133, gone = { 26.9, 27.9 } },
				},
				fade = { 14, 40 },
				alpha = 0.82,
				jitter = { 1, 1 },
			},
			pieces = {
				-- a see-through glass cube with a white glint on one top
				-- corner: they rise slowly as the player runs, wobbling and
				-- drifting out, in three sizes
				{
					blocks = {
						{ size = V(1, 1, 1), colour = hex("c6ebff"), alpha = 0.5 },
						{
							size = V(0.22, 0.22, 0.22),
							at = V(0.36, 0.611, 0.36),
							colour = hex("ffffff"),
						},
					},
					colours = { hex("c6ebff") },
					size = { 1.47, 1.73 },
					rate = 0.375,
					life = { 8, 8 },
					follow = true,
					back = { 1.4, 12.2 },
					creep = { 0.04, 0.15 },
					side = { 0, 1.67 },
					out = { 0.33, 1.33 },
					height = { 1, 1.1 },
					settle = { 3.3, 4.4 },
					sway = { 0.1, 0.18 },
					swayTurns = 2,
					tilt = { 0.1, 0.1 },
					grow = 0.14,
					shrink = 0.18,
				},
				{
					blocks = {
						{ size = V(1, 1, 1), colour = hex("c6ebff"), alpha = 0.5 },
						{
							size = V(0.22, 0.22, 0.22),
							at = V(0.36, 0.611, 0.36),
							colour = hex("ffffff"),
						},
					},
					colours = { hex("c6ebff") },
					size = { 0.87, 1.07 },
					rate = 0.75,
					life = { 8, 8 },
					follow = true,
					back = { 2.2, 26 },
					creep = { 0.04, 0.15 },
					side = { 0, 1.67 },
					out = { 0.33, 1.33 },
					height = { 0.6, 0.7 },
					settle = { 3.9, 6 },
					sway = { 0.1, 0.18 },
					swayTurns = 2,
					tilt = { 0.1, 0.1 },
					grow = 0.14,
					shrink = 0.18,
				},
				{
					blocks = {
						{ size = V(1, 1, 1), colour = hex("c6ebff"), alpha = 0.5 },
						{
							size = V(0.22, 0.22, 0.22),
							at = V(0.36, 0.611, 0.36),
							colour = hex("ffffff"),
						},
					},
					colours = { hex("c6ebff") },
					size = { 0.37, 0.63 },
					rate = 3.25,
					life = { 8, 8 },
					follow = true,
					back = { 0.7, 35 },
					creep = { 0.04, 0.15 },
					side = { 0, 1.67 },
					out = { 0.33, 1.33 },
					height = { 0.4, 0.5 },
					settle = { 4.7, 7.8 },
					sway = { 0.1, 0.18 },
					swayTurns = 2,
					tilt = { 0.1, 0.1 },
					grow = 0.14,
					shrink = 0.18,
				},
				-- the loose chips past its end
				{
					blocks = {
						{ size = V(1, 0.3, 1), at = V(0, 0.15, 0), alpha = 0.26 },
					},
					colours = { hex("cfeeff"), hex("86cdf2") },
					size = { 0.34, 0.5 },
					rate = 8.75,
					life = { 0.48, 0.48 },
					back = { 36, 42 },
					side = { 0, 1.1 },
					height = { 0, 0 },
				},
			},
			glow = false,
			icon = "rbxassetid://130247254394380",
		},
		SplashWake = {
			name = "SPLASH WAKE",
			rarity = "Epic",
			area = "DrownedVillage",
			earn = "Gems",
			design = "https://claude.ai/design/p/5dfcc528-7d7a-4059-884b-873c94c71d6a",
			-- six across: water bright in the middle and deeper blue out
			-- to the edges, a cube of white foam on each edge (some heaped
			-- two high); the foam goes first, then the water narrows and
			-- breaks up at its end
			ribbon = {
				columns = {
					{
						colour = hex("d6edf8"),
						streak = hex("ffffff"),
						streaks = 0.4,
						height = 1.2,
						tall = 2.2,
						tallShare = 0.15,
						chance = 0.7,
						gone = { 21.5, 28 },
					},
					{
						colour = hex("26a4ea"),
						streak = hex("1a82d4"),
						streaks = 0.22,
						height = 0.2,
						gone = { 27, 33 },
					},
					{
						colour = hex("4cc8f5"),
						streak = hex("a0e8fc"),
						streaks = 0.22,
						height = 0.2,
						dissolve = { 29, 40 },
					},
					{
						colour = hex("4cc8f5"),
						streak = hex("a0e8fc"),
						streaks = 0.22,
						height = 0.2,
						dissolve = { 29, 40 },
					},
					{
						colour = hex("26a4ea"),
						streak = hex("1a82d4"),
						streaks = 0.22,
						height = 0.2,
						gone = { 27, 33 },
					},
					{
						colour = hex("d6edf8"),
						streak = hex("ffffff"),
						streaks = 0.4,
						height = 1.2,
						tall = 2.2,
						tallShare = 0.15,
						chance = 0.7,
						gone = { 21.5, 28 },
					},
				},
				fade = { 18.5, 37 },
				alpha = 1,
				jitter = { 0.965, 1.035 },
			},
			pieces = {
				-- spray cubes, sky blue or white, thrown out over the foam
				-- in a short arc; they land, sit a moment and shrink away
				{
					blocks = {
						{ size = V(1, 1, 1) },
					},
					colours = {
						hex("44c6ff"),
						hex("44c6ff"),
						hex("44c6ff"),
						hex("effbff"),
						hex("effbff"),
					},
					size = { 0.56, 0.76 },
					rate = 10.4,
					life = { 0.85, 1.45 },
					back = { 1.8, 18 },
					side = { 4.33, 4.33 },
					out = { 0.6, 2.2 },
					outAt = { 0, 0.55 },
					height = { 0.4, 1.6 },
					peak = { 1.4, 2.4 },
					peakAt = { 0.2, 0.25 },
					settle = { 0.33, 0.33 },
					settleAt = { 0.5, 0.6 },
					grow = 0.07,
					shrink = 0.1,
				},
			},
			glow = false,
			icon = "rbxassetid://99601980300479",
		},
		TideBell = {
			name = "TIDE BELL",
			rarity = "Legendary",
			area = "DrownedVillage",
			earn = "Boss",
			design = "https://claude.ai/design/p/b19ced93-07df-446d-924f-dd2ba25c0340",
			-- glowing water four across, aqua in the middle and sea green
			-- at the edges, between two rails of gold cubes that follow
			-- every step; at its end it all shrinks away, edges first
			ribbon = {
				columns = {
					{
						colour = hex("f4b42a"),
						streak = hex("ffd95e"),
						streaks = 0.4,
						height = 0.7,
						dissolve = { 24, 29 },
					},
					{
						colour = hex("1fc28f"),
						streak = hex("28d09c"),
						streaks = 0.3,
						height = 0.15,
						neon = true,
						dissolve = { 24, 28 },
					},
					{
						colour = hex("52f2da"),
						streak = hex("8cfaea"),
						streaks = 0.25,
						height = 0.15,
						neon = true,
						dissolve = { 25.5, 30.5 },
					},
					{
						colour = hex("3fe6cf"),
						streak = hex("8cfaea"),
						streaks = 0.25,
						height = 0.15,
						neon = true,
						dissolve = { 25.5, 30.5 },
					},
					{
						colour = hex("17ad80"),
						streak = hex("28d09c"),
						streaks = 0.3,
						height = 0.15,
						neon = true,
						dissolve = { 24, 28 },
					},
					{
						colour = hex("ffcc3d"),
						streak = hex("eaa622"),
						streaks = 0.4,
						height = 0.7,
						dissolve = { 24, 29 },
					},
				},
				fade = { 31, 32 },
				alpha = 1,
				jitter = { 0.95, 1.05 },
				shrink = 2,
			},
			pieces = {
				-- gold sparkle cubes, flashing white-gold and big now and
				-- then: on the rails, outside them, and over the middle
				{
					blocks = {
						{
							size = V(1, 1, 1),
							colour = hex("fff4c2"),
							dim = hex("ffc21f"),
							neon = true,
						},
					},
					colours = { hex("ffc21f") },
					size = { 0.13, 0.21 },
					rate = 2.1,
					life = { 2.3, 2.3 },
					back = { 0.5, 1 },
					side = { 2.5, 2.5 },
					height = { 0.9, 1.7 },
					grow = 0.05,
					shrink = 0.15,
					blink = { 1, 1.33, 2 },
					duty = 0.12,
					pulse = 1.67,
				},
				{
					blocks = {
						{
							size = V(1, 1, 1),
							colour = hex("fff4c2"),
							dim = hex("ffc21f"),
							neon = true,
						},
					},
					colours = { hex("ffc21f") },
					size = { 0.13, 0.21 },
					rate = 2.1,
					life = { 2.3, 2.3 },
					back = { 0.5, 1 },
					side = { 3.3, 4.2 },
					height = { 0.15, 1.75 },
					grow = 0.05,
					shrink = 0.15,
					blink = { 1, 1.33, 2 },
					duty = 0.12,
					pulse = 1.67,
				},
				{
					blocks = {
						{
							size = V(1, 1, 1),
							colour = hex("fff4c2"),
							dim = hex("ffc21f"),
							neon = true,
						},
					},
					colours = { hex("ffc21f") },
					size = { 0.13, 0.21 },
					rate = 2.1,
					life = { 2.3, 2.3 },
					back = { 0.5, 1 },
					side = { 0, 0.75 },
					height = { 1.2, 2.45 },
					grow = 0.05,
					shrink = 0.15,
					blink = { 1, 1.33, 2 },
					duty = 0.12,
					pulse = 1.67,
				},
				-- glassy aqua droplets beside the rails: they rise, shrink a
				-- little and fade, over and over along the trail
				{
					blocks = {
						{ size = V(1, 1, 1), neon = true, alpha = 0.8 },
					},
					colours = { hex("86ffea") },
					size = { 0.45, 0.65 },
					rate = 9.8,
					life = { 1.33, 2 },
					back = { 1.5, 24 },
					side = { 3.4, 4.1 },
					out = { 0.4, 0.4 },
					height = { 0.3, 0.35 },
					settle = { 2.5, 4.5 },
					grow = 0.12,
					shrink = 0.35,
					fadeFrom = 0.5,
				},
			},
			glow = true,
			light = hex("40f0d2"),
			icon = "rbxassetid://75602925138999",
		},
		-- Bogheart Caverns
		BogSpores = {
			name = "BOG SPORES",
			rarity = "Rare",
			area = "BogheartCaverns",
			earn = "Gems",
			design = "https://claude.ai/design/p/1cdaa90c-2368-4876-b85f-9b2ecd3c8cf3",
			-- mottled moss four across, ragged at both edges, darker out
			-- to them, some middle tiles raised and brighter; it thins,
			-- dulls and breaks up towards its end
			ribbon = {
				columns = {
					{ colour = hex("47581c"), height = 0.1, chance = 0.25, dissolve = { 20, 30 } },
					{
						colour = hex("5e7224"),
						streak = hex("526520"),
						streaks = 0.5,
						height = 0.1,
						dissolve = { 22.8, 34 },
					},
					{
						colour = hex("768c2e"),
						streak = hex("91a83b"),
						streaks = 0.3,
						height = 0.1,
						tall = 0.17,
						tallShare = 0.3,
						dissolve = { 23.6, 40 },
					},
					{
						colour = hex("6a7f29"),
						streak = hex("839a34"),
						streaks = 0.3,
						height = 0.1,
						tall = 0.17,
						tallShare = 0.3,
						dissolve = { 23.6, 40 },
					},
					{
						colour = hex("5e7224"),
						streak = hex("526520"),
						streaks = 0.5,
						height = 0.1,
						dissolve = { 22.8, 34 },
					},
					{ colour = hex("47581c"), height = 0.1, chance = 0.25, dissolve = { 20, 30 } },
				},
				fade = { 23.6, 38 },
				alpha = 1,
				jitter = { 0.85, 1.12 },
			},
			pieces = {
				-- glowing lime spores in a faint glow of their own: off the
				-- ribbon's edges they rise slowly, swaying and turning,
				-- drift out, and fade
				{
					blocks = {
						{ size = V(1, 1, 1), neon = true },
						{
							size = V(1.8, 1.8, 1.8),
							colour = hex("b8ff3a"),
							neon = true,
							alpha = 0.22,
						},
					},
					colours = { hex("97d41c"), hex("b0e62a"), hex("c2f23a") },
					jitter = { 0.75, 1 },
					size = { 0.18, 0.3 },
					rate = 6.5,
					life = { 2.7, 5.1 },
					back = { 1.5, 20 },
					side = { 1.5, 2.2 },
					out = { 0.3, 1.2 },
					height = { 0.45, 0.5 },
					settle = { 2.6, 5.6 },
					sway = { 0.2, 0.55 },
					swayTurns = 2.5,
					spin = 40,
					grow = 0.22,
					shrink = 0.35,
					fadeFrom = 0.55,
				},
				{
					blocks = {
						{ size = V(1, 1, 1), neon = true },
						{
							size = V(1.8, 1.8, 1.8),
							colour = hex("b8ff3a"),
							neon = true,
							alpha = 0.22,
						},
					},
					colours = { hex("97d41c"), hex("b0e62a"), hex("c2f23a") },
					jitter = { 0.85, 1 },
					size = { 0.38, 0.78 },
					rate = 3.5,
					life = { 2.7, 5.1 },
					back = { 1.5, 20 },
					side = { 1.5, 2.2 },
					out = { 0.3, 1.2 },
					height = { 0.55, 0.7 },
					settle = { 2.8, 6 },
					sway = { 0.2, 0.55 },
					swayTurns = 2.5,
					spin = 40,
					grow = 0.22,
					shrink = 0.35,
					fadeFrom = 0.55,
				},
			},
			glow = false,
			icon = "rbxassetid://95427363295518",
		},
		GlowcapPath = {
			name = "GLOWCAP PATH",
			rarity = "Epic",
			area = "BogheartCaverns",
			earn = "Gems",
			design = "https://claude.ai/design/p/5cf3a9c6-7bbb-4d63-98cd-37dc591b354f",
			-- deep teal edges round a brighter teal middle with a few
			-- glowing tiles, uneven heights, a pale flash at its head; it
			-- breaks up into the floor at its end
			ribbon = {
				columns = {
					{
						colour = hex("0e5a62"),
						streak = hex("1a8b92"),
						streaks = 0.08,
						fresh = hex("6ff5ee"),
						freshRows = 1.5,
						height = 0.13,
						tall = 0.18,
						tallShare = 0.33,
						dissolve = { 20, 28 },
					},
					{
						colour = hex("1f9ca0"),
						streak = hex("4fdcd6"),
						streaks = 0.1,
						fresh = hex("6ff5ee"),
						freshRows = 1.5,
						height = 0.17,
						tall = 0.22,
						tallShare = 0.33,
						dissolve = { 20, 30 },
					},
					{
						colour = hex("1c9399"),
						streak = hex("4fdcd6"),
						streaks = 0.1,
						fresh = hex("6ff5ee"),
						freshRows = 1.5,
						height = 0.17,
						tall = 0.22,
						tallShare = 0.33,
						dissolve = { 20, 30 },
					},
					{
						colour = hex("0c535c"),
						streak = hex("1a8b92"),
						streaks = 0.08,
						fresh = hex("6ff5ee"),
						freshRows = 1.5,
						height = 0.13,
						tall = 0.18,
						tallShare = 0.33,
						dissolve = { 20, 28 },
					},
				},
				fade = { 20, 30 },
				alpha = 1,
				jitter = { 0.88, 1.08 },
			},
			pieces = {
				-- a glowcap on an edge tile: a pale stem under a glowing cap
				-- of three stepped tiers with white spots; it pops up,
				-- stands, and shrinks back down
				{
					blocks = {
						{ size = V(0.5, 0.8, 0.5), at = V(0, 0.4, 0), colour = hex("b5eee0") },
						{
							size = V(1.8, 0.34, 1.8),
							at = V(0, 0.97, 0),
							colour = hex("1fc8df"),
							neon = true,
						},
						{
							size = V(1.3, 0.28, 1.3),
							at = V(0, 1.28, 0),
							colour = hex("2ad2e7"),
							neon = true,
						},
						{
							size = V(0.7, 0.2, 0.7),
							at = V(0, 1.52, 0),
							colour = hex("44ddee"),
							neon = true,
						},
						{
							size = V(0.22, 0.1, 0.22),
							at = V(-0.78, 1.19, 0.2),
							colour = hex("ffffff"),
						},
						{
							size = V(0.2, 0.1, 0.2),
							at = V(0.5, 1.47, -0.2),
							colour = hex("ffffff"),
						},
					},
					colours = { hex("1fc8df") },
					size = { 1, 1 },
					rate = 3.1,
					life = { 1.3, 1.4 },
					back = { 3, 3.9 },
					side = { 1.5, 1.5 },
					height = { 0.15, 0.15 },
					grow = 0.08,
					shrink = 0.155,
				},
				-- glowing cyan spore cubes rising beside the glowcaps
				{
					blocks = {
						{ size = V(1, 1, 1), neon = true },
					},
					colours = { hex("5ff4ff") },
					jitter = { 0.7, 1 },
					size = { 0.2, 0.3 },
					rate = 12.5,
					life = { 0.5, 0.5 },
					back = { 4, 17 },
					side = { 0, 3.4 },
					height = { 0.7, 0.7 },
					settle = { 3.6, 3.6 },
					grow = 0.12,
					shrink = 0.6,
				},
			},
			glow = false,
			icon = "rbxassetid://130127850551156",
		},
		GulpsBubbles = {
			name = "GULP'S BUBBLES",
			rarity = "Legendary",
			area = "BogheartCaverns",
			earn = "Boss",
			design = "https://claude.ai/design/p/c342ff79-325c-4a15-ad7e-544d66b58a8d",
			-- glowing toad-skin purple four across, pale violet rims and
			-- lime spots in its middle; it dims and breaks up at its end
			ribbon = {
				columns = {
					{ colour = hex("c862ff"), height = 0.2, neon = true, dissolve = { 18.3, 34 } },
					{
						colour = hex("8f2ff0"),
						streak = hex("a6f53b"),
						streaks = 0.15,
						height = 0.2,
						neon = true,
						dissolve = { 18.3, 34 },
					},
					{
						colour = hex("a23ff9"),
						streak = hex("bdff55"),
						streaks = 0.15,
						height = 0.2,
						neon = true,
						dissolve = { 18.3, 34 },
					},
					{ colour = hex("c862ff"), height = 0.2, neon = true, dissolve = { 18.3, 34 } },
				},
				fade = { 15.3, 42 },
				curve = 1,
				alpha = 1,
				jitter = { 0.92, 1.06 },
			},
			pieces = {
				-- a big see-through lilac bubble with white glints on top:
				-- it swells up, rises off the ribbon, wobbling, and pops
				{
					blocks = {
						{ size = V(1, 1, 1), colour = hex("d9c6ff"), neon = true, alpha = 0.4 },
						{
							size = V(0.22, 0.02, 0.22),
							at = V(-0.29, 0.51, 0.29),
							colour = hex("ffffff"),
						},
						{
							size = V(0.1, 0.02, 0.1),
							at = V(0.27, 0.51, -0.29),
							colour = hex("ffffff"),
						},
					},
					colours = { hex("d9c6ff") },
					size = { 1.6, 2.5 },
					rate = 3.6,
					life = { 4.4, 5.4 },
					back = { 1, 12 },
					side = { 0, 0.8 },
					height = { 1, 1.4 },
					settle = { 5.4, 9 },
					settleFrom = 0.07,
					sway = { 0.2, 0.2 },
					swayTurns = 3,
					tilt = { 0.15, 0.15 },
					grow = 0.11,
					shrink = 0.08,
				},
				-- small glowing lime cubes rising between them, spinning
				{
					blocks = {
						{ size = V(1, 1, 1), neon = true },
					},
					colours = { hex("a8ff3e") },
					size = { 0.32, 0.56 },
					rate = 8.9,
					life = { 2.4, 3.6 },
					back = { 0, 16 },
					side = { 0.6, 1.6 },
					out = { 0.9, 0.9 },
					height = { 0.4, 0.5 },
					settle = { 3.2, 6.9 },
					settleFrom = 0.05,
					spin = 130,
					tilt = { 0.45, 0.45 },
					grow = 0.1,
					shrink = 0.1,
				},
			},
			glow = true,
			light = hex("a84dff"),
			icon = "rbxassetid://105770692447734",
		},
		-- the one Mythic, from Endless
		Starfall = {
			name = "STARFALL",
			rarity = "Mythic",
			area = "Endless",
			earn = "Endless",
			design = "https://claude.ai/design/p/87179e06-8104-4f9e-8367-57e90c476496",
			-- glowing night blue: electric-blue core, deep blue edges, a
			-- stray fringe tile beside now and then; it dims along its
			-- length and flickers apart at its end
			ribbon = {
				columns = {
					{
						colour = hex("2247e8"),
						height = 0.12,
						neon = true,
						chance = 0.09,
						dissolve = { 13.6, 34 },
					},
					{ colour = hex("1633c4"), height = 0.12, neon = true, dissolve = { 26, 40 } },
					{
						colour = hex("2a74ff"),
						streak = hex("a8dcff"),
						streaks = 0.12,
						height = 0.12,
						neon = true,
						dissolve = { 26, 40 },
					},
					{
						colour = hex("2a74ff"),
						streak = hex("a8dcff"),
						streaks = 0.12,
						height = 0.12,
						neon = true,
						dissolve = { 26, 40 },
					},
					{ colour = hex("1633c4"), height = 0.12, neon = true, dissolve = { 26, 40 } },
					{
						colour = hex("2247e8"),
						height = 0.12,
						neon = true,
						chance = 0.09,
						dissolve = { 13.6, 34 },
					},
				},
				fade = { 0, 55 },
				curve = 1,
				alpha = 1,
				jitter = { 0.96, 1.04 },
			},
			pieces = {
				-- flat plus stars of five cubes facing the sky, white and
				-- pale gold, along and beside the ribbon; each twinkles
				-- brighter and a little bigger now and then
				{
					blocks = {
						{
							size = V(1, 1, 1),
							colour = hex("ffffff"),
							dim = hex("dfe8ff"),
							neon = true,
						},
						{
							size = V(1, 1, 1),
							at = V(1, 0, 0),
							colour = hex("f4f7ff"),
							dim = hex("b9c8f2"),
							neon = true,
						},
						{
							size = V(1, 1, 1),
							at = V(-1, 0, 0),
							colour = hex("f4f7ff"),
							dim = hex("b9c8f2"),
							neon = true,
						},
						{
							size = V(1, 1, 1),
							at = V(0, 0, 1),
							colour = hex("f4f7ff"),
							dim = hex("b9c8f2"),
							neon = true,
						},
						{
							size = V(1, 1, 1),
							at = V(0, 0, -1),
							colour = hex("f4f7ff"),
							dim = hex("b9c8f2"),
							neon = true,
						},
					},
					colours = { hex("e8efff") },
					size = { 0.26, 0.68 },
					rate = 3.3,
					life = { 2.7, 2.7 },
					back = { 0, 1 },
					side = { 0, 2.5 },
					height = { 0.45, 1.8 },
					bob = 0.08,
					bobPeriod = 4,
					grow = 0.08,
					shrink = 0.15,
					blink = { 2.67, 4, 8 },
					duty = 0.25,
					pulse = 0.14,
				},
				{
					blocks = {
						{
							size = V(1, 1, 1),
							colour = hex("fff6dd"),
							dim = hex("fff0c8"),
							neon = true,
						},
						{
							size = V(1, 1, 1),
							at = V(1, 0, 0),
							colour = hex("ffe7b0"),
							dim = hex("ffd88a"),
							neon = true,
						},
						{
							size = V(1, 1, 1),
							at = V(-1, 0, 0),
							colour = hex("ffe7b0"),
							dim = hex("ffd88a"),
							neon = true,
						},
						{
							size = V(1, 1, 1),
							at = V(0, 0, 1),
							colour = hex("ffe7b0"),
							dim = hex("ffd88a"),
							neon = true,
						},
						{
							size = V(1, 1, 1),
							at = V(0, 0, -1),
							colour = hex("ffe7b0"),
							dim = hex("ffd88a"),
							neon = true,
						},
					},
					colours = { hex("ffd88a") },
					size = { 0.26, 0.68 },
					rate = 2.95,
					life = { 2.7, 2.7 },
					back = { 0, 1 },
					side = { 0, 2.5 },
					height = { 0.45, 1.8 },
					bob = 0.08,
					bobPeriod = 4,
					grow = 0.08,
					shrink = 0.15,
					blink = { 2.67, 4, 8 },
					duty = 0.25,
					pulse = 0.14,
				},
				-- now and then a big gold star shoots off, arcing up and
				-- out, spinning, and shrinks away in steps
				{
					blocks = {
						{ size = V(1, 1, 1), colour = hex("fff0c8"), neon = true },
						{ size = V(1, 1, 1), at = V(1, 0, 0), colour = hex("ffd88a"), neon = true },
						{
							size = V(1, 1, 1),
							at = V(-1, 0, 0),
							colour = hex("ffd88a"),
							neon = true,
						},
						{ size = V(1, 1, 1), at = V(0, 0, 1), colour = hex("ffd88a"), neon = true },
						{
							size = V(1, 1, 1),
							at = V(0, 0, -1),
							colour = hex("ffd88a"),
							neon = true,
						},
					},
					colours = { hex("ffd88a") },
					size = { 0.68, 0.68 },
					rate = 0.4,
					life = { 1.6, 1.6 },
					back = { 2, 8 },
					side = { 0.5, 1 },
					out = { 12, 12 },
					height = { 0.6, 0.6 },
					peak = { 6.2, 6.2 },
					peakAt = { 0.45, 0.45 },
					settle = { 0.6, 0.6 },
					settleAt = { 1, 1 },
					yawTurns = { 1, 1 },
					tilt = { 0.9, 0.9 },
					grow = 0.1,
					shrink = 0.4,
					steps = 4,
				},
				-- small glowing blue sparks drifting up beside it
				{
					blocks = {
						{ size = V(1, 1, 1), colour = hex("4d9bff"), neon = true },
					},
					colours = { hex("4d9bff") },
					size = { 0.2, 0.48 },
					rate = 2.7,
					life = { 4, 8 },
					back = { 1, 30 },
					side = { 2.6, 5.6 },
					out = { 0.5, 0.5 },
					height = { 0.3, 1.2 },
					settle = { 1.3, 3.6 },
					grow = 0.5,
					shrink = 0.5,
				},
			},
			glow = true,
			light = hex("2f6bff"),
			lightBrightness = 2,
			icon = "rbxassetid://116548860955448",
		},
	} :: { [string]: Trail },
}

return table.freeze(Trails)
