---
name: status
description: Say where the game stands — what is in flight, what waits on the owner, open PRs and branches — from docs/TRACKER.md checked against git and GitHub.
---

# Status

1. Read `docs/TRACKER.md`.
2. Check it against reality: `gh pr list --state open`, `git branch -r`, linked sessions, and Studio if relevant. Fix anything stale in the tracker (in a branch, shipped with the next change).
3. Report to the owner: what waits on them first (with exactly what to do), then what is in progress, then what is designed but not built.
