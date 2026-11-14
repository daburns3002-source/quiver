--!strict
--[[
	Class levels (`Config/ClassLevels`, `Util/ClassLevelRules`; owner,
	2026-11-14: "class specific leveling ... when a player gets to level 10
	on a certain class, they should unlock a golden weapon"): what a run
	pays, how XP becomes levels, what each level gives, that level 10 gives
	the class's golden weapon, and that a golden weapon is a Legendary that
	can be worn but is never sold or rolled.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local ClassLevelRules = require(ReplicatedStorage.Shared.Util.ClassLevelRules)
local ClassLevels = require(ReplicatedStorage.Shared.Config.ClassLevels)
local Classes = require(ReplicatedStorage.Shared.Config.Classes)
local DexBook = require(ReplicatedStorage.Shared.Util.DexBook)
local SaveSchema = require(ReplicatedStorage.Shared.Util.SaveSchema)
local Shop = require(ReplicatedStorage.Shared.Config.Shop)
local ShopRules = require(ReplicatedStorage.Shared.Util.ShopRules)
local TestRunner = require(script.Parent.TestRunner)
local WeaponStats = require(ReplicatedStorage.Shared.Config.WeaponStats)

local function total(): number
	local sum = 0
	for _, need in ClassLevels.toNext do
		sum += need
	end
	return sum
end

return function(t: TestRunner.Helper)
	t.test("the table has a step for every level under the top, each longer", function()
		t.equal(#ClassLevels.toNext, ClassLevels.cap - 1)
		for level = 2, #ClassLevels.toNext do
			t.isTrue(
				ClassLevels.toNext[level] > ClassLevels.toNext[level - 1],
				"level " .. level .. " asks more than the one before"
			)
		end
		t.isNil(ClassLevelRules.need(ClassLevels.cap), "the top level needs nothing")
		t.equal(ClassLevelRules.need(1), ClassLevels.toNext[1])
	end)

	t.test("a run pays for what was cleared, and a win pays more", function()
		t.equal(ClassLevelRules.runXp(0, false), 0, "nothing cleared, nothing paid")
		t.equal(ClassLevelRules.runXp(4, false), 4 * ClassLevels.clearXp, "a loss still pays")
		t.equal(
			ClassLevelRules.runXp(10, true),
			10 * ClassLevels.clearXp + ClassLevels.winXp,
			"a win pays its bonus on top"
		)
		t.equal(ClassLevelRules.runXp(-3, false), 0)
		t.equal(ClassLevelRules.runXp(2.9, false), 2 * ClassLevels.clearXp)
		t.equal(ClassLevelRules.runXp(0 / 0, false), 0)
	end)

	t.test("the first won level reaches level 2, and level 10 is about 20 runs", function()
		-- 1-1 is ten rooms
		t.isTrue(ClassLevelRules.runXp(10, true) >= ClassLevels.toNext[1])
		local runs = total() / ClassLevelRules.runXp(15, true)
		t.isTrue(runs >= 12 and runs <= 30, "about 20 won runs, not " .. runs)
	end)

	t.test("every class in the game levels, and no other name does", function()
		for class in Classes do
			t.isTrue(ClassLevelRules.levels(class), class)
			t.notNil(ClassLevels.weapons[class], class .. " has a golden weapon")
		end
		for class in ClassLevels.weapons do
			t.notNil(Classes[class], class .. " is a class")
		end
		t.isFalse(ClassLevelRules.levels("Wizard"))
		t.isFalse(ClassLevelRules.levels(nil))
		t.isFalse(ClassLevelRules.levels(7))
	end)

	t.test("XP goes to the class played and to no other", function()
		local levels: ClassLevelRules.Levels = {}
		local gain = ClassLevelRules.add(levels, "Arcanist", 60)
		t.notNil(gain)
		t.equal(levels.Arcanist.level, 1)
		t.equal(levels.Arcanist.xp, 60)
		t.isNil(levels.Ranger)
		t.equal(ClassLevelRules.standing(levels, "Ranger").level, 1, "unplayed reads as level 1")
		t.equal(#(gain :: ClassLevelRules.Gain).reached, 0)
	end)

	t.test("XP carries over a level, and through several at once", function()
		local levels: ClassLevelRules.Levels = {}
		local one = ClassLevelRules.add(levels, "Ranger", ClassLevels.toNext[1] + 30) :: any
		t.equal(levels.Ranger.level, 2)
		t.equal(levels.Ranger.xp, 30)
		t.equal(one.before.level, 1)
		t.equal(one.before.xp, 0)
		t.equal(one.after.level, 2)
		t.equal(one.after.xp, 30)
		t.equal(one.reached[1], 2)
		local many = ClassLevelRules.add(
			levels,
			"Ranger",
			ClassLevels.toNext[2] + ClassLevels.toNext[3]
		) :: any
		t.equal(levels.Ranger.level, 4)
		t.equal(levels.Ranger.xp, 30)
		t.equal(#many.reached, 2)
		t.equal(many.reached[2], 4)
	end)

	t.test("each level from 2 to 9 has a gift, and a gain sums the ones it passed", function()
		for level = 2, ClassLevels.cap - 1 do
			local gift = ClassLevels.gifts[level]
			t.notNil(gift, "level " .. level .. " gives something")
			t.isTrue((gift.coins or 0) + (gift.gems or 0) > 0)
		end
		t.isNil(ClassLevels.gifts[1])
		local levels: ClassLevelRules.Levels = {}
		local gain = ClassLevelRules.add(
			levels,
			"Warden",
			ClassLevels.toNext[1] + ClassLevels.toNext[2]
		) :: any
		t.equal(gain.coins, ClassLevels.gifts[2].coins or 0)
		t.equal(gain.gems, ClassLevels.gifts[3].gems or 0)
		t.isNil(gain.weapon, "no golden weapon before level 10")
	end)

	t.test("level 10 gives the class's golden weapon, once, and is the top", function()
		t.equal(ClassLevels.weaponLevel, 10)
		t.equal(ClassLevels.cap, 10)
		local levels: ClassLevelRules.Levels = { Ranger = { level = 9, xp = 0 } }
		local short = ClassLevelRules.add(levels, "Ranger", ClassLevels.toNext[9] - 1) :: any
		t.isNil(short.weapon)
		t.equal(levels.Ranger.level, 9)
		local gain = ClassLevelRules.add(levels, "Ranger", 500) :: any
		t.equal(levels.Ranger.level, 10)
		t.equal(levels.Ranger.xp, 0, "XP past the top is not kept")
		t.equal(gain.weapon, ClassLevels.weapons.Ranger)
		local after = ClassLevelRules.add(levels, "Ranger", 5000) :: any
		t.equal(levels.Ranger.level, 10)
		t.isNil(after.weapon, "given once")
		t.equal(#after.reached, 0)
		t.equal(ClassLevelRules.fraction(levels.Ranger), 1)
		t.equal(ClassLevelRules.words(10), "MAX LEVEL")
		t.equal(ClassLevelRules.words(3), "LEVEL 3")
	end)

	t.test("the whole table's XP at once lands exactly on the top", function()
		local levels: ClassLevelRules.Levels = {}
		local gain = ClassLevelRules.add(levels, "Arcanist", total()) :: any
		t.equal(levels.Arcanist.level, ClassLevels.cap)
		t.equal(#gain.reached, ClassLevels.cap - 1)
		t.equal(gain.weapon, ClassLevels.weapons.Arcanist)
	end)

	t.test("nothing is added for no XP, a broken number or no such class", function()
		local levels: ClassLevelRules.Levels = {}
		t.isNil(ClassLevelRules.add(levels, "Ranger", 0))
		t.isNil(ClassLevelRules.add(levels, "Ranger", -40))
		t.isNil(ClassLevelRules.add(levels, "Ranger", 0 / 0))
		t.isNil(ClassLevelRules.add(levels, "Wizard", 100))
		t.isNil((next(levels)))
	end)

	t.test("a saved level 10 is owed its golden weapon", function()
		local owed = ClassLevelRules.owed({
			Ranger = { level = 10, xp = 0 },
			Arcanist = { level = 9, xp = 700 },
		})
		t.equal(#owed, 1)
		t.equal(owed[1], ClassLevels.weapons.Ranger)
	end)

	t.test("levels live in the save and survive a rejoin", function()
		local profile = SaveSchema.default()
		t.isNil((next(profile.classLevels)), "a new player has none")
		ClassLevelRules.add(profile.classLevels, "Warden", 260)
		local again = SaveSchema.migrate(profile)
		t.equal(again.classLevels.Warden.level, 3)
		t.equal(again.classLevels.Warden.xp, 10)
	end)

	t.test("a golden weapon is a Legendary its own class wears, with an effect", function()
		for class, weapon in ClassLevels.weapons do
			local stats = WeaponStats.weapons[weapon]
			t.notNil(stats, weapon .. " has stats")
			t.equal(stats.rarity, "Legendary", weapon)
			t.isTrue(stats.earned == true, weapon .. " is marked earned")
			t.notNil(stats.innate, weapon .. " has a Legendary's extra effect")
			t.notNil(stats.effect, weapon .. " says what it does")
			local entry = ShopRules.find(weapon)
			t.notNil(entry, weapon .. " can be worn at Gear")
			t.equal((entry :: ShopRules.Entry).class, class)
		end
	end)

	t.test("a golden weapon is never sold and never rolled from a crate", function()
		for _, weapon in ClassLevels.weapons do
			local entry = ShopRules.find(weapon) :: ShopRules.Entry
			t.isNil(ShopRules.price(entry), weapon .. " has no price")
			for index in Shop.crates do
				for _, chest in Shop.chests do
					for _, other in ShopRules.cratePool(index, chest.class) do
						t.isTrue(other.weapon ~= weapon, weapon .. " is in crate " .. index)
					end
				end
				for _, other in ShopRules.cratePool(index) do
					t.isTrue(other.weapon ~= weapon, weapon .. " is in crate " .. index)
				end
			end
		end
	end)

	t.test("a golden weapon is in no area's Dex page", function()
		for _, entry in DexBook.entries("Weapons", nil) do
			for _, weapon in ClassLevels.weapons do
				t.isTrue(entry.key ~= weapon, weapon .. " is in the Dex")
			end
		end
	end)

	t.test("only the golden weapons are marked earned", function()
		local golden: { [string]: boolean } = {}
		for _, weapon in ClassLevels.weapons do
			golden[weapon] = true
		end
		for weapon, stats in WeaponStats.weapons do
			t.equal(stats.earned == true, golden[weapon] == true, weapon)
		end
	end)
end
