# World — classes and areas

The owner's direction of 2026-10-22: the game is **no longer archer-only**.
Three classes, ten areas in five acts of two. This is the plan of record for
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

Five acts of **two** — ten areas, each ending in its boss (owner,
2026-10-22: two bosses per act; five areas were cut with their bosses and
are kept in `ENEMIES-AND-ARENAS.md`, "Cut areas"). Each act has **one
signature hazard**, so the acts feel distinct, and the areas lean toward
different classes (open arenas suit the Ranger, crowded rooms the Arcanist,
tight corridors the Warden), so the class chosen matters across a run.

| # | Area | Act | Enemies | Hazards and shape | Boss |
|---|---|---|---|---|---|
| 1 | Mossy Glade | 1 · The Wilds | slimes, wolves | tutorial-friendly forest | King Bloblin |
| 2 | Thornwood | 1 | bramble boars, thistles | brambles that make choke points | the Broodmother |
| 3 | Drowned Village | 2 · The Lowlands | zombies, eels | ruined houses | Old Tollcrab |
| 4 | Bogheart Caverns | 2 | spore puffs, glowcaps | glowing fungus, poison vents | Grandmother Gulp |
| 5 | Windswept Cliffs | 3 · The Heights | harpies, goats | narrow paths, knockback | the Tempest Roc |
| 6 | Frostpeak Pass | 3 | yetis, frost golems | ice that slows | Rimeheart |
| 7 | Ember Mines | 4 · The Depths | fire imps, ember bats | lava cracks, collapsing tunnels | Cindertusk |
| 8 | Obsidian Forge | 4 | constructs, turrets | furnaces, conveyors | the Forgewarden |
| 9 | Shattered Kingdom | 5 · The End | undead knights, gargoyles | ruined castle | Sir Gravemourne |
| 10 | Void Rift | 5 | void wisps, rift stalkers | floating platforms, gravity | the Riftwalker (final) |

Signature hazards by act, as suggested: slow (Lowlands — poison and slow
zones), knockback (Heights), lava (Depths), void (The End); the Wilds' is
open — brambles' choke points are the nearest candidate.

New enemy types are built the way `PROGRESSION.md` already says: from the
five archetypes (charger, spitter, lancer, bulwark, lurker) with new art and
stats where they fit, and new archetypes only where a behaviour is genuinely
new (teleporting, turrets).

### Bosses

**Settled** (2026-10-22): **two bosses per act**, one ending each area, so
an area is still unlocked by beating its boss (`PROGRESSION.md`). Ten in
`BOSSES.md`; the Riftwalker is the final boss. Not built yet.

---

## Decisions this needs from the owner

1. **The title** — one of the five, or keep "Arrow Legends".
2. **The unlockable melee class** — Warden or Duelist.
3. ~~**Boss cadence**~~ — settled: two bosses per act, one per area (`BOSSES.md`).
4. **When classes land in the roadmap** — the Arcanist is cheap (projectile
   pipeline); the melee class needs the attack-pipeline change first.
5. **How the melee class is unlocked** — clearing an area, a currency, or
   something else.
