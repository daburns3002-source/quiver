#!/usr/bin/env bash
# starwish: one front view each from Codex (rule 9).
cd "$(dirname "$0")/starwish" || exit 1
timeout 900 codex exec -i ../../golden/golden_bow.png --skip-git-repo-check < wishbright_bow.txt 2>&1 | tail -20 > wishbright_bow.log; echo "=== wishbright_bow done"
timeout 900 codex exec -i ../../golden/golden_blade.png --skip-git-repo-check < wishcutter_blade.txt 2>&1 | tail -20 > wishcutter_blade.log; echo "=== wishcutter_blade done"
