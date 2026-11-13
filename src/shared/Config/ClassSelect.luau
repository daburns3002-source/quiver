--!strict
--[[
	The class select screen (`UI/ClassScreen`), as the owner's "option B"
	(2026-11-13: "I LIKE B BUT MAKE SURE THERE IS A CHOICE IN THERE TO SWITCH
	GENDER AND ALSO MAKE SURE THE ASSASSIN CLASS IS VISIBLE BUT BLACKE DOUT",
	then "MAKE THE SWORD A LITTLE BIGGER AND MAKE THE ASSASSIN MORE
	NOTICEABLE"). The mock-ups are `assets/concepts/blocky/ui/class_select_b/`.

	`cards` are drawn in this order. Each is a class from `Config/Classes`,
	the colour of its medallion and name tag (from the UI's palette,
	`Config/UiPalette`), a line on how it plays (a "\n" breaks it), and its
	hero's head-and-shoulders portrait for each look the BOY / GIRL switch
	offers (`SaveSchema.LOOKS`). The portraits are Codex's, cut by
	`class_select_b/cut.py`: each is the medallion's square with
	`portraitTop` of it again standing above, where a plume or antlers rise
	past the circle. They are pictures only: every player wears their own
	avatar in game (class armour was scrapped, PR #572).
	`locked` is a class that is not playable yet: its card shows a blacked-out
	figure with a padlock and empty bars and cannot be chosen, on the screen or
	on the server (`Data/Shop`'s own list of playable classes decides there).
]]

export type Card = {
	class: string,
	locked: boolean,
	colour: Color3,
	pitch: string,
	portraits: { [string]: string },
}

export type Look = { look: string, words: string, icon: string }

export type Stat = { key: string, words: string, icon: string }

local UiPalette = require(script.Parent.UiPalette)

local ASSASSIN = "rbxassetid://108317335485104"

local ClassSelect = {
	cards = {
		{
			class = "Ranger",
			locked = false,
			colour = UiPalette.go.top,
			pitch = "FAST SHOTS FROM\nFAR AWAY",
			portraits = {
				male = "rbxassetid://92916280523106",
				female = "rbxassetid://131299876391682",
			},
		},
		{
			class = "Arcanist",
			locked = false,
			colour = UiPalette.header.top,
			pitch = "SLOW ORBS THAT\nBLAST",
			portraits = {
				male = "rbxassetid://134595032303494",
				female = "rbxassetid://72933285644547",
			},
		},
		{
			class = "Warden",
			locked = false,
			colour = UiPalette.danger.top,
			pitch = "A BIG SWORD,\nUP CLOSE",
			portraits = {
				male = "rbxassetid://87720916199080",
				female = "rbxassetid://101494182702223",
			},
		},
		{
			class = "Assassin",
			locked = true,
			colour = UiPalette.off.top,
			pitch = "NOT HERE YET",
			portraits = { male = ASSASSIN, female = ASSASSIN },
		},
	} :: { Card },
	--[[ The switch's two halves, left to right; `look` is what is saved. ]]
	looks = {
		{ look = "male", words = "BOY", icon = "rbxassetid://93159798243376" },
		{ look = "female", words = "GIRL", icon = "rbxassetid://94031846279290" },
	} :: { Look },
	--[[ The three bars, top to bottom (`Util/ClassStats` has the numbers). ]]
	stats = {
		{ key = "range", words = "RANGE", icon = "rbxassetid://90692011638345" },
		{ key = "power", words = "POWER", icon = "rbxassetid://138073113934919" },
		{ key = "speed", words = "SPEED", icon = "rbxassetid://79655151450234" },
	} :: { Stat },
	--[[ The padlock over a locked class's figure. ]]
	lock = "rbxassetid://128665050319850",
	portraitTop = 96 / 640,
}

return table.freeze(ClassSelect)
