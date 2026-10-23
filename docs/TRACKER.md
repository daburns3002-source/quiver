# Tracker: what is in flight

Everything started and not finished, and who it waits on. Claude updates
this in the same PR as the work it describes (CLAUDE.md): add a row when
something starts or gets blocked, strike it when it lands. How each kind of
thing gets made is in [PIPELINES.md](PIPELINES.md).

Last brought up to date: 2026-10-23.

## Waiting on the owner

| What | What the owner does | Then Claude | Where it is |
|---|---|---|---|
| Swaying trees | Import `assets/models/arenas/mossy_glade_trees_roblox.glb` (Merge Meshes off, no rig) — or skip until the blocky glade exists | Dump the 160 mesh ids into `tree_ids.json`, regenerate `ArenaTrees`, playtest, merge | Branch `phase-3/swaying-trees` |
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

- The other nine bosses (`docs/BOSSES.md`; the Slime King is built).
- Wave 2 of the Warden's and the Arcanist's cards (`docs/CLASS-CARDS.md`; icons made).
- Pets, eggs and weapon skins (`docs/PETS-FOREST.md`, the Wilf pets): design only, no pet system in the game yet.

## Known rough edges

- Enemy overlap with cover is measured clean in rooms 1–4 only; rooms 5–10 and the arena art itself are unmeasured (CLAUDE.md, "Known rough edges").
- A Wilf lunge stopped short by cover still plays its leap for the full time.
- The Slime King's moves have no sounds yet.
- The Meteor cast (1.6 s) hides the staff's cast animation while it plays; shorten it if it feels long.

## Offered, not asked for

- Jelly splats where the Slime King slams.
