--!strict
--[[
	A chest for each finished Dex page (`Config/Rewards.pages`; owner,
	2026-11-14: "there should be more rewards for players"). The Dex Hall's
	three books have a page an area (`Util/DexBook`), so a finished page is
	also a finished set: every enemy of an area met, all of its pets
	hatched, or all of its weapons owned. The pets' and the weapons' pages
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
local Goals = require(script.Parent.Parent.Config.Goals)
local Rewards = require(script.Parent.Parent.Config.Rewards)
local SaveSchema = require(script.Parent.SaveSchema)

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

local NOUNS: { [string]: string } = { Enemies = "ENEMIES", Weapons = "WEAPONS", Pets = "PETS" }
local PRIZES: { [string]: Goals.Prize } = Rewards.pages

function PageRules.key(book: string, area: string): string
	return book .. ":" .. area
end

--[[ Every page with a chest, in the Dex's order (book by book, area by
     area), as `profile` stands on it. ]]
function PageRules.pages(profile: SaveSchema.Profile): { Page }
	local out: { Page } = {}
	for _, book in DexBook.BOOKS do
		local prize = PRIZES[book]
		local entries = DexBook.entries(book, profile)
		for _, area in DexBook.areas(entries) do
			local theme = Dex.areas[area]
			local page = DexBook.inArea(entries, area)
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
