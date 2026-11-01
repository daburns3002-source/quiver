--!strict
--[[
	The Tide Wilf's Wake Chase (`Shared/Util/PetWake`, `Config/PetCombat`):
	damage an enemy only pays by moving, and only up to what the wake holds.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local PetCombat = require(ReplicatedStorage.Shared.Config.PetCombat)
local PetWake = require(ReplicatedStorage.Shared.Util.PetWake)
local TestRunner = require(script.Parent.TestRunner)

local WAKE: PetWake.Wake = { damage = 45, perStud = 3, hits = 4, duration = 3 }

return function(t: TestRunner.Helper)
	--[[ The whole point of the pet: standing still is free. ]]
	t.test("an enemy that does not move owes nothing", function()
		t.equal(PetWake.owed(WAKE, 0, 0), 0)
		t.equal(PetWake.owed(WAKE, 2.9, 0), 0)
	end)

	t.test("a splash is owed for each full step, never a part of one", function()
		t.equal(PetWake.owed(WAKE, 3, 0), 1)
		t.equal(PetWake.owed(WAKE, 5.9, 0), 1)
		t.equal(PetWake.owed(WAKE, 6, 0), 2)
	end)

	t.test("splashes already paid are not owed twice", function()
		t.equal(PetWake.owed(WAKE, 9, 2), 1)
		t.equal(PetWake.owed(WAKE, 9, 3), 0)
	end)

	--[[ A wake that kept paying would make one Legendary the answer to
	     every chase in the game, however long it went on. ]]
	t.test("a wake stops at its own count, however far the enemy runs", function()
		t.equal(PetWake.owed(WAKE, 1000, 0), WAKE.hits)
		t.equal(PetWake.owed(WAKE, 1000, WAKE.hits), 0)
	end)

	t.test("its total and its reach are its count, spelled out", function()
		t.equal(PetWake.total(WAKE), 180)
		t.equal(PetWake.reach(WAKE), 12)
	end)

	--[[ A wake whose reach an enemy could not cover inside its own
	     duration could never pay out, however fast the enemy ran. Against
	     a 7-studs-a-second runner, 3 seconds is 21 studs. ]]
	t.test("every pet's wake can be paid in full inside its own time", function()
		for key, spec in PetCombat.pets do
			local wake = spec.wake
			if wake then
				t.isTrue(PetWake.reach(wake) <= wake.duration * 7, key)
				t.isTrue(wake.hits > 0 and wake.perStud > 0, key)
			end
		end
	end)
end
