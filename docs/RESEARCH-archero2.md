# Archero 2 — art, mechanics and damage, as observed

What Archero 2 looks like, how it plays, and how its numbers scale, so Arrow
Legends can be built to match. `RESEARCH-archero.md` is the teardown of the
first game plus the measured proportions (§7); this file is the second game,
from footage and from written guides.

Each claim says where it came from: **[footage]** is something seen and
usually measured in a video, **[guide]** is from a written source listed at
the bottom, **[ours]** is the current state of our game. Where a number is a
guess, it says so.

---

## 1. Art style

**Overall: soft, rounded, saturated toy-like 3D.** [footage] Not flat-shaded
low poly: characters and props have smooth bevels, soft shading and gentle
gradients, like painted vinyl toys. Shadows are soft blobs under characters,
not hard cast shadows. Lighting is even and bright; nothing important is ever
in darkness.

**Readability through colour temperature.** [footage] Arena floors are cool
and desaturated — blue-violet flagstone in chapter 1, dusky purple/brown
stone later. Everything that matters is warm or bright against it: red and
orange enemies, white and cyan player shots, magenta and orange enemy shots,
gold coins. The floor never competes with the fight.

**Characters.** [footage]
- *Player:* a chibi hero with a big head; most enemies are about 1.4× the
  player's width. A **blue ring** sits under the player at all times.
- *Enemies:* small round creatures with one strong feature — a red beetle
  with glowing yellow eyes, a blue one-eyed slime, a jack-o'-lantern. Each
  reads by silhouette and one colour. A **red ring** under an enemy marks it
  (also the spawn marker before it lands).
- *Bosses:* several times an enemy's size, same style.

**Health bars.** [footage]
- Player: a **segmented** green bar (blocks, like a lives meter) with the HP
  number printed on it, floating above the head.
- Enemies: a thin red bar with a dark backing, above the head, shown once
  damaged.

**Damage numbers.** [footage] Bold, outlined, float up and fade. **White**
for a normal hit; **larger and red/orange** for a crit. Late game they reach
five digits ("-7302", "-22469").

**Projectiles.** [footage] Player arrows are bright streaks with a dark tip
and a pale trail; staff/beam weapons are thick glowing cyan beams with a
white orb head. Enemy shots are glowing orbs (magenta, orange fireballs) with
comet tails. Muzzle flash is a small white burst at the player.

**Environment.** [footage] Arenas are walled courtyards: stone walls with
lamp posts or glowing orbs, banners and a gate at the top, a carpet or
doorway at the bottom, statues outside. Floor decoration (moss hexagons,
tiles, cracks) is subtle. Beyond the walls, a lush stylised backdrop — water,
plants, flowers — fills the rest of the screen.

**HUD.** [footage] Top: pause button (left), XP bar with "Lv.N" (centre),
coin count (right); under it a wave indicator ("WAVE" with icons for
upcoming special waves) and a small kill counter. Bottom: a **dynamic
joystick** that appears where the thumb lands. Cards and blessing screens are
big, bright and rarity-coloured.

**Camera.** [footage] Portrait, fixed sideways, follows the player up and
down only (measured in §7 of the other doc). The view is **more tilted than
ours**: walls and pillars show visible front faces, and the back wall with
its gate is clearly seen. We look down at 68°; Archero 2 is noticeably
lower. Not precisely measured — a colour-based attempt on a ground ring was
confounded by other red things on screen.

---

## 2. Gameplay mechanics

**Move or shoot.** [guide][footage] The hero fires automatically at the
nearest enemy, only while standing still. This applies to every arrow
modifier (front, diagonal, split). Charged skills also need stillness. Most
other damage — orbiting orbs, sprites, auras — works while moving.

**Fire rate.** [footage] About **0.6 s** between volleys on a fresh hero
(measured). [ours: 0.7 s, by owner's choice.]

**Range.** [guide] "Large" — effectively the whole arena.

**Arena mode: waves in one room.** [guide][footage] A stage is a sequence of
**waves in the same arena**; the wave counter ticks up and enemies arrive
behind red skull markers. It is not a series of rooms with doors.
- **Every 10th wave:** a boss.
- **Every 5th wave (5, 15, 25…):** a Valkyrie — choose one of two skills,
  and a heart drops.
- **Every 9th wave (9, 19, 29…):** an Angel — choose a minor stat boost or a
  random heal.
- **After a boss:** a Roulette (random prize) or a Devil (a skill for
  permanent max HP).
- A full stage is ~50 waves (footage shows "10/50", "15/50").
- [ours: 10 rooms joined by doors.]

**Survivors mode** [guide] is a second level type: survive a timer while
enemies stream in. Not needed yet.

**XP.** [guide][footage] Kills drop **blue crystals**. In arena mode they
are collected **at the end of the wave**, not by walking over them. A full
bar opens a choice of **3 skills**, with rarity shown by colour: green Fine,
blue Rare, purple Epic, orange Legendary. **Skills don't level up:**
picking one twice does nothing. [ours: stacking abilities with caps;
crystals collected when a wave or room clears.]

**Healing.** [guide] Mainly **hearts**, dropped rarely by enemies and by
special waves. They stay on the floor until picked up. One revive per stage
(full HP plus brief invulnerability). [ours: Mending card, Bloodthirst;
hearts on 5% of kills and every Valkyrie wave, 20% of max HP each. One
automatic revive per stage: full HP, 2.5 s invulnerable, enemy shots within
12 studs cleared. Archero 2 asks first and charges; ours is free until
there is a currency.]

**Enemies.** [guide] Enemy attacks have **no area markers**; damage comes
from projectiles or collision. [ours: we telegraph with lines, flashes and
ground markers, which is more forgiving.]

**Skills** [guide] (101 in total). Grouped as they would map to our
pipeline, by bucket:
- *Count/pattern:* Front Arrow (+1), Diagonal Arrows (+2), Backward Arrow,
  Rapid Fire (multishot +1), Split Shot.
- *Flight:* Tracking Eye, Ricocheting Arrow (between enemies), Bounce Arrow
  (off walls), Piercing Arrow, Wall-Piercing Arrow, Lightwing Arrow.
- *On hit:* Blaze, Venom, Freeze, Bolt (with "Super" upgrades), Assault
  Strike.
- *Stats:* Power Trio (HP/ATK SPD/ATK ×1.15), Warrior's Soul (ATK ↑↑↑↑), Soul
  of Strength (HP ↑↑↑↑), Soul of Swiftness, ATK Increase, Fairy's Breath, Swift
  Arrow (speed up, damage down).
- *Situational:* Perilous Fervor (ATK and speed under 50% HP), Demon Slayer
  (ATK after kills), Stand Strong (ATK and speed while still), Wounded
  Warrior, Bane of Bosses, Long-Range Power.
- *Summons and orbs:* sprites (laser, flame, ice, venom, lightning, bomb),
  rotating orbs (fire/ice/poison/thunder/vamp), flying swords, meteors.
- *Defence:* Sacred Protection (block one shot per wave), Revive, Angelic
  Shelter, Wind Blessing (dodge).
- Community top picks: Power Trio, Tracking Eye, Rapid Fire, Freeze, Sacred
  Protection, Warrior's Soul.

---

## 3. Damage and scaling

**The damage formula** [guide], as far as published:
- Every damage source is a multiple of **Attack Power**.
- Flat attack (gear, talents) adds up first; **ATK PWR %** bonuses add
  together (+100% → 2.0×, +125% → 2.25×).
- **Final Damage %** multiplies the whole result (2.0 × 1.25 = 2.5×).
- **Crit:** base **200%** crit damage (2.0×), multiplying the finished hit.
- **Skills grant multipliers** on top of gear's flat stats — the run layer
  multiplies the meta layer, which is exactly our non-negotiable 8.

**Fresh-account numbers, chapter 1** [footage]:
- Player HP **225**; arrow hit **100**.
- Wave-1 grunt: **3 hits** to kill (about 300 HP), so about 1–1.5 s each.
- "Don't expect to survive more than about **4 hits**" [guide] → an enemy
  hit is roughly **a quarter of the player's HP**.
- Crits read as distinct big red numbers.

**Late-account numbers** [footage]: player HP ~10,000; hits 2,000–7,000;
crits in the tens of thousands. Everything inflates by about 40× in both
directions, while hits-to-kill stays in single digits. That is the "numbers
inflate, difficulty does not" model.

**Ours, for comparison** [ours]:

| | Archero 2 (fresh) | ours |
|---|---|---|
| player HP | 225 | 100 |
| player hit | 100 (0.44 of HP) | 10 (0.1 of HP) |
| grunt HP | ~300 (3 hits) | Charger 45 (4.5 hits) |
| heaviest regular enemy | — | Bulwark 180 (18 hits) |
| enemy hit on player | ~56 (¼ of HP) | 8–18 (8–18% of HP) |
| hits to die | ~4 | 6–12 |
| crit | 2.0× base, big red number | 2.0× + Overdraw, same number style |

So ours is **slower to kill and more forgiving to be hit**. Archero 2 trades
fast kills for lethal mistakes. That is also why its fights read as "dodge
everything" while ours read as "stand and trade".

---

## 4. What to change, in priority order

A plan, not decisions. Each item needs the owner's yes, since several
reverse earlier tuning.

1. **Damage scale** — numbers ×10 (player 225 HP, hits around 100) and
   ratios like Archero 2's: grunts die in ~3 hits, ~4 hits kill the player.
   Pure config plus tests; the biggest change in feel for the least code.
2. **Damage numbers** — white normal, larger red crits.
3. **Waves in one arena** — replace rooms-with-doors with a wave counter in
   one room, red skull markers, a boss every 10, a Valkyrie (one of two skills)
   on 5s and an Angel (stat or heal) on 9s. Structural; a Phase 4 shape.
4. **XP crystals** — blue cubes dropped by kills, collected at wave end.
5. **Hearts** — rare drops that heal and wait on the floor.
6. **Skills don't stack** — Archero 2 gives one copy of each; ours stack with
   caps. **Decided (owner, 2026-10-22): ours stack.**
7. **Camera tilt** — lower than our 68°, so walls show faces. Measure first.
8. **Art pass** — soft, rounded, saturated characters on a cool floor;
   segmented player HP bar; blue ring under the player, red under enemies;
   walled courtyard with gate, lamps and a lush backdrop. The owner said UI
   and animation art would come later, so confirm scope.
9. **Enemy telegraphs** — Archero 2 shows none. Removing ours makes the
   game much harder; probably keep them.

---

## Sources

- Footage: [Archero 2 walkthrough part 1](https://www.youtube.com/watch?v=cb0fRO72R_g)
  (1080p60, fresh account, chapter 1), [Archero 2 #18](https://www.youtube.com/watch?v=cPgcsbyyOEE)
  (1440p, late account), [1080×1920 capture](https://www.youtube.com/watch?v=r4lsAXa6Trs).
- [Archero 2 beginner's guide — LevelWinner](https://www.levelwinner.com/archero-2-beginners-guide/)
  — waves, Valkyrie/Angel/Devil, XP crystals, rarity, hearts, revive.
- [Archero 2 guide — Pocket Gamer](https://www.pocketgamer.com/archero-2/guide/) — gear and merge tiers.
- [Final Damage explained — mturbogamer](https://mturbogamer.com/2026/10/archero-2-final-damage/)
  — damage formula structure (the formulas themselves did not survive conversion).
- [Archero 2 skill tier list — mobi.gg](https://mobi.gg/en/tips/archero-2-skill-tier-list/) — the 101 skills.
- [Skills tier list — Pro Game Guides](https://progameguides.com/archero-2/archero-2-skills-tier-list/)
  and [allthings.how](https://allthings.how/?p=31813) — current-version picks (Beam Strike, Corrosive Field).
