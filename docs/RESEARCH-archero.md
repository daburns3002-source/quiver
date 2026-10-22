# Archero — Teardown

Source notes for the clone. Everything here is what the original does; Roblox adaptation
notes are marked **[RBX]**.

---

## 1. The one rule everything hangs off

**You move or you shoot. Never both.**

- Stand still → the archer auto-fires at the nearest valid target. No aim input, ever.
- Touch the stick → fire stops instantly, mid-volley.
- There is no dodge button, no dash, no block. The only defensive verb is *walking*.

This is the whole game. Every ability, enemy and room exists to pressure one decision:
*can I afford to stand here for 0.4 more seconds?*

**[RBX]** This must feel instant. Any lag between "stick released" and "first arrow out" kills
it. Target: fire resumes within one frame of stick release, first projectile spawned
client-side immediately and reconciled server-side.

### The asymmetry nobody notices but everybody feels

Obstacles **block the player's arrows** but **enemy projectiles fly over them**.

That single asymmetry turns every room into a positioning puzzle instead of a kiting lane —
cover is not safety, it is a damage penalty. Do not "fix" this. It is load-bearing.

---

## 2. Run structure

A chapter is **50 stages**, played as one continuous run. Death sends you back to stage 1.

| Stage pattern | Contents |
|---|---|
| First of each group | Intro / reward wheel |
| Most stages | Enemy arena, clear all to proceed |
| Ends in **5** | **Angel room** — no enemies. Choose: new ability *or* heal |
| Ends in **9** | **Treasure chest** (except 49) |
| Every **10th** | **Boss** |
| After a **no-damage clear** | **Devil room** — strong ability, costs max HP |

Rooms are short — **under a minute**, usually 20–40 seconds — with a beat of rest between them.
That rhythm of tension and release is why it works in three-minute sessions on a phone.

Chapters unlock in sequence. Variants exist (a 30-stage trap dungeon, arena chapters), but ship
the 50 / boss-every-10 format first.

---

## 3. Abilities — the roguelike layer

XP from kills → level up → **choose 1 of 3 random abilities**. All abilities are **lost on death
or chapter completion**. Permanent power lives in the meta layer instead.

### Why the system is good

Most abilities are **modifiers on the projectile pipeline**, not standalone effects. They stack
multiplicatively into absurd end-of-run states. Front Arrow + Diagonal + Ricochet + Bouncy Wall
turns one arrow into a room-filling pinball machine. That compounding is the dopamine.

**[RBX]** Build the shot system as an ordered **modifier pipeline** from day one:

```
BaseShot → [count] → [spawn pattern] → [flight behaviour] → [on-hit] → [on-kill]
```

Every ability is a data entry that inserts into one of those stages. If abilities are hardcoded
`if` branches, the game dies at ability #12. This is the single most important architectural
decision in the project.

### Ability catalogue, grouped by pipeline stage

**Projectile count / pattern**

- Front Arrow +1 — extra parallel arrow forward (damage penalty per extra, roughly -25%)
- Diagonal Arrows — two extra arrows at ±45°
- Side Arrows +1 — arrows at ±90°
- Rear Arrow +1 — arrow at 180°
- Multishot — the big one; effectively doubles output
- Double Shot — two arrows in sequence rather than side by side (better against moving targets)

**Flight behaviour**

- Piercing Shot — passes through enemies, about -33% damage per subsequent target
- Ricochet — bounces to a nearby enemy, up to 3 times, about -30% damage per bounce
- Bouncy Wall — rebounds off walls, about -50% after the bounce
- Slow Projectile — projectile crawls; absurd with Ricochet
- Through The Wall / Water Walking — terrain traversal, also carries a flat +15% damage

**On-hit / status**

- Blaze — burn damage over time on contact
- Freeze — slow, and interrupts enemy attack animations (defensive, not damage)
- Poison — weaker Blaze
- Bolt — chain lightning between grouped enemies
- Headshot — small chance of instant kill

**Stats**

- Attack Boost, Attack Speed Up, Crit Chance, Crit Damage, HP Up, Rage (more damage at low HP),
  Strong Heart, Bloodthirst (lifesteal on kill)

**Defensive and summons**

- Extra Life (+1) — top tier, always take it
- Wingman — spirit that shoots *and* body-blocks
- Shield Guard — two orbiting shields that block projectiles
- Invincibility Star — 2s shield every 10s, uncontrollable
- Elemental Circles (Fire / Ice / Poison / Lightning) — orbiting damage orbs
- Elemental Swords — summoned auto-attacking blades
- Summon Bat / Shadow Clone — pets and turrets

**On enemy death**

- Death Bomb, Nova, Holy Touch — small AoE or projectiles from corpses

**Economy**

- Smart — more gold

### Balance lesson from the original

Players converge hard: Ricochet, Multishot, Front Arrow and Extra Life are near-auto-picks, and
a chunk of the pool (Smart, Death Nova, Holy Touch) is dead weight. **Don't copy the dead
weight.** Ship about 25 abilities where every one is a real choice, then expand.

---

## 4. Enemy archetypes

Five behaviours cover almost everything. Enemy *variety* in Archero is mostly reskins plus stat
curves on top of these five. That is a gift for scope.

| Archetype | Behaviour | Counterplay it teaches |
|---|---|---|
| **Melee charger** | Beelines at you; some lunge; some split on death | Keep distance, never get surrounded |
| **Spread ranged** | Slow projectiles in several directions at once | Find the gap, move through it |
| **Line ranged** | Telegraphs with a **red line**, then fires one fast shot | Read the tell, sidestep the line |
| **Hidden** | Burrows or leaps to become untargetable, resurfaces with a spread | Pre-move before they land |
| **Tank** | Large, slow, placed to deny space | Treat as terrain, kill last |

Everything is **readable**. Telegraphs are long and explicit. Projectiles are slow enough to see
and dodge on a phone screen.

**[RBX]** Keep enemy projectile speeds low (8–20 studs/s) and give every attack a telegraph of at
least 0.4s with a clear visual.

---

## 5. Meta progression

Lost-on-death abilities are balanced by permanent power:

- **Gold and scrolls** earned from runs
- **Talents** — flat permanent combat bonuses bought with gold
- **Equipment** — weapon, armor, two rings, pet, locket, bracelet, spell book; leveled and fused
- **Weapons change the shot itself** — Brave Bow (balanced starter), Death Scythe (slow, huge
  damage, big hitbox, knockback), Tornado (built-in pierce and bounce, weak to bosses)
- **Heroes** — alternative characters with passive bonuses

**[RBX]** Weapons being *shot-pipeline presets* rather than stat sticks is what makes them
interesting. A weapon is just a base entry in the same modifier pipeline the abilities use.

---

## 6. What to deliberately change for Roblox

1. **No energy system.** The original gates runs behind energy to sell refills. Roblox players
   will bounce instantly. Monetize cosmetics and meta-progression convenience instead.
2. **Shorter first chapter.** 50 stages is a long first impression. Ship chapter 1 at about 20
   stages so a full run is 8–12 minutes, then extend.
3. **Co-op is the Roblox-native hook.** Two to four players in a shared run is the single biggest
   reason someone plays this on Roblox instead of on their phone. Design the systems co-op-ready
   from Phase 1 (server-authoritative, per-player ability stacks) even though co-op ships later.
4. **Cross-platform input parity.** Mobile thumbstick, PC WASD, gamepad stick. Auto-aim means none
   of them has an aiming advantage — this game is unusually fair across devices, which is why it
   is the right genre choice for Roblox.

---

## 7. Measured from Archero 2 footage

Everything above is teardown — what the game *is*. This section is what it
*measures as*, so the numbers in `Config/Balance` trace back to something.
Taken frame by frame from a 1080×1920, 30 fps full-screen capture
([youtube.com/watch?v=r4lsAXa6Trs](https://www.youtube.com/watch?v=r4lsAXa6Trs)),
reading pixel data in code rather than eyeballing screenshots, which the
browser downscales by about a fifth.

Earlier passes used a 1280×720 walkthrough where the game is a 257-pixel
column with blurred bars either side. Three things read from that were
wrong, and are worth knowing so nobody repeats them: enemy orbs **do** trail
a comet tail; the teal hexagon is **floor decoration**, not a telegraph; and
the red rings are **spawn markers**, not static floor features.

| | measured | ours |
|---|---|---|
| room width on screen | ~915 of 1080 px — **~85%**, always the full width | ~78% in portrait — zoomed out a little by choice |
| room shape | taller than wide, **≥ 1.5:1** | 35 × 58 studs (1.66:1) |
| camera | **fixed sideways**, follows the player up and down | the same |
| room width / player width | **~13** | ~17, roomier by choice |
| enemy / player width | ~1.4 | 1.5 |
| enemy orb / player width | ~0.64 | 0.6 |
| enemy orb tail | ~3–4× the orb | 0.6 s comet trail |
| player pace | **0.19 room-widths/s** | 0.26, brisker by choice |
| spawn warning | red ring per enemy, **~0.8–1.0 s** ahead, staggered, waves in triangles of three | 0.9 s + 0.08 s stagger; no clusters yet |
| multishot | a **parallel lane**, not a fan | parallel lane |
| arrow speed | **~5.5 room-widths/s** (~1,840 px/s, ref. video below) | 190 studs/s |
| fire interval | **0.6 s** between volleys | 0.7 s, by playtest choice |
| Diagonal Arrows | **±30°** either side of the aim | ±30° |
| Ricochet | bounces **between enemies**, not walls | between enemies |
| enemy orb speed | ~0.4–0.6 room-widths/s | 4–14 studs/s, slower — not yet matched |

**How the camera was measured.** The lamp posts on the side walls sit about
858 px apart and move together vertically between frames and never
horizontally, so the camera follows depth only. Over the clip it scrolled at
least 270 px, which is how the room is known to be taller than the screen.

**How pace was measured.** Horizontally, since the camera never moves that
way and there is no scroll to subtract: the player's health bar moved from
x≈330 to x≈227 in 0.6 s.

**Speeds, from a second video.** The ability walkthrough
([youtube.com/watch?v=cb0fRO72R_g](https://www.youtube.com/watch?v=cb0fRO72R_g))
plays at 1080p and 60 fps with the game in a 400 px column and a 336 px
floor. Its pixels can be read in code, which gave arrow speed by tracking
three arrow tips across consecutive frames, the fire interval from volley
frames, and the player's pace at 0.2 room-widths/s — which matches the
other footage and confirms the clip is real-time.

**What could not be measured.** Enemy movement speeds, and enemy orb
speeds only roughly — from a few hand-read samples, which is why the table
gives a range. Automatic colour tracking is too noisy with this many teal
and green things on screen: a health-bar detector reported widths between
134 and 664 px on one bar. Enemy speeds are therefore our own tuned values
scaled with the room, and should not be described as matching.

**Not built yet:** XP gems (blue cubes dropped on the floor by kills) and
triangle-cluster spawning.

---

## Sources

- [How to play Archero — Pocket Gamer](https://www.pocketgamer.com/archero/how-to-play-archero-the-latest-free-mobile-rogueli/)
- [Finding the Fun: Archero Part 1 — Scott Fine Game Design](http://scottfinegamedesign.com/design-blog/2019/7/2/archero-part-1-gameplay)
- [Archero Beginner's Guide — Level Winner](https://www.levelwinner.com/archero-beginners-guide-tips-cheats-strategies/)
- [Archero Skills List — Gamezebo](https://www.gamezebo.com/walkthroughs/archero-skills-list-a-list-of-skills-and-what-they-do/)
- [Archero Abilities Tier List — Pro Game Guides](https://progameguides.com/archero/archero-abilities-tier-list/)
- [Archero Tier List — Pocket Gamer](https://www.pocketgamer.com/archero/tier-list/)
- [The Capital — Archero Wiki](https://archero.fandom.com/wiki/The_Capital)
- [Dungeon of Traps — Archero Wiki](https://archero.fandom.com/wiki/Dungeon_of_Traps)
- [Archero equipment guide — Android Authority](https://androidauthority.com/archero-equipment-weapon-armor-ring-pet-1087817)
- [Archero — Gamepressure](https://www.gamepressure.com/games/archero/zc5f01)
