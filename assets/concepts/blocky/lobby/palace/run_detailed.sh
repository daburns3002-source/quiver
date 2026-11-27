#!/usr/bin/env bash
cd "$(dirname "$0")" || exit 1
R=..
for n in weapon_shop:blacksmith_card hatch_eggs:hatchery_fairy_card your_gear:blacksmith_card; do
  name=${n%%:*}; card=${n##*:}
  { cat "${name}_d.txt"; cat _detailed_common.txt; } \
    | timeout 500 codex exec -i building_dex_hall_detailed.png -i "building_$name.png" -i "$R/npcs/$card.png" --skip-git-repo-check 2>&1 | tail -1
  echo "=== $name done $(date +%T)"
done
ls -la building_*_detailed.png
