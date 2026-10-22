# Arrow Legends — builder rulebook

**Archero's combat inside a Pet Simulator / Steal an Egg progression shell.**
Low poly, cross-platform, co-op-shaped.

Run loop: `docs/RESEARCH-archero.md`. Meta loop: `docs/PROGRESSION.md`.
Phase plan: `docs/ROADMAP.md`. Lobby spec: `docs/LOBBY.md`.

**Bugs that shipped, and what fixed them: `docs/FIXES.md`.** Written to be
found by symptom. Read it before debugging anything that sounds familiar, and
add to it in the same PR as every fix — the same classes of bug recur here.

## Where we are

**Active again, mid Phase 3.** Paused on 2026-10-21 and resumed the same
day; the focus since has been making projectiles behave like the Archero 2
footage, measured rather than eyeballed.

What exists and works, all verified in Studio rather than only by the gates:

- **Phases 1 and 2:** move-or-shoot, five enemy archetypes, ten-room runs,
  death and restart. Playtest 1 passed. Playtest 2's question — *after five
  rooms, do you want a sixth?* — was never formally answered.
- **Upgrades follow the owner's card design** (`design_handoff_upgrade_cards`,
  chosen 2026-10-22): 26 skills, each with levels, a rarity and a stat line per
  level (`Config/Abilities`, `Config/Rarities`), dealt weighted by rarity with
  2 rerolls a run, and a Heal filler card. Momentum is banked by moving and
  spent on the 2 s of shooting after; every archer crits 5% of the time.
- **Phase 3, mostly:** the shot pipeline with its abilities as data, XP and a
  choose-one-of-three draft that pauses the world, crit, splash, Ricochet
  (enemy to enemy), Bouncy Wall, Tracking Eye (homing), Double Shot
  (the volley again 0.12 s later), Blaze (burns, server-side in
  `Combat/Burning`), chain-on-kill,
  Momentum, Second Wind, exclusions (`Abilities.excludes`, read both ways),
  a run summary, and the client's prediction replicated from the server.
- **One flight for both sides.** `Shared/Combat/ProjectileFlight` steps every
  projectile on the server *and* in the renderer — sweep, overlap pass,
  sub-steps, bounce, pierce, homing — so what is drawn is what fires. Change
  how projectiles move there and only there.
- **Measured speeds** (`docs/RESEARCH-archero.md` §7): arrows 110 studs/s (footage 190, slowed at playtest),
  slow enemy orbs 12, the Lancer 28, Diagonal Arrows ±30°.
- **Two stage shapes, chosen per stage** (`Balance.Stages`, `Balance.stage`):
  *Rooms* (rooms joined by doors) and *Waves* (one arena; a Valkyrie offers
  one of two skills on every 5th wave, an Angel a stat or heal on every 9th,
  a boss wave every 10th). The owner sets which shape each stage is,
  depending on where in the game it sits. Boss waves are a Bulwark with an
  escort until Phase 4 brings real bosses.
- **Archero 2 art pass** (`docs/ART-archero2.md`): enemies restyled as round
  toy creatures with glowing eyes and contact shadows (ladybug, one-eyed
  slime, hooded mage, rock-shell brute, spiked urchin); a blue ring under
  the player, a segmented red ring under the aimed-at enemy, a red "!" over
  enemies winding up; a dressed arena (flagstones, caps, orb lamps, grass
  edge) under soft bright lighting with tier-gated bloom; magenta sparkling
  enemy orbs. Presentation only.
- **The dash** (4-second cooldown, readiness bar), player hit feedback, and
  draft enemy bodies.
- **Archero 2 proportions:** a portrait 35 × 58 room, a camera that fits the
  room's width and follows depth only, spawn markers, orb enemy shots.

The numbers in `Config/Balance` are the last ones asked for or measured, not
settled ones. **Damage is on Archero 2's scale** (docs/RESEARCH-archero2.md
§3): player 225 HP hitting for 100, grunts die in three hits, about four
enemy hits kill the player — which replaced the owner's earlier "enemy
health ×1.5". Damage numbers are white, red crits, orange burns.

**XP crystals and hearts** (`Run/Pickups`, `Fx/PickupFx`): a kill's XP
drops as cyan crystals; walk over your own to take them mid-fight, and any
left are drawn in when the wave or room clears. Hearts drop on 5% of kills and on every
Valkyrie wave, wait on the floor, and heal 20% of max health when walked
over, full health or not.

**Revive** (`Balance.Revive`): once per stage, automatically, after Second
Wind — full health, 2.5 s untouchable behind a gold shield, and enemy shots
within 12 studs cleared.

Not done: real bosses (the owner wants to think about them first — do not
start); Phase 3's playtest question — *did two runs in a row feel
meaningfully different?* — which needs the owner.

**Enemies arrive in triangles of three** (`Balance.Spawning.clusterSize`),
the tip pointing at the player; the row swings round the tip when a wall is
behind it. Blocked arrows stick in the wall for a moment.

To resume: `rojo serve`, connect the Studio plugin, Play. Read
`docs/FIXES.md` before debugging anything — most of what can go wrong here
already has.

**What first run fixed, so it does not get re-broken:**

- Chargers deadlocked against pillars, which soft-locked the room. Fixed by
  `Arena.deflectionNormal` plus a committed `slideSign`. Measure the normal at
  the body, not the probe, and never re-derive the slide side per frame — an
  enemy level with its target flips it and jitters on the spot for ever.
- `FiringSystem` must call `RunSession.isStationary` every frame and *before*
  the cooldown check: that call is what advances the settle timer.
- `TopDownCamera` re-asserts `CameraType = Scriptable` every frame, because
  Roblox's camera script resets it to Custom on each character spawn.
- `Arena.build` deletes the place's default baseplate. Its top surface sits at
  exactly y = 0, the same plane as the arena floor, and the two z-fight.
- The place has no `PlayerModule`, so `src/client/Input/` owns movement:
  world-space, keyboard, gamepad and a dynamic on-screen thumbstick. Roblox's
  default controller is camera-relative and fights a fixed-yaw camera anyway.

**Known rough edges, deliberately not addressed:**

- `Arena.deflectionNormal` handles obstacles but not the outer walls.
- **Enemy visuals may still overlap pillars slightly.** Hitboxes are now
  resolved by their turned footprint (`Arena.resolveBox`) and measured 0 of
  2,819 samples inside a pillar. A probe of *visible* parts still found
  corners up to 0.59 studs in, but it counted every non-transparent part,
  and the "widest" parts it named (a Base 8 studs across) look like the
  ground rings drawn under enemies, not bodies. Unconfirmed — check which
  parts before fixing anything.

**Testing over MCP, learned the hard way:**

- `execute_luau` does **not** share the module `require` cache with the running
  game. A probe calling `EnemyManager.aliveCount()` gets a fresh, empty module
  and returns zeros. Probe the DataModel, never module state.
- **A card screen opened between probes pauses the run silently.** A probe
  that listens for `AbilityOffer` only answers offers made while it runs; one
  already open stays open and the next probe records zero shots. Fire
  `AbilityChosen` once at the start of every probe.
- **`GetPartBoundsInBox` reports a rotated part by its axis-aligned bounds**,
  which swell as it turns, so it over-reports clipping. Measure a part's real
  corners instead — and over several rooms: one quiet run read 0.1 studs at
  most, the next found turned hitbox corners 0.62 studs into pillars. That
  one is real and unfixed — see "Known rough edges".
- **Arrow impact sparks are round parts named `Impact`** in
  `ProjectileVisuals`, beside the enemy orbs. Filter orbs by
  `Name == "Projectile"`, not by shape, or stationary sparks read as orbs that
  have stopped moving.
- `screen_capture` in play mode returns the GUI layer over a black 3D viewport.
  That is a capture limitation, not a render fault — verify geometry instead.
- **Never call a client Fx module's `start()` in the Edit datamodel** to
  preview it. Its RenderStepped connection outlives the probe, keeps running
  against the Edit scene's stale `Balance` cache, and logs errors under
  `StarterPlayer.StarterPlayerScripts…` until Studio restarts. Build the
  parts once and capture instead.
- To move the character from a probe, call `Humanoid:Move` from
  `RunService.Stepped`: `MoveController` resets it every RenderStepped, and
  a teleport does not count as moving for the move-or-shoot rule.
- `VirtualInputManager:SendKeyEvent` and `Lighting.Technology` are capability
  blocked from `execute_luau`, so synthetic key input is not available.
- `rojo serve` does not reload structural changes to `default.project.json`.
  Restart it for those; script edits live-sync fine.
- **In the Edit datamodel, `require` caches persist between probes.** Studio
  can hold the current source while a module you required earlier in the
  session keeps returning its old table — so `Balance.Player.dash` reads as
  nil minutes after the field shipped. Play mode is unaffected; it builds a
  fresh datamodel with fresh caches. **Check `.Source`, never a required
  value**, when the question is "did this reach Studio".
- **A dead sync looks exactly like a passing test run.** `rojo serve` can keep
  its process alive while the Studio plugin is no longer connected — branch
  switching does it — and then Studio quietly runs the code from whenever the
  link broke. The suite still passes, on the old code, and reports a count
  that looks plausible. Before trusting any in-Roblox result after a branch
  switch or a `rojo serve` restart, check that a file you just changed is
  actually in Studio: read `.Source` and look for the change. A restart drops
  the plugin and reconnecting is a manual click in Studio, which nothing
  automated can do for you.

**Still blocked on the user:** lobby reference images, which belong in
`assets/reference/lobby/` and are the spec for `docs/LOBBY.md`.

**Codex is not reviewing this project.** That was the Phase 0 plan and it was
dropped — PR #3 merged with zero reviews and zero comments. **Claude
self-reviews instead**, against the priorities in `AGENTS.md`.

Self-review is weaker than a second pair of eyes and should be treated that
way. It catches what a careful reread catches: exploitable client trust,
unchecked assumptions, dead paths. It does not catch a bad idea that was bad
when it was written, because the same reasoning that wrote it is checking it.
So bias the pass toward the things in `AGENTS.md` that are mechanical to
verify — server authority, remote validation, `if` branches that should be
pipeline stages — and raise anything that needs real judgement to the user
instead of ruling on it.

Note that branch protection was configured around Codex (`docs/SETUP.md` sets
required approving reviews to 0 and relies on conversation resolution), so
nothing in GitHub enforces this. It holds only because it is written here.

**Settled design decisions, so they do not get relitigated:**

- Area gating is on **beating the boss**, not on a coin price, so the run loop
  stays load-bearing.
- **No raiding and no PvP.** Raiding was discussed and explicitly rejected.
- **No energy gate.**
- Rebirth is in scope but late; the save schema must not preclude it.
- Co-op is Phase 9, but state is per-player from day one regardless.
- **Drafted abilities stack** (with caps), unlike Archero 2's one-copy rule
  (owner, 2026-10-22).

## Commands

```bash
rojo serve                      # live-sync into Studio
rojo build -o build.rbxl        # smoke-test the build
wally install                   # fetch packages
selene src tests                # lint
stylua src tests                # format
stylua --check src tests        # CI-style format check
```

## Tests

`tests/` syncs to `ServerStorage.Tests` and runs **inside** Roblox, because the
code under test speaks `Vector3` and `CFrame` and there is no honest way to
stub those. Driven over MCP in one call, with the game playing:

```lua
local tests = game:GetService("ServerStorage").Tests
local TestRunner = require(tests.TestRunner)
local result = TestRunner.runAll(tests)
return { TestRunner.summarise(result), result.failures }
```

They exist because the four gates cannot catch what this project actually
gets wrong. Selene, StyLua, `rojo build` and `luau-lsp` were all green on a
charger that deadlocked against a pillar, a burrower that dived exactly once,
a telegraph that drew a line its shot did not follow, a wave that spawned on
top of the player, and an arrow that flew straight through the enemy it was
aimed at. Every one was geometry or state.

**Shape casts ignore what they already overlap.** `Blockcast`, `Spherecast`
and `Raycast` all decline to report a body the shape is intersecting at the
moment the cast starts — measured, not assumed: a 4.2-stud arrow box reports
a clean miss against a target it overlaps by 0.1 studs, by 0.6, and dead
centre. So any swept shape has a dead zone its own size, and anything that
*moves into* that zone is invisible for as long as it stays there. Static
geometry cannot do this; enemies do it constantly. `ProjectileSystem` pays
for it with a `GetPartBoundsInBox` pass every step, and
`tests/HitDetection.spec.luau` pins the behaviour so a future engine change
surfaces as a failing test rather than as a worse game.

A spec returns a function taking the `t` helper:

```lua
return function(t)
    t.test("three shots keep one on centre", function()
        t.near(out[2].angleOffset, 0, 1e-9)
    end)
end
```

Assert *relationships*, not values — retuning a number must never fail a test,
but tuning it into a shape that cannot work should. `Balance.spec` is the model
for this.

**Changing `default.project.json` needs `rojo serve` restarted.** It does not
reload structural project changes, and a restart drops the Studio plugin, so
reconnecting is a manual click.

Type check — the only thing that catches strict-mode errors without opening Studio:

```bash
rojo sourcemap default.project.json -o sourcemap.json
luau-lsp analyze --sourcemap=sourcemap.json --defs=globalTypes.d.luau src tests
```

Once per clone (all three outputs are gitignored):

```bash
selene generate-roblox-std
curl -sfL -o globalTypes.d.luau https://raw.githubusercontent.com/JohnnyMorganz/luau-lsp/main/scripts/globalTypes.d.luau
```

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
- Every PR gets a self-review pass against the priorities in `AGENTS.md`,
  exploitability first, before it is merged. Report what the pass found — "no
  findings" is a result worth stating, and silence is not the same as clean.
- No phase starts before the previous phase's playtest question gets a yes from the user.

## Repo layout

```
src/shared/   → ReplicatedStorage.Shared    Config/ Combat/ Util/
src/server/   → ServerScriptService.Server  Run/ Enemies/ Data/ Net/
src/client/   → StarterPlayerScripts.Client Input/ Camera/ UI/ Fx/
assets/       Blender sources and export scripts (Phase 5)
docs/         research, roadmap, architecture
```
