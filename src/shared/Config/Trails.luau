--!strict
--[[
	The trails (owner, 2026-11-13: "ANOTHER FOR CREATING THE TRAILS"; the
	roster and Starfall picked from Codex's sheets in
	`assets/concepts/blocky/ui/trails/`): what goes in the Gear sheet's TRAIL
	slot. Looks only -- a trail adds no power (player power is pets and
	weapons). `Fx/PlayerTrails` draws the equipped one behind every player
	who wears it: a ribbon low along the ground and the trail's own square
	particles, as the sheets show.

	Each area has three, earned three ways (`earn`):
	- `Gems`: bought on the Gear sheet's TRAILS tab for `gemPrices[rarity]`
	  times the area's number (the weapon store's numbers, `Config/Shop`).
	- `Boss`: given the first time the area's boss falls, and to anyone
	  who had already beaten it before trails existed.
	- `Endless`: Starfall, the one Mythic (owner: "should be a reward for
	  getting to a certain floor on endless with all 3 classes"), given once
	  `endless.floor` has been reached in Endless as each of
	  `endless.classes`.

	Every Legendary and Mythic glows (rule 12): `glow` and a `light`,
	pinned by `tests/Trails.spec`. One picture an item: `icon` is the only
	one, on every screen (Codex's, cut by `assets/ui/trails/cutout.py`).
]]

export type Emitter = {
	--[[ "Square", the game's white square (`PetAuras.square`), or "Star",
	     Starfall's white cross (`star` below). Tinted by `colours`. ]]
	texture: string,
	colours: { Color3 },
	--[[ A second while running; standing still emits `idle` of it. ]]
	rate: number,
	--[[ Seconds each lives, studs across at birth, studs a second. ]]
	life: number,
	size: number,
	speed: number,
	--[[ Studs a second each second upward (below zero falls). ]]
	lift: number,
	--[[ Degrees a second it turns, either way. ]]
	spin: number,
	--[[ How much it lights itself (0 lit by the world, 1 glowing). ]]
	glow: number,
}

export type Trail = {
	name: string,
	rarity: string,
	--[[ The area it belongs to, by `Config/Economy` key. ]]
	area: string,
	earn: string,
	--[[ The ribbon's colours, from the player back to its end. ]]
	ribbon: { Color3 },
	--[[ Studs across, and seconds it lingers behind. ]]
	width: number,
	life: number,
	--[[ Glowing: the ribbon lights itself and a light rides with it. ]]
	glow: boolean,
	light: Color3?,
	--[[ The ribbon's colours slide along it, slowly (the Mythic's). ]]
	shimmer: boolean?,
	emitters: { Emitter },
	icon: string,
}

local function rgb(r: number, g: number, b: number): Color3
	return Color3.fromRGB(r, g, b)
end

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

	--[[ What standing still leaves of a trail's particles: a little, so a
	     glowing trail still shines, not a heap at the player's feet. ]]
	idle = 0.15,

	--[[ The look that makes a trail more than a stripe (owner, 2026-11-13:
	     "Make it very cool"), the same for every trail:
	     - `core`: a brighter ribbon standing upright along the middle of
	       the flat one, `height` studs tall, its colours this far towards
	       white (a glowing trail's further), lingering `life` as long. The
	       flat ribbon reads from the run's camera overhead and the fin from
	       the lobby's low one (seen in Play, 2026-11-13: flat alone was a
	       thin line from the lobby).
	     - `burst`: a dash (moving faster than `speed` studs a second) or
	       putting the trail on throws `count` of its particles out all
	       round, at most once in `gap` seconds.
	     - `pulse`: a glowing trail's light breathes, `depth` either side,
	       `rate` times a second.
	     - `shimmerRate`: how many times a second a shimmering ribbon's
	       colours slide one step along it. ]]
	core = { height = 1.1, white = 0.3, whiteGlow = 0.6, life = 0.7 },
	burst = { speed = 30, count = 16, gap = 0.5 },
	pulse = { rate = 0.8, depth = 0.3 },
	shimmerRate = 0.6,

	--[[ Starfall's white cross, a particle (Codex's, `assets/ui/trails/star.png`). ]]
	star = "rbxassetid://74384355268464",

	trails = {
		-- Mossy Glade
		LeafDrift = {
			name = "LEAF DRIFT",
			rarity = "Rare",
			area = "MossyGlade",
			earn = "Gems",
			ribbon = { rgb(150, 222, 92), rgb(96, 178, 62) },
			width = 2.2,
			life = 0.55,
			glow = false,
			emitters = {
				{
					texture = "Square",
					colours = { rgb(126, 212, 72), rgb(204, 232, 92) },
					rate = 10,
					life = 1.1,
					size = 0.64,
					speed = 1.2,
					lift = -1.5,
					spin = 200,
					glow = 0,
				},
			},
			icon = "rbxassetid://83559446857743",
		},
		FireflyWake = {
			name = "FIREFLY WAKE",
			rarity = "Epic",
			area = "MossyGlade",
			earn = "Gems",
			ribbon = { rgb(44, 118, 54), rgb(26, 72, 36) },
			width = 2.4,
			life = 0.65,
			glow = false,
			emitters = {
				{
					texture = "Square",
					colours = { rgb(255, 232, 96), rgb(255, 198, 62) },
					rate = 12,
					life = 1.6,
					size = 0.48,
					speed = 1,
					lift = 1.4,
					spin = 60,
					glow = 1,
				},
			},
			icon = "rbxassetid://98989425582849",
		},
		RoyalGoo = {
			name = "ROYAL GOO",
			rarity = "Legendary",
			area = "MossyGlade",
			earn = "Boss",
			ribbon = { rgb(176, 255, 66), rgb(112, 222, 44) },
			width = 2.8,
			life = 0.8,
			glow = true,
			light = rgb(160, 255, 84),
			emitters = {
				{
					texture = "Square",
					colours = { rgb(156, 242, 64), rgb(110, 210, 40) },
					rate = 9,
					life = 0.9,
					size = 0.8,
					speed = 0.4,
					lift = -6,
					spin = 40,
					glow = 0.6,
				},
				{
					texture = "Square",
					colours = { rgb(255, 214, 84), rgb(255, 240, 160) },
					rate = 6,
					life = 1,
					size = 0.45,
					speed = 1,
					lift = 1.5,
					spin = 180,
					glow = 1,
				},
			},
			icon = "rbxassetid://73952091491527",
		},
		-- Thornwood
		BramblePollen = {
			name = "BRAMBLE POLLEN",
			rarity = "Rare",
			area = "Thornwood",
			earn = "Gems",
			ribbon = { rgb(238, 84, 204), rgb(172, 52, 162) },
			width = 2.0,
			life = 0.55,
			glow = false,
			emitters = {
				{
					texture = "Square",
					colours = { rgb(255, 124, 224), rgb(232, 84, 204) },
					rate = 10,
					life = 1.4,
					size = 0.56,
					speed = 0.8,
					lift = 1.6,
					spin = 90,
					glow = 0.5,
				},
			},
			icon = "rbxassetid://95388423540752",
		},
		CrowFeathers = {
			name = "CROW FEATHERS",
			rarity = "Epic",
			area = "Thornwood",
			earn = "Gems",
			ribbon = { rgb(116, 64, 158), rgb(62, 36, 92) },
			width = 2.4,
			life = 0.65,
			glow = false,
			emitters = {
				{
					texture = "Square",
					colours = { rgb(46, 28, 62), rgb(78, 46, 104) },
					rate = 9,
					life = 1.4,
					size = 0.72,
					speed = 1.4,
					lift = -1,
					spin = 240,
					glow = 0,
				},
			},
			icon = "rbxassetid://105803115814322",
		},
		BroodSilk = {
			name = "BROOD SILK",
			rarity = "Legendary",
			area = "Thornwood",
			earn = "Boss",
			ribbon = { rgb(196, 128, 255), rgb(132, 72, 222) },
			width = 2.8,
			life = 0.8,
			glow = true,
			light = rgb(172, 112, 255),
			emitters = {
				{
					texture = "Square",
					colours = { rgb(206, 232, 255), rgb(150, 200, 255) },
					rate = 8,
					life = 1,
					size = 0.4,
					speed = 1,
					lift = 1,
					spin = 120,
					glow = 1,
				},
				{
					texture = "Square",
					colours = { rgb(176, 104, 255), rgb(122, 60, 210) },
					rate = 5,
					life = 1.1,
					size = 0.72,
					speed = 0.6,
					lift = 0.5,
					spin = 60,
					glow = 0.8,
				},
			},
			icon = "rbxassetid://119075661571853",
		},
		-- Drowned Village
		BubbleStream = {
			name = "BUBBLE STREAM",
			rarity = "Rare",
			area = "DrownedVillage",
			earn = "Gems",
			ribbon = { rgb(152, 212, 255), rgb(100, 170, 240) },
			width = 2.1,
			life = 0.55,
			glow = false,
			emitters = {
				{
					texture = "Square",
					colours = { rgb(206, 238, 255), rgb(150, 210, 255) },
					rate = 9,
					life = 1.5,
					size = 0.72,
					speed = 0.5,
					lift = 2.2,
					spin = 30,
					glow = 0.4,
				},
			},
			icon = "rbxassetid://130247254394380",
		},
		SplashWake = {
			name = "SPLASH WAKE",
			rarity = "Epic",
			area = "DrownedVillage",
			earn = "Gems",
			ribbon = { rgb(242, 250, 255), rgb(84, 172, 232) },
			width = 2.5,
			life = 0.6,
			glow = false,
			emitters = {
				{
					texture = "Square",
					colours = { rgb(236, 248, 255), rgb(124, 202, 250) },
					rate = 16,
					life = 0.7,
					size = 0.51,
					speed = 4,
					lift = -9,
					spin = 160,
					glow = 0.3,
				},
			},
			icon = "rbxassetid://99601980300479",
		},
		TideBell = {
			name = "TIDE BELL",
			rarity = "Legendary",
			area = "DrownedVillage",
			earn = "Boss",
			ribbon = { rgb(96, 242, 206), rgb(42, 180, 172) },
			width = 2.8,
			life = 0.8,
			glow = true,
			light = rgb(96, 240, 214),
			emitters = {
				{
					texture = "Square",
					colours = { rgb(255, 216, 92), rgb(255, 238, 160) },
					rate = 8,
					life = 1,
					size = 0.45,
					speed = 1,
					lift = 1.2,
					spin = 180,
					glow = 1,
				},
				{
					texture = "Square",
					colours = { rgb(184, 242, 255), rgb(120, 220, 240) },
					rate = 6,
					life = 0.8,
					size = 0.48,
					speed = 2.5,
					lift = -6,
					spin = 90,
					glow = 0.7,
				},
			},
			icon = "rbxassetid://75602925138999",
		},
		-- Bogheart Caverns
		BogSpores = {
			name = "BOG SPORES",
			rarity = "Rare",
			area = "BogheartCaverns",
			earn = "Gems",
			ribbon = { rgb(134, 144, 54), rgb(92, 102, 40) },
			width = 2.2,
			life = 0.55,
			glow = false,
			emitters = {
				{
					texture = "Square",
					colours = { rgb(192, 242, 64), rgb(150, 210, 50) },
					rate = 11,
					life = 1.5,
					size = 0.48,
					speed = 0.6,
					lift = 1.2,
					spin = 90,
					glow = 0.6,
				},
			},
			icon = "rbxassetid://95427363295518",
		},
		GlowcapPath = {
			name = "GLOWCAP PATH",
			rarity = "Epic",
			area = "BogheartCaverns",
			earn = "Gems",
			ribbon = { rgb(32, 118, 128), rgb(20, 72, 82) },
			width = 2.4,
			life = 0.7,
			glow = false,
			emitters = {
				{
					texture = "Square",
					colours = { rgb(96, 242, 255), rgb(160, 250, 255) },
					rate = 8,
					life = 1.2,
					size = 0.67,
					speed = 0.3,
					lift = 0.8,
					spin = 0,
					glow = 1,
				},
			},
			icon = "rbxassetid://130127850551156",
		},
		GulpsBubbles = {
			name = "GULP'S BUBBLES",
			rarity = "Legendary",
			area = "BogheartCaverns",
			earn = "Boss",
			ribbon = { rgb(184, 94, 244), rgb(130, 60, 204) },
			width = 2.8,
			life = 0.8,
			glow = true,
			light = rgb(190, 112, 255),
			emitters = {
				{
					texture = "Square",
					colours = { rgb(196, 255, 84), rgb(150, 230, 60) },
					rate = 6,
					life = 1.4,
					size = 0.64,
					speed = 0.5,
					lift = 2,
					spin = 40,
					glow = 1,
				},
				{
					texture = "Square",
					colours = { rgb(214, 156, 255), rgb(176, 110, 250) },
					rate = 6,
					life = 1.4,
					size = 0.88,
					speed = 0.4,
					lift = 1.6,
					spin = 30,
					glow = 0.8,
				},
			},
			icon = "rbxassetid://105770692447734",
		},
		-- the one Mythic, from Endless
		Starfall = {
			name = "STARFALL",
			rarity = "Mythic",
			area = "Endless",
			earn = "Endless",
			ribbon = { rgb(70, 124, 255), rgb(28, 44, 150) },
			width = 2.9,
			life = 0.9,
			glow = true,
			light = rgb(110, 158, 255),
			shimmer = true,
			emitters = {
				{
					texture = "Star",
					colours = { rgb(255, 255, 255), rgb(255, 232, 150) },
					rate = 12,
					life = 1.2,
					size = 0.96,
					speed = 0.8,
					lift = 0.6,
					spin = 0,
					glow = 1,
				},
				{
					texture = "Square",
					colours = { rgb(110, 170, 255), rgb(60, 110, 255) },
					rate = 5,
					life = 0.9,
					size = 0.4,
					speed = 1,
					lift = 0.4,
					spin = 120,
					glow = 1,
				},
				-- now and then a big star shoots off and falls
				{
					texture = "Star",
					colours = { rgb(255, 246, 210), rgb(255, 214, 110) },
					rate = 1.2,
					life = 0.6,
					size = 1.76,
					speed = 9,
					lift = -14,
					spin = 0,
					glow = 1,
				},
			},
			icon = "rbxassetid://116548860955448",
		},
	} :: { [string]: Trail },
}

return table.freeze(Trails)
