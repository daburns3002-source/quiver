--!strict
--[[
	Thorns that stack (`Shared/Combat/Bleed`, the Bramble Wilf's Thorn Bite;
	owner, 2026-10-31: the Ember Wilf's burn in green was not enough).

	The arithmetic is the whole point of the pet, so it is pinned here: a
	thorn adds rather than refreshing, the stack is capped, and the bleed a
	pet carries is worth staying on one enemy for without being worth more
	than its rarity.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Bleed = require(ReplicatedStorage.Shared.Combat.Bleed)
local PetCombat = require(ReplicatedStorage.Shared.Config.PetCombat)
local TestRunner = require(script.Parent.TestRunner)

return function(t: TestRunner.Helper)
	local thorns: Bleed.Bleed = { rate = 10, stacks = 3, duration = 6 }

	t.test("a thorn adds to the stack, where a burn would only refresh", function()
		t.equal(Bleed.stack(thorns, 0), 1, "the first one")
		t.equal(Bleed.stack(thorns, 1), 2, "the second adds")
		t.equal(Bleed.stack(thorns, 2), 3)
	end)

	t.test("the stack is capped, and a thorn never takes it past the cap", function()
		t.equal(Bleed.stack(thorns, 3), 3, "held at the cap")
		t.equal(Bleed.stack(thorns, 99), 3, "nothing gets past it")
		t.equal(
			Bleed.stack({ rate = 5, stacks = 0, duration = 1 }, 0),
			1,
			"a cap of 0 still bleeds"
		)
	end)

	t.test("the rate is a thorn's for every one carried", function()
		t.near(Bleed.rate(thorns, 0), 0, 1e-9, "no thorns, no bleed")
		t.near(Bleed.rate(thorns, 1), 10, 1e-9)
		t.near(Bleed.rate(thorns, 3), 30, 1e-9)
		t.near(Bleed.rate(thorns, 9), 30, 1e-9, "counted to the cap, never past it")
	end)

	t.test("the most it can do is a full stack for its duration", function()
		t.near(Bleed.most(thorns), 180, 1e-9)
	end)

	t.test("a full stack takes the gaps between all but the first thorn", function()
		t.near(Bleed.ramp(thorns, 3), 6, 1e-9, "two more attacks after the first")
		t.near(Bleed.ramp({ rate = 1, stacks = 1, duration = 1 }, 3), 0, 1e-9, "one thorn, at once")
	end)

	t.test("every pet that bleeds has to earn it, and keeps it while it works", function()
		for name, spec in PetCombat.pets do
			local bleed = spec.bleed
			if not bleed then
				continue
			end
			t.isTrue(bleed.rate > 0, `{name}: a thorn that does something`)
			t.isTrue(bleed.stacks >= 2, `{name}: a stack of one is a burn with extra words`)
			--[[ A stack that lapses between attacks could never be built,
			     so the bleed has to outlive the pet's own clock. ]]
			t.isTrue(
				bleed.duration > spec.every,
				`{name}: thorns lapse before the next attack ({bleed.duration} vs {spec.every})`
			)
			--[[ And it has to be reachable: a full stack inside the time a
			     brute or a boss is alive for, not a theoretical number. ]]
			t.isTrue(
				Bleed.ramp(bleed, spec.every) <= 12,
				`{name}: a full stack takes {Bleed.ramp(bleed, spec.every)}s, too long to see`
			)
		end
	end)
end
