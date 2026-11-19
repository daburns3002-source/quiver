--!strict
--[[
	The themed weapon sets (`Config/Shop.sets`, `Util/ShopRules`; owner,
	2026-11-18: weapons "that are not area specific", in themed lines):
	one theme across one weapon for every class, all of one rarity,
	belonging to no area. So a set's weapon is sold from the store's SETS
	shelf for coins and gems, waits on no boss, comes out of no crate, has
	the first area's scale and a Dex page of its own after the areas'.
	docs/WEAPONS-THEMED.md.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Abilities = require(ReplicatedStorage.Shared.Config.Abilities)
local ClassList = require(ReplicatedStorage.Shared.Util.ClassList)
local Dex = require(ReplicatedStorage.Shared.Config.Dex)
local DexBook = require(ReplicatedStorage.Shared.Util.DexBook)
local Sandbox = require(ReplicatedStorage.Shared.Config.Sandbox)
local SetRotation = require(ReplicatedStorage.Shared.Util.SetRotation)
local Shop = require(ReplicatedStorage.Shared.Config.Shop)
local ShopRules = require(ReplicatedStorage.Shared.Util.ShopRules)
local TestRunner = require(script.Parent.TestRunner)
local UiContrast = require(ReplicatedStorage.Shared.Util.UiContrast)
local WeaponStats = require(ReplicatedStorage.Shared.Config.WeaponStats)

--[[ A set's weapons by class, from the stats alone. ]]
local function ofSet(key: string): { [string]: string }
	local out: { [string]: string } = {}
	for _, row in Sandbox.weapons do
		local stats = WeaponStats.weapons[row.weapon]
		if stats and stats.set == key then
			out[row.class] = row.weapon
		end
	end
	return out
end

--[[ An entry as the catalog would make it, for a rule that takes one. ]]
local function entry(set: string?, rarity: string, area: number): ShopRules.Entry
	return {
		weapon = "Test",
		class = "Ranger",
		label = "TEST",
		rarity = rarity,
		area = area,
		set = set,
	}
end

return function(t: TestRunner.Helper)
	t.test("every set has a name, a price in coins and gems, and its own key", function()
		local seen: { [string]: boolean } = {}
		for _, set in Shop.sets do
			t.isTrue(set.name ~= "", `{set.key} has no name`)
			t.isTrue(set.coins > 0 and set.gems > 0, `{set.key} has no price`)
			t.isNil(seen[set.key], `{set.key} is listed twice`)
			seen[set.key] = true
			-- a set is no area: its key must never be read as one
			t.isNil(table.find(DexBook.AREAS, set.key), `{set.key} is an area's name`)
			for _, crate in Shop.crates do
				t.isTrue(crate.area ~= set.key, `{set.key} is a crate's area`)
			end
		end
	end)

	t.test("a weapon's set is a real one, and its scale is the first area's", function()
		for key, stats in WeaponStats.weapons do
			if stats.set then
				t.notNil(ShopRules.set(stats.set), `{key} names no set: {stats.set}`)
				t.equal(stats.area, 1, `{key}'s scale`)
				t.equal(WeaponStats.areaScale[stats.area], 1)
			end
		end
	end)

	--[[ One theme across one weapon for every class, all of one rarity.
	     Held to a stocked set: one being built may be short a class. A set
	     weapon given as a reward (`earned`, never sold) may stand above it:
	     the Nebula Blade and the Petalfall Blade are Mythics (owner,
	     2026-11-19), Endless room 100's and the season pass's. ]]
	t.test("a stocked set is one weapon for every open class, all of one rarity", function()
		for _, set in Shop.sets do
			if not set.stocked then
				continue
			end
			local weapons = ofSet(set.key)
			local rarity: string? = nil
			for _, class in ClassList.open() do
				local weapon = weapons[class]
				t.notNil(weapon, `{set.key} has no weapon for the {class}`)
				if weapon then
					local stats = WeaponStats.weapons[weapon]
					if not stats.earned then
						rarity = rarity or stats.rarity
						t.equal(stats.rarity, rarity, `{weapon}'s rarity`)
					end
				end
			end
			local count = 0
			for _ in weapons do
				count += 1
			end
			t.equal(count, #ClassList.open(), `{set.key}: one weapon a class`)
			t.equal(#ShopRules.setPool(set.key), count, `{set.key}'s shelf`)
		end
	end)

	--[[ Rule 12 and the owner's ladder: a Legendary or a Mythic carries a
	     card its own class can draw. ]]
	t.test("a set's Legendary or Mythic carries a card its class draws", function()
		for _, row in Sandbox.weapons do
			local stats = WeaponStats.weapons[row.weapon]
			if
				stats
				and stats.set
				and (stats.rarity == "Legendary" or stats.rarity == "Mythic")
			then
				t.notNil(stats.innate, `{row.weapon} has no effect`)
				t.isTrue((stats.effect or "") ~= "", `{row.weapon} does not say its effect`)
				local innate: { [string]: number } = stats.innate or {}
				for card in innate do
					local ability = Abilities.byId[card]
					t.notNil(ability, `{row.weapon} carries {card}, which is no card`)
					local classes = ability and ability.classes
					t.isTrue(
						classes == nil or table.find(classes, row.class) ~= nil,
						`{row.weapon} carries {card}, which the {row.class} cannot draw`
					)
				end
			end
		end
	end)

	t.test("a set's weapon costs its set's coins and gems, and no boss item", function()
		for _, set in Shop.sets do
			for _, rarity in { "Uncommon", "Rare", "Epic", "Legendary" } do
				local price = ShopRules.price(entry(set.key, rarity, 1))
				t.notNil(price, `{set.key} {rarity}`)
				if price then
					t.equal(price.coins, set.coins)
					t.equal(price.gems, set.gems)
					t.isNil(price.items, `{set.key} asks for a boss item`)
				end
			end
		end
	end)

	--[[ Mythics are never sold (docs/ROBUX-STORE.md): gems can be bought,
	     so a Mythic with a gem price would be a Mythic for Robux. ]]
	t.test("a set never sells a Mythic or an earned weapon", function()
		for _, set in Shop.sets do
			t.isNil(ShopRules.price(entry(set.key, "Mythic", 1)), set.key)
			local earned = entry(set.key, "Legendary", 1)
			earned.earned = true
			t.isNil(ShopRules.price(earned), set.key)
		end
		t.isNil(ShopRules.price(entry("NoSuchSet", "Legendary", 1)))
	end)

	t.test("a set's weapon waits on no boss, with the launch locks on or off", function()
		for _, set in Shop.sets do
			if not set.stocked then
				continue
			end
			-- in its own week of the rotation (`Util/SetRotation`)
			local now: number? = nil
			local weeks = #Shop.sets
			for week = 0, weeks do
				local at = SetRotation.weekStart(week) + 60
				if SetRotation.onSale(set.key, at) then
					now = at
					break
				end
			end
			t.isTrue(now ~= nil, set.key .. " has a week of its own")
			for _, locks in { true, false } do
				t.isTrue(
					ShopRules.buyable(entry(set.key, "Legendary", 1), nil, locks, now),
					set.key
				)
				t.isTrue(ShopRules.buyable(entry(set.key, "Legendary", 1), {}, locks, now), set.key)
			end
			-- never without the server's clock
			t.isFalse(ShopRules.buyable(entry(set.key, "Legendary", 1), {}, false), set.key)
		end
		-- an area's weapon still waits on its crate
		t.isFalse(ShopRules.buyable(entry(nil, "Epic", 3), {}, true))
		t.isTrue(ShopRules.buyable(entry(nil, "Epic", 3), { Thornwood = true }, true))
	end)

	--[[ No area, so no crate: and every free crate, Endless prize, victory
	     chest and Soulstone crate asks `cratePool`, so none gives one. ]]
	t.test("no crate of any area holds a set's weapon", function()
		for index in Shop.crates do
			for _, held in ShopRules.cratePool(index) do
				t.isNil(held.set, `{held.weapon} is in crate {index}`)
				local stats = WeaponStats.weapons[held.weapon]
				t.isNil(stats.set, `{held.weapon} is in crate {index}`)
			end
		end
	end)

	t.test("the catalog lists the areas' weapons first, then the sets' in order", function()
		local last = 0
		for _, held in ShopRules.catalog() do
			local at = ShopRules.setIndex(held.set)
			t.isTrue(at >= last, `{held.weapon} is out of order`)
			last = at
		end
		t.equal(ShopRules.setIndex(nil), 0)
		t.equal(ShopRules.setIndex("NoSuchSet"), #Shop.sets + 1)
	end)

	t.test("a set that is not for sale has no shelf and no Dex page", function()
		local pages = DexBook.areas(DexBook.entries("Weapons", nil))
		for _, set in Shop.sets do
			if not set.stocked then
				t.equal(#ShopRules.setPool(set.key), 0, set.key)
				t.isNil(table.find(pages, set.key), `{set.key} has a page`)
			end
		end
	end)

	--[[ A page a set, after every area's, in its own colours: no area's
	     NEW ENEMY! sheet to cut scenery from, so it has none. ]]
	t.test("a stocked set's Dex page comes after the areas', with its own look", function()
		local entries = DexBook.entries("Weapons", nil)
		local pages = DexBook.areas(entries)
		local lastArea = 0
		for at, page in pages do
			if table.find(DexBook.AREAS, page) then
				lastArea = at
			end
		end
		for _, set in Shop.sets do
			if not set.stocked then
				continue
			end
			local at = table.find(pages, set.key)
			t.notNil(at, `{set.key} has no page`)
			t.isTrue((at or 0) > lastArea, `{set.key}'s page is before an area's`)
			local theme = Dex.areas[set.key]
			t.notNil(theme, `{set.key} has no page look`)
			if theme then
				t.equal(theme.name, set.name)
				local face = UiContrast.faceOf(theme.plate)
				t.isTrue(
					UiContrast.contrast(face.text, theme.plate) >= 3,
					`{set.key}'s name does not read on its plate`
				)
				for other, look in Dex.areas do
					if other ~= set.key then
						t.isTrue(look.plate ~= theme.plate, `{set.key} shares {other}'s plate`)
					end
				end
			end
			for _, found in DexBook.inArea(entries, set.key) do
				t.equal(WeaponStats.weapons[found.key].set, set.key)
			end
		end
	end)
end
