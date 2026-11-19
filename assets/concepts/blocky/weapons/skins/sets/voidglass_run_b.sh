#!/usr/bin/env bash
# voidglass: one front view each from Codex (rule 9).
cd "$(dirname "$0")/voidglass" || exit 1
timeout 900 codex exec -i ../../golden/golden_staff.png --skip-git-repo-check < starwell_staff.txt 2>&1 | tail -20 > starwell_staff.log; echo "=== starwell_staff done"
timeout 900 codex exec -i ../../golden/golden_daggers.png --skip-git-repo-check < comet_daggers.txt 2>&1 | tail -20 > comet_daggers.log; echo "=== comet_daggers done"
