--!strict
--[[
	Card rarities, from the upgrade card design (design_handoff_upgrade_cards,
	data/rarities.json).

	`weight` is how often a card of this rarity is dealt relative to the
	others: a Common is five times as likely as a Legendary, and a Mythic
	about a third as likely again. `color`, `light` and `dark` are the card's
	gradient — light is the colour mixed 38% with white, dark 38% with black.
]]

export type Name = "Common" | "Uncommon" | "Rare" | "Epic" | "Legendary" | "Mythic"

export type Rarity = {
	name: Name,
	--[[ 1 for Common up to 6 for Mythic. ]]
	tier: number,
	color: Color3,
	light: Color3,
	dark: Color3,
	weight: number,
}

local list: { Rarity } = {
	{
		name = "Common",
		tier = 1,
		color = Color3.fromRGB(169, 177, 186),
		light = Color3.fromRGB(202, 207, 212),
		dark = Color3.fromRGB(105, 110, 115),
		weight = 5,
	},
	{
		name = "Uncommon",
		tier = 2,
		color = Color3.fromRGB(95, 196, 110),
		light = Color3.fromRGB(156, 218, 165),
		dark = Color3.fromRGB(59, 122, 68),
		weight = 4,
	},
	{
		name = "Rare",
		tier = 3,
		color = Color3.fromRGB(79, 163, 242),
		light = Color3.fromRGB(146, 198, 247),
		dark = Color3.fromRGB(49, 101, 150),
		weight = 3,
	},
	{
		name = "Epic",
		tier = 4,
		color = Color3.fromRGB(178, 108, 232),
		light = Color3.fromRGB(207, 164, 241),
		dark = Color3.fromRGB(110, 67, 144),
		weight = 2,
	},
	{
		name = "Legendary",
		tier = 5,
		color = Color3.fromRGB(244, 181, 63),
		light = Color3.fromRGB(248, 209, 136),
		dark = Color3.fromRGB(151, 112, 39),
		weight = 1,
	},
	{
		name = "Mythic",
		tier = 6,
		color = Color3.fromRGB(232, 32, 46),
		light = Color3.fromRGB(255, 106, 85),
		dark = Color3.fromRGB(61, 8, 17),
		weight = 0.35,
	},
}

local byName: { [string]: Rarity } = {}
for _, rarity in list do
	byName[rarity.name] = rarity
end

return table.freeze({
	list = list,
	byName = byName,
})
