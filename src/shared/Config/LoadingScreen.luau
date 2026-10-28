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
	--[[ The uploaded art (nil: the screen stays black
	     with the picture, tip and bar drawn on their own). ]]
	art = "rbxassetid://96723708924131" :: string?,
	--[[ The art's size in pixels, and its panels. ]]
	size = Vector2.new(1672, 941),
	--[[ The picture window holds the picture, then its line under it
	     (owner, 2026-10-26: "the left side needs to have a description of
	     the enemy and i dont like the tan color": the window is recoloured
	     forest green, `loading_screen_green.png`). ]]
	picture = { x = 240, y = 262, w = 736, h = 262 } :: Box,
	description = { x = 262, y = 528, w = 692, h = 112 } :: Box,
	plaque = { x = 480, y = 652, w = 268, h = 46 } :: Box,
	--[[ The whole green window, which a scene of the picture's area fills
	     (owner, 2026-10-26: "the weapon looks like its just floating there
	     ... it looks empty"), rays in its rarity's colour turning behind
	     it. ]]
	window = { x = 224, y = 252, w = 770, h = 398 } :: Box,
	backdrops = {
		MossyGlade = "",
		Thornwood = "",
	} :: { [string]: string },
	rays = "rbxassetid://123315883761316",
	glow = "rbxassetid://72053512669132",
	tip = { x = 1126, y = 270, w = 332, h = 390 } :: Box,
	--[[ The bar's trough, to the pixel, so the fill sits flush in it. ]]
	bar = { x = 470, y = 810, w = 728, h = 43 } :: Box,
	--[[ Where the tip, plaque and bar text go when there is no art. ]]
	parchment = Color3.fromRGB(30, 52, 40),
	descriptionText = Color3.fromRGB(214, 226, 200),
	tipText = Color3.fromRGB(236, 232, 214),
	barFill = Color3.fromRGB(110, 200, 60),
	--[[ How long the screen waits for the player's save before choosing
	     the picture from what every player has met. ]]
	profileWait = 2,
}

return table.freeze(LoadingScreen)
