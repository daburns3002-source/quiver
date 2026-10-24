# Tracker: what is in flight

Everything started and not finished, and who it waits on. Claude updates
this in the same PR as the work it describes (CLAUDE.md): add a row when
something starts or gets blocked, strike it when it lands. How each kind of
thing gets made is in [PIPELINES.md](PIPELINES.md).

Last brought up to date: 2026-10-23.

**Scope:** Acts 1–3 only (areas 1–6) until the owner says otherwise (2026-10-24). Acts 4–5 work is on hold.

## Waiting on the owner

| What | What the owner does | Then Claude | Where it is |
|---|---|---|---|
| Pet and enemy animations (Claude Design clips) | Pets: all 12 imported and in the **P** preview with their clips. Optional: re-import `glade_fox.glb` and `glimmerhorn.glb` from `assets/models/pets/forest/` for their open mouths (Pounce, Leap). Enemies: import each finished GLB | Enemies: their clips into `Config/ModelClips`, tag the models `ModelClips` | Pets done (PRs #179–#181 and the nine-clips PR); enemy GLBs not downloaded yet |
| Swaying trees | Import `assets/models/arenas/mossy_glade_trees_roblox.glb` (Merge Meshes off, no rig) — or skip until the blocky glade exists | Dump the 160 mesh ids into `tree_ids.json`, regenerate `ArenaTrees`, playtest, merge | Branch `phase-3/swaying-trees` |
| Blocky weapons replace the class weapons | Import `assets/models/weapons/blocky/twig_bow_roblox.glb`, `branch_staff_roblox.glb` and `timber_blade_roblox.glb` (File → Import 3D, Merge Meshes off) | Dump their mesh ids; `Config/Weapons` entries with their own animation kits (being made in Claude Design: Twig Bow, Branch Staff and Timber Blade R15 Kits); switch `Config/Classes`; the bow string follows the held bow | Optimised 2026-10-23; waits on the import and the kits |
| Blocky enemies replace the round ones | Import each enemy's optimised GLB when it is ready | Moss Slime, Mother Slime (Brood Slime), Sprout Slime (Sprout Spitter) and King Bloblin (Slime King) through `optimise_enemy.py` once their glowing-eyes pass is done | Glowing-eyes pass running in Claude Design |
| Mossy Glade blocky kit and room | Import the 8 kit GLBs in `assets/models/arenas/mossy_glade_kit/` when the room needs them (Merge Meshes off) | The room itself is being rebuilt in Claude Design from these pieces ("Mossy Glade Arena v3"); then its GLB through `optimise_arena.py` into `ArenaModels` | Kit downloaded 2026-10-23 (260–1,040 triangles each); room in progress |
| Blocky restyle of the game's models | Make blocky models of the enemies, bosses, arenas and weapons in Claude Design from the new blocky concept sheets, and send them | Each through its pipeline, replacing the round one | Concept sheets: the pet-design session (PR #174 and after) |
| The updated slimes (Moss, Brood, Baby; #163) | Import `moss_slime_roblox.glb`, `brood_slime_roblox.glb`, `baby_slime_roblox.glb` from `assets/models/enemies/` — or skip if the blocky slimes replace them | Mesh ids into `EnemyDesigns` (the Baby Slime is a primitive stand-in now; the Moss and Brood Slimes still use their first models) | — |
| Phase 3 playtest question | Answer: *did two runs in a row feel meaningfully different?* | Phase 4 can start | ROADMAP.md |
| Lobby reference images | Put them in `assets/reference/lobby/` | Spec `docs/LOBBY.md` from them | — |

## Open PRs

| PR | What | Waiting on |
|---|---|---|
| #174 | Wolves are Wilfs, and every area has a Wilf pet (designs) | Its session; then merge |
| #173 | A Codex-built Mosslet with animations, against Claude Design's | Owner's comparison |

## Designed, not built

- The other bosses of Acts 1–3 (`docs/BOSSES.md`; the Slime King is built). Acts 4–5's are on hold.
- Wave 2 of the Warden's and the Arcanist's cards (`docs/CLASS-CARDS.md`; icons made).
- Pets, eggs and weapon skins (`docs/PETS-FOREST.md`, the Wilf pets): design only, no pet system in the game yet.

## Known rough edges

- Enemy overlap with cover is measured clean in rooms 1–4 only; rooms 5–10 and the arena art itself are unmeasured (CLAUDE.md, "Known rough edges").
- A Wilf lunge stopped short by cover still plays its leap for the full time.
- The Slime King's moves have no sounds yet.
- The Meteor cast (1.6 s) hides the staff's cast animation while it plays; shorten it if it feels long.

## Offered, not asked for

- Jelly splats where the Slime King slams.
