--!strict
--[[
	The class select screen's cards (`Config/ClassSelect`, `Util/ClassStats`).
	The screen draws the player's own character with each class's weapon, so
	what is held here is the data under it: every card is a real class with
	a weapon to hold, the bars say what `Config/Classes` says, and a locked
	class is one the game cannot play.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local ClassCards = require(ReplicatedStorage.Shared.Config.ClassSelect)
local ClassStats = require(ReplicatedStorage.Shared.Util.ClassStats)
local Classes = require(ReplicatedStorage.Shared.Config.Classes)
local SaveSchema = require(ReplicatedStorage.Shared.Util.SaveSchema)
local ShopAssets = require(ReplicatedStorage.Shared.Config.ShopAssets)
local TestRunner = require(script.Parent.TestRunner)
local Weapons = require(ReplicatedStorage.Shared.Config.Weapons)

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

	t.test("a locked card is a class the game cannot play", function()
		for _, card in ClassCards do
			if card.locked then
				t.isNil(Classes[card.class], `{card.class} is locked but playable`)
			end
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
		local full = { damage = false, speed = false, health = false }
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
		t.isTrue(full.damage and full.speed and full.health, "some bar is never full")
	end)

	t.test("the bars follow the numbers", function()
		local ranger, arcanist, warden =
			ClassStats.bars("Ranger"), ClassStats.bars("Arcanist"), ClassStats.bars("Warden")
		t.isTrue(arcanist.damage > ranger.damage, "the Arcanist hits harder than the Ranger")
		t.isTrue(ranger.speed > arcanist.speed, "the Ranger attacks faster than the Arcanist")
		t.isTrue(warden.health > ranger.health, "the Warden is tougher than the Ranger")
		local none = ClassStats.bars("Nobody")
		t.equal(none.damage + none.speed + none.health, 0)
	end)

	t.test("the look the screen sends is one the save keeps", function()
		t.notNil(SaveSchema.LOOKS[1], "there is no look to send")
	end)
end
