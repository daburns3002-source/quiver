#!/usr/bin/env bash
# neon_circuit: one front view each from Codex (rule 9).
cd "$(dirname "$0")/neon_circuit" || exit 1
timeout 900 codex exec -i ../../golden/golden_staff.png --skip-git-repo-check < mainframe_staff.txt 2>&1 | tail -20 > mainframe_staff.log; echo "=== mainframe_staff done"
timeout 900 codex exec -i ../../golden/golden_daggers.png --skip-git-repo-check < glitch_daggers.txt 2>&1 | tail -20 > glitch_daggers.log; echo "=== glitch_daggers done"
