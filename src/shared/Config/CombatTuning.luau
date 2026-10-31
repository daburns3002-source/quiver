--!strict
-- Combat balance pass, 2026-10-29. Extra-copy scales compound when patterns
-- combine; default stage arguments remain full damage for enemy patterns.
return table.freeze({
	extraProjectileDamage = 0.4,
	multishotDamage = 0.5,
	--[[ Within-level health ramp, relative to the stage's own base, reset
	     each level (`Enemies/EnemyManager.difficulty`, `docs/DIFFICULTY.md`).

	     Codex's pass added the growth; the owner asked for the other half
	     (2026-10-31: "it starts easier and gets harder", of the levels as
	     well as Endless). So the first encounter now sits at 0.75 and the
	     rate rises 0.02 to 0.029 to pay for it: over a 20-wave level that is
	     0.75 at wave 1, about 1.0 at wave 10 and 1.30 at wave 20.

	     Why it was needed: a level's difficulty was one flat number, so it
	     was tuned for the middle and met the player at wave 1 with no cards
	     drafted at all. ]]
	roomHealthStart = 0.75,
	roomHealthPerEncounter = 0.029,
})
