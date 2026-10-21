# Quiver

An Archero-like top-down roguelike for Roblox. Low poly, built to play the same on phone,
tablet, desktop and gamepad.

**The one rule:** you move or you shoot, never both. Stand still and you auto-fire at the
nearest enemy. Move and you stop firing. There is no dodge button — walking is the only
defence.

Runs are room-to-room. Clear a room, doors open, next room. Every level-up offers three random
abilities and you take one. Abilities stack multiplicatively into absurd shot patterns, and you
lose all of them when you die.

## Status

**Phase 0 — pipeline.** No gameplay yet. See [docs/ROADMAP.md](docs/ROADMAP.md).

## Getting set up

```bash
rokit install                   # Rojo, Wally, Selene, StyLua
selene generate-roblox-std      # once per clone; roblox.yml is gitignored
rojo serve                      # then connect from the Rojo plugin in Studio
```

## Docs

| | |
|---|---|
| [docs/RESEARCH-archero.md](docs/RESEARCH-archero.md) | Teardown of the original — mechanics, abilities, enemies, what to change |
| [docs/ROADMAP.md](docs/ROADMAP.md) | Eight phases, each ending in one playtest question |
| [docs/ARCHITECTURE.md](docs/ARCHITECTURE.md) | Repo layout, the agent loop, the non-negotiables |
| [CLAUDE.md](CLAUDE.md) | Builder rulebook |
| [AGENTS.md](AGENTS.md) | Reviewer rulebook |

The filesystem is the source of truth. Changes made by hand in Studio are lost.
