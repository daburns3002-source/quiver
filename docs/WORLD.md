# World — classes and areas

The owner's direction of 2026-10-22: the game is **no longer archer-only**.
Three classes, fifteen areas in five acts. This is the plan of record for
content; `PROGRESSION.md` still owns the meta loop and `ROADMAP.md` the order
things are built in. Nothing here is built yet. The enemies and arenas for
each area, with concept art, are in `ENEMIES-AND-ARENAS.md`.

---

## Title

"Arrow Legends" names one class. Candidates that fit all three:
**Splitpath, Threefold, Descent, Hollow Crown, Ashborn.** *Open — see the
decisions at the end.* Until one is chosen the code, repo and docs keep
"Arrow Legends".

---

## Classes

| Class | Role | Range | Builds around |
|---|---|---|---|
| **Ranger** (archer) | fast, fragile | long | multishot, ricochet, pierce |
| **Arcanist** (mage) | slow attacks that hit hard | medium | AoE; burn, freeze, shock |
| **Warden** (melee, **unlockable**) | tanky | close, sweeping arcs | dash, lifesteal, knockback, thorns |

**Each class's Mythic** (owner, 2026-10-22):

- **Ranger — Dual Bows.** A second bow: twice the attack speed. Built
  (`Abilities.DualBows`, dealt only to the Ranger).
- **Arcanist — Homing Orbs.** Shots home on the nearest enemy. The homing is
  built as Tracking Eye, now held back from the Ranger; it becomes Homing
  Orbs, with its own art, when the Arcanist is built.
- **Warden / Duelist** — not chosen yet.

Skills say which classes can draw them (`Ability.classes`, none named means
all); Second Wind stays a Mythic every class can draw.

**Alternative to the Warden:** a **Duelist** — fast dagger strikes, crits,
evasion — if the unlockable melee class should play faster. *Open.*

What exists today is the Ranger: move-or-shoot, the shot pipeline and every
ability are built for it. How the others fit the pipeline:

- **Arcanist** is a projectile class and fits the pipeline as it stands:
  slower, heavier shots, splash as a base trait rather than an ability, and
  elemental on-hit stages. Burn already exists (`Combat/Burning`); freeze and
  shock are new on-hit stages of the same kind.
- **Warden / Duelist** do not fire projectiles. Non-negotiable #1 names the
  *projectile* modifier pipeline; a melee class needs it generalised to an
  **attack** pipeline whose "spawn pattern" can be an arc sweep or a stab, so
  that abilities stay data and no class becomes an `if` branch in combat code.
  That is an architecture change and gets its own design pass before code.
- Each class needs its own ability pool (some shared — stats, defensive —
  some class-only), drawn by the same rarity-weighted draft.

---

## Areas

Five acts of three. Each act has **one signature hazard**, so the acts feel
distinct, and the areas lean toward different classes (open arenas suit the
Ranger, crowded rooms the Arcanist, tight corridors the Warden), so the class
chosen matters across a run.

| # | Area | Act | Enemies | Hazards and shape |
|---|---|---|---|---|
| 1 | Mossy Glade | 1 · The Wilds | slimes, wolves | tutorial-friendly forest |
| 2 | Thornwood | 1 | spiders | brambles that make choke points |
| 3 | Bandit Hollow | 1 | humanoid archers, brutes | canyon camp |
| 4 | Sunken Marsh | 2 · The Lowlands | frogs | poison pools, slow zones |
| 5 | Drowned Village | 2 | zombies, ghosts | ruined houses |
| 6 | Bogheart Caverns | 2 | — | glowing fungus; **giant toad boss** |
| 7 | Windswept Cliffs | 3 · The Heights | harpies | narrow paths, knockback hazards |
| 8 | Frostpeak Pass | 3 | yetis, frozen golems | ice that slows |
| 9 | Skyreach Monastery | 3 | corrupted monks | traps in patterns |
| 10 | Ember Mines | 4 · The Depths | fire imps | lava cracks, collapsing tunnels |
| 11 | Obsidian Forge | 4 | dwarven constructs, turrets | — |
| 12 | Molten Core | 4 | — | rising lava; **fire elemental boss** |
| 13 | Shattered Kingdom | 5 · The End | undead knights | ruined castle |
| 14 | Void Rift | 5 | teleporting enemies | floating platforms, gravity shifts |
| 15 | The Hollow Throne | 5 | — | **final boss**, mixing earlier mechanics |

Signature hazards by act, as suggested: slow (Lowlands — poison and slow
zones), knockback (Heights), lava (Depths), void (The End); the Wilds' is
open — brambles' choke points are the nearest candidate.

New enemy types are built the way `PROGRESSION.md` already says: from the
five archetypes (charger, spitter, lancer, bulwark, lurker) with new art and
stats where they fit, and new archetypes only where a behaviour is genuinely
new (teleporting, turrets).

### Bosses

Two cadences were suggested: a boss at the end of each act (areas 3, 6, 9,
12, 15), or one ending every area, as Archero does. The settled decision
that **an area is unlocked by beating its boss** (`PROGRESSION.md`, "Area
gating") needs a boss in every area to gate on. So the reading that fits
what is settled is **every area ends in a boss, and the act-ending areas'
bosses are the big set pieces** (the giant toad, the fire elemental, the
Hollow Throne). **Settled** (2026-10-22): the owner asked for a boss for
each area; all fifteen are designed in `BOSSES.md` — not built yet.

---

## Decisions this needs from the owner

1. **The title** — one of the five, or keep "Arrow Legends".
2. **The unlockable melee class** — Warden or Duelist.
3. ~~**Boss cadence**~~ — settled: every area (`BOSSES.md`).
4. **When classes land in the roadmap** — the Arcanist is cheap (projectile
   pipeline); the melee class needs the attack-pipeline change first.
5. **How the melee class is unlocked** — clearing an area, a currency, or
   something else.
