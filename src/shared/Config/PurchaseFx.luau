--!strict
--[[
	The burst that plays on the buyer's screen whenever a purchase goes
	through (owner, 2026-11-14: "i also want a big ui effect to play
	whenever someone purchases something"). `Util/PurchaseRules` reads a
	purchase's size out of this and `UI/PurchaseFx` draws it.

	Three sizes. A purchase is `big` at or over `big`'s amount of what it
	was paid in, and `huge` when it was paid in Robux or bought a thing of a
	`grand` rarity outright (a Legendary from the Blacksmith's store). What
	an egg or a crate rolled never makes it bigger: the burst plays before
	the reveal and would give the surprise away.

	Lengths are seconds; `reach`, `piece` and `word` are sheet pixels (a
	1920 x 1080 screen, or 1080 x 1920 held upright), so the burst is the
	same share of any screen.
]]

export type Look = {
	--[[ The punchy word. ]]
	word: string,
	--[[ Coins or diamonds thrown, and the small sparks among them. ]]
	pieces: number,
	sparks: number,
	--[[ Rings that spread from the button pressed. ]]
	rings: number,
	--[[ How far the pieces fly and the rings spread. ]]
	reach: number,
	--[[ A thrown piece's side, and the word's height. ]]
	piece: number,
	wordHeight: number,
	--[[ How strongly the whole screen is washed for a moment (0 none). ]]
	flash: number,
	length: number,
}

local PurchaseFx = {
	big = { coins = 2500, gems = 400, soulstones = 400 } :: { [string]: number },
	grand = { Legendary = true, Mythic = true } :: { [string]: boolean },

	sizes = {
		small = {
			word = "KA-CHING!",
			pieces = 12,
			sparks = 10,
			rings = 1,
			reach = 420,
			piece = 64,
			wordHeight = 96,
			flash = 0,
			length = 0.9,
		},
		big = {
			word = "BIG BUY!",
			pieces = 22,
			sparks = 16,
			rings = 2,
			reach = 620,
			piece = 76,
			wordHeight = 124,
			flash = 0.14,
			length = 1.05,
		},
		huge = {
			word = "MEGA BUY!",
			pieces = 36,
			sparks = 26,
			rings = 3,
			reach = 860,
			piece = 88,
			wordHeight = 156,
			flash = 0.22,
			length = 1.25,
		},
	} :: { [string]: Look },

	--[[ The sound (`Config/Sounds`) and how long a press on a button stays
	     the place the burst comes from; later than that, or for Robux
	     (whose last press was on Roblox's own prompt), it comes from
	     `centre`, a share of the screen. ]]
	sound = "purchase",
	pressAge = 5,
	centre = { 0.5, 0.42 },
	--[[ Over the reveal (180) and the store's thank-you (160), and it takes
	     no input, so nothing under it waits. ]]
	displayOrder = 185,
	--[[ Bursts on screen at once before the oldest is dropped. ]]
	most = 3,
}

return table.freeze(PurchaseFx)
