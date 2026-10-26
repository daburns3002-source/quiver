--!strict
--[[
	A pet's root (`Shared/Util/RootHold`, Stumpy's Root Snare; owner,
	2026-10-26: "stumpy needs to hold enemies in place"): how long a hold
	lasts, how two combine, and that the numbers in `Config/PetCombat` help
	without holding a room still.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local PetAttacks = require(ReplicatedStorage.Shared.Config.PetAttacks)
local PetCombat = require(ReplicatedStorage.Shared.Config.PetCombat)
local RootHold = require(ReplicatedStorage.Shared.Util.RootHold)
local TestRunner = require(script.Parent.TestRunner)

return function(t: TestRunner.Helper)
	local root = { duration = 2, boss = 0.5 }

	t.test("a root holds an enemy its duration, a boss its own", function()
		t.near(RootHold.seconds(root, false), 2, 1e-9)
		t.near(RootHold.seconds(root, true), 0.5, 1e-9)
		t.near(RootHold.seconds({ duration = 2, boss = 0 }, true), 0, 1e-9, "0 holds no boss")
	end)

	t.test("held from the hit until it runs out, and no longer", function()
		local untilTime = RootHold.extend(0, 10, 2)
		t.isTrue(RootHold.held(untilTime, 10), "held as it lands")
		t.isTrue(RootHold.held(untilTime, 11.99), "held to the end")
		t.isFalse(RootHold.held(untilTime, 12), "let go at the end")
		t.isFalse(RootHold.held(0, 10), "never rooted, never held")
	end)

	t.test("a second root refreshes a hold, never sums with it", function()
		local first = RootHold.extend(0, 10, 2)
		t.near(RootHold.extend(first, 11, 2), 13, 1e-9, "refreshed from the new hit")
		t.near(RootHold.extend(first, 10.5, 0.5), first, 1e-9, "a shorter one keeps the longer")
	end)

	t.test("every pet that roots holds for a while, but under half the time", function()
		for name, spec in PetCombat.pets do
			local hold = spec.root
			if not hold then
				continue
			end
			t.isTrue(hold.duration >= 1, `{name}: a hold long enough to see`)
			t.isTrue(hold.boss >= 0 and hold.boss <= hold.duration, `{name}: a boss held less`)
			t.isTrue(
				RootHold.uptime(hold, spec.every) <= 0.5,
				`{name}: one enemy is free at least half the time`
			)
		end
	end)

	t.test("every pet that roots draws its hold", function()
		for name, spec in PetCombat.pets do
			if not spec.root then
				continue
			end
			local drawn = false
			for _, shot in (PetAttacks :: any)[name] or {} do
				drawn = drawn or shot.kind == "Hold"
			end
			t.isTrue(drawn, `{name}: a Hold piece in Config/PetAttacks`)
		end
	end)
end
