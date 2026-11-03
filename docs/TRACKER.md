# Tracker: what is in flight

Everything started and not finished, and who it waits on. Claude updates
this in the same PR as the work it describes (CLAUDE.md): add a row when
something starts or gets blocked, strike it when it lands. How each kind of
thing gets made is in [PIPELINES.md](PIPELINES.md).

Last brought up to date: 2026-11-03.

**Scope:** Acts 1-3 only (areas 1-6) until the owner says otherwise (2026-10-24). Acts 4-5 work is on hold.

**Pruned 2026-11-03** (owner: "prune the tracker"). "Waiting on the owner" had
grown to 64 full rows since 2026-10-25, and only 4 of them had ever been
struck. Sixteen were dead -- the work had landed, or a later row had overtaken
them -- and are gone. The rest were almost all the same sentence said forty
times: *built, never looked at.* Those are one line each now, under "a look in
the game", grouped by where you would be standing to see them, so one play
session can clear most of the list. Only the rows that actually **block work**
keep their full detail. Every pruned row is in git at `d0c9af8`, the commit
before this one.


## Waiting on the owner - a decision

Nothing moves on these until you answer, so they keep their full detail.

| What | What the owner does | Then Claude | Where it is |
|---|---|---|---|
| Forty new upgrade card ideas, ten a class (owner, 2026-11-03: "we need to make cooler upgrades so players stay more engaged ... i also want 10 new upgrade ideas for each class") | **Read [docs/CARD-IDEAS.md](CARD-IDEAS.md) and say which of the forty you want built.** Four questions at its end: which cards, whether any of wave 2's eight unbuilt ones go in with them (Sunder, Frost Orb and Gravity Well are nearly free now), whether the **Assassin** is on the table at all this phase â the class has no combat system, so its ten cards mean building the class first â and whether to make the icons. **Every card needs one Codex icon** and none of the forty has art; Codex was out of usage when they were written | Build the ones picked: a row in `Config/Abilities`, its effect in `Combat/AbilityEffects` or `Combat/ClassUpgrades`, art in `Config/CardAssets`, and its tests. The doc says per card what machinery it reuses and what is new, and names seven pieces wanted by more than one card, so picking cards that share a piece makes the second nearly free | Designed, not built. Forty cards: ten Ranger, ten Arcanist, ten Warden, ten Assassin. Written against `docs/RESEARCH-archero.md` and the balance report's finding that nineteen of the 42 live cards are a flat percentage â twelve of the forty do no direct damage at all. **Wave 2's eight stay unbuilt and are not re-proposed** (Sunder, Echo Slash, Riposte, Frost Orb, Arcane Shield, Split Orb, Gravity Well, Orbiting Orb): `docs/CLASS-CARDS.md` says their icons are uploaded and that is wrong â `Config/CardAssets` has none of them and neither does `assets/ui/glow_toy_cards/icons/`, so they are blocked on Codex too |
| The Egg Hatchery and the Blacksmith, rebuilt from their sheets (CLAUDE.md 13: "if it does not match 1 to 1 then redo it") | Walk up to both in the lobby and say whether each reads as its panel of `assets/concepts/blocky/lobby/ref_main.png`. **Neither has been seen lit in Studio** -- the MCP `screen_capture` timed out on every call this session, nine tries across Edit and Play, so both were judged from their built geometry drawn flat (`tools/lobby_views.py`), which has no Roblox lighting in it. Three things to judge: whether the hatchery's stone deck sits high enough that you see the eggs under it from the lobby's own camera angle, whether the forge fire reads from across the lawn or only from in front of it, and whether both nameboards want to be the sheets' dark boards rather than the light brown every lobby station shares | Retune `Config/HatcheryDesign` and `Config/BlacksmithDesign`, where every measurement is written down against the reading it came from; the boards are one change to `signboard` in `Run/Lobby`, which would move every station's at once | Built: both are their own builders in `Run/Lobby`, neither a cottage any more. The hatchery is an open pavilion 30 x 14 on 21-stud posts under a flat stone deck, with three eggs in gold collars in a 28-wide stone nest ring that spills out past the front. The blacksmith is a 32 x 22 stone forge open to the front, its hearth cut into the wall under a chimney standing behind it, with two anvils, a sword rack, a workbench and a banner at each end. 715 tests pass in Play, 9 of them new |
| The blocky tree is ready to import (owner, 2026-11-01: "ok now i need an importable file of this") | **Import `assets/models/lobby/imports/blocky_tree/blocky_tree.glb`** in Studio with the 3D Importer, Merge Meshes off, and say where the tree should go -- lobby lawn, an arena, or both. Send back its mesh and texture ids | Wire the ids into whatever uses it; for arena trees that is the `split_trees.py` route in `docs/PIPELINES.md`, for the lobby a piece in `Config/Lobby` | Done: the handoff was an FBX with its texture loose in a `.fbm` folder, which Studio imports untextured. Converted in Blender to one GLB carrying its own texture. Three fixes: the texture was 8192 square, eight times Roblox's ceiling, now 1024 and packed in; the height ran along Y so it would have imported lying down, now upright with Y up; and it was one unit tall, now 4.6 with its feet on the origin, which sits with `Lobby_LobbyTree` at 4.98. 2,469 tris, one primitive, one material -- one MeshPart, 135 KB. Keeps its UVs, so it can be re-textured later |
| Drowned Village enemies, the arena, and the pets' attacks (owner, 2026-11-01: "the enemies", then "we also need the enemy and pet attacks to be created. and the arena") | **Three things, all of which need you first.** (1) **The arena**: nothing exists for it but the concept sheet `assets/concepts/blocky/arenas/area03_drowned_village.jpg` -- no GLB, no kit, no imports. Make the Drowned Village arena in Claude Design (or Tripo) and send it, as the Mossy Glade and Thornwood kits were. Without it the area has no rooms, so no enemy can stand anywhere. (2) **Three enemy models**: the Drowned Zombie, Ditch Eel and Bell Ringer. All three already have their NEW ENEMY! cards written and their pictures uploaded (`Config/NewEnemies`); only the models are missing. (3) **Spawn the Hollow Fisherman** (`Remotes.DebugSpawnEnemy:FireServer("HollowFisherman")`) and say whether it faces you -- its turn is **unconfirmed**, set to -Z to match the Tripo pets -- and whether the hook reads: one slow cast down a drawn line, and a catch that drags you 6 studs back toward it | Build the arena kit, its rooms and stages from the import (`docs/PIPELINES.md` §4), then the three enemies; flip one field if the fisherman faces the wrong way, and retune its numbers. The **pet attacks** are five new server behaviours and their own piece of work: Roof Huddle (a 20% damage cut while it tucks in), Payback Puff (a retaliation on the owner being hit), Ink Blink (an accuracy blind), Wake Chase (hits as a marked enemy moves) and Deep Accord (damage split across linked enemies), all specified in `docs/PETS-DROWNED.md` | Built: the **Hollow Fisherman** whole -- its `EnemyDesigns` body from the Tripo import, its archetype in the new `Balance.Benched`, and its hook, which is `EnemyShot.reel`: a locked, drawn line whose hit drags the player back along it (`Combat/ProjectileSystem`, `EnemyManager.shovePlayer`), so a client walks the pull and cover stops it. It is in no roster because the area has no rooms; `DebugSpawnEnemy` reaches it. Measured in Studio: the body builds as a real textured MeshPart, 0.001 studs inside its hitbox across, flush on the floor. 640 tests pass. **The reel is not yet felt in a playtest** |
| Drowned Village pets: five imported, the egg still shut (owner, 2026-11-01: "The pets") | Generate and import the three the egg is short of -- two of the Commons (**Dock Otter**, **Reed Duck**, **Foam Pup**) and the **Toll Prince**, the baby Tollcrab that shares the Legendary slot with the Tide Wilf -- and make the egg's hatch art (whole, crack1, crack2, burst) for `Config/GearAssets.eggs`. Also say whether these five read at their imported size (about one stud, same as the Glimmerhorn) beside the blocky pets, which they are not: they are single Tripo meshes. Say too whether their icons pass: they are **rendered from the models**, not drawn like the other twenty-four, because these five came with no art (assets/concepts/pets/drowned/README.md) | Add the Drowned Village Egg to `Config/Eggs` at 2,000 coins (its crate's price, as the other two eggs match theirs), put `egg = "DrownedEgg"` on the eight, swap any icon the owner wants drawn instead, and give the five `Config/PetCombat` specs, `Config/PetAttacks` pieces and `Config/PetSounds` cues from docs/PETS-DROWNED.md -- Roof Huddle, Payback Puff, Ink Blink, Wake Chase and Deep Accord are all new server behaviours, so each is its own piece of work | Built: `Config/PetModels` for the **Slate Turtle**, **Buoy Puffer**, **Inkpot**, **Tide Wilf** and **Abyss Jelly**, their `Config/Pets` rows (benched, no egg), and `Config/PetAuras` for the Tide Wilf (gold) and the Abyss Jelly (rainbow). `docs/PETS-DROWNED.md` restored -- it was written in 449ef79 and lost in the squash of #402, which kept only `WEAPONS-DROWNED.md`. All five checked in Studio facing -Z, so none is turned |
| Four Thornwood pets are built but not hatchable (found 2026-10-31 by the in-Roblox suite) | Each egg holds 8 pets at fixed rarities (owner, 2026-10-31: "the eggs from now on will only have 8 pets each"), so one Uncommon, one Rare and two Commons were benched. Thornwood's benched four are now the **Budbulb**, the **Berry Mouse**, the **Berry Bat** and the **Briar Lynx** — all four have full combat specs and attacks nobody can reach. The Thistle Mole and the Berry Bat were reworked on 2026-10-31 at the owner's own request. Decide: is Thornwood's Uncommon the **Thistle Mole** (a guard, like the Mossy Egg's Snail) or the **Berry Mouse** (a healer, as now)? Same question for its Rare: Briar Beetle or Berry Bat | Swap the `egg` field in `Config/Pets` either way; the specs, attacks and blurbs already exist for all twelve | **Uncommon answered** (owner, 2026-10-31): Thornwood's is the **Thistle Mole**, the guard, so each egg holds one guard and Thorn Shell is reachable. The **Berry Mouse** is benched in its place, which leaves **neither egg with a healer** (the Toadstool Tot is benched too) — raise that when a third egg or a ninth slot is on the table. **Settled** (owner, 2026-10-31): the **Berry Bat** moved from Rare to Common and took the **Burrball**'s slot, so the egg's eight are the Bark Hoglet, Berry Bat, Thistle Mole, Briar Beetle, Bramble Bear, Bramble Wilf, Thorn Princess and Thornwake. Benched: Budbulb, Burrball, Berry Mouse, Briar Lynx. Five of the six reworks are now reachable. Nothing in the game heals on a patch any more — raise it when a third egg or a ninth slot is on the table |
| King Bloblin's health thirds and two of him in Endless (owner, 2026-10-28) | Fight him at Mossy Glade 1-10 and say whether the thirds read: the bar in three parts, and two Brood Slimes dropping as he crosses 2/3 and 1/3 (1.5 s of `Attack` wind-up first). **Two calls to make:** (1) a single blow that crosses both thirds at once owes **both** clutches, so four slimes land together — say if it should be two; (2) Endless fights two kings on floors 30, 50, 70 and deeper and one on floor 10 — say if it should be two from floor 10 on. Also: this puts him in the game outside 1-10, which CLAUDE.md still calls "his only appearance" — confirm that line should read "his only appearance in the story" | Flip either call (one line each: the clamp in `EnemyManager.bankThresholds`, and `Balance.Endless.areas[1].bossByLap` from `{ 1, 2 }` to `{ 2 }`); retune the clutch (`BossSummon.count`, `atFractions`, `windup`) and narrow the CLAUDE.md line | Built (`Util/BossThresholds`, `Balance` `slimeKing.boss.summon` / `EndlessArea.bossByLap`, `Enemies/EnemyManager`, `Run/Waves.floorBossCount`, `UI/BossBar` segmented and one bar per boss, `tests/BossThresholds.spec`, `tests/Endless.spec`). Gates pass and the threshold arithmetic was run outside Roblox. **Not yet seen in Studio** (it was synced to another session's branch and mid-playtest): the in-Roblox suite, 1-10's segmented bar and both clutches, and Endless floors 10 and 30 side by side |
| Performance pass: the options left (`docs/PERFORMANCE.md`) | Say which, if any: (1) merge the clip-driven enemies', bosses' and pets' parts per joint (1,819 parts to 621, needs every one re-imported); (2) merge the outer forest into a few chunks (100 of a room's ~190 draws) instead of per-tree sway; (3) shadows off on the Low tier (visible); (4) move `ServerStorage.Imports` out of the place (about 100 import models the game never reads) | Build the chosen ones and list every re-import | Done without any re-import: clip-driven models pose 1.9x faster, pickups and the target ring cheaper (#320); shots, slime hops and the Web Walker's tiles written only when they change or in one batch. Still to do: `Fx/ForestAmbience` and the Thornwood outer forest once that session merges |
| The Drowned Village's fourteen weapon pictures, and the Abyss Jelly's sting (owner, 2026-11-02: "do the weapons and the mythic jellyfish attacks") | Two things. **The pictures:** all fourteen are cut, uploaded and wired into `Config/ShopAssets`, and **none has been seen in game** -- `screen_capture` timed out on every call again, and the area is unstocked so the shop will not draw them anyway. Open the gear screen or a Drowned crate yourself and say whether they read beside the glade's. **The jelly:** take it into a run (O, sandbox, pick it) and say whether a flurry every 16 seconds reads as a Mythic, or whether it wants a faster, smaller sting | Recut from the sheets in `assets/concepts/blocky/weapons/skins/drowned/` and re-upload if an angle is wrong; retune `Config/PetCombat`'s `AbyssJelly` block, where the arithmetic against area 3's Mythic band is written down | Built: the fourteen sheets recovered from `phase-3/gear-and-shops` (bfe0227), which never merged and is the whole reason they had no art; cut by the same `assets/ui/shop/three_quarter.py` as every other weapon, to the same angle. The Abyss Jelly now hits the three its canopy joins with three stings of 125 each, 70.3 damage a second against a room against area 3's Mythic band of 70, and the canopy is untouched. 717 tests pass in Play, 2 of them new. **Still to do:** the fourteen mini pixel icons for the gear screen -- Codex ran out of usage (resets 2026-11-03), and the three prompts are written and ready at `assets/concepts/blocky/ui/pixel/drowned_*.prompt.txt` |

## Waiting on the owner - a look in the game

Each of these is **built and passing its tests, and nobody has looked at it**.
Nothing is blocked on them; they are a checklist of things to judge, grouped by
where you would be standing. Say what reads wrong and Claude retunes it.

### In the lobby

- **The circuit.** Four buildings on four corners, each turned to face you from the fountain; is the walk the right length (the Blacksmith, furthest, is 105 studs)?
- **The Mossy Glade arch.** Does it face you the right way round, and does its swirl sit in its opening? Never seen - Studio's capture stopped answering.
- **The trees.** Different enough heights, and enough of them? Do the seven black arches read as locked?
- **The Dex Hall.** Porch columns flush to the grass on stone with no timber cutting through them, no daylight at the roof/wall join, chimneys gone.
- **The dexes.** Press E: the page should curl the other way coming back, and the book must not shift. All three tabs, nine slots a spread.
- **The hatchery and crate screens.** Four cards across for an egg's eight pets, three for a crate's six weapons, full rarity colour, the chance in the corner, an unowned Mythic a black silhouette.
- **The shop.** Open a Mossy Glade crate, buy from the store, equip from MY WEAPONS (`Remotes.DebugWallet:FireServer(5000, 2000, 5)` fills the wallet).
- **The Gear Station** stands clear of the Blacksmith; the portal screen reads; Shift sprints and Space jumps instead of the old dash.
- **The leaderboards** are behind you as you spawn, side by side and readable, with the walk north clear of them.

### In a Mossy Glade run

- **The level grid.** 2 x 5, locked dimmed under a lock, CLEARED in gold. After beating 1-1, rejoining should go straight to the lobby.
- **1-6 and 1-10 as rooms** rather than waves. This took about sixteen guaranteed card offers out of 1-6..1-10 - does the late glade feel starved of upgrades?
- **1-8, 1-9 and 1-10: still long?** Enemy health now rises 0.04 a level instead of 0.1, so 1-10 asks 87,074 health instead of 119,280.
- **The Angel** (1-1 room 9 is the first). Does the cream hold up under the glade's light, is it the right size next to you, is the bob too much? Should the halo be part of the mesh?
- **The pet ladder.** Hatch down the Mossy Egg: Common 16 damage a second against a room, Rare 24, Epic 34, Legendary 44, Glimmerhorn 56. Does the climb read?
- **Stumpy's hold** (roots the nearest enemy every 4 s for 1.75 s, bosses excepted) and the **Glade Fox's dash** (crouch, run to three in turn round the cover, slash each, run back).
- **Pet projectiles.** The Hootmoss's feathers and the Babacorn's pellets should land their damage numbers on arrival, not on firing.
- **Your own arrows, on a long stand.** Stand completely still and shoot one enemy for ten seconds or more: the damage number and white flash should land on the same beat as the arrow arriving. The firing rhythm used to drift out of step with the client's prediction the longer you stood there (59 studs over 30 s), so a few shots always looked fine and a long stand did not (`docs/FIXES.md`, shipped unplaytested at the owner's word). Say too whether the damage number wants moving from the enemy's origin to the contact point, 2.8-3.1 studs away.
- **The seven class upgrades** - Phoenix Arrow, Rain of Arrows, Black Hole, Elemental Orbs, Arcane Turret, Titan's Grip, Counter Strike. Are the effects big enough? They also want sounds picked: seven hooks, one sprite, one audio upload.
- **The twenty kept upgrade cards.** Which read wrong? `Remotes.DebugGrant:FireServer("HeavyBlade")` grants one.
- **Combat feel.** A heart's green "+N" on the health bar; weapons 20% bigger in hand on every class; the XP bar rising as crystals reach you; the first shot after a card pick coming with its draw and release.
- **Movement.** 1.5x walking speed once a cleared room's gate opens, and a 6-stud dash, up from 4.
- **A sword's swing.** Does the red reach in far enough, now that it starts at the player?
- **Doors and first card hands** should feel instant, on a phone too.
- **NEW ENEMY! cards.** Does one drop in and settle, hold the run, and sweep away on GOT IT!? Are the names and descriptions right?
- **The outer forest.** Calm enough past the walls now, or still too loud - or gone too dull?

### In a Thornwood run

- **Every hit.** A short solid white flash and a visible shove back, even mid-charge, on every non-boss enemy.
- **The Bramble Sow's drop.** Her brambles burst, she rears and falls, and each Boarlet somersaults out curled up and lands on its feet. Should she drop 2 while alive rather than 3 on death?
- **The Bramble Hedge v2** against its sheet (`kit/thornwood_bramble_hedge_v2_views.png`).
- **The Broodmother's Web Walker** in room 40: she opens with the web shot and runs at you between moves; for the spin she walks to the middle and you walk the edge.
- **The outer wood** against `area02_thornwood_ambience.jpg`: thorn trees, bramble banks, bone spikes, snags with crows, magenta pollen.
- **Thornwood's pet attacks.** The effects are Mossy Glade pieces standing in - which look wrong enough to need Thornwood art of their own?

### The Drowned Village

- **Its five pets' attacks** (O, sandbox). Three do no damage at all, which is the thing to judge: the Slate Turtle's 20% cut for 3 s in 14, the Buoy Puffer's 240 only once you are hurt, the Inkpot's 3 s blind, the Tide Wilf's 138 a 3 studs. None of the five plays an animation - do they need rigged models, or is a pose and an effect piece enough?

### The opening and the screens

- **The intro.** Black, DYL.DEVS in dark gold with PRESENTS under it, the cut to the title at 5.0 s, then BEGIN ADVENTURE.
- **The story** after BEGIN ADVENTURE, about 43 s, SKIP at the top right, ending in the tutorial.
- **The tutorial.** Five glade rooms of Moss Slimes and Spitters: does it teach well, at the right difficulty?
- **The class-select cover.** The 1.8 s wait should be a spotlight with a tip and a bar, never the old green backdrop with a weapon panel.
- **The end screens.** Press V and B in a playtest and hold them against `end_victory_chest.jpg` and `end_defeat.jpg`.
- **The in-run MENU button.** It sits on the left edge at mid-height, which is where a floating thumbstick is most often grabbed - is it under your thumb on a phone?
- **Endless.** Beat 1-10 and walk into the Endless arch: a draft every 3rd floor, a mini-boss every 5th, a boss every 10th, the area changing every 10. Health x1.045 a floor, damage x1.030.

### The big one

- **A run-through with every class, weapon and pet, on both maps.** 1-1..1-10 once with each class (C switches class, O opens the sandbox), then Thornwood. This is the row that would answer most of the others at once, and the Phase 3 question behind it: *did two runs in a row feel meaningfully different?*

## Open PRs

| PR | What | Waiting on |
|---|---|---|
| #449 | The Egg Hatchery and the Blacksmith are the Dex Hall, recoloured | The owner's eye in the lobby; a Codex redraw when its usage resets |

Checked against GitHub 2026-11-03: #449 is the only PR open. The two that sat
here before it, #173 and #174, were closed long ago.

## Planned by the owner (not to build yet)

The owner's plans, noted 2026-10-25 so they aren't forgotten: "dont implement these changes now just keep notes of them so i dont forget when i want to build all of these". Build one only when the owner says to.

**Checked against the code 2026-11-03: all but three of these are built.** The
list had not been struck since it was written, which is most of why it reads as
a backlog. What is genuinely not built is the last three.

- **Lobby** in the same top-down style as the gameplay - **not built** (its music is ready: `Config/Music` Lobby, Mossy Glade take B).
- ~~**Eggs for pet hatching**~~ - built: `Config/Eggs`, two eggs of eight pets, rolled on the server.
- ~~**2D animated intro cutscene** when the player opens the game~~ — built 2026-10-25 (owner asked): see the intro row above. Its own sounds beyond the music are not made.
- ~~**Story cutscene** after BEGIN ADVENTURE~~ — built 2026-10-25 (owner asked): see the story row above.
- ~~**Tutorial** after the story cutscene~~ — built 2026-10-25 (owner's design): see the tutorial row above.
- **Character creation screen** right after that cutscene - **not built** as such; `UI/ClassScreen` picks a class and a look, which may be as far as this needs to go.
- **Egg breeder** for the eggs - **not built**, and nothing in the game points at it.
- ~~**Blacksmith** for the weapons~~ - built, and rebuilt twice since.
- ~~**Gear selection area**~~ - built: the Gear Station and `UI/GearScreen`.
- ~~**Weapon crates and a weapon store**~~ - built: `Config/Shop`, crates by area and a store by rarity. Area 1 is the only area stocked; what each later area still needs is in `Config/Shop`'s `stocked` comment.
- ~~**Dexes** for every weapon, pet and enemy, unowned as black silhouettes~~ - built: the Dex Hall and `UI/DexScreen`, three books. Waiting on the owner's eye, above.

## Designed, not built

- The other bosses of Acts 1–3 (`docs/BOSSES.md`; the Slime King is built). Acts 4–5's are on hold.
- Thornwood's rest (Level 2 is built, 2026-10-25: forty generated rooms (`tools/thornwood_rooms.py`), the four enemies on their own models and clips, the Broodmother on Web Walker and the Slime King's pull, with her own clips): the Thistle's burr (it fires the Spitter's seed), thorn trees mid-wall. Level 2 is `Balance.Stages[4]`, and runs open on it (2026-10-25).
- Wave 2 of the Warden's and the Arcanist's cards (`docs/CLASS-CARDS.md`; icons made).
- The Wilf pets of areas 4-6 (`docs/PETS-WILFS.md`): design only. Areas 1-3's pets, eggs and weapon skins are all built and in the game.

## Known rough edges

- The blocky Mossy Glade has no blocky forest or boulder yet: the trees past the walls are still the round models, and boulders are drawn as mossy stone pillars, whose moss tops read as lawn from above. A blocky tree and boulder in the kit would fix both.

- Enemy overlap with cover is measured clean in rooms 1–4 only; rooms 5–10 and the arena art itself are unmeasured (CLAUDE.md, "Known rough edges").
- A Wilf lunge stopped short by cover still plays its leap for the full time.
- The Slime King's moves have no sounds yet.
- The Meteor cast (1.6 s) hides the staff's cast animation while it plays; shorten it if it feels long.
- Slime residue (`Fx/SlimeResidue`, `Balance.SlimeResidue`) lands on the floor plane, y = 0: a cube thrown over a log, a boulder or the pond sinks into it instead of resting on top. Its colours are taken from the blocky models' vertex colours; the owner may want them tuned.

## Offered, not asked for

- Jelly splats where the Slime King slams.
