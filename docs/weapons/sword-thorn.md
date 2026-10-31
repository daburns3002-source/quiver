# Thorn Blade (Rare greatsword skin), redone

The owner judged the Timber Blade good and asked for every other Warden
greatsword to be redone to its standard. This is the Thorn Blade, Rare, from
`assets/concepts/blocky/weapons/skins/forest/thorn_blade_views.png`.

- **Claude Design project:** https://claude.ai/design/p/ff191c1b-30eb-407d-8264-da409bde1cc4
- **GLB:** `wpn_thorn_blade.glb` in the owner's Downloads (replaces PR #213's file)

## What makes the Timber Blade work (the checklist)

Read from `assets/models/weapons/blocky/timber_blade.glb` and its sheet.

1. **One frame for the family.** Y-up, front faces +Z, origin at the bottom of
   the pommel. Pommel 0–0.155, grip 0.17–0.355, guard 0.38–0.53, blade
   0.49–1.13, point to 1.26. Blade 0.20 wide, 0.076 thick; guard 0.48 across.
   A skin built in this frame swaps into the same hand pose.
2. **The blade is the sword.** About two thirds of the length, and the widest
   thing apart from the guard. The hilt is short and fat.
3. **Built from cubes.** Boxes, chamfered boxes, octagonal prisms, pyramids.
   No tubes, no curves, no noise.
4. **Two tones per material.** Light front face, darker sides, plus one dark
   inset (the fuller) running the length, so the blade reads as a shape and
   not a flat card.
5. **A few big features.** Stepped notches on the edges, two chunky guard end
   blocks, one octagonal pommel. Nothing thin enough to vanish at distance.
6. **Gem and gold on both faces.** Ruby in a gold frame at the guard and the
   pommel, front and back, so it reads from either side.
7. **Small budget, named parts.** About 2,250 triangles, every part its own
   named mesh.
8. **Bright enough for the top-down camera.** The honey wood stays light
   against a dark floor.

## The previous version, and what fell short

PR #213 built the Thorn Blade in the Mossstone Blade's frame alongside three
other blades in one pass. Rendered beside the Timber Blade:

- **It was almost black.** The blade's base colour was a near-black green
  (linear 0.019, 0.048, 0.032), far darker than the sheet's forest green. From
  the game camera above a dark floor it read as a dark slab.
- **The thorns were a saw.** A dense row of thin spikes up both edges in
  place of the sheet's five big staggered thorns a side, so the silhouette
  was a Christmas tree, not a sword with thorns.
- **The guard was thin antlers.** Curved, thin arms instead of the chunky
  upturned block arms on the sheet; it did not sit beside Timber's end
  blocks.
- **The pommel was a spiky star** rather than a green faceted ball with a
  ruby.
- **Another frame.** Its length ran −0.30 to 0.96 around the grip, so it did
  not match the Timber Blade in the hand.

## This version

Built fresh in a new project from the sheet, briefed with the Timber Blade's
frame in numbers, then reviewed in four rounds against every view of the
sheet and at the game's real size.

- **Same frame as the Timber Blade:** origin at the pommel's base, Y-up,
  front +Z, 0 to 1.32 long (the Timber Blade is 1.26; the extra 0.06 is a
  longer green point). Same hilt heights, so it sits in the hand the same.
  The guard spans 0.64, wider than Timber's 0.48: the sheet's upturned arms
  have to clear the mushroom clusters.
- **Forest green you can see:** face #3F6A4E, sides #2A4A37, a lighter
  centre ridge (#4C7A5C) for the diamond section. That is about three times
  the old base colour in linear light. At 3.8× scale under the GAME camera
  (40 up, 25 back, over a dark green floor) the blade stands clear of the
  floor, and the tan thorns, cyan clusters and red grip all read.
- **Five big thorns per edge**, staggered: solid two-tone tan pyramids,
  tilted toward the tip as on the sheet. Six small studs per face.
- **Angular vine** of straight segments, on both faces, ending at the
  housing.
- **Shallow-U guard:** a flat brown bar with short chunky arms rising at
  50°, the sheet's shape, not antlers.
- **Squat glowing mushrooms**, three per side on the bar top: two stacked
  octagonal slabs per cap, emissive cyan, visible from straight above.
- **Green faceted pommel** with eight tan spikes, and a ruby in a gold
  diamond on both faces, matching the housing.
- 2,072 triangles, 50 named meshes (`blade_*`, `thorn_l_*`/`thorn_r_*`,
  `stud_*`, `vine_*`, `guard_*`, `mushroom_*`, `grip_*`, `pommel_*`), flat
  materials, sword only (no ground or lights).

Not done here: the import into Studio and a `Config/Weapons` entry. Those
follow the Timber Blade's import.
