#!/usr/bin/env bash
# tumbleweed: one front view each from Codex (rule 9).
cd "$(dirname "$0")/tumbleweed" || exit 1
timeout 900 codex exec -i ../../golden/golden_staff.png --skip-git-repo-check < wagonwheel_staff.txt 2>&1 | tail -20 > wagonwheel_staff.log; echo "=== wagonwheel_staff done"
timeout 900 codex exec -i ../../golden/golden_daggers.png --skip-git-repo-check < spur_daggers.txt 2>&1 | tail -20 > spur_daggers.log; echo "=== spur_daggers done"
