# The Windswept Cliffs (area 5): the design, and what is built

Asked 2026-11-26 ("keep working on the rest in the still to build section"):
build area 5 as a full playable area, the way areas 3 and 4 were. This is the
one place its state is written down, as `DROWNED-VILLAGE.md` is for area 3.

**Owner's answers (2026-11-26):** edges are falls at 12%; the roster below
as written; the spend (about 1,345 Tripo credits, one audio upload, Fable
5.2 for the Tempest Roc and the Zephyr Whale); Claude downloads the GLBs and
does the Studio imports with computer use.

**Where it stands:** designed (this file). Nothing is built yet. It ships in
six stages, each its own PR: enemies, boss, arena, pets and egg, weapons,
levels and portal (with the story beat). Area 6 (Frostpeak Pass) starts after
it, because both touch `Balance`, `Lobby`, `Shop`, `Eggs` and `Economy`.

Sources: `WORLD.md` row 5 (Act 3, The Heights: narrow paths, knockback),
`ENEMIES-AND-ARENAS.md` §5, `BOSSES.md` §5, `PETS-WILFS.md` #5, `STORY.md`.

## The look

Grey-blue slate cliff tops floating in a sea of white cloud, short bright
grass on the rims, glowing pale-blue wind streaks across the stone, rope and
plank bridges, and strings of bright prayer flags (red, yellow, green, blue)
on stone posts. Sky blue, cloud white and slate grey, with navy, gold and a
lightning yellow from the Tempest Roc. References:

| What | Reference |
|---|---|
| Arena (Twin Peaks: two plateaus and a bridge) | `assets/concepts/blocky/arenas/area05_windswept_cliffs.jpg` |
| Enemies (blocky line-up) | `assets/concepts/blocky/act3_enemies.jpg` (harpy, gust shaman, cliff goat are the first three); detail sheets `assets/concepts/enemies/act3/{harpy,gust_shaman,cliff_goat,storm_roc}.jpg` |
| Boss | `assets/concepts/blocky/boss07_tempest_roc.jpg` |
| Gale Wilf | `assets/concepts/pets/wilfs/05_gale_wilf.png`, built as a recolour of the Glowcap Wilf sheet |

Every model but the weapons is built in Claude Design with the
`voxel-pet-design-prompts` skill, from a Codex reference picture, until it
matches front, side and 3/4. Weapons are Tripo (Polycount 4,000, 8K), the
Gale Wilf is Tripo from a Codex recolour of the Glowcap Wilf.

## The edges (the area's one new rule)

The rooms are cliff tops: the walls are drops. **Walking never takes you
off** (the edge is a wall to feet, as every room's is), but **a push can**:
a Gust Shaman's shot, a Cliff Goat's charge or the Roc's gust that carries a
player over an edge drops them. A fall costs **12% of max health**, puts the
player back on the nearest floor inside the edge, and gives 1 s without being
hit. Enemies are never pushed off (a Wind Arrows build would empty rooms).
The edge glows pale blue under a player standing within 3 studs of it, so the
danger is seen before it is felt.

## Enemies

Area 5's numbers sit a step past Bogheart's. Stage multipliers climb from
**2.12 / 1.16** (health / damage) at 5-1 to **2.35 / 1.20** at 5-15
(area 4: 1.87 / 1.11 to 2.1 / 1.15).

| Enemy | Made from | Health | Hit | What it does |
|---|---|---|---|---|
| **Harpy** | New: flyer | 280 | 60 | A purple-and-navy owl-faced harpy with a bone-white mask. Flies at 9 studs high, **over walls and gaps**, so cover does not stop it. Every 2.6 s it marks a ring (3 studs) on the player's spot, hangs 0.7 s, then dives on it and climbs back. Hittable all the time (arrows and orbs aim at its body). |
| **Gust Shaman** | Lancer, twist | 380 | 50 | A hooded ram-horned shaman with a crook topped by a pale-blue wind spiral. Draws a line (0.8 s), then fires one fast gust down it; the gust **pushes the player 7 studs** along the line as well as hurting. Keeps 18 studs off. |
| **Cliff Goat** | Charger, twist | 700 | 78 | A cream woolly goat with big curled brown horns, a red collar and a bell. Paws the ground (0.6 s, a lane drawn ahead), then charges down the lane; a hit **knocks the player 10 studs**. Stops at cover and shakes its head (1 s, its punish window). |
| *Elite:* **Storm Roc** | Harpy, big | 2,400 | 70 | A navy storm bird with glowing blue wing edges. Dives as the Harpy does, and as it climbs drops a **fan of five feathers** (spread 70°) that fly outward. The last room of every fifth level (5-5, 5-10) and the boss's summons. |

All four flash white and are knocked back when hit (the flyers drift back
in the air). Each gets its NEW ENEMY! card and Dex entry.

**Flyer** is the new behaviour: an enemy whose path ignores cover and room
gaps, drawn at a height with a shadow on the floor under it, and whose
contact hit only lands at the bottom of a dive. It is shared later with the
Ember Mines' Ember Bat.

## The boss: the Tempest Roc

*A giant storm bird with lightning on its wingtips* (`BOSSES.md` §5). Navy
and cream feathers, gold crest, gold talons, yellow-lightning wingtips.
Alone in the last room of 5-15. **Health 8,200** (Gulp's 6,800, a step up),
and the owner's kept last-room ramp applies as it does to the others.

**Phase 1 — Dive (100% to 50%).** Its loop:
- **Dive Line** (`dive`): rises, a lane as wide as its wings (7 studs) is
  drawn across the whole room through the player, 1.1 s, then it crosses the
  room down it and lands at the far end. 160 on a hit, and a 6-stud shove
  sideways out of the lane. It stands 2 s where it lands: the punish window.
- **Wing Gust** (`gust`): plants its feet and beats its wings: a 70° cone,
  22 studs long, marked 0.9 s, then pushes everyone in it **12 studs** away
  from it for 1.2 s (walking against it is slowed, not stopped). No damage of
  its own: the edge does the damage. Used right after a dive, when it is
  nearest a wall.
- **Talon Swipe** (`swipe`): if the player is within 8 studs, a short 120°
  arc in front of it, 0.6 s tell, 120.

**Phase 2 — Storm (below 50%).** It screams, climbs and circles overhead:
**out of reach** (no hits land) for 6 s at a time. While up there,
**Lightning** (`storm`) strikes marked circles (4 studs, 1 s warning, 140)
in a pattern: a line of five towards the player, then a ring of six round
them, then three on them in a row. Then it dives (a Dive Line) and lands for
3 s, the only time it can be hit in this phase, then gusts and goes up again.
At half and at a quarter it calls **two Harpies**.

*Teaches:* knockback near edges. *Class notes:* the Ranger hits it between
dives; the Warden waits for its landing after each dive; the Assassin dashes
through the lane's edge to reach it.

Its sounds: a scream (phase change and the climb), wing beats (gust),
thunder (each strike). The boss item is the **TEMPEST FEATHER** (key
`StormFeather`), with a banner and icon in `Config/BossBanners`.

## The pets (8)

Eight, per the owner's rule: two Commons, one Uncommon, one Rare, one Epic,
two Legendaries (the Gale Wilf and the boss heir) and one Mythic. No earlier
animal repeats (no goat or ram either: that is the Cliff Goat).

Damage sits on area 5's bands (1.5x area 1's: Common 24, Rare 36, Epic 51,
Legendary 66, Mythic 84 a second against a room; `Util/PetPower`). The area
is about position, so most of the attacks are about it too: none repeats an
earlier area's kind (no slow, burn, bleed, root, mark, heal, guard, shelter,
beam, ring, dash, volley, summons, revive, decoy, trap, execute, blind,
cone, pool coat, farthest-target, counted fourth hit, delayed mote, crowd
slam, densest leap or split shards).

| # | Pet | Rarity | Look | Attack |
|---|---|---|---|---|
| 1 | **Whistle Marmot** | Common | a chunky golden-brown cube marmot standing up on its back legs, cream belly, two square buck teeth, a little red prayer-flag scarf | **Alarm Whistle**: every 3 s whistles at the enemy **nearest its owner** (not nearest itself) for 72. 24/s |
| 2 | **Cliff Puffin** | Common | a round black-and-white cube puffin with a big striped orange-red-yellow beak and orange feet | **Pebble Drop**: every 2.5 s flies up and drops a pebble on the nearest enemy for 48; **double on an enemy in the air** (Harpies, the Storm Roc, and anything knocked back that moment). 24/s on the ground |
| 3 | **Woolly Alpaca** | Uncommon | a cloud-white fluffy cube alpaca with a long neck, a woven blanket in prayer-flag stripes and a tuft of wool on its head | **Wool Wall**: every 12 s plants itself between its owner and the nearest enemy and puffs up for 3 s: enemy shots that reach it are stopped. No damage of its own (the egg's shelter pet: a wall, not a coat) |
| 4 | **Gale Glider** | Rare | a pale-grey and sky-blue flying squirrel with square gliding flaps between its legs and big round eyes | **Updraft**: every 4 s glides through the enemy nearest it and on for 10 studs, hitting each enemy it passes for 108 and **lifting** it (0.6 s, it cannot move or attack). 36/s on one |
| 5 | **Flagtail Panda** | Epic | a ginger-and-cream red panda with a long ringed tail, white cheek patches and a string of tiny prayer flags round its neck | **Flag Spin**: every 3 s whirls its tail and flings three little flags in a **spiral** out from itself (one each 120°, turning as they go) for 52 each to whatever they cross. 51/s |
| 6 | **Gale Wilf** | Legendary | the Glowcap Wilf's shape in sky blue and cloud white, little white feather wings, a wind-swirl tail, flight goggles on its head; golden glow | **Glide** (`PETS-WILFS.md` #5): every 4 s spreads its wings and glides in a straight line through up to 3 enemies toward the nearest, 132 each, and lands where the last stood. 66/s on two |
| 7 | **Rocling** | Legendary | a round baby Tempest Roc: navy and cream fluff, a small gold crest, tiny gold-tipped wings, big yellow eyes and a crackle of yellow spark; golden glow | **Little Thunder** (heir to the Roc's storm): every 5 s marks the enemy with the most health and strikes it with lightning 0.6 s later for 330. 66/s |
| 8 | **Zephyr Whale** | Mythic | a majestic cloud-white and sky-blue whale floating in the air, long pectoral fins like wings, glowing pale-cyan rune stripes, ribbons of wind trailing from its tail, a little cloud halo; glows `MythicSky` (pale cyan, not rainbow) | **Tailwind**: every 3 s a broad gust from its tail **pushes every enemy within 12 studs of its owner 6 studs away** and hits each for 84. 84/s on one, more on a crowd |

The two Legendaries glow gold, the Mythic `MythicSky`. Every pet but the
Gale Wilf is a Claude Design model (one GLB each, Merge Meshes off, clips in
the GLB); the Wilf is one Tripo mesh moved by `pet_motions.json`.

**The Windswept Egg**: a slate-grey egg banded with prayer-flag colours, a
cloud-white wisp curling round it, its top two pieces turning opposite ways
(the egg rule). 10,000 coins, as the area's crate; at launch it waits on
Bogheart's boss.

## The weapons (20)

One a class at Uncommon, Rare, Epic, Legendary and Mythic, named from the
area's cast. Legendaries and Mythics glow; the Legendary costs coins plus the
Tempest Feather. Stats are `WeaponStats.areaScale[5] = 1.5`.

| Tier | Bow (Ranger) | Staff (Arcanist) | Blade (Warden) | Daggers (Assassin) |
|---|---|---|---|---|
| Uncommon | **Slatewood Bow**: grey slate-wood limbs, prayer-flag cloth wraps | **Cloudspun Staff**: pale birch shaft, a puff of cloud-white wool on top | **Ledgestone Blade**: slate-grey blade, rope-bound grip | **Flint Talons**: a short flint knife with a leather grip |
| Rare | **Harpy Bow**: purple feather limbs, a bone-white mask at the grip | **Gustcaller Staff**: the shaman's crook with a glowing pale-blue wind spiral | **Ramhorn Cleaver**: a broad blade curling like a goat's horn | **Harpy Claw**: a curved purple talon blade |
| Epic | **Galestring Longbow**: sky-blue limbs with glowing wind-swirl tips | **Prayerflag Staff**: a pole hung with bright flags round a glowing blue gem | **Windcutter Blade**: pale-blue blade with glowing wind slits | **Storm Quill**: a long navy feather-quill dagger with a glowing blue edge |
| Legendary | **Roc's Wing Bow**: navy-and-gold wing limbs, gold talon tips | **Tempest Staff**: navy shaft, gold talons gripping a glowing storm-cloud orb | **Stormtalon Blade**: navy blade, gold talon guard, lightning-yellow edge | **Thunderbeak Dagger**: a gold beak blade with a navy feather grip |
| Mythic | **Skyrender Bow**: limbs of glowing yellow lightning feathers, cloud-white grip | **Eye of the Storm**: a ring of navy feathers round a glowing cyclone core | **Thunderhead Blade**: a glowing storm-cloud greatsword crackling with yellow lightning, gold wing guard | **Zephyr Fang**: a glowing pale-cyan wind-crystal dagger with a gold feather guard |

| Weapon | Innate card | Its words |
|---|---|---|
| Roc's Wing Bow | Wind Arrows | Roc's wing: arrows knock enemies twice as far and blow their shots away. |
| Skyrender Bow | Phoenix Arrow | Skyrender: every 8th arrow is a thunderbird that tears through everything. |
| Tempest Staff | Arcane Shield | Tempest ward: a wall of wind blocks one hit, then comes back. |
| Eye of the Storm | Chain Lightning | Eye of the storm: every orb arcs on to two more. |
| Stormtalon Blade | Shield Throw | Stormtalon: your dash flings a talon that bounces between three enemies. |
| Thunderhead Blade | Blade Storm | Thunderhead: every fifth swing throws a thundercloud sword out and back. |
| Thunderbeak Dagger | Quickstep | Tailwind: a kill brings your dash back sooner. |
| Zephyr Fang | Fan of Knives | Zephyr: a fan of feathers flies with your strikes. |

Wind Arrows, Phoenix Arrow, Arcane Shield, Shield Throw and Quickstep are no
weapon's innate yet. Each dagger is drawn and modelled as **one** dagger.
The 2D art (Codex) is also each weapon's picture.

## Levels 5-1..5-15

`tools/area_levels.py`, as areas 3 and 4: rooms per level
10, 10, 10, 15, 15, 15, 15, 15, 20, 20, 20, 20, 20, 20, 25; every ninth room
of ten an Angel room; enemy counts from 3-5 rising to 5-8; one mix a level in
order; every level ends in the boss's arena without the boss, and only 5-15's
last room holds the Tempest Roc. Stages 60..74, behind the portal.

Three layouts from the sheet:
- **Cliffs Open** (`CliffsOpen`): one wide plateau, no cover (the owner's
  open-floor rule).
- **Twin Peaks** (`CliffsBridge`): two plateaus joined by the plank bridge,
  rocks and flag posts as cover on each.
- **Ledge Path** (`CliffsLedge`): a narrow walkway down the middle with
  drops each side, widening at both ends.

Mixes: Harpy / Harpy + Shaman / Goat + Harpy / Shaman + Goat / all three /
two of each with the Storm Roc in the heart of 5-5 and 5-10.

**Wind Tunnel** (from 5-6 on, one room in three): a gust crosses the room
one way every 8 s, shown by white streaks for 1.5 s first, pushing players
4 studs (not enemies' paths). Drawn with the wind streaks the floor already
has.

## Lobby, economy, story

- **Portal** `Windswept Cliffs`: `levels = stageRun(60, 15)`,
  `atLaunch = { boss = "BogheartCaverns" }`, sky-blue tint, a Design portal
  model with its own spinning `Vortex`.
- **Economy** `WindsweptCliffs`: 95 coins a kill, 2,500 a clear, the
  Tempest Feather, 170 gems the first boss win and 30 after. First clear
  gives a Windswept Egg.
- **Crate** `WINDSWEPT CLIFFS` (10,000, already listed) stocked at
  `atLaunch = "BogheartCaverns"`.
- **Story**: Bogheart's poster loses "To be continued..." for a line on why
  the Roc is there ("Its storms keep everyone off the cliffs."). Area 5's own
  beat (`b5a..b5d`, Codex stills): *The Tempest Roc crashes down and drops
  a Tempest Feather!* / *The storm clears, and the bridges stop swaying.* /
  *But the wind turns cold... snow is falling on the pass.* /
  *WANTED: RIMEHEART, THE YETI KING* (*To be continued...*).
- **Sounds**: one sprite for the area (harpy screech, wind gust, goat bleat
  and charge, Roc scream, thunder, edge fall): one audio upload.

## Build order and state

| Stage | PR | State |
|---|---|---|
| Enemies (Harpy, Gust Shaman, Cliff Goat, Storm Roc; flyer; push shots) | | not started |
| The Tempest Roc | | not started |
| Arena (kit, three layouts, edges, outer cliffs) | | not started |
| Pets and egg | | not started |
| Weapons | | not started |
| Levels, portal, economy, crate, story | | not started |
