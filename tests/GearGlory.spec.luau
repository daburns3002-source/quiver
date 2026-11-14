--!strict
--[[
	How grand an owned item is drawn (`Util/GearGlory`; owner, 2026-11-14:
	"it should feel more grand to own a mythic, legendary or high merge
	tier").
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local GearGlory = require(ReplicatedStorage.Shared.Util.GearGlory)
local MergeRules = require(ReplicatedStorage.Shared.Util.MergeRules)
local TestRunner = require(script.Parent.TestRunner)
local WeaponStats = require(ReplicatedStorage.Shared.Config.WeaponStats)

return function(t: TestRunner.Helper)
	t.test("a Legendary is grand and a Mythic grander; lesser rarities are plain", function()
		for rarity in WeaponStats.bonus do
			local rank = GearGlory.rank(rarity, "C")
			local expected = if rarity == "Mythic" then 2 elseif rarity == "Legendary" then 1 else 0
			t.equal(rank, expected, rarity)
		end
		t.equal(GearGlory.rank(nil, nil), 0)
		t.equal(GearGlory.rank("NoSuchRarity", nil), 0)
	end)

	t.test("a high merge tier is grand whatever the rarity", function()
		t.equal(GearGlory.rank("Common", "C"), 0)
		t.equal(GearGlory.rank("Common", "B"), 0)
		t.equal(GearGlory.rank("Common", "A"), 1)
		t.equal(GearGlory.rank("Common", "S"), 2, "merged all the way is as grand as a Mythic")
		-- every tier there is has an answer, and it never goes down as tiers rise
		local last = 0
		for _, tier in MergeRules.TIERS do
			local rank = GearGlory.rank("Common", tier)
			t.isTrue(rank >= last, tier)
			last = rank
		end
	end)

	t.test("rarity and tier do not stack past the top; the greater counts", function()
		t.equal(GearGlory.rank("Legendary", "A"), 1)
		t.equal(GearGlory.rank("Legendary", "S"), 2)
		t.equal(GearGlory.rank("Mythic", "C"), 2)
		t.equal(GearGlory.rank("Mythic", "S"), 2)
	end)

	t.test("the card's banner names what makes it grand", function()
		t.isNil(GearGlory.banner("Rare", "B"))
		t.isNil(GearGlory.banner(nil, nil))
		t.equal(GearGlory.banner("Legendary", "C"), "LEGENDARY!")
		t.equal(GearGlory.banner("Mythic", nil), "MYTHIC!")
		t.equal(GearGlory.banner("Common", "S"), "TIER S!")
		t.equal(GearGlory.banner("Legendary", "S"), "TIER S!", "the tier counts for more here")
		t.equal(GearGlory.banner("Mythic", "S"), "MYTHIC!")
	end)
end
