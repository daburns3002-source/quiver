#!/usr/bin/env bash
# coin_op: one front view each from Codex (rule 9).
cd "$(dirname "$0")/coin_op" || exit 1
timeout 900 codex exec -i ../../golden/golden_bow.png --skip-git-repo-check < highscore_bow.txt 2>&1 | tail -20 > highscore_bow.log; echo "=== highscore_bow done"
timeout 900 codex exec -i ../../golden/golden_blade.png --skip-git-repo-check < pixel_blade.txt 2>&1 | tail -20 > pixel_blade.log; echo "=== pixel_blade done"
