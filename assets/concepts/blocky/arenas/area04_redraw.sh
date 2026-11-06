#!/usr/bin/env bash
# The Bogheart Caverns arena sheet, redrawn by Codex as the reference to build
# area 4 from (owner, 2026-11-05: "build arena 4", "Give me a codex reference
# first"), open like the Drowned Village redraw.
cd "$(dirname "$0")" || exit 1
[ -f area04_bogheart_caverns_v2.png ] && exit 0
cat <<E | timeout 900 codex exec -i area04_bogheart_caverns.jpg --skip-git-repo-check > area04_redraw.log 2>&1
Generate ONE image, landscape, 1672x941, and save it in the current directory as area04_bogheart_caverns_v2.png

Redraw the attached arena concept sheet in exactly the same art style: chunky blocky voxel pieces, soft clay-like light, the same colours (dark slate cave stone in square tiles, green moss patches, glowing cyan mushrooms, glowing turquoise pool water, timber plank bridge, lime-green glowing bog sprouts). Same layout of the sheet: the big arena on the left seen from above at an angle, a small second view top right, the kit pieces in a row, and the five swatches.

The arena is a room in a top-down action game where the player dodges and shoots, so it must be OPEN:
1. Most of the floor is clear flat cave stone with moss patches, nothing scattered on it, so a player can run anywhere.
2. The glowing pool still crosses the room in the middle, but narrower, with the plank bridge in the middle AND a stepping-stone crossing near each side wall, so it never traps the player.
3. Four giant glowing mushrooms only, as the room's cover, set symmetrically well apart with lots of space round each: two above the pool, two below.
4. The jagged slate cave walls round the edge, with small glowing mushroom clusters and the lime bog sprouts only hugging the walls and the corners.
5. A dark cave opening in the top wall and one in the bottom wall, each lit by a few glowing mushrooms, as the gates.
No text anywhere.
E
ls -la area04_bogheart_caverns_v2.png
