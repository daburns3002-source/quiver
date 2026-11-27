# Pets — Bogheart Caverns (Act 2, area 4)

**Approved by the owner 2026-11-06; pictures in `assets/concepts/blocky/pets/bogheart/` (Mythic options picked: A, daggers B).** Drafted
2026-11-06 because the owner asked for Bogheart's pets, weapons and enemies as Tripo models,
and no Bogheart pets had been designed. Same pool shape, rarity ladder and blocky style as
`PETS-DROWNED.md`. Once approved, each pet goes through the Tripo route (a Codex front view,
then image-to-3D; see memory `tripo-for-models`).

**Look.** Dark cavern stone, deep purple bog water, moss and lime lichen, glowing cyan and teal
mushroom caps, pink spore puffs, poison-green vent smoke and a still underground lake. Colours
come from `assets/concepts/blocky/arenas/area04_bogheart_caverns.jpg` and the act-2 enemy
sheets (Spore Puff, Glowcap, Shellback). Grandmother Gulp adds purple-and-lime toad skin, gold
spectacles and cream belly.

No earlier animal is repeated (see the list in `PETS-DROWNED.md`), so: no mushroom pet, no frog
except the boss heir, no beetle, bat, snail, firefly, turtle, axolotl or slime.

| # | Pet | Rarity | Look | Ties to the area |
|---|---|---|---|---|
| 1 | **Cave Cricket** | Common | a chunky stone-grey cube cricket with long slab legs folded high, two wedge antennae and a lime belly | chirps in the cavern dark |
| 2 | **Lichen Gecko** | Common | a moss-green cube gecko with lime lichen patches, round toe pads and a big cube head | clings to the damp cave walls |
| 3 | **Bog Beaver** | Uncommon | a deep-brown cube beaver with a flat paddle tail, buck-tooth square and a little reed satchel (its accessory) | dams the bog channels |
| 4 | **Lanternfin** | Rare | a round purple cave anglerfish paddling just above the ground, with one glowing cyan lure on a stalk | the underground lake's only light |
| 5 | **Olm** | Epic | a pale pink-white blind cave salamander, long box body, four tiny legs, glowing cyan side markings | the lake's ancient blind dweller |
| 6 | **Glowcap Wilf** | Legendary | the Wilf family shape in bog purple and moss, a longer sock on its front-right leg like every Wilf, glowing cyan mushroom caps along its back; golden aura and sparkles | the area's Wilf (`PETS-WILFS.md`, #4), spore-sneeze pose |
| 7 | **Gulpling** | Legendary | a cute baby purple-and-lime toad with big yellow eyes, tiny gold round spectacles and one glowing cyan mushroom on its head; golden aura | heir to Grandmother Gulp |
| 8 | **Prism Leviathan** | Mythic | a majestic floating sea-serpent coiled in an S, dark-teal crystal box segments with glowing cyan cores, a crown of crystal fin spikes, a halo ring behind its head and glowing lake-water ribbons | the legend of the underground lake |

Eight pets, per the owner's rule of 8 per area (2026-11-06): two Commons, one Uncommon, one
Rare, one Epic, two Legendaries (Wilf and boss heir) and one Mythic. Cut from the first draft:
Peat Pangolin, Moss Sloth, Spore Moth and Gloom Ray. Every Legendary glows gold and the Mythic glows too (memory
`legendary-mythic-glow`).

## Attacks

Built 2026-11-06 (`Config/PetCombat`, `Config/PetAttacks`), one behaviour each.
**Placeholder numbers until the owner plays them**: area 4's enemies are not
built. Damage sits on area 4's bands, one step above area 3's (1.375x area 1's:
Common 22, Rare 33, Epic 47, Legendary 61, Mythic 77 a second against a room;
`Util/PetPower`, held by `tests/PetPower.spec`). Bogheart leans crowded
(`ENEMIES-AND-ARENAS.md`), so five of the eight answer a pack rather than one
enemy; every targeting rule lives in `Util/PetCrowd` (`tests/PetCrowd.spec`).

| Pet | Rarity | Role | Attack |
|---|---|---|---|
| Cave Cricket | Common | Shoots | **Long Chirp**: every 2.5 s leaps and chirps at the *furthest* enemy within 60 studs for 55 -- the one the player is least likely to be dealing with. 22/s |
| Lichen Gecko | Common | Shoots | **Fourth Lick**: every 2 s skitters in and licks the nearest enemy within 16 studs for 30; every fourth lick (counted, never rolled) hits for triple, 90. 22.5/s |
| Bog Beaver | Uncommon | Shelters | **Mud Plaster**: every 15 s slaps a mud coat on its owner that soaks 60 damage in all, for up to 6 s (`Util/MudCoat`). Small hits vanish into it; a big one breaks through with what the mud could not hold. No damage of its own |
| Lanternfin | Rare | Shoots | **Glow Mote**: every 4 s its lure sticks a glowing mote on the nearest enemy; 1.5 s later it bursts for 66 on that enemy and everything within 6 studs of where it has walked (or where it fell). 33/s |
| Olm | Epic | Shoots | **Tremor Snap**: every 3 s, blind, it feels the crowd and slaps the ground under the nearest enemy for 94, a quarter harder for each other enemy within 8 studs of it, up to double (188). 47/s |
| Glowcap Wilf | Legendary | Shoots | **Spore Sneeze** (`PETS-WILFS.md` #4): every 4 s a 60-degree wedge of spores, 16 studs long, toward the nearest enemy; 121 to everything in it. 60.5/s |
| Gulpling | Legendary | Shoots | **Little Belly Flop** (heir to Grandmother Gulp's Belly Flop): every 5 s leaps onto the enemy with the most others round it, within 60 studs, and hits everything within 7 studs of the landing for 151. 60.4/s |
| Prism Leviathan | Mythic | Shoots | **Prism Split**: every 3 s a crystal bolt at the nearest enemy for 116 that shatters as it lands into three shards of 58 on the three nearest others within 12 studs. 77.3/s |

None repeats areas 1-3: no slow, burn, bleed, root, mark, heal, guard,
shelter cut, beam, ring, dash, homing volley, summons, revive, first-hit
bonus, decoy, double splash, cleanse, payback, trap, execute, blind, wake,
canopy or tentacle flurry. The coat is the egg's shelter pet, kept apart
from the other two kinds on purpose: the Snail's shell eats one whole hit,
the Turtle's shelter takes a share off every hit, and the coat is a pool.
The Cricket's and the Gulpling's pieces aim where the server hits
(`aim = "Farthest" / "Densest"` in `Config/PetAttacks`).

The Glowcap Wilf and the Gulpling glow Legendary gold; the Prism Leviathan
glows `MythicLake`, a crystal cyan and teal that is not rainbow (CLAUDE.md
rule 12, owner 2026-11-06).

### Motions

Each pet is one static Tripo mesh, so `assets/models/pet_motions.json` moves
the whole body (`tools/pet_motions.py` → `Config/ModelClips/<Pet>`), sized
from each GLB's bounds to about a stud: the cricket springs and leaps, the
gecko wiggles and darts, the beaver waddles and rears to slap, the Lanternfin
and the Leviathan float and swim off the ground, the olm slithers and rears,
the Wilf trots and sneezes (two sniffs, then the throw), the Gulpling hops and
belly-flops. Each Attack's peak is timed to its piece's `at`.

### Effect pieces

**Built 2026-11-26** (checklist item `bd-petfx`). Until then every piece was
an earlier area's standing in. Codex drew the sheet
`assets/concepts/pets/attacks/bogheart_pieces.png` (prompt `_prompt_bogheart.txt`,
from the eight pets' pictures). Claude Design then built all ten as one page with
a button per piece (project "Bogheart Caverns Pet Attack Pieces",
`claude.ai/design/p/a45e0d8a-f70b-4d22-8eb5-c7ae87994aa0`, prompt `_design_bogheart.txt`).
Each was exported as a GLB at game size (1 unit = 1 stud, front toward +Z), kept
in `assets/models/effects/source/` and slimmed by `optimise_effect.py` into
`assets/models/effects/fx_pet_*.glb`. Its clip went into `Config/ModelClips`,
its import into `Config/ImportedModels`, and its name into `Config/PetAttacks`.

| Piece | Pet | Model, clip | What it is | Replaced |
|---|---|---|---|---|
| **Chirp Ring** | Cave Cricket | `FxPetChirpRing`, Fly (loop) | a 1.2-stud ring of lime cubes round a stone-grey rim, spinning in flight | `FxPetFeatherDart` |
| **Lichen Lick** | Lichen Gecko | `FxPetLichenLick`, Lash | a moss-green tongue out to 4 studs with a fat lime tip | `FxPetTongueLash` (no `flip` now) |
| **Mud Coat** | Bog Beaver | `FxPetMudCoat`, Play (6 s) | brown mud slabs round the owner's feet, open in the middle, reed stalks, crumbling in its last second | `FxPetHowlAura` |
| **Glow Mote** | Lanternfin | `FxPetGlowMote`, Spin (loop) | a glowing cyan cube in four halo slabs, riding the enemy | `FxPetLureMark` |
| **Mote Burst** | Lanternfin | `FxPetMoteBurst`, Play | a flash and a ring of cyan tiles to 6 studs out | `FxPetCrownShockwave` |
| **Tremor Ripple** | Olm | `FxPetTremorRipple`, Play | square ripples of pale stone tiles with cyan cracks, 8 studs across | `FxPetCrownShockwave` |
| **Spore Sneeze** | Glowcap Wilf | `FxPetSporeSneeze`, Sneeze | the whole 60-degree, 16-stud wedge of pink and glowing cyan spore cubes with gold sparkles (so no `sweep`) | `FxPetLeafSlash` |
| **Flop Splash** | Gulpling | `FxPetFlopSplash`, Play | a ring of purple bog-water blocks with lime tips, 7 studs out | `FxPetCrownShockwave` |
| **Prism Bolt** | Prism Leviathan | `FxPetPrismBolt`, Fly (loop) | a 2.4-stud dark-teal crystal shard with a glowing cyan core and trail | `FxPetEmberBolt` |
| **Prism Shards** | Prism Leviathan | `FxPetPrismShards`, Play | the bolt's impact: a flash and teal and cyan crystal cubes flying out | `FxPetCrownShockwave` |

Two exports came out over the 40-part cap phones are held to
(`Balance.UpgradeFx.maxParts`, `tests/UpgradeFx.spec`): the Spore Sneeze (86, one
part per spore) and Thornwood's Briar Cage (62). `optimise_effect.py`'s new
`still_children` option merges each animated group's children into it, so a
spore band (near, mid, far) or a cage post moves as one piece: 9 and 30 parts.
