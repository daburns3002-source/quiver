--!strict
--[[
	The loading screen's art and layout (owner, 2026-10-26: "have codex make
	another loading screen ... put up a concept sheet of an enemy or weapon
	that the player has run into already with one of the tips"). The art is
	Codex's (`assets/concepts/blocky/ui/loading/loading_screen.png`), its
	panels left empty for `first/Loading` to fill; the boxes below are where
	they are on that picture, in its pixels.
]]

export type Box = { x: number, y: number, w: number, h: number }

local LoadingScreen = {
	--[[ The old shared loading art. The loading screen no longer draws it
	     — it shows Codex's spotlights and nothing else (owner, 2026-10-31:
	     "the old loading screens need to be removed, the 4 new ones should
	     be the only ones in the game so far") — but `UI/ClassScreen` still
	     uses it as the backdrop it puts the chosen class's weapon on, with
	     `picture`, `description` and `plaque` below. It lives here until
	     that screen gets art of its own. ]]
	art = "rbxassetid://96723708924131" :: string?,
	--[[ Codex's per-enemy spotlight screens (2026-10-31), keyed by the entry
	     name `Util/LoadingPick` hands over, which is the enemy's
	     `NewEnemies.name`. Each bakes its own backdrop, enemy, title and
	     line into one 1672x941 picture, so the screen draws it whole and
	     keeps only the live furniture over it: the bar, LOADING and the tip.
	     An entry with no spotlight falls back to `art` exactly as before.
	     Sources in `assets/concepts/blocky/ui/loading/spotlight/`. ]]
	spotlights = {
		["BABY SLIME"] = "rbxassetid://109875530590023",
		["BROOD SLIME"] = "rbxassetid://85643151176705",
		["MOSS SLIME"] = "rbxassetid://140658661048079",
		["SPLITTER SPITTER"] = "rbxassetid://108350133336178",
	} :: { [string]: string },
	--[[ The art's size in pixels, and its panels. ]]
	size = Vector2.new(1672, 941),
	--[[ `UI/ClassScreen`'s boxes on that art: the picture window, then its
	     line under it, then the name plaque. The loading screen drew these
	     too until 2026-10-31. ]]
	picture = { x = 240, y = 262, w = 736, h = 262 } :: Box,
	description = { x = 262, y = 528, w = 692, h = 112 } :: Box,
	plaque = { x = 480, y = 652, w = 268, h = 46 } :: Box,
	tip = { x = 1126, y = 270, w = 332, h = 390 } :: Box,
	--[[ The bar's trough, to the pixel, so the fill sits flush in it. ]]
	bar = { x = 470, y = 810, w = 728, h = 43 } :: Box,
	descriptionText = Color3.fromRGB(214, 226, 200),
	tipText = Color3.fromRGB(236, 232, 214),
	barFill = Color3.fromRGB(110, 200, 60),
	--[[ How long the screen waits for the player's save before choosing
	     the picture from what every player has met. ]]
	profileWait = 2,
}

return table.freeze(LoadingScreen)
