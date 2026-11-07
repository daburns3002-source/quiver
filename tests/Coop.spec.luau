--!strict
--[[
	Co-op's numbers and rules (`Shared/Util/Coop`, `docs/COOP.md`): what a
	party of two scales, the revive's fill and drain, and who a portal's
	START takes along.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Coop = require(ReplicatedStorage.Shared.Util.Coop)
local TestRunner = require(script.Parent.TestRunner)

return function(t: TestRunner.Helper)
	t.test("solo changes nothing", function()
		t.equal(Coop.enemyCount(7, 1), 7)
		t.equal(Coop.healthScale(1, false), 1)
		t.equal(Coop.healthScale(1, true), 1)
	end)

	t.test("two players: x1.65 enemies, health x1.10, boss health x1.7", function()
		t.equal(Coop.enemyCount(10, 2), 17)
		t.equal(Coop.enemyCount(6, 2), 10)
		t.near(Coop.healthScale(2, false), 1.10, 1e-9)
		t.near(Coop.healthScale(2, true), 1.7, 1e-9)
	end)

	t.test("a count never drops below solo, and nothing stays nothing", function()
		t.equal(Coop.enemyCount(1, 2), 2)
		t.equal(Coop.enemyCount(0, 2), 0)
		for count = 1, 30 do
			t.isTrue(Coop.enemyCount(count, 2) >= count, `count {count}`)
		end
	end)

	t.test("a party past the table uses its last row", function()
		t.equal(Coop.healthScale(9, true), Coop.scale[#Coop.scale].bossHealth)
	end)

	t.test("a revive fills in range, drains out of it, and caps at the hold", function()
		local hold = Coop.revive.hold
		local p = Coop.reviveStep(0, 1, true)
		t.near(p, 1, 1e-9)
		p = Coop.reviveStep(p, 0.5, false)
		t.near(p, 1 - 0.5 * Coop.revive.drain, 1e-9)
		t.equal(Coop.reviveStep(p, 100, true), hold)
		t.equal(Coop.reviveStep(0, 5, false), 0)
	end)

	t.test("a portal party is the starter first, then others, up to the cap", function()
		local party = Coop.pickParty(5, { 7, 5, 9 })
		t.equal(#party, Coop.maxParty)
		t.equal(party[1], 5)
		t.equal(party[2], 7)
		t.equal(#Coop.pickParty(5, {}), 1)
	end)

	t.test("the revive numbers make sense", function()
		t.isTrue(Coop.revive.health > Coop.revive.returnHealth)
		t.isTrue(Coop.revive.bleedOut > Coop.revive.hold * 3)
		t.isTrue(Coop.maxParty >= 2)
	end)
end
