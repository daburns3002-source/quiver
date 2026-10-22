# Archero 2 — art and design reference

Detailed notes on how Archero 2 *looks*: characters, enemies, attacks,
effects, arenas and screens. It's the art companion to
`RESEARCH-archero2.md`, which covers mechanics and numbers.

Everything here was studied frame by frame in four native-portrait 1080×1920
gameplay videos (sources at the bottom), plus the earlier 1440p and 1080p
captures. Times like "#1 1200 s" point to a moment in a source video so a
claim can be checked.

The goal is to match Archero 2's **style and readability**, not its assets:
our characters, names and models stay our own.

---

## 1. The style in one paragraph

**Soft, rounded, saturated toy-like 3D on a muted floor, lit evenly, with
glowing effects.** Characters look like painted vinyl toys: chunky, bevelled,
smooth-shaded, never sharp-edged or flat-shaded. Every character sits on a
soft dark contact shadow. The floor is always lighter or duller than what
stands on it, so the fight reads at a glance. Anything dangerous or rewarding
**glows**: shots, hits, pickups, rings. Nothing important is ever dark.

---

## 2. Palette and lighting

| Area | Floor | Walls and trim | Accents |
|---|---|---|---|
| Ch. 1 Moonlight Forest | blue-violet flagstone, dark seams, faint drifting sparkles | purple bevelled stone, pink glowing orb lamps, grass strip with small flowers | green moss hexagon inset, water pools, lily pads |
| Ch. 2 Cloud Dreamland | warm sand-beige tiles | golden/orange cliff edges of a floating island | waterfalls, clouds below, pink crystals |
| Ch. 3 Autumn Ruins | grey stone with darker tile seams | stone walls with grass tops; **huge soft rounded cubes** in the foreground, one colour per room (green, red, purple, orange) | carved stone blocks, wooden crates, teal gems on pedestals |
| Gold Cave dungeon | warm brown flagstone | torches, mine rails and carts | gold crystals, firelight |
| Survivors mode | flat lime-green grass | soft hedges | — |

Rules that hold across all of them:
- The **floor is the least saturated thing on screen**. Characters and
  effects are the most saturated.
- **Lighting is even and soft.** No hard cast shadows, only soft blobs under
  characters. Bloom is on glows only.
- **Warm against cool.** Cool floors carry warm enemies and shots, and warm
  floors carry cool or magenta ones.

---

## 3. Characters

**Player** (#1 44 s, #18 448 s)
- A chibi hero: big head, small body, about 1.5× as tall as wide.
- A **blue ring with a darker centre** sits under the player at all times.
- A **segmented health bar** floats above: dark backing in blocks, green fill
  (red when low), and the HP number in white with a dark outline.
- On being hit: a yellow-orange glow bursts around the body (#1 340 s).

**Enemies** are small, round and cute, each built from **one silhouette plus
one colour plus glowing eyes**:

| Enemy (as seen) | Build | Colours | Notes |
|---|---|---|---|
| Ladybug beetle (#1 720 s) | round domed shell, small black head | red shell, black spots, **glowing yellow eyes** | chapter-1 melee |
| One-eyed slime (#1 720 s, #4 416 s) | translucent teardrop jelly | cyan/teal, glossy highlight | **one big eye**, yellow iris; comes in sizes |
| Egg ghost (#1 44 s) | white egg, cracked top | white, red eyes, dark mouth | |
| Flower (#1 250 s) | rose-bloom head on a green stem | orange petals | |
| Spiky grub (#1 1080 s) | segmented larva with spikes | purple | |
| Bee (#2 150 s, #4 416 s) | round striped body, white wings | yellow and black | drops red droplets |
| Horned fluff (#2 330 s) | fluffy ball with small horns | purple/pink | |
| Hooded mage (#3 456 s) | hood with a single eye | purple, pink face | casts purple orbs |
| Skeleton knight (#3 753 s) | helmeted skull | bone white, yellow scythe | |
| Spiked urchin (#3 753 s) | spiked ball | purple body, **cyan spikes**, yellow eyes | |
| Rock shell (#4 416 s) | round grey-blue shell | slate blue | carries a "!" when winding up |

**Bosses** are the same style at 3–4× scale with a stronger silhouette:
- *Egg demon* (#1 1200 s, #4 149 s): a black body under a **cracked white
  eggshell cap**, glowing jagged red-orange eyes and mouth, and red bat-wing
  arms. It arrives in a ring of white smoke puffs.
- *Blue lizard* (#2 960 s): a glowing blue dinosaur with a ridged back.

**Health bars on enemies:** thin and red with a dark backing, shown above the
head once the enemy has taken damage.

---

## 4. Attacks and effects

**Attack warning.** Before an enemy attacks, a **red "!" burst icon** pops
above its head (#2 150 s, #4 416 s). It is the main tell, used *in addition
to* any shot pattern.

**Target lock.** A **segmented red ring** (three arcs around a dark disc)
sits under **the enemy the player is currently shooting**, and only that one
(#2 330 s: of two side-by-side enemies, only the targeted one has it).
It's also used as the spawn marker before an enemy appears, in the same red.

**Enemy projectiles** glow, and their **trail tells you the type**:
- Magenta orb: glossy sphere with a white specular highlight, a soft halo and
  **a trail of small sparkles** (#1 138 s).
- Fireball: bright yellow-orange core and a **dark smoky red-brown trail**
  (#2 960 s, #4 149 s).
- Thrown boulder: glowing white rock with a grey smoke trail (#3 1149 s).
- Yellow orb: golden comet tail (#3 1149 s).
- Enemy arrow: purple, with a sparkle trail (#3 1149 s).
- Homing orb: purple, drawing a **long magenta ribbon** (#1 1080 s).
- Bosses fire **radial rings** of 12–16 fireballs (#2 960 s, #4 149 s).

**Player projectiles**
- The default arrow is a **real arrow**: dark shaft, **red fletching**, pale
  pink-white trail (#1 100 s).
- Beams (staff weapons) are thick cyan-white rays with a glowing orb head.

**Hits.**
- The struck enemy **flashes bright white-orange**, as additive glow over
  the whole body (#1 250 s).
- **Damage numbers** are bold and outlined. White is a normal hit, orange
  is fire, magenta is poison, and crits are larger red. They stack upward.
- **Elemental bursts:** freeze throws blue ice shards outward, explosions are
  a big yellow flash disc (#2 150 s), and poison is magenta.

**Deaths and pickups.** Kills drop **cyan XP crystals** (small faceted cubes)
that lie on the floor. Arrivals and big landings are marked by **puffs of
white smoke**.

**Encounters.**
- The Valkyrie is a golden winged helmeted figure in a warm glow (#1 60 s).
- Card reveals are **pillars of light**, rarity-coloured (#4 683 s).

---

## 5. Arenas

- **Walled courtyards** with chunky bevelled walls, lamps or orbs on pillars,
  a **gate at the top** (candles, banners, statues) and an **entry at the
  bottom**.
- **Rooms stages** show a glowing purple gate as the exit (#3).
- **Obstacles** are soft-edged stone blocks with a carved emblem, or wooden
  crates. They're never flat grey boxes.
- **Beyond the walls**, the world continues: water, plants, cliffs, clouds.
  The arena sits *in* a place.

---

## 6. Screens (for the later UI art pass)

- **Cards:** a rarity-coloured frame (green Fine, blue Rare, purple Epic,
  orange Legendary), a rounded white icon tile, a bold title bar, and white
  description text on a dark tint of the rarity colour.
- **Banners:** a yellow ribbon header ("Level Up", "You've Met Valkyrie")
  over a cream subtitle.
- **Wheels:** Roulette and the post-boss reward wheel use gold-rimmed segments.
- **HUD:** pause, XP bar with "Lv.N", and coins along the top; a wave strip
  with icons for upcoming special waves; a boss HP bar that **replaces** the
  XP bar during a boss.

---

## 7. What we have vs. what to change

Art only; gameplay stays as it is (owner, 2026-10-22).

| Area | Ours now | Change |
|---|---|---|
| Enemy look | draft bodies from parts | restyle each archetype as a round cute creature with glowing eyes: Charger → ladybug beetle, Spitter → one-eyed slime, Lancer → hooded one-eyed mage, Bulwark → rock-shell brute, Lurker → spiked urchin |
| Attack tell | flash, line, ground marker | **add the red "!" icon** above an enemy while it winds up, on top of the existing tells |
| Target | none | **segmented red ring** under the enemy the player is aiming at |
| Shadows | — | **soft dark contact shadow** under every character |
| Player ring | — | **blue ring** under the player |
| Enemy orbs | glowing ball with comet trail | white highlight and a sparkle trail |
| Arena | flat colours | blue-violet floor with seams, bevelled purple walls, pink orb lamps |
| Damage numbers | white / red crit / orange burn | matches already |

---

## Sources

- [Archero 2 #1](https://www.youtube.com/watch?v=rwwpGLnqt7c): chapter 1,
  native 1080×1920.
- [Archero 2 #2](https://www.youtube.com/watch?v=_NCC5jR9-Vo): chapter 2,
  Cloud Dreamland.
- [Archero 2 #3](https://www.youtube.com/watch?v=0nFJ7F5Jm2s): chapter 3,
  Autumn Ruins (rooms stage).
- [Archero 2 #4](https://www.youtube.com/watch?v=6sBW8S3acYg): Gold Cave,
  survivors mode, screens.
- Earlier: [#18](https://www.youtube.com/watch?v=cPgcsbyyOEE) and
  [walkthrough part 1](https://www.youtube.com/watch?v=cb0fRO72R_g).
