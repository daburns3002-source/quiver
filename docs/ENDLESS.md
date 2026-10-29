# Endless mode

Owner, 2026-10-27: an infinite mode alongside the story, with rewards for passing certain
floors, built before co-op.

**Endless is a stage mode, not a new map.** `Balance.StageConfig.mode` already decides a run's
shape from data — `"Rooms"` walks a list, `"Waves"` holds one arena and sends waves into it.
Endless is a third value, `"Endless"`: the Waves loop with no last wave, a per-floor curve in
place of the stage's fixed `enemyDamage` / `enemyHealth`, and an arena that changes every ten
floors instead of never.

The alternative considered and rejected was a dedicated endless map. Endless is defined by its
curve, not its scenery, and a bespoke map is a lot of art for something the existing arena kits
already do. Rotating the built areas also means every area added later shows up in Endless for
free.

---

## The floor

**A floor is one wave.** A Waves stage is 20 waves at roughly 8–12 minutes
(`docs/PROGRESSION.md`), so a floor is about 30 seconds and the depths read as:

| Floor | Time in |
|---|---|
| 10 | ~5 min |
| 20 | ~10 min |
| 30 | ~15 min |
| 50 | ~25 min |
| 100 | ~50 min |

A floor-50 run is well past the story loop's 8–12 minutes. That is the point of the mode, and
it is also why every tenth floor is a place to leave: a player who wants ten minutes takes
floor 20 and banks.

### Floor kinds

Floor kind and the card draft are **orthogonal**, so there is no precedence table to get wrong:

- **Boss** — `floor % 10 == 0`
- **Mini-boss** — `floor % 5 == 0` and not a boss floor
- **Fight** — everything else

and separately, on clearing any floor where `floor % 3 == 0`, the player drafts. Floor 15 is a
mini-boss fight *and* a draft; floor 30 is a boss fight *and* a draft. A draft is never
displaced by a fight and never has to be deferred.

This replaces `Balance.Waves`'s `valkyrieAt` / `angelAt` / `bossAt` positions for this mode —
Endless gets its own `Balance.Endless` schedule block rather than bending the story one.

### The checkpoint beat

After every boss floor, a beat with no fight in it. The player picks one of three: a full heal,
an extra card, or the Endless shop. This is the Archero 2 shape and it is also where the mode's
one real decision lives — see **Bank or push** below.

---

## The curve

Compounding from floor 1, on top of the area's own values:

```
enemyHealth = 1.045 ^ (floor - 1)
enemyDamage = 1.030 ^ (floor - 1)
```

**Health grows faster than damage on purpose.** Spongy enemies are a worse run; enemies that
delete you without warning are a worse *game*. The player should always see the wall coming.

### Why not ×1.08–1.12

That rate was floated before the build curve was checked against it, and it is too steep. With
a draft every 3 floors and cards deliberately modest (~+10% effective each after the 20% cut in
PR #342), run power reaches about 2.6× by floor 30 and 4.6× by floor 50. Against ×1.10 per
floor, enemy health is 10.8× by floor 25 — the wall lands around floor 22–28, not 40–60.

At ×1.045, health is 9.0× by floor 50 against the player's 4.6×, and account power (pets,
weapons, gear) covers the rest. That puts the wall near floor 45–55 for a geared account and
deeper as the account grows, which is the hook: **your best floor is a readout of your
collection.**

These two numbers are the whole difficulty of the mode. They go in `Balance.Endless` and get
retuned from measured runs, not from feel.

### Count

Enemy count grows with the floor off the area's base, **capped** — the arena only fits so many
and the device tiers have projectile budgets (`docs/PERFORMANCE.md`). Reach the cap around
floor 30 and let the multipliers carry it from there.

### Hard floor cap

Stop at floor 200. Nothing should overflow, and the leaderboard should be bounded.

---

## Area rotation

Floors take the arena and roster of a built area, ten floors each, then loop:

| Floors | Area |
|---|---|
| 1–10 | Mossy Glade |
| 11–20 | Thornwood |
| 21–30 | Drowned Village |
| 31+ | loop, with a modifier per lap |

Each lap past the first adds one modifier — enemies fire faster, a second elite joins every
mini-boss, a floor hazard — so loop two is not loop one with bigger numbers. Modifiers are a
list in `Balance.Endless`, drawn in order so a run is reproducible.

Bosses on boss floors are the areas' own bosses, which is already how `StageConfig.finale`
works.

---

## Rewards

Two layers, because they do different jobs. Milestones get a player up the first climb;
repeatable currency keeps the mode worth replaying once the milestones are claimed.

### Milestones — one-time, per account

| Floor | Reward |
|---|---|
| 10 | a pet egg |
| 20 | a gear piece |
| 30 | a cosmetic (trail or aura) |
| 50 | a pet egg, guaranteed Legendary or better |
| 75 | a gear piece, guaranteed Legendary |
| 100 | a title, and a Mythic-tier cosmetic |

Each hits a different system on purpose, so no one milestone is skippable because you already
have enough of that thing.

### The reward set — designed, not built

Owner, 2026-10-28, with reference sheets: the Endless rewards are a matched **astral set**, two
pieces so far. Both are drawn and **nothing is modelled yet** — notes only until the owner says
to build them.

- **Astral Arc**, a bow — `assets/concepts/blocky/weapons/endless/astral_arc_views.png`.
  Front, side, back and three-quarter, a close-up of the centre star and its orbit ring, and
  four views of the star-tipped arrow that goes with it.
- **Orbit Manta**, a pet — `assets/concepts/blocky/pets/endless/orbit_manta_views.png`.
  Front, right, three-quarter, back and top, plus exploded wing layers, the ring on its own,
  and how the ring sits around the body.

They share one design language so they read as a set: black body, lavender panels, silver trim,
a hot pink four-point star and a faceted low-poly cut. Both carry a **silver orbit ring** — on
the bow around the centre star, on the pet floating around the upper body, encircling it
without intersecting. The bow sheet's material swatches are black, lavender, silver and pink.

Three things are still open:

- **Which floors they sit on.** The table above puts pet eggs at 10 and 50 and gear at 20 and
  75, and a pet and a bow fit that shape, but the owner has not said which goes where.
- **Their rarity.** Every Legendary and Mythic has to glow, and a Mythic's glow is a rainbow
  (the owner's standing rule). These sheets show a pink glow, not a rainbow, so the tier has to
  be settled before either is modelled.
- **Whether the set grows.** Two pieces cover two milestones; the table has six.

When they are built they go through the usual pipelines — the weapon pipeline for the Arc and
its arrow, the pet modelling route for the Manta — and must match these sheets 1:1 in game.

### Repeatable — at checkpoints, not per floor

Pay the currency **at each boss floor**, not per floor. Payment lands exactly where the
bank-or-push decision is, and a per-floor dribble makes the decision quieter.

Growing per block, with a per-run cap at roughly the floor-60 total. Past that, depth pays
prestige — leaderboard, milestones — and not currency. **Without the cap, Endless is a gold
firehose** the moment one account's build outruns the curve.

The currency is **Soulstones** (owner, 2026-10-27), its own, spent in an Endless-only shop, so it
never inflates the story economy (`Config/Economy` coins and gems). Stored as the version 6 save's
`soulstones`, drawn as SOULSTONES (`SaveSchema.SOULSTONES`), and paid only through `Data/Wallet`.

### Bank or push

Rewards **vest at each boss floor** and are written to the profile there, not at the end of the
run. Then:

- **Die** — keep everything vested; lose the current block's progress.
- **Leave at a checkpoint** — keep everything, including the block just cleared.

Lose it all on death and nobody pushes. Lose nothing and there is no tension. Vesting every ten
floors is the middle, and writing at the checkpoint means a disconnect costs the run but never
the rewards.

**No mid-run resume in v1.** The run is lost on disconnect; the rewards are not. Resume is a
later feature if the logs say people are dropping deep runs.

---

## Saving

`SaveSchema` version 6 (and its migration test — CLAUDE.md non-negotiable 7, never a schema
change without one):

- `endlessBest: number` — deepest floor reached, 0 until the first run
- `endlessMilestones: { [string]: boolean }` — milestones claimed, keyed by floor
- the Endless currency, alongside `coins` and `gems`

Server-owned, like every other payout (`Data/Wallet`). The client is told what floor it is on
and never reports one — floor is what the leaderboard and the milestones pay on, so a client
that could claim a floor could claim a Mythic.

---

## Where it is entered

Its own lobby portal, in the row with the areas, **unlocked by beating 1-10**. Endless with no
cards learned and no gear is a death at floor 6; clearing the first area's boss is the proof
that the mode is worth opening.

## Leaderboard

A board on `endlessBest`, following `Run/StoryLeaderboard`'s pattern and
`docs/LEADERBOARD.md`.

---

## Co-op

Endless is co-op's second mode, not its first. Everything co-op needs from Endless is in
`docs/COOP.md`; the two decisions Endless itself has to answer are there too — credit for a
floor, and what happens when a player leaves mid-run.
