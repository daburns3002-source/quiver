#!/usr/bin/env bash
# lantern_bloom: one front view each from Codex (rule 9).
cd "$(dirname "$0")/lantern_bloom" || exit 1
timeout 900 codex exec -i ../../golden/golden_bow.png --skip-git-repo-check < blossom_bow.txt 2>&1 | tail -20 > blossom_bow.log; echo "=== blossom_bow done"
timeout 900 codex exec -i ../../golden/golden_blade.png --skip-git-repo-check < petalfall_blade.txt 2>&1 | tail -20 > petalfall_blade.log; echo "=== petalfall_blade done"
