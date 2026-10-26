--!strict
--[[
	Saved data (`Util/SaveSchema`) and paying from it (`Util/Purse`): a new
	player gets the classes' weapons and an empty wallet, any stored copy
	migrates without losing what is valid, a newer game's copy is left
	alone, and a price is paid whole or not at all.
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
