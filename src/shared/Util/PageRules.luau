--!strict
--[[
	A chest for each finished Dex page (`Config/Rewards.pages`; owner,
	2026-11-14: "there should be more rewards for players"). The Dex Hall's
	three books have a page an area (`Util/DexBook`), so a finished page is
	also a finished set: every enemy of an area met, all of the pets its
	eggs hold hatched, or all of its weapons owned. The pets' and the weapons' pages
	are the collection sets and pay the big gifts.

	Pure, and judged from the saved profile alone with the Dex's own
	reading of it, so the server decides with it (`Data/Rewards`) and the
	screen draws with the same answers; `tests/Gifts.spec` pins it. A claim
	names a page and nothing else, and each page pays once
	(`SaveSchema.dexChests`).

	Only an area the Dex has a look for has pages here (`Config/Dex.areas`),
	and only a page with something on it.
]]

local Dex = require(script.Parent.Parent.Config.Dex)
local DexBook = require(script.Parent.DexBook)
local EggRules = require(script.Parent.EggRules)
local Eggs = require(script.Parent.Parent.Config.Eggs)
local Goals = require(script.Parent.Parent.Config.Goals)
local Rewards = require(script.Parent.Parent.Config.Rewards)
local SaveSchema = require(script.Parent.SaveSchema)
local Shop = require(script.Parent.Parent.Config.Shop)

local PageRules = {}

export type Page = {
	--[[ "Book:Area", as it is saved. ]]
	key: string,
	book: string,
	area: string,
	--[[ What the screen says: "ALL MOSSY GLADE PETS". ]]
	words: string,
	found: number,
	total: number,
	claimed: boolean,
	prize: Goals.Prize,
}

local NOUNS: { [string]: string } = { Enemies = "ENEMIES", Weapons = "WEAPONS", Pets = "EGG PETS" }

--[[ The pets some egg holds. The Dex lists every pet of the world, and
     some have no egg yet (`Util/DexBook`); a set that asked for those could
     never be finished (the run-through, 2026-11-14: Mossy Glade's page is
     12 pets, its egg holds 8). So a pets page's chest asks for the pets
     that can be hatched, and a page with none of those has no chest. ]]
local hatchable: { [string]: boolean } = {}
for _, egg in Eggs.list do
	for _, entry in EggRules.pool(egg.key) do
		hatchable[entry.pet] = true
	end
end
local PRIZES: { [string]: Goals.Prize } = Rewards.pages
--[[ A themed set's page (`Config/Shop.sets`) pays `Rewards.setPage`. ]]
local SETS: { [string]: boolean } = {}
for _, set in Shop.sets do
	SETS[set.key] = true
end

function PageRules.key(book: string, area: string): string
	return book .. ":" .. area
end

--[[ Every page with a chest, in the Dex's order (book by book, area by
     area), as `profile` stands on it. ]]
function PageRules.pages(profile: SaveSchema.Profile): { Page }
	local out: { Page } = {}
	for _, book in DexBook.BOOKS do
		local entries = DexBook.entries(book, profile)
		for _, area in DexBook.areas(entries) do
			local prize = if book == "Weapons" and SETS[area] then Rewards.setPage else PRIZES[book]
			local theme = Dex.areas[area]
			local page = DexBook.inArea(entries, area)
			if book == "Pets" then
				local eggs = {}
				for _, entry in page do
					if hatchable[entry.key] then
						table.insert(eggs, entry)
					end
				end
				page = eggs
			end
			if prize and theme and #page > 0 then
				local found, total = DexBook.found(page)
				local key = PageRules.key(book, area)
				table.insert(out, {
					key = key,
					book = book,
					area = area,
					words = `ALL {theme.name} {NOUNS[book] or string.upper(book)}`,
					found = found,
					total = total,
					claimed = profile.dexChests[key] == true,
					prize = prize,
				})
			end
		end
	end
	return out
end

local function find(profile: SaveSchema.Profile, key: unknown): Page?
	if type(key) ~= "string" then
		return nil
	end
	for _, page in PageRules.pages(profile) do
		if page.key == key then
			return page
		end
	end
	return nil
end

--[[ Whether `page` is finished and its chest not yet opened. ]]
function PageRules.ready(page: Page): boolean
	return not page.claimed and page.found >= page.total
end

--[[ Opens page `key`'s chest: marked, and its prize returned for the
     server to give. Nil when it is no page, not finished, or opened. ]]
function PageRules.claim(profile: SaveSchema.Profile, key: unknown): Goals.Prize?
	local page = find(profile, key)
	if not page or not PageRules.ready(page) then
		return nil
	end
	profile.dexChests[page.key] = true
	return page.prize
end

--[[ How many pages' chests wait to be opened. ]]
function PageRules.tally(profile: SaveSchema.Profile): number
	local waiting = 0
	for _, page in PageRules.pages(profile) do
		if PageRules.ready(page) then
			waiting += 1
		end
	end
	return waiting
end

return PageRules
