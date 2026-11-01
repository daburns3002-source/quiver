--!strict
--[[
	The weapon shop's rules (`Config/Shop`), pure, so the server and the
	shop screen agree and `tests/Shop.spec` pins them: which weapons each
	area's crate holds, how a roll picks one, what the store charges, and
	which class holds a weapon.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Economy = require(ReplicatedStorage.Shared.Config.Economy)
local Purse = require(script.Parent.Purse)
local Sandbox = require(ReplicatedStorage.Shared.Config.Sandbox)
local Shop = require(ReplicatedStorage.Shared.Config.Shop)
local WeaponStats = require(ReplicatedStorage.Shared.Config.WeaponStats)

local ShopRules = {}

export type Entry = { weapon: string, class: string, label: string, rarity: string, area: number }

local ORDER = { Common = 1, Uncommon = 2, Rare = 3, Epic = 4, Legendary = 5, Mythic = 6 }

--[[ Every weapon a player can own: one with stats and a class to hold it,
     not a pair the Dual Bows card swaps in, and from an area that is
     stocked (`Config/Shop`'s `stocked`). In rarity order.

     An unstocked area's weapons exist -- they are modelled, held and
     fought with in the sandbox -- but they are not for sale, so they are
     not here either: this is what the store, the crates and the gear
     screen all read. ]]
function ShopRules.catalog(): { Entry }
	local out = {}
	for _, entry in Sandbox.weapons do
		local stats = WeaponStats.weapons[entry.weapon]
		local crate = stats and Shop.crates[stats.area]
		if stats and crate and crate.stocked then
			table.insert(out, {
				weapon = entry.weapon,
				class = entry.class,
				label = entry.label,
				rarity = stats.rarity :: string,
				area = stats.area,
			})
		end
	end
	table.sort(out, function(a, b)
		if a.area ~= b.area then
			return a.area < b.area
		end
		if a.class ~= b.class then
			return a.class < b.class
		end
		return ORDER[a.rarity] < ORDER[b.rarity]
	end)
	return out
end

function ShopRules.find(weapon: string): Entry?
	for _, entry in ShopRules.catalog() do
		if entry.weapon == weapon then
			return entry
		end
	end
	return nil
end

--[[ What area `index`'s chest can give: its weapons of a rarity the chest
     rolls, and of `class` when one is named — an area's crate is three
     chests, one a class (`Shop.chests`). Empty for an area with no weapons
     yet (a silhouette). ]]
function ShopRules.cratePool(index: number, class: string?): { Entry }
	local out = {}
	for _, entry in ShopRules.catalog() do
		local wanted = class == nil or entry.class == class
		if entry.area == index and wanted and Shop.crateOdds[entry.rarity] then
			table.insert(out, entry)
		end
	end
	return out
end

--[[ Whether `class` is one of the three chests, which is what the server
     checks before it charges for one. ]]
function ShopRules.chest(class: unknown): Shop.Chest?
	for _, chest in Shop.chests do
		if chest.class == class then
			return chest
		end
	end
	return nil
end

--[[ Picks from a crate's pool: a rarity by `Shop.crateOdds` (only those
     the pool has), then a weapon of it. `r1` and `r2` are uniform in
     [0, 1), from the server's `Random`. ]]
function ShopRules.roll(pool: { Entry }, r1: number, r2: number): Entry?
	local byRarity: { [string]: { Entry } } = {}
	local total = 0
	for _, entry in pool do
		if not byRarity[entry.rarity] then
			byRarity[entry.rarity] = {}
			total += Shop.crateOdds[entry.rarity] or 0
		end
		table.insert(byRarity[entry.rarity], entry)
	end
	if total <= 0 then
		return nil
	end
	local rarities = {}
	for rarity in byRarity do
		table.insert(rarities, rarity)
	end
	table.sort(rarities, function(a, b)
		return ORDER[a] < ORDER[b]
	end)
	local pick = r1 * total
	for _, rarity in rarities do
		pick -= Shop.crateOdds[rarity]
		if pick < 0 then
			local list = byRarity[rarity]
			return list[math.clamp(math.floor(r2 * #list) + 1, 1, #list)]
		end
	end
	local last = byRarity[rarities[#rarities]]
	return last[#last]
end

--[[ A weapon's chance (0..1) from crate `index`, as `roll` picks it: its
     rarity's share of the rarities the crate has, split evenly by the
     weapons of that rarity. ]]
function ShopRules.chance(index: number, entry: Entry, class: string?): number
	local total, same = 0, 0
	local seen: { [string]: boolean } = {}
	for _, other in ShopRules.cratePool(index, class) do
		if not seen[other.rarity] then
			seen[other.rarity] = true
			total += Shop.crateOdds[other.rarity] or 0
		end
		if other.rarity == entry.rarity then
			same += 1
		end
	end
	if total <= 0 or same == 0 then
		return 0
	end
	return (Shop.crateOdds[entry.rarity] or 0) / total / same
end

--[[ The store's price for a weapon, or nil when the store does not sell
     it (the class weapons, Mythics). ]]
function ShopRules.price(entry: Entry): Purse.Cost?
	local crate = Shop.crates[entry.area]
	if not crate then
		return nil
	end
	if entry.rarity == "Legendary" then
		local item = Economy.areas[crate.area] and Economy.areas[crate.area].bossItem
		if not item then
			return nil
		end
		local scale = crate.price / Shop.crates[1].price
		return {
			coins = math.floor(Shop.legendaryCoins * scale),
			items = { [item] = Shop.legendaryItems },
		}
	end
	local gems = Shop.gemPrices[entry.rarity]
	if not gems then
		return nil
	end
	return { gems = gems * entry.area }
end

--[[ Coins paid back when a crate gives a weapon already owned. ]]
function ShopRules.refund(index: number): number
	local crate = Shop.crates[index]
	return if crate then math.floor(crate.price * Shop.duplicateRefund) else 0
end

return ShopRules
