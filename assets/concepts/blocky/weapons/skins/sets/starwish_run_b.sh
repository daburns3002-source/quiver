#!/usr/bin/env bash
# starwish: one front view each from Codex (rule 9).
cd "$(dirname "$0")/starwish" || exit 1
timeout 900 codex exec -i ../../golden/golden_staff.png --skip-git-repo-check < dreamdrop_staff.txt 2>&1 | tail -20 > dreamdrop_staff.log; echo "=== dreamdrop_staff done"
timeout 900 codex exec -i ../../golden/golden_daggers.png --skip-git-repo-check < twinkle_daggers.txt 2>&1 | tail -20 > twinkle_daggers.log; echo "=== twinkle_daggers done"
