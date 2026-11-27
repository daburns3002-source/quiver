#!/usr/bin/env bash
# The Drowned Village's outer-arena master, redrawn round the approved room
# (owner, 2026-11-05: "THE OUTER ARENAS NEED TO ALSO BE BUILT FOR ARENA 3 AND
# 4"). The first master (area03_drowned_village_ambience.jpg, 2026-11-03) was
# drawn round the cluttered first room sheet; the flooded village outside it
# stays, the room in the middle becomes area03_drowned_village_v2.png's.
# The kit sheet (area03_drowned_village_ambience_kit.jpg) still holds.
cd "$(dirname "$0")" || exit 1
[ -f area03_drowned_village_ambience_v2.png ] && exit 0
cat <<E | timeout 1200 codex exec -i area03_drowned_village_ambience.jpg -i area03_drowned_village_v2.png --skip-git-repo-check > area03_outer_redraw.log 2>&1
Generate ONE image, landscape, 1672x941, and save it in the current directory as area03_drowned_village_ambience_v2.png

Two reference images are attached, in order:
1. The Drowned Village OUTER ARENA sheet: a walled room in the middle of the frame, and all round it the drowned village under open floodwater (sunken houses, the leaning bell tower, the stone toll gate on a broken causeway, dead trees with nets, reeds, rowboats, crab pots, rocks, drifting rafts, gulls, dragonflies, mist and light shafts).
2. The APPROVED Drowned Village ROOM sheet: the room as it is now built in the game.

Redraw image 1 in exactly its art style, camera, framing and colours, keeping EVERYTHING OUTSIDE the room's walls as it is: the same flooded village, the same pieces in the same places.

Change only the room in the middle, so it is image 2's big arena exactly: open turquoise water across the middle, the grey cobble causeway straight up the centre from gate to gate, the stone well in the exact centre, two short broken stone walls in the upper half and two crate-and-barrel stacks in the lower half as the only other things on the floor, three sunken blue-roofed timber houses set into each long side wall with a lit lantern by each, small reed clumps only at the corners and wall feet, and a wooden dock gate in the middle of the top wall and of the bottom wall. Grey stone block walls all round. Nothing scattered on the floor: no planks, no barrels, no stumps, no rope fences.

The room stays the same size and in the same place in the frame as in image 1. No text anywhere.
E
ls -la area03_drowned_village_ambience_v2.png
