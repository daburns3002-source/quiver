#!/usr/bin/env bash
# splash_day: one front view each from Codex (rule 9).
cd "$(dirname "$0")/splash_day" || exit 1
timeout 900 codex exec -i ../../golden/golden_staff.png --skip-git-repo-check < splashring_staff.txt 2>&1 | tail -20 > splashring_staff.log; echo "=== splashring_staff done"
timeout 900 codex exec -i ../../golden/golden_daggers.png --skip-git-repo-check < squirt_daggers.txt 2>&1 | tail -20 > squirt_daggers.log; echo "=== squirt_daggers done"
