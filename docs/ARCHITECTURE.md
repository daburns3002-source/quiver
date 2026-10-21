# Architecture

## The three-agent loop

```
  Claude (Opus 5.5)          GitHub repo             Codex
  ─────────────────          ───────────             ─────
  designs + writes    ──push──▶  branch  ──PR──▶   reviews
  Luau, models, maps                                  │
        ▲                                             │
        └──────────── reads review comments ──────────┘
                             │
                      CI: lint, format, build
                             │
                    Rojo live-sync ──▶ Roblox Studio
                             │
                    Studio MCP ──▶ playtest, console, screenshots
```

Nobody edits anything by hand in Studio. Studio is a renderer and a test harness, not a source
of truth. Everything that matters is a file in the repo.

## Repo layout

```
/
├── src/
│   ├── shared/          → ReplicatedStorage.Shared
│   │   ├── Config/          ability, enemy, room, balance data (pure data modules)
│   │   ├── Combat/          the projectile modifier pipeline
│   │   └── Util/
│   ├── server/          → ServerScriptService.Server
│   │   ├── Run/             run state machine, room progression
│   │   ├── Enemies/         spawning, AI tick
│   │   ├── Data/            DataStore, profiles
│   │   └── Net/             remote handlers, validation
│   └── client/          → StarterPlayerScripts.Client
│       ├── Input/           thumbstick, keyboard, gamepad → one movement vector
│       ├── Camera/
│       ├── UI/
│       └── Fx/              projectile rendering, hit feedback
├── assets/              Blender sources + export scripts
├── docs/
├── .github/workflows/   CI
├── default.project.json Rojo
├── rokit.toml           pinned toolchain
├── wally.toml           packages
├── CLAUDE.md            rulebook for the builder
└── AGENTS.md            rulebook for the reviewer
```

## Non-negotiables

**1. The projectile pipeline is the core abstraction.**
Abilities are data that insert stages into an ordered pipeline. No ability is ever an `if`
branch in the shooting code. If this is done wrong, Phase 3 collapses.

**2. Server authority on everything that matters.**
Damage, death, currency, loot, ability grants, progression. The client predicts movement and
renders projectiles; the server owns the outcome. Roblox games get exploited the moment they
are popular — building this in later is a rewrite.

**3. Co-op-shaped from day one.**
Run state, ability stacks and enemy aggro are per-player-aware even in Phase 1 when there is
only one player. Retrofitting multiplayer onto singleton state is the classic way this project
dies at Phase 7.

**4. Device tiering is a first-class concern.**
Poly budgets, particle counts, projectile limits and lighting all read from a device tier
resolved at join. A phone and a desktop run the same code with different numbers.

**5. Strict Luau, everywhere.**
`--!strict` at the top of every file. Selene and StyLua gate every PR.

## Tooling

| Role | Tool | Status |
|---|---|---|
| Version control | Git + GitHub | installed, authenticated |
| Toolchain manager | Rokit | 1.2.0 |
| Sync | Rojo | 7.7.1 |
| Packages | Wally | 0.3.2 |
| Lint / format | Selene 0.32.0, StyLua 2.6.0 | pinned in `rokit.toml` |
| Engine | Roblox Studio | installed |
| Studio control | Roblox Studio MCP (built-in) | `mcp.bat` present, needs wiring |
| Art | Blender + Blender MCP | not installed — Phase 5 |
| Review | Codex | needs your confirmation |
