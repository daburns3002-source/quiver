# Gladeheart Blade (Mythic greatsword) — rebuilt

The Warden's Mythic skin (`docs/PETS-FOREST.md`), redone from its sheet
`assets/concepts/blocky/weapons/skins/forest/gladeheart_blade_views.png` to the
Timber Blade's standard, after the owner judged the Timber Blade good and
asked for every other greatsword to be redone.

- **Claude Design project:** https://claude.ai/design/p/901a15fb-84e5-4221-8054-33bdbe9ab613
- **GLB:** `wpn_gladeheart_blade.glb` in the owner's Downloads (replaces the PR #213 export)

## The checklist: what makes the Timber Blade work

Measured from `assets/models/weapons/blocky/timber_blade.glb` (origin at the
pommel's base, Y up, flat faces ±Z): 1.26 long, blade 0.20 × 0.076 from
y 0.49 to 1.13 with a steel roof to 1.26, guard 0.48 wide at y 0.38–0.53, grip
0.074 square, pommel 0.19 wide. 49 named parts, about 1,800 triangles.

1. **A few big solids.** Blade slab, crossbar, end blocks, grip, pommel. All
   detail sits on the faces as inset or proud boxes, never as loose shards.
2. **A plain cross silhouette.** Wide flat blade, guard about 2.4 × the blade,
   short grip, chunky pommel. Nothing bristles out of that outline.
3. **Proportion.** The blade is about half the length; the pommel matches the
   guard housing in size.
4. **One accent, repeated.** A gem in a gold frame at the guard and on the
   pommel, on both faces.
5. **Gold bands** close the grip at both ends.
6. **Two-tone flat colour** per material (light face, darker side) instead of
   texture noise.
7. **From the top-down camera** the flat face reads as one bold shape with one
   accent.

## What fell short in the previous version (PR #213)

The owner didn't say. Rendered beside the Timber Blade, the reasons are clear:

- **It read as a leafy bush, not a sword.** Hundreds of small leaf shards
  bristled out of every edge, so from any distance the outline was a fuzzy
  green spindle. The Timber Blade's whole appeal is a clean cross; this broke
  rule 2.
- **It had no blade.** The blade was a hollow oval of branches round a
  crystal, with no solid slab. Seen from the top-down camera it had no flat
  face to read (rule 7).
- **The guard wasn't a crossguard.** Two leaf clumps with no bar between
  them, so the cross shape was lost.
- **Out of family.** Thin, spindly parts rather than chunky boxes, a skinny
  grip and pommel, and the origin 0.3 below the pommel instead of at its
  base like the Timber Blade's.
- It was no longer than the Common (1.26), so nothing about its size said
  "Mythic".

## What changed and why

Built fresh in four rounds. Each round was exported and rendered offline
(front, back, side, three-quarter, and a small top-down "game" view) beside
the Timber Blade, because the viewer's screenshots froze the shared Chrome.

- **A real blade slab.** A solid 0.24 × 0.08 dark-teal crystal blade with
  a glowing inset channel (cyan, deep blue edges, ice centre line) on each
  face. Branches, leaves and crystals sit on it as proud blocks, as the
  Timber Blade's fuller and grain do (checklist 1, 7).
- **The sheet's tree, in blocks.** Front: two kinked bark branches rise
  from the guard, cradle the big rainbow crystal in a V, cross above it and
  run to the tip. Back: edge branches plus one trunk splitting into a clean Y,
  with the sheet's green leaf on the guard instead of the heart. A first
  pass with a busy back tangle was simplified (round 3).
- **Leaves are chunky, few and counted.** Six per edge in pairs, one over
  each top corner, two on the branches, five or six per guard cluster, eight
  round the pommel. Each one is a faceted block; none sticks out of the edge
  more than 0.035, so the outline is still a cross (checklist 2).
- **A proper crossguard.** A bark bar 0.10 tall with branch-like raised ends,
  leaf clusters 0.17 × 0.20, two white flowers, and a gold-rimmed boss holding
  the rainbow heart gem: the Timber Blade's housing and ruby, made Mythic
  (checklist 4).
- **The same grip and pommel as the Timber Blade, made richer.** Gold band
  and collar, a 0.08 bark grip wrapped in a block vine (3 turns, standing
  0.014 proud; it slopes about 10° because 3 turns don't fit at 35°), and an
  octagonal pommel with a gold ring, a 0.10 rainbow gem and a crown of leaves
  (checklist 3, 5).
- **Tip.** A hard four-sided leaf spear, two-tone with a raised midrib, built
  like the Timber Blade's steel roof. Round 2's rounded bullet tip broke the
  blocky family and was replaced.
- **Clearly the top of the ladder.** 1.42 long and 0.68 across the guard
  (Timber: 1.26 and 0.48), and it's the only greatsword that glows: the
  channel, the big crystal, the heart and pommel gems, and the pink edge
  crystals are emissive. From the top-down view it reads as a teal blade with
  a rainbow centre and a leafy guard. The sheet's butterflies, sparkles and
  light rings are effects, not model, so they aren't in it.
- **Same conventions as the Timber Blade's GLB.** Origin at the pommel's base,
  Y up, flat faces ±Z. 38 named meshes, 27 flat PBR materials (base colour,
  emissive where it glows), 4,252 triangles, 375 KB.

### Known departures from the sheet

- The grip vine is shallower than the sheet's spiral (see above).
- Both blade flowers sit on the left edge; the sheet has the white one upper
  right.
- The channel is banded flat colour, not a smooth gradient, in keeping with
  the family's flat two-tone rule.
