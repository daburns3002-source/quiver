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

## The outer arena: the kit pieces

Owner, 2026-11-03: *"i have the arena made, but i need the outer arena made.
give me the kit pieces for the outer arena."*

The outer arena is the scenery past the room's walls, the way the glade has its
outer forest and Thornwood its outer wood (`docs/PIPELINES.md` §5.5). The
principle Thornwood settled is that it is **the room continuing outward** --
built from the room's own pieces, in the room's own colours and light -- so
every piece below is taken from `area03_drowned_village.jpg`. Past the walls
the village keeps going, deeper under the flood.

Two sheets drive it, and both prompts are written and waiting on Codex's usage
reset (`..._ambience_prompt_master.txt`, `..._ambience_prompt_kit.txt` beside
the concept sheet):

**The big pieces** -- the silhouette of the flooded village.

| Piece | What it is |
|---|---|
| **Drowned bell tower** | Pale-grey stone, leaning, slate-blue cap, a bronze bell in an open arch near the top, algae round its base. The tallest thing in the frame, and the Bell Ringer's home. |
| **Sunken house** | The room's own timber frame and slate-blue roof, tilted, cut off at the eaves as if the rest is under, a green algae band along the cut. |
| **Roof ridge alone** | Just the roof peak and its ridge beam -- the smallest a drowned house gets, for the deep water. |
| **Toll gate** | A grey stone arch, a timber bar across it, a lit lantern on the post, on a cobble causeway that runs out of the water and stops. The Old Tollcrab's toll, seen before you fight it. |
| **Dead drowned tree** | A bare grey-brown forked trunk, no leaves, rope and a net panel snagged in the fork. |

**Water dressing** -- what fills the space between them.

Reed bed (three reed heights on a shallow base) · swamped rowboat with an oar ·
net on two poles with cork floats · slatted crab pot · mossy rock cluster with
an algae waterline · drifting debris raft of planks, a barrel and a crate ·
leaning lantern post, still lit · the cobble causeway tile.

**The moving ambience** -- the pieces `Fx/ForestAmbience` will drive.

Water glint (a flat pale-cyan slab) · ripple (a flat turquoise ring) · bubble ·
gull · dragonfly · mist slab · light shaft. The glade's leaves and fireflies and
Thornwood's pollen and crows have no place here; the water does the moving.

**Swatches:** shallow turquoise, deep flood teal, grey cobble, pale grey stone,
timber brown, dark plank brown, slate-blue roof, reed green, algae green, cream
rope, bronze bell, lantern orange, mist white.

Two things the outer arena is doing besides looking right: the bell tower and
the toll gate put the Bell Ringer and the Old Tollcrab in front of the player
before either is fought, which is the only foreshadowing the area has.

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
- **The five pets move now, as far as one mesh can.** They came out of Tripo as
  single static meshes with no clips, so until 2026-11-04 they stood dead still.
  `tools/pet_motions.py` generates `Config/ModelClips` for all five from a
  hand-authored spec (`assets/models/pet_motions.json`): the jelly pulses its
  bell, the puffer swells, the Inkpot recoils and spits, the turtle hunkers
  under its shell, the Tide Wilf lunges. Each pet is still ONE part, so the
  whole animal moves together and no fin, limb or tentacle moves alone -- a
  jointed Claude Design rebuild is still the real fix, and would replace that
  script with the GLB pipeline every other model uses.
- **Their attacks can be drawn now.** `tests/PetAttacks.spec` asks that an
  attacking pet has clips the preview can show, which is what blocked a
  `Config/PetAttacks` entry for the five. With clips in place the Abyss Jelly
  could finally get the trailing tentacle ring it wanted, and the other four
  their own pieces. Not done.
