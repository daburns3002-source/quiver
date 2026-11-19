--!strict
--[[
	Hatch shout-outs (`Util/ShoutoutRules`, `Util/FavouriteRules`): only the
	rarest rolls are shouted, only the far rarities leave the server, a
	message from elsewhere is believed only in the shape we send, gaps hold,
	and the favourite prompt is owed once, after a boss.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config.Shoutouts)
local FavouriteRules = require(ReplicatedStorage.Shared.Util.FavouriteRules)
local Rarities = require(ReplicatedStorage.Shared.Config.Rarities)
local ShoutoutRules = require(ReplicatedStorage.Shared.Util.ShoutoutRules)
local TestRunner = require(script.Parent.TestRunner)

return function(t: TestRunner.Helper)
	t.test("Legendary and Mythic are shouted; only what is shouted goes far", function()
		t.isTrue(ShoutoutRules.loud("Legendary"))
		t.isTrue(ShoutoutRules.loud("Mythic"))
		t.isFalse(ShoutoutRules.loud("Epic"))
		t.isFalse(ShoutoutRules.loud(nil))
		t.isTrue(ShoutoutRules.far("Mythic"))
		t.isFalse(ShoutoutRules.far("Legendary"))
		for _, rarity in Config.far.rarities do
			t.isTrue(ShoutoutRules.loud(rarity), `{rarity} going far is shouted here too`)
		end
		for _, rarity in Config.rarities do
			t.isTrue(Rarities.byName[rarity] ~= nil, `{rarity} is a rarity`)
		end
	end)

	t.test("the line reads as a sentence", function()
		t.equal(
			ShoutoutRules.line("Sam", "Pet", "Mythic", "Glimmerhorn"),
			"Sam HATCHED A MYTHIC GLIMMERHORN!"
		)
		t.equal(ShoutoutRules.line("Sam", "Weapon", "Epic", "Bow"), "Sam PULLED AN EPIC BOW!")
		t.equal(
			ShoutoutRules.line("Sam", "Pet", "Mythic", "Wilf", Config.far.suffix),
			"Sam HATCHED A MYTHIC WILF" .. Config.far.suffix .. "!"
		)
	end)

	t.test("a message from another server is believed only in our shape", function()
		local good =
			{ who = "Sam", kind = "Pet", item = "Glimmerhorn", rarity = "Mythic", from = "x" }
		local read = ShoutoutRules.read(good)
		t.isTrue(read ~= nil and read.item == "Glimmerhorn" and read.rarity == "Mythic")
		t.equal(
			ShoutoutRules.read({ who = "Sam", kind = "Pet", item = "X", rarity = "Legendary" }),
			nil,
			"not far"
		)
		t.equal(
			ShoutoutRules.read({ who = "Sam", kind = "Robux", item = "X", rarity = "Mythic" }),
			nil
		)
		t.equal(
			ShoutoutRules.read({
				who = string.rep("a", 41),
				kind = "Pet",
				item = "X",
				rarity = "Mythic",
			}),
			nil
		)
		t.equal(ShoutoutRules.read({ who = 5, kind = "Pet", item = "X", rarity = "Mythic" }), nil)
		t.equal(ShoutoutRules.read("Sam hatched"), nil)
	end)

	t.test("a gap holds, and the first is always allowed", function()
		local ok, last = ShoutoutRules.spaced(nil, 100, 10)
		t.isTrue(ok)
		t.equal(last, 100)
		t.isFalse((ShoutoutRules.spaced(last, 105, 10)))
		t.isTrue((ShoutoutRules.spaced(last, 110, 10)))
		t.isTrue(Config.far.showGap >= Config.far.sendGap, "a server shows no more than one sends")
	end)

	t.test("the favourite prompt is owed once, after a boss, in a clear lobby", function()
		t.isFalse(FavouriteRules.owed(false, {}), "no boss yet")
		t.isTrue(FavouriteRules.owed(false, { MossyGlade = true }))
		t.isFalse(FavouriteRules.owed(true, { MossyGlade = true }), "never twice")
		t.isTrue(FavouriteRules.ready(true, true, false))
		t.isFalse(FavouriteRules.ready(true, false, false), "not in a run")
		t.isFalse(FavouriteRules.ready(true, true, true), "not over another screen")
		t.isFalse(FavouriteRules.ready(false, true, false))
	end)
end
