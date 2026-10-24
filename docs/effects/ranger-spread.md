# Ranger spread upgrades — in-game effects

The five Ranger spread and flight upgrades, and what each one looks like in a
fight. Designed in Claude Design in the blocky house language — chunky voxel
cubes on an integer grid, flat-shaded, hard-edged, flat saturated colour baked
per face, no textures and no smoothing. Every piece is centred at the origin,
faces −Z (the arrow's direction of travel), and stays under 2,000 triangles.
Colour is stored per vertex in the GLB, so the mesh parts stay white in Studio
exactly as the enemy models do.

All five live in one Claude Design project, a page each:
**[Arrow Legends voxel effects](https://claude.ai/design/p/f23f9c65-1d2c-4d41-ae87-a7de4dec24c6)**.

The GLBs are in the owner's Downloads folder and are imported in Studio by
hand. Nothing here is wired up yet — no `Config` change, nothing under
`src/client/Fx/`. This file is the design, not the implementation.

Rarity reads through loudness. In a line-up the Epic (Piercing Shot) grabs the
eye first and the Common (Swift Arrows) last.

---

## Side Arrow — `SideArrows`

**Uncommon.** Also fire arrows to your left and right
(`Stages.mirror` at ±90°, one or two arrows each side).

**Effect**, fired once at the bow the instant the shot leaves — not a trail.
The ability changes *where* arrows go rather than how they fly, so the tell
belongs at the moment of firing: a flare that snaps out, holds a few frames and
fades. A flat bar of stepped cubes lying along the X axis only, a stubby
arrow-chevron at each end pointing straight out to +X and −X, and a pale lime
core cube at the centre. Grass green and pale lime; two arms, deliberately
quiet, because it is the cheaper of the two pattern cards.

It is the same double-ended arrow the card's icon shows, read in three
dimensions, which is what makes it legible without being read.

**Telling it from Diagonal Arrows at a glance:** this one is a *flat green bar*
on one axis. That one is a *blue four-arm X*. Different shape, different
colour, different arm count — no overlap.

- Page: [fx_sidearrows](https://claude.ai/design/p/f23f9c65-1d2c-4d41-ae87-a7de4dec24c6?file=fx_sidearrows.html)
- GLB: `fx_sidearrows.glb`

## Diagonal Arrows — `DiagonalArrows`

**Rare.** Also fire arrows at diagonal angles — a pair at
`Balance.Projectile.diagonalAngle` (30°), and at level 2 a second pair at the
wide angle (45°).

**Effect**, same family as Side Arrow and for the same reason: the card changes
the spawn pattern, so it tells at the muzzle. A four-armed X-shaped burst,
each arm a stepped chevron of cubes running out along the 45° diagonals in the
XZ plane, with short spark rays at 30° and 60° beside each arm — the two angles
the ability actually fires at — and a pale cyan core cube. Electric blue and
pale cyan, and noticeably bigger and brighter than the green flare, which is
the rarity speaking.

- Page: [fx_diagonalarrows](https://claude.ai/design/p/f23f9c65-1d2c-4d41-ae87-a7de4dec24c6?file=fx_diagonalarrows.html)
- GLB: `fx_diagonalarrows.glb`

## Piercing Shot — `PiercingShot`

**Epic.** Arrows pass through enemies — one, two, or all of them
(`Stages.pierce`).

**Effect**, spawned at the enemy at the moment of pass-through, one per enemy
pierced. Everything that makes this card good happens in that instant, so
that is where the whole budget goes.

A hard-edged square aperture of cubes standing upright across the arrow's path,
its middle blazing white-hot — the brightest thing in the set — with a hot
magenta lip running all the way round the inside edge so the ring looks like it
is burning through. The four corners of the ring are broken outward, each with
a magenta leading face. Eight or nine chunky angular shards spray out of the
**exit** side, away from the shooter, fanning wider as they go, each with a
white-hot leading face. Violet, magenta and white-hot.

The card's icon is an arrow driving clean through a solid block with chunks
coming off it; this is that, in the round. The square silhouette is the thing
that has to survive a glance, so the shards are few and chunky rather than a
scatter — an earlier pass was louder but read as a generic starburst and was
rebuilt.

- Page: [fx_piercingshot](https://claude.ai/design/p/f23f9c65-1d2c-4d41-ae87-a7de4dec24c6?file=fx_piercingshot.html)
- GLB: `fx_piercingshot.glb`

## Swift Arrows — `SwiftArrows`

**Common.** Arrows travel faster, +15% a level up to +75%
(`Stages.scale` on `speed`).

**Animation**, not a one-shot: this card changes how an arrow *flies*, and it
is true for the whole flight, so it has to ride the arrow the whole way. A
short tapering chain of three or four flat cube slabs stepping down in size
along +Z behind the arrowhead, plus two thin horizontal streak bars offset to
either side — the speed lines the card's icon draws. Pale ice cyan and white.
Completely flat, small and clean: it is the quietest piece of the five, as a
Common should be, and it stacks to five levels, so it must not shout.

**Telling it from Long Shot:** Swift is flat, thin and uniformly cyan, the same
all the way along. Long Shot grows and heats.

- Page: [fx_swiftarrows](https://claude.ai/design/p/f23f9c65-1d2c-4d41-ae87-a7de4dec24c6?file=fx_swiftarrows.html)
- GLB: `fx_swiftarrows.glb`

## Long Shot — `LongShot`

**Uncommon.** Damage rises with distance travelled, from nothing at point blank
to the full bonus at `Balance.Projectile.farRange` (30 studs) and beyond
(`Stages.farDamage`).

**Animation**, and it has to do something no other trail does: show the shot
*charging*. The card's whole idea is that the arrow is worth more the further
it has gone, so the trail reads as building power rather than as motion. A low
stepped ladder along +Z that starts as a single thin pale ice-cyan rung at the
far tail and grows rung by rung — a little wider and a step taller every few
rungs — toward the arrowhead, never more than three units tall. The colour
ramps cleanly along its length: pale ice cyan at the tail, white through the
middle, hot amber, then a red-hot head finished with a chunky red ring of cubes
around a white centre cube — the target mark the card's icon carries, and the
thing a player should recognise. Small bright grass-green accent pips on the
rungs tie it to Uncommon without muddying the heat ramp.

A first pass built this taller and shorter and it read as a stacked pyramid,
not a trail; it was rebuilt long and shallow.

- Page: [fx_longshot](https://claude.ai/design/p/f23f9c65-1d2c-4d41-ae87-a7de4dec24c6?file=fx_longshot.html)
- GLB: `fx_longshot.glb`

---

## For the owner

- The five GLBs are in Downloads, named `fx_sidearrows.glb`,
  `fx_diagonalarrows.glb`, `fx_piercingshot.glb`, `fx_swiftarrows.glb` and
  `fx_longshot.glb`. They need importing by hand in Studio (File → Import 3D),
  which cannot go over MCP.
- Each viewer page has a reference arrow toggle so the two trails can be judged
  against an arrow. **The reference arrow is never part of the export** — the
  GLBs contain the effect only.
- Worth checking on the first import that Roblox keeps the vertex colours, as
  it does for the enemy meshes.
- Claude Design is moving to Artifacts and this version stops working on
  2026-12-14, so these project pages have a shelf life.
