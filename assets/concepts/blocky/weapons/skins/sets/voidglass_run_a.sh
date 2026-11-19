#!/usr/bin/env bash
# voidglass: one front view each from Codex (rule 9).
cd "$(dirname "$0")/voidglass" || exit 1
timeout 900 codex exec -i ../../golden/golden_bow.png --skip-git-repo-check < orbit_bow.txt 2>&1 | tail -20 > orbit_bow.log; echo "=== orbit_bow done"
timeout 900 codex exec -i ../../golden/golden_blade.png --skip-git-repo-check < nebula_blade.txt 2>&1 | tail -20 > nebula_blade.log; echo "=== nebula_blade done"
