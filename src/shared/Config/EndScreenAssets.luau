--!strict
--[[
	The end screens' images, uploaded to Roblox on 2026-10-25: the blocky
	restyle (owner, 2026-10-25: "change defeat and victory screen to new
	blocky design language").

	Codex art cut from its magenta backgrounds by
	`assets/ui/end_screens/cutout.py` (raws and prompts in
	`assets/concepts/blocky/ui/end_screens_raw/`), to match the reference
	sheets `assets/concepts/blocky/ui/end_victory.jpg` and `end_defeat.jpg`.
	The ribbons are blank, for live blocky text; the cube is plain grey,
	tinted where it is used.
]]

local EndScreenAssets = {
	ribbonVictory = "rbxassetid://104233184250779",
	ribbonDefeat = "rbxassetid://121514637917026",
	heroVictory = "rbxassetid://131261335765461",
	heroDefeat = "rbxassetid://91611465071192",
	rays = "rbxassetid://110500527798364",

	skull = "rbxassetid://81391037520188",
	hourglass = "rbxassetid://93832562742445",
	heart = "rbxassetid://132016175854758",
	chart = "rbxassetid://89255397360408",
	coin = "rbxassetid://105417892155855",
	gem = "rbxassetid://110312361811467",
	chevron = "rbxassetid://102496291506472",
	refresh = "rbxassetid://131860825119130",
	cube = "rbxassetid://93394386923395",
	drop = "rbxassetid://98128376234101",
	star = "rbxassetid://133495348208361",
	sparkle = "rbxassetid://75145958219959",
}

return table.freeze(EndScreenAssets)
