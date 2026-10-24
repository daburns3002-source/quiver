# Tracker: what is in flight

Everything started and not finished, and who it waits on. Claude updates
this in the same PR as the work it describes (CLAUDE.md): add a row when
something starts or gets blocked, strike it when it lands. How each kind of
thing gets made is in [PIPELINES.md](PIPELINES.md).

Last brought up to date: 2026-10-24.

**Scope:** Acts 1–3 only (areas 1–6) until the owner says otherwise (2026-10-24). Acts 4–5 work is on hold.

## Waiting on the owner

| What | What the owner does | Then Claude | Where it is |
|---|---|---|---|
| Mossy Glade music (our own) | Listen on the music page (https://claude.ai/artifact/BdnUVpMs7vdeZMMCpYRniY), pick A or B, then upload `assets/audio/music/glade_<pick>.ogg` to Roblox (Creator Hub → Audio) and say it's up | Find the id (`search_asset`, scope user), make it the Rooms music in `Config/Music` (one track, so it loops seamlessly), playtest, merge; then offer a boss-fight track the same way | Branch `phase-3/glade-music`: `assets/audio/music/glade_theme.py` makes both takes (92 s, F major, 104 BPM, −16 LUFS) |
| Mossy Glade outer forest, warmer light, moss and enemy contrast | Play a glade room and say whether the light, the moss-vs-lawn contrast and the darker lawn read; then save the place (the forest import now lives in `ServerStorage.Imports`) | Forest wired from the import (`Config/GladeForest`, `tools/forest_to_luau.py`); light in `Balance.Lighting`; moss tints in `Config/ArenaKits`; Next: per-tree sway (`ForestTree` tags), and a lighter floor between the trees needs the model's own ground colour changed in Claude Design | Branch `phase-3/glade-outer-forest`; the forest's placement checked in Studio, the light only partly (Studio stopped drawing frames to the capture tool) |
| Pet and enemy animations (Claude Design clips) | Pets: all 12 imported and in the **P** preview with their clips. Optional: re-import `glade_fox.glb` and `glimmerhorn.glb` from `assets/models/pets/forest/` for their open mouths (Pounce, Leap). Enemies: import each finished GLB | Enemies: their clips into `Config/ModelClips`, tag the models `ModelClips` | Pets done (PRs #179–#181 and the nine-clips PR); enemy GLBs not downloaded yet |
| Swaying trees | Import `assets/models/arenas/mossy_glade_trees_roblox.glb` (Merge Meshes off, no rig) — or skip until the blocky glade exists | Dump the 160 mesh ids into `tree_ids.json`, regenerate `ArenaTrees`, playtest, merge | Branch `phase-3/swaying-trees` |
| Uncommon forest weapons | Import them once they're optimised | Built in Claude Design and downloaded to `assets/models/weapons/blocky/uncommon/`: Acorn Bow and its arrow, Toadstool Staff and its bolt, Mossstone Blade, Bramble Shivs and its arcing slash (the slash's `Trail` mesh is the viewer's, so drop it). Next: optimise for import, then each its own animation kit (owner's rule), then `Config/Weapons` entries | Models done 2026-10-24 |
| King Bloblin's fight, blocky | Play room 10 and say whether the fight reads (Studio: jump with `Remotes.DebugRoom:FireServer(10)`) | Wired (2026-10-24): built from his imported rig (`Config/ImportedModels/KingBloblin`, amber Neon eyes), his 22 clips on the fight's beats (`Balance` boss `clips`, `BossMoves.clip`, `Fx/ModelAnimator`), the chain stretched to the lane (`BossMoves.chainScale`), every effect rebuilt in cubes (`Fx/BossFx`). Open: his moves' sounds; the bounce and lash clips mix 60 and 30 fps (the designer offers a resample) | Merged (#197, #198); seen in Studio on #197. #198's fix (he animates however he is moving when first seen) still owes a Studio look |
| Blocky weapons replace the class weapons | Import `assets/models/weapons/blocky/twig_bow_roblox.glb`, `branch_staff_roblox.glb` and `timber_blade_roblox.glb` (File → Import 3D, Merge Meshes off) | Dump their mesh ids; `Config/Weapons` entries with their own animation kits (being made in Claude Design: Twig Bow, Branch Staff and Timber Blade R15 Kits); switch `Config/Classes`; the bow string follows the held bow | Optimised 2026-10-23; waits on the import and the kits |
| Blocky enemies replace the round ones | Import each enemy's optimised GLB when it is ready | Moss Slime, Mother Slime (Brood Slime), Sprout Slime (Sprout Spitter) and King Bloblin (Slime King) through `optimise_enemy.py` once their glowing-eyes pass is done | Glowing-eyes pass running in Claude Design |
| Mossy Glade blocky kit and room | Import the 8 kit GLBs in `assets/models/arenas/mossy_glade_kit/` when the room needs them (Merge Meshes off) | The room itself is being rebuilt in Claude Design from these pieces ("Mossy Glade Arena v3"); then its GLB through `optimise_arena.py` into `ArenaModels` | Kit downloaded 2026-10-23 (260–1,040 triangles each); room in progress |
| Blocky restyle of the game's models | Make blocky models of the enemies, bosses, arenas and weapons in Claude Design from the new blocky concept sheets, and send them | Each through its pipeline, replacing the round one | Concept sheets: the pet-design session (PR #174 and after) |
| The updated slimes (Moss, Brood, Baby; #163) | Import `moss_slime_roblox.glb`, `brood_slime_roblox.glb`, `baby_slime_roblox.glb` from `assets/models/enemies/` — or skip if the blocky slimes replace them | Mesh ids into `EnemyDesigns` (the Baby Slime is a primitive stand-in now; the Moss and Brood Slimes still use their first models) | — |
| Upgrade card effects (20 kept) | Try the cards in a run and say which read wrong (Studio: `Remotes.DebugGrant:FireServer("HeavyBlade")` grants one) | The owner kept 20 of 40 (2026-10-24): Deadly Strike, Blaze, Agility, Vitality, Bloodthirst, Second Wind, Heal, Overdraw, Bouncy Wall, Blast Arrows, Soul Chain, Cleave, Heavy Blade, Bloodletting, Earthbreaker, Twin Cast, Arcane Echo, Spell Pierce, Chain Lightning, Meteor. Placements to confirm in Studio: Bloodletting's heart, Soul Chain's axis, Meteor's trail, Bouncy Wall on the wall | #221, then the trim PR |
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

- The blocky Mossy Glade has no blocky forest or boulder yet: the trees past the walls are still the round models, and boulders are drawn as mossy stone pillars, whose moss tops read as lawn from above. A blocky tree and boulder in the kit would fix both.

- Enemy overlap with cover is measured clean in rooms 1–4 only; rooms 5–10 and the arena art itself are unmeasured (CLAUDE.md, "Known rough edges").
- A Wilf lunge stopped short by cover still plays its leap for the full time.
- The Slime King's moves have no sounds yet.
- The Meteor cast (1.6 s) hides the staff's cast animation while it plays; shorten it if it feels long.
- Slime residue (`Fx/SlimeResidue`, `Balance.SlimeResidue`) lands on the floor plane, y = 0: a cube thrown over a log, a boulder or the pond sinks into it instead of resting on top. Its colours are taken from the blocky models' vertex colours; the owner may want them tuned.

## Offered, not asked for

- Jelly splats where the Slime King slams.
