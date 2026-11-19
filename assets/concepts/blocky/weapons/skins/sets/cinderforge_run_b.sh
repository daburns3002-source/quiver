#!/usr/bin/env bash
# cinderforge: one front view each from Codex (rule 9).
cd "$(dirname "$0")/cinderforge" || exit 1
timeout 900 codex exec -i ../../golden/golden_staff.png --skip-git-repo-check < forgeheart_staff.txt 2>&1 | tail -20 > forgeheart_staff.log; echo "=== forgeheart_staff done"
timeout 900 codex exec -i ../../golden/golden_daggers.png --skip-git-repo-check < embershard_daggers.txt 2>&1 | tail -20 > embershard_daggers.log; echo "=== embershard_daggers done"
