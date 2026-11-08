# The Drowned Village (area 3): what is built and what it waits on

Owner, 2026-11-03: *"make sure drowned village is put together"*.

This is the one place the area's state is written down. It was spread across
three tracker rows, two pet docs, a weapons doc and `docs/BOSSES.md`, which is
why it kept looking more finished than it is.

**The short version (2026-11-05): the arena and its rooms are built; the area's
own enemies are next.** The owner's kit is in game (`Config/ArenaKits.Drowned`),
ten rooms are generated from the approved sheet (`tools/area34_rooms.py`), and
`Balance.drownedStage` (18) plays them. It is behind no portal yet, because
its rosters are stand-ins: the Hollow Fisherman among Thornwood's enemies.

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
| **The arena** | Built 2026-11-05 from the owner's kit (`assets/models/arenas/drowned_village_kit/`, bundled `--srgb`, imported) after `assets/concepts/blocky/arenas/area03_drowned_village_v2.png`: turquoise flood water (the sheet's own shades), a causeway of path tiles up the middle, the well at the centre, broken stone walls to the north and crate-and-barrel stacks to the south, three sunken houses set into each side wall with a lit lantern by each, reeds at the corners and wall feet, and the dock gate in both gaps (the exit's doors swing inside the north one). `Config/ArenaKits.Drowned`, `ArenaModels.DrownedVillage` / `DrownedOpen` / `DrownedBoss`, laid out by `Util/KitLayout`. |
| **The rooms** | Ten, from `tools/area34_rooms.py`: only the sheet's own cover at the sheet's own places, so every room matches it; rooms 1, 5 and 9 are the open floor (owner: "there should also be an open floor layout"), and the middle is never filled (the first sheet was "too cluttered there is no space to move"). The tenth is the Old Tollcrab's room with an elite fight until he is built. `Balance.drownedStage` (18), after Endless so no stage moved; behind no portal. |
| **Footsteps in the water** | `Fx/WaterSteps` (owner: "the footsteps in the shallow water need to be emphasized"): every stride of every player throws blocky droplets, flashes a foam disc and sends two ripple rings out. Three synthesised splashes (`assets/audio/water_step_synth.py`) are one sprite, `assets/audio/final/water_step_sprite.mp3`, **not uploaded yet** (1 of the day's 20), so the steps are silent until `WATER_SPRITE` in `Config/Sounds` has its id. |

## The outer arena: the kit pieces

**2026-11-05: the master is redrawn round the built room**
(`area03_drowned_village_ambience_v2.png`, `area03_outer_redraw.sh`; owner: "THE
OUTER ARENAS NEED TO ALSO BE BUILT FOR ARENA 3 AND 4"). The first master was
drawn round the cluttered first room; the flooded village outside is unchanged,
and the kit sheet still holds. Bogheart Caverns' pair is beside it
(`area04_bogheart_caverns_ambience.png`, `_ambience_kit.png`,
`area04_outer_sheets.sh`).

**Built 2026-11-05, both areas.** The owner approved the sheets. Claude Design
closes on December 14, so `assets/models/arenas/outer34_build.py` builds each
outer arena block by block in Python, after its sheet, in the room's frame
(hole and gate lanes checked). The owner imported both GLBs, and
`tools/forest_to_luau.py drowned|bogheart` wrote `Config/DrownedForest` (72
parts) and `Config/BogheartForest` (304), the areas' `ArenaModels` `parts`,
with `Balance.Ambience.Drowned` and `.Bogheart`. Two lessons from the first
imports: face winding must be counter-clockwise from outside (inside-out boxes
drew every top dark, with a grid of edges), and the Bogheart caps need a deep
cyan tint to read cyan rather than white under the outer glow.

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

1. ~~**The arena.**~~ Done 2026-11-05: the owner's kit, imported.
2. ~~**The kit, the rooms and the stages.**~~ Done 2026-11-05 (above). The
   stage is behind no portal until step 3 gives it its own enemies.
3. **Three enemy models** — Drowned Zombie, Ditch Eel, Bell Ringer. Their cards
   and pictures are already waiting for them. Then rosters, and the Hollow
   Fisherman comes off the bench.
4. ~~**The Old Tollcrab.**~~ Built 2026-11-07 and the portal opened (owner:
   "MAKE SURE ARENA 3 AND 4 ARE PLAYABLE"): `Balance.oldTollcrab`, Gulp's slam,
   lash and summon in his numbers, Hollow Fishermen at his thirds. Still new
   work: the ring that smashes through cover, and phase 2's paired rings.
5. **The boss item's name and icon.** `Config/Economy.DrownedVillage` is in (2026-11-07) with a placeholder item, TOLL BRONZE. Before that it had no entry at all, so
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
- **Their attacks are drawn.** All five have `Config/PetAttacks` entries
  (2026-11-04), timed to the clips above: the jelly's three stings on its three
  pulses plus a canopy mark under each of the three enemies it shares a blow
  among, the puffer's burst at the top of its swell, the Inkpot's squirt landing
  as a patch for the 3 s of its blind, the turtle's dome raised as it hunkers,
  the Tide Wilf's slash at the far end of its lunge. **Every effect is a Mossy
  Glade or Thornwood piece standing in**, as Thornwood's own pets did before
  they were redrawn — ink is not slime and a tentacle is not a tongue, so these
  are the first in line for art of their own. Nobody has watched them yet.
