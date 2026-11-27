--!strict
--[[
	Merge tiers (`Util/MergeRules`) and the version 10 save (`Util/SaveSchema`):
	three of a tier make one of the next up to S, the best tier is the one
	in hand, and an older save holds what it owned at C, so a duplicate is
	saved as a copy from then on.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local MergeRules = require(ReplicatedStorage.Shared.Util.MergeRules)
local SaveSchema = require(ReplicatedStorage.Shared.Util.SaveSchema)
local TestRunner = require(script.Parent.TestRunner)

return function(t: TestRunner.Helper)
	t.test("three of a tier merge into one of the next, C to B to A to S", function()
		local held: MergeRules.Counts = { C = 4 }
		t.isTrue(MergeRules.merge(held, "C"))
		t.equal(held.C, 1)
		t.equal(held.B, 1)
		t.isFalse(MergeRules.merge(held, "C"), "one C left is not three")
		t.isFalse(MergeRules.merge(held, "B"), "one B is not three")
		t.equal(held.C, 1, "a refused merge changes nothing")
		local up: MergeRules.Counts = { A = 3 }
		t.isTrue(MergeRules.merge(up, "A"))
		t.isNil(up.A, "none of a tier is no entry")
		t.equal(up.S, 1)
		t.equal(MergeRules.nextTier("C"), "B")
		t.equal(MergeRules.nextTier("B"), "A")
		t.equal(MergeRules.nextTier("A"), "S")
	end)

	t.test("S is the top: never merged", function()
		local held: MergeRules.Counts = { S = 5 }
		t.isFalse(MergeRules.canMerge(held, "S"))
		t.isFalse(MergeRules.merge(held, "S"))
		t.equal(held.S, 5)
		t.isFalse(MergeRules.merge(held, "X"), "an unknown tier is refused")
	end)

	t.test("the best tier is in hand; totals count every copy", function()
		t.equal(MergeRules.best({ C = 2, A = 1 }), "A")
		t.isNil(MergeRules.best({}))
		t.isNil(MergeRules.best(nil))
		t.equal(MergeRules.total({ C = 2, B = 1, S = 1 }), 4)
	end)

	t.test("each tier is 1.2x the last, S 1.5x over A (owner)", function()
		for _, scales in { MergeRules.weaponScale, MergeRules.petScale } do
			t.equal(scales.C, 1)
			t.near(scales.B / scales.C, 1.2, 1e-9)
			t.near(scales.A / scales.B, 1.2, 1e-9)
			t.near(scales.S / scales.A, 1.5, 1e-9)
			t.near(scales.S, 2.16, 1e-9)
		end
	end)

	t.test("stored tier counts are cleaned", function()
		local held = MergeRules.clean({ C = 2.7, B = -1, A = 0 / 0, S = "3", Z = 4 })
		t.equal(held.C, 2)
		t.isNil(held.B)
		t.isNil(held.A)
		t.isNil(held.S)
		t.isNil((held :: any).Z)
	end)

	t.test("a new profile holds each starter weapon at one C", function()
		local p = SaveSchema.default()
		t.equal(p.tiers.weapons.TwigBow.C, 1)
		t.equal(p.tiers.weapons.BranchStaff.C, 1)
		t.equal(p.tiers.weapons.TimberBlade.C, 1)
		t.isNil((next(p.tiers.pets)))
	end)

	t.test("9 -> 10: owned weapons are one C, each pet's count is that many C", function()
		local p = SaveSchema.migrate({
			version = 9,
			tutorialDone = true,
			coins = 12,
			weapons = { AcornBow = true },
			equipped = "AcornBow",
			pets = { Mosslet = 3, GladeFox = 1 },
			equippedPets = { "Mosslet" },
		})
		t.equal(p.version, SaveSchema.VERSION)
		t.equal(p.coins, 12, "nothing else is touched")
		t.isTrue(p.tutorialDone, "an earlier version's own field comes across")
		t.equal(p.equipped, "AcornBow")
		t.equal(p.equippedPets[1], "Mosslet")
		t.equal(p.tiers.weapons.AcornBow.C, 1)
		t.equal(p.tiers.weapons.TwigBow.C, 1, "the starters too")
		t.equal(p.tiers.pets.Mosslet.C, 3)
		t.equal(p.tiers.pets.GladeFox.C, 1)
		t.equal(p.pets.Mosslet, 3)
	end)

	t.test("a version 1 save with no tiers migrates all the way", function()
		local p = SaveSchema.migrate({ version = 1, weapons = { AcornBow = true } })
		t.equal(p.tiers.weapons.AcornBow.C, 1)
	end)

	t.test("10 keeps its tiers; a pet's count is its copies; junk is dropped", function()
		local p = SaveSchema.migrate({
			version = 10,
			weapons = { AcornBow = true },
			pets = { Mosslet = 9 },
			tiers = {
				weapons = { AcornBow = { C = 2, B = 1 }, Unowned = { S = 1 } },
				pets = { Mosslet = { B = 1, C = 1 }, NotHatched = { C = 3 } },
			},
		})
		t.equal(p.tiers.weapons.AcornBow.C, 2)
		t.equal(p.tiers.weapons.AcornBow.B, 1)
		t.isNil(p.tiers.weapons.Unowned, "only owned weapons hold copies")
		t.equal(p.tiers.pets.Mosslet.B, 1)
		t.equal(p.pets.Mosslet, 2, "the count follows the copies")
		t.isNil(p.tiers.pets.NotHatched)
		-- broken tiers fall back to one C, never to nothing
		local broken = SaveSchema.migrate({
			version = 10,
			weapons = { AcornBow = true },
			tiers = { weapons = { AcornBow = "junk" } },
		})
		t.equal(broken.tiers.weapons.AcornBow.C, 1)
	end)

	t.test("a merged save survives a save and load", function()
		local p = SaveSchema.default()
		p.tiers.weapons.TwigBow = { C = 3 }
		t.isTrue(MergeRules.merge(p.tiers.weapons.TwigBow, "C"))
		local again = SaveSchema.migrate(p)
		t.equal(MergeRules.best(again.tiers.weapons.TwigBow), "B")
		t.isNil(again.tiers.weapons.TwigBow.C)
	end)
end
