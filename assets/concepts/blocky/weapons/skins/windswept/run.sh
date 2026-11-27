#!/bin/bash
# Sends prompts.py's twenty prompts to Codex, four at a time.
cd "$(dirname "$0")"
T=/c/Dev/ArcheroRoblox/assets/concepts/blocky/weapons/skins/thornwood
AREA=../../../windswept/boss07_tempest_roc_views.png
ref() { case $1 in *_bow|*bow) echo $T/boar_tusk_bow_single.png;; *staff|eye_of_the_storm) echo $T/blackspine_staff_single.png;; *blade|*cleaver) echo $T/boarback_blade_single.png;; *) echo $T/burrfang_daggers.png;; esac; }
one() { n=$1; [ -f "$n.png" ] && return; timeout 900 codex exec -i "$(ref $n)" -i "$AREA" --skip-git-repo-check < "$n.txt" 2>&1 | tail -1; echo "== $n"; }
export -f one ref; export T AREA
ls *.txt | sed 's/\.txt$//' | xargs -P 4 -I{} bash -c 'one {}'
ls *.png | wc -l
