# Enemies and arenas — first pass

Ideas for every area in `WORLD.md`, written to be built: each enemy says what
it is made from, and each arena what its hazard asks of the engine. A first
pass for the owner to cut, keep and rename — nothing here is settled or built.

Concept art for each act, generated with ChatGPT Codex, is in
`assets/concepts/` (see the table at the end).

**Bosses are in `BOSSES.md`** — one for every area, the act-enders as
three-phase set pieces.

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

Enemies belong to their arena: forest slimes and wolves, marsh frogs and
toads, mountain yetis and goats, forge imps and golems, castle knights and
ghosts — in the same Archero 2 toy style as the arenas (`ART-archero2.md`).

On top of that, a light touch of what makes Hollow Knight's and Silksong's
creatures memorable (owner, 2026-10-22: "take some inspiration but still
keep the arena theme" — an earlier all-insect pass went too far):

- **Bold, simple silhouettes** — one idea per creature, readable from our
  steep top-down camera on a phone.
- **Hollow, glowing eyes**, in each act's colour: amber in the Wilds, pale
  green in the Lowlands, white-blue in the Heights, ember orange in the
  Depths, violet at the End.
- **A small pale mask or face plate on *some* creatures** — the Glade Wolf's
  skull mask, the Corrupted Monk's hollow mask, the Void Wisp that is only a
  mask — not on all of them, so it stays a signature rather than a uniform.
- **The odd slender limb or little tattered cloak**, and a slightly wistful
  charm — never gory.

These are original designs; the prompts that made the concept art describe
the style without naming either game.

---

## Act 1 — The Wilds

Signature hazard: **choke points.** Brambles and rocks that narrow the room
— terrain that shapes the fight without hurting anyone, which is right for
the act that teaches the game.

### 1. Mossy Glade — tutorial forest · lean: Ranger (open)

| Enemy | Made from | What it does | Teaches |
|---|---|---|---|
| **Moss Slime** | Charger, slow · reskin | Hops straight at you | Move or shoot |
| **Sprout Slime** | Spitter · reskin | Lobs one slow seed | Dodging a shot |
| **Glade Wolf** | Charger, fast · twist: comes in packs of 3 that circle before lunging | Circles, then dashes in | Reading a lunge |
| *Elite:* **Mother Slime** | Bulwark · twist: splits into 2 Moss Slimes on death | A slow wall that becomes two threats | Finishing what you start |

**Arenas.** *Clearing* — open grass, two mossy stumps. *Fairy Ring* — a ring
of mushrooms (low cover) round an open centre. *Fallen Log* — one long log
across the middle with a gap at each end.

### 2. Thornwood — bramble choke points · lean: Warden (corridors)

| Enemy | Made from | What it does |
|---|---|---|
| **Thorn Spider** | Charger · twist: leaves a short sticky web patch where it dies (slows) | Fast skitter, web on death |
| **Web Spitter** | Spitter · twist: its orbs leave slow patches | Area denial |
| **Bramble Lurker** | Lurker · reskin (vine bulb) | Surfaces under you with a ring of thorns |
| *Elite:* **Broodmother** | Bulwark · twist: drops 2 Thorn Spiders every few seconds | Must be pushed through |

**Arenas.** *Bramble Maze* — brambles carve the room into lanes with gaps.
*The Funnel* — the room narrows to a single gap halfway up. *Briar Patch* —
scattered bramble clumps; touching one slows (a soft hazard).

### 3. Bandit Hollow — canyon camp · lean: Ranger (open) · act boss slot

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

---

## Act 2 — The Lowlands

Signature hazard: **poison and slow.** Pools that hurt to stand in and mud
that slows — the act where standing still in the wrong place costs you.

### 4. Sunken Marsh — poison pools · lean: Arcanist (crowded)

| Enemy | Made from | What it does |
|---|---|---|
| **Bog Frog** | **New: leaper** — jumps to a marked spot, lands with a splash ring | Telegraphed leaps |
| **Toxic Toad** | Spitter · twist: shots leave a poison puddle | Poisons the ground |
| **Swamp Lurker** | Lurker · reskin (eyes on stalks) | Pops up out of the water |
| *Elite:* **Croaking Chorus** | 4 Bog Frogs that leap together on a beat | Rhythm dodging |

**Arenas.** *Lily Pads* — the floor is water with pad "islands"; water is a
slow zone. *Poison Ring* — a poison pool in the middle, fight round its edge.
*Reed Rows* — rows of reeds give cover to shooters.

### 5. Drowned Village — ruins · lean: Warden (corridors)

| Enemy | Made from | What it does |
|---|---|---|
| **Drowned Zombie** | Charger, slow · twist: rises once more after death unless it burns | Slow, relentless |
| **Wisp Ghost** | **New: phaser** — drifts through walls and obstacles, fades in and out | Can't be hidden from |
| **Bell Ringer** | Lancer · twist: its shot is a sound wave cone, not a line | A wide telegraph |
| *Elite:* **Hollow Fisherman** | Bulwark · twist: hooks you toward it (pull) | Being pulled |

**Arenas.** *Flooded Street* — two rows of broken houses, a lane between.
*The Square* — a well in the middle, houses round the edge. *Rooftops* —
gaps between roofs are drops (void edges, a light preview of Act 5).

### 6. Bogheart Caverns — glowing fungus · lean: Arcanist (crowded) · act boss slot

| Enemy | Made from | What it does |
|---|---|---|
| **Spore Puff** | Charger · twist: bursts into a poison cloud when killed close | Kill it from range |
| **Glowcap** | **New: stationary** — a mushroom turret that sprays spores in a spiral | A rotating hazard |
| **Cave Crawler** | Lurker · reskin (blind cave worm) | Surfaces under you |
| **Shellback** | Bulwark · reskin (beetle) | The wall between you and the turrets |

**Arenas.** *Fungus Grove* — giant mushrooms as pillars; their caps glow.
*Underground Lake* — a lake splits the room; a bridge crosses it. *Spore
Vents* — vents puff poison on a timer (patterned hazard).

**Boss** — Grandmother Gulp (`BOSSES.md`).

---

## Act 3 — The Heights

Signature hazard: **knockback and ice.** Wind that pushes, ice that won't let
you stop — the act where your position is not fully yours.

### 7. Windswept Cliffs — narrow paths · lean: Ranger (open)

| Enemy | Made from | What it does |
|---|---|---|
| **Harpy** | **New: flyer** — crosses walls and gaps, dives at a marked spot | Threat from anywhere |
| **Gust Shaman** | Lancer · twist: shot knocks you back instead of only hurting | Positional danger |
| **Cliff Goat** | Charger · twist: charge knocks back hard | Don't stand near edges |
| *Elite:* **Storm Roc** | Harpy, big · drops feathers in a fan as it dives | — |

**Arenas.** *Ledge Path* — a narrow walkway with drops each side (void
edges). *Wind Tunnel* — gusts push everything one way on a cycle (shown by
streaks first). *Twin Peaks* — two plateaus joined by a bridge.

### 8. Frostpeak Pass — ice · lean: Warden (corridors)

| Enemy | Made from | What it does |
|---|---|---|
| **Yeti** | Bulwark · twist: throws a big snowball (slow, arcing, splash) | Heavy, slow |
| **Frost Golem** | Bulwark · twist: freezes the ground in a ring when it stomps | Makes ice |
| **Snow Sprite** | Spitter · twist: shots chill (slow you) | Speed drain |
| **Ice Lurker** | Lurker · reskin (crystal) | Surfaces under you |

**Arenas.** *Frozen Lake* — most of the floor is ice: you slide, you can't
stop dead (a movement change, the act's real test). *Icicle Gorge* — icicles
fall on marked spots on a timer. *Snowbound Pass* — snowdrifts as low cover.

### 9. Skyreach Monastery — patterned traps · lean: Arcanist (crowded) · act boss slot

| Enemy | Made from | What it does |
|---|---|---|
| **Corrupted Monk** | Charger · twist: a 3-hit combo, then pauses | Wait for the opening |
| **Chanting Acolyte** | Spitter · twist: fires in rotating spirals | Bullet patterns |
| **Lantern Spirit** | **New: phaser** (shared with Wisp Ghost) | — |
| **Bell Guardian** | Bulwark · twist: rings a shockwave ring every few seconds | Ring timing |

**Arenas.** *Prayer Hall* — rows of pillars. *Spike Floor* — floor tiles spike
up in a pattern (checkerboard, sweeping row) that the room shows a beat
ahead. *Rotating Blades* — two blades sweep round fixed posts.

**Boss** — the Thousand-Palm Abbot (`BOSSES.md`).

---

## Act 4 — The Depths

Signature hazard: **lava.** Cracks that erupt, floors that fall — the act
where the arena itself is the most dangerous enemy.

### 10. Ember Mines — lava cracks · lean: Warden (corridors)

| Enemy | Made from | What it does |
|---|---|---|
| **Fire Imp** | Charger, fast · twist: leaves a short fire trail | Don't follow its path |
| **Ember Bat** | **New: flyer** (shared with Harpy) | Swoops over the cracks |
| **Mine Cart Bomber** | **New: rider** — rides fixed rails, drops bombs | Rails are lanes to avoid |
| **Magma Lurker** | Lurker · reskin | Surfaces under you |

**Arenas.** *Mine Shafts* — narrow tunnels. *Lava Cracks* — glowing cracks
that erupt on a timer (warning glow first). *Collapsing Tunnel* — floor
sections crumble after you've stood on them for a moment.

### 11. Obsidian Forge — constructs and turrets · lean: Ranger (open)

| Enemy | Made from | What it does |
|---|---|---|
| **Dwarven Construct** | Bulwark · reskin (stone and brass) | The wall |
| **Forge Turret** | **New: stationary** (shared with Glowcap) — aimed bursts | Stationary threat |
| **Anvil Golem** | Charger, slow · twist: slam leaves a burning ring | Big telegraph |
| **Spark Drone** | Spitter · twist: hovers, sprays a short fan | Pressure |

**Arenas.** *Assembly Line* — conveyor belts move you (and enemies) along.
*Forge Floor* — open, with furnaces that vent fire on a timer. *Turret Gallery*
— turrets line the walls; cover in the middle.

### 12. Molten Core — rising lava · lean: Arcanist (crowded) · act boss slot

| Enemy | Made from | What it does |
|---|---|---|
| **Lava Slime** | Charger · twist: splits into 2 small lava slimes (Act 1's lesson, harder) | — |
| **Ember Mage** | Lancer · twist: fires three lines in a fan | Wider telegraph |
| **Obsidian Brute** | Bulwark · twist: immune from the front | Flank it |

**Arenas.** *Rising Lava* — the room's edges flood with lava over the fight,
shrinking the safe floor. *Basalt Islands* — islands over lava joined by
bridges. *The Crucible* — a ring round a lava pit.

**Boss** — Ignar, the Living Flame (`BOSSES.md`).

---

## Act 5 — The End

Signature hazard: **the void.** Gaps with no floor, teleports, gravity that
shifts — the act where the rules of the room change.

### 13. Shattered Kingdom — ruined castle · lean: Warden (corridors)

| Enemy | Made from | What it does |
|---|---|---|
| **Undead Knight** | Bulwark · twist: blocks from the front, lunges | Patience |
| **Skeleton Archer** | Lancer · reskin | — |
| **Banshee** | **New: phaser** (shared) · twist: shriek cone slows | — |
| **Gargoyle** | **New: perch** — a statue (untargetable) until you come near | Ambush |

**Arenas.** *Throne Hall* — pillars and a long carpet. *Broken Battlements* —
wall walk with gaps (void edges). *Courtyard of Statues* — gargoyle statues
everywhere; some wake.

### 14. Void Rift — floating platforms · lean: Ranger (open)

| Enemy | Made from | What it does |
|---|---|---|
| **Void Wisp** | **New: blinker** — teleports to a marked spot near you, then fires | Watch the mark |
| **Rift Stalker** | Charger · twist: blinks the last few studs of its charge | Late dodge |
| **Gravity Orb** | **New: stationary** · pulls you toward it | Fight the pull |
| *Elite:* **Echo** | A copy of the player's own class, weaker | Fight yourself |

**Arenas.** *Floating Isles* — platforms over the void joined by bridges
(void edges everywhere). *Gravity Well* — a pull toward the centre on a
cycle. *Shifting Platforms* — platforms that blink out on a pattern.

### 15. The Hollow Throne — final arena · lean: all · final boss slot

Mixes one hazard from each act: a bramble choke, a poison ring, a wind gust,
lava cracks and void edges, cycled through the fight. **Boss** — the Hollow
Crown (`BOSSES.md`).

---

## What this asks the engine for

Built once, used across many areas — in the order they first appear:

| System | First area | Reused in |
|---|---|---|
| Slow zones (webs, mud, water, chill) | 2 | 4, 8, 13 |
| Ground hazards that hurt (poison, fire trails, lava) | 4 | 6, 10, 11, 12 |
| Split on death | 1 | 12 |
| **Leaper** enemy | 4 | — |
| **Phaser** enemy (through walls) | 5 | 9, 13 |
| **Stationary** enemy (turrets, totems) | 6 | 11, 14 |
| **Flyer** enemy (over walls and gaps) | 7 | 10 |
| Knockback / pull on the player | 5 | 7, 14 |
| Timed patterned hazards (vents, spikes, eruptions) | 6 | 9, 10, 11 |
| Void edges (no floor) | 5 | 7, 13, 14 |
| Ice movement (sliding) | 8 | — |
| Rising / shrinking floor | 12 | 15 |
| Teleport (**blinker**) | 14 | — |

Seven new enemy behaviours — leaper, phaser, stationary, flyer, rider,
perch and blinker — and the rest is reskins and twists of the five types we
have.

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
