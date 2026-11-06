#!/usr/bin/env bash
# Bogheart Caverns' outer arena, the scenery past the room's walls (owner,
# 2026-11-05: "THE OUTER ARENAS NEED TO ALSO BE BUILT FOR ARENA 3 AND 4"):
# the master view round the approved room, then the kit sheet of its pieces,
# the way the Mossy Glade's, Thornwood's and the Drowned Village's were made
# (docs/PIPELINES.md §4.5). The principle Thornwood settled holds: the outside
# is the room continuing outward, in its own pieces, colours and light.
cd "$(dirname "$0")" || exit 1

if [ ! -f area04_bogheart_caverns_ambience.png ]; then
cat <<E | timeout 1200 codex exec -i area04_bogheart_caverns_v2.png -i area01_mossy_glade_ambience.jpg -i area02_thornwood_ambience.jpg -i area03_drowned_village_ambience.jpg --skip-git-repo-check > area04_outer_master.log 2>&1
Generate ONE image, landscape, 1672x941, and save it in the current directory as area04_bogheart_caverns_ambience.png

Reference images attached, in order:
1. The APPROVED Bogheart Caverns room sheet: the room itself, its second view, its kit pieces and its swatches. EVERY colour and EVERY material below is taken from this image.
2, 3 and 4. The outer-arena sheets of the game's first three areas: copy ONLY their camera, their composition and the way the room sits small in the middle of the frame with the area continuing outward all round it. Not their shapes, not their colours.

Match image 1's visual language EXACTLY -- chunky voxel blocks, flat shading, hard edges, no textures, saturated colours, soft ambient light with a gentle drop shadow, plain light-grey studio backdrop round the edge.

Subject: the same walled Bogheart Caverns room, small and centred, seen from a steep near-top-down three-quarter angle, drawn exactly as image 1's big arena: dark slate cave floor in square tiles with lime-green moss patches, tall dark slate rock walls with glowing cyan mushroom clusters at their feet, the glowing turquoise stream across the middle with the wooden plank bridge in the centre and grey stepping stones near each side wall, four giant glowing cyan mushrooms, lime-green glowing bog sprouts in the corners, and a dark cave mouth in the middle of the top wall and of the bottom wall.

Around it, filling most of the frame, the rest of the cavern, the room continuing outward in its own pieces:

- CAVE FLOOR as the ground: the same dark slate tiles in two or three tones, darker further from the room, with lime-green moss patches and small loose slate cubes.
- ROCK: tall dark slate rock columns and stalagmite clusters of stacked cubes, broken rock walls like the room's own, and a few deep black chasms or pits with a faint glow at their bottom.
- GLOWING WATER: the room's turquoise stream running on out of the walls on both sides and winding away, opening into a few still glowing pools with flat stepping stones and a plank bridge or two.
- MUSHROOM GROVES: giant glowing cyan mushrooms like the room's, in clusters of different heights, and many small glowing mushroom clusters along rock bases.
- BOG: patches of dark green bog with lime-green glowing bog sprouts, hanging roots dangling from overhead rock in a few places, seen from above as thin brown cube strands.
- A few dark side tunnels: black cave mouths like the room's gates in outer rock walls.

The living ambience, all of it blocky and faceted, nothing soft or round:
- Small glowing spore cubes floating in little drifts over the mushroom groves, cyan and lime.
- Flat turquoise ring slabs as ripples on the glowing pools, and pale-cyan glints on the water.
- A few tiny glow-bugs: a dark body cube with a lime-green glowing tail cube.
- Thin low mist as flat translucent pale-teal slabs lying over the bog and the pools.
- Two or three pale cyan shafts of light as angled translucent prisms coming down through gaps in the rock, with a soft pool where each meets the floor.

The cavern is dark but readable: the glow of the mushrooms, sprouts, stream and pools lights it, as in image 1. Composition: the room occupies about a third of the frame, the cavern and its ambience the rest. Everything readable from directly above. No text, no labels, no UI, no characters.
E
fi

[ -f area04_bogheart_caverns_ambience.png ] || { echo "no master"; exit 1; }

if [ ! -f area04_bogheart_caverns_ambience_kit.png ]; then
cat <<E | timeout 1200 codex exec -i area04_bogheart_caverns_ambience.png -i area04_bogheart_caverns_v2.png -i area01_mossy_glade_ambience_kit.jpg --skip-git-repo-check > area04_outer_kit.log 2>&1
Generate ONE image, landscape, 1672x941, and save it in the current directory as area04_bogheart_caverns_ambience_kit.png

Reference images attached, in order:
1. The Bogheart Caverns outer-arena view: the cavern round the room. EVERY piece below is taken from this image, with its shapes and its colours.
2. The Bogheart Caverns room sheet with its kit pieces (giant glowing mushroom, bog sprout, rock wall, plank bridge, stream tile, mushroom cluster) and swatches.
3. The Mossy Glade outer-arena KIT sheet: copy ONLY its layout, plain light-grey backdrop, lighting, angle and spacing. None of its pieces or colours.

Match the visual language EXACTLY -- chunky voxel blocks, flat shading, hard edges, no textures, saturated colours, soft ambient light with a gentle drop shadow.

This is a KIT SHEET, not a scene: individual objects laid out in neat rows on a plain light-grey studio backdrop, each piece isolated with space around it, lit the same way, all at a consistent three-quarter angle, exactly like reference 3. No scene, no ground plane -- a catalogue of parts.

Lay out these pieces in rows (but draw NO text):

Row 1 -- the big pieces, each a separate whole object:
- A tall dark slate rock column of stacked cubes with lime-green moss and a few glowing cyan mushrooms at its foot.
- A stalagmite cluster: three slate cube spires of different heights on one base.
- A giant glowing mushroom grove: three giant glowing cyan mushrooms of different heights on one mossy slate base.
- A broken outer rock wall section with a black cave mouth in it.
- A chasm edge: a square black pit with broken slate cube rims and a faint cyan glow at the bottom.

Row 2 -- the floor dressing:
- A glowing pool: a square-edged pool of glowing turquoise water cubes with a slate rim.
- A stream bend tile: the room's glowing stream turning a corner, slate banks.
- A short plank bridge, the room's, alone.
- Flat grey stepping stones, three in a row.
- A bog patch: dark green bog cubes with two lime-green glowing bog sprouts.
- A small glowing mushroom cluster on a slate cube.
- Hanging roots: thin brown cube strands hanging from a slate overhang block.
- A loose slate rubble pile with moss.

Row 3 -- the moving ambience, each drawn large and clearly faceted:
- A spore: one small glowing cyan cube, and one lime-green one.
- A ripple: one flat turquoise square ring slab.
- A water glint: one small flat pale-cyan slab, slightly tilted.
- A glow-bug: a dark body cube with a lime-green glowing tail cube and two tiny flat wing slabs.
- A mist piece: one flat translucent pale-teal slab, low and wide.
- A light shaft: one angled translucent pale-cyan prism with flat sides.

Row 4 -- material swatches as flat square tiles, sampled from image 1: dark slate, mid slate, moss green, glowing cyan mushroom, glowing turquoise water, plank brown, bog green, lime sprout glow, root brown, mist teal.

No text, no labels, no numbers, no UI, no characters, no background scenery.
E
fi
ls -la area04_bogheart_caverns_ambience*.png
