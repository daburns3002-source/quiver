# Roadmap — Quiver

**Archero's combat inside a Pet Simulator / Steal an Egg progression shell.**
Run loop: `docs/RESEARCH-archero.md`. Meta loop: `docs/PROGRESSION.md`.

Ten phases. Each one ends in a **playtest with a single question**. If the answer is no, we fix
that phase rather than building on top of it.

The ordering is deliberate. **The combat feel is validated before any content, any lobby and any
art exists.** Phase 1 is the riskiest phase in the project, which is exactly why it comes first
and why it is grey boxes. A beautiful lobby in front of combat that does not feel good is a dead
game; good combat in a grey box can be dressed later.

---

## Phase 0 — Pipeline ✅

No gameplay. The machine that builds the game.

Rokit toolchain, Rojo sync, CI (Selene / StyLua / `rojo build`), protected `main`,
`CLAUDE.md` + `AGENTS.md`, docs. Done and verified end to end.

---

## Phase 1 — Does move-or-shoot feel good?

One room, one enemy type, grey capsules.

- Top-down camera, framed correctly on phone, tablet and desktop
- Movement: mobile thumbstick, WASD, gamepad stick — identical speed on all three
- **Move-or-shoot**: auto-fire at nearest enemy while still, instant cancel on input
- One projectile, client-predicted, server-validated
- One enemy: the melee charger
- Obstacles that block your arrows but not theirs
- Hit feedback: flash, knockback, damage numbers, shake

**Playtest question** — *Does standing still to shoot feel like a real decision, or like a chore?*

> The most important moment in the project. If this fails, nothing after it matters.

---

## Phase 2 — Does a room-to-room loop hold up?

- Room system: spawn wave → clear → doors open → next room
- All five enemy archetypes: melee charger, spread ranged, line ranged (red-line telegraph),
  hidden, tank
- AI as shared behaviour modules over data-driven stats
- Death, run end, restart
- A 10-room grey-box run

**Playtest question** — *After five rooms, do you want a sixth?*

---

## Phase 3 — The ability engine

The heart of the run loop.

- **The projectile modifier pipeline** (`RESEARCH-archero.md` §3). Everything else is data on it.
- XP, levelling, the choose-1-of-3 card screen
- ~25 abilities across count, pattern, flight, on-hit, stats, defensive, on-kill
- Stacking rules, caps, exclusions
- Run summary showing the build you assembled

**Playtest question** — *Did two runs in a row feel meaningfully different?*

---

## Phase 4 — Area 1

- 20 stages, boss every 10, two bosses with multi-phase patterns
- Angel room (ability or heal), Devil room (power for max HP), treasure chests
- Difficulty curve and enemy scaling
- Run-fail and run-complete flow, coins paid out on completion

**Playtest question** — *Does losing at stage 17 make you want to start again immediately?*

---

## Phase 5 — The lobby and the gate

Where the game stops being a roguelike and starts being a progression game. This is the first
thing a new player sees, so it carries the art direction — and unlike every other phase, **it
gets its art pass in-phase** rather than waiting for Phase 8.

- Persistent lobby hub, other players visible
- **Area portals in a row**: cleared ones open, the next visibly locked with its requirement,
  later ones fogged but visible
- **Clear Area 1's boss → Area 2 portal unlocks, permanently**
- **Persistence lands here**: DataStore with session locking, schema versioning, migration path.
  Area unlocks and coins must survive death, rejoin and server restart.
- Coin payout, coin display, the first spend sink
- Lobby built to match the reference images in low poly — see `docs/LOBBY.md` for the
  acceptance standard, which is stricter than the usual phase gate

**Playtest question** — *Does walking into the lobby make you want to find out what is behind
the locked portal?*

---

## Phase 6 — Pets and eggs

The collection hook.

- Egg stands, one tier per unlocked area, **server-rolled hatch RNG**
- Rarity ladder: Common → Mythic, plus Golden and Rainbow variants
- Pets as permanent damage multipliers *and* visible combat companions that act in runs
- Equip limit (~3), inventory, duplicate fusion so no hatch is ever a dead hatch
- Pet replication budget and cull for a busy lobby

**Playtest question** — *Does opening an egg feel good enough to do it ten more times?*

---

## Phase 7 — Areas 2 and 3

Proves the content pipeline scales and that the two loops feed each other.

- Two new areas: own enemy roster, theme, coin tier, egg tier
- Exponential coin scaling, linear difficulty scaling
  (`PROGRESSION.md` — numbers inflate, difficulty does not)
- Enemy stats scale off *expected player power at that area*, not flat values
- Replay-for-farming flow

**Playtest question** — *Did you grind Area 2 to afford the pets that got you through Area 3 —
and did that feel like progress rather than a wall?*

---

## Phase 8 — Art and audio

Blender enters. Deliberately late — no point modelling enemies whose behaviour might change.
The lobby is already art-complete from Phase 5; this is everything else.

- Low-poly direction locked: palette, silhouette rules, poly budgets per device tier
- Blender MCP pipeline: model → rig → animate → export → import, scripted and repeatable
- Hero, five archetypes across three areas, bosses, modular environment kits
- VFX: projectiles, impacts, status, ability auras, hatch sequences
- Audio: SFX for every verb, music per area, mix
- Device-tiered quality settings

**Playtest question** — *Does it look like a game you would click on in the Roblox discover page?*

---

## Phase 9 — Co-op

The Roblox-native hook, and the reason to play this instead of the phone game.

- 2–4 player shared runs, per-player ability stacks
- Shared clear conditions, revives
- Matchmaking or friend invite
- Network pass under four-player projectile and pet load

**Playtest question** — *Is this better with a friend?*

---

## Phase 10 — Launch

- Monetisation: gems, hatch multipliers, inventory slots, cosmetics. **No energy gate.**
- Analytics: funnel, run length, death stage, ability pick rates, hatch and unlock points
- Anti-exploit audit — server authority on every damage, currency, hatch and unlock path
- Onboarding, store page, thumbnails, trailer
- Soft launch, then iterate on funnel data

---

## Working agreements

- Every phase is a milestone, every feature a PR. Claude writes, Codex reviews, CI gates.
- No phase starts before the previous playtest question gets a yes.
- The filesystem is the source of truth. Hand edits in Studio are lost.
- Everything data-driven that can be: abilities, enemies, rooms, pets, loot, balance.
