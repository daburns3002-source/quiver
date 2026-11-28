# Co-op

Owner, 2026-10-27: **two players first, raised to three later.** Built after Endless
(`docs/ENDLESS.md`), which is why this doc is decisions-locked rather than a build plan.

Roadmap Phase 9. **Built 2026-11-06** (`Shared/Util/Coop`, `Run/Party`, `UI/CoopHud`, downed and
revive in `Run/RunSession`): party portals, a reserved run server per run (solo and the tutorial
too; in Studio, which cannot teleport, runs play in place), scaling locked at start, downed and
revive (radius 6, hold 2.5 s, 40%; 20 s bleed-out, then out until the next fight at 30%), shared
XP and kill coins, no player collision, the teammate arrow. **Lobby parties built 2026-11-20**
("Parties", below): invite a player in the server, and the leader's PLAY takes the party. **Not
built:** the arena footprint (the arenas are art imports now, 1:1 with their sheets, so they cannot
stretch), a public queue, three players.

---

## Parties (built 2026-11-20)

Owner, 2026-11-19: "make co-op work from the PLAY button too", then "have there be a party system
where you can invite someone in the server". `Shared/Util/PartyRules` (the pure rules,
`tests/PartyRules.spec`), `Run/Parties` (the server's one state), `UI/PartyScreen` and `UI/PartyAsk`.

- **Forming.** PARTY in the lobby lists the other players in this server with INVITE. The server
  checks both are free in its lobby (arrived, off the title, not choosing a class, not travelling,
  never on a run server), that the sender is in no party or leads one with room, that neither has
  another invite open (one out and one in each), and that the same pair is not asked again within
  `againSeconds` (20) of a NO or a lapse. An invite lapses after `inviteSeconds` (30). ACCEPT makes
  the sender the leader. Open invites a change makes impossible are taken away (`tidy`).
- **Leaving.** LEAVE, or leaving the server, takes a player out; a party left with one player is
  over; if the leader went and two or more remain, the next member leads.
- **Starting.** The leader's start (PLAY's screen or a portal) takes each member who is free with the
  level open (on hard, open on hard), wherever they stand, then whoever stands in the portal's mouth
  and is in no party, up to `maxParty`. A member who cannot come is told why (not opened, on the
  title, busy, the run full). **A member who starts a run without the whole party leaves the party**
  (picked over refusing them: a kid is never blocked from playing; the leader is told).
- **The round trip.** A party whose every member goes is written into the teleport's data
  (`groups`); the run server forms it again from its members' join data, and `sendToLobby` writes the
  parties there into the data back. Roblox's group teleport lands the group in one public server, where
  the party forms again within `regroupSeconds` (60) once every member is there. Teleport data passes
  through the client, so a party forms only when **every** member's data names the same party: one
  player's data can never put them in someone's party. A party whose members land apart (a full
  server) is simply not formed again.
- **Not built:** a party across servers (inviting a friend elsewhere is still Roblox's INVITE A FRIEND,
  which brings them here), a party card in the run HUD (the teammate arrow and names stand for it), and
  three players (`Coop.maxParty` is 2; the rules are written for more).

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

### The idle clock (built 2026-11-28)

A card screen and an Endless checkpoint hold the world for the whole party, and they used to hold
it for as long as one player left them open: a teammate away from the keyboard stopped the run for
good, and BACK TO LOBBY was the only way on (the four-playtester pass; owner the same day: "Yes,
add it"). With more than one player in the run the server now answers a screen left open
(`Shared/Util/IdlePick`, numbers in `Coop.idle`):

- **A card screen**, 30 seconds after it opens: the rarest card in the hand, the leftmost of
  equals. A redeal starts the 30 seconds again, and so does the next hand of a double level-up.
- **An Endless checkpoint**, 30 seconds after it opens: FULL HEAL for whoever has not picked.
  Never BANK & LEAVE, which ends the run for everybody, and never the Soulstone cache: nothing
  is paid for being away.
- **Alone, nothing is timed.** It counts the players in the run now, not the party's locked
  size, so a player whose teammate has left reads as long as they like.

The pick goes through the same server functions as a pressed one (`RunSession.chooseAbility`,
`RoomController.endlessPick`), so nothing about it is new to validate.

On screen (`UI/IdleClock`), one gold pill: **PICKING FOR YOU IN 9** over the open screen's own
heading for the chooser's last ten seconds; **WAITING FOR ALEX: 23** at the top of the screen for
a teammate with no screen of their own; **PICKED FOR YOU: MULTISHOT** once it is done. The clocks
it reads are Player attributes in server time (`DraftPickBy`, `CheckpointPickBy`).

Not timed: the end screen (anyone may press its buttons), MENU's panel and a first-time tip
(each already on a budget of its own).

Studio's Play has one player: `IdlePickSolo` on Workspace (Studio only) times a lone player's
screens so the clock can be watched there.

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
