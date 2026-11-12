--!strict
--[[
	The Soulstone shop (owner, 2026-11-11: Soulstones buy eggs and crates).

	Soulstones are Endless's own currency, kept apart from coins and gems so
	the mode cannot inflate the story economy (`docs/ENDLESS.md`). A run pays
	at most `Balance.Endless.runCap` (525) and a floor-30 run about 150, with
	the one-time milestones on top, so at `base` 100 a decent run buys an egg
	or a crate of the first area, and two runs one of the second.

	`base` is the price of one of the first area's eggs or crates; each area
	after it doubles (`Util/SoulstoneShopRules.price`). `counts` is how many
	one press buys. Placeholder numbers, as the coin prices are.
]]

return table.freeze({
	base = 100,
	counts = { 1, 5 },
})
