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
	art = "rbxassetid://138476916037906" :: string?,
	--[[ The art's size in pixels, and its panels. ]]
	size = Vector2.new(1672, 941),
	picture = { x = 224, y = 256, w = 768, h = 376 } :: Box,
	plaque = { x = 480, y = 652, w = 268, h = 46 } :: Box,
	tip = { x = 1126, y = 270, w = 332, h = 390 } :: Box,
	bar = { x = 474, y = 810, w = 724, h = 40 } :: Box,
	--[[ Where the tip, plaque and bar text go when there is no art. ]]
	parchment = Color3.fromRGB(240, 228, 196),
	tipText = Color3.fromRGB(236, 232, 214),
	barFill = Color3.fromRGB(110, 200, 60),
	--[[ How long the screen waits for the player's save before choosing
	     the picture from what every player has met. ]]
	profileWait = 2,
}

return table.freeze(LoadingScreen)
