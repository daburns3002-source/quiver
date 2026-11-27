#!/usr/bin/env bash
cd "$(dirname "$0")" || exit 1
R=..
for n in a b c d; do
  { cat "$n.txt"; echo; [ "$n" != d ] && cat _common.txt; } \
    | timeout 400 codex exec -i "$R/dex_hall_in_game.jpg" -i "$R/npcs/hatchery_fairy_card.png" -i "$R/npcs/blacksmith_card.png" --skip-git-repo-check 2>&1 | tail -2
  echo "=== $n done $(date +%T)"
done
ls -la *.png
