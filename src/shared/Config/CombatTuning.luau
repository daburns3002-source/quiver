--!strict
-- Combat balance pass, 2026-10-29. Extra-copy scales compound when patterns
-- combine; default stage arguments remain full damage for enemy patterns.
return table.freeze({
	extraProjectileDamage = 0.4,
	multishotDamage = 0.5,
	-- Linear growth relative to stage base HP, reset for each level.
	roomHealthPerEncounter = 0.02,
})
