#!/usr/bin/env bash
# tumbleweed: one front view each from Codex (rule 9).
cd "$(dirname "$0")/tumbleweed" || exit 1
timeout 900 codex exec -i ../../golden/golden_bow.png --skip-git-repo-check < saddlehorn_bow.txt 2>&1 | tail -20 > saddlehorn_bow.log; echo "=== saddlehorn_bow done"
timeout 900 codex exec -i ../../golden/golden_blade.png --skip-git-repo-check < trailboss_blade.txt 2>&1 | tail -20 > trailboss_blade.log; echo "=== trailboss_blade done"
