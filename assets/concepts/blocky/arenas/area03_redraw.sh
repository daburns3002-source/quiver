#!/usr/bin/env bash
# The Drowned Village arena sheet, redrawn with room to fight in (owner,
# 2026-11-05, of area03_drowned_village.jpg: "That is too cluttered there is
# no space to move redraw").
cd "$(dirname "$0")" || exit 1
[ -f area03_drowned_village_v2.png ] && exit 0
cat <<E | timeout 900 codex exec -i area03_drowned_village.jpg --skip-git-repo-check > area03_redraw.log 2>&1
Generate ONE image, landscape, 1672x941, and save it in the current directory as area03_drowned_village_v2.png

Redraw the attached arena concept sheet in exactly the same art style: chunky blocky voxel pieces, soft clay-like light, the same colours (shallow turquoise water floor in square tiles, grey cobble, timber brown, slate-blue roofs, bright reed green, orange lit lanterns). Same layout of the sheet: the big arena on the left seen from above at an angle, a small second view top right, the kit pieces in a row, and the five swatches.

The arena is a room in a top-down action game where the player dodges and shoots, so it must be OPEN. Change it like this:
1. The middle of the room, about 70 percent of the floor, is clear shallow water with nothing on it, so a player can run anywhere: no stray planks, rocks, stumps, reeds or barrels scattered across the floor.
2. The flooded houses sit only along the two long edges, pushed into the walls, half of each out of the room, three a side, smaller than now.
3. The cobble causeway still runs straight up the middle from the bottom gate to the top gate, flat and level with the water.
4. The stone well stays in the exact centre, as the one piece of cover in the middle, a little smaller.
5. Only four other pieces of cover on the floor, set symmetrically well apart: two short broken stone walls and two crates-and-barrel stacks, each small, with plenty of space around them.
6. Four lantern posts only, standing against the side edges, not in the floor.
7. Reeds only in small clumps hugging the edges and the corners.
8. A gap in the wall at the top and the bottom, each with a short wooden dock as the gate.
No text anywhere.
E
ls -la area03_drowned_village_v2.png
