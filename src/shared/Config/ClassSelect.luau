--!strict
--[[
	The cards on the class select screen (`UI/ClassScreen`), in the order
	they are drawn (owner, 2026-11-11: "the change class screen needs to be
	fixed. it looks too ai right now").

	Each is a class from `Config/Classes`, the colour its card is filled
	with (from the UI's palette, `Config/UiPalette`), and a line on how it
	plays. The picture on the card is not here:
	it is the player's own character holding the class's weapon, drawn live.
	`locked` is a class that is not playable yet: its card shows a lock and
	cannot be chosen, on the screen or on the server (`Data/Shop`'s own
	list of playable classes decides there).
]]

export type Card = {
	class: string,
	locked: boolean,
	colour: Color3,
	pitch: string,
}

local UiPalette = require(script.Parent.UiPalette)

local ClassCards: { Card } = {
	{
		class = "Ranger",
		locked = false,
		colour = UiPalette.go.top,
		pitch = "FAST SHOTS FROM FAR AWAY",
	},
	{
		class = "Arcanist",
		locked = false,
		colour = UiPalette.header.top,
		pitch = "SLOW ORBS THAT BLAST",
	},
	{
		class = "Warden",
		locked = false,
		colour = UiPalette.danger.top,
		pitch = "A BIG SWORD, UP CLOSE",
	},
	{
		class = "Assassin",
		locked = true,
		colour = UiPalette.off.top,
		pitch = "NOT HERE YET",
	},
}

return table.freeze(ClassCards)
