# Progression design

Quiver is **Archero's combat inside a Pet Simulator / Steal an Egg progression shell.**

Two loops, deliberately different in shape:

| | Run loop | Meta loop |
|---|---|---|
| Model | Archero | Pet Simulator, Steal an Egg |
| Length | 8–12 minutes | weeks |
| Power | drafted, **lost on death** | collected, **permanent** |
| Feel | tense, skill-expressive | number-go-up, always climbing |
| Where | inside an area | in the lobby |

The run loop provides the skill and the tension. The meta loop provides the reason to log in
tomorrow. Neither works alone: Archero's own meta is thin, and Pet Sim's own activity is a
click. Putting real combat under a real collection game is the whole pitch.

---

## The lobby

A persistent hub. Players see each other, their pets trail behind them, and the progression UI
lives here. It is the first thing a new player sees, so it carries the art direction.

Contents:

- **Area portals in a row**, left to right, in unlock order. Cleared ones are open and lit.
  The next one is visibly locked with its requirement shown. Everything past that is fogged
  but *visible* — you can always see how far the game goes.
- **Egg stands**, one tier per unlocked area
- **Pet inventory / equip**, **gear**, **upgrades**
- **Rebirth plinth** (late; see below)

Seeing the locked content is the point. Pet Sim's whole engine is a visible wall with a price
on it.

---

## Area gating

**Clear an area to permanently unlock the next.** Clearing means killing the area's final boss
once. That unlock is forever and survives death, rejoin and server restart.

Each area is a complete themed package:

| | |
|---|---|
| Stages | ~20, boss every 10 (see `RESEARCH-archero.md` §2) |
| Enemies | its own roster, built from the five archetypes with new art and stats |
| Theme | its own palette and environment kit |
| Currency tier | its own coin type, worth roughly 10× the previous area's |
| Egg tier | its own egg at the lobby stand, with its own pet pool |

Replaying a cleared area is always allowed and is how you farm that tier's currency. Players
will grind area N to afford the pets that make area N+1 survivable — that back-and-forth
between the two loops is the engine.

### Gate on clearing, not on currency

Pet Sim gates zones behind a coin price. We gate on **beating the boss**. This matters: it
keeps the run loop load-bearing instead of decorative, and it means no player can buy past
content they cannot play. Currency still gates *power* (pets, gear, upgrades) — just not
*access*.

---

## Pets

Pets are the collection hook and they do double duty, which is the neatest part of the merge:
**Archero already has pets as a combat ability** (Wingman, Summon Bat). So a pet is both a
Pet-Sim-style permanent multiplier *and* a visible combat companion that shoots.

- Hatched from eggs with per-tier pools and rarity weights
- Rarities: Common → Uncommon → Rare → Epic → Legendary → Mythic, with Golden and Rainbow
  variants on top
- Each grants a **permanent damage multiplier** plus one combat behaviour (shoots, heals,
  collects gold, tanks a hit)
- Equip a limited number, say 3, so collection creates a real loadout decision
- Duplicates fuse upward, which is what makes a bad hatch still feel like progress

**Every hatch must produce something.** A dupe that fuses is a reward. A hatch that gives
nothing is the fastest way to lose a Pet Sim player.

---

## Currencies

- **Coins**, tiered per area, exponential. Area N coins ≈ 10× area N−1.
- **Gems**, premium, from bosses, first clears and Robux. Spent on hatch multipliers and
  inventory slots.
- No energy. No run gate. See `RESEARCH-archero.md` §6.

Exponential scaling is the Pet Sim feel and it is intentional, but it fights Archero's tighter
combat tuning. **The rule: numbers scale exponentially, difficulty scales linearly.** Players
should feel themselves outgrow old areas. That feeling *is* the product.

---

## Rebirth

Late addition, planned for but not early. Reset area unlocks and coins, keep pets, gain a
permanent global multiplier. It is the standard Pet Sim long-tail and the thing that keeps
month-two players. Design the save schema so rebirth can be added without a migration
nightmare — that is the only thing that matters about it right now.

---

## What this changes architecturally

**1. Persistence moves early and becomes critical.**
Area unlocks, pets, coins and gear must survive from the first playable area. DataStore with
session locking, schema versioning and migration is no longer a late phase — it lands with the
lobby. A wipe in a collection game is fatal in a way it is not in a pure roguelike.

**2. Server authority on currency is now the top exploit risk.**
Collection games are exploit magnets, far more than roguelikes. Coin grants, hatch results,
fusion and area unlocks are server-side only. The client never reports a coin total, a hatch
outcome or a clear. Hatch RNG is rolled on the server, always.

**3. The lobby is a real place with real cost.**
Persistent hub, other players, pets replicating per player, NPC shops, portal state per player.
Budget for it. Pet replication with several players each trailing three pets is a genuine
network and render load — it needs a cap and a cull.

**4. Two balance surfaces that fight each other.**
Permanent multipliers inflate while drafted abilities stay fixed. Without care, late-game
players one-shot everything and the run loop stops mattering. Area enemy stats must scale off
*expected player power at that area*, not off flat values.
