# Broodsplit Blade (Warden greatsword, Epic) — redone to the Timber Blade's standard

The owner judged the Timber Blade good and asked for every other greatsword
to be redone, one agent per sword. This is the Broodsplit Blade, the Epic
(`docs/PETS-FOREST.md`), rebuilt fresh from its sheet
`assets/concepts/blocky/weapons/skins/forest/broodsplit_blade_views.png`.

- **Claude Design project:** https://claude.ai/design/p/a003d834-2691-4181-bd3d-7f34eee179d2
- **GLB:** `wpn_broodsplit_blade.glb` in the owner's Downloads (replaces the
  PR #213 export of the same name)
- Timber Blade for comparison: `assets/models/weapons/blocky/timber_blade.glb`,
  project https://claude.ai/design/p/934f0379-c0ab-4064-8e6f-8800e0bf43b0

## What makes the Timber Blade work (the checklist)

Measured from `timber_blade.glb` (Y up, blade along +Y, faces along ±Z):

1. **One skeleton, exact numbers.** Pommel bottom at y = 0, tip at 1.26.
   Pommel 0–0.15, gold band 0.15–0.175, grip 0.17–0.355, gold collar
   0.35–0.38, guard bar 0.412–0.498, end blocks 0.38–0.53, housing
   0.39–0.52, blade 0.498–1.13, tip 1.13–1.26. Overall 0.48 × 1.26 × 0.15.
2. **The blade is a slab, not a sheet:** 0.20 wide, 0.075 thick, so it
   still has mass edge-on and from above.
3. **A broken, blocky silhouette:** three chamfered 0.024 notches per edge
   and a separate faceted cap for the point.
4. **Chunky guard:** a bar with big chamfered end blocks standing above and
   below it, and a two-tier stepped housing in the middle carrying a
   gold-framed gem on both faces.
5. **Readable hilt bands:** gold collar and gold band bracketing a wrapped
   grip with a few wide crossing straps, not a dense braid.
6. **Pommel as a block:** an octagonal prism with a gold cross, ring and
   gem on both faces.
7. **Flat colours, one material per role** (~15), ~2,200 triangles, every
   part touching the sword, nothing floating.
8. **Two-tone faces** (a light bevel on the upper part) give it shape at
   game distance without textures.

## The new model

Three rounds in Claude Design: the build from both sheets with every
dimension given, one round of fixes against the sheet, and one round that
changed only the export (UVs). It has the Timber Blade's skeleton number for
number and is dressed as the sheet shows:

- a dark purple stone frame with lighter faceted bevels and three notches per
  edge, around a glowing lime slime core that runs unbroken into the point;
- four baby slime cubes with faces set into the core, on both faces;
- a lime seam down both edges, so the glow shows edge-on and from above, as on
  the sheet's SIDE and TOP views;
- faceted purple guard end blocks with red end gems, lime bracket inlays on
  the bar, and the charcoal two-tier housing with a gold-framed ruby;
- a purple leather grip with four wide and four thin crossing wraps between
  gold bands;
- an octagonal charcoal-purple pommel with a gold-ringed ruby, lime slits and
  side gems.

Export: 2,638 triangles, 61 named meshes under a root `broodsplit_blade`,
17 flat-colour materials (emissive on the slime), POSITION, NORMAL and
TEXCOORD_0 on every primitive. Bounds are 0.486 × 1.26 × 0.15, with the
pommel bottom at y = 0, the same frame as `timber_blade.glb`.

The sheet's floating green cubes are left out of the model on purpose. If
they are wanted, they belong in a particle emitter on the held sword. As
geometry they would be detached specks.

Self-review: I checked it against the sheet in FRONT, BACK, LEFT, TOP and
3/4, and against `timber_blade.glb` in flat-shaded renders from the front,
the side and the top-down game camera. It reads as the object on the sheet,
and it stands beside the Timber Blade as the same sword re-dressed. At game
distance the green core, the purple frame and the red gems all read.

## What changed against the previous Broodsplit Blade (PR #213), and why

The owner didn't say what was wrong with it. Measured against
`timber_blade.glb`, these are the clear reasons:

| Previous | Now | Why it matters |
| --- | --- | --- |
| Origin at the guard: y −0.30 to 0.96 | Pommel bottom at y = 0, tip at 1.26, like Timber | Swapping skins must not move the sword in the hand. |
| Blade 0.04 thick, a flat sheet: a needle edge-on | 0.075 slab, the Timber thickness | It had no mass from the side or from the top-down camera. |
| Straight smooth rails, no notches | Three chamfered notches per edge, faceted bevels | The sheet and the Timber Blade both have the broken, blocky edge. The old one read as a generic sci-fi bar. |
| Slime faces were 0.04 cubes with tiny features | 0.07 cubes, bright, with 0.016 eyes | The "brood" in Broodsplit was invisible at game distance. |
| Eight floating 0.02 specks around the blade | None (a particle effect if wanted) | Detached geometry welded to a held weapon reads as noise, and it is not a Timber-family build. |
| Guard bar 0.28 wide with drum-shaped end caps | 0.40 bar with chamfered blocks to the full 0.48 | It matches the Timber guard and the sheet's chunky end blocks. |
| No glow edge-on | Lime seam down both edges | The sheet's SIDE and TOP views show it, and it keeps the Epic glow readable from above. |
| Translucent slime (alpha 0.78) | Opaque emissive slime | All materials are opaque like Timber's, so it imports the same way. The glow comes from emissive colour. |

For the owner's import, as with the other Claude Design weapons: File →
Import 3D. The colour is in the materials, not textures.
