--!strict
--[[
	The Egg Hatchery.

	The owner's call on 2026-11-03, after three passes at building it from
	its own sheets came out wrong in game: "just reuse the building that
	you made for the codex and recolor it". So the Hatchery is now the Dex
	Hall's building -- the same plinth, timber frame, porch columns, low
	gable roof, counter, shelves, lanterns and two front pads, built by the
	one `hall` builder in `Run/Lobby` -- wearing the palette below, with
	eggs where the Dex Hall has books.

	Its geometry therefore lives in `Config/Lobby.dex` with the Dex Hall's,
	and is not repeated here. What is here is what makes it the Hatchery
	rather than the Dex Hall: the colours, and the eggs.

	The palette is the Egg Hatchery's own, taken off
	`assets/concepts/blocky/lobby/ref4_hatchery.png` -- cream stone, a
	magenta roof, gold trim, cyan light and green timber -- so the two
	buildings read as the same architecture in two liveries, which is what
	the owner asked for. Every key matches `Config/Lobby.dex.colours`,
	because the one builder reads both through the same names.

	Offsets are in the building's own frame: +Z is the way it faces (toward
	the middle of the clearing, `Config/Lobby.facing`), +X to the right of
	a player standing in front of it, and y is height above the lawn.
]]

local HatcheryDesign = {
	--[[ The egg standing on each of the two front pads, and the big one on
	     the roof where the Dex Hall rests its open book. `seat` is how far
	     the roof egg's middle sits below the ridge. ]]
	padEgg = { wide = 4.6, tall = 5.6 },
	roofEgg = { wide = 7.4, tall = 9, seat = 1.2 },
	--[[ The nest of gold straw each pad egg sits in. ]]
	nest = { across = 5.8, tall = 1.1 },

	--[[ The eggs' shells and the two spot colours the sheet dots them
	     with, which `Run/Lobby.egg` scatters over each shell. ]]
	shell = Color3.fromRGB(240, 232, 214),
	spotA = Color3.fromRGB(232, 51, 143),
	spotB = Color3.fromRGB(158, 68, 230),

	--[[
		The building's livery. Every key here is one the shared `hall`
		builder reads, and `Config/Lobby.dex.colours` has the same set in
		the Dex Hall's purple.
	]]
	colours = {
		--[[ The roof, in the sheet's magenta instead of the Dex's purple. ]]
		roof = Color3.fromRGB(198, 44, 124),
		gold = Color3.fromRGB(250, 205, 70),
		--[[ The frame is green rather than brown: this is the garden
		     station, and the sheet's only woodwork is leaf and vine. Deep
		     rather than bright -- at a lighter green the beams stopped
		     reading as a frame round the cream panels and the whole
		     front went lime. ]]
		timber = Color3.fromRGB(58, 114, 44),
		panel = Color3.fromRGB(248, 242, 226),
		stone = Color3.fromRGB(233, 221, 196),
		column = Color3.fromRGB(255, 255, 255),
		--[[ The runner over the porch: cyan, which is the light the sheet
		     runs through all of this station's stonework. ]]
		red = Color3.fromRGB(88, 198, 228),
		lantern = Color3.fromRGB(255, 186, 96),
		iron = Color3.fromRGB(30, 30, 30),
		glass = Color3.fromRGB(186, 240, 255),
		--[[ What stands on the shelves behind the counter: eggs, in the
		     three colours the sheet spots its shells with. ]]
		books = {
			Color3.fromRGB(232, 51, 143),
			Color3.fromRGB(158, 68, 230),
			Color3.fromRGB(64, 214, 245),
		},
	},
}

return table.freeze(HatcheryDesign)
