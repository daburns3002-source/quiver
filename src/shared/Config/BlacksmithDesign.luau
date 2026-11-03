--!strict
--[[
	The Blacksmith.

	The owner's call on 2026-11-03, after three passes at building both
	shop stations from their own sheets came out wrong in game: "just
	reuse the building that you made for the codex and recolor it". The
	Egg Hatchery went first; this is the same answer for the Blacksmith.
	It is the Dex Hall's building -- the same plinth, timber frame, porch
	columns, low gable roof, counter, shelves, lanterns and two front pads,
	built by the one `hall` builder in `Run/Lobby` -- wearing the forge's
	palette, with weapons where the Dex Hall has books.

	Its geometry therefore lives in `Config/Lobby.dex` with the Dex Hall's,
	and is not repeated here. What is here is what makes it the forge: the
	colours, and what stands on the pads and the roof.

	The palette is read off `assets/concepts/blocky/lobby/ref4_blacksmith.png`
	-- purple-grey stone, warm brown timber, gold trim, a red runner and
	the forge's own orange through the windows -- so all three stations
	read as one architecture in three liveries, which is what the owner
	asked for. Every key matches `Config/Lobby.dex.colours`, because the
	one builder reads them all through the same names.

	Offsets are in the building's own frame: +Z is the way it faces (toward
	the middle of the clearing, `Config/Lobby.facing`), +X to the right of
	a player standing in front of it, and y is height above the lawn.
]]

local BlacksmithDesign = {
	--[[ What stands on the two front pads: a rack of the three classes'
	     weapons on one, a suit of armour on the other. Both are the
	     lobby's own pieces, the same ones the sandbox and the cottage
	     shops use. ]]
	rack = { "sword", "bow", "staff" },

	--[[ The great sword standing on the ridge, where the Dex Hall rests
	     its open book. `grow` is how many times a hand sword's size it
	     is drawn, and `seat` how far its guard sits below the ridge so
	     the blade rises out of the roof rather than floating over it.

	     It came down from 2.1: at that size the blade stood half again
	     the height of the building and was the first thing you saw from
	     anywhere in the clearing, where the roof ornament should read as
	     a weathervane. ]]
	roofSword = { grow = 1.4, seat = 1.1, forward = 4 },

	--[[
		The forge's livery. Every key here is one the shared `hall`
		builder reads, and `Config/Lobby.dex.colours` has the same set in
		the Dex Hall's purple.
	]]
	colours = {
		--[[ The roof is the sheet's purple-grey rock rather than a
		     colour of its own: on the sheet the forge is cut into stone
		     and roofed with it. ]]
		roof = Color3.fromRGB(96, 86, 112),
		gold = Color3.fromRGB(250, 170, 45),
		timber = Color3.fromRGB(150, 88, 40),
		--[[ The panels are pale stone, well off the timber: at a darker
		     grey the frame and the fill ran together and the whole shop
		     read as another wooden cottage. ]]
		panel = Color3.fromRGB(198, 196, 206),
		stone = Color3.fromRGB(150, 146, 158),
		column = Color3.fromRGB(196, 192, 202),
		--[[ The runner into the shop, in the banners' own red. ]]
		red = Color3.fromRGB(186, 36, 36),
		lantern = Color3.fromRGB(255, 176, 72),
		iron = Color3.fromRGB(30, 30, 30),
		--[[ The windows: the forge burning behind them, which is what
		     lights this shop on the sheet. ]]
		glass = Color3.fromRGB(255, 186, 96),
		--[[ What stands on the shelves behind the counter: stock, in
		     steel, gold and the banners' red. ]]
		books = {
			Color3.fromRGB(206, 210, 220),
			Color3.fromRGB(250, 170, 45),
			Color3.fromRGB(186, 36, 36),
		},
	},
}

return table.freeze(BlacksmithDesign)
