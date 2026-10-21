# Quiver — builder rulebook

**Archero's combat inside a Pet Simulator / Steal an Egg progression shell.**
Low poly, cross-platform, co-op-shaped.

Run loop: `docs/RESEARCH-archero.md`. Meta loop: `docs/PROGRESSION.md`.
Phase plan: `docs/ROADMAP.md`. Lobby spec: `docs/LOBBY.md`.

## Commands

```bash
rojo serve                      # live-sync into Studio
rojo build -o build.rbxl        # smoke-test the build
wally install                   # fetch packages
selene src                      # lint
stylua src                      # format
stylua --check src              # CI-style format check
```

Run `selene generate-roblox-std` once per clone — `roblox.yml` is gitignored.

## Non-negotiables

**1. The projectile modifier pipeline is the core abstraction.**
Abilities are *data* that insert stages into an ordered pipeline:

```
BaseShot → [count] → [spawn pattern] → [flight behaviour] → [on-hit] → [on-kill]
```

No ability is ever an `if` branch inside the shooting code. If you find yourself special-casing
an ability name in combat logic, stop and extend the pipeline instead.

**2. Server authority on everything that matters.**
Damage, death, currency, loot, ability grants, progression. The client predicts movement and
renders projectiles; the server owns every outcome. Never trust a client-reported hit.

Collection games are exploit magnets far more than roguelikes are. **Hatch RNG is rolled on the
server, always.** The client never reports a coin total, a hatch result, a fusion or an area
clear — it asks, and the server decides.

**3. Co-op-shaped from day one.**
Run state, ability stacks and enemy aggro are per-player-aware even while only one player
exists. No singleton run state, ever.

**4. Data-driven by default.**
Abilities, enemies, rooms, loot and balance live in `src/shared/Config` as pure data modules —
no logic, no requires. A balance change should be a readable diff.

**5. Device tiering is first-class.**
Poly budgets, particle counts, projectile caps and lighting read from a tier resolved at join.
Phone and desktop run the same code with different numbers.

**6. Feel beats correctness in the input path.**
Fire must resume within one frame of the stick being released. If a design choice trades
responsiveness for tidiness, responsiveness wins.

**7. Saved data is sacred.**
Area unlocks, pets, coins and gear are a player's whole investment. Session locking, schema
versioning and a migration path from day one of persistence. A wipe in a collection game is
fatal in a way it is not in a pure roguelike. Never ship a save-schema change without a
migration.

**8. Numbers inflate; difficulty does not.**
Permanent multipliers scale exponentially per area while drafted abilities stay fixed. Enemy
stats scale off *expected player power at that area*, never flat values. Players outgrowing
old areas is the product, not a bug.

## Code conventions

- `--!strict` at the top of every Luau file. No exceptions.
- Tabs, 100 columns, double quotes — StyLua enforces it; run it before committing.
- One module per file, named after the file. `PascalCase` for modules and types,
  `camelCase` for locals and functions, `SCREAMING_SNAKE` for file-level constants.
- `*.server.luau` → Script, `*.client.luau` → LocalScript, plain `.luau` → ModuleScript.
- Services via `game:GetService()` at the top of the file, never mid-function.
- Config modules end with `table.freeze(...)`.
- Log through `Shared.Util.Log.forTag("Subsystem")` so MCP console reads are greppable.

## Workflow

- The filesystem is the source of truth. **Changes made by hand in Studio are lost.** Studio is
  a renderer and a test harness.
- One branch and one PR per feature. Branch names: `phase-N/short-description`.
- CI must be green before review: Selene, StyLua, `rojo build`.
- Codex reviews every PR. Read its comments and act on them before merging.
- No phase starts before the previous phase's playtest question gets a yes from the user.

## Repo layout

```
src/shared/   → ReplicatedStorage.Shared    Config/ Combat/ Util/
src/server/   → ServerScriptService.Server  Run/ Enemies/ Data/ Net/
src/client/   → StarterPlayerScripts.Client Input/ Camera/ UI/ Fx/
assets/       Blender sources and export scripts (Phase 5)
docs/         research, roadmap, architecture
```
