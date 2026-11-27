--!strict
--[[
	The Soulstone shop's rules (`Config/SoulstoneShop`; owner, 2026-11-11,
	asked what Soulstones should buy: eggs and crates). Soulstones are the
	Endless currency (`SaveSchema.soulstones`), paid only by Endless, and
	until now nothing sold for them (the 2026-11-11 loop and UI review).

	What is for sale to a player, and at what price. The server checks a
	purchase against exactly this (`Server/Data/SoulstoneShop`) and the
	screen draws exactly this (`UI/SoulstoneShop`).
]]

local Config = require(script.Parent.Parent.Config.SoulstoneShop)
local EggRules = require(script.Parent.EggRules)
local Eggs = require(script.Parent.Parent.Config.Eggs)
local Shop = require(script.Parent.Parent.Config.Shop)
local ShopRules = require(script.Parent.ShopRules)

local SoulstoneShopRules = {}

export type Offer = {
	kind: "Egg" | "Crate",
	--[[ An egg's key, or a crate's place in `Config/Shop.crates` as text. ]]
	key: string,
	name: string,
	--[[ The price of one, in Soulstones. ]]
	price: number,
}

--[[ An area's place in the campaign (`Config/Shop.crates`' order), 1 for
     the first; 1 for an area that is not listed. ]]
local function areaIndex(area: string): number
	for index, crate in Shop.crates do
		if crate.area == area then
			return index
		end
	end
	return 1
end

--[[ One of area `index`'s eggs or crates: the base price, doubling an
     area. ]]
function SoulstoneShopRules.price(index: number): number
	return Config.base * 2 ^ (math.max(1, index) - 1)
end

--[[ Whether `count` is a number of them one press may buy. ]]
function SoulstoneShopRules.countAllowed(count: unknown): boolean
	return type(count) == "number" and table.find(Config.counts, count) ~= nil
end

--[[ Everything for sale to a player who has beaten these bosses and plays
     `class`: each egg open to them that has pets, then each crate that has
     weapons for the class. In campaign order. ]]
function SoulstoneShopRules.offers(bossesBeaten: { [string]: boolean }, class: string?): { Offer }
	local out: { Offer } = {}
	for _, egg in Eggs.list do
		if EggRules.open(egg, bossesBeaten) and #EggRules.pool(egg.key) > 0 then
			table.insert(out, {
				kind = "Egg",
				key = egg.key,
				name = egg.name,
				price = SoulstoneShopRules.price(areaIndex(egg.area)),
			})
		end
	end
	for index, crate in Shop.crates do
		if #ShopRules.cratePool(index, class) > 0 then
			table.insert(out, {
				kind = "Crate",
				key = tostring(index),
				name = `{crate.name} CRATE`,
				price = SoulstoneShopRules.price(index),
			})
		end
	end
	return out
end

--[[ The offer a purchase names, or nil if it is not for sale to them. ]]
function SoulstoneShopRules.find(
	bossesBeaten: { [string]: boolean },
	class: string?,
	kind: unknown,
	key: unknown
): Offer?
	for _, offer in SoulstoneShopRules.offers(bossesBeaten, class) do
		if offer.kind == kind and offer.key == key then
			return offer
		end
	end
	return nil
end

return SoulstoneShopRules
