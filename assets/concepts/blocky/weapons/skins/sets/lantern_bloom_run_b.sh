#!/usr/bin/env bash
# lantern_bloom: one front view each from Codex (rule 9).
cd "$(dirname "$0")/lantern_bloom" || exit 1
timeout 900 codex exec -i ../../golden/golden_staff.png --skip-git-repo-check < paperglow_staff.txt 2>&1 | tail -20 > paperglow_staff.log; echo "=== paperglow_staff done"
timeout 900 codex exec -i ../../golden/golden_daggers.png --skip-git-repo-check < bellchime_daggers.txt 2>&1 | tail -20 > bellchime_daggers.log; echo "=== bellchime_daggers done"
