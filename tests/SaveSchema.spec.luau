--!strict
--[[
	Saved data (`Util/SaveSchema`) and paying from it (`Util/Purse`): a new
	player gets the classes' weapons and an empty wallet, any stored copy
	migrates without losing what is valid, a newer game's copy is left
	alone, and a price is paid whole or not at all.

	Every version's migration is pinned here, version 6's (Endless) included
	— CLAUDE.md non-negotiable 7: never a schema change without one.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Purse = require(ReplicatedStorage.Shared.Util.Purse)
local SaveSchema = require(ReplicatedStorage.Shared.Util.SaveSchema)
local TestRunner = require(script.Parent.TestRunner)

return function(t: TestRunner.Helper)
	t.test("a new player owns the three class weapons and nothing else", function()
		local p = SaveSchema.migrate(nil)
		t.equal(p.version, SaveSchema.VERSION)
		t.equal(p.coins, 0)
		t.equal(p.gems, 0)
		t.isTrue(p.weapons.TwigBow and p.weapons.BranchStaff and p.weapons.TimberBlade)
		t.isNil(p.equipped)
	end)

	t.test("a stored profile keeps everything valid", function()
		local p = SaveSchema.migrate({
			version = 1,
			coins = 1234,
			gems = 56,
			items = { RoyalJelly = 2 },
			weapons = { AcornBow = true },
			equipped = "AcornBow",
			bossesBeaten = { MossyGlade = true },
		})
		t.equal(p.coins, 1234)
		t.equal(p.gems, 56)
		t.equal(p.items.RoyalJelly, 2)
		t.isTrue(p.weapons.AcornBow)
		t.isTrue(p.weapons.TwigBow, "the starters are always owned")
		t.equal(p.equipped, "AcornBow")
		t.isTrue(p.bossesBeaten.MossyGlade)
	end)

	t.test("broken fields fall back instead of breaking the profile", function()
		local p = SaveSchema.migrate({
			coins = -50,
			gems = "lots",
			items = { RoyalJelly = 0, BroodSilk = 1.7, [3] = 9 },
			weapons = { AcornBow = "yes" },
			equipped = "NotOwned",
		})
		t.equal(p.coins, 0)
		t.equal(p.gems, 0)
		t.isNil(p.items.RoyalJelly)
		t.equal(p.items.BroodSilk, 1)
		t.isNil(p.weapons.AcornBow)
		t.isNil(p.equipped, "a weapon not owned is not equipped")
	end)

	t.test("a new profile has beaten no level", function()
		local p = SaveSchema.migrate(nil)
		t.equal(SaveSchema.VERSION, 6)
		t.isNil((next(p.levelsBeaten)))
	end)

	t.test("version 1 migrates up: nothing lost, no levels beaten", function()
		local p = SaveSchema.migrate({
			version = 1,
			coins = 70,
			gems = 3,
			items = { RoyalJelly = 1 },
			weapons = { AcornBow = true },
			equipped = "AcornBow",
			bossesBeaten = { Thornwood = true },
		})
		t.equal(p.version, SaveSchema.VERSION)
		t.equal(p.coins, 70)
		t.equal(p.gems, 3)
		t.equal(p.items.RoyalJelly, 1)
		t.equal(p.equipped, "AcornBow")
		t.isTrue(p.bossesBeaten.Thornwood)
		t.isNil((next(p.levelsBeaten)), "a version 1 profile has no levels beaten")
	end)

	t.test("version 1 that beat King Bloblin counts 1-1 as beaten", function()
		local p = SaveSchema.migrate({ version = 1, bossesBeaten = { MossyGlade = true } })
		t.isTrue(p.levelsBeaten["1-1"] == true, "the old Mossy Glade run, won, is 1-1")
		t.isNil(p.levelsBeaten["1-2"])
		-- a record with no version is a 1
		t.isTrue(SaveSchema.migrate({ bossesBeaten = { MossyGlade = true } }).levelsBeaten["1-1"])
	end)

	t.test("version 2 keeps its levels as they are", function()
		local p = SaveSchema.migrate({
			version = 2,
			bossesBeaten = { MossyGlade = true },
			levelsBeaten = { ["1-2"] = true, ["1-3"] = "yes", [4] = true },
		})
		t.isTrue(p.levelsBeaten["1-2"])
		t.isNil(p.levelsBeaten["1-3"], "only true counts")
		t.isNil(p.levelsBeaten["1-1"], "no stand-in once levels exist")
		-- and round-trips
		local again = SaveSchema.migrate(p)
		t.isTrue(again.levelsBeaten["1-2"])
		t.isNil(again.levelsBeaten["1-1"])
	end)

	t.test("an older profile has no pets and keeps the rest", function()
		local p = SaveSchema.migrate({ version = 1, coins = 7, weapons = { AcornBow = true } })
		t.equal(p.version, SaveSchema.VERSION)
		t.equal(p.coins, 7)
		t.isTrue(p.weapons.AcornBow)
		t.isNil((next(p.pets)))
		t.isNil((next(p.equippedPets)))
	end)

	t.test("pets keep their counts; only owned pets stay equipped, two at most", function()
		local p = SaveSchema.migrate({
			version = 3,
			pets = { Mosslet = 3, GladeFox = 1, Stumpy = 0 },
			equippedPets = { "GladeFox", "Stumpy", "Mosslet" },
		})
		t.equal(p.pets.Mosslet, 3)
		t.isNil(p.pets.Stumpy, "none of it, none owned")
		t.equal(p.equippedPets[1], "GladeFox")
		t.isNil(p.equippedPets[2], "a pet not owned is not equipped")
		t.isNil(p.equippedPets[3], "only two slots")
	end)

	t.test("3 -> 4: no look until chosen; a valid look is kept, a bad one dropped", function()
		t.isNil(SaveSchema.migrate({ version = 3 }).look)
		t.equal(SaveSchema.migrate({ version = 4, look = "female" }).look, "female")
		t.isNil(SaveSchema.migrate({ version = 4, look = "dragon" }).look)
	end)

	--[[
		5 → 6, Endless (`docs/ENDLESS.md`). Nothing of an older save is read
		as Endless progress, because there was none: no best, no milestone
		claimed, no Soulstones. That is also exactly what a new profile has.
	]]
	t.test("5 -> 6: an older profile has no Endless progress at all", function()
		for _, version in { 1, 2, 3, 4, 5 } do
			local p = SaveSchema.migrate({
				version = version,
				coins = 90,
				weapons = { AcornBow = true },
				levelsBeaten = { ["1-1"] = true },
			})
			t.equal(p.version, SaveSchema.VERSION)
			t.equal(p.endlessBest, 0, `version {version} invented an Endless best`)
			t.isNil((next(p.endlessMilestones)), `version {version} invented a milestone`)
			t.equal(p.soulstones, 0, `version {version} invented Soulstones`)
			-- and lost nothing of its own
			t.equal(p.coins, 90)
			t.isTrue(p.weapons.AcornBow)
			t.isTrue(p.levelsBeaten["1-1"])
		end
		local fresh = SaveSchema.migrate(nil)
		t.equal(fresh.endlessBest, 0)
		t.equal(fresh.soulstones, 0)
		t.isNil((next(fresh.endlessMilestones)))
	end)

	t.test("a version 6 profile keeps its Endless progress, and round-trips", function()
		local p = SaveSchema.migrate({
			version = 6,
			endlessBest = 47,
			endlessMilestones = { ["10"] = true, ["20"] = true, ["30"] = "yes", [50] = true },
			soulstones = 820,
		})
		t.equal(p.endlessBest, 47)
		t.equal(p.soulstones, 820)
		t.isTrue(p.endlessMilestones["10"])
		t.isTrue(p.endlessMilestones["20"])
		t.isNil(p.endlessMilestones["30"], "only true counts")
		t.isNil(p.endlessMilestones["50"], "a number key is not a floor key")
		local again = SaveSchema.migrate(p)
		t.equal(again.endlessBest, 47)
		t.equal(again.soulstones, 820)
		t.isTrue(again.endlessMilestones["20"])
	end)

	--[[ A best is a record. It is never clamped to today's hard cap, so
	     lowering the cap cannot erase a floor somebody actually reached;
	     nonsense still falls back to 0 rather than through. ]]
	t.test("a broken Endless best or total falls back without breaking the profile", function()
		local p = SaveSchema.migrate({
			version = 6,
			endlessBest = -4,
			soulstones = "lots",
			endlessMilestones = "none",
		})
		t.equal(p.endlessBest, 0)
		t.equal(p.soulstones, 0)
		t.isNil((next(p.endlessMilestones)))
		t.equal(SaveSchema.migrate({ version = 6, endlessBest = 61.8 }).endlessBest, 61)
		t.equal(
			SaveSchema.migrate({ version = 6, endlessBest = 4000 }).endlessBest,
			4000,
			"a record set under a higher cap was erased"
		)
	end)

	t.test("the Soulstones' name is one string every screen reads", function()
		t.equal(SaveSchema.SOULSTONES, "SOULSTONES")
	end)

	t.test("a newer game's save is not readable here", function()
		t.isFalse(SaveSchema.readable({ version = SaveSchema.VERSION + 1 }))
		t.isTrue(SaveSchema.readable({ version = SaveSchema.VERSION }))
		t.isTrue(SaveSchema.readable(nil))
	end)

	t.test("a price is paid whole or not at all", function()
		local p = SaveSchema.migrate({ coins = 100, gems = 10, items = { RoyalJelly = 2 } })
		t.isFalse(Purse.pay(p, { coins = 50, items = { RoyalJelly = 3 } }))
		t.equal(p.coins, 100, "nothing taken when one part is short")
		t.equal(p.items.RoyalJelly, 2)
		t.isTrue(Purse.pay(p, { coins = 50, gems = 10, items = { RoyalJelly = 2 } }))
		t.equal(p.coins, 50)
		t.equal(p.gems, 0)
		t.isNil(p.items.RoyalJelly)
		t.isFalse(Purse.pay(p, { gems = 1 }))
	end)
end
