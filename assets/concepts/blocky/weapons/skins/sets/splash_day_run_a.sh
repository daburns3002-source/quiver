#!/usr/bin/env bash
# splash_day: one front view each from Codex (rule 9).
cd "$(dirname "$0")/splash_day" || exit 1
timeout 900 codex exec -i ../../golden/golden_bow.png --skip-git-repo-check < noodle_bow.txt 2>&1 | tail -20 > noodle_bow.log; echo "=== noodle_bow done"
timeout 900 codex exec -i ../../golden/golden_blade.png --skip-git-repo-check < breaker_blade.txt 2>&1 | tail -20 > breaker_blade.log; echo "=== breaker_blade done"
