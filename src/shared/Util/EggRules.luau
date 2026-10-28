--!strict
--[[
	The eggs' rules (`Config/Eggs`, `Config/Pets`), pure, so the server and
	the egg screen agree and `tests/Eggs.spec` pins them: which pets an egg
	holds, each one's chance, how a roll picks one, and whether a player may
	buy it.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Eggs = require(ReplicatedStorage.Shared.Config.Eggs)
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
     none of them is in the game yet (the egg is a silhouette). ]]
function EggRules.pool(key: string): { Entry }
	local byRarity: { [string]: number } = {}
	local out: { Entry } = {}
	for pet, info in Pets do
		if info.egg == key and built(pet) and Eggs.odds[info.rarity] then
			byRarity[info.rarity] = (byRarity[info.rarity] or 0) + 1
			table.insert(out, { pet = pet, name = info.name, rarity = info.rarity, chance = 0 })
		end
	end
	local total = 0
	for rarity in byRarity do
		total += Eggs.odds[rarity]
	end
	for _, entry in out do
		entry.chance = Eggs.odds[entry.rarity] / total / byRarity[entry.rarity]
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

--[[ Whether a profile may buy this egg: its area is open. ]]
function EggRules.open(egg: Eggs.Egg, bossesBeaten: { [string]: boolean }): boolean
	return egg.unlock == nil or bossesBeaten[egg.unlock] == true
end

--[[ A pet's rarity, Common for one not listed. ]]
function EggRules.rarity(pet: string): string
	local info = Pets[pet]
	return if info then info.rarity else "Common"
end

return EggRules
