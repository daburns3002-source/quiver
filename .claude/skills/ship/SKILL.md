---
name: ship
description: Finish a change the Arrow Legends way — gates, sync check, in-Roblox tests, a real playtest, FIXES/TRACKER/CLAUDE.md, self-review, then PR and merge with tools/ship.sh.
---

# Ship a change

1. `tools/check.sh` until clean.
2. In Studio: stop Play, run the probe from `python -I tools/sync_probe.py` in the Edit datamodel (every file true; otherwise the Rojo plugin needs reconnecting), start Play, answer any open card screen, run `tools/studio/run_tests.luau` (Server).
3. Playtest the change itself: measure it by probe and look at a capture. Never ship on gates alone.
4. Record: `docs/FIXES.md` for a fixed bug (findable by symptom), `docs/TRACKER.md` for what is now open or done, `CLAUDE.md` for a new system or rule.
5. Self-review against `AGENTS.md`, exploitability first; state the findings (or "no findings").
6. Commit on a `phase-N/name` branch, write the PR body to a file, run `tools/ship.sh "<title>" <body-file>`. Merging is pre-authorised.
