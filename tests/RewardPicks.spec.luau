--!strict
--[[
	The reward picks (`Util/RewardPickRules`; owner, 2026-11-19: "a choice
	BETWEEN THE MYTHICS AND LEGENDARIES FOR ALL CLASSES for the endless
	rewards and the battlepass", "the space and sakura ones"): Endless room
	100 and the season pass's premium tier 30 each let the player take any
	one of a themed set's four weapons, one for each class, and the server
	gives only a weapon of a set it owes a pick of.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local ClassList = require(ReplicatedStorage.Shared.Util.ClassList)
local RewardPickRules = require(ReplicatedStorage.Shared.Util.RewardPickRules)
local ShopRules = require(ReplicatedStorage.Shared.Util.ShopRules)
local TestRunner = require(script.Parent.TestRunner)

local function keys(entries: { ShopRules.Entry }): string
	local out: { string } = {}
	for _, entry in entries do
		table.insert(out, entry.weapon)
	end
	return table.concat(out, ",")
end

return function(t: TestRunner.Helper)
	t.test("each reward set is one weapon a class, in the class list's order", function()
		t.equal(
			keys(RewardPickRules.options("Voidglass")),
			"OrbitBow,StarwellStaff,NebulaBlade,CometDaggers"
		)
		t.equal(
			keys(RewardPickRules.options("LanternBloom")),
			"BlossomBow,PaperglowStaff,PetalfallBlade,BellchimeDaggers"
		)
		for _, set in { "Voidglass", "LanternBloom" } do
			local options = RewardPickRules.options(set)
			t.equal(#options, #ClassList.open(), `{set} is short a class`)
			for n, entry in options do
				t.equal(entry.class, ClassList.open()[n], `{set}'s order`)
				-- every class's pick is a Legendary or a Mythic
				t.isTrue(
					entry.rarity == "Legendary" or entry.rarity == "Mythic",
					`{entry.weapon} is {entry.rarity}`
				)
			end
		end
	end)

	t.test("a set's picture is its Mythic", function()
		t.equal(RewardPickRules.headline("Voidglass"), "NebulaBlade")
		t.equal(RewardPickRules.headline("LanternBloom"), "PetalfallBlade")
		t.isNil(RewardPickRules.headline("NoSuchSet"))
	end)

	t.test("a held-once weapon held already cannot be picked; one that merges can", function()
		local owned = { NebulaBlade = true, OrbitBow = true }
		t.isFalse(RewardPickRules.canTake("NebulaBlade", owned), "the Nebula is held once")
		t.isTrue(RewardPickRules.canTake("OrbitBow", owned), "another copy to merge")
		t.isTrue(RewardPickRules.canTake("NebulaBlade", {}))
		t.equal(
			table.concat(RewardPickRules.pickable("Voidglass", owned), ","),
			"OrbitBow,StarwellStaff,CometDaggers"
		)
	end)

	t.test("only a weapon of an owed set is found, and from the pick it belongs to", function()
		local picks = { ["Endless:100"] = "Voidglass", ["Season:1:premium"] = "LanternBloom" }
		t.equal(RewardPickRules.find(picks, "NebulaBlade", {}), "Endless:100")
		t.equal(RewardPickRules.find(picks, "CometDaggers", {}), "Endless:100")
		t.equal(RewardPickRules.find(picks, "BlossomBow", {}), "Season:1:premium")
		t.isNil(RewardPickRules.find(picks, "WishcutterBlade", {}), "a set not owed")
		t.isNil(RewardPickRules.find(picks, "WoodenBow", {}), "no set's weapon")
		t.isNil(RewardPickRules.find(picks, "PetalfallBlade", { PetalfallBlade = true }), "held")
		t.isNil(RewardPickRules.find({}, "NebulaBlade", {}), "nothing owed")
	end)

	t.test("the panel shows the picks in order, skipping those put off", function()
		local picks = { ["Season:1:premium"] = "LanternBloom", ["Endless:100"] = "Voidglass" }
		local id, set = RewardPickRules.next(picks)
		t.equal(id, "Endless:100")
		t.equal(set, "Voidglass")
		id, set = RewardPickRules.next(picks, { ["Endless:100"] = true })
		t.equal(id, "Season:1:premium")
		t.equal(set, "LanternBloom")
		t.isNil(
			(RewardPickRules.next(picks, { ["Endless:100"] = true, ["Season:1:premium"] = true }))
		)
	end)

	t.test("each pick's id says where it came from", function()
		t.equal(RewardPickRules.endlessId(100), "Endless:100")
		t.equal(RewardPickRules.seasonId(1, "premium"), "Season:1:premium")
		t.equal(RewardPickRules.from("Endless:100"), "ENDLESS ROOM 100")
		t.equal(RewardPickRules.from("Season:1:premium"), "SEASON 1 PREMIUM PASS")
		t.equal(RewardPickRules.from("Season:2:free"), "SEASON 2 PASS")
		t.equal(RewardPickRules.from("junk"), "A REWARD")
	end)
end
