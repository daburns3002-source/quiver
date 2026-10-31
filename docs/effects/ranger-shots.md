# Ranger shot upgrades — in-game effects

The five Ranger "arrow skill" cards that change *how many arrows leave the bow
and where they go*. Their icons and card art already exist
(`Config/CardAssets`, `assets/ui/glow_toy_cards/`); this is the effect each one
produces in a fight.

Designed in Claude Design from the card icons, in the blocky language of
`assets/concepts/blocky/` — axis-aligned cubes, flat shading, hard edges,
saturated colour, vertex colours and no textures. Rarity sets the volume:
Legendary gold is the loudest, Uncommon green the quietest.

All five live in one Claude Design project so the family stays coherent —
same voxel arrow, same cube grammar, same trail vocabulary:

**https://claude.ai/design/p/80cf431a-763b-431c-b565-d6eafad7d8ab** — *Arrow Legends VFX Upgrades*

The shared arrow, used by every effect: a red nock cube, five mid-brown shaft
cubes banded darker, and a three-cube stepped white chevron head — the arrow
drawn on the cards. It flies along +Z, because the Studio importer brings
models in facing +Z.

Wiring these into `src/client/Fx/` is a later pass. **Nothing in this PR
touches config or Fx** — the GLBs are handed to the owner for import, and the
mesh ids come back afterwards.

## The problem these five share

Four of the five change the *count or spread* of arrows, and the arrows
themselves are identical. Without a per-upgrade signature a player sees "more
arrows" and cannot tell Multishot from Double Shot from Front Arrow in a
fight. So each effect gets one unmistakable shape:

| upgrade | the shape | reads as |
|---|---|---|
| Multishot | a gold **lane** the volleys ride, one behind the next | same line, staggered in time |
| Front Arrow | purple **rails**, dead parallel, never converging | side by side |
| Double Shot | a blue **wedge** that opens, ground fan widening | diverging |
| Rear Arrow | a short green **back dash** | one goes the other way |
| Ricochet | a purple **dog-leg** and a red-and-white target snap | it bounced |

---

## Multishot — Legendary

`Count` · `levels = { 1, 2, 3 }` · +1/+2/+3 arrows · icon `multishot`

**What it does.** `Stages.repeatVolley(n, Balance.Projectile.multishotInterval)`
— the whole volley again, `0.12 s` later, down the exact same aim line, once
per level.

**Effect, persistent.** Not a moment: it is true of every shot while the card
is held, and the thing to communicate is a rhythm, not an event. A repeat of
an identical volley reads as nothing but a faster fire rate unless the repeats
are visibly *linked*, so the arrows share a visual track.

**The design.** A flat gold lane of cubes is laid along the firing line and the
staggered arrows ride it, each trailing three shrinking translucent gold
ghosts, the lane brightening under each one as it passes. At the bow a gold
ring of eight cubes flashes on fire and a stack of gold chevrons pops
outward — one chevron per repeat, so the card's level is legible from the
muzzle alone. Gold `#FFC53D` / `#FF9F1C` / `#FFF0B8`, matching the Legendary
card frame; the loudest of the five, as its rarity should be.

**The design as built.** Three arrows strung out along one line with clear
gaps, all on screen together — the staggering *is* the effect, so it has to be
visible as a whole. A thin dashed gold trail behind each, and three distinct
stepped gold chevrons beside the bow, one per repeat, so the card's level
reads from the muzzle. An early pass laid a full-length gold "lane" for the
arrows to ride; from the game camera it became a twenty-tile runway that
swamped the arrows, and it was cut back to per-arrow dashes.

**GLB:** `fx_multishot.glb` — 456 tris, 17 nodes, clip `Multishot` (1.1 s)

---

## Ricochet — Epic

`OnHit` · `levels = { 2, 3, 4 }` · 2/3/4 bounces · icon `ricochet`

**What it does.** `Stages.ricochet(n)` — on hit, the arrow jumps to another
enemy within `Balance.Projectile.ricochetRange` (14 studs) at
`ricochetDamageScale` (0.7) of its damage, up to n times.

**Animation, a moment.** The only one of the five that is an event rather than
a state. Nothing about the arrow in flight is different; what matters is the
instant it changes its mind at a body, and the second enemy that did not
expect it. A persistent treatment would waste itself on flight time and say
nothing at the bounce.

**The design.** The arrow strikes, ten small yellow spark cubes scatter, and a
purple kinked path draws itself from the impact to the next target as a dashed
line of cubes with a hard angle at the corner — a dog-leg, never a curve,
because a curve would read as homing. A purple chevron caret flips direction
at the kink. At the far end the card's own red-and-white voxel target square
snaps onto the next enemy, flashes and shrinks away, which is the icon's
loudest element and makes the card and the effect the same object.
Purple `#A855F7` / `#6D28D9` / `#F0ABFC` with yellow sparks `#FFD43B`.

**The design as built.** The arrow strikes, sticks at the impact point, and
ten yellow spark cubes scatter. A purple dashed dog-leg draws itself to the
next target, the arrow re-launches along it, and the red-and-white target
square snaps on, flashes and shrinks away. The white hit flash was oversized
on the first pass and swallowed both the arrow and the target; it is a third
of that now.

**GLB:** `fx_ricochet.glb` — 900 tris, 32 nodes, clip `Ricochet` (1.0 s)

---

## Front Arrow — Epic

`Count` · `levels = { 1, 2, 3 }` · +1/+2/+3 front · icon `front-arrow`

**What it does.** `Stages.parallel(1 + n, Balance.Projectile.parallelSpacing)`
— extra arrows *beside* the first, `0.85` studs apart, not fanned, so the whole
volley lands in the enemy the player aimed at.

**Effect, persistent.** Parallel is a property of every volley, and it is
exactly the property a player could mistake for Double Shot. The whole job is
to make "beside" and "spreading" look nothing alike.

**The design.** The rails. Each arrow sits over its own thin flat purple rail
of ground cubes running dead straight to the horizon, and the rails never
converge — held against Double Shot's widening ground fan the difference is
immediate, even at a glance. The added arrows wear purple nocks in place of
red and a small purple fletching cube, so the extras are countable in flight.
At the bow a purple bracket of cubes spans the full lane width, a flat voxel
staple, and snaps open as the volley leaves. Same Epic purple as Ricochet —
shared rarity, shared palette, different shape.

**The design as built.** Three identical arrows abreast, flying in lockstep at
a constant 0.85 apart, with a purple bracket at the bow spanning their width
and a short four-cube dash behind each. The long ground rails from the first
pass are **gone**: perspective makes any pair of long parallel lines converge
toward the horizon, which says the exact opposite of what the card does.
Parallelism is carried by the three arrows themselves holding their spacing.

**GLB:** `fx_frontarrow.glb` — 432 tris, 18 nodes, clip `FrontArrow` (1.0 s)

---

## Double Shot — Rare

`Pattern` · `levels = { 2, 3 }` · 2-way/3-way spread · icon `double-shot`

**What it does.** `Stages.spread(n, Balance.Projectile.doubleShotSpread)` — a
narrow fan, 9° apart, from one point.

**Effect, persistent.** As with Front Arrow, it is how every shot leaves the
bow. The signature has to be divergence, and it has to be visible at the
range the player actually fights at, where 9° is a small angle.

**The design.** The wedge. A blue voxel chevron flashes at the bow and opens
to the fan angle — the card icon exactly: two arrows rising out of a single
red base cube in a V. Behind the arrows a faint blue fan of ground cubes
spreads and *widens with distance*, which exaggerates 9° into something
readable without lying about where the arrows go. Each arrow trails two small
blue cubes. Blue `#3B82F6` / `#1D4ED8` / `#BFDBFE`, pitched below the two
Epics: the wedge flash is bright, the trails are not.

**The design as built.** A blue voxel V anchored on the red 2x2 base block,
held for the whole clip rather than flashing and vanishing — it is the card's
signature and the clearest "one origin, two directions" cue there is. A short
ground wedge widens under the arrows, and the outer two arrows drift apart
faster than their 9° headings alone would carry them, so the gap between them
is visibly wider at the end than at the start. True headings stay at −9°, 0°
and +9° so the aim is honest; only the read is exaggerated.

**Why that was needed.** Front Arrow and Double Shot are the pair most likely
to be confused, and on the first two passes they were: three arrows abreast,
drifting away, almost evenly spaced. 18° over a few studs is nearly nothing on
screen. Front Arrow's three never change their spacing and Double Shot's
always do — that, plus blue against purple, is what separates them.

**GLB:** `fx_doubleshot.glb` — 696 tris, 35 nodes, clip `DoubleShot` (0.9 s)

---

## Rear Arrow — Uncommon

`Pattern` · `levels = { 1, 2 }` · +1/+2 rear · icon `rear-arrow`

**What it does.**
`Stages.mirror("RearArrow", around(math.pi, n, Balance.Projectile.extraArrowSpread))`
— the volley again behind the player, 180° around, extra copies 12° apart.

**Effect, persistent, and deliberately quiet.** Uncommon. It should be
noticeable the first time and then sit in the background; a loud backwards
effect would fight the player's attention with the thing they are aiming at,
which is in front of them.

**The design.** The back flash. One arrow forward, one backward wearing green
fletching and a yellow stepped head — the card icon has a white head one way
and a yellow head the other, which is the clearest single cue that something
left in the opposite direction. A small green chevron at the bow points
backwards and pulses once. The ground dash behind the player is four cubes
long, far shorter and dimmer than the other four trails. Green `#4ADE80` /
`#16A34A` / `#DCFCE7`.

**The design as built.** The icon's column, standing up in the world: white
stepped head forward, red nock, the blue centre block at the bow, red nock,
and a green-fletched arrow with a yellow stepped head going the other way.
Both arrows stay in frame for the whole clip. An earlier pass took "quiet" too
far and left two green dashes and nothing else — quiet means small and clean,
not absent.

**GLB:** `fx_reararrow.glb` — 492 tris, 9 nodes, clip `RearArrow` (0.8 s)

---

## Technical notes for the import

All five files were checked after export, not just exported:

| GLB | tris | nodes | clip | channels |
|---|---|---|---|---|
| `fx_multishot.glb` | 456 | 17 | `Multishot` | 21 |
| `fx_ricochet.glb` | 900 | 32 | `Ricochet` | 77 |
| `fx_frontarrow.glb` | 432 | 18 | `FrontArrow` | 19 |
| `fx_doubleshot.glb` | 696 | 35 | `DoubleShot` | 38 |
| `fx_reararrow.glb` | 492 | 9 | `RearArrow` | 10 |

- Every rig animates **node transforms only** — `translation`, `rotation` and
  `scale` channels on named nodes, and **no skins in any of the five**. That is
  what `tools/glb_clips_to_luau.py` and `Fx/ModelAnimator` read
  (PIPELINES.md §10).
- Vertex colours, no textures, so the mesh parts come in white and take their
  colour from the mesh itself, as the enemy models do.
- All five are well under the 2500-triangle budget.
- Everything points along +Z for the importer's +Z facing.
- Because nothing changes colour or opacity (transform-only), flashes are
  quick scale pops and pieces leave by shrinking to ~0 scale rather than
  fading. Worth knowing before anyone tries to tune them.
- **A GLB does not record whether a clip loops.** Four of these loop;
  `Ricochet` plays once and holds. That has to be set on the Roblox side.
- Multishot is about 7.4 units end to end — three 2.08-unit arrows in a line
  with gaps between them do not fit in less. The other four sit inside about
  6 units.
