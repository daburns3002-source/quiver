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

## Design language — an insect kingdom

The owner, 2026-10-22: keep the arenas, and "take inspiration from the enemy
design from Hollow Knight and Hollow Knight Silksong". So every enemy is an
**original** creature of an insect kingdom, built to the same rules those
games' bestiaries follow — not a copy of any of their characters:

- **Bugs, all of them.** Chitin shells, slender spindly legs, wings, horns,
  mandibles. The roles are unchanged — a Charger is still a Charger — only
  the body is new.
- **A pale mask.** Each creature wears a bone-white face plate with two big
  hollow eye sockets. From our steep top-down camera the mask is what a
  player sees first, so it carries the silhouette.
- **Eyes glow in the act's colour.** It keeps our readability rule (glowing
  eyes, nothing important dark) and ties each act together: amber in the
  Wilds, pale green in the Lowlands, cold white-blue in the Heights, ember
  orange in the Depths, void violet at the End.
- **One silhouette idea per creature.** A shield, a bell, a horn, a hood —
  the rest stays quiet, so a busy room on a phone still reads.
- **Muted bodies, bright danger.** Shells in dusty, desaturated tones;
  shots, telegraphs and the eyes carry the colour.
- **Charming, not grim.** Odd, a little sad, never gory — the kingdom has
  fallen, and its bugs carry on.

In game they become low-poly 3D models in the toy style the arenas use
(`ART-archero2.md`); the concept sheets are painted to settle the design.

| Act | Accent | New names (old role name) |
|---|---|---|
| 1 | amber | Mossgrub (Moss Slime) · Seedspitter (Sprout Slime) · Thicket Hound (Glade Wolf) · Broodbelly (Mother Slime) · Briar Skitter (Thorn Spider) · Silk Spinner (Web Spitter) · Root Lurker (Bramble Lurker) · Weaver Matron (Broodmother) · Mantis Archer (Bandit Archer) · Shellguard (Brute) · Needle Rogue (Cutthroat) · Spore Lobber (Bomb Tosser) |
| 2 | pale green | Mire Flea (Bog Frog) · Bloatfly (Toxic Toad) · Mire Leech (Swamp Lurker) · Flea Swarm (Croaking Chorus) · Sodden Shell (Drowned Zombie) · Lantern Moth (Wisp Ghost) · Bell Snail (Bell Ringer) · Angler Mantis (Hollow Fisherman) · Puffshroom Crawler (Spore Puff) · Glowcap · Blind Centipede (Cave Crawler) · Shellback |
| 3 | white-blue | Gale Moth (Harpy) · Chime Mantis (Gust Shaman) · Ram Beetle (Cliff Goat) · Thunder Moth (Storm Roc) · Frost Bulk (Yeti) · Rime Scarab (Frost Golem) · Frost Mite (Snow Sprite) · Crystal Tick (Ice Lurker) · Masked Pilgrim (Corrupted Monk) · Censer Acolyte (Chanting Acolyte) · Lantern Wisp (Lantern Spirit) · Bellkeeper Beetle (Bell Guardian) |
| 4 | ember orange | Ember Mite (Fire Imp) · Cinder Moth (Ember Bat) · Rail Weevil (Mine Cart Bomber) · Magma Grub (Magma Lurker) · Forge Shell (Dwarven Construct) · Mortar Snail (Forge Turret) · Anvil Rhino Beetle (Anvil Golem) · Spark Firefly (Spark Drone) · Magma Larva (Lava Slime) · Ember Mantis (Ember Mage) · Obsidian Stag (Obsidian Brute) |
| 5 | void violet | Lost Sentinel (Undead Knight) · Shade Archer (Skeleton Archer) · Wailing Moth (Banshee) · Stone Stag (Gargoyle) · Void Mote (Void Wisp) · Rift Mantis (Rift Stalker) · Gravity Orb · Echo |

---

## Act 1 — The Wilds

Signature hazard: **choke points.** Brambles and rocks that narrow the room
— terrain that shapes the fight without hurting anyone, which is right for
the act that teaches the game.

### 1. Mossy Glade — tutorial forest · lean: Ranger (open)

| Enemy | Made from | What it does | Teaches |
|---|---|---|---|
| **Mossgrub** | Charger, slow · reskin | Hops straight at you | Move or shoot |
| **Seedspitter** | Spitter · reskin | Lobs one slow seed | Dodging a shot |
| **Thicket Hound** | Charger, fast · twist: comes in packs of 3 that circle before lunging | Circles, then dashes in | Reading a lunge |
| *Elite:* **Broodbelly** | Bulwark · twist: bursts into 2 Mossgrubs on death | A slow wall that becomes two threats | Finishing what you start |

**Arenas.** *Clearing* — open grass, two mossy stumps. *Fairy Ring* — a ring
of mushrooms (low cover) round an open centre. *Fallen Log* — one long log
across the middle with a gap at each end.

### 2. Thornwood — bramble choke points · lean: Warden (corridors)

| Enemy | Made from | What it does |
|---|---|---|
| **Briar Skitter** | Charger · twist: leaves a short sticky web patch where it dies (slows) | Fast skitter, web on death |
| **Silk Spinner** | Spitter · twist: its orbs leave slow patches | Area denial |
| **Root Lurker** | Lurker · reskin (vine bulb) | Surfaces under you with a ring of thorns |
| *Elite:* **Weaver Matron** | Bulwark · twist: drops 2 Briar Skitters every few seconds | Must be pushed through |

**Arenas.** *Bramble Maze* — brambles carve the room into lanes with gaps.
*The Funnel* — the room narrows to a single gap halfway up. *Briar Patch* —
scattered bramble clumps; touching one slows (a soft hazard).

### 3. Bandit Hollow — canyon camp · lean: Ranger (open) · act boss slot

| Enemy | Made from | What it does |
|---|---|---|
| **Mantis Archer** | Lancer · reskin (hooded bandit, bow) | Telegraphed aimed shot |
| **Shellguard** | Bulwark · reskin (big club, wooden shield) | Blocks, swings when close |
| **Needle Rogue** | Charger · twist: dashes in, strikes, then retreats | Hit-and-run |
| **Spore Lobber** | Spitter · twist: one arcing bomb that bursts in a ring after a fuse | A delayed area |

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
| **Mire Flea** | **New: leaper** — jumps to a marked spot, lands with a splash ring | Telegraphed leaps |
| **Bloatfly** | Spitter · twist: shots leave a poison puddle | Poisons the ground |
| **Mire Leech** | Lurker · reskin (eyes on stalks) | Pops up out of the water |
| *Elite:* **Flea Swarm** | 4 Mire Fleas that leap together on a beat | Rhythm dodging |

**Arenas.** *Lily Pads* — the floor is water with pad "islands"; water is a
slow zone. *Poison Ring* — a poison pool in the middle, fight round its edge.
*Reed Rows* — rows of reeds give cover to shooters.

### 5. Drowned Village — ruins · lean: Warden (corridors)

| Enemy | Made from | What it does |
|---|---|---|
| **Sodden Shell** | Charger, slow · twist: rises once more after death unless it burns | Slow, relentless |
| **Lantern Moth** | **New: phaser** — drifts through walls and obstacles, fades in and out | Can't be hidden from |
| **Bell Snail** | Lancer · twist: its shot is a sound wave cone, not a line | A wide telegraph |
| *Elite:* **Angler Mantis** | Bulwark · twist: hooks you toward it (pull) | Being pulled |

**Arenas.** *Flooded Street* — two rows of broken houses, a lane between.
*The Square* — a well in the middle, houses round the edge. *Rooftops* —
gaps between roofs are drops (void edges, a light preview of Act 5).

### 6. Bogheart Caverns — glowing fungus · lean: Arcanist (crowded) · act boss slot

| Enemy | Made from | What it does |
|---|---|---|
| **Puffshroom Crawler** | Charger · twist: bursts into a poison cloud when killed close | Kill it from range |
| **Glowcap** | **New: stationary** — a mushroom turret that sprays spores in a spiral | A rotating hazard |
| **Blind Centipede** | Lurker · reskin (blind cave worm) | Surfaces under you |
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
| **Gale Moth** | **New: flyer** — crosses walls and gaps, dives at a marked spot | Threat from anywhere |
| **Chime Mantis** | Lancer · twist: shot knocks you back instead of only hurting | Positional danger |
| **Ram Beetle** | Charger · twist: charge knocks back hard | Don't stand near edges |
| *Elite:* **Thunder Moth** | Gale Moth, big · sheds scales in a fan as it dives | — |

**Arenas.** *Ledge Path* — a narrow walkway with drops each side (void
edges). *Wind Tunnel* — gusts push everything one way on a cycle (shown by
streaks first). *Twin Peaks* — two plateaus joined by a bridge.

### 8. Frostpeak Pass — ice · lean: Warden (corridors)

| Enemy | Made from | What it does |
|---|---|---|
| **Frost Bulk** | Bulwark · twist: throws a big snowball (slow, arcing, splash) | Heavy, slow |
| **Rime Scarab** | Bulwark · twist: freezes the ground in a ring when it stomps | Makes ice |
| **Frost Mite** | Spitter · twist: shots chill (slow you) | Speed drain |
| **Crystal Tick** | Lurker · reskin (crystal) | Surfaces under you |

**Arenas.** *Frozen Lake* — most of the floor is ice: you slide, you can't
stop dead (a movement change, the act's real test). *Icicle Gorge* — icicles
fall on marked spots on a timer. *Snowbound Pass* — snowdrifts as low cover.

### 9. Skyreach Monastery — patterned traps · lean: Arcanist (crowded) · act boss slot

| Enemy | Made from | What it does |
|---|---|---|
| **Masked Pilgrim** | Charger · twist: a 3-hit combo, then pauses | Wait for the opening |
| **Censer Acolyte** | Spitter · twist: fires in rotating spirals | Bullet patterns |
| **Lantern Wisp** | **New: phaser** (shared with Lantern Moth) | — |
| **Bellkeeper Beetle** | Bulwark · twist: rings a shockwave ring every few seconds | Ring timing |

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
| **Ember Mite** | Charger, fast · twist: leaves a short fire trail | Don't follow its path |
| **Cinder Moth** | **New: flyer** (shared with Gale Moth) | Swoops over the cracks |
| **Rail Weevil** | **New: rider** — rides fixed rails, drops bombs | Rails are lanes to avoid |
| **Magma Grub** | Lurker · reskin | Surfaces under you |

**Arenas.** *Mine Shafts* — narrow tunnels. *Lava Cracks* — glowing cracks
that erupt on a timer (warning glow first). *Collapsing Tunnel* — floor
sections crumble after you've stood on them for a moment.

### 11. Obsidian Forge — constructs and turrets · lean: Ranger (open)

| Enemy | Made from | What it does |
|---|---|---|
| **Forge Shell** | Bulwark · reskin (stone and brass) | The wall |
| **Mortar Snail** | **New: stationary** (shared with Glowcap) — aimed bursts | Stationary threat |
| **Anvil Rhino Beetle** | Charger, slow · twist: slam leaves a burning ring | Big telegraph |
| **Spark Firefly** | Spitter · twist: hovers, sprays a short fan | Pressure |

**Arenas.** *Assembly Line* — conveyor belts move you (and enemies) along.
*Forge Floor* — open, with furnaces that vent fire on a timer. *Turret Gallery*
— turrets line the walls; cover in the middle.

### 12. Molten Core — rising lava · lean: Arcanist (crowded) · act boss slot

| Enemy | Made from | What it does |
|---|---|---|
| **Magma Larva** | Charger · twist: bursts into 2 small Magma Larvae (Act 1's lesson, harder) | — |
| **Ember Mantis** | Lancer · twist: fires three lines in a fan | Wider telegraph |
| **Obsidian Stag** | Bulwark · twist: immune from the front | Flank it |

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
| **Lost Sentinel** | Bulwark · twist: blocks from the front, lunges | Patience |
| **Shade Archer** | Lancer · reskin | — |
| **Wailing Moth** | **New: phaser** (shared) · twist: shriek cone slows | — |
| **Stone Stag** | **New: perch** — a statue (untargetable) until you come near | Ambush |

**Arenas.** *Throne Hall* — pillars and a long carpet. *Broken Battlements* —
wall walk with gaps (void edges). *Courtyard of Statues* — stag-beetle statues
everywhere; some wake.

### 14. Void Rift — floating platforms · lean: Ranger (open)

| Enemy | Made from | What it does |
|---|---|---|
| **Void Mote** | **New: blinker** — teleports to a marked spot near you, then fires | Watch the mark |
| **Rift Mantis** | Charger · twist: blinks the last few studs of its charge | Late dodge |
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

Made with ChatGPT Codex (owner's choice for images and models). The arenas
are in the Archero 2 toy style of `ART-archero2.md`; the enemy line-ups were
redone in the insect-kingdom design language above (2026-10-22).

| Act | Enemies | Arena |
|---|---|---|
| 1 · The Wilds | `assets/concepts/act1_enemies.jpg` | `assets/concepts/act1_arena.jpg` |
| 2 · The Lowlands | `assets/concepts/act2_enemies.jpg` | `assets/concepts/act2_arena.jpg` |
| 3 · The Heights | `assets/concepts/act3_enemies.jpg` | `assets/concepts/act3_arena.jpg` |
| 4 · The Depths | `assets/concepts/act4_enemies.jpg` | `assets/concepts/act4_arena.jpg` |
| 5 · The End | `assets/concepts/act5_enemies.jpg` | `assets/concepts/act5_arena.jpg` |

All ten on one page: `assets/concepts/overview.jpg`. Generated as PNG and
saved as JPEG (85) to keep the repo light.
