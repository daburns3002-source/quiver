# Fixes

A running log of bugs that actually shipped, newest first.

Entries are written to be found by **symptom**, because that is what you have
when one recurs — usually a sentence from a playtest, not a stack trace. Each
one names what the player saw, what was actually wrong, what was done, and the
measurement that showed it worked. A fix without a number in it is a claim.

Two things make this worth keeping. The same classes of bug recur here:
projectile hit detection has broken three separate times, enemy steering
twice. And **every single one of these was green on all four CI gates** —
Selene, StyLua, `rojo build` and `luau-lsp` — because they were geometry or
state, which no type and no lint can see. If a symptom below shows up again,
start from the cause recorded here rather than from the code.

---

## Abilities did nothing, and arrows stopped connecting

**Symptom** — two complaints, one cause: "the player projectiles are missing
again" and "the abilities dont actually change what is happening".

**Cause** — the client draws its own predicted volley and deliberately skips
the server's copy to avoid double-drawing. Its pipeline was never given the
loadout, so it drew **one unbuffed arrow for the whole run** while the server
fired the real ones at angles nothing on screen reflected. The arrow the
player watched was not one of the arrows that existed — so abilities appeared
to do nothing, and shots appeared to pass through enemies that a different,
invisible arrow was busy killing.

`LocalFiring` had carried a comment since Phase 1 saying precisely this would
happen if Phase 3 did not replicate the stage list. Phase 3 did not.

**Fix** — `ClientStats` now carries the ability stack counts and the attack
cooldown. Stages are functions and cannot replicate; counts can, and
`AbilityEffects.stages` rebuilds the identical pipeline on either side. The
prediction rebuilds on every grant rather than per volley.

**Measured** — server arrows fired versus arrows actually drawn, over one
window with Front Arrow taken: **99 fired / 21 drawn (21%) → 112 fired / 112
drawn (100%)**, every volley two-arrow.

**Watch for** — anything the client predicts. Movement, firing rate and volley
shape are all predicted here, so every one of them needs its inputs
replicated. `tests/AbilityEffects.spec.luau` now pins the contract: whatever
`clientStats` carries must rebuild the server's volley exactly.

---

## Prediction froze for the rest of the run after one draft

**Symptom** — found while verifying the fix above, not reported: after a card
screen, the client drew almost nothing.

**Cause** — the pause that stops the client predicting during a draft was
lifted in the card button's own callback. Any choice that did not go through
that click — and any click that was missed — left prediction paused for ever,
while the server went on firing arrows nobody could see.

**Fix** — resume on the next `PlayerStats` from the server instead. The server
sends it on every grant and every run reset, so it means "the world is running
again" however the choice was made. The button still clears it too.

**Measured** — choosing by remote without touching the button: 21% agreement
before, 100% after, with 0 phantom arrows drawn during a deliberate one-second
pause on the card screen.

**Watch for** — any client state whose *exit* depends on a UI callback. The
entry can be a UI event; the exit has to be something authoritative, or a
single missed input strands the player.

---

## All three draft cards drawn on top of each other

**Symptom** — a level-up offered what looked like one card. The other two were
behind it, exactly aligned.

**Cause** — `clearCards` used `ClearAllChildren` on the card holder, which
destroyed the `UIListLayout` along with the cards. `show` clears before it
builds, so this bit on the *first* offer and every one after: with no layout,
three cards sized `UDim2.new(1, 0, 0, 108)` all resolve to the same position.

**Fix** — clear only the `TextButton`s and leave the layout alone.

**Measured** — before: 3 cards, 1 distinct Y position, no layout present.
After: 3 cards at y = 296 / 418 / 540, spaced by exactly the card height plus
the configured padding, layout intact. Confirmed on a *second* consecutive
offer, since that is the path that clears an existing screen.

**Watch for** — any Roblox UI built once and refilled later. `ClearAllChildren`
takes the constraints, layouts and corners with it, and the result is not an
error — it is a layout that silently stops applying.

---

## A passing test run against code Studio was not running

**Symptom** — the in-Roblox suite passed with a plausible test count while
newly added specs were silently not running at all.

**Cause** — `rojo serve` keeps its process alive after the Studio plugin has
stopped being connected to it; branch switching triggers this. Studio then
goes on running whatever it had when the link broke. Nothing reports an error
at any layer: the suite runs, the old specs pass, and the count only looks
wrong if you already know what it should be.

**Fix** — none in code; this is a procedure. After any branch switch or
`rojo serve` restart, verify the link before trusting an in-Roblox result:
read the `.Source` of a file you just changed and check the change is in it.
Restarting `rojo serve` drops the plugin and reconnecting is a manual click in
Studio.

**Measured** — a suite reporting `PASS — 89 tests` while two new specs worth
31 tests were absent from `ServerStorage.Tests` entirely. The same probe after
reconnecting reported 120.

**Watch for** — any in-Roblox result that does not change when you expect it
to. The stale read is the default failure here, not the exception.

---

## Lurker surfaced outside its own warning marker

**Symptom** — "im not sure when it is disappearing and when it is coming back".

**Cause** — The ground marker was sent from wherever the Lurker was when the
0.75s warning began, and then it *kept travelling underground for the whole
warning*. At burrow speed that is about ten studs, against a marker 6.5 studs
across. So it routinely came up nowhere near the circle it had just drawn.

**Fix** — The marker is a promise, so the trip now ends when the promise is
made: the position is resolved out of any obstacle and frozen, and the
underground steering is gated on `surfaceTold`. See `EnemyManager.stepEnemy`.

**Measured** — distance from marker centre to where it actually surfaced:

| | mean | worst | surfaced fully outside the marker |
|---|---|---|---|
| before | 6.14 studs | **27.24** | 3 of 10 |
| after | 0.24 studs | 0.40 | 0 of 8 |

**Watch for** — any future "it hit me and I was not warned" report about the
Lurker. The counterplay is entirely "step off the circle", so a marker that
lies costs this archetype its whole reason to exist.

---

## Enemies standing inside each other

**Symptom** — visible clipping once archetypes got bodies; two merged
silhouettes read as one target.

**Cause** — Separation existed, but only as a soft force folded into an
enemy's *desired heading*, so it applied **only while the enemy was moving**.
Once one reached its hold distance it stopped, the steering stopped being
applied, and nothing pushed it back out of whatever it had drifted into. It
also used a flat 3.5 studs, which is narrower than a Bulwark.

**Fix** — A positional pass after the step loop that guarantees bodies never
intersect, measuring against real hitbox sizes, pushing both halves of a pair
back through `Arena.resolve` so a pair against a wall is not separated through
it. It is a nudge per frame rather than a snap, so crowds settle. The old
steering is kept: it keeps a moving group loose, this stops bodies merging.

**Measured** — overlapping pairs per frame, across 1801 frames: **348 → 38**,
worst remaining penetration 1 stud (bodies grazing while converging).

---

## Player arrows passed through enemies

**Symptom** — "sometimes the projectile hits the enemy and it does not damage
it", and "sometimes it damages the enemy and then goes through it".

**Cause** — **A shape cast ignores anything it already intersects when it
starts.** The arrow's box is 4.2 studs long and centred on the simulated
point, so there is a 2.1-stud region in front of it the sweep cannot see into,
while one frame of travel is only 0.93 studs. Measured: a target overlapping
the box by 0.1 studs reports a clean miss, and so does one dead centre.

Nothing static can get in there — a pillar's gap shrinks by exactly one frame
of travel per frame, so the sweep always catches it. A *moving* target can: a
Charger closes at 63.5 studs/s against a sweep covering the arrow's own 0.93,
so the gap goes from positive to deep inside the box between two frames. From
then on the box carries the enemy along inside itself.

**Fix** — The overlap pass already existed and already did the right thing; it
was gated to run once at spawn. It now runs every step. The client mirrors it,
which fixed the second symptom — the server stopped the shot and the renderer
did not. Separately `EnemyManager.damage` reported whether it *killed* rather
than whether it *landed*, and the caller discarded that and returned true
regardless.

**Measured** — drawn-arrow frames whose centre sat inside an enemy hitbox:
**46 of 1271 (3.61%) → 0 of 1284**, worst single arrow 8 frames → 0.

**Watch for** — this is the third time hit detection has broken. Any
"projectiles do not connect" report starts here. `tests/HitDetection.spec.luau`
pins the engine behaviour the fix compensates for.

---

## Enemy bodies could have broken hit detection

**Symptom** — none yet; this is the trap that was avoided when archetypes got
bodies.

**Cause** — Giving an enemy decorative parts makes it very easy for one of
them to answer raycasts, which silently widens the hitbox the whole combat
system is built on.

**Fix** — The hitbox is invisible and remains the only queryable part. Every
skin part has `CanQuery` off and is welded to the hitbox, so the shape the
server sweeps is unchanged.

**Measured** — in a live room: 0 skin parts answering raycasts, hitbox sizes
unchanged, 0 studs of drift between skin and hitbox after 2.5s of walking.
`tests/EnemyDesigns.spec.luau` additionally enforces that a body fits inside
its hitbox *and* fills it — both directions are the same complaint, since a
body wider than its box gives shots that visibly connect and do nothing, and a
body smaller gives shots that visibly miss and damage anyway. It caught the
Lancer at 59% of its own width on the first run.

---

## Earlier fixes

These predate this log and are recorded in `CLAUDE.md` under "What first run
fixed" and "Testing over MCP, learned the hard way":

- **Chargers deadlocked against pillars**, soft-locking the room. The normal
  was measured at the probe point rather than at the body, and the slide side
  was re-decided every frame.
- **The Burrower dived exactly once.** The dive gate and the hold distance
  were the same number.
- **Waves spawned on top of the player.** Rooms are populated before any
  session exists, so the exclusion check measured against an empty list.
- **Room 1 ate every arrow** — 41 of 45 player shots hit an obstacle placed
  across the spawn's sight-line. The test written for that change checked that
  the room stayed uncleared, which passed *because nothing could be hit*. The
  wrong thing was verified.
- **Enemy projectiles vanished into walls** on the client, because the
  renderer used one filter containing arena blockers for every faction, while
  the server flies enemy shots straight over them.
