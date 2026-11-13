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

	**A book is a page an area** (owner, 2026-11-12: "the dexes should be 1
	page for each area with bigger icons on the right page. the page should
	also be themed to match the area"): every entry says which area it is
	from, `areas` lists the areas a book has anything from in the order the
	game plays them, and `inArea` is that area's page. `Config/Dex.areas`
	has each area's look.

	A pet no egg holds is still in its book: the dex is a record of the
	world, not of what is obtainable this week. A **benched** enemy is not,
	because it cannot be met at all -- it would be a slot that can never be
	anything but a silhouette, which reads as a dex you can never finish.
	Nothing with no picture is in a book either, since a slot with nothing
	in it cannot even be a silhouette.

	Pure, so `tests/DexBook.spec` pins it.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Eggs = require(ReplicatedStorage.Shared.Config.Eggs)
local GearAssets = require(ReplicatedStorage.Shared.Config.GearAssets)
local LoadingPick = require(ReplicatedStorage.Shared.Util.LoadingPick)
local MergeRules = require(ReplicatedStorage.Shared.Util.MergeRules)
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
	--[[ The frame the tile wears: a weapon's or pet's rarity. Enemies
	     carry none, so they wear Common. ]]
	rarity: string,
	--[[ The area it is from (a `Balance.Stages` `area`), which is the page
	     it is on. ]]
	area: string,
	--[[ One short fact for the line under the name: where an enemy is met,
	     or a weapon's or pet's rarity. ]]
	detail: string,
	--[[ The best merge tier held of a found weapon or pet (`Util/MergeRules`),
	     for the letter in its tile's bottom left. Nil for an enemy, and for
	     anything not found. ]]
	tier: string?,
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
DexBook.AREAS = { "MossyGlade", "Thornwood", "DrownedVillage", "BogheartCaverns" }
local AREAS: { [string]: number } = {}
for index, area in DexBook.AREAS do
	AREAS[area] = index
end
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
--[[ The page's line under the rarity pill, which already names the rarity
     (it said "COMMON." twice on the page until 2026-11-13). ]]
local function describePet(pet: Pets.Pet): string
	if not pet.egg then
		return "Not in any egg yet."
	end
	local egg = eggName(pet.egg)
	return if egg then `Hatches from the {egg}.` else ""
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
			if enemy.picture and enemy.picture ~= "" and not enemy.benched then
				table.insert(ranked, {
					rank = AREAS[enemy.area] or LAST_AREA,
					entry = {
						key = key,
						name = enemy.name,
						icon = enemy.picture,
						picture = enemy.picture,
						description = enemy.description,
						unlocked = seen[key] == true,
						rarity = "Common",
						area = enemy.area,
						detail = (string.gsub(enemy.area, "(%l)(%u)", "%1 %2")),
					},
				})
			end
		end
	elseif book == "Weapons" then
		local owned = if saved then saved.weapons else {}
		local tiers = if saved then saved.tiers.weapons else {}
		for key, stats in WeaponStats.weapons do
			local art = ShopAssets.weapons[key]
			if art then
				table.insert(ranked, {
					rank = stats.area * 10 + (RANK[stats.rarity] or 9),
					entry = {
						key = key,
						name = label(key),
						--[[ the same 2D art as every other screen's (the Blacksmith,
						     Gear, the reveal); the grid showed the old mini pixel
						     icons for the first two areas' weapons until
						     2026-11-13 (owner: "make sure the icons ... all match") ]]
						icon = art,
						picture = art,
						-- without its leading rarity: the pill under the name says it
						description = (string.gsub(LoadingPick.describeWeapon(key), "^%u+%. ", "")),
						unlocked = owned[key] == true,
						rarity = stats.rarity,
						-- `WeaponStats.area` is the area's number, in the order played
						area = DexBook.AREAS[stats.area] or `Area{stats.area}`,
						detail = stats.rarity,
						tier = if owned[key] == true
							then MergeRules.best(tiers[key]) or MergeRules.TIERS[1]
							else nil,
					},
				})
			end
		end
	elseif book == "Pets" then
		local hatched = if saved then saved.pets else {}
		local tiers = if saved then saved.tiers.pets else {}
		for key, pet in Pets do
			local icon = GearAssets.pets[key]
			if icon then
				table.insert(ranked, {
					rank = (AREAS[pet.area] or LAST_AREA) * 10 + (RANK[pet.rarity] or 9),
					entry = {
						key = key,
						name = pet.name,
						icon = icon,
						picture = icon,
						description = describePet(pet),
						unlocked = (hatched[key] or 0) > 0,
						rarity = pet.rarity,
						area = pet.area,
						detail = pet.rarity,
						tier = if (hatched[key] or 0) > 0
							then MergeRules.best(tiers[key]) or MergeRules.TIERS[1]
							else nil,
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

--[[ The areas `entries` has anything from, in the order the game plays
     them: a book's pages. An area the order does not know yet comes after
     the ones it does, by name, so a new area's page shows up rather than
     going missing. ]]
function DexBook.areas(entries: { Entry }): { string }
	local seen: { [string]: boolean } = {}
	local out: { string } = {}
	for _, entry in entries do
		if not seen[entry.area] then
			seen[entry.area] = true
			table.insert(out, entry.area)
		end
	end
	table.sort(out, function(a, b)
		local ra, rb = AREAS[a] or LAST_AREA, AREAS[b] or LAST_AREA
		if ra ~= rb then
			return ra < rb
		end
		return a < b
	end)
	return out
end

--[[ `area`'s page: its entries, in the book's own order. ]]
function DexBook.inArea(entries: { Entry }, area: string): { Entry }
	local out: { Entry } = {}
	for _, entry in entries do
		if entry.area == area then
			table.insert(out, entry)
		end
	end
	return out
end

return DexBook
