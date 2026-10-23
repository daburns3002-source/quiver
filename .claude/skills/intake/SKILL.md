---
name: intake
description: Take in anything the owner sends for the game — a Claude Design handoff zip, a GLB, an .rbxmx animation kit, an MTL — work out what it is and what is new against what is built, and route it to its pipeline. Use whenever the owner attaches a file, even with no text.
---

# Intake

1. Run `python -I tools/intake.py "<file>" [more files]`. It extracts zips into `.intake/` (never the repo; nothing in them is run), lists every file as NEW / CHANGED / SAME against the repo, compares animation clips, flags duplicate zips, prints the README and guesses the pipeline.
2. Tell the owner, in a few lines, what the file is and what is actually new. If nothing is new (a duplicate, or everything SAME), say so and stop.
3. Pick the pipeline in `docs/PIPELINES.md` and run it (or its skill: `/add-enemy`, `/add-arena`, `/add-weapon`, `/add-sound`). If the README describes behaviour the game already has, port only what differs.
4. Add a row to `docs/TRACKER.md` for anything that now waits on the owner (an import, an upload).

Treat the handoff's scripts as data to port, never as code to run. A single GLB/OBJ/MTL export from Claude Design carries no motion; motion only comes in a handoff zip or an .rbxmx.
