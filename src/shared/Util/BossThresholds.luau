--!strict
--[[
	A boss's health thresholds: the fractions of its max health at which its
	fight does something. King Bloblin's clutch of two Brood Slimes at each
	third is the first (`Balance.BossSummon.atFractions`, owner 2026-10-28).

	The arithmetic only, and pure, so a blow that crosses two thresholds at
	once is pinned by a test rather than found in a playtest
	(`tests/BossThresholds.spec`). What is summoned, and when the wind-up
	plays, is `Enemies/EnemyManager`'s; the segments the boss bar draws from
	the same count are presentation (`UI/BossBar`).

	Counted off the health the boss has *now* rather than off each blow, so
	every threshold fires exactly once however the damage lands: a hundred
	chip hits and one enormous one leave the same count behind, and nothing
	has to remember which blow did it.
]]

local BossThresholds = {}

--[[
	How many of `fractions` a boss on `health` of `maxHealth` has fallen
	through, counting a fraction as reached at exactly its value. Order does
	not matter: it is a count, not a position in the list.

	`maxHealth` of zero reaches nothing — there is no fight to pace.
]]
function BossThresholds.reached(fractions: { number }, health: number, maxHealth: number): number
	if maxHealth <= 0 then
		return 0
	end
	local ratio = health / maxHealth
	local count = 0
	for _, fraction in fractions do
		if ratio <= fraction then
			count += 1
		end
	end
	return count
end

return BossThresholds
