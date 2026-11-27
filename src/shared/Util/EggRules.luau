--!strict
--[[
	The eggs' rules (`Config/Eggs`, `Config/Pets`), pure, so the server and
	the egg screen agree and `tests/Eggs.spec` pins them: which pets an egg
	holds, each one's chance, how a roll picks one, and whether a player may
	buy it.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Economy = require(ReplicatedStorage.Shared.Config.Economy)
local Eggs = require(ReplicatedStorage.Shared.Config.Eggs)
local LaunchLocks = require(ReplicatedStorage.Shared.Util.LaunchLocks)
local LiveBoosts = require(ReplicatedStorage.Shared.Util.LiveBoosts)
local Pets = require(ReplicatedStorage.Shared.Config.Pets)

local EggRules = {}

export type Entry = { pet: string, name: string, rarity: string, chance: number }

local ORDER = { Common = 1, Uncommon = 2, Rare = 3, Epic = 4, Legendary = 5, Mythic = 6 }

EggRules.ORDER = ORDER

--[[ Whether a pet's model is in the game (`Config/PetModels`). ]]
local function built(pet: string): boolean
	local folder = ReplicatedStorage.Shared.Config:FindFirstChild("PetModels")
	return folder ~= nil and folder:FindFirstChild(pet) ~= nil
end

function EggRules.find(key: string): (Eggs.Egg?, number?)
	for index, egg in Eggs.list do
		if egg.key == key then
			return egg, index
		end
	end
	return nil, nil
end

--[[ An egg's pets, rarest last, each with its chance (0..1). Empty while
     none of them is in the game yet (the egg is a silhouette). Under `luck`
     (a live boost, `Util/LiveBoosts.odds`; 1 by default) the Legendary and
     Mythic chances are that many times larger and the others pay for it. ]]
function EggRules.pool(key: string, luck: number?): { Entry }
	local byRarity: { [string]: number } = {}
	local out: { Entry } = {}
	for pet, info in Pets do
		if info.egg == key and built(pet) and Eggs.odds[info.rarity] then
			byRarity[info.rarity] = (byRarity[info.rarity] or 0) + 1
			table.insert(out, { pet = pet, name = info.name, rarity = info.rarity, chance = 0 })
		end
	end
	local held: { [string]: number } = {}
	for rarity in byRarity do
		held[rarity] = Eggs.odds[rarity]
	end
	local odds = LiveBoosts.odds(held, luck or 1)
	local total = 0
	for _, weight in odds do
		total += weight
	end
	for _, entry in out do
		entry.chance = odds[entry.rarity] / total / byRarity[entry.rarity]
	end
	table.sort(out, function(a, b)
		if a.rarity ~= b.rarity then
			return ORDER[a.rarity] < ORDER[b.rarity]
		end
		return a.pet < b.pet
	end)
	return out
end

--[[ Picks from a pool by its chances; `r` is uniform in [0, 1), from the
     server's `Random`. ]]
function EggRules.roll(pool: { Entry }, r: number): Entry?
	local pick = r
	for _, entry in pool do
		pick -= entry.chance
		if pick < 0 then
			return entry
		end
	end
	return pool[#pool]
end

--[[ Whether a profile may buy this egg: its area is open. What it waits
     on is its own `unlock`, or at launch its `atLaunch`
     (`Util/LaunchLocks.eggUnlock`). ]]
function EggRules.open(egg: Eggs.Egg, bossesBeaten: { [string]: boolean }): boolean
	local unlock = LaunchLocks.eggUnlock(egg)
	return unlock == nil or bossesBeaten[unlock] == true
end

--[[ What a shut egg says opens it, as a shut crate does
     (`ShopRules.crateWords`): "BEAT OLD TOLLCRAB", the boss of the area it
     waits on; nil for an open one. Every shut egg said "BEAT KING BLOBLIN"
     before 2026-11-13, the Bogheart Egg's wait on the Drowned Village too. ]]
function EggRules.lockWords(
	egg: Eggs.Egg,
	bossesBeaten: { [string]: boolean }?,
	locks: boolean?
): string?
	local unlock = LaunchLocks.eggUnlock(egg, locks)
	if unlock == nil or (bossesBeaten and bossesBeaten[unlock] == true) then
		return nil
	end
	local area = Economy.areas[unlock]
	local item = area and Economy.items[area.bossItem]
	return "BEAT " .. string.upper(if item then item.boss else unlock)
end

--[[ A pet's rarity, Common for one not listed. ]]
function EggRules.rarity(pet: string): string
	local info = Pets[pet]
	return if info then info.rarity else "Common"
end

--[[ Which hatched pets go into empty slots by themselves, as slot to pet
     (owner, 2026-11-14, after the kid playtest: three eggs hatched and PET 2
     stayed empty; "Build top 5"). Only empty slots of the first `open`
     are filled, never one the player has filled; a pet already in a slot
     is not put in a second; the rarest of `hatched` goes first, and of two
     alike the one hatched first. ]]
function EggRules.fill(
	equipped: { [number]: string? },
	open: number,
	hatched: { string }
): { [number]: string }
	local taken: { [string]: boolean } = {}
	for _, pet in equipped do
		if pet then
			taken[pet] = true
		end
	end
	local waiting: { { pet: string, at: number } } = {}
	for at, pet in hatched do
		if not taken[pet] then
			taken[pet] = true
			table.insert(waiting, { pet = pet, at = at })
		end
	end
	table.sort(waiting, function(a, b)
		local ra, rb = ORDER[EggRules.rarity(a.pet)] or 0, ORDER[EggRules.rarity(b.pet)] or 0
		if ra ~= rb then
			return ra > rb
		end
		return a.at < b.at
	end)
	local out: { [number]: string } = {}
	local nextUp = 1
	for slot = 1, open do
		local pick = waiting[nextUp]
		if equipped[slot] == nil and pick then
			out[slot] = pick.pet
			nextUp += 1
		end
	end
	return out
end

return EggRules
