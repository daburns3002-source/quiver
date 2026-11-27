# Windswept Cliffs (area 5): Claude Design prompts (2026-11-26)

One Design chat per model, its reference attached. Check front, side and
3/4 against the reference before asking for clips; keep fixing until it
matches (owner's 1:1 rule). Enemy clips the game plays by name: `Idle`,
`Move`, `Attack wind-up`, `Death` (and `Charge` for a charger).

## Harpy -> `harpy.glb`
Attach: `assets/concepts/blocky/enemies/act3/harpy.jpg`
```
Roblox enemy in blocky voxel style, built from stepped cubes like Steal an Egg / Minecraft, no round shapes.

Harpy: a small flying enemy of a windswept cliff world, a menacing toy-like owl-bird. Hovering upright, wings spread wide and raised.
A chunky stepped body, deep navy-indigo with a lavender-purple chest, not a box body. Short thick dark-brown legs with dark talons under the body.
Huge layered wings, the widest part of the silhouette: a thick navy wing arm along the top, then long stepped feathers fading from indigo to purple to magenta-pink at the tips.
A bone-white owl-skull mask over the face with a short hooked beak and two glowing pale-blue eyes. A spiky crest of purple and magenta feathers on top of the head.
No clipping: no part pokes through another, every piece sits flush on what it touches, no two faces share a plane. Low poly, under 10k triangles. Match the attached reference image.
Show front, side and 3/4 view on a plain background.
```

## Gust Shaman -> `gust_shaman.glb`
Attach: `assets/concepts/blocky/enemies/act3/gust_shaman.jpg`
```
Roblox enemy in blocky voxel style, built from stepped cubes like Steal an Egg / Minecraft, no round shapes.

Gust Shaman: a small hooded sheep-folk wind caster of a windswept cliff world. Standing upright, holding a tall crook staff in its right hand.
A short chunky body in a deep teal hooded robe over a cream inner robe, a rope belt, cream cloth strips hanging at the front, short brown boots. Every hand connects through a wrist into its sleeve.
Under the hood a cream sheep face with pink-lined floppy ears, glowing pale-blue eyes, a small pink nose. Big dark-brown ram horns curl out of the hood on both sides.
Pale teal swirl patterns on the hood and the robe's hem. A necklace of brown and teal beads with a teal medallion.
The staff: a knotted brown crook taller than the shaman, topped by a glowing pale-blue wind spiral, with cream and teal ribbons tied under it.
No clipping: no part pokes through another, every piece sits flush on what it touches, no two faces share a plane. Low poly, under 10k triangles. Match the attached reference image.
Show front, side and 3/4 view on a plain background.
```

## Cliff Goat -> `cliff_goat.glb`
Attach: `assets/concepts/blocky/enemies/act3/cliff_goat.jpg`
```
Roblox enemy in blocky voxel style, built from stepped cubes like Steal an Egg / Minecraft, no round shapes.

Cliff Goat: a stocky charging mountain goat enemy of a windswept cliff world. Head lowered ready to charge, front legs braced.
Deep broad chest and heavy shoulders narrowing to the hips, not a box body; thick legs with clear knee bends and dark-brown square hooves.
Cream-white stepped wool coat, lighter on the top edges, with warm beige shading under the belly and neck.
A real goat head: tapered muzzle with a brown nose, pink-lined ears out to the sides, glowing pale-blue eyes under heavy brows.
Huge dark-brown ridged horns curling back and round beside the head, each almost as big as the head.
A short stepped tail.
No clipping: no part pokes through another, every piece sits flush on what it touches, no two faces share a plane. Low poly, under 10k triangles. Match the attached reference image.
Show front, side and 3/4 view on a plain background.
```

## Storm Roc (elite) -> `storm_roc.glb`
Attach: `assets/concepts/blocky/enemies/act3/storm_roc.jpg`
```
Roblox enemy in blocky voxel style, built from stepped cubes like Steal an Egg / Minecraft, no round shapes.

Storm Roc: the big elite storm bird of a windswept cliff world. Standing tall on strong legs, wings raised and spread wide, menacing.
Standing tall on strong legs with big dark-grey talons, a puffed stepped chest, a slim head with a sharp dark-grey hooked beak pointing forward.
Steel-blue body and wings with darker navy shading, a pale icy-white head, neck ruff and chest, a ragged crest swept back.
Wings with layered feathers: a thick wing arm along the top, short coverts near the arm, long flight feathers at the tips, the widest part of the silhouette. Glowing pale-blue jagged lightning cracks along the wing edges.
Glowing pale-blue eyes under a heavy brow. A long fanned tail of stepped feathers.
No clipping: no part pokes through another, every piece sits flush on what it touches, no two faces share a plane. Low poly, under 10k triangles. Match the attached reference image.
Show front, side and 3/4 view on a plain background.
```

## The Tempest Roc -> `tempest_roc.glb` (done, Fable 5.2, 3 fix rounds, 9 clips)
Attach: `assets/concepts/blocky/windswept/boss07_tempest_roc_views.png` (Codex, from `boss07_tempest_roc.jpg`).

## Arena kit -> one GLB per piece, `assets/models/arenas/windswept_kit/`
Attach: `assets/concepts/blocky/arenas/area05_windswept_cliffs.jpg`
```
Model a 3D object: Roblox arena kit in blocky voxel style, built from stepped cubes like Steal an Egg / Minecraft, no round shapes.

Windswept Cliffs arena kit: build the pieces of the attached sheet as separate 3D models, matching its shapes and colours one to one: slate grey-blue stone with lighter top edges, short bright green grass on the rims, weathered brown wood, prayer flags in red, yellow, green and blue, glowing pale-blue wind streaks, white clouds. One page with a button per piece; the selected piece is shown alone, so Download GLB exports just that piece.

Every piece: its own root group named as below; 1 unit = 1 metre; front toward +Z; resting on y = 0. Under 1,500 triangles a piece. No clipping: no part pokes through another, every cube sits flush on what it touches, no two faces share a plane.

1 RimWall: a cliff rim section 1.3 wide, 1.2 tall, 0.7 deep: stacked slate blocks of uneven heights with grass tufts on top; its +Z face, toward the room, flat.
2 CornerPillar: a tall stack of slate blocks 0.8 x 1.8 x 0.8 with a grass top.
3 Boulder: a chunky slate cube rock 1.4 wide and 1.1 tall, a few small rocks and grass tufts at its foot.
4 FlagPost: two wooden posts 1.6 tall and 1.8 apart, a sagging rope between their tops hung with five square prayer flags (red, yellow, green, blue, red).
5 Bridge: a plank rope bridge 1.6 wide and 2.6 long along Z: brown planks, rope rails on four corner posts.
6 FloorTile: a flat slate floor tile 1.35 x 0.12 x 1.35, four stepped squares with thin darker seams.
7 WindStreak: a flat glowing pale-blue wind swirl 1.6 long, made of stepped curved bands, lying flat at y = 0.01.
8 CloudGap: a flat field of fluffy white cloud cubes 1.35 x 0.5 x 1.35, the drop between two cliffs, its top at y = -0.1.
9 GrassTuft: a small clump of bright green grass blades 0.4 wide and 0.3 tall.
10 StoneGate: a slate archway 2.4 wide and 2.2 tall with a 1.2-wide opening and a prayer-flag string across its top; two wooden doors filling the opening, each its own part (Door_L, Door_R) so they can swing.

Show the selected piece in front, side and 3/4 view on a plain background.
```
