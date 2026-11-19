#!/usr/bin/env bash
# coin_op: one front view each from Codex (rule 9).
cd "$(dirname "$0")/coin_op" || exit 1
timeout 900 codex exec -i ../../golden/golden_staff.png --skip-git-repo-check < joystick_staff.txt 2>&1 | tail -20 > joystick_staff.log; echo "=== joystick_staff done"
timeout 900 codex exec -i ../../golden/golden_daggers.png --skip-git-repo-check < token_daggers.txt 2>&1 | tail -20 > token_daggers.log; echo "=== token_daggers done"
