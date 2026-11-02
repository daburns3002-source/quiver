--!strict
--[[
	What each of the Dex Hall's three books holds, and how much of it the
	player has found (owner, 2026-10-25: three codex books -- Enemy, Weapon,
	Pet -- with the entries not yet found shown as black silhouettes).

	Nothing here is new data. The three books are three readings of what the
	game already keeps:

	- **Enemies** from `Config/NewEnemies`, found once met. Meeting an enemy
	  had nowhere lasting to be written down until save version 7, so this
	  is the one book with a field of its own (`Profile.enemiesSeen`).
	- **Weapons** from `Config/WeaponStats`, found once owned. Their
	  pictures are the 2D art (`Config/ShopAssets`), never a render of the
	  model, and their line is the one the loading screen already writes.
	- **Pets** from `Config/Pets`, found once hatched.

	A benched enemy or a pet no egg holds is still in its book: the dex is a
	record of the world, not of what is obtainable this week. What is *not*
	in a book is anything with no picture to draw, since a slot with nothing
	in it cannot even be a silhouette.

	Pure, so `tests/DexBook.spec` pins it.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Eggs = require(ReplicatedStorage.Shared.Config.Eggs)
local GearAssets = require(ReplicatedStorage.Shared.Config.GearAssets)
local LoadingPick = require(ReplicatedStorage.Shared.Util.LoadingPick)
local NewEnemies = require(ReplicatedStorage.Shared.Config.NewEnemies)
local Pets = require(ReplicatedStorage.Shared.Config.Pets)
local Sandbox = require(ReplicatedStorage.Shared.Config.Sandbox)
local SaveSchema = require(ReplicatedStorage.Shared.Util.SaveSchema)
local ShopAssets = require(ReplicatedStorage.Shared.Config.ShopAssets)
local WeaponStats = require(ReplicatedStorage.Shared.Config.WeaponStats)

--[[ `icon` goes in the grid slot and `picture` on the left page. They are
     the same for an enemy or a pet, which have one picture each; a weapon
     has both a mini pixel icon and its 2D art, and the slot is too small
     for the art. ]]
export type Entry = {
	key: string,
	name: string,
	icon: string,
	picture: string,
	description: string,
	unlocked: boolean,
}

local DexBook = {}

DexBook.BOOKS = { "Enemies", "Weapons", "Pets" }

--[[ Rarity, worst first, so a book reads up the ladder the way the hatchery
     and the shop do. Anything unrecognised sorts last. ]]
local RANK = {
	Common = 1,
	Uncommon = 2,
	Rare = 3,
	Epic = 4,
	Legendary = 5,
	Mythic = 6,
}

--[[ The areas in the order the game plays them, so enemies group by where
     they are met rather than by name. An area not listed here sorts after
     all of them, which is what a new one does until it is added. ]]
local AREAS = { MossyGlade = 1, Thornwood = 2, DrownedVillage = 3 }
local LAST_AREA = 99

local function label(weapon: string): string
	for _, entry in Sandbox.weapons do
		if entry.weapon == weapon then
			return entry.label
		end
	end
	return string.upper((weapon:gsub("(%l)(%u)", "%1 %2")))
end

local function eggName(key: string): string?
	for _, egg in Eggs.list do
		if egg.key == key then
			return egg.name
		end
	end
	return nil
end

--[[ A pet's line. It has no written description of its own anywhere, so
     this is made of what it does have: how rare it is, and which egg it
     comes out of. ]]
local function describePet(pet: Pets.Pet): string
	local rarity = string.upper(pet.rarity)
	if not pet.egg then
		return `{rarity}. Not in any egg yet.`
	end
	local egg = eggName(pet.egg)
	return if egg then `{rarity}. Hatches from the {egg}.` else `{rarity}.`
end

--[[ Sort by a rank, then by name, so a book's order never depends on the
     order a config table happens to iterate in. ]]
local function byRankThenName(
	a: { rank: number, entry: Entry },
	b: { rank: number, entry: Entry }
): boolean
	if a.rank ~= b.rank then
		return a.rank < b.rank
	end
	return a.entry.name < b.entry.name
end

local function sorted(ranked: { { rank: number, entry: Entry } }): { Entry }
	table.sort(ranked, byRankThenName)
	local out: { Entry } = {}
	for _, row in ranked do
		table.insert(out, row.entry)
	end
	return out
end

--[[ Every entry in `book`, in the order it is laid out, each saying whether
     this player has found it. With no profile, nothing is found: that is
     what a brand new player's book looks like. ]]
function DexBook.entries(book: string, profile: SaveSchema.Profile?): { Entry }
	local saved = profile
	local ranked: { { rank: number, entry: Entry } } = {}

	if book == "Enemies" then
		local seen = if saved then saved.enemiesSeen else {}
		for key, enemy in NewEnemies.enemies do
			if enemy.picture and enemy.picture ~= "" then
				table.insert(ranked, {
					rank = AREAS[enemy.area] or LAST_AREA,
					entry = {
						key = key,
						name = enemy.name,
						icon = enemy.picture,
						picture = enemy.picture,
						description = enemy.description,
						unlocked = seen[key] == true,
					},
				})
			end
		end
	elseif book == "Weapons" then
		local owned = if saved then saved.weapons else {}
		for key, stats in WeaponStats.weapons do
			local art = ShopAssets.weapons[key]
			if art then
				table.insert(ranked, {
					rank = stats.area * 10 + (RANK[stats.rarity] or 9),
					entry = {
						key = key,
						name = label(key),
						icon = GearAssets.weapons[key] or art,
						picture = art,
						description = LoadingPick.describeWeapon(key),
						unlocked = owned[key] == true,
					},
				})
			end
		end
	elseif book == "Pets" then
		local hatched = if saved then saved.pets else {}
		for key, pet in Pets do
			local icon = GearAssets.pets[key]
			if icon then
				table.insert(ranked, {
					rank = RANK[pet.rarity] or 9,
					entry = {
						key = key,
						name = pet.name,
						icon = icon,
						picture = icon,
						description = describePet(pet),
						unlocked = (hatched[key] or 0) > 0,
					},
				})
			end
		end
	end

	return sorted(ranked)
end

--[[ How many of `entries` the player has found, and how many there are. ]]
function DexBook.found(entries: { Entry }): (number, number)
	local found = 0
	for _, entry in entries do
		if entry.unlocked then
			found += 1
		end
	end
	return found, #entries
end

--[[ How many pages `entries` fills. Always at least one, so an empty book
     still draws its spread rather than nothing. ]]
function DexBook.pages(entries: { Entry }, perPage: number): number
	return math.max(1, math.ceil(#entries / perPage))
end

--[[ Page `index` (1-based) of `entries`. A short last page is short: the
     slots it does not fill are left empty, not padded. ]]
function DexBook.page(entries: { Entry }, index: number, perPage: number): { Entry }
	local out: { Entry } = {}
	local first = (index - 1) * perPage + 1
	for offset = 0, perPage - 1 do
		local entry = entries[first + offset]
		if entry then
			table.insert(out, entry)
		end
	end
	return out
end

return DexBook
