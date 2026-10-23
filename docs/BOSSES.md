# Bosses — one per area

A first pass at all fifteen, asked for by the owner on 2026-10-22 ("give me
bosses for each of the areas"). Design only — nothing here is built. The
areas, their enemies and arenas are in `ENEMIES-AND-ARENAS.md`; the world in
`WORLD.md`. Concept art for every boss, made with ChatGPT Codex, is in
`assets/concepts/boss01_…` to `boss15_…` (table at the end).

**Every area ends in a boss**, which is what the settled gate needs: an
area unlocks the next when its boss is beaten (`PROGRESSION.md`). The bosses
that close an act (areas 3, 6, 9, 12, 15) are the set pieces — three phases,
their own arena — and the rest are two-phase bosses in the area's own arena.

---

## Rules every boss follows

Archero's bosses are fair because they are readable, and these are built to
the same rules:

- **Every attack is telegraphed** — a red ring, line, cone or marked spot —
  for at least as long as an enemy's wind-up (`Balance`), longer for anything
  that can kill outright. The red "!" over the boss fires on every wind-up.
- **Phases change at health thresholds** (shown as notches on the boss bar),
  with a short pause and a roar between them, so a player always knows the
  rules just changed.
- **A boss teaches its area's lesson one more time, louder.** Its attacks
  are built from the same pieces as the area's enemies — the hazard the
  player has been dodging all area, done big.
- **No attack depends on seeing anything off-screen**, and nothing hides
  the floor: phone players see a small screen.
- **Each class can win.** The "Class notes" line says where each one has
  it easy or hard; no boss is unwinnable at close range or at long range.

---

## Act 1 — The Wilds

### 1 · King Bloblin — Mossy Glade
*A huge moss slime wearing a tiny crown.* The tutorial boss: one idea, shown
clearly.

- **Phase 1 — Royal Hop.** Hops toward you; a ring marks where it lands; the
  landing sends out a slow ripple. Between hops it sits still — the window.
- **Phase 2 (50%) — Divided Court.** Splits into two half-size Bloblins that
  hop in turn, then, below 25% each, into Mossgrubs.
- *Teaches:* watch the landing mark; finish what you start (Mother Slime,
  bigger). *Class notes:* Ranger kites easily; Warden must dodge the ripple
  to stay close.

### 2 · Thornweaver — Thornwood
*A spider queen with bramble legs and a glowing abdomen.*

- **Phase 1 — Web Lanes.** Shoots web lines across the room that become slow
  strips, cutting the arena into lanes; spiderlings drop from the ceiling.
- **Phase 2 (50%) — From Above.** Climbs out of reach (untargetable) and
  drops onto a marked spot near you, breaking every web in a ring.
- *Teaches:* choke points — the room keeps narrowing. *Class notes:* Arcanist
  clears spiderlings well; Ranger must not get trapped in a lane.

### 3 · Captain Redscarf — Bandit Hollow · *Act 1 boss*
*A stout bandit chief with a red scarf, dagger bandolier and powder kegs.*

- **Phase 1 — Knives Out.** Throws a fan of daggers, then charges along a
  marked line.
- **Phase 2 (66%) — Volley!** Whistles; marked circles rain arrows from the
  canyon rim. Keeps throwing daggers between volleys.
- **Phase 3 (33%) — Powder Kegs.** Rolls lit kegs that burst in rings after a
  fuse. Shoot a keg next to him and it hurts him.
- *Arena:* the canyon camp, crates as cover that his charge smashes.
  *Teaches:* reading three telegraphs at once. *Class notes:* Ranger can
  detonate kegs from range; Warden gets the charge's recovery window.

---

## Act 2 — The Lowlands

### 4 · The Bog Hydra — Sunken Marsh
*Three serpent heads rising from poison pools.*

- **Phase 1.** Three heads, each its own health bar, surface from pools in
  turn (Lurker-style) and spit poison that pools where it lands.
- **Phase 2 (two heads left).** The survivors surface together and spit in
  crossing lines. The last head, alone, thrashes in a ring.
- *Teaches:* poison ground and priorities — which head first. *Class notes:*
  Arcanist's area damage hits two heads at once; Warden must reach the pools.

### 5 · The Drowned Bellkeeper — Drowned Village
*A ghost fisherman carrying a huge rusted bell.*

- **Phase 1 — Toll.** Rings the bell: a shockwave ring expands from it,
  jump-free — you must be outside it or between two rings. Drifts through
  houses (phaser).
- **Phase 2 (50%) — The Drowned Rise.** Each toll raises Sodden Shells; the
  bell's rings now come in pairs.
- *Teaches:* ring timing; nothing can hide behind a wall here. *Class notes:*
  Warden can stand inside the ring's gap; Ranger must keep line of sight.

### 6 · Grandmother Gulp — Bogheart Caverns · *Act 2 boss*
*An enormous warty toad with glowing fungus on her back.*

- **Phase 1 — Tongue.** A tongue lash down a long marked line, then a pause.
- **Phase 2 (66%) — Belly Flop.** Leaps to a marked spot (leaper); the landing
  sends a shockwave ring and splashes poison.
- **Phase 3 (33%) — The Bog Rises.** Poison floods the room's edges, shrinking
  the dry floor; she swallows Puffshroom Crawlers and spits them as bursting clouds.
- *Arena:* an underground lake ringed by glowing mushrooms. *Teaches:* every
  Lowlands lesson at once. *Class notes:* Ranger has the safest tongue
  windows; Arcanist's freeze can hold her mid-leap.

---

## Act 3 — The Heights

### 7 · The Tempest Roc — Windswept Cliffs
*A giant storm bird with lightning on its wingtips.*

- **Phase 1 — Dive.** Crosses the arena in a marked dive line (flyer), then
  beats its wings: a gust pushes you toward an edge.
- **Phase 2 (50%) — Storm.** Lightning strikes marked spots in a pattern while
  it circles overhead, out of reach between dives.
- *Teaches:* knockback near edges. *Class notes:* Ranger hits it between dives;
  Warden waits for its landing after each dive.

### 8 · Rimeheart, the Yeti King — Frostpeak Pass
*A massive yeti with an ice crown and a glowing frozen heart.*

- **Phase 1 — Avalanche.** Rolls a snowball that grows as it goes, along a
  marked line; ground-pound freezes the floor around him into ice.
- **Phase 2 (50%) — Icefall.** Icicles fall on marked spots; frozen ones stay
  as walls, reshaping the room. His heart glows — hits to it do extra.
- *Teaches:* moving on ice. *Class notes:* the ice favours whoever keeps
  distance; Warden must commit through the pound's recovery.

### 9 · The Thousand-Palm Abbot — Skyreach Monastery · *Act 3 boss*
*A floating monk master with a halo of spectral hands.*

- **Phase 1 — Palms.** Fires spiral patterns of palm strikes (bullet
  patterns) that turn slowly — find the gap and walk it.
- **Phase 2 (66%) — Stillness.** Teleports between pillars; the floor's spike
  traps fire in a pattern he conducts.
- **Phase 3 (33%) — Thousand Palms.** Two spirals turning opposite ways,
  traps and teleports together, with a clear pause between cycles.
- *Arena:* the prayer hall. *Teaches:* patterns over reflexes. *Class notes:*
  Arcanist's area damage punishes his teleport landings; Ranger reads spirals
  best from range.

---

## Act 4 — The Depths

### 10 · Cindertusk — Ember Mines
*A giant armoured mole miner with a drill arm and lava in its hide.*

- **Phase 1 — Tunnel.** Burrows (untargetable) along a marked path; lava
  cracks erupt along its tunnel line a moment later; surfaces and drills.
- **Phase 2 (50%) — Cave-in.** Each surfacing collapses floor sections nearby;
  mine carts it knocks loose roll down the rails.
- *Teaches:* reading the ground. *Class notes:* Warden owns the surfacing
  window; Ranger must track its tunnel.

### 11 · The Forgewarden — Obsidian Forge
*A towering dwarven war-construct with a hammer and a furnace core.*

- **Phase 1 — Hammer.** Slams in a marked cone and a shockwave line; deploys
  Mortar Snails on the walls.
- **Phase 2 (50%) — Overheat.** Vents fire in a ring after every few slams,
  then stalls with its core exposed — the big damage window.
- *Teaches:* stationary threats and windows. *Class notes:* Ranger clears
  turrets; Warden lives for the overheat stall.

### 12 · Ignar, the Living Flame — Molten Core · *Act 4 boss*
*A fire elemental with molten fists and an obsidian crown.*

- **Phase 1 — Volley.** Fireball fans and slam rings; lava fills the room's
  edges a step at a time.
- **Phase 2 (66%) — Three Flames.** Splits into three small flames that each
  attack; they re-merge after a while, healing for the ones still standing.
- **Phase 3 (33%) — Molten Core.** The floor is islands over lava; Ignar
  leaps between them, erupting the island it leaves.
- *Arena:* the crucible ring. *Teaches:* the arena as the enemy.
  *Class notes:* Arcanist's freeze is strongest here; burn does nothing to
  him (he is immune to fire).

---

## Act 5 — The End

### 13 · Sir Gravemourne — Shattered Kingdom
*A giant undead knight with a tower shield and a greatsword.*

- **Phase 1 — Shield Wall.** Blocks everything from the front; sweeping sword
  arcs; summons Shade Archers. Flank him.
- **Phase 2 (50%) — Broken Oath.** Drops the shield; throws his sword in a
  spinning arc that returns, and lunges after it.
- *Teaches:* patience and flanking. *Class notes:* Warden's knockback turns
  him; Ranger's ricochet can reach behind the shield.

### 14 · The Riftwalker — Void Rift
*A masked void sorcerer with mirror-image clones.*

- **Phase 1 — Blink.** Teleports to marked spots (blinker) and fires void
  bolts; platforms blink out in a pattern.
- **Phase 2 (50%) — Mirrors.** Splits into three; only the real one casts a
  shadow — the tell. Gravity pulls toward the real one on a cycle.
- *Teaches:* watching marks and tells. *Class notes:* Arcanist's area damage
  hits the clones to reveal the real one; Duelist's evasion shines.

### 15 · The Hollow Crown — The Hollow Throne · *Final boss*
*An empty suit of ornate armour under a floating crown, orbited by five
glowing orbs — one for each act.*

- **Phase 1 — The Wilds.** Brambles close the room (Thornweaver's web lanes)
  and the Crown hops with Bloblin's landing ring.
- **Phase 2 — The Lowlands.** Poison rises at the edges and the Crown
  belly-flops (Gulp).
- **Phase 3 — The Heights.** Spiral patterns (Abbot) with wind gusts.
- **Phase 4 — The Depths.** Lava islands and fireball fans (Ignar).
- **Phase 5 — The End.** Teleports with mirror clones (Riftwalker), then, in
  its last 10%, cycles one attack from every act.
- Each orb breaks as its phase ends — the bar is the five orbs.
- *Teaches:* everything. *Class notes:* every class has a phase it loves and
  one it fears; that is the point.

---

## What bosses ask the engine for

Built once, shared by all fifteen:

| Piece | Used by |
|---|---|
| Boss health bar with phase notches; phase change at a threshold with a pause | all |
| Untargetable windows (burrowed, airborne, out of reach) | 2, 7, 10 |
| Multi-part boss (separate health per part) | 4, 15 |
| Weak point / damage window | 8, 11, 13 |
| Summons (adds) | 2, 3, 5, 6, 11, 13 |
| Split and re-merge | 1, 12 |
| Arena change mid-fight (rising hazard, walls, islands) | 3, 6, 8, 10, 12, 15 |
| Clones with one real body | 14, 15 |
| Damage-type immunity (fire) | 12 |

Most attacks reuse the enemy behaviours from `ENEMIES-AND-ARENAS.md` (leaper,
phaser, flyer, blinker, burrow, stationary) at boss scale, which is why those
are worth building well first.

---

## Concept art

Made with ChatGPT Codex, Archero 2 toy style, one per boss.

| # | Boss | Art |
|---|---|---|
| 1 | King Bloblin | `assets/concepts/boss01_king_bloblin.jpg` |
| 2 | Thornweaver | `assets/concepts/boss02_thornweaver.jpg` |
| 3 | Captain Redscarf | `assets/concepts/boss03_captain_redscarf.jpg` |
| 4 | The Bog Hydra | `assets/concepts/boss04_bog_hydra.jpg` |
| 5 | The Drowned Bellkeeper | `assets/concepts/boss05_drowned_bellkeeper.jpg` |
| 6 | Grandmother Gulp | `assets/concepts/boss06_grandmother_gulp.jpg` |
| 7 | The Tempest Roc | `assets/concepts/boss07_tempest_roc.jpg` |
| 8 | Rimeheart, the Yeti King | `assets/concepts/boss08_rimeheart.jpg` |
| 9 | The Thousand-Palm Abbot | `assets/concepts/boss09_thousand_palm_abbot.jpg` |
| 10 | Cindertusk | `assets/concepts/boss10_cindertusk.jpg` |
| 11 | The Forgewarden | `assets/concepts/boss11_forgewarden.jpg` |
| 12 | Ignar, the Living Flame | `assets/concepts/boss12_ignar.jpg` |
| 13 | Sir Gravemourne | `assets/concepts/boss13_sir_gravemourne.jpg` |
| 14 | The Riftwalker | `assets/concepts/boss14_riftwalker.jpg` |
| 15 | The Hollow Crown | `assets/concepts/boss15_hollow_crown.jpg` |

All fifteen on one page: `assets/concepts/bosses_overview.jpg`.
