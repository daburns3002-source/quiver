# Roadmap — Archero-like for Roblox

Eight phases. Each one ends in a **playtest with a single question**. If the answer is no, we fix
that phase rather than building on top of it.

The ordering is deliberate. **The feel is validated before any content exists.** Phase 1 is the
riskiest phase in the project, which is exactly why it comes first and why it is grey boxes.

Working title: **TBD** (needs your call before the repo is named).

---

## Phase 0 — Pipeline

No gameplay. Build the machine that builds the game.

**Scope**

- Git repo + GitHub, branch protection, PR template, one milestone per phase
- Rokit toolchain pinned in `rokit.toml`: Rojo, Wally, Selene, StyLua
- Rojo project syncing `src/` into Studio; **the filesystem is the source of truth**, never Studio
- Roblox Studio MCP connected and verified end to end
- GitHub Actions CI: Selene lint, StyLua format check, `rojo build` smoke test
- `CLAUDE.md` and `AGENTS.md` so Claude (builder) and Codex (reviewer) share one rulebook
- A grey-box place that syncs, runs, and can be playtested through MCP

**Exit criteria** — I can change a file, see it in Studio, press play through MCP, read the
console, and open a PR that CI checks and Codex reviews. End to end, no manual steps.

**Playtest question** — none. This is plumbing.

---

## Phase 1 — Does move-or-shoot feel good?

The vertical slice of *feel*. One room, one enemy type, grey capsules.

**Scope**

- Top-down camera, fixed angle, correctly framed on phone / tablet / desktop
- Movement: mobile thumbstick, WASD, gamepad stick — all three, identical speed
- **Move-or-shoot**: auto-fire at nearest enemy while stationary, instant cancel on input
- One projectile, client-predicted and server-validated
- One enemy: the melee charger
- Obstacles that block your arrows but not theirs
- Hit feedback: flash, knockback, damage numbers, screen shake

**Exit criteria** — stopping to shoot and running to dodge feels tense and responsive on a phone.

**Playtest question** — *Does standing still to shoot feel like a real decision, or like a chore?*

> This is the most important moment in the project. If this fails, nothing after it matters.

---

## Phase 2 — Does a room-to-room loop hold up?

**Scope**

- Room system: spawn wave, clear all, doors open, walk through, next room
- All five enemy archetypes: melee charger, spread ranged, line ranged (red-line telegraph),
  hidden, tank
- Enemy AI as shared behaviour modules, data-driven stats
- Player death, run end, restart
- A 10-room grey-box run
- Room layout generator from a hand-authored layout library

**Exit criteria** — a 10-room run is playable start to finish without a crash.

**Playtest question** — *After five rooms, do you want a sixth?*

---

## Phase 3 — The ability engine

The heart of the game. Nothing here is cosmetic.

**Scope**

- **The projectile modifier pipeline** (see `RESEARCH-archero.md` §3). Everything else in this
  phase is data on top of it.
- XP, levelling, the choose-1-of-3 card screen
- About 25 abilities across count, pattern, flight, on-hit, stats, defensive, on-kill
- Ability stacking, caps, and exclusion rules
- Run summary screen showing the build you assembled

**Exit criteria** — a 10-room run ends with a visibly absurd shot pattern that you chose.

**Playtest question** — *Did two runs in a row feel meaningfully different?*

---

## Phase 4 — A real chapter

**Scope**

- Chapter 1 at 20 stages (shortened from Archero's 50 — see research §6)
- Boss every 10 stages; two bosses with multi-phase patterns
- Angel room (ability or heal), Devil room (power for max HP), treasure chest rooms
- Difficulty curve and enemy stat scaling
- Full run-fail / run-complete flow

**Exit criteria** — a complete 8–12 minute run with a boss kill at the end.

**Playtest question** — *Does losing at stage 17 make you want to start again immediately?*

---

## Phase 5 — Art and audio

The first phase where Blender enters the picture. Deliberately late — there is no point
modelling enemies whose behaviour might still change.

**Scope**

- Low-poly art direction locked: palette, silhouette rules, poly budgets per device tier
- Blender MCP pipeline: model → rig → animate → export → import to Roblox, scripted and repeatable
- Hero, five enemy archetypes, two bosses, modular environment kit
- VFX: projectiles, impacts, status effects, ability auras
- Audio: SFX for every verb, music per chapter, mix
- Device-tiered quality settings

**Exit criteria** — the game is visually coherent and holds 60fps on a mid-range phone.

**Playtest question** — *Does it look like a game you would click on in the Roblox discover page?*

---

## Phase 6 — Meta progression and persistence

**Scope**

- DataStore saves with session locking and migration versioning
- Gold, scrolls, run rewards
- Talent tree of permanent bonuses
- Equipment: weapons as shot-pipeline presets, plus armor, rings, pet
- Two or three heroes with distinct passives
- Full UI: main menu, inventory, upgrade screens

**Exit criteria** — a returning player is measurably stronger than a new one, and saves survive
a server restart.

**Playtest question** — *Does coming back tomorrow feel worth it?*

---

## Phase 7 — Co-op

The Roblox-native hook, and the reason to play this instead of the phone game.

**Scope**

- 2–4 player shared runs, per-player ability stacks
- Shared room clear conditions, revive mechanics
- Matchmaking or friend invite
- Network optimisation pass under four-player projectile load

**Exit criteria** — a four-player run is stable and no slower than solo.

**Playtest question** — *Is this better with a friend?*

---

## Phase 8 — Launch

**Scope**

- Monetisation: cosmetics and convenience only, **no energy gate**
- Analytics on funnel, run length, death stage, ability pick rates
- Anti-exploit audit — server authority on every damage and currency path
- Onboarding, tutorial, store page, thumbnails, trailer
- Soft launch, then iterate on the funnel data

---

## Working agreements

- Every phase is a milestone, every feature a PR. Claude writes, Codex reviews, CI gates.
- No phase starts before the previous playtest question gets a yes.
- The filesystem is the source of truth. Changes made by hand in Studio are lost.
- Everything data-driven that can be: abilities, enemies, rooms, loot, balance.
