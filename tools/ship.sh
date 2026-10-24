#!/usr/bin/env bash
# Ship the current branch as one PR, after the work is done and playtested:
#   tools/ship.sh "<PR title>" <body-file>
# Runs the gates, pushes, opens the PR (or reuses the branch's open one),
# waits for CI, brings the branch up to date if main moved on, and merges
# (squash, branch deleted): the owner's standing authorisation to merge.
# Stops, and says why, on any failure; it never forces anything.
set -euo pipefail
cd "$(dirname "$0")/.."
title="$1"; body="$2"
branch=$(git branch --show-current)
[ "$branch" != "main" ] || { echo "On main: make a branch first (phase-N/name)."; exit 1; }
[ -z "$(git status --porcelain --untracked-files=no)" ] || { echo "Uncommitted changes: commit them first."; exit 1; }
tools/check.sh
git push -q -u origin "$branch"
pr=$(gh pr view "$branch" --json number --jq .number 2>/dev/null || true)
if [ -z "$pr" ]; then
	gh pr create --title "$title" --body-file "$body" >/dev/null
	pr=$(gh pr view "$branch" --json number --jq .number)
fi
echo "PR #$pr"
for attempt in 1 2 3; do
	sleep 20
	gh pr checks "$pr" --watch --interval 10 >/dev/null || { gh pr checks "$pr"; echo "CI failed."; exit 1; }
	state=$(gh pr view "$pr" --json mergeStateStatus --jq .mergeStateStatus)
	if [ "$state" = "BEHIND" ]; then
		echo "Behind main: updating the branch and waiting for CI again."
		gh pr update-branch "$pr" >/dev/null
		continue
	fi
	gh pr merge "$pr" --squash --delete-branch >/dev/null
	git checkout -q main && git pull -q
	echo "Merged #$pr: $(git log --oneline -1)"
	exit 0
done
echo "Still not mergeable after updating three times; look at PR #$pr."; exit 1
