#!/usr/bin/env bash
# Thornwood's weapons, front view alone, from Codex (rule 9).
cd "$(dirname "$0")/thornwood" || exit 1
timeout 900 codex exec -i boar_tusk_bow_views.png --skip-git-repo-check < boar_tusk_bow_single.txt 2>&1 | tail -20 > boar_tusk_bow_single.log; echo "=== boar_tusk_bow done"
timeout 900 codex exec -i lurker_vine_bow_views.png --skip-git-repo-check < lurker_vine_bow_single.txt 2>&1 | tail -20 > lurker_vine_bow_single.log; echo "=== lurker_vine_bow done"
timeout 900 codex exec -i nightbarb_bow_views.png --skip-git-repo-check < nightbarb_bow_single.txt 2>&1 | tail -20 > nightbarb_bow_single.log; echo "=== nightbarb_bow done"
timeout 900 codex exec -i burr_totem_staff_views.png --skip-git-repo-check < burr_totem_staff_single.txt 2>&1 | tail -20 > burr_totem_staff_single.log; echo "=== burr_totem_staff done"
timeout 900 codex exec -i silk_diadem_staff_views.png --skip-git-repo-check < silk_diadem_staff_single.txt 2>&1 | tail -20 > silk_diadem_staff_single.log; echo "=== silk_diadem_staff done"
timeout 900 codex exec -i boarback_blade_views.png --skip-git-repo-check < boarback_blade_single.txt 2>&1 | tail -20 > boarback_blade_single.log; echo "=== boarback_blade done"
timeout 900 codex exec -i burrcrest_blade_views.png --skip-git-repo-check < burrcrest_blade_single.txt 2>&1 | tail -20 > burrcrest_blade_single.log; echo "=== burrcrest_blade done"
timeout 900 codex exec -i briarbreaker_blade_views.png --skip-git-repo-check < briarbreaker_blade_single.txt 2>&1 | tail -20 > briarbreaker_blade_single.log; echo "=== briarbreaker_blade done"
