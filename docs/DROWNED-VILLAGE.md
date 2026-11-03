# The Drowned Village (area 3): what is built and what it waits on

Owner, 2026-11-03: *"make sure drowned village is put together"*.

This is the one place the area's state is written down. It was spread across
three tracker rows, two pet docs, a weapons doc and `docs/BOSSES.md`, which is
why it kept looking more finished than it is.

**The short version: the area has no arena, and almost everything else is
waiting on that.** Its weapons, its pets, its boss design and three of its four
enemy cards are done. None of them can be reached, because there is nowhere to
stand.

## What is built

| Piece | State |
|---|---|
| **Weapons** | All 14 in `Config/WeaponStats`, `Config/Sandbox` and `Config/Weapons`, with their reference sheets and all 14 shop pictures in `Config/ShopAssets` (2026-11-03). |
| **Pets, 5 of 8** | Slate Turtle, Buoy Puffer, Inkpot, Tide Wilf, Abyss Jelly: models, `Config/Pets` rows (benched), auras, and `Config/PetCombat` specs. |
| **Pet behaviours** | All five are real server rules, each its own pure module: `Util/Shelter`, `Util/PetWake`, `Util/DeepAccord`, plus `EnemyManager.blind` and the puffer's payback. |
| **Hollow Fisherman** | Whole: `EnemyDesigns` body from its Tripo import, its archetype in `Balance.Benched`, and its hook (`EnemyShot.reel`, a drawn line that drags the player back). In no roster, because there are no rooms. |
| **Three enemy cards** | Drowned Zombie, Ditch Eel and Bell Ringer have their NEW ENEMY! entries in `Config/NewEnemies` with pictures uploaded. |
| **The boss, on paper** | The Old Tollcrab is fully designed in `docs/BOSSES.md`: Toll (an expanding shockwave ring that smashes through houses), Echo Mark, and Phase 2's Drowned Rise. Its banner and icon are in `Config/BossBanners`, uploaded. Its model is imported (`assets/models/enemies/drowned/crab_arena_3`). |
| **The crate** | In `Config/Shop` at 2,000 coins, `stocked` off. |

## What it waits on, in the order it has to happen

Each step needs the one before it. This is why nothing here can be picked up
out of order.

1. **The arena. The owner's to make.** Nothing exists but the concept sheet
   `assets/concepts/blocky/arenas/area03_drowned_village.jpg` — no GLB, no kit,
   no imports. It has to come out of Claude Design and be sent, the way the
   Mossy Glade and Thornwood kits were (CLAUDE.md rule 10). **Everything below
   is blocked on this.**
2. **The kit, the rooms and the stages.** From the import: `Config/ArenaKits`,
   generated rooms the way `tools/thornwood_rooms.py` wrote Thornwood's, and
   `Balance.Stages` entries. Until these exist the area has no levels, so no
   enemy can spawn and no boss can be fought.
3. **Three enemy models** — Drowned Zombie, Ditch Eel, Bell Ringer. Their cards
   and pictures are already waiting for them. Then rosters, and the Hollow
   Fisherman comes off the bench.
4. **The Old Tollcrab.** The design and the model are ready; it needs its
   `Balance` boss entry, its moves built (the ring is new work — it smashes
   through cover rather than going round it), and a boss arena from the kit.
5. **The boss item.** `Config/Economy` has no `DrownedVillage` entry at all, so
   there is nothing to price a Legendary against — the Royal Jelly and the Brood
   Silk each need an opposite number here, with a name, a price and a Codex
   icon. It can only drop once step 4 can be fought.
6. **The crate, stocked.** `Config/Shop`'s `stocked` flag, once steps 2 and 5
   are done. `tests/ConfigConsistency.spec` holds it to exactly that: a stocked
   area must have stages to reach it, an `Economy` entry to price its Legendary,
   and a picture for every weapon it sells. Stocking it early would put gear a
   quarter stronger than anything native on sale to a glade-only player
   (`docs/BALANCE-REPORT.md`, finding 1).

## Loose ends that are not blocked on the arena

- **Three more pets.** The egg holds 8 and 5 are modelled. `docs/PETS-DROWNED.md`
  designs 12; the gap is two of the three Commons (Dock Otter, Reed Duck, Foam
  Pup) and the Toll Prince, the baby Tollcrab sharing the Legendary slot.
- **The egg itself.** No `Config/Eggs` entry and no hatch art (whole, crack1,
  crack2, burst) — a Codex job.
- **The weapons' pixel icons**, running overnight 2026-11-04.
- **There is no Uncommon bow.** Fourteen weapons against fifteen slots, and it
  is a real gap in the set rather than a missing sheet
  (`docs/WEAPONS-DROWNED.md`).
- **None of the five pets plays an animation.** They came out of Tripo as single
  static meshes with no clips, which is also why the Abyss Jelly's sting could
  not be the trailing ring a jellyfish wants. Rigged models would fix all five
  at once.
