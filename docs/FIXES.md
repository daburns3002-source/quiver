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

## The walls flickered while moving

**Symptom** — "the walls is clipping when moving". The side walls and the
wall-top corners shimmered, only while the camera moved.

**Cause** — z-fighting from the art pass's dressing. The lamp columns were
exactly as thick as the side walls and centred on them, so each column's
faces lay in the same planes as the wall's faces, in a different colour. The
side wall caps ran the full room length and overlapped the end caps at all
four corners, with their tops in one plane. Two opaque coplanar faces have no
front; the renderer's answer flips as the view changes. (The default
baseplate did the same to the floor in Phase 1 — see `clearDefaultBaseplate`.)

**Fix** — the columns stand 0.2 studs proud of the wall on both faces, as
pilasters, and the side caps stop where the end caps begin.

**Measured** — a probe of the live arena for overlapping coplanar visible
faces found 28 before (both faces of all ten columns against their walls,
and the cap tops and ends at the corners) and 0 after.
`Arena.spec` now fails if any two visible arena parts share a face.

---

## Knocked-back enemies left their bodies behind

**Symptom** — "the enemy models are not following the ring that is getting
knocked back". The target ring slid away with the hit; the body stayed put.

**Cause** — the knockback slide and the end-of-frame separation moved the
hitbox with `hitbox.Position = …`. A WeldConstraint only carries its other
parts when a part's **CFrame** is set; a Position write moves the hitbox
alone and silently re-welds the body at the new offset. So the body stayed
offset for the rest of the enemy's life, and arrows struck an invisible box
beside the visible enemy. The old instant knockback had the same bug, just
too fast to notice.

**Fix** — every move goes through `placeHitbox`, which sets the CFrame
(position plus the enemy's turn). Knockback back to 3 studs at the same
time (owner's call).

**Measured** — 0.000 studs of drift between body and hitbox across 38,320
body-part samples with 12 knockback hits. `tests/EnemyModel.spec.luau` pins
both that CFrame carries the body and that Position does not.

**Watch for** — any new `hitbox.Position =` on an enemy. Set CFrame.

---

## The killing blow showed no damage number

**Symptom** — found while restyling damage numbers: the hit that finished an
enemy drew no number, so the strongest moment of a fight was the invisible
one.

**Cause** — `EnemyManager.damage` fires `EnemyHit` only while the enemy
survives; a killing blow fires `EnemyDied` instead, which carried only a
position.

**Fix** — `EnemyDied` carries the blow's amount and kind, and the client
draws it like any other hit.

**Measured** — 10 of 10 kills drew a number in a clean run; with crits and
burns on, killing blows arrived as Hit 2, Crit 7, Burn 2 and every one was
drawn in its own style.

---

## Turned enemies' hitbox corners poked into pillars

**Symptom** — found by a clipping probe, not reported: hitbox corners up to
0.62 studs inside pillars.

**Cause** — `Arena.resolve` kept an enemy's *centre* half a hitbox from a
face, which is exact only while the square hitbox is square-on. It turns
with the enemy, and at 45° a corner sits 2.12 studs from the centre.

**Fix** — `Arena.resolveBox` takes per-axis half-widths; enemies resolve by
their footprint at their current turn, again after turning each frame, and
in knockback and the end-of-frame separation.

**Measured** — 0 hitbox corners inside a pillar across 2,819 enemy samples
in 5 rooms (was up to 0.62 studs). 173 tests pass, including a turned square
at 0/20/45/70° ending clear of a pillar.

**Watch for** — the Bulwark in Teeth: turned 45° it needs 8.49 studs and one
channel there is 8.4. It is squeezed, never unshootable. And probes: see the
`GetPartBoundsInBox` note in `CLAUDE.md`.

---

## Enemy orbs crawled at a third of the reference's speed

**Symptom** — measured, not reported: Spitter and Lurker orbs at 4–4.4
studs/s, against 0.27–0.40 room-widths a second (~12 studs/s) in the
footage. The Spitter's own comment asked for the teardown's 8–20 band.

**Cause** — the same as the arrows: scaled down with the room rather than
measured, twice over.

**Fix** — Spitter and Lurker 12, Lancer 14 → 28 (the footage's fast red
shot, one sample). Each lifetime adjusted so reach is unchanged: only speed
moved.

**Measured** — tracked in the footage with camera drift removed (static
objects read 2–10 px/s, so the correction holds). In Studio, the Lancer's
drawn orbs measured 27.5–27.8 studs/s, and none was drawn overlapping
the player across 162 orb frames.

**Watch for** — difficulty. These are the biggest single jump enemy fire
has had, and the Lurker's point-blank fan now arrives about 0.15 s after
its tell instead of 0.45 s.

---

## Arrows did not stop at the enemy's hitbox

**Symptom** — "make the projectiles stop when they hit the hitbox of the
enemy". Mostly the arrow vanished before it reached the enemy it hit.

**Cause** — two halves. The flight left a stopped arrow with its *centre* on
the contact point, half its length inside the body. And the renderer released
the part on the same frame the flight ended, so the stop was never drawn: at
190 studs/s the last frame shown could be three studs short.

**Fix** — a projectile that stops is left where its box first touches, with
its tip on the surface (`RaycastResult.Distance` along the cast). One that
carries on (pierce, bounce, a body already struck) still moves to the contact
point, inside, because left merely touching, every following cast finds the
same body again and the arrow stalls on its surface. The renderer draws a
stopped arrow for one more frame before releasing it.

**Measured** — `ProjectileFlight.spec` checks that a 190 studs/s arrow stops
with its tip within 0.05 studs of the body's face.

---

## Bouncing and piercing arrows stopped dead on screen

**Symptom** — found auditing the projectile code against the reference video,
not reported. With Ricochet (then a wall bounce) or Piercing Shot, drawn
arrows stopped at the first wall or enemy, while damage kept landing further
on with nothing visible causing it.

**Cause** — two flights. `ProjectileSystem` bounced and pierced;
`ProjectileRenderer` had its own simpler step that stopped every arrow at its
first contact, whatever the loadout. The same class of bug as #25: the client
showing a different shot from the one the server fired.

**Fix** — one flight. `Shared/Combat/ProjectileFlight` holds the sweep, the
overlap pass, bounces and pierce, and both sides step through it, answering
contacts through a `Contact` table: damage on the server, a spark on the
client. Server-invented shots (chain, ricochet) carry the body they leave
from, so the drawn arrow does not stop inside it.

**Measured** — loadout of Ricochet 2, Bouncy Wall 2, Piercing Shot 1 and
Diagonal Arrows: 185 drawn wall bounces and 13 drawn ricochets in 2,838 arrow
frames. In a clean run, 0 of 98 arrow frames inside an enemy, with 48 hits
from 63 volleys. `tests/ProjectileFlight.spec.luau` pins bounce, pierce,
the ignored source body and footage-speed hits.

**Watch for** — any change to how a projectile moves made in
`ProjectileSystem` or `ProjectileRenderer` instead of `ProjectileFlight`.

---

## Arrows ten times slower than the reference

**Symptom** — "make sure that projectiles are reacting the same as the video".
Measured at 1080p, 60 fps: Archero 2's arrows cross about 5.5 room-widths a
second. Ours did 0.5.

**Cause** — the speed was scaled down with the room when the room was rebuilt
to Archero 2's proportions, rather than measured. Speed was never in the
measurements table, so nothing caught it.

**Fix** — `Projectile.speed` 17.4 → 190, lifetime held at 45 studs of reach.
At that speed an arrow covers more than its own length a frame, which breaks
the overlap pass's assumption, so `ProjectileFlight` sub-steps flight at
`maxStepTravel` (1.2 studs, under half an arrow). The arrow trail became a
length (4 studs) rather than a lifetime, or it draws across half the room.

**Measured** — 160 tests pass, including a 190-studs/s arrow at 30 fps
landing on a body in its path and a body appearing inside a fast arrow.

**Watch for** — `maxStepTravel` reaching half the arrow's length:
`HitDetection.spec` fails at exactly 1.5, and it should.

---

## Ricochet bounced off walls; Archero 2's bounces between enemies

**Symptom** — the video's card reads "Bullets can bounce between monsters,
+1 bounce". Ours bounced off walls.

**Fix** — Ricochet now fires a new arrow from the point of contact to the
nearest enemy this chain has not struck, within `ricochetRange` (14), at
`ricochetDamageScale` (0.7). The wall bounce survives as its own card,
Bouncy Wall. Diagonal Arrows narrowed from ±45° to the footage's ±30°.

**Measured** — 19 ricochets announced in one run, each leaving 3.4–4.4 studs
from the centre of the enemy it hit, which is the surface of a 3-stud body.

---

## A shot enemy could be knocked into another for a frame

**Symptom** — found while verifying the larger room, not reported: four
overlap frames in one run, one of them 1.8 studs deep.

**Cause** — frame order. Separation ran at the end of the enemy step, but
projectiles resolve *after* that, and a hit knocks its enemy back two studs —
often into whatever is behind it. The overlap then stood until the next
frame's separation.

**Fix** — separation moved to its own call, `EnemyManager.resolveOverlaps`,
run last in the server loop after everything that can move a body.

**Measured** — before: 4 overlap frames, worst 1.8 studs. After: 0 overlap
frames across 1,921 with 12 knockback hits in the run. Not a controlled A/B —
the hit count before was not recorded — but consistent with the cause.

**Watch for** — anything new that moves an enemy (a pull, a push, a
teleport). If it runs after `resolveOverlaps`, it reopens this.

---

## Enemies spawned standing inside each other

**Symptom** — found while verifying the move to Archero's proportions, not
reported: 102 overlapping enemy-pair frames in one run, where the old room
showed almost none.

**Cause** — the spawn scan kept new enemies away from *players* and nothing
else, so two members of one wave could be picked from neighbouring grid cells
and arrive inside each other. In a ninety-stud room that was rare enough to
hide. At 28 studs wide it happened every wave. A second cause sat behind it:
the separation pass only closed a quarter of an overlap per side per frame,
and in a small room where everything converges on the player, steering
pushed bodies back together faster than that.

**Fix** — `clearOfEnemies` in the spawn scan, so a wave's members are placed
apart from each other as well as from the player; and separation now
resolves the whole overlap each frame, leaving bodies exactly touching.

**Measured** — one run: 260 brushing frames, worst 0.66 studs deep. After:
worst **0.014 studs** — floating-point touching — and 0 frames reaching even
a quarter-stud.

**Watch for** — any change that makes rooms smaller or more crowded. Density
is what exposes this, not code.

---

## The Bulwark copied the player's movements

**Symptom** — "there is a bug on level 4 where the giant enemy mirrors the
movement of the player". Room 4 is the first room with a Bulwark in it.

**Cause** — not its movement. Measured: at range it chases normally, two to
three studs a second, loosely towards the player. The problem was *facing*.
Every enemy snapped to face the player every frame with `CFrame.lookAt`, and
the Bulwark's shield is wider than its body — so the whole slab swung in
exact step with every move the player made. Strafing past it at six studs, it
turned up to 30.7° in a single frame and 315° in three seconds. The player
could also walk inside its hitbox, since enemies deliberately do not collide
with the player, and crossing its centre flipped it straight round.

**Fix** — a `turnRate` per archetype in `Balance`, and facing turns towards
the player by at most that much per second instead of snapping. The Bulwark
turns at 90°/s; a Charger at 540. Facing is presentation only — every shot is
aimed separately — so this changes how an enemy looks, never how hard it is
to dodge.

**Measured** — the same close-range strafe, before and after: largest
single-frame turn **30.7° → 3.1°**, the remainder being two server frames
arriving together over replication. It now trails the player at its cap
rather than tracking them exactly.

**Watch for** — any enemy that seems to copy the player. Check the facing
before the steering. `tests/Balance.spec.luau` requires every archetype to
turn and none to snap, and no bigger enemy to turn faster than a smaller one.

---

## Front Arrow's extra arrows missed the target they were aimed at

**Symptom** — "the front arrow upgrade should not go out in a v shape it
should be one next to the other in a straight line parallel, make sure they
are close enough so both will hit the target".

**Cause** — Front Arrow was built on `Stages.spread`, an angular fan. A fan
separates with distance, so at range only the centre arrow reaches the enemy
every arrow was aimed at. Archero 2 renders the same upgrade as a tight
parallel lane, confirmed from the reference footage.

**Fix** — a `lateralOffset` on the spec and a `Stages.parallel` that offsets
extra arrows sideways on the same heading. `ShotPipeline.spawnPoint` places
them, and the server, the client's prediction and the renderer all call it,
so the lane is a lane in the simulation *and* on screen.

**Measured** — live, one stack: two arrows both on angle 0, starting 0.84–0.85
studs apart against a configured 0.85, centred on the aim line.
`tests/AbilityEffects.spec.luau` holds the full four-stack lane inside the
narrowest enemy's hitbox, so widening the spacing far enough to miss again
fails a test.

---

## Blast Arrows exploded invisibly

**Symptom** — "the bomb upgrade needs to be more pronounced so the player
knows that the bomb is exploding".

**Cause** — splash damage was applied server-side with no event at all, so
enemies near the target simply died for no visible reason.

**Fix** — an `Explosion` remote carrying the real radius, and a client effect
in two parts: a ground ring that snaps to the true radius and only fades,
because the area *is* the information, and a core flash that expands so it
reads as a detonation. Light shake, gated on tier.

**Measured** — 17 explosions fired, 17 rings drawn, at the radius one stack
grants.

---

## The player could walk around behind the upgrade screen

**Symptom** — "make sure when the player levels up and unlocks an upgrade
that they cant move when the upgrade screen is there".

**Cause** — the server froze the world and the client froze firing
prediction, but movement and the dash read neither. The player crossed a room
nothing else was running in, and reappeared elsewhere on choosing.

**Fix** — one `RunPaused` flag on the client, read by movement, prediction and
the dash, rather than three copies of it. Movement is actively told
`Move(zero)` so the Humanoid does not coast.

**Measured** — partially. `tests/RunPaused.spec.luau` pins the flag, but the
movement half needs real input and `VirtualInputManager` is capability-blocked
over MCP, so walking behind the cards has been reasoned about rather than
driven. If it still happens, the wiring in `MoveController.step` is where to
look.

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
