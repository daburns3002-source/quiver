# Quiver — reviewer rulebook

This repo is built by Claude and reviewed by Codex. This file is the review contract.
The builder's rulebook is `CLAUDE.md`; the two must not contradict each other.

Design reference: `docs/RESEARCH-archero.md`. Phase plan: `docs/ROADMAP.md`.

## What this project is

**Archero's combat inside a Pet Simulator / Steal an Egg progression shell.**

The defining mechanic is **move-or-shoot**: the player auto-fires at the nearest enemy while
stationary and stops firing the instant they move. Runs are room-to-room; abilities are drafted
1-of-3 on level-up and lost on death.

Around that sits a persistent meta loop — a lobby, area portals that unlock permanently when
you beat an area's boss, coins, eggs and collectable pets that are both damage multipliers and
combat companions. See `docs/PROGRESSION.md`.

## Review priorities, in order

**1. Exploitability.** This is the highest-value thing a reviewer catches in a Roblox project.
Flag any path where a client can influence damage, health, currency, loot, ability grants or
progression. Remotes must validate every argument, including type, range and ownership. Assume
every client is hostile.

The progression shell raises the stakes: **hatch RNG, fusion results, coin grants and area
unlocks must be server-decided.** A client that reports its own hatch result, coin total or
clear is a blocking finding, every time.

**2. Pipeline violations.** Abilities must be data inserted into the projectile modifier
pipeline, never `if abilityName == ...` branches in combat code. A special case in the shooting
path is a design bug, not a style nit — flag it as blocking.

**3. Singleton run state.** The game must stay co-op-ready. Anything that assumes exactly one
player — a module-level `currentRun`, a global ability list, a single player reference — is a
blocking finding even though co-op ships in Phase 7.

**4. Performance under load.** Projectile counts compound multiplicatively by design; a run can
end with hundreds of live projectiles. Flag per-frame allocations, unbounded instance creation,
uncleaned connections, and anything O(n²) over enemies or projectiles.

**5. Memory and connection leaks.** Every `:Connect` needs a disconnect path. Every instance
created during a run needs a destroy path on run end.

**6. Save-schema safety.** Any change to persisted data needs a version bump and a migration
path. Players' pets, coins and unlocks are their whole investment — an unmigrated schema change
is a blocking finding.

**7. Correctness and clarity.** Normal code review.

## Conventions to enforce

- `--!strict` on every Luau file.
- Config modules in `src/shared/Config` are pure data: no logic, no requires, frozen with
  `table.freeze`.
- Services fetched with `game:GetService()` at file top.
- Naming: `PascalCase` modules and types, `camelCase` locals and functions.
- StyLua and Selene are CI-enforced, so do not spend review on formatting.

## What not to flag

- Formatting — CI handles it.
- Missing art, audio or VFX before Phase 5. Grey boxes are intentional until then.
- Missing content (enemy variety, ability count, chapters) ahead of its phase. Check the PR's
  phase label in `docs/ROADMAP.md` before calling something incomplete.
- Absent co-op *features*. Only co-op-hostile *architecture* is in scope before Phase 7.

## Review format

Leave findings as inline PR comments. Mark each one **blocking** or **non-blocking**. For
blocking findings, state the concrete failure: the input, the state, and the wrong outcome.
