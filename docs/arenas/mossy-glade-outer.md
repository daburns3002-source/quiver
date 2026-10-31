# Mossy Glade — the outer arena (the forest past the walls)

Level 1's blocky forest: the scenery outside the walled room, seen from the
game's near-top-down camera. The room itself (walls, lawn, stumps, log,
mushroom ring) is already built from the owner's kit (PRs #183, #192) and is
**not** in this model. The model has a hole exactly where the room goes.

Built 2026-10-24 in Claude Design from the Codex reference sheets on
`phase-3/ambience-refs`:

- `assets/concepts/blocky/arenas/area01_mossy_glade_ambience.jpg` — master
  sheet, the clearing from the game camera
- `assets/concepts/blocky/arenas/area01_mossy_glade_ambience_kit.jpg` — kit
  sheet, the pieces
- `assets/concepts/blocky/arenas/area01_mossy_glade.jpg` — the interior, for
  context only

## Where it is

- **Claude Design project:** "Mossy Glade outer forest",
  <https://claude.ai/design/p/5486023c-c4a2-4717-be2c-48589fa5e664>
  (file `Mossy Glade Outer Arena.html`; earlier passes kept beside it as
  `… v1.html` etc.). Claude Design is retired on December 14 — the GLB is the
  thing to keep.
- **GLB:** `mossy_glade_outer_arena.glb`, in the owner's `Downloads`. Exported
  by the project's own `mossy_glade_outer_arena.glb` button, which exports
  only the forest: no room ghost, kit lineup, lights or helpers.

## Import (owner, by hand)

File → Import 3D → `mossy_glade_outer_arena.glb`, with:

- **Merge Meshes: off.** This keeps every tree its own object. With it on,
  the forest becomes one lump and per-tree sway is blocked again.
- **Vertex colours on.** The colours are per vertex on plain white
  materials, so with them off the model imports white.
- **No rig, no animation.**
- Units: the model is authored at **1 unit = 1 stud**. If the importer
  rescales it, a tree that comes in near 15 studs tall is correct, and one
  near 4 or 54 is not.
- The importer turns models 180° (see `CLAUDE.md`). The forest is almost
  symmetric, except for the gate gap in the north (−Z) side: after import that
  gap must line up with the gatehouse.

## How it lines up with the room

The model is authored in the room's own frame: origin at the centre of the
lawn, Y up, north = −Z (the exit gate's side), as in `Balance.Arena`
(`size` 35 × 58, `wallThickness` 2, `wallHeight` 8).

| what | where |
|---|---|
| The hole (nothing at all inside) | x −19.5 … +19.5, z −31 … +31 — the room's outer wall faces |
| Gate clearance (nothing over 1.5 studs) | x −6 … +6, z −31 … −37, behind the north wall's gatehouse |
| Forest floor top | Y −0.2 (the lawn is at Y 0, so they never z-fight) |
| Extent | x ±75, z ±60 — past the ambience strips (`AmbienceVolumes.strips`: \|x\| to 68.5, \|z\| to ~45) and the camera's view on every device |
| Wall band | a 3–5 stud strip of moss cubes, bushes, ferns, flowers and mushrooms against the walls' outer faces; the first crowns start beyond it |
| Canopy tops | 13–15.5 studs, varying tree to tree; nothing in the model above 16 |

Placed at the arena's origin with no offset, its hole sits exactly on the
room's walls. Nothing in it overlaps the existing interior, so it is added
alongside the kit room, never instead of it.

## What is in it

Numbers below were read from the exported GLB, not from the design's own
report:

- **81 trees**, each its own `Tree_###`, in the kit sheet's two types: A,
  taller, with more lime on top; B, rounder, with the crown starting lower.
  Trunks are 3–4 studs wide with a stepped root flare. Each crown is a lumpy
  cluster of 15–25 cubes: lime on the highest cubes, mid green below them,
  dark green on the shaded sides and underneath. Crowns are 9–11 studs
  across. They are placed irregularly (no rows), each in one of 8
  rotate/mirror variants.
- **Separation (the owner's note): "make sure that the trees have some
  separation so you can tell that they are trees."** No two crowns overlap;
  every crown is 1.5–3 studs from its nearest neighbour, with green ground
  and undergrowth showing between them. That cost the master sheet's
  slightly bigger crowns, a trade-off made on purpose.
- **Canopy tops 13.05–15.44.** The model's highest point is 15.44.
- **40 `Bush_###`** in the wall band, **29 `GlowCap_###`** across 12
  mushroom clusters, 13 boulders, 7 logs and 6 stumps. Ferns, flowers and
  low mounds fill the gaps between trees.
- **92,522 triangles** in 252 meshes. The largest single mesh is the
  `Ground` slab at 6,856, and no mesh comes near Roblox's per-mesh limit.
  7.3 MB on disk.
- Materials: `ForestFloor`, `Bark`, `Foliage`, `Undergrowth`, `MossyStone`,
  `GlowCap`. Colour is in the vertex colours on every mesh except the glow
  caps, which are a flat cyan material.
- Checked from the exported file: no vertex inside the room's rectangle,
  nothing over 1.5 studs in the gate zone, every tree a node with exactly a
  `Trunk` mesh and a `Canopy` group (holding `CanopyMesh`), trunk bases at
  exactly Y −0.2, each canopy's origin exactly at the bottom of its mesh.

Palette, from the kit swatches: lime `#9ED13A`, mid green `#5FAE38`, dark
green `#2C6E2E`, wood `#8B5A2E` / `#6A4222`, forest floor `#3F6B2A` with
`#4C7A30` patches and `#6E5A36` dirt tiles, all darker than the lawn.

How it was judged: from the game camera (pitch 68°, FOV 40, about 74 studs
out, looking north) and from a wide overview, set beside the master sheet,
and in a kit lineup set beside the kit sheet. It took four passes: the first
was too spindly and grid-like, with olive greens; the second added the
owner's separation and kit-true props; the third broke up the grid and made
the crowns lumpy; the fourth evened out the lime on the crown tops.

## Structure — what the moving layer can rely on

Every tree is its own node, **never one merged forest**:

```
Tree_001            origin at the centre of the trunk base (Y −0.2)
├─ Trunk            one mesh: trunk, root flare, moss on the roots
└─ Canopy           group; origin at the BOTTOM CENTRE of the canopy mass
   └─ (mesh)        one merged canopy mesh
```

Wall-band bushes are separate `Bush_###` nodes, origin at their base.
Glowing mushroom caps are separate `GlowCap_###` meshes with one cyan
material. Everything else (ground, rocks, logs, stumps, ferns, flowers,
mushroom stems) is merged by kind and quadrant (`Rocks_NE`, `Plants_SW`, …),
each mesh under 10,000 triangles.

## What the moving ambience will need from this (not built here)

`Fx/ForestAmbience` (leaves, fireflies, butterflies, birds, mist, light
shafts) is a separate piece. When the model is wired in:

- **Per-tree sway.** After import each `Tree_###` becomes a `Model`: tag it
  `ForestTree`, set `PrimaryPart` to `Trunk` and `WorldPivot` at the trunk
  base. Make each `Canopy` a `Model` (even holding one mesh) with its
  `WorldPivot` at the canopy base, which is where the GLB already puts the
  node's origin. That is the contract in
  `assets/design/forest_ambience/README.md`, so the sway needs no
  translation layer.
- **Bushes.** Tag the `Bush_###` nodes `ForestBush`. They are all outside the
  walls, so a consumer can sway every tagged bush without checking where it
  is.
- **Canopy heights.** Tops sit inside `Balance.Ambience.Forest.canopy`
  (13–15.5) and under `hover` (16), so the current numbers hold.
- **Canopy gaps are real.** The owner asked for visible separation between
  trees, so there are 1.5–3 stud holes between the crowns. A leaf over a gap
  must settle on a `canopyFloor` fallback, not fall through to the floor.
  This is the hazard in the ambience design findings, and it is now certain,
  not hypothetical.
- **Glow.** The GLB carries the cyan cap material but no lights. Set the
  `GlowCap_###` parts to Neon (or add a small `PointLight`) in Studio.

## Wiring it in (a later pass, not this one)

Not done here, deliberately: no `ArenaModels`, `ArenaKits`, `Balance` or
`Arena` changes. Once the owner has imported it: dump the mesh ids, add an
`ArenaModels` entry that places the forest at the room's origin in place of
the old round `BOSS_FOREST` / `WIDE_FOREST` surround, and tag the trees and
bushes as above. Then walk the room in Studio: no void at the screen edges,
no z-fighting where the floor meets the walls, the gate visible.
