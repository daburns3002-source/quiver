# What's next

Written 2026-10-29 from the owner's list, for when the weekly usage resets on the 31st.

**This is not a one-day list.** Landing the stack is a day. Co-op is a phase. The arena 3 and 4
content is dozens of models. The order below matters more than the list does, because most of
it is blocked behind one thing.

---

## 0. Land the stack — everything else waits on this

`main` is on `SaveSchema.VERSION = 2`. Four unlanded versions sit on top of it, each written as
if the ones below had already landed. **Land them bottom-up and nobody renumbers a migration**
(CLAUDE.md non-negotiable 7). Land them out of order and someone ships a migration for a version
that never existed.

| # | Work | Schema | Owner session |
|---|---|---|---|
| 1 | Pets, eggs, hatchery | **v3** | Egg hatching modelled on Tap Simulator Reborn |
| 2 | Gear screen, merge tiers | none | Gear screen fixes, C/B/A/S merge tiers |
| 3 | Class select | **v4** | unassigned — small (4 files) |
| 4 | Pity | **v5** | unassigned — small (2 files) |
| 5 | Lobby rebuild | none | Lobby: gear area, sprint and jump, portal level select |
| 6 | Endless | **v6** | Implement Endless mode — rebase, close #398 |

Recovery for each: branch off `main`, then

```
git checkout phase-3/swept-up-work -- <its files>
```

The per-feature file table is in PR #398's description. For shared files — `SaveSchema`,
`Wallet`, `Shop`, `Remotes`, `Main.server`, `Main.client`, `RunSession`, `PortalScreen`,
`ShopScreen`, `Sounds`, `PetCombat` — **take only your own hunks**, never the whole file.

Two traps:

- **`perRow` lands at 5.** The 5→6 change belongs to Endless, not the lobby. Land the lobby at
  6 and its own row-count test fails for a reason that has nothing to do with it.
- **The shared checkout is parked on `phase-3/endless-mode`, not `main`,** deliberately, so the
  other sessions' files stay in the working tree. Only switch it once they have recovered.

This covers three of the owner's asks at once: **the new lobby finished and imported** (step 5),
**the UI fixes updated** (step 5 plus PR #399), and **Endless implemented** (step 6 — it is
already built, it needs landing, not building).

### Codex's changes must survive this — the one real risk

The owner: *"all of the changes that codex made should stay in the game, especially the ui."*

The sweep commit has a bucket nobody has claimed. From #398's table, these belong to no listed
feature:

`TopDownCamera`, `Fx/MusicFx`, `Fx/SoundFx`, `Input/MoveController`, `UI/ShopScreen`,
`UI/TutorialPrompts`, `first/Loading.client`, `Combat/HeldWeapon`, `Data/Shop`,
`Config/LoadingScreen`, `Config/Shop`, `Config/Sounds`, `Config/Tutorial`, `Util/LoadingPick`,
`Util/ShopRules`, `upgrade_cards.md`, and a Thornwood arena concept PNG.

**That unclaimed bucket is where Codex's UI work would get dropped.** Before
`phase-3/swept-up-work` is abandoned, go through it file by file and give every hunk an owner.
Some may already be in PR #399. Nothing gets dropped on the grounds that no session claimed it.

---

## 1. Model pipeline — settle this before generating in bulk

The owner is moving to **Tripo 3D** for model generation, importing to Roblox, with texturing
and animation done here.

### Polygon budgets

Measured from what already ships (`docs/PERFORMANCE.md`, 2026-10-25), not invented:

| Kind | What ships now | Budget for new work |
|---|---|---|
| Enemy | 704 – 9,520 tris | **≤ 10,000** |
| Boss | 11,172 – 11,536 | **≤ 12,000** |
| Pet | 476 – 11,356 (most 1,300–5,100) | **≤ 6,000** |
| Weapon | 154 – 4,252 | **≤ 4,500** |
| Arena kit piece | ~560 avg, Bramble Hedge 2,364 | **≤ 2,500** (used up to 16× a room) |
| Whole room | 125k – 180k tris, 145–270 draws, 2.5–3.1 GPU ms | **stay under 180k** |

### Triangles are not the real constraint — part count is

This is the thing to carry into Tripo. A room already draws 125–180k triangles in about 3 ms of
GPU and that was never the problem. The biggest client cost was **`Fx/ModelAnimator`**, which
poses every part of every clip-driven model every frame — 1.46 ms a frame for 20 enemies *after*
a 1.9× optimisation, and **a phone runs Luau several times slower than the test PC**.

Every GLB primitive becomes its own MeshPart, posed each frame. So:

- **Glimmerhorn is the cautionary tale**: 11,356 triangles but **348 parts**. It is expensive
  because of the parts, not the triangles.
- Across all 59 clip-driven models: 1,819 parts, but **621 if merged**. Merging primitives that
  ride the same joint with the same material is the single biggest win available.
- **Part budget for a new pet or enemy: ≤ 40 parts.** Under 20 is better. Triangles can go to
  the limits above; parts should not.

### Tripo specifics to work out on the first model

- Tripo output is typically dense and organic. It will need **decimation** to the budgets and
  reshaping to the game's faceted low-poly blocky style. The standing rule is that a model
  matches its reference sheet **1:1 in game** — Tripo output that merely resembles the sheet
  gets redone.
- Decide **where merging happens** — in Tripo, in Blender before import, or at import — and
  then make it the default rather than a per-model decision.
- Rigging and clips: the existing route is GLB clips driven by `Util/ModelClip` and
  `Fx/ModelAnimator`, with `.rbxmx` KeyframeSequences for weapons. Confirm Tripo rigs import
  into it, **on one model, before generating a batch.**

**Do one enemy end to end first.** Generate, decimate, import, texture, animate, measure it, put
it in a room. Then scale up. A pipeline problem found on model 1 is an afternoon; found on model
30 it is a re-import of 30 models.

---

## 2. Content — arenas 3 and 4

Blocked on the pipeline above, not on the merge train.

- **Arena 4**: 3D models for the arena itself.
- **Arena 3 and 4**: enemies, pets and weapons.

Drowned Village (area 3) already has design work and five enemies defined in
`docs/ENEMIES-AND-ARENAS.md` §3, and the owner has imported them into Studio. Start there —
it is the shortest path from the new pipeline to something playable.

The `add-enemy`, `add-weapon` and `add-arena` skills already encode the existing route; Tripo
replaces the model-source step in each, not the rest.

---

## 3. Co-op

Design is settled in `docs/COOP.md` — **2 players first, 3 later**. Not started.

The short version: run state is already per-player and co-op-shaped. The blocker is that
`Arena.luau` and the room loop are server singletons, so the plan is **one party per reserved
server** rather than several arenas in one place. Scaling locks at run start: enemy count ×1.65
for two players, health ×1.10, damage untouched, boss health ×1.7, arena footprint ×1.2.

Then the per-player pieces: downed-and-revive after Second Wind, no player-player collision,
shots passing through teammates, an off-screen teammate arrow, shared-credit pickups.

Still open in that doc: the aggro target rule, the network pass against device tiers, and
whether mid-run join is allowed (recommendation: no).

Co-op Endless falls out nearly free once Endless is a stage mode and the party loop runs it.

---

## 4. New upgrades

The owner wants new upgrade cards. Points to settle first:

- Cards were deliberately cut ~20% in PR #342 because **pets and weapons carry a player's
  power**. New cards hold that line — they are not a place to add power back.
- `Config/Abilities` is data feeding an ordered pipeline; a card is never an `if` branch in the
  shooting code.
- ~~Diagonal Arrows has no magnitude knob~~ — **wrong, and already fixed.** Codex's combat
  pass passes `CombatTuning.extraProjectileDamage` (0.4) into `Stages.mirror`, so the diagonal
  copies do 40% each: level 2 is 1 forward plus 4 at 40%, about 2.6x, not 5x. Checked
  2026-10-31.
- `upgrade_cards.md` is sitting in the unclaimed sweep bucket. Find out what it is before
  writing new cards.

---

## 5. Smaller things already queued

- **Back-to-lobby buttons** — mid-run and on Victory/Defeat. None exists: no pause or menu
  control in the HUD at all, and one button on each end screen. Needs a HUD control, a confirm
  step, a server remote, and a second button on both end screens.
- **Phone emulation for PR #399** — four of five bugs fixed; the blue line never reproduced.
  Needs the owner to turn on phone emulation in portrait.
- **The within-level difficulty curve** — `docs/DIFFICULTY.md`, fully specified. Needs
  `Balance.luau`, `Waves.luau` and `EnemyManager.luau`, so it waits for Endless to land.
- **Endless reward models** — Astral Arc and Orbit Manta sheets are in the repo. Their rarity is
  unsettled: the sheets glow pink, but a Mythic's glow has to be a rainbow.
- **The PR backlog** — 24 open PRs, some back to #208. Worth a triage pass to close what is dead.

---

## 6. Added 2026-10-29

### Ember Wilf goes, as an enemy only

Owner: *"ember wilf needs to go completely as an enemy."*

**The pet stays.** They are two different things with two different keys, so the removal has to
be surgical:

- **Remove** — the enemy. `Config/Balance` (the archetype, `displayName = "Wilf"`),
  `Config/EnemyDesigns`, `Config/EnemyRigs`, `Fx/EnemyRig`, its entry in `UI/SandboxMenu`, and
  every roster that fights it: check each stage's `fights`, `elite` and `finale` in
  `Balance.Stages`, and `Balance.Rooms`. A roster referencing a deleted archetype is a crash,
  not a lint error, so the roster sweep is the part that actually matters.
- **Keep** — `EmberWilfPet`: `Config/Pets` (Legendary, Mossy Egg), `PetModels/EmberWilfPet`,
  `ModelClips/EmberWilfPet`, `PetAttacks`, `PetAuras`, `PetCombat`, `PetSounds`,
  `HatchUiAssets`, `GearAssets`.

Shared between them: `Config/Sounds` and `tests/RigClip.spec` mention both — take only the
enemy's lines. Confirm with the owner whether the enemy's **sounds and mesh uploads** should go
too, or stay in case it returns.

### Endless needs reworking

Owner: *"endless needs to be reworked."* **No detail given yet — get specifics before touching
anything.**

This collides with the plan above, and the collision is worth deciding early. Step 0.6 is
"land Endless v6, close #398". If the mode is being reworked, landing it as built may be
wasted work. Three ways to go:

1. **Land it, then rework on top.** Keeps the merge order intact and unblocks everything else,
   since Endless is last in the stack anyway and holds schema v6. The rework becomes a normal
   follow-up PR. **Recommended** unless the rework is fundamental.
2. **Rework first, then land.** Only worth it if the save schema itself changes — `endlessBest`,
   `endlessMilestones`, `soulstones` — because reworking those after they ship means another
   migration.
3. **Drop it from the stack.** Costs the most: everything below it still has to land, and
   Endless would need re-cutting against whatever `main` becomes.

What to ask the owner: is it the **curve** (floor scaling, where the wall lands), the
**structure** (floor kinds, the draft cadence, checkpoints), the **rewards** (Soulstones, the
milestone table, bank-or-push), the **areas** (the rotation and its modifiers), or the whole
shape of the mode? `docs/ENDLESS.md` holds what was agreed, so the fastest route is walking
that doc and marking what changes.

---

## Suggested order

1. Land the stack (0), with the Codex audit as part of it.
2. One model end to end through Tripo (1).
3. Drowned Village content (2) and co-op (3) in parallel — different files, no overlap.
4. New upgrades (4) and the queued small things (5) as they fit.
