# Difficulty within a stage

Owner, 2026-10-27: "mossy glade is a little bit too hard early in the level and a little too
easy late in the level, that is a theme present throughout the levels. i think there needs to be
some sort of nerf on the early health of enemies and then a scaling difficulty throughout the
level kind of like endless."

---

## The bug

`StageConfig.enemyDamage` and `enemyHealth` are **one constant for a whole stage**, applied in
`Enemies/EnemyManager.difficulty()`. Across Mossy Glade they step up level by level:

| Level | Mode | Waves | `enemyDamage` | `enemyHealth` |
|---|---|---|---|---|
| 1-1 | Rooms | — | 0.75 | 1.1 |
| 1-2 | Rooms | — | 0.78 | 1.2 |
| 1-3 | Rooms | — | 0.81 | 1.3 |
| 1-4 | Rooms | — | 0.84 | 1.4 |
| 1-5 | Waves | 20 | 0.87 | 1.5 |
| 1-6 | Waves | 20 | 0.90 | 1.6 |
| 1-7 | Waves | 20 | 0.93 | 1.7 |
| 1-8 | Waves | 20 | 0.96 | 1.8 |
| 1-9 | Waves | 20 | 0.99 | 1.9 |
| 1-10 | Waves | 25 | 1.02 | 2.0 |

A clean line **between** levels and a flat line **inside** each one. That flat line is the
whole problem: a player enters 1-5 with no cards drafted and meets the full 1.5× health, then
twenty waves later meets exactly the same 1.5× with a built loadout. The difficulty is tuned
for the middle of the stage, so it is too hard at the start and too easy at the end — and
because every level is shaped the same way, so is every level.

Endless already solved this. It does not have a stage constant; it reads a curve per floor
(`Run/Waves.floorCurve`, `docs/ENDLESS.md`). Story stages should read a curve per wave or room
the same way.

---

## The fix

Keep each stage's existing value as its **baseline**, and ramp a factor across the stage on top
of it. One global curve in `Balance`, not ten hand-tuned pairs — the shape is wrong in every
level, so the fix belongs in one place.

```
Balance.StageCurve = {
    healthStart = 0.75,  healthEnd = 1.30,
    damageStart = 0.85,  damageEnd = 1.12,
    shape = 0.5,
    bossesExempt = true,
}
```

```
progress = (index - 1) / (total - 1)             -- 0 at the first, 1 at the last
factor   = start * (end / start) ^ progress ^ shape
health   = stage.enemyHealth * healthFactor(progress)
damage   = stage.enemyDamage * damageFactor(progress)
```

with `shape = 0.5`. `index` is the wave number in a Waves stage and the room number in a Rooms
stage; `total` is `waves` or `#rooms`. A one-room stage has `progress = 1`.

`shape` front-loads the ramp. At `shape = 1.0` it is plain geometric interpolation — a constant
rate, the same shape Endless uses. Below 1.0 the ramp rises faster early and flattens late.
**It is 0.5 here because the player's build also arrives front-loaded**, which the next section
measures. Endless keeps the constant rate because its drafts come every 3 floors forever, so
cards accrue linearly there and a constant enemy rate is the right match. Different card curve,
different shape — the two modes differ for a reason rather than by accident.

### How fast the build actually grows

The ramp only makes sense against the player's own curve, so that was measured rather than
guessed. `Config/Progression`: level 2 costs 28 XP and each level after costs ×1.25 the last,
capped at level 20. Common enemies pay 10–20 XP (`EnemyConfig.xpReward`), and 1-5 is 20 waves
of 4–7 enemies, so roughly 110 kills and ~1650 XP across the stage — about **level 13, so 12
cards**. The absolute count is an estimate; the shape below is not, because it comes from the
×1.25 cost growth rather than from the XP total.

| Through the stage | Cards held | Build power |
|---|---|---|
| start | 0 | 1.00× |
| 10% | 4 | 1.36× |
| 25% | 7 | 1.71× |
| 50% | 9–10 | 2.07× |
| 75% | 11 | 2.33× |
| end | 12 | 2.52× |

**A third of a level's cards arrive in its first 10%.** Geometric XP costs mean levels come
almost immediately at first and crawl by the end, so power more than doubles in the first half
and then flattens.

Dividing enemy health by build power gives what the stage actually feels like — higher is
harder:

| Through the stage | Today (flat) | Ramped |
|---|---|---|
| start | 1.00 | 0.75 |
| 10% | 0.74 | 0.65 |
| 25% | 0.58 | 0.58 |
| 50% | 0.48 | 0.54 |
| 75% | 0.43 | 0.52 |
| end | 0.40 | 0.52 |

Today a level gets **60% easier** from its first wave to its last, monotonically — the hardest
moment of any level is its opening, which is precisely the complaint. The ramp cuts that to
31% and holds it steady over the back half, so a level still rewards the build without going
slack.

This is also why `shape` is 0.5 rather than 1.0. At a constant rate the enemy ramp lags the
card rush, difficulty bottoms out at 0.48 around the middle and then rises to 0.52 — making
the *middle* of the level the easiest part, which is a subtler version of the same bug. The
front-loaded ramp is monotonic.

### Why these numbers

**The geometric mean stays near 1.0.** `sqrt(0.75 × 1.30) = 0.99` for health and
`sqrt(0.85 × 1.12) = 0.98` for damage. The owner said "a little" twice, so this is a **tilt,
not a nerf** — the middle of every level lands almost exactly where it is tuned today, and only
the ends move. That also means no level needs its baseline retuned.

**Health tilts further than damage** (±27% against ±13%), the same reasoning as Endless: a
spongy opening is a worse *run*, but getting deleted in wave 1 is a worse *game*. Early health
is also exactly what the owner asked to nerf.

**0.75 is not arbitrary.** 1-1's health baseline is 1.1, so its opening becomes
`1.1 × 0.75 = 0.83` — within a rounding error of the old `Level 1` value of 0.8, which is what
the stage was eased to after the owner's 2026-10-22 playtest ("the difficulty is still too
high"). The curve lands the first thing a new player fights back on the number that already
tested well.

### Bosses are exempt

A boss takes its stage's **baseline**, not the ramped value. Bosses sit at or near
`progress = 1`, so ramping them would put King Bloblin at `2.0 × 1.30 = 2.6×` health — a 30%
boss buff nobody asked for, on a fight that has been tuned by hand. Applies to `Boss`,
`Elite` and `finale` waves.

The cost is a dip at the end of 1-10: wave 24 ramps to 2.57 and the boss sits at 2.00. The
front-loaded shape makes that dip slightly worse than a constant rate would. Still the right
trade — the boss has its own mechanics, banner and intro hold, and the alternative is silently
rebalancing every boss in the game. If it reads badly in playtest, the fix is a separate
`bossFactor` on top of the baseline, tuned per boss, not folding bosses into the ramp.

---

## Worked examples

**1-5** — baseline 1.5 health, 0.87 damage, 20 waves:

| Wave | Health | vs today | Damage |
|---|---|---|---|
| 1 | 1.13 | −25% | 0.74 |
| 5 | 1.45 | −3% | 0.84 |
| 10 | 1.64 | +9% | 0.89 |
| 20 | 1.95 | +30% | 0.97 |

**1-10** — baseline 2.0 health, 25 waves:

| Wave | Health | Note |
|---|---|---|
| 1 | 1.50 | |
| 7 | 1.98 | ≈ today's flat value, a quarter in |
| 13 | 2.21 | |
| 24 | 2.57 | last ramped wave |
| 25 | 2.00 | King Bloblin, exempt |

Note what the front-loading does to where the stage crosses its old value: a quarter of the way
in, not halfway. The early relief is real but short, which is the intent — it covers the window
where the player has no cards.

---

## What was actually built (2026-10-31)

**Not the geometric curve above.** Codex's combat pass had already added half of
this — `CombatTuning.roomHealthPerEncounter`, a linear +2% per encounter applied
in `EnemyManager.difficulty()` off a `CombatEncounter` workspace attribute that
`RoomController` already maintains. Adding a second, geometric ramp on top would
have double-counted, and the owner's standing rule is that Codex's work stays.

So the existing mechanism was extended rather than replaced:

- `roomHealthStart = 0.75` — the missing "starts easier" half. The first
  encounter now sits below the stage's own number instead of on it.
- `roomHealthPerEncounter` 0.02 to 0.029, so the end of a 20-wave level still
  lands at 1.30 despite the lower start.
- The `area == "MossyGlade"` gate is gone. The flat-difficulty problem was every
  level's, not one area's.
- **Bosses keep the stage's own number.** They sit at the end of the ramp, and
  1-10's King Bloblin at `2.0 x 1.30` would be a 30% buff nobody asked for.

Over a 20-wave level: 0.75 at wave 1, about 1.0 at wave 10, 1.30 at wave 20.

**What this gives up against the design above:** the ramp is linear, not
front-loaded by `progress ^ 0.5`. The measured card curve says a third of a
level's cards arrive in its first 10%, so a linear ramp still lags the player
early and the middle of a level stays its easiest stretch. That is a smaller
error than it was — the start is 25% lower, which is where the mismatch hurt
most — but it is not gone. Front-loading is a one-line change to the same
constant if playtesting says the middle still sags.

## Where it goes

One hook, already built. `Enemies/EnemyManager.difficulty()` currently returns the stage
constants for a Rooms or Waves stage and `Waves.floorCurve(floor)` for an Endless run. The
change is to make the non-Endless branch read a stage curve instead of a constant:

- `src/shared/Config/Balance.luau` — the `StageCurve` block
- `src/server/Run/Waves.luau` — `stageCurve(index, total)` beside `floorCurve`, pure and
  unit-tested like the rest of that module
- `src/server/Enemies/EnemyManager.luau` — `difficulty()` reads it; needs the current
  wave/room index, which `Util/CurrentStage` already tracks for the HUD
- `tests/` — the curve's ends, its midpoint near 1.0, the boss exemption, and the
  one-room edge case

No save schema change, so no migration.

## Ordering

This needs `Balance.luau`, `Waves.luau` and `EnemyManager.luau` — all three touched by the
Endless work. **It lands after the Endless PR**, and it reuses that PR's curve machinery rather
than adding a parallel one.

## The other lever

The ramp attacks early difficulty from the enemy side. There is a second lever on the player
side, and it is arguably the more direct one: **wave 1 is hard because the player has zero
cards.** Granting a card at the start of a stage, or making the first level-up nearly free,
fixes the opening without touching enemy health at all.

There is precedent both ways. `baseLevelCost` was already cut from 40 to 28 and
`levelCostGrowth` from ×1.35 to ×1.25 on the owner's 2026-10-22 ask for faster levelling, so
this lever has been pulled once. And `Config/Tutorial.levelUpIn = { 3 }` already grants owed XP
to force a level-up at a chosen room, so the machinery for "level up here" exists.

Not folded into this change, deliberately — two difficulty levers moving in one PR cannot be
told apart in playtest. Ramp first, measure, then decide whether the opening still needs a free
card.

## Open

Once this is in, the per-level baselines in the table above are worth a second look. The
between-level line (+0.1 health per level) was drawn to carry the whole difficulty by itself;
with a ramp inside each level doing part of that job, the step between levels may want to be
flatter. Tune from playtest, not from arithmetic.

`shape` is the number least grounded in evidence here. 0.5 matches the measured card curve, but
the card curve itself rests on an estimated XP total per stage. Worth logging actual level-ups
per stage in playtest and refitting.
