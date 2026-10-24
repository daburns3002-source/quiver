# Warden greatswords redo — A (Mossstone Blade)

2026-10-24. The owner judged the **Timber Blade** (Common) good and wants every
other greatsword redone to its standard. This doc covers the **Mossstone Blade**
(Uncommon). The Thorn, Broodsplit, Emberfang and Gladeheart Blades went to their
own sessions.

## The Timber Blade checklist

Measured from `assets/models/weapons/blocky/timber_blade.glb` and its Claude
Design project ([Timber Blade 3D Model](https://claude.ai/design/p/934f0379-c0ab-4064-8e6f-8800e0bf43b0?file=Timber+Blade.html)),
which got there in nine rounds of exact-dimension feedback. That is the first
lesson: brief it in numbers, not adjectives.

1. **One frame for the family.** 1.26 tall, origin at the bottom of the pommel,
   blade up +Y, flat faces ±Z. Blade 0.20 wide × 0.075 thick, 0.64 of slab
   plus a 0.13 pyramid tip centred on the axis. Guard 0.48 wide.
2. **Few, big, hard parts.** Every part is a box, a chamfered box or an
   octagonal prism with 0.012–0.02 chamfers. No detail smaller than ~0.03; the
   smallest things on it (fuller, notches) are still a sixth of the blade wide.
3. **The guard is a dumbbell.** A thin bar (0.40 × 0.085 × 0.08) with chunky
   end blocks (0.095 × 0.15 × 0.11) standing above and below it, and ~0.035 of
   bare bar showing between each block and the housing. From the top-down
   camera this cross shape is what says "sword".
4. **A dark two-tier housing** (0.12 × 0.13 centre over 0.22 × 0.105 wings)
   with a gold frame and a faceted gem on each face: the darkest value on the
   sword sits right at its centre, so the gem pops.
5. **Gold rings the grip.** Collar 0.11 × 0.03, grip 0.175 × 0.08, band
   0.11 × 0.025, then a big octagonal pommel (0.19 × 0.15 × 0.105) with gold
   and a gem on both faces. The pommel is nearly guard-block size, which
   balances the silhouette.
6. **Value contrast in four steps**: one main material in two or three flat
   tones, near-black housing, gold, red. No noise, no textures.
7. **Clean side profile.** Nothing sticks out of the blade's outline in LEFT
   view except deliberate shapes (guard, pommel).

## Mossstone Blade (Uncommon)

- **Claude Design project:** [Mossstone Blade Design](https://claude.ai/design/p/ca98d0b2-6d30-48c5-b845-dc95f0794b39?file=Mossstone+Blade.html)
  (file `Mossstone Blade.html`; it references the Timber project and started
  from a copy of Timber's viewer and export code).
- **GLB:** `wpn_mossstone_blade.glb` in the owner's Downloads, waiting for the
  owner's import. One root `wpn_mossstone_blade` with 17 named parts (`blade`,
  `blade_tip`, `blade_moss_front`, `blade_moss_back`, `guard_bar`,
  `guard_end_l/r`, `guard_moss`, `housing`, `housing_gold`, `housing_gem`,
  `collar_upper`, `grip`, `band_pommel`, `pommel`, `pommel_gold`,
  `pommel_moss`). 2,734 triangles, 1.26 tall, origin at the pommel bottom,
  blade +Y, ruby on the +Z face. 0.51 wide: the guard is Timber's 0.48, plus
  the moss caps on the end blocks.
- **Sheet:** `assets/concepts/blocky/weapons/skins/forest/mossstone_blade_views.png`.

### What it is

The Timber Blade's frame and part list, made in stone: a straight-edged grey
slab blade (no notches or fuller, as on the sheet) with a few large tone
patches and jagged inset cracks, and a pyramid tip. The guard is a stone
dumbbell with moss caps on the end blocks. The housing is two-tier slate with
a gold hexagon around a faceted ruby on the front, and the same frame filled
with slate on the back (the sheet's back view has no gem). The grip is ribbed
leather in 4 segments. The pommel is a stone octagon with 3 straight gold bars
and a recessed slate centre holding a raised green plus. Over the blade, on
each face, run two one-tile-wide vines of 0.025 tiles that climb as
staircases from edge to edge, wrapping onto the sides. They cross twice, carry
a few leaf clusters and end in a plus-shaped leaf near the tip, covering
37–39% of each face. The vine tiles mix two greens, with darker sides, so the
moss reads as lumpy and lit, not as a decal.

Rarity: it is one step up from the Timber Blade. It keeps the same build but
moves from wood to stone with living moss, and it has no glow or effects,
which are left for the higher rarities.

### Against the previous version, and why

The previous Mossstone Blade (`assets/models/weapons/blocky/uncommon/MossstoneBlade.glb`,
also `MossstoneBlade.glb` in Downloads) was not iterated on; this one was
started fresh. It read worse than the Timber Blade for these reasons:

1. **Moss as noise.** It was hundreds of tiny loose voxels scattered over the
   blade, guard and pommel. At the top-down game camera they blur into green
   fuzz, and in side view they make the blade look hairy. **Now:** the moss is
   built as continuous vines, one tile wide, that wrap at most 0.015 past the
   stone's outline, so the side profile stays clean.
2. **Plain slab, weak guard.** The blade was a flat slab with nothing to
   read, and the guard ends were thin plates rather than blocks. **Now:** the
   blade has Timber's 0.20 × 0.075 section and pyramid tip, and the guard is
   Timber's dumbbell (0.40 bar, 0.095 × 0.15 × 0.11 end blocks) with chunky
   moss caps. The grey stone against the near-black housing and the gold gives
   it the same four-step value contrast.
3. **Off-frame proportions.** It did not share Timber's grip, collar, band and
   pommel sizes, so it would not have sat beside Timber as a set. **Now:** every
   one of those matches Timber's numbers.

### How it was reviewed

Each round was exported and rendered locally with a flat-shaded renderer: FRONT,
BACK, side, 3/4, and a game view (the sword lying flat, seen from 55° above),
next to `timber_blade.glb` at the same scale. It was also checked view by view
against the sheet in Claude Design's straight-on views. These caught what the
default turntable flattered:

- Round 2's moss covered too much, as a flat mass of 0.035 tiles.
- Round 3's vines bunched in the centre.
- Round 4's two vines mirrored each other into a chain-link X pattern.

### Gotchas for the next designer

- Claude Design's first two turns on the full ~5,000-character brief **ended
  silently after ~8 minutes of thinking with no file written**. Splitting the
  work fixed it: step 1 was "copy Timber Blade.html, change only the sword, no
  moss". After that, each step was one short message, and a step came back in
  2–4 minutes.
- Its view buttons sometimes lag one click behind a re-render. Its GAME
  button looked end-on down the blade, so the game-camera check was done in the
  local render instead.
- Repeated exports land as `wpn_mossstone_blade (1).glb`. Rename the newest
  one over the old name.
