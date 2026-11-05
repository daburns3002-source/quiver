#!/usr/bin/env bash
cd "$(dirname "$0")" || exit 1
R=..
for n in weapon_shop:blacksmith_card hatch_eggs:hatchery_fairy_card your_gear:blacksmith_card; do
  name=${n%%:*}; card=${n##*:}
  { cat "$name.txt"; cat _building_common.txt; } \
    | timeout 500 codex exec -i lobby_layout_reference.png -i palace_d_landmark_options.png -i "$R/dex_hall_in_game.jpg" -i "$R/npcs/$card.png" --skip-git-repo-check 2>&1 | tail -2
  echo "=== $name done $(date +%T)"
done
ls -la building_*.png
