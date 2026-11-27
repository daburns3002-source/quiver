#!/bin/bash
# The Tempest Roc's turnaround sheet for Claude Design, from the blocky boss art (2026-11-26).
cd "$(dirname "$0")"
[ -f boss07_tempest_roc_views.png ] && exit 0
cat <<E | timeout 900 codex exec -i ../boss07_tempest_roc.jpg -i ../boss01_king_bloblin_views.png --skip-git-repo-check 2>&1 | tail -1
Generate ONE wide 16:9 image at the highest resolution available and save it in the current directory as boss07_tempest_roc_views.png

Image 1 is our boss THE TEMPEST ROC, a giant blocky voxel storm bird. Image 2 shows the layout we want for a boss character sheet (NOT its character or colours).
Draw the Tempest Roc exactly as in image 1: same blocky stepped-cube style, same navy and royal-blue feathers, cream-white head, neck ruff and chest, gold-yellow crest feathers, gold V mark on the chest, gold-tipped wing feathers, dark grey hooked beak, yellow eyes under a heavy brow, thick navy legs with gold talons, wings raised and spread wide with glowing yellow lightning crackling along the wing tips.
Lay it out as a model sheet: a large three-quarter front view on the left, and smaller FRONT, SIDE (facing right), BACK and TOP views on the right, all the same pose and size, plus a small palette row.
Plain flat light-grey background, no scenery, no rock, no clouds, no ground, no shadow, no text, no labels. Even soft lighting.
E
echo done
