#!/usr/bin/env bash
# Thornwood's weapons, front view alone, from Codex (rule 9).
cd "$(dirname "$0")/thornwood" || exit 1
timeout 900 codex exec -i plum_burr_bow_views.png --skip-git-repo-check < plum_burr_bow_single.txt 2>&1 | tail -20 > plum_burr_bow_single.log; echo "=== plum_burr_bow done"
timeout 900 codex exec -i silkweaver_bow_views.png --skip-git-repo-check < silkweaver_bow_single.txt 2>&1 | tail -20 > silkweaver_bow_single.log; echo "=== silkweaver_bow done"
timeout 900 codex exec -i hedge_bulb_staff_views.png --skip-git-repo-check < hedge_bulb_staff_single.txt 2>&1 | tail -20 > hedge_bulb_staff_single.log; echo "=== hedge_bulb_staff done"
timeout 900 codex exec -i lurker_crest_staff_views.png --skip-git-repo-check < lurker_crest_staff_single.txt 2>&1 | tail -20 > lurker_crest_staff_single.log; echo "=== lurker_crest_staff done"
timeout 900 codex exec -i blackspine_staff_views.png --skip-git-repo-check < blackspine_staff_single.txt 2>&1 | tail -20 > blackspine_staff_single.log; echo "=== blackspine_staff done"
timeout 900 codex exec -i plumguard_blade_views.png --skip-git-repo-check < plumguard_blade_single.txt 2>&1 | tail -20 > plumguard_blade_single.log; echo "=== plumguard_blade done"
timeout 900 codex exec -i silkbound_blade_views.png --skip-git-repo-check < silkbound_blade_single.txt 2>&1 | tail -20 > silkbound_blade_single.log; echo "=== silkbound_blade done"
