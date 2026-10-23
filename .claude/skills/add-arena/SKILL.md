---
name: add-arena
description: Add or update an arena (a room's look) or its scenery — slim the Claude Design arena, the owner's import, ArenaModels, cover boxes, swaying trees and ambience — and check it in Studio.
---

# Add an arena

Follow `docs/PIPELINES.md` §4. In short:

1. `/intake` the files.
2. `assets/models/arenas/optimise_arena.py <in> <out> <arena>`; the owner imports the result.
3. `tools/studio/dump_imports.luau` for the ids → the `ArenaModels` entry (parts, `surround`, `outsideColor`, `ambience`); cover as obstacle boxes in the level's rooms in `Balance`, at the model's own positions.
4. Swaying trees: `split_trees.py` (add the forest to `FORESTS`) → owner imports `*_trees_roblox.glb` with Merge Meshes off → dump → `tree_ids.json` → `trees_to_luau.py`.
5. Loop 0: gates, sync probe, tests, then walk the room in Studio — no void at the screen's edges, cover blocks the player, low cover lets arrows over, no z-fighting — and `tools/ship.sh`.
