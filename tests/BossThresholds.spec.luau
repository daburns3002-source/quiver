--!strict
--[[
	King Bloblin's health thirds (`Util/BossThresholds`,
	`Balance.BossSummon.atFractions`, owner 2026-10-28): two Brood Slimes
	each time his health falls through a third of his max.

	What is pinned here is the rule that is easy to get wrong and invisible
	in a playtest: **each threshold is owed exactly once, however the damage
	lands**, and a single blow that crosses two owes both. The crossings are
	counted off the health he has now rather than off each blow, so the
	banking the server does (`EnemyManager`'s `bankThresholds`) is the two
	lines this spec replays.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Balance = require(ReplicatedStorage.Shared.Config.Balance)
local BossThresholds = require(ReplicatedStorage.Shared.Util.BossThresholds)
local KingBloblinClips = require(ReplicatedStorage.Shared.Config.ModelClips.KingBloblin)
local TestRunner = require(script.Parent.TestRunner)

--[[ The server's own banking, which is why it is three lines: hits in,
     clutches owed out, and no memory of which blow did it. ]]
local function clutches(fractions: { number }, maxHealth: number, hits: { number }): { number }
	local owed: { number } = {}
	local health = maxHealth
	local passed = 0
	for _, hit in hits do
		health -= hit
		if health <= 0 then
			break
		end
		local now = BossThresholds.reached(fractions, health, maxHealth)
		table.insert(owed, now - passed)
		passed = now
	end
	return owed
end

local function total(owed: { number }): number
	local sum = 0
	for _, each in owed do
		sum += each
	end
	return sum
end

return function(t: TestRunner.Helper)
	local summon = (Balance.Enemies.SlimeKing.boss :: Balance.EnemyBoss).summon

	t.test("King Bloblin summons two Brood Slimes at each third", function()
		t.notNil(summon, "the King has no summon")
		local fight = summon :: Balance.BossSummon
		local fractions = fight.atFractions
		t.notNil(fractions, "the King's summon is not health-driven")
		t.equal(#(fractions :: { number }), 2, "the King's thresholds are not two")
		t.near((fractions :: { number })[1], 2 / 3, 1e-6)
		t.near((fractions :: { number })[2], 1 / 3, 1e-6)
		t.equal(fight.count, 2, "the King's clutch is not two slimes")
		t.equal(fight.into.displayName, "BroodSlime")
		--[[ A move-count summon and a health-driven one are different
		     fields, and the King must not have both. ]]
		t.isNil(fight.every, "the King's summon is on a move count as well")
	end)

	t.test("the King's clip is one of the 22 he already has", function()
		local fight = summon :: Balance.BossSummon
		t.notNil((KingBloblinClips.clips :: any)[fight.clip], `the King has no "{fight.clip}" clip`)
	end)

	t.test("a fraction is reached at exactly its value and below, not above", function()
		local fractions = { 2 / 3, 1 / 3 }
		t.equal(BossThresholds.reached(fractions, 100, 100), 0, "full health reached a third")
		t.equal(BossThresholds.reached(fractions, 67, 100), 0)
		t.equal(BossThresholds.reached(fractions, 66, 100), 1)
		t.equal(BossThresholds.reached(fractions, 2, 3), 1, "exactly 2/3 was not reached")
		t.equal(BossThresholds.reached(fractions, 1, 3), 2, "exactly 1/3 was not reached")
		t.equal(BossThresholds.reached(fractions, 34, 100), 1)
		t.equal(BossThresholds.reached(fractions, 33, 100), 2)
		t.equal(BossThresholds.reached(fractions, 0, 100), 2, "a dead boss reached neither")
	end)

	t.test("no fight and no thresholds reach nothing", function()
		t.equal(BossThresholds.reached({ 2 / 3 }, 50, 0), 0, "a boss with no max health")
		t.equal(BossThresholds.reached({}, 1, 100), 0, "a boss with no thresholds")
	end)

	t.test("the order of the fractions does not change the count", function()
		t.equal(BossThresholds.reached({ 1 / 3, 2 / 3 }, 40, 100), 1)
		t.equal(BossThresholds.reached({ 2 / 3, 1 / 3 }, 40, 100), 1)
	end)

	t.test("chip damage owes each third exactly once", function()
		local hits: { number } = {}
		for _ = 1, 90 do
			table.insert(hits, 10)
		end
		local owed = clutches({ 2 / 3, 1 / 3 }, 1000, hits)
		t.equal(total(owed), 2, "ninety chip hits did not owe exactly two clutches")
		--[[ On the hits that cross, and on no others: health 660 and 330. ]]
		t.equal(owed[34], 1, "the 34th hit (to 660) owed nothing")
		t.equal(owed[67], 1, "the 67th hit (to 330) owed nothing")
		t.equal(owed[35], 0, "the hit after a crossing owed a second clutch")
	end)

	t.test("one blow from 70% to 30% owes both thirds", function()
		local owed = clutches({ 2 / 3, 1 / 3 }, 1000, { 300, 400 })
		t.equal(owed[1], 0, "a blow to 70% owed a clutch")
		t.equal(owed[2], 2, "a blow from 70% to 30% did not owe both thirds")
		t.equal(total(owed), 2)
	end)

	t.test("a killing blow owes nothing: the fight is over", function()
		--[[ The server banks only on a blow that leaves the boss standing,
		     so the clutch that would land as he dies never drops. ]]
		local owed = clutches({ 2 / 3, 1 / 3 }, 1000, { 1000 })
		t.equal(total(owed), 0, "a boss killed outright still summoned")
	end)

	t.test("the bar is segmented from the thresholds, one part more", function()
		local fight = summon :: Balance.BossSummon
		local fractions = fight.atFractions :: { number }
		--[[ `EnemyManager` publishes this as `HealthSegments` and
		     `UI/BossBar` draws that many parts: two thresholds, thirds. ]]
		t.equal(#fractions + 1, 3, "the King's bar is not in thirds")
	end)
end
