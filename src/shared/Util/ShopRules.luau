--!strict
--[[
	The weapon shop's rules (`Config/Shop`), pure, so the server and the
	shop screen agree and `tests/Shop.spec` pins them: which weapons each
	area's crate holds, how a roll picks one, what the store charges, and
	which class holds a weapon.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Economy = require(ReplicatedStorage.Shared.Config.Economy)
local LaunchLocks = require(script.Parent.LaunchLocks)
local MergeRules = require(script.Parent.MergeRules)
local Purse = require(script.Parent.Purse)
local Sandbox = require(ReplicatedStorage.Shared.Config.Sandbox)
local Shop = require(ReplicatedStorage.Shared.Config.Shop)
local WeaponStats = require(ReplicatedStorage.Shared.Config.WeaponStats)

local ShopRules = {}

export type Entry = {
	weapon: string,
	class: string,
	label: string,
	rarity: string,
	area: number,
	--[[ Earned, not sold or rolled (`WeaponStats.earned`): a golden weapon. ]]
	earned: boolean?,
}

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
				earned = stats.earned,
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
     yet (a silhouette). An earned weapon (a golden one) is in no chest. ]]
function ShopRules.cratePool(index: number, class: string?): { Entry }
	local out = {}
	for _, entry in ShopRules.catalog() do
		local wanted = class == nil or entry.class == class
		if entry.area == index and wanted and not entry.earned and Shop.crateOdds[entry.rarity] then
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

--[[ Each rarity's share (0..1) of an open from `pool`, by `Shop.crateOdds`.
     A Mythic keeps its own share of the full odds whatever else the chest
     holds (owner, 2026-10-28: "make the odds of pulling a mythic 1%"); a
     rarity the chest lacks (the Drowned Village has no Uncommon bow) gives
     its share to the other rarities, in proportion. For a chest with every
     rarity that is exactly `crateOdds` over its total. ]]
local FIXED = { Mythic = true }
local function shares(pool: { Entry }): { [string]: number }
	local full, present, fixed = 0, 0, 0
	local has: { [string]: boolean } = {}
	for _, odds in Shop.crateOdds do
		full += odds
	end
	for _, entry in pool do
		if not has[entry.rarity] then
			has[entry.rarity] = true
			local odds = Shop.crateOdds[entry.rarity] or 0
			if FIXED[entry.rarity] then
				fixed += odds
			else
				present += odds
			end
		end
	end
	local out: { [string]: number } = {}
	if full <= 0 then
		return out
	end
	-- a chest of only fixed rarities has nothing to give the rest to
	local rest = if present > 0 then 1 - fixed / full else 0
	for rarity in has do
		local odds = Shop.crateOdds[rarity] or 0
		if FIXED[rarity] then
			out[rarity] = if present > 0 then odds / full else odds / math.max(fixed, 1e-9)
		elseif present > 0 then
			out[rarity] = odds / present * rest
		end
	end
	return out
end

--[[ Picks from a crate's pool: a rarity by its share (`shares`), then a
     weapon of it. `r1` and `r2` are uniform in [0, 1), from the server's
     `Random`. ]]
function ShopRules.roll(pool: { Entry }, r1: number, r2: number): Entry?
	local byRarity: { [string]: { Entry } } = {}
	for _, entry in pool do
		byRarity[entry.rarity] = byRarity[entry.rarity] or {}
		table.insert(byRarity[entry.rarity], entry)
	end
	local share = shares(pool)
	local rarities = {}
	local total = 0
	for rarity in byRarity do
		if (share[rarity] or 0) > 0 then
			table.insert(rarities, rarity)
			total += share[rarity]
		end
	end
	if total <= 0 then
		return nil
	end
	table.sort(rarities, function(a, b)
		return ORDER[a] < ORDER[b]
	end)
	local pick = r1 * total
	for _, rarity in rarities do
		pick -= share[rarity]
		if pick < 0 then
			local list = byRarity[rarity]
			return list[math.clamp(math.floor(r2 * #list) + 1, 1, #list)]
		end
	end
	local last = byRarity[rarities[#rarities]]
	return last[#last]
end

--[[ A weapon's chance (0..1) from crate `index`, as `roll` picks it: its
     rarity's share, split evenly by the weapons of that rarity. ]]
function ShopRules.chance(index: number, entry: Entry, class: string?): number
	local pool = ShopRules.cratePool(index, class)
	local same = 0
	for _, other in pool do
		if other.rarity == entry.rarity then
			same += 1
		end
	end
	if same == 0 then
		return 0
	end
	return (shares(pool)[entry.rarity] or 0) / same
end

--[[ Whether a player who has beaten `bossesBeaten` may open crate `index`
     and buy from its area's store: what it waits on at launch
     (`Util/LaunchLocks.crateUnlock`) is beaten, or it waits on nothing. ]]
function ShopRules.crateOpen(
	index: number,
	bossesBeaten: { [string]: boolean }?,
	locks: boolean?
): boolean
	local crate = Shop.crates[index]
	local unlock = if crate then LaunchLocks.crateUnlock(crate, locks) else nil
	return unlock == nil or (bossesBeaten ~= nil and bossesBeaten[unlock] == true)
end

--[[ What a shut crate says opens it: "BEAT THE BROODMOTHER", nil for an
     open one. ]]
function ShopRules.crateWords(
	index: number,
	bossesBeaten: { [string]: boolean }?,
	locks: boolean?
): string?
	if ShopRules.crateOpen(index, bossesBeaten, locks) then
		return nil
	end
	local crate = Shop.crates[index]
	local unlock = crate and LaunchLocks.crateUnlock(crate, locks)
	local area = unlock and Economy.areas[unlock]
	local item = area and Economy.items[area.bossItem]
	return "BEAT " .. string.upper(if item then item.boss else tostring(unlock))
end

--[[ The store's price for a weapon, or nil when the store does not sell
     it (the class weapons, Mythics, the earned golden weapons). ]]
function ShopRules.price(entry: Entry): Purse.Cost?
	local crate = Shop.crates[entry.area]
	if not crate or entry.earned then
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

--[[ Whether a weapon has merge tiers (`Util/MergeRules`): every weapon but
     one that can never be had twice (`WeaponStats.earned`; owner,
     2026-11-14: "for weapons with no duplicates ... there should not be a
     merge tier"). The server, the damage and the screens all ask this. ]]
function ShopRules.merges(weapon: string?): boolean
	local stats = if weapon then WeaponStats.weapons[weapon] else nil
	return not (stats ~= nil and stats.earned == true)
end

--[[ A weapon's damage scale at merge tier `tier`: its rarity's bonus, its
     area's scale and the tier's (`Config/WeaponStats`, `Util/MergeRules`),
     as `Run/RunSession` multiplies them; no tier's for a weapon that has
     none (`merges`). 0 for one with no stats. ]]
function ShopRules.strength(weapon: string?, tier: string?): number
	local stats = if weapon then WeaponStats.weapons[weapon] else nil
	if not stats then
		return 0
	end
	local held = if ShopRules.merges(weapon) then tier or "C" else "C"
	return (1 + WeaponStats.bonus[stats.rarity])
		* (WeaponStats.areaScale[stats.area] or 1)
		* (MergeRules.weaponScale[held] or 1)
end

--[[ Of the weapons just `gained`, the one that goes in hand by itself
     (owner, 2026-11-14, after the kid playtest: the crate's bow stayed in
     the bag; "Build top 5"): one `class` holds that is strictly stronger
     than `equipped` (`strength`, each at the tier `tierOf` says is held),
     the strongest of them. Nil for none, so a weapon the player chose is
     never swapped for a weaker or an equal one. ]]
function ShopRules.upgrade(
	gained: { string },
	class: string?,
	equipped: string?,
	tierOf: (string) -> string?
): string?
	local best: string? = nil
	local bestStrength = ShopRules.strength(equipped, if equipped then tierOf(equipped) else nil)
	for _, weapon in gained do
		local entry = ShopRules.find(weapon)
		if entry and entry.class == class then
			local strength = ShopRules.strength(weapon, tierOf(weapon))
			if strength > bestStrength then
				best, bestStrength = weapon, strength
			end
		end
	end
	return best
end

return ShopRules
