# Arcanist orb upgrades — in-game effects

The five upgrades that modify the Arcanist's orbs. Designed in Claude Design,
2026-10-24, in the blocky language: faceted, flat-shaded, hard-edged, navy
outline shells, saturated blues.

All five live in one Claude Design project, because they share a canvas and had
to be judged stacked rather than one at a time:

**[Arcanist Orb FX](https://claude.ai/design/p/3840a4ee-86b9-445f-9b5f-eef89423c767)**

The GLBs are exported to the owner's Downloads folder. They are not in the repo
and nothing here is wired up — meshes are imported by hand in Studio.

## Palette

Sampled from the real card icons in `assets/concepts/icons/`, not eyeballed:

| role | hex |
|---|---|
| core deep blue | `#021DB1` |
| mid blue | `#0059FC` |
| bright blue | `#0077FB` |
| cyan | `#26BBFC` |
| pale cyan | `#8CFAFB` |
| white specular | `#FFFFFF` |
| outline navy | `#000436` |
| target red | `#FF2635` |

## Homing Orbs — `TrackingEye`, Legendary

`fx_trackingeye.glb` · clip `TrackingEye_Flight`

**Animation**, not an effect. `Stages.homing` curves the orb toward the nearest
enemy, so the upgrade *is* the flight path — anything that doesn't move over
time cannot show it. A static decal on the orb would say "this orb is special"
without saying what it does.

Two parts. On the projectile, a comet tail of six shrinking faceted cyan wedges
(`Tail_1`..`Tail_6`) laid along the orb's actual path, each overlapping the one
ahead so the tail reads as one continuous bending ribbon rather than a line of
separate darts. The orb leaves the staff aimed off to one side of the target and
visibly bends in; a curve that starts straight at the target reads as no homing
at all. On the target, `Crosshair_Ring` — a red low-segment torus with four
chunky prongs and a centre bead, spinning slowly, with the same navy outline
shell as the orbs.

The crosshair is the Legendary volume. It is drawn **once per target, not once
per orb**, which is what keeps it from multiplying into noise under Twin Cast.

## Bigger Orbs — `BiggerOrbs`, Common

`fx_biggerorbs.glb` · clips `BiggerOrbs_Impact_L1` / `_L2` / `_L3`

**Effect**, on impact. `BiggerOrbs` multiplies the `Stages.splash` radius and
touches nothing about flight, so the cue belongs at the point of contact:
`BiggerOrbs_BlastShell`, an icosahedron-detail-1 dome in saturated cyan that
expands once and pops, with four chevrons at the cardinals
(`BiggerOrbs_Chevron_N/E/S/W`) echoing the four arrows on the card icon.

A separate clip per level, because the card's whole content is the radius — the
shell has to visibly grow, and a single clip scaled at runtime loses the
facet proportions.

Restrained, as a Common should be: the shell and the four chevrons, nothing
else. The orb itself only grows slightly. The first pass had a dense dome that
read as a smooth bubble and out-shouted the Legendary crosshair; it was dropped
to detail 1 and a smaller base radius so the facets are countable and a Common
stays quieter than a Legendary.

## Mana Flow — `ManaFlow`, Common

`fx_manaflow.glb` · clips `ManaFlow_Cast_L1` / `_L2` / `_L3`

**Effect**, on the caster — deliberately *not* a projectile change. `ManaFlow`
only feeds `attackSpeed`; it changes how often orbs leave, never what an orb is.
Putting a mark on the orb would be a lie about the mechanic, and would also
spend the orb's limited visual budget, which the other four upgrades need.

Three chunky faceted teardrops (`ManaFlow_Droplet_1..3`) orbit the staff crystal
in open air, each trailing a flat cyan streak wedge behind it along the orbit —
the fat droplet and speed-streaks of the card icon, in blocky form. The orbit
runs faster per level, so cast speed reads as literal speed. One droplet flicks
off down the lane on each cast, which is the only moment it touches the lane.

The orbit ring is lifted clear of the caster's body at every point, so the
droplets read as orbiting rather than stuck into the robe.

## Twin Cast — `TwinCast`, Rare

`fx_twincast.glb` · clip `TwinCast_Spawn`

**Effect**, at spawn. `TwinCast` feeds `Stages.parallel`, putting extra orbs
*beside* the first in the same instant. So the read is lateral and simultaneous:
`Orb_Twin_L` and `Orb_Twin_R`, two solid orbs of **equal size and equal
brightness** side by side across the lane, joined for about 0.15s by
`TwinLink_L`, a faceted cyan bar that stretches between them and snaps.

The link bar is the "both at once" tell, and it is the thing that stops Twin
Cast being confused with Arcane Echo in the first frame, before the timing
difference has had a chance to show.

## Arcane Echo — `ArcaneEcho`, Rare

`fx_arcaneecho.glb` · clip `ArcaneEcho_Repeat`

**Effect**, delayed. `ArcaneEcho` feeds `Stages.repeatVolley` — the same cast
again, a moment later. The read is in-line and temporal: `Echo_Ghost`, the same
faceted silhouette at the same size as the lead orb, but pale, translucent, no
white specular, only a thin cyan outline shell, following **on the same line**
and arriving late. `Echo_Ripple` is a faceted ring left at the lead orb's spawn
point that the ghost passes through, so the repeat has a fixed landmark.

The ghost must stay recognisably the *same orb*. An early pass made it a soft
flat disc, which read as a different object; it was rebuilt from the orb's own
geometry so a player sees "that orb again, fainter".

## Telling them apart, and stacking

The three that touch the projectile were given three different axes, which is
what lets them stack:

| upgrade | axis | reads as |
|---|---|---|
| Twin Cast | **lateral** — across the lane | two equal orbs, side by side, at once |
| Homing Orbs | **longitudinal** — along the path | one bending saturated tail, attached |
| Arcane Echo | **temporal** — behind in time | a pale detached copy, in line, late |

Twin Cast and Arcane Echo both add projectiles and are the pair most at risk of
blurring. They are separated three ways at once: *equal vs dimmer*, *beside vs
behind*, *simultaneous vs delayed*. Any one of the three carries the read on its
own, so the distinction survives a small phone screen.

**All three at once** is two bright orbs side by side, each with its own bending
tail, each followed by its own pale ghost. The volley composes the way the
pipeline does: `Stages.parallel` widens the lane first and `Stages.repeatVolley`
repeats the widened lane, so an echo of a two-orb cast is **two** ghosts, one per
lane — not one ghost floating down the middle, which would read as a third
projectile that does not exist. The homing tail is likewise per-orb.

The one real collision risk is the tail and the ghost both occupying the space
behind an orb. They are held apart by material and attachment: the tail is
saturated cyan and welded to the orb, the ghost is pale and separated by a clear
gap.

The other two never collide with anything. Mana Flow lives on the caster, and
Bigger Orbs only appears at the moment of impact, after flight is over.

## Notes for import

- Every GLB holds one lane. The second lane in the preview is preview-only.
- Outline shells are inside-out meshes, not a backface trick, so they survive
  export. On the translucent pieces (the blast dome, the echo ghost) only the
  outer edge of the outline shows; depending on how Roblox sorts transparent
  parts, the inner edge may show through on import and need darkening.
- Materials are flat-shaded Lambert in the preview, exported as non-metallic
  PBR of the same colour. No textures.
- Animation moves position, rotation and scale only. Opacity fades are
  preview-only — GLB animation cannot carry them, and they are not faked by
  scaling to zero.
