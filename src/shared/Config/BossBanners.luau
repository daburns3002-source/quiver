--!strict
--[[
	The banner that comes up as the player walks into a boss room (owner,
	2026-10-24: "for acts 1-3 i want a 2d blocky icon created that shows up
	when you enter their boss room"), drawn by `UI/BossBanner` over the boss
	music's battle intro.

	Keyed by the boss's title, the `Boss` attribute the server sets
	(`Balance` boss `title`). Icons are Codex's 2D blocky portraits, cut out
	by `assets/ui/boss_banner/cutout.py` and uploaded by the owner; an empty
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
	bosses = {
		["Slime King"] = {
			name = "King Bloblin",
			subtitle = "Ruler of the Mossy Glade",
			area = "Mossy Glade",
			act = "Act 1 · Area 1",
			icon = "",
			tint = Color3.fromRGB(108, 194, 74),
			deep = Color3.fromRGB(44, 90, 29),
		},
		["The Broodmother"] = {
			name = "The Broodmother",
			subtitle = "Queen of the Thornwood",
			area = "Thornwood",
			act = "Act 1 · Area 2",
			icon = "",
			tint = Color3.fromRGB(122, 79, 214),
			deep = Color3.fromRGB(46, 29, 87),
		},
		["Old Tollcrab"] = {
			name = "Old Tollcrab",
			subtitle = "Bell of the Drowned Village",
			area = "Drowned Village",
			act = "Act 2 · Area 3",
			icon = "",
			tint = Color3.fromRGB(226, 103, 58),
			deep = Color3.fromRGB(31, 85, 82),
		},
		["Grandmother Gulp"] = {
			name = "Grandmother Gulp",
			subtitle = "Hunger of Bogheart Caverns",
			area = "Bogheart Caverns",
			act = "Act 2 · Area 4",
			icon = "",
			tint = Color3.fromRGB(154, 79, 201),
			deep = Color3.fromRGB(58, 31, 79),
		},
		["The Tempest Roc"] = {
			name = "The Tempest Roc",
			subtitle = "Storm of the Windswept Cliffs",
			area = "Windswept Cliffs",
			act = "Act 3 · Area 5",
			icon = "",
			tint = Color3.fromRGB(242, 194, 48),
			deep = Color3.fromRGB(31, 58, 122),
		},
		["Rimeheart"] = {
			name = "Rimeheart",
			subtitle = "the Yeti King of Frostpeak Pass",
			area = "Frostpeak Pass",
			act = "Act 3 · Area 6",
			icon = "",
			tint = Color3.fromRGB(92, 200, 242),
			deep = Color3.fromRGB(29, 74, 110),
		},
	} :: { [string]: Banner },
}

return table.freeze(BossBanners)
