---
name: add-enemy
description: Add or update an enemy or boss model in the game — static mesh, rigged (skinned with animations) or a boss with moves — from the owner's Claude Design files through slimming, the owner's Studio import, mesh ids, designs, config and a playtest.
---

# Add an enemy

Follow `docs/PIPELINES.md` §1 (static), §2 (rigged) or §3 (boss). In short:

1. `/intake` the files first.
2. Static: `assets/models/enemies/optimise_enemy.py <in> <out> <enemy> [model]` (add the enemy to its `ENEMIES` table), preview the output, then ask the owner to import the slimmed GLB (File → Import 3D). Rigged: the owner imports the rigged GLB with Rig: Custom.
3. After the import: run `tools/studio/dump_imports.luau` (Edit datamodel) for the mesh ids (and bones). Rigged: write `rig.json` and regenerate `Config/EnemyRigs` with the enemy's `rig_to_luau.py`.
4. `EnemyDesigns` body (white mesh parts, Neon eyes in the act's colour, 180° turn for static imports), hitbox fitted in `Balance`, roster in the level. Names: every wolf is a Wilf.
5. Loop 0 in `docs/PIPELINES.md`: `tools/check.sh`, sync probe, tests, spawn it in Studio (`DebugSpawnEnemy`) and measure, FIXES/TRACKER/CLAUDE.md, self-review, `tools/ship.sh`.
