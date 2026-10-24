--!strict
--[[
	The banner that comes up as the player walks into a boss room (owner,
	2026-10-24: "for acts 1-3 i want a 2d blocky icon created that shows up
	when you enter their boss room"), drawn by `UI/BossBanner` over the boss
	music's battle intro.

	The owner's pick is style A, Slash (audition page, 2026-10-24), with
	each boss's icon playing an attack in a few frames ("have a couple
	frames showing an attack animation that goes with the style of boss").

	Keyed by the boss's title, the `Boss` attribute the server sets
	(`Balance` boss `title`). Each icon is a 2x2 sheet of Codex's 2D blocky
	frames (ready, wind-up, strike, follow-through), cut out by
	`assets/ui/boss_banner/cutout.py` and uploaded through Studio's MCP
	(`upload_image`, from a localhost server); an empty
	`icon` shows the banner without one. Acts 1–3's six bosses: only King
	Bloblin is built, the rest wait under the titles docs/BOSSES.md gives them.
]]

export type Banner = {
	name: string,
	--[[ The line under the name. ]]
	subtitle: string,
	area: string,
	act: string,
	icon: string,
	--[[ The boss's colour, and a deep shade of it for the banner's ground. ]]
	tint: Color3,
	deep: Color3,
}

local BossBanners = {
	--[[ Seconds on screen: the length of the boss music's battle intro
	     (`Config/Music`), which starts on the same tick. ]]
	duration = 4.7,
	--[[ The icon sheet: `grid` x `grid` frames of `cell` pixels each, read
	     left to right, top to bottom. ]]
	sheet = { grid = 2, cell = 512 },
	--[[ Which frame shows from when (seconds): ready, then the attack
	     once — wind-up, strike, follow-through, held to the end (owner,
	     2026-10-24: "only play the 4 frame animation once"). ]]
	frames = {
		{ at = 0, frame = 1 },
		{ at = 1.3, frame = 2 },
		{ at = 1.7, frame = 3 },
		{ at = 2.4, frame = 4 },
	},
	--[[ How long the icon shakes from the strike, and how far (a share of
	     the icon's height). ]]
	shake = { time = 0.3, size = 0.025 },
	bosses = {
		["Slime King"] = {
			name = "King Bloblin",
			subtitle = "Ruler of the Mossy Glade",
			area = "Mossy Glade",
			act = "Act 1 · Area 1",
			icon = "rbxassetid://78460485194173",
			tint = Color3.fromRGB(108, 194, 74),
			deep = Color3.fromRGB(44, 90, 29),
		},
		["The Broodmother"] = {
			name = "The Broodmother",
			subtitle = "Queen of the Thornwood",
			area = "Thornwood",
			act = "Act 1 · Area 2",
			icon = "rbxassetid://136663810724087",
			tint = Color3.fromRGB(122, 79, 214),
			deep = Color3.fromRGB(46, 29, 87),
		},
		["Old Tollcrab"] = {
			name = "Old Tollcrab",
			subtitle = "Bell of the Drowned Village",
			area = "Drowned Village",
			act = "Act 2 · Area 3",
			icon = "rbxassetid://124607941375492",
			tint = Color3.fromRGB(226, 103, 58),
			deep = Color3.fromRGB(31, 85, 82),
		},
		["Grandmother Gulp"] = {
			name = "Grandmother Gulp",
			subtitle = "Hunger of Bogheart Caverns",
			area = "Bogheart Caverns",
			act = "Act 2 · Area 4",
			icon = "rbxassetid://89932935592152",
			tint = Color3.fromRGB(154, 79, 201),
			deep = Color3.fromRGB(58, 31, 79),
		},
		["The Tempest Roc"] = {
			name = "The Tempest Roc",
			subtitle = "Storm of the Windswept Cliffs",
			area = "Windswept Cliffs",
			act = "Act 3 · Area 5",
			icon = "rbxassetid://105286421915986",
			tint = Color3.fromRGB(242, 194, 48),
			deep = Color3.fromRGB(31, 58, 122),
		},
		["Rimeheart"] = {
			name = "Rimeheart",
			subtitle = "the Yeti King of Frostpeak Pass",
			area = "Frostpeak Pass",
			act = "Act 3 · Area 6",
			icon = "rbxassetid://98889449308519",
			tint = Color3.fromRGB(92, 200, 242),
			deep = Color3.fromRGB(29, 74, 110),
		},
	} :: { [string]: Banner },
}

return table.freeze(BossBanners)
