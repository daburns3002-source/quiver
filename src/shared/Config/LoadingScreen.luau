--!strict
--[[
	The loading screen's art and layout (owner, 2026-10-26: "have codex make
	another loading screen ... put up a concept sheet of an enemy or weapon
	that the player has run into already with one of the tips").

	Both loading screens -- `first/Loading` on join and the cover
	`UI/ClassScreen` puts up after CHOOSE -- now draw one of Codex's four
	spotlights and nothing else (owner, 2026-11-01: "the old loading screens
	need to be removed from the game"). A spotlight is a finished 1672x941
	picture, so the only boxes left here are for the live furniture over it:
	the tip and the bar, in that picture's pixels.
]]

export type Box = { x: number, y: number, w: number, h: number }

local LoadingScreen = {
	--[[ Codex's per-enemy spotlight screens (2026-10-31), keyed by the entry
	     name `Util/LoadingPick` hands over, which is the enemy's
	     `NewEnemies.name`. Each bakes its own backdrop, enemy, title and
	     line into one 1672x941 picture, so the screen draws it whole and
	     keeps only the live furniture over it: the bar, LOADING and the tip.
	     These four are every loading screen the game has: an enemy without
	     one is simply not drawn, on either screen.
	     Sources in `assets/concepts/blocky/ui/loading/spotlight/`.

	     Each is its left and right halves, 836x941 apiece plus
	     `tileOverlap` pixels of the other half past the cut, drawn side by
	     side by `Util/SpotlightArt` (owner, 2026-11-05: "i need the loading
	     thumbnails higher resolution"): Roblox shrinks an upload to 1024 on
	     its longest side, so the whole picture had been shown at 1024x576.
	     The halves are in `assets/ui/loading_tiles/`. ]]
	spotlights = {
		["BABY SLIME"] = { "rbxassetid://113200378901201", "rbxassetid://79381368210341" },
		["BROOD SLIME"] = { "rbxassetid://98125274935404", "rbxassetid://91177741126351" },
		["MOSS SLIME"] = { "rbxassetid://122909053983457", "rbxassetid://118985955689898" },
		["SPLITTER SPITTER"] = {
			"rbxassetid://117967764117644",
			"rbxassetid://75718199343735",
		},
	} :: { [string]: { string } },
	--[[ The most pixels Roblox keeps on an image's longest side. ]]
	uploadLimit = 1024,
	--[[ Pixels each tile carries past its cut, so the seam blends into
	     real picture rather than showing a light line. ]]
	tileOverlap = 8,
	--[[ A spotlight's size in pixels, which every box below is measured
	     against. ]]
	size = Vector2.new(1672, 941),
	tip = { x = 80, y = 836, w = 1500, h = 40 } :: Box,
	--[[ The bar's trough, to the pixel, so the fill sits flush in it. ]]
	bar = { x = 81, y = 808, w = 1508, h = 13 } :: Box,
	tipText = Color3.fromRGB(236, 232, 214),
	barFill = Color3.fromRGB(110, 200, 60),
	--[[ How long the screen waits for the player's save before choosing
	     the picture from what every player has met. ]]
	profileWait = 2,
}

return table.freeze(LoadingScreen)
