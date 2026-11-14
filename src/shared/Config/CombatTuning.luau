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
	--[[ Every boss's health, on top of its own number, its stage's and
	     co-op's (owner, 2026-11-08: "boss health needs to be higher, the
	     bosses are too easy to kill"). One knob, so each boss's own number
	     keeps its place relative to the others. ]]
	bossHealth = 1.5,
	roomHealthStart = 0.75,
	roomHealthPerEncounter = 0.029,
	--[[ The same ramp on enemy damage (owner, 2026-11-05: "the levels should
	     scale difficulty per room", when two Bramble Boars killed a player
	     in Thornwood's room 12). The stage's number is now the top: 0.7 of
	     it in the first fight, all of it by the twentieth, never over. Damage
	     was flat, so a level's first room hit as hard as its last.
	     (`Run/Waves.damageRamp`) ]]
	roomDamageStart = 0.7,
	roomDamagePerEncounter = 0.016,
	--[[ How long MENU's LEAVE THE RUN? panel can hold the run, in seconds:
	     a budget spent while held (`Util/MenuHold`), earned back at
	     `menuRefill` seconds a second while not. ]]
	menuHold = 60,
	menuRefill = 0.25,
})
