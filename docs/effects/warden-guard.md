# The Warden's guard cards — effects

The in-game effect each of the five Warden guard upgrades produces. Designed
2026-10-24 in Claude Design, one project for all five so they share a palette
and read as one family:

**https://claude.ai/design/p/cfbc9b6d-98be-4c62-851c-234804f9926f**

The props were exported one GLB per upgrade; the owner imports them by hand in
Studio (File → Import 3D). Nothing here is wired up yet: no config, no
`src/client/Fx/`. This file is the design, and the GLB is the part that has to
cross into Studio before any of it can be built.

## The language they are in

All five sit on the Warden's existing look (PR #164 for the Ruby Greatsword
kit, PR #165 for the swing streak), so they share its palette: blade crimson
with pale pink highlights, gold trim, steel grey-blue, pale ice-cyan, and a
deeper royal blue for the two defensive cards. Chunky axis-aligned cubes,
flat-shaded, hard edges, no curves and no glow meshes — the house style in
`assets/concepts/blocky/`. These are Commons and Uncommons, so each one is
small, quiet and readable rather than showy. Triangle counts run 230–528.

Two of the five are already drawn for free today and must not be redrawn.
`Fx/SwingTrail` sweeps the red ribbon over exactly the box the server checks
(`Shared/Combat/SwingBox`, `SwingSweep`), and that box is **already** grown by
Cleave's `widthScale` and Long Reach's `reachBonus`
(`Combat/AbilityEffects` lines 319–320). So the streak already gets wider and
longer when you take those cards. The props below extend that streak; they do
not replace it.

## Quick Hands — Common, +10/20/30% attack speed

**Effect.** Three pale ice-cyan chevrons, each a stepped voxel V of about seven
cubes, at descending size. They snap into existence in a short diagonal line
behind the blade's tip as a swing finishes, hold for a couple of frames and pop
out — no fade, no trail, the hard on/off the blocky style wants. One chevron at
rank 1, two at rank 2, three at rank 3, so the card's level is legible without
reading the HUD.

**Why.** Attack speed is the easiest of the five to show, because the swing
itself is already visibly faster; the chevrons only need to say *why* it is
faster. The card's icon is the red sword with three pale-blue speed ticks
trailing it, so the chevrons are literally that icon in three dimensions, which
is the shortest possible route from "what I picked" to "what I see". Keeping
them behind the tip and off the blade means they never compete with the red
streak.

Quick Hands feeds the shared attack-speed term in `Combat/AbilityEffects:296`
alongside Dual Bows and Mana Flow, so the chevrons are the Warden's own tell
for it and should not be reused by the other two.

**GLB.** `fx_quickhands.glb` — three chevron meshes, 252 triangles.

## Iron Skin — Common, −8/16/24% damage taken

**Effect, and it is both.** An on-body look *and* a flash when it saves you.

- **On-body, always while held:** four steel grey-blue voxel shield plates
  standing upright around the Warden's torso — front, back, left, right — each
  with two bright yellow rivet cubes at its top corners and a small white boss
  square dead centre. They float a little off the body with a clear gap between
  them and turn slowly with him. Semi-transparent and dim at rest, so they
  read as armour rather than as a bubble.
- **On the hit it reduces:** the plate nearest the incoming damage snaps to
  full opacity and flashes white for about a tenth of a second, then settles
  back. One plate, not all four, so the flash also tells you where you were hit
  from.

**Why both.** Iron Skin produces nothing — it is a multiplier applied at
`Run/RunSession:688` (`amount *= session.damageTaken`) and is otherwise
invisible. A card that only flashed on damage would look like it did nothing
for the whole first room; a card that only sat on the body would never prove it
was working. The standing look answers "did my pick take?" and the flash
answers "did it just do something?", and they are the same object, so the
second reads as the first firing rather than as a new effect.

The shape is taken straight from the card's icon, which is a grey-blue shield
plate with two yellow studs and a white boss — the plates are that icon,
unchanged, stood up in a square.

**GLB.** `fx_ironskin.glb` — four identical plate meshes, 528 triangles.

## Cleave — Uncommon, +15/30/45% swing width

**Effect.** A flat crimson crescent lying on the floor: a band of slabs one or
two cubes thick, sweeping about 120°, visibly thickest at the middle of the arc
and tapering to a point at both ends, pale pink along the inner edge and
crimson at the stair-stepped outer rim. It is laid down for a few frames at the
moment a side-to-side blow lands, from where the Warden stood when the slash
began, under the red streak that `Fx/SwingTrail` is already drawing.

**Why.** This is the extension case, not a replacement. The streak already
widens with `widthScale`, so the honest job is to make that extra width
*felt* rather than merely true: the crescent is the ground the wider swing now
covers, left behind for a moment after the ribbon has passed. Keeping it flat
and low means it never obscures the enemies it just hit, and keeping it the
same crimson as the streak means it reads as the same blade, not a second
effect. It should be drawn only at Cleave rank 1 and up, and grow with the box
rather than having its own size.

The card's icon is a red sword with a wide white-and-cyan crescent over it; the
crescent here is the same gesture, flattened onto the floor where the game's
top-down camera can actually see it.

**GLB.** `fx_cleave.glb` — one crescent mesh, 230 triangles.

## Long Reach — Uncommon, +1.5/3/4.5 studs reach

**Effect.** A slim tapering blade-tip segment — crimson, with a single
one-cube pale pink highlight stripe along its top edge and a chunky gold cap at
its point — that appears as a ghost extension past the real blade's tip for the
length of the swing, then vanishes with it. The segment tiles end to end: one
at rank 1, two at rank 2, three at rank 3, with a gold cap cube at each joint,
so the three ranks are three visibly longer blades. The GLB also carries the
thin gold measuring bar with square end caps that runs under the line of them.

**Why.** "A longer reach should look like the same blade covering more ground",
so this is deliberately not a beam or a projectile: it is the Warden's own
blade, in the Warden's own crimson, simply carried further, and it ends in the
same gold the sword's trim is already made of. Because the swing box is already
grown by `reachBonus` and the streak already sweeps that longer box, the ghost
segment lines up with the red the player is already seeing — the extension
explains the longer streak rather than adding a second thing to track.

The gold ruler bar comes from the card's icon, which is a red sword above a
gold measuring rod. It is exported with the prop so it can be used as a
one-off flourish when the card is first picked; it is **not** meant to be drawn
on every swing, which would be far too loud for an Uncommon.

**GLB.** `fx_longreach.glb` — three tiling blade segments plus the ruler bar,
270 triangles.

## Steadfast — Uncommon, +0.3/0.6s guard after each swing

**Effect, and it is both.** A ring and a flash, and the ring is a timer.

- **While the guard is up:** eight small royal-blue brace plates, each wider
  than it is tall with a pale ice-cyan cap and a thin gold foot, planted in a
  ring around the Warden's feet and facing outward like a palisade. They snap
  up the instant a swing starts.
- **As the guard runs out:** the plates drop one at a time, evenly spaced over
  the linger, so the ring visibly empties. The last plate drops exactly when
  the guard ends. Two plates fall before the normal swing window is over and
  the remaining six span the bonus seconds, so the part of the ring Steadfast
  bought is the part you watch disappear.
- **When it actually blocks a hit:** the plate facing the attack flashes white
  and drops out of the ring early.

**Why.** Steadfast is the hardest of the five, because the thing it modifies is
already invisible: the Warden is *already* untouchable while swinging
(`Classes.swing.guard`, `Combat/MeleeSystem:103-105`, checked at
`Run/RunSession:566`), and the card only extends that window past
`swingEndsAt`. So there is no new mechanic to show, only a duration — and a
duration is exactly what a count of eight plates can show that a glow cannot.
The player learns the shape of their own safe window by watching the ring
empty, which is the difference between "I take less damage somehow" and "I know
when I am safe". The block flash is there because a guard that never visibly
catches anything is indistinguishable from luck.

Royal blue and the pale cyan cap come from the card's icon, which is a blue
shield with pale braces down its sides; the plates are those braces, planted.

**GLB.** `fx_steadfast.glb` — eight separate plate meshes, 288 triangles.

## What is needed to build these

Every one of the five needs its GLB imported in Studio and a mesh id before any
of it can run; that import is the owner's, and cannot go over MCP. Beyond that:

- Iron Skin and Steadfast need a client signal when damage is reduced or
  blocked. The server knows both (`RunSession:688` and `RunSession:566`), but
  neither is replicated today, so a remote would have to carry it.
- Cleave and Long Reach need nothing new from the server: `SwingSweep` already
  has the grown shape, and both props hang off the markers `Fx/SwingTrail`
  already listens to.
- Quick Hands needs the swing's end, which `Fx/WeaponPose` already marks.
