# Greatsword redo B — Emberfang Blade

The owner judged the Timber Blade (Common) good and asked for every other
Warden greatsword to be redone to its standard. This session redid the
**Emberfang Blade** (Legendary). Gladeheart (Mythic) moved to its own session
mid-way; Mossstone, Thorn and Broodsplit are redo A.

## The Timber Blade checklist

Studied from `assets/models/weapons/blocky/timber_blade.glb`, its sheet
`assets/concepts/blocky/weapons/skins/forest/timber_blade_views.jpg` and its
Claude Design project ("Timber Blade 3D Model",
https://claude.ai/design/p/934f0379-c0ab-4064-8e6f-8800e0bf43b0), which got
there over nine rounds of numeric corrections against the sheet.

1. **One skeleton.** 1.26 long, pommel bottom at y = 0, tip apex at 1.26,
   flats on ±Z. Guard 0.48 wide; blade 0.20 wide × 0.075 thick, 0.64 long
   plus a 0.13 point; grip 0.08 thick; pommel 0.19 × 0.15. The blade is
   about 40 % of the guard's width, so it reads as a *greatsword*, not a rapier.
2. **Few, big parts.** Blade, point, guard bar, two end blocks, housing,
   gem, collar, grip, band, pommel. Every part is a box or a chamfered prism;
   nothing smaller than about 0.02, nothing floating.
3. **Three materials and one accent.** Honey wood, charcoal stone, gold
   trim, and one red gem repeated at guard and pommel. Each part has at most
   a light face, a mid bevel and a dark side. No noise, no mosaic.
4. **Depth by layering, not texture.** The fuller is a real groove between
   face plates; the steel point sits proud of the wood; the housing stands
   above and below the bar. Detail reads in the side view too.
5. **Chunky guard ends.** The 0.095 × 0.15 end blocks give the silhouette a
   clear cross from every angle, which is what survives the top-down camera.
6. **Symmetric and two-faced.** Same gems and trim on the back.
7. **Checked in fixed views** (FRONT, BACK, LEFT, TOP, 3/4 buttons), not a
   turntable.

## Emberfang Blade (Legendary)

### Why the previous version read worse than the Timber Blade

Measured from the old `wpn_emberfang_blade.glb` (PR #213) against
`timber_blade.glb`; the owner gave no reason, so these are mine.

- **Thinner than the Common sword.** Blade body 0.16 wide × 0.05 thick
  against the Timber Blade's 0.20 × 0.075, and a 0.064 grip against 0.08.
  The Legendary looked weaker than the Common in the hand.
- **Pixel-mosaic lava.** The core was four colours of ~0.01 cells (about 400
  faces of noise). From the game camera it blurs into one orange smear,
  where the Timber Blade's fuller is one clean groove.
- **Gold the wrong colour.** `#D87D0F` orange-brown instead of the sheet's
  yellow gold (`#FED364` / `#F1BC49`), so frame, studs, head and lava all
  merged into orange with no contrast.
- **Floating ember cubes.** Seven loose cubes beside the blade. The sheet
  draws them only in its 3/4 view as an effect; in a mesh they import as
  solid chunks hanging in the air. The Timber Blade has nothing detached.
- **Near-black grip.** `#450303` / `#1A0202` instead of the sheet's red, so
  the hilt vanished.
- **Different pivot.** The origin sat at the guard (y −0.30 to 0.96)
  instead of the pommel bottom (0 to 1.26) like the Timber Blade.
- **Small horns, flat head.** The beast head was a shallow plate, so the
  guard didn't read as a face from above or from the side.

### The redo

- **Claude Design project:** "Emberfang Blade Design",
  https://claude.ai/design/p/b4e859e0-f3da-4ad8-b595-4acfa7e407d0
  (file `Emberfang Blade.html`). It has FRONT / BACK / LEFT / TOP / 3/4
  views, **GAME** (our camera: 68° down, 40° lens, from `Balance.Camera`),
  **GAME FLAT** (the same camera on the sword lying flat, as it is seen
  mid-swing) and a **TIMBER** toggle that stands the Timber Blade beside it
  at the same scale, copied from its project and kept out of the export.
- **GLB:** `C:\Users\dabur\Downloads\wpn_emberfang_blade.glb`, which replaces
  the old one. It is 0.48 × 1.26 × 0.15, with the pommel bottom at y = 0 and
  flats on ±Z like the Timber Blade. 1,738 triangles, 37 named parts
  (`blade_rail_L/R`, `lava_core`, `guard_horn_L/R`, `guard_fist_L/R`,
  `pommel_gem_front`, …), material colours, no vertex colours or textures.
  Part vertices sit in sword space with no node offsets, the same as
  `timber_blade.glb`.
- Built fresh from `emberfang_blade_views.png` with a numeric brief, the way
  the Timber Blade was, then three rounds of corrections against the sheet
  and the Timber Blade side by side.

What changed against the previous version, and why:

| | Previous | Redo | Why |
|---|---|---|---|
| Blade | 0.16 × 0.05 | 0.19 × 0.08 | At least as chunky as the Common blade |
| Lava | ~400-face, four-colour mosaic | Red base, a zigzag of 9 orange blocks, 6 hot blocks inside it, a dark lip | Reads as fire from the game camera instead of mush |
| Edge | Flat | Raised gold spine with red lines either side | The sheet's side view; detail in LEFT, as on the Timber |
| Studs | Scattered small cubes | The sheet's 5 + 6, as cubes 0.035–0.05 that pass through the blade | Clean saw-tooth silhouette |
| Gold | `#D87D0F` orange-brown | `#FDCB3E` / `#F0AD32` / `#DF8318` | The sheet's yellow gold, so it contrasts with the lava |
| Head | Shallow plate | 0.15 deep, stepped crest, brows, cheeks, charcoal snout standing 0.03 proud, glowing eyes | Reads as a Wilf face from the front and side |
| Horns | Small | Tapered 0.065 → 0.035, tips at (±0.19, 0.54) | Visible in FRONT, 3/4 and GAME |
| Guard ends | Thin red claws | Red fists 0.08 cube + 0.045 × 0.13 block, chamfered | As heavy as the Timber's 0.095 × 0.15 end blocks; the cross reads at game distance |
| Grip | 0.064, near-black | 0.08 octagon, `#AA2124` with four raised bands | The Timber's thickness and the sheet's red |
| Pommel | 0.18 | 0.17 × 0.14 charcoal octagon, gold clasps, 0.075 ruby on both faces | Same build and gem size as the Timber pommel |
| Embers | Seven floating cubes | None | Nothing detached, as on the Timber; embers are an effect, not mesh |
| Origin | At the guard (y −0.30 to 0.96) | At the pommel bottom (0 to 1.26) | Same pivot as the Timber Blade |

Self-review against the sheet and the Timber Blade: it is the sheet's object
(gold-framed lava blade, studded edges, horned Wilf head, red fists on a
charcoal bar, banded red grip, charcoal pommel with a red diamond), and next
to the Timber Blade it has the same skeleton, the same box-built
construction, the same three-tone parts and a guard and pommel at least as
heavy. Only the gold, lava and head make it the grander one. In GAME view it
reads as a bold yellow sword with a red core and red fists, stronger than the
Timber. In GAME FLAT the studs show as a saw-toothed edge, which the sheet
intends. The one thing left: the studs still look a little wider than tall
from the front.

For the owner's import: the colours are materials, not vertex colours, the
same as `timber_blade.glb`. The lava and eyes are emissive (lava about 0.6,
eyes 1.0).
