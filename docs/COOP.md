# Co-op

Owner, 2026-10-27: **two players first, raised to three later.** Built after Endless
(`docs/ENDLESS.md`), which is why this doc is decisions-locked rather than a build plan.

Roadmap Phase 9. Everything below is settled; nothing is implemented.

---

## What is already done, and what actually blocks it

`Run/RunSession` is keyed by Player and says so in its own header: health, damage, the shot
pipeline, the drafted loadout and the pet state all hang off a session, never a singleton. That
was the right call and it holds.

**The blocker is the arena, not the player state.** `Arena/Arena.luau` keeps module-level
state — `blockersFolder`, `exitGate`, `boxes`, `halfSize`, `layoutVersion` — so there is
exactly one arena per server, and `Run/RoomController` is one loop over it.

### One party per server

Do **not** run several arenas in one Workspace. That means coordinate offsets on every room
build, a pathing grid per arena, split projectile budgets against the device tiers, and a party
handle threaded through every `Arena` collision query.

Instead: the lobby is the public server, and starting a run does
`TeleportService:ReserveServer` and sends the party there. `Arena` stays a singleton,
`RoomController` gains *N sessions attached* instead of one, and matchmaking comes free —
friend invite first, a public queue later.

What that leaves to build: a `Party` concept owning the shared clear condition, the reserved
server handoff, and the per-player pieces below.

---

## Scaling

Party size is **locked at run start**. Recompute it live and a party can kick a player to
trivialise a boss.

| | Solo | 2 players | 3 players (later) |
|---|---|---|---|
| Enemy count | ×1.0 | ×1.65 | ×2.3 |
| Enemy health | ×1.0 | ×1.10 | ×1.20 |
| Enemy damage | ×1.0 | ×1.0 | ×1.0 |
| Boss health | ×1.0 | ×1.7 | ×2.3 |
| Arena footprint | ×1.0 | ×1.2 | ×1.35 |

**Count, not health.** More enemies keeps the game feeling like itself; health bloat makes
everything spongy. Damage is untouched — two players do not need to be hit harder, there are
just more things hitting.

**Bosses are the exception.** Count cannot scale on a single body, so boss health takes it.

### The arena does not double

The camera is the constraint, not the floor. Double the footprint and either the camera pulls
out until enemies are specks on a phone, or players lose each other off-screen — plus twice the
walking and half the chance two players fight the same thing.

×1.2 for two players, through a `Balance.coop.arenaScale[partySize]` multiplier on the existing
procedural kits. **One data value, not a second set of maps** — the kits build from code
because the filesystem is the source of truth, and that property is what makes this cheap.

---

## The per-player pieces

### Downed and revive

After Second Wind is spent (it is already per-session), a player at zero health goes **downed**
rather than dead: alive, immobile, on a timer. A teammate standing inside a revive radius for a
hold brings them back at a share of max health.

The run wipes when **every** player is down. Two players means one can always save the other,
which is the co-op fantasy and the reason the mode exists.

### Players do not block each other

No player-player collision, and **shots pass through teammates**. A melee class standing in a
Ranger's line is a bug, not a tactic.

### Camera and the teammate arrow

Per-player camera, not a party centroid — centroid framing is wrong on a phone and makes one
player's movement drag the other's view. The cost is losing your teammate off-screen, so there
is an **off-screen teammate arrow** at the edge of the HUD pointing at them, with their
distance.

### Pickups are shared-credit

One pickup, everyone gets it. XP crystals and hearts already fly to their owner on a clear
(`Balance.Pickups`); in co-op a crystal taken by either player credits both. Per-player drops
make teammates race each other for the floor instead of fighting what is on it.

**Drafted cards stay per-player.** `Run/Loadout` already keeps the draft pool per session, and
its comment names two players drawing from one pool as the first thing that breaks. It is
right.

---

## Co-op Endless

Falls out almost free once Endless is a stage mode and the party loop runs it. The two
decisions it needs:

- **Floor credit** — every player alive at a floor gets credit for it. `endlessBest` is per
  account, milestones are claimed once per account.
- **A player leaves mid-run** — scaling is locked at run start, so nothing changes. The
  remaining player keeps the harder run. Do not rescale down; that is the kick exploit again.

---

## Unresolved

- **Aggro.** With more than one player, enemies need an explicit target-selection rule.
  Nearest, or threat-based. `docs/ARCHITECTURE.md` already calls aggro per-player-aware.
- **Network pass.** Two players' projectiles and pets against the device tiers
  (`docs/PERFORMANCE.md`). The projectile budget was sized for one player.
- **Mid-run join.** Almost certainly no — a player joining at floor 30 of an Endless run has no
  cards and is instantly downed.

---

## Phase note

The roadmap puts co-op at Phase 9, after art and audio. Building it now means retrofitting the
party model through systems that are still moving, which is why Endless goes first: it is
nearly all data, it is testable solo, and it makes co-op Endless free later.
