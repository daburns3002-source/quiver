--!strict
--[[
	The class select screen's cards (`Config/ClassSelect`, `Util/ClassStats`).
	What is held here is the data under the screen: every card is a real
	class with a portrait for every look the BOY / GIRL switch offers, the
	bars say what `Config/Classes` says, and a locked class is one the game
	cannot play.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local ClassLevelRules = require(ReplicatedStorage.Shared.Util.ClassLevelRules)
local ClassList = require(ReplicatedStorage.Shared.Util.ClassList)
local ClassSelect = require(ReplicatedStorage.Shared.Config.ClassSelect)
local ClassStats = require(ReplicatedStorage.Shared.Util.ClassStats)
local Classes = require(ReplicatedStorage.Shared.Config.Classes)
local SaveSchema = require(ReplicatedStorage.Shared.Util.SaveSchema)
local ShopAssets = require(ReplicatedStorage.Shared.Config.ShopAssets)
local ShopRules = require(ReplicatedStorage.Shared.Util.ShopRules)
local TestRunner = require(script.Parent.TestRunner)
local Weapons = require(ReplicatedStorage.Shared.Config.Weapons)

local ClassCards = ClassSelect.cards

return function(t: TestRunner.Helper)
	t.test("every playable class has one card, and every open card a class", function()
		local seen: { [string]: boolean } = {}
		for _, card in ClassCards do
			t.isNil(seen[card.class], `{card.class} has two cards`)
			seen[card.class] = true
			if not card.locked then
				t.notNil(Classes[card.class], `{card.class} is not a class`)
			end
			t.isTrue(card.pitch ~= "", `{card.class} says nothing about itself`)
		end
		for class in Classes do
			t.isTrue(seen[class] == true, `{class} has no card`)
		end
	end)

	--[[ A locked card's class may be built already (it is played in Studio
	     while it is made), but no player can choose it, level it or own
	     its weapons (`Util/ClassList`, which the server's CHOOSE reads). ]]
	t.test("a locked card is a class no player can choose, level or arm", function()
		for _, card in ClassCards do
			if card.locked then
				t.isFalse(ClassList.isOpen(card.class), `{card.class} is locked but open`)
				t.isNil(table.find(ClassList.open(), card.class), `{card.class} is listed open`)
				t.isFalse(ClassLevelRules.levels(card.class), `{card.class} is locked but levels`)
				for _, entry in ShopRules.catalog() do
					t.isTrue(entry.class ~= card.class, `{entry.weapon} can be owned`)
				end
			else
				t.isTrue(ClassList.isOpen(card.class), `{card.class} is not open`)
			end
		end
		t.isFalse(ClassList.isOpen("Wizard"))
		t.isFalse(ClassList.isOpen(nil))
	end)

	t.test("the class list is every class there is, in the cards' order", function()
		local all = ClassList.all()
		local count = 0
		for _ in Classes do
			count += 1
		end
		t.equal(#all, count)
		local at = 0
		for _, card in ClassCards do
			if Classes[card.class] then
				at += 1
				t.equal(all[at], card.class)
			end
		end
		for _, class in ClassList.open() do
			t.notNil(table.find(all, class), class)
		end
	end)

	t.test("every open card's class has a weapon to hold and its picture", function()
		for _, card in ClassCards do
			if not card.locked then
				local weapon = Classes[card.class].weapon
				t.notNil((Weapons :: any)[weapon], `{card.class}'s {weapon} is not a weapon`)
				t.notNil(
					(ShopAssets.weapons :: { [string]: string })[weapon],
					`{weapon} has no picture`
				)
			end
		end
	end)

	t.test("the bars are shares of the best, and the best is full", function()
		local full = { range = false, power = false, speed = false }
		for _, card in ClassCards do
			if not card.locked then
				local bars = ClassStats.bars(card.class)
				for name, share in bars :: { [string]: number } do
					t.isTrue(share > 0 and share <= 1, `{card.class} {name} is {share}`)
					if share == 1 then
						(full :: any)[name] = true
					end
				end
			end
		end
		t.isTrue(full.range and full.power and full.speed, "some bar is never full")
	end)

	t.test("the bars follow the numbers", function()
		local ranger, arcanist, warden =
			ClassStats.bars("Ranger"), ClassStats.bars("Arcanist"), ClassStats.bars("Warden")
		t.isTrue(arcanist.power > ranger.power, "the Arcanist hits harder than the Ranger")
		t.isTrue(ranger.speed > arcanist.speed, "the Ranger attacks faster than the Arcanist")
		t.isTrue(ranger.range > warden.range, "the Ranger reaches further than the Warden")
		local none = ClassStats.bars("Nobody")
		t.equal(none.range + none.power + none.speed, 0)
	end)

	t.test("every bar on a card is one the numbers give", function()
		local bars = ClassStats.bars("Ranger") :: any
		for _, stat in ClassSelect.stats do
			t.equal(type(bars[stat.key]), "number", `{stat.words} has no number`)
			t.isTrue(string.find(stat.icon, "^rbxassetid://%d+$") ~= nil, `{stat.words}'s icon`)
		end
	end)

	t.test("the switch offers exactly the looks the save keeps", function()
		t.equal(#ClassSelect.looks, #SaveSchema.LOOKS)
		for _, entry in ClassSelect.looks do
			t.notNil(table.find(SaveSchema.LOOKS, entry.look), `{entry.look} is not saved`)
			t.isTrue(entry.words ~= "", `{entry.look} says nothing`)
		end
	end)

	t.test("every card has a portrait for every look", function()
		for _, card in ClassCards do
			for _, look in SaveSchema.LOOKS do
				local picture = card.portraits[look]
				t.isTrue(
					picture ~= nil and string.find(picture, "^rbxassetid://%d+$") ~= nil,
					`{card.class} has no {look} portrait`
				)
			end
		end
	end)
end
