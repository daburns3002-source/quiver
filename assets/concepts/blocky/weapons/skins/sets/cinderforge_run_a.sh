#!/usr/bin/env bash
# cinderforge: one front view each from Codex (rule 9).
cd "$(dirname "$0")/cinderforge" || exit 1
timeout 900 codex exec -i ../../golden/golden_bow.png --skip-git-repo-check < cinderstring_bow.txt 2>&1 | tail -20 > cinderstring_bow.log; echo "=== cinderstring_bow done"
timeout 900 codex exec -i ../../golden/golden_blade.png --skip-git-repo-check < molten_blade.txt 2>&1 | tail -20 > molten_blade.log; echo "=== molten_blade done"
