#!/usr/bin/env bash
# Bogheart Caverns' open-floor room (owner, 2026-11-05: "The open floor layout
# should take the water out of the middle and the bridge").
cd "$(dirname "$0")" || exit 1
[ -f area04_bogheart_caverns_open.png ] && exit 0
cat <<E | timeout 900 codex exec -i area04_bogheart_caverns_v2.png --skip-git-repo-check > area04_open.log 2>&1
Generate ONE image, landscape, 1672x941, and save it in the current directory as area04_bogheart_caverns_open.png

Redraw the attached arena sheet exactly, same style, colours, walls, gates, kit row and swatches, with only one change: remove the glowing water stream across the middle of the room, its stepping stones and the wooden bridge, in both the big view and the small view, and fill that strip with the same flat cave stone floor and green moss patches as the rest of the floor. Keep the four giant glowing mushrooms exactly where they are. No text anywhere.
E
ls -la area04_bogheart_caverns_open.png
