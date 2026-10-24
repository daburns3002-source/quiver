# Enemies and arenas — first pass

Ideas for every area in `WORLD.md`, written to be built: each enemy says what
it is made from, and each arena what its hazard asks of the engine. A first
pass for the owner to cut, keep and rename — nothing here is settled or built.

Concept art for each act, generated with ChatGPT Codex, is in
`assets/concepts/` (see the table at the end).

**The art is blocky now** (owner, 2026-10-23: everything recreated in the
blocky Pet Simulator / Steal an Egg style of the pets). Every enemy, arena
and act page below has a blocky redraw at the same path under
`assets/concepts/blocky/` (as `.jpg`, in the same layout as the original).
The blocky set is the reference; the originals stay for comparison.

**Bosses are in `BOSSES.md`** — two per act, one ending each area; the
second closes its act.

---

## How to read this

**Cost of an enemy**

- **Reskin** — one of the five existing types (Charger, Spitter, Lancer,
  Bulwark, Lurker) with new art and numbers. Data only.
- **Twist** — an existing type plus one small new rule (splits on death,
  leaves a puddle, shoots twice). A pipeline stage or a flag, not a new AI.
- **New** — a behaviour the enemy code does not have yet (flying over walls,
  teleporting, being a turret). Each one is real work and is listed in the
  build list at the end.

**Class lean** — which class an area favours, per `WORLD.md`:
open arenas suit the **Ranger**, crowded rooms the **Arcanist**, tight
corridors the **Warden / Duelist**. Each act mixes all three so no class is
shut out of a whole act.

Every enemy keeps the house rules: a toy-like silhouette readable from
directly above on a phone, glowing eyes, and a telegraph before any hit.

---

## Design language — themed, with a touch of Hollow Knight

Enemies belong to their arena: forest slimes, wilfs and bramble boars,
marsh frogs, toads and eels, mountain yetis and goats, forge imps and golems,
castle knights — in the same Archero 2 toy style as the arenas
(`ART-archero2.md`). **No spiders in Act 1 and no ghost in Act 2** (owner,
2026-10-22): Thornwood's spiders became bramble creatures, and Drowned
Village's ghost an eel. Spiders appear in Act 1 only as the boss's own —
the Broodmother and the Thornlings she summons (`BOSSES.md`).

On top of that, a light touch of what makes Hollow Knight's and Silksong's
creatures memorable (owner, 2026-10-22: "take some inspiration but still
keep the arena theme" — an earlier all-insect pass went too far):

- **Bold, simple silhouettes** — one idea per creature, readable from our
  steep top-down camera on a phone.
- **Hollow, glowing eyes**, in each act's colour: amber in the Wilds, pale
  green in the Lowlands, white-blue in the Heights, ember orange in the
  Depths, violet at the End.
- **A small pale mask or face plate on *some* creatures** — the Corrupted
  Monk's hollow mask, the Void Wisp that is only a mask — not on all of them,
  so it stays a signature rather than a uniform.
- **The odd slender limb or little tattered cloak**, and a slightly wistful
  charm — never gory.

These are original designs; the prompts that made the concept art describe
the style without naming either game.

---

## Act 1 — The Wilds

Signature hazard: **choke points.** Brambles and rocks that narrow the room
— terrain that shapes the fight without hurting anyone, which is right for
the act that teaches the game.

### 1. Mossy Glade — tutorial forest · lean: Ranger (open) · boss: King Bloblin

| Enemy | Made from | What it does | Teaches |
|---|---|---|---|
| **Moss Slime** | Charger, slow · reskin | Hops straight at you | Move or shoot |
| **Sprout Slime** | Spitter · reskin | Lobs one slow seed | Dodging a shot |
| *Elite:* **Brood Slime** (built 2026-10-22) | Charger · twist: splits into 4 Moss Slimes (owner, like Zac) on death, thrown out like Zac's Cell Division | A slow wall that becomes four threats | Finishing what you start |

The **Glade Wilf** (a masked mossy wolf in packs of three) is **dropped**,
design and concept art both (owner, 2026-10-23). The Wilf the glade has in
the game is the Ember Wilf, which this does not touch.

**Arenas.** *Clearing* — open grass, two mossy stumps. *Fairy Ring* — a ring
of mushrooms (low cover) round an open centre. *Fallen Log* — one long log
across the middle with a gap at each end.

### 2. Thornwood — bramble choke points · lean: Warden (corridors) · act boss: the Broodmother

| Enemy | Made from | What it does |
|---|---|---|
| **Bramble Boar** | Charger · twist: leaves a short thorn patch where it dies (slows) | Fast charge, thorns on death |
| **Burr Thistle** | Spitter · twist: its sticky burrs leave slow patches | Area denial |
| **Bramble Lurker** | Lurker · reskin (vine bulb) | Surfaces under you with a ring of thorns |
| *Elite:* **Bramble Sow** | Bulwark · twist: drops 2 Bramble Boarlets every few seconds | Must be pushed through |

**Arenas.** *Bramble Maze* — brambles carve the room into lanes with gaps.
*The Funnel* — the room narrows to a single gap halfway up. *Briar Patch* —
scattered bramble clumps; touching one slows (a soft hazard).

---

## Act 2 — The Lowlands

Signature hazard: **poison and slow.** Pools that hurt to stand in and mud
that slows — the act where standing still in the wrong place costs you.

### 3. Drowned Village — ruins · lean: Warden (corridors) · boss: Old Tollcrab

| Enemy | Made from | What it does |
|---|---|---|
| **Drowned Zombie** | Charger, slow · twist: rises once more after death unless it burns | Slow, relentless |
| **Ditch Eel** | **New: phaser** — slides through the flooded ground, under walls and houses, and surfaces to bite | Can't be hidden from |
| **Bell Ringer** | Lancer · twist: its shot is a sound wave cone, not a line | A wide telegraph |
| *Elite:* **Hollow Fisherman** | Bulwark · twist: hooks you toward it (pull) | Being pulled |

**Arenas.** *Flooded Street* — two rows of broken houses, a lane between.
*The Square* — a well in the middle, houses round the edge. *Rooftops* —
gaps between roofs are drops (void edges, a light preview of Act 5).

### 4. Bogheart Caverns — glowing fungus · lean: Arcanist (crowded) · act boss: Grandmother Gulp

| Enemy | Made from | What it does |
|---|---|---|
| **Spore Puff** | Charger · twist: bursts into a poison cloud when killed close | Kill it from range |
| **Glowcap** | **New: stationary** — a mushroom turret that sprays spores in a spiral | A rotating hazard |
| **Cave Crawler** | Lurker · reskin (blind cave worm) | Surfaces under you |
| **Shellback** | Bulwark · reskin (beetle) | The wall between you and the turrets |

**Arenas.** *Fungus Grove* — giant mushrooms as pillars; their caps glow.
*Underground Lake* — a lake splits the room; a bridge crosses it. *Spore
Vents* — vents puff poison on a timer (patterned hazard).


---

## Act 3 — The Heights

Signature hazard: **knockback and ice.** Wind that pushes, ice that won't let
you stop — the act where your position is not fully yours.

### 5. Windswept Cliffs — narrow paths · lean: Ranger (open) · boss: the Tempest Roc

| Enemy | Made from | What it does |
|---|---|---|
| **Harpy** | **New: flyer** — crosses walls and gaps, dives at a marked spot | Threat from anywhere |
| **Gust Shaman** | Lancer · twist: shot knocks you back instead of only hurting | Positional danger |
| **Cliff Goat** | Charger · twist: charge knocks back hard | Don't stand near edges |
| *Elite:* **Storm Roc** | Harpy, big · drops feathers in a fan as it dives | — |

**Arenas.** *Ledge Path* — a narrow walkway with drops each side (void
edges). *Wind Tunnel* — gusts push everything one way on a cycle (shown by
streaks first). *Twin Peaks* — two plateaus joined by a bridge.

### 6. Frostpeak Pass — ice · lean: Warden (corridors) · act boss: Rimeheart

| Enemy | Made from | What it does |
|---|---|---|
| **Yeti** | Bulwark · twist: throws a big snowball (slow, arcing, splash) | Heavy, slow |
| **Frost Golem** | Bulwark · twist: freezes the ground in a ring when it stomps | Makes ice |
| **Snow Sprite** | Spitter · twist: shots chill (slow you) | Speed drain |
| **Ice Lurker** | Lurker · reskin (crystal) | Surfaces under you |

**Arenas.** *Frozen Lake* — most of the floor is ice: you slide, you can't
stop dead (a movement change, the act's real test). *Icicle Gorge* — icicles
fall on marked spots on a timer. *Snowbound Pass* — snowdrifts as low cover.

---

## Act 4 — The Depths

Signature hazard: **lava.** Cracks that erupt, floors that fall — the act
where the arena itself is the most dangerous enemy.

### 7. Ember Mines — lava cracks · lean: Warden (corridors) · boss: Cindertusk

| Enemy | Made from | What it does |
|---|---|---|
| **Fire Imp** | Charger, fast · twist: leaves a short fire trail | Don't follow its path |
| **Ember Bat** | **New: flyer** (shared with Harpy) | Swoops over the cracks |
| **Mine Cart Bomber** | **New: rider** — rides fixed rails, drops bombs | Rails are lanes to avoid |
| **Magma Lurker** | Lurker · reskin | Surfaces under you |

**Arenas.** *Mine Shafts* — narrow tunnels. *Lava Cracks* — glowing cracks
that erupt on a timer (warning glow first). *Collapsing Tunnel* — floor
sections crumble after you've stood on them for a moment.

### 8. Obsidian Forge — constructs and turrets · lean: Ranger (open) · act boss: the Forgewarden

| Enemy | Made from | What it does |
|---|---|---|
| **Dwarven Construct** | Bulwark · reskin (stone and brass) | The wall |
| **Forge Turret** | **New: stationary** (shared with Glowcap) — aimed bursts | Stationary threat |
| **Anvil Golem** | Charger, slow · twist: slam leaves a burning ring | Big telegraph |
| **Spark Drone** | Spitter · twist: hovers, sprays a short fan | Pressure |

**Arenas.** *Assembly Line* — conveyor belts move you (and enemies) along.
*Forge Floor* — open, with furnaces that vent fire on a timer. *Turret Gallery*
— turrets line the walls; cover in the middle.

---

## Act 5 — The End

Signature hazard: **the void.** Gaps with no floor, teleports, gravity that
shifts — the act where the rules of the room change.

### 9. Shattered Kingdom — ruined castle · lean: Warden (corridors) · boss: Sir Gravemourne

| Enemy | Made from | What it does |
|---|---|---|
| **Undead Knight** | Bulwark · twist: blocks from the front, lunges | Patience |
| **Skeleton Archer** | Lancer · reskin | — |
| **Banshee** | **New: phaser** (shared) · twist: shriek cone slows | — |
| **Gargoyle** | **New: perch** — a statue (untargetable) until you come near | Ambush |

**Arenas.** *Throne Hall* — pillars and a long carpet. *Broken Battlements* —
wall walk with gaps (void edges). *Courtyard of Statues* — gargoyle statues
everywhere; some wake.

### 10. Void Rift — floating platforms · lean: Ranger (open) · final boss: the Riftwalker

| Enemy | Made from | What it does |
|---|---|---|
| **Void Wisp** | **New: blinker** — teleports to a marked spot near you, then fires | Watch the mark |
| **Rift Stalker** | Charger · twist: blinks the last few studs of its charge | Late dodge |
| **Gravity Orb** | **New: stationary** · pulls you toward it | Fight the pull |
| *Elite:* **Echo** | A copy of the player's own class, weaker | Fight yourself |

**Arenas.** *Floating Isles* — platforms over the void joined by bridges
(void edges everywhere). *Gravity Well* — a pull toward the centre on a
cycle. *Shifting Platforms* — platforms that blink out on a pattern.

---

## What this asks the engine for

Built once, used across many areas — in the order they first appear (area
numbers after the cut to ten, 2026-10-22):

| System | First area | Reused in |
|---|---|---|
| Slow zones (thorns, burrs, chill, shrieks) | 2 | 6, 9 |
| Ground hazards that hurt (poison clouds, fire trails, lava) | 4 | 7, 8 |
| Split on death | 1 | — |
| **Leaper** (Grandmother Gulp's belly flop) | boss 4 | — |
| **Phaser** enemy (through walls) | 3 | 9 |
| **Stationary** enemy (turrets, totems) | 4 | 8, 10 |
| **Flyer** enemy (over walls and gaps) | 5 | 7 |
| Knockback / pull on the player | 3 | 5, 10 |
| Timed patterned hazards (vents, cracks, furnaces) | 4 | 7, 8 |
| Void edges (no floor) | 3 | 5, 9, 10 |
| Ice movement (sliding) | 6 | — |
| Rising floor (Gulp's flood) | boss 4 | — |
| Teleport (**blinker**) | 10 | — |

Seven new enemy behaviours — leaper, phaser, stationary, flyer, rider,
perch and blinker — and the rest is reskins and twists of the five types we
have.

---

## Cut areas (2026-10-22)

The owner set **two bosses per act**, and with them **two areas per act** —
ten in all, each ending in its boss. These five areas went with the bosses
that were cut; they are kept here, with their enemies and arenas, in case
any of it is wanted back or folded into another area.

### Cut — Bandit Hollow — canyon camp · lean: Ranger (open) · act boss slot

| Enemy | Made from | What it does |
|---|---|---|
| **Bandit Archer** | Lancer · reskin (hooded bandit, bow) | Telegraphed aimed shot |
| **Brute** | Bulwark · reskin (big club, wooden shield) | Blocks, swings when close |
| **Cutthroat** | Charger · twist: dashes in, strikes, then retreats | Hit-and-run |
| **Bomb Tosser** | Spitter · twist: one arcing bomb that bursts in a ring after a fuse | A delayed area |

**Arenas.** *Canyon Floor* — long open room, crates as cover. *Watchtowers* —
two raised platforms an archer stands on (it can only be reached by shots).
*Wagon Circle* — wagons ring the middle; the fight is around the outside.

**Boss** — Captain Redscarf (`BOSSES.md`).

### Cut — Sunken Marsh — poison pools · lean: Arcanist (crowded)

| Enemy | Made from | What it does |
|---|---|---|
| **Bog Frog** | **New: leaper** — jumps to a marked spot, lands with a splash ring | Telegraphed leaps |
| **Toxic Toad** | Spitter · twist: shots leave a poison puddle | Poisons the ground |
| **Swamp Lurker** | Lurker · reskin (eyes on stalks) | Pops up out of the water |
| *Elite:* **Croaking Chorus** | 4 Bog Frogs that leap together on a beat | Rhythm dodging |

**Arenas.** *Lily Pads* — the floor is water with pad "islands"; water is a
slow zone. *Poison Ring* — a poison pool in the middle, fight round its edge.
*Reed Rows* — rows of reeds give cover to shooters.

### Cut — Skyreach Monastery — patterned traps · lean: Arcanist (crowded) · act boss slot

| Enemy | Made from | What it does |
|---|---|---|
| **Corrupted Monk** | Charger · twist: a 3-hit combo, then pauses | Wait for the opening |
| **Chanting Acolyte** | Spitter · twist: fires in rotating spirals | Bullet patterns |
| **Lantern Spirit** | **New: phaser** (shared with Ditch Eel) | — |
| **Bell Guardian** | Bulwark · twist: rings a shockwave ring every few seconds | Ring timing |

**Arenas.** *Prayer Hall* — rows of pillars. *Spike Floor* — floor tiles spike
up in a pattern (checkerboard, sweeping row) that the room shows a beat
ahead. *Rotating Blades* — two blades sweep round fixed posts.

**Boss** — the Thousand-Palm Abbot (`BOSSES.md`).

### Cut — Molten Core — rising lava · lean: Arcanist (crowded) · act boss slot

| Enemy | Made from | What it does |
|---|---|---|
| **Lava Slime** | Charger · twist: splits into 2 small lava slimes (Act 1's lesson, harder) | — |
| **Ember Mage** | Lancer · twist: fires three lines in a fan | Wider telegraph |
| **Obsidian Brute** | Bulwark · twist: immune from the front | Flank it |

**Arenas.** *Rising Lava* — the room's edges flood with lava over the fight,
shrinking the safe floor. *Basalt Islands* — islands over lava joined by
bridges. *The Crucible* — a ring round a lava pit.

**Boss** — Ignar, the Living Flame (`BOSSES.md`).

### Cut — The Hollow Throne — final arena · lean: all · final boss slot

Mixes one hazard from each act: a bramble choke, a poison ring, a wind gust,
lava cracks and void edges, cycled through the fight. **Boss** — the Hollow
Crown (`BOSSES.md`).

---

## Concept art

Made with ChatGPT Codex (owner's choice for images and models), in the
Archero 2 toy style of `ART-archero2.md`. Each act has an enemy line-up —
redone 2026-10-22 with the design language above — and an arena sheet.

| Act | Enemies | Arena |
|---|---|---|
| 1 · The Wilds | `assets/concepts/act1_enemies.jpg` | `assets/concepts/act1_arena.jpg` |
| 2 · The Lowlands | `assets/concepts/act2_enemies.jpg` | `assets/concepts/act2_arena.jpg` |
| 3 · The Heights | `assets/concepts/act3_enemies.jpg` | `assets/concepts/act3_arena.jpg` |
| 4 · The Depths | `assets/concepts/act4_enemies.jpg` | `assets/concepts/act4_arena.jpg` |
| 5 · The End | `assets/concepts/act5_enemies.jpg` | `assets/concepts/act5_arena.jpg` |

All ten on one page: `assets/concepts/overview.jpg`. Generated as PNG and
saved as JPEG (85) to keep the repo light.

### Concept pages — for modelling

One page per enemy and per arena, made with ChatGPT Codex (2026-10-22), so
each can be built as a 3D model. An **enemy page** has a hero render, front,
side, back and top-down views (top-down is our camera), a face close-up and
colour swatches, with the eyes in the act's colour. An **arena page** has
the arena from the game camera, a top-down floor plan, its modular kit
pieces one by one, and material swatches.

**Enemies** — 54 pages. Pages marked *(cut area)* belong to areas cut in the
move to ten; they are kept in case those enemies come back.

- **Act 1** (`assets/concepts/enemies/act1/`, all on `act1_pages.jpg`): bandit_archer *(cut area)*, bomb_tosser *(cut area)*, bramble_boar, bramble_lurker, bramble_sow, brute *(cut area)*, burr_thistle, cutthroat *(cut area)*, moss_slime, mother_slime, sprout_slime
- **Act 2** (`assets/concepts/enemies/act2/`, all on `act2_pages.jpg`): bell_ringer, bog_frog *(cut area)*, cave_crawler, ditch_eel, drowned_zombie, glowcap, hollow_fisherman, shellback, spore_puff, swamp_lurker *(cut area)*, toxic_toad *(cut area)*
- **Act 3** (`assets/concepts/enemies/act3/`, all on `act3_pages.jpg`): bell_guardian *(cut area)*, chanting_acolyte *(cut area)*, cliff_goat, corrupted_monk *(cut area)*, frost_golem, gust_shaman, harpy, ice_lurker, lantern_spirit *(cut area)*, snow_sprite, storm_roc, yeti
- **Act 4** (`assets/concepts/enemies/act4/`, all on `act4_pages.jpg`): anvil_golem, dwarven_construct, ember_bat, ember_mage *(cut area)*, fire_imp, forge_turret, lava_slime *(cut area)*, magma_lurker, mine_cart_bomber, obsidian_brute *(cut area)*, spark_drone
- **Act 5** (`assets/concepts/enemies/act5/`, all on `act5_pages.jpg`): banshee, echo, gargoyle, gravity_orb, rift_stalker, skeleton_archer, undead_knight, void_wisp

**Arenas** — one page per area, `assets/concepts/arenas/`:
`area01_mossy_glade` · `area02_thornwood` · `area03_drowned_village` ·
`area04_bogheart_caverns` · `area05_windswept_cliffs` · `area06_frostpeak_pass` ·
`area07_ember_mines` · `area08_obsidian_forge` · `area09_shattered_kingdom` ·
`area10_void_rift`.

**New arena themes, not yet placed** (owner, 2026-10-22): a robot and
technology arena (`assets/concepts/arena_robot.jpg`), a heavenly one
(`arena_heaven.jpg`) and a space one (`arena_space.jpg`). Which acts or areas
they become is still open.

**Bosses** — pages are made one at a time once the owner has approved the
ten (`BOSSES.md`).
