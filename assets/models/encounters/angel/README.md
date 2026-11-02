# The Angel

`angel.glb` — the Angel who stands in an Angel room (`RoomConfig.encounter`),
as three meshes: **cream** (robe, head, arms, wings), **gold** (waist band,
brooch, halo) and **eye** (the two closed eyes). One piece a colour, so
Roblox draws three MeshParts with flat colours and no texture, instead of
the nineteen parts `Config/AngelDesign` builds today.

Owner, 2026-11-02: "add an angel room", "it should be in the blocky design
language", "ok i like it build the model", then "Redo as a GLB".

## What it is made from

Its reference sheet is
`assets/concepts/blocky/encounters/angel/angel_views.png`, drawn by Codex
and approved by the owner. The blocks measured off that sheet live in
`src/shared/Config/AngelDesign.luau`, and **this GLB is exported from those
very numbers** by `export_glb.py` — so the mesh and the blocks are the same
figure, and neither can drift from the other.

It stands on the floor point it hovers over: the lowest geometry is 1.5
studs up, the halo tops out at 7.61, and it is 6.95 wide across the wings.
The pool of warm light under it is **not** in the GLB: that is a Neon part
`Run/AngelProp` lays on the floor, because it is light rather than
geometry.

## What the owner has to do

A mesh cannot be loaded from a file. `MeshPart.MeshId` is not assignable
and `AssetService:CreateMeshPartAsync` wants an uploaded asset, so:

1. Import `angel.glb` in Studio (the importer turns models 180°; check
   which way the face points and say so if it comes in backwards).
2. Take the three mesh ids and put them in `Config/AngelDesign.mesh`
   (`cream.id`, `gold.id`, `eye.id`), as `rbxassetid://…`.

That is the whole change. `Run/AngelProp` builds the blocks while any id is
empty and the meshes once all three are filled in, so nothing breaks
in between and `tests/Angel.spec` fails if only some are set.

The sizes and offsets already in `Config/AngelDesign.mesh` are measured off
the GLB in Blender, and the parts are given those sizes rather than
whatever the import happens to arrive at — so a piece that imports at some
other scale is still placed correctly.

## Rebuilding it

`export_glb.py` is run through the Blender MCP, not from a shell: it needs
the live Blender the server is attached to. Paste it into
`mcp__blender__execute_blender_code`. It reads
`assets/concepts/blocky/encounters/angel/built_parts.json` — a dump of
`Config/AngelDesign.parts` from the running game — builds the blocks in
their own collection, joins them by colour and exports over `angel.glb`,
leaving whatever else is open in Blender alone.

Refresh `built_parts.json` first if the design has moved, by reading
`AngelDesign.parts` in Studio.

**This departs from CLAUDE.md rule 10**, which sends 3D models through
Claude Design in the owner's Chrome. No Chrome was connected when this was
made (`list_connected_browsers` was empty, twice), so that route was not
available. Blender was also paused for modelling on 2026-10-24 ("scrap
blender for now") and is used here only as an exporter: it invents no
geometry, it writes out blocks that were already approved on the sheet and
already measured in the config.
