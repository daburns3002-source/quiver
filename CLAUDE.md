# Arrow Legends — builder rulebook

**Archero's combat inside a Pet Simulator / Steal an Egg progression shell.**
Low poly, cross-platform, co-op-shaped.

**Scope: Acts 1–3 only** (owner, 2026-10-24: "we are only going to deal with
acts 1-3 until i say so from now on"). Areas 1–6 — Mossy Glade, Thornwood,
Drowned Village, Bogheart Caverns, Windswept Cliffs, Frostpeak Pass — and
nothing for Acts 4–5 (enemies, bosses, arenas, pets, art) until the owner
lifts it. Their designs stay on file, untouched.

**There are no wolves in this game, only Wilfs** (owner, 2026-10-23): every
wolf is named "Wilf" — the Ember Wilf, plural Wilfs — in names, code, docs
and files. Every area gets a Wilf pet.

Run loop: `docs/RESEARCH-archero.md`. Meta loop: `docs/PROGRESSION.md`.
Phase plan: `docs/ROADMAP.md`. Lobby spec: `docs/LOBBY.md`.
**Classes and world: `docs/WORLD.md`** — since 2026-10-22 the game is three
classes (Ranger, Arcanist, an unlockable melee class) across ten areas
in five acts. A new title is being chosen; until then it stays "Arrow
Legends". Nothing of it is built yet, and its open decisions are the
owner's. Enemy and arena ideas per area: `docs/ENEMIES-AND-ARENAS.md`, with
concept art in `assets/concepts/`. **Images and models are made with
ChatGPT Codex** (owner's rule): `codex exec` with its image generation,
signed in with the owner's ChatGPT account.

**Enemy models, the pipeline** (the Moss Slime as the Charger, the Splitter
Spitter as the Spitter, the Brood Slime as its own elite, which splits into
four Baby Slimes on death — `EnemyConfig.split`, drawn by `Fx/SplitFx`):
GLB from Claude Design → `assets/models/enemies/optimise_enemy.py <in>
<out> <enemy>` (slims to a few thousand triangles, keeps vertex colours or
samples textures onto vertices, cuts eye sockets, turns it to face −Z, splits
Body / Eyes / Decor) → the owner imports it in Studio (File → Import 3D;
uploading a mesh is not something we can do over MCP) → the mesh ids go
into `EnemyDesigns` as `shape = "Mesh"` parts, built by `EnemyModel` from
templates made once in `EnemyModel.preload()`. The importer turns models
to face +Z, so designs rotate them 180°. Roblox shows vertex colours, so
mesh parts are white; eyes are Neon in the act's colour. Each archetype's
hitbox fits its model (the slime's is 3 × 2.2 × 3), so player arrows fly
low, at `Balance.Projectile.height` (1.1), from `Aim.shotOrigin` on both
sides; `Balance.spec` keeps that height inside every enemy's hitbox.
The slimes hop (`Fx/SlimeHop`, `Balance.SlimeHop`, owner's
design_handoff_slime_movement): client-only, phased by the distance the
hitbox travels, folding in `HitSquash` (which a hopping body is claimed
from). The Slime King's lash is the design's Zac-Q motion: a twist, a
12-segment jelly tube (`BossBody`), a splat and goo droplets (`Goo` tell).
**Rigged enemies** (the Ember Wilf, 2026-10-23): a skinned mesh imported
with its rig; its bones and clips are data in `Config/EnemyRigs`, generated
by `assets/models/enemies/ember_wilf/rig_to_luau.py` from `rig.json` (bones
dumped from Studio) and the kit's `.rbxmx`. `EnemyModel` builds the bones;
`Fx/EnemyRig` runs it at the hitbox's pace, fits the Dash to each lunge
(`LungeWindup`, `LungeTravel`, `WindingUp`), squashes bones with the body
and carries the eyes on the head bone.
**Claude Design models' own clips** (pets, enemies, 2026-10-23): their GLBs
animate joint nodes, with no skin, so Roblox's importer drops the clips.
`tools/glb_clips_to_luau.py` turns the GLBs in `assets/models/model_clips.json`
into `Config/ModelClips/<Name>`; a model tagged `ModelClips` (attribute of
the same name = the data's name, `ModelClip` = the clip) is played by
`Fx/ModelAnimator`, which reads the import's scale and turn from its parts
(`Shared/Util/ModelClip`, pinned by `tests/ModelClip.spec`). PIPELINES.md §10.

**The game opens on the intro cutscene** (`UI/IntroCutscene`, `Config/Intro`,
owner 2026-10-25, after Pixel Lineage's): black, DYL.DEVS in dark gold with
PRESENTS small and white under it, a cut on the music's hit at 5.0 s (`revealAt`,
the shared contract with the intro music, `Config/Music.intro`) to the Codex title
picture (logo painted in; a portrait one on upright screens, phones; both 2x tiles, `Intro.pictures`), which never moves once up (owner) and shows whole at
the screen's height with dimmed copies filling the sides, and BEGIN ADVENTURE,
still until hovered or pressed. BEGIN ADVENTURE plays **the story cutscene**
(`UI/StoryCutscene`, `Config/Story`, `Util/StoryTimeline`, owner 2026-10-25): **one
frame at a time** (owner: "stop changing the frames and adding effects"), 40
Codex frames from the owner's approved storyboard (`assets/concepts/blocky/ui/story/`),
each shown once, whole and still, with straight cuts: King Bloblin asleep in the
glade with his over-the-top slimy chest, a Slime Soldier brings a WANTED poster
(WANTED: his icon, REWARD: the chest icon, the three class icons signed), he
roars, the heroes (never in a frame with the king) run into the forest, black.
Its calm music (`Config/Music.story`, `assets/audio/music/story_theme.py`) is
scored to the frames' holds, the king's yawn mixed in: change a hold and
re-render and re-upload it. SKIP >> cuts to black. It ends in **the tutorial**
(`Config/Tutorial`, owner 2026-10-25): `Balance.Stages[Balance.tutorialStage]`, five
Mossy Glade rooms (81-85, kept apart from the generated rooms) of Moss Slimes and
Sprout Spitters only, played as a Ranger, won into the lobby. Its upgrades are
fixed, the same for everyone (`Util/TutorialHands`, `tests/Tutorial.spec`): a
Common, an Uncommon and a Rare first; on room 3's level-up Multishot (Legendary)
in the middle; Legendaries and Mythics banned from its pool (`Loadout.State.banned`,
which a fixed hand ignores), no rerolls. The rooms' XP lands the level-ups in rooms
1-3, and room 3 is granted the XP it owes if not. `UI/TutorialPrompts` says how to
move (per device) until the player has, that standing still shoots at the next
fight, and how levelling up works over the first hand.
The run holds still until the story's black has held: the server skips
its step while any player is still on the title (`RunSession.anyAtTitle`,
cleared by `Remotes.IntroBegin`, fired at the story's end), the client holds on
`RunPaused.setTitle` then `setStory`, the room's music and its ROOM sign wait. **In Studio, set a `SkipIntro` attribute
on Workspace in Edit before Play** to skip it on both sides, for probes that
need the run going, into the lobby (firing `Remotes.IntroBegin` from a probe now
starts the tutorial, as the story's end does).

**The game is Mossy Glade, then Thornwood** (`Balance.campaign = { 5, 4 }`,
owner 2026-10-25): after the intro, **the Mossy Glade run** (stage 5, the first
run, `Balance.stage`): twenty glade rooms generated by `tools/glade_rooms.py`
in Archero 2's layout style from the glade's kit, ending in King Bloblin alone
in Level 1's boss room (rooms 61-80; `RoomPaths.spec`). NEXT LEVEL on its
Victory resets the upgrades and starts **Level 2, Thornwood** (stage 4):
twenty rooms, the first nineteen `tools/thornwood_rooms.py` wrote and the
Broodmother alone in the Brood Heart (rooms 21-39, 60). After the last stage,
NEXT LEVEL plays it again; TRY AGAIN replays the stage lost. The server keeps
the current stage (`RoomController`) and publishes it as Workspace's `Stage`
attribute; read it through `Util/CurrentStage`, never `Balance.stage`
(`tests/Campaign.spec`). In Studio, `Sandbox.startRoom` starts any stage at a
later room.

**Level 1** (`Balance.stage = 3`, owner 2026-10-22): ten Mossy Glade
rooms — logs, pond, boulders, thorns, boss arena, twice. **Slimes**
(Moss Slimes and Brood Slimes), the **Ember Wilf** from room 6 (lunges:
a long charge warned by its eyes flashing red, a quick dash up close; `EnemyConfig.lunges`),
and room 10 is the **Slime King alone** (`tests/Level1.spec.luau` pins all
three; owner, 2026-10-23). Each room names
its look in `RoomConfig.arena`, an `ArenaModels` entry drawn by `Arena.build`
over the same invisible floor, walls and obstacle boxes as the grey box
(nil, or a model not imported yet, is the grey box). Since 2026-10-24 the
glade arenas are **built from the owner's blocky kit** (`Config/ArenaKits`,
`Shared/Util/KitLayout`): walls, corner pillars, a log, stumps or stone
pillars on each room's own cover boxes, water or fern thickets for flat
cover, a stepping-stone path and plants, laid out per room. Arena models follow the
enemy pipeline through `assets/models/arenas/optimise_arena.py`, scaled ×2.7
into the 35 × 58 room. Cover under `Projectile.height` (pond, thorns) blocks
walking but not arrows. Every piece of cover has a full-height invisible
`PlayerWall` over it that only the player meets, so nobody walks over a log
or across the pond. Past the walls the forest lives
(`Fx/ForestAmbience`, `Balance.Ambience`, the owner's forest ambience
handoff): leaves, fireflies, mist, butterflies, birds and light shafts, on
top of the canopy because the camera looks down onto it, never inside the
room (`AmbienceVolumes.spec`). Per-tree sway waits on the trees being split
out of their merged mesh. Each area has its own outer forest: the glade's
(`Config/GladeForest`) and **Thornwood's wood** (`Config/ThornwoodForest`,
2026-10-25: the room's thorn trees, bramble banks, bone spikes, dead snags
with crows; crows and magenta pollen in `Balance.Ambience.Thornwood`), made
as `docs/PIPELINES.md` §4.5 says. Thornwood keeps its colours as the
importer stores them, darker than the design (the owner's pick over the
`srgb_glb.py`-converted import, 2026-10-25). Both are toned down so the fight reads first (owner, 2026-10-26: "a little less
distracting"): `ArenaModels.outerShade` / `outerGlow` darken the forest and its glow, never the
kit's room, and `Balance.Ambience` keeps its life sparse. As each room starts, a blocky ROOM <n> sign flies out of the top of the gate, hangs at the top of the screen and flies back (`UI/RoomSign`, `Config/RoomSign`, letters from `Config/PixelFont`; the last room's number is red). The exit is a gate in the north wall
(`Arena/ExitGate`, `Balance.Run.gate`): dark purple haze until the room is
cleared, then glowing white-gold with a GO arrow, after Archero 2. While it is open, players walk 1.5× faster (`Balance.Player.exitRush`, `ExitOpen` on Workspace, set by `RoomController`; owner 2026-10-25). **The next room is built while this one is played** (`Arena.prepare`, `Balance.Run.prepareDelay`, owner 2026-10-26), parked in `ReplicatedStorage.NextArena` and swapped in at the door; the client preloads it and its enemies (`Fx/RoomPreload`), and every card image from the story on (`UI/Cards/CardPreload`, `DeviceTiers.warmCardImages`); `tests/Preload.spec`, numbers in `docs/PERFORMANCE.md`. Moonlit
Arena's waves draw from the first
`Balance.Waves.rooms` (10) rooms only.

**How new things get in, and what is in flight** (owner, 2026-10-23: "keep
track of all of the steps … automate things so when i want to add something
new to the game, I can"): `docs/PIPELINES.md` is every pipeline step by step
— enemy, rigged enemy, boss, arena, weapon kit, card, sound, art — with the
owner's steps and Claude's; `docs/TRACKER.md` is everything started and not
finished and who it waits on, **updated in the same PR as the work**. Start
every file the owner sends with `python -I tools/intake.py <file>` (what is
new against the repo, clip by clip), finish every change with
`tools/check.sh` and `tools/ship.sh`, and trust no Studio test before
`tools/sync_probe.py`'s probe reads all true. After any import,
`tools/studio/dump_imports.luau` gives the mesh ids and bones. Project
skills run these: `/intake`, `/add-enemy`, `/add-arena`, `/add-weapon`,
`/add-sound`, `/ship`, `/status`.

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
  chosen 2026-10-22): 27 skills (Dual Bows added 2026-10-22), each with levels, a rarity and a stat line per
  level (`Config/Abilities`, `Config/Rarities`), dealt weighted by rarity with
  2 rerolls a run, and a Heal filler card. Momentum is banked by moving and
  spent on the 2 s of shooting after; every archer crits 5% of the time.
- **The owner's card UI** (`client/UI/Cards`, `Config/Card*`): the draft
  screen, skill bar, hold-for-detail panel, phone celebration, gamepad focus
  and the Mythic reveal, from `design_handoff_upgrade_cards`. `CardFrames` is
  generated from the design's `frames.json` by script — regenerate, never
  hand-edit. Images are uploaded; ids in `CardAssets`.
  **Since 2026-10-24 the cards are the owner's Glow Toy set**
  (`assets/ui/glow_toy_cards/`): each card a crystal body per rarity, its
  own name banner and its icon tile, with the stat, description, level chip
  and pips drawn live from `Config/Abilities` (the set's stat lines are
  placeholders). `CardArt.spec` makes every new card bring its art.
  The skill bar stays at the bottom through the whole run (small in a
  fight, `Config/Hud`, full size under the draft), and
  every pick plays the celebration — the card's icon flies into its slot —
  on every device, not only phones (owner, 2026-10-22).
  Card motion follows Balatro (`DraftScreen`, `FOLLOW_K`/`FOLLOW_D`):
  cards chase their places on a spring and lean into their sideways
  speed, the hand is fanned, and each card's shadow stays on the table as
  it rises. **Card sizes never spring or pop** — the owner found that read
  as the text pulsing; only places, leans and turns move.
- **The owner's end screens** (`client/UI/EndScreen`, `Config/EndScreen*`):
  Victory when the stage is finished, Defeat on death, from
  `design_handoff_end_screens` (2026-10-22). Stage, kills, time, health and
  progress come from the server; the button asks for the next run
  (`Remotes.RunRestart`), which the server grants only once the run is over
  — there is no restart timer any more, and the world holds still behind
  the screen. Fully animated from `EndScreenTimeline` by
  `UI/EndScreenMotion` (posed from one clock, so a tap skips by moving the
  clock); `EndScreen.hold(ms)` freezes it at one moment for a Studio
  capture. **Blocky since 2026-10-25** (owner: "change defeat and victory
  screen to new blocky design language"): built 1:1 from Codex sheets
  `assets/concepts/blocky/ui/end_victory.jpg` / `end_defeat.jpg`, laid out
  in the sheets' own pixels (`EndScreenLayout`), every panel, row and
  button flat blocks with stepped corners, the art Codex's
  (`assets/ui/end_screens/cutout.py`). Defeat is deliberately sad (slate,
  rain, the fallen hood; owner: "make the defeat screen sadder"). Both keep
  a REWARDS box (coins, gems) that counts up `Summary.coins` / `gems`,
  which nothing sends until the meta loop pays out; Victory's has a chest
  slot under them showing the chest of the stage's `area` (one Codex chest
  per area, owner: "codex needs to draw a chest per area"). HOME stays out until a
  lobby exists.
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
- **Measured speeds** (`docs/RESEARCH-archero.md` §7): arrows 165 studs/s (footage 190; slowed to 110 at playtest, then every speed ×1.5 on 2026-10-22),
  slow enemy orbs 18, the Lancer 42, Diagonal Arrows ±30°.
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
  edge) under soft bright lighting with tier-gated bloom; sparkling enemy
  shots (since 2026-10-24 the Spitter's seed: a leaf-green outlined cube,
  tumbling, `Fx/ProjectileRenderer`). Presentation only.
- **The dash** (4-second cooldown, readiness bar), player hit feedback, and
  draft enemy bodies.
- **Archero 2 proportions:** a portrait 35 × 58 room, a camera that fits the
  room's width and follows depth only, spawn markers, orb enemy shots.
  **Phones are framed closer** (`Balance.Camera.phone`, `Util/CameraFit`):
  about 1.8× closer held sideways and the floor at ~97% of an upright
  phone's width, still all of it. Studio cannot emulate a phone over MCP, so `CameraFit.spec` pins it.
  **The phone UI is larger too** (`Device.isPhone`, `Config/Hud`,
  `UI/HudLayout`): either way it is held, the skill bar is centred at the
  bottom with health and dash right above it, inside the device's safe area
  (`ScreenInsets.DeviceSafeInsets`), and the dash button lifts above that
  stack when the screen is too narrow for it to keep its corner. The draft
  keeps the skill bar off until a pick is confirmed,
  and end screens take 97% of the height and 98% of the width.

The numbers in `Config/Balance` are the last ones asked for or measured, not
settled ones. **Damage is on Archero 2's scale** (docs/RESEARCH-archero2.md
§3): player 225 HP hitting for 100, grunts die in three hits, about four
enemy hits kill the player — which replaced the owner's earlier "enemy
health ×1.5". Damage numbers are white, red crits, orange burns.

**Classes** (`Config/Classes`, 2026-10-23): the Ranger (Twig Bow), the
Arcanist (Branch Staff: slow, heavy orbs with Blast Arrows built in) and
the Warden (Timber Blade, melee: `Combat/MeleeSystem` lands each blow of
a three-hit combo on the server, in `Shared/Combat/SwingBox`): an arc in
front for the first two blows, a circle in front for the slam, both grown by
Cleave and Long Reach. The red of his swing sweeps exactly that shape
(`Fx/SwingTrail`, `Shared/Combat/SwingSweep`). Each weapon
is the owner's Claude Design kit, its animations generated into
`Config/WeaponAnimations` and played in code by `Fx/WeaponPose`. The
first weapons (Leaf Bow, Arcane Staff, Ruby Greatsword) were deleted on
2026-10-24 (owner); the blocky ones' R15 kits (KeyframeSequences) are
converted by `assets/models/weapons/leaf_bow_r15/kit_to_json.py <kit>
<prefix> <out>`). The bow has a legs layer (`clips.legs`: Idle standing,
Walk at the character's pace) under the upper-body Hold; the sword a
`special` clip, Earthbreaker's leap, played as a dash ends
(`WeaponPose.playSpecial`), whose Impact marker times the server's slam. Each class
drafts its own cards plus a shared twelve (`Ability.classes`,
`docs/CLASS-CARDS.md`): wave 1 of the Warden's and the Arcanist's is built,
wave 2 is designed and has its icons. Each class has one Mythic: Dual Bows,
**Meteor** (every 5th cast) and **Earthbreaker** (the dash ends in a slam
and erupting cracks), both resolved by `Combat/AreaStrikes`. They look as the
owner's mythic-fx.js draws them (`Fx/MythicFx`, `Balance.MythicFx`, budgeted
by `DeviceTiers.mythicFxShare`), and the staff plays the kit's Meteor cast
when the server counts one on the player (`Meteors` attribute).

**XP crystals and hearts** (`Run/Pickups`, `Fx/PickupFx`): a kill's XP
drops as cyan crystals; walk over your own to take them mid-fight, and any
left are drawn in when the wave or room clears. Hearts drop on 5% of kills and on every
Valkyrie wave, wait on the floor, and heal 20% of max health when walked
over, full health or not, putting a green "+N" on the health bar's right end
(`HealthChanged`'s third value, `Hud.healNumber`, owner 2026-10-26). **XP counts as the crystals arrive** (owner, 2026-10-26):
a crystal can't be taken until it has landed (`Balance.Pickups.popTime`), and its XP is
credited a `collectFlight` later (`RunSession.landXp`), so the bar and any level-up rise
as it reaches the player, never as the enemy dies.

**After every pause the attack starts over** (owner, 2026-10-26: the hit landed before
the attack's animation after an upgrade pick): `Shared/Combat/FireRhythm` is the
move-or-shoot rhythm both sides keep; the server's first step after any hold (card screen,
banner, NEW ENEMY!, end screen, lobby) calls `RunSession.resumeAttacks` and
`MeleeSystem.resume` (a swing in the air never lands), the client's `RunPaused` resume
does the same in `LocalFiring`, and `WeaponPose` holds still behind the screen and readies
the weapon from the start. A screen that lets the server go on must let the client go at the
same moment, never after its own exit animation (the NEW ENEMY! screen did; `docs/FIXES.md`). `tests/FireRhythm.spec` pins it. Weapons are held
`Balance.Player.heldWeaponScale` (1.2×) their `Config/Weapons` size, about the grip.

**Sounds** (`Config/Sounds`, `Fx/SoundFx`): made from scratch in
`assets/audio/synth.py`, or cut from CC0 Freesound recordings by
`assets/audio/freesound.py` (licence checked on each sound's page; a
game's ripped audio is never used, only measured against), auditioned on a page whose picks save to its own
database (`assets/audio/build_page.py`; since round 20 artifact M81L9gr5Wiows6H6G5nGyQ, which pauses long takes, before it E53Pu8d5UbwLKnyKYEDo2K,
read with `ArtifactData` `picks`), uploaded to Roblox by the owner, and the
ids go in `Config/Sounds`. A sound with an empty id is silent, so every hook
is wired before its audio exists.

**Saved data and payouts** (2026-10-25, the first persistence): `Server/Data/PlayerData`
loads each player's profile (`Util/SaveSchema`: coins, gems, boss items, weapons owned, the one
equipped, bosses beaten) with a session lock in the record, saves a changed profile within 6 s,
all every 60 s, on leave and on shutdown, and never writes over a record another live server
holds or one from a newer game version. Studio uses its own store (`PlayerData_Studio`), and
with Studio API access off profiles live in memory only. Every change goes through
`Data/Wallet` (server only; the `Coins`/`Gems` Player attributes and `Remotes.ProfileChanged`
tell the owner). Runs pay (`Config/Economy`, per area): coins per kill, a clear bonus at Victory,
and the boss's item every time it falls plus gems, more the first time; the end screen's REWARDS
box shows the stage's take. Any schema change bumps `SaveSchema.VERSION` with a migration and a
`SaveSchema.spec` case.

**Portals open a screen; the lobby sprints and jumps** (owner, 2026-10-26): walking into a lit
portal opens `UI/PortalScreen` (the area, its levels from `Config/Lobby.portals[i].levels`, START),
and only START starts the run, validated by the server against the portal the player stands at
(`Remotes.PortalStart`, `Run/Lobby.startFor`, `tests/Lobby.spec`). In the lobby there is no dash:
Shift / gamepad X / the phone's SPRINT runs (`Config/Lobby.sprint`) and Space / A / JUMP jumps
(`RunSession.allowJump`, `Input/LobbyButtons`); a run still dashes and never jumps.

**Empty hands in the lobby** (owner, 2026-10-25): the server holds no weapon while `InLobby`
(`Main.refreshWeapon`, `HeldWeapon.unequip`) and `Fx/WeaponPose` writes no pose there, so
Roblox's own animation has the arms; the weapon comes back as a run starts.

**The weapon shop** (owner, 2026-10-25; `Config/Shop`, `Util/ShopRules`, `Server/Data/Shop`,
`UI/ShopScreen`): at the lobby's Blacksmith, SHOP (or E) opens CRATES, STORE and MY WEAPONS.
A crate per area for coins (500, 1,000, 2,000, 4,000, 10,000, 20,000) rolls on the server
(Uncommon 60, Rare 28, Epic 11, Mythic 1) one of that area's weapons; a weapon already owned
pays back 40%; areas with no weapons yet are black silhouettes. The store sells an area's
weapons for gems by rarity, its Legendaries for coins and 3 of its boss's item; Mythics only
come out of crates. EQUIP holds an owned weapon (its class with it), saved, in hand at once in
the lobby. Every weapon picture is the THREE-QUARTER view of the reference sheet its 3D model was
built from (owner: "use the 2d reference sheet 3/4 view pictures"), all turned to the Acorn Bow's
angle (owner, 2026-10-26: "all at the same angle"; `Config/ShopAssets`,
`assets/ui/shop/three_quarter.py`); a new weapon needs one (`Shop.spec`). Studio test remote:
`Remotes.DebugWallet:FireServer(coins, gems, itemsEach)`. In Studio the shop opens by itself on
reaching the lobby, wallet topped up (`Sandbox.openShop`; set it to nil to stop that).

**Revive** (`Balance.Revive`): once per stage, automatically, after Second
Wind — full health, 2.5 s untouchable behind a gold shield, and enemy shots
within 12 studs cleared.

**The Slime King** (Mossy Glade's boss, the owner's
`design_handoff_slime_king`, 2026-10-23) is the first boss built. A boss
is an `EnemyConfig` with `boss` set: it does not walk and swing but loops
its moves, Royal Bounce then Slime Lash. `Enemies/BossMoves` runs each
move as a pure timeline (pinned by `tests/BossMoves.spec.luau`),
`EnemyManager` resolves what lands through `RunSession.applyDamage`, the
client obeys shoves and the grab (`Input/Shove`, via `Remotes.PlayerShoved`
/ `PlayerGrabbed`) and draws the boss bar (`UI/BossBar`). **Since
2026-10-24 he is King Bloblin, blocky and clip-driven** (the owner's King
Bloblin Fight): built from his imported rig (`EnemyDesigns.Imported`,
`Config/ImportedModels/KingBloblin`, amber Neon eyes), his 22 clips played
on each beat (`Balance` boss `clips` → `BossMoves.clip` → the `ModelClip`,
`ModelClipAt`, `ModelClipSpan` attributes → `Fx/ModelAnimator`), his lash
chain stretched to the lane (`BossMoves.chainScale`, `ModelClipStretch`),
and every effect in cubes and tiles (`Fx/BossFx`, `Balance.Telegraph.king`;
nothing round). `BossBody` only keeps his shadow on the floor; its jelly
tube is for a server-posed body. `tests/BossClips.spec.luau` pins it.
Sounds for his moves are not made yet.
**The Broodmother's Web Walker** (owner, 2026-10-25, in place of the
jump): a boss can name its own move loop (`EnemyBoss.loop`; hers opens
with the lash, then the spin) and run at the player between moves
(`EnemyBoss.chase`, `BossMoves.chase`). A `Spin` raises a web nearly as wide as the room that
turns clockwise round her. The player walks the edge with its arms, like a
horse walker. One pure module (`Shared/Util/WebWheel`) decides both who
is hit (server, `BossMoves.wheelHit`) and where the arms are drawn
(`Fx/BroodWheelFx`). `tests/WebWalker.spec.luau` pins it.
**The boss entry banner** (`UI/BossBanner`, `Config/BossBanners`, owner's
pick 2026-10-24: style A, "Slash"): as a boss appears, a slanted band in its
colour tears across, its 2D blocky icon rushes in and plays a four-frame
attack once (a 2x2 sheet from Codex, `assets/ui/boss_banner/cutout.py`), and
its name slams down — 4.7 s, over the boss music's battle intro. Both start
from `Fx/BossWatch` on the same tick (measured 0.03 s apart). Keyed by the
`Boss` attribute's title; the boss bar shows the banner's name. Icons for all
six Act 1–3 bosses are uploaded.
It plays over a dark ground in the boss's colour, above the whole HUD, so
nothing of the room shows, and **the run holds still until it has gone**
(owner, 2026-10-24): the server skips its step for `BossBanners.hold` from
the boss's arrival (`EnemyManager.introHolding`, beside the card screen's
pause) and the client stops input on `RunPaused.setIntro`, a flag apart from
the draft's.
**The NEW ENEMY! screen** (`UI/NewEnemyScreen`, `Config/NewEnemies`, owner
2026-10-25): the first time a player meets a kind of non-boss enemy (once per
server visit until there is a save), its picture, name and description come up
on its area's banner, and **the run holds until GOT IT!** (`RunSession.meetEnemy`
as an enemy lands, `anyMeeting` in the server loop, `RunPaused.setMeeting`,
`Remotes.NewEnemy` / `NewEnemySeen`). Each area's screen is the owner's
approved Codex sheet 1:1 (`assets/concepts/blocky/ui/new_enemy/`), uploaded
in two halves with its picture window, name plate and description box emptied
by Codex, its dark ground cut away and an ink border round the card; it drops in
and settles, and GOT IT! plays the cards' click and sweeps it away; the enemy pictures are Codex's 2D blocky art from each one's sheet
(`assets/ui/new_enemy/cutout.py`). The sheet is the stage's area's. Areas
1–3's fourteen are in, Drowned Village's four waiting for their enemies.
`tests/NewEnemies.spec` makes every enemy met in an area bring a screen.

Not done: the other nine bosses — designed (`docs/BOSSES.md`, two per
act, one per area, with Codex concept art) but not built; Phase 3's
playtest question — *did two runs in a row feel
meaningfully different?* — which needs the owner.

**Every enemy but a boss flashes white and is knocked back on a hit** (owner,
2026-10-25, a rule for every enemy from now on): `Fx/HitFeedback`'s solid white
Highlight, and for `Balance.Knockback.stagger` after a hit an enemy only slides
with the shove (`EnemyManager` `staggerUntil`), so its own walking and charges
cannot cancel it. A new enemy needs a `knockback` above 0 (`Balance.spec`).

**Enemies arrive in triangles of three** (`Balance.Spawning.clusterSize`),
the tip pointing at the player; the row swings round the tip when a wall is
behind it. Blocked arrows stick in the wall for a moment.

To resume: `rojo serve`, connect the Studio plugin, Play. Read
`docs/FIXES.md` before debugging anything — most of what can go wrong here
already has.

**Enemies path round cover** (`Enemies/Pathing`, 2026-10-23): when cover
stands between an enemy and its target it follows an A* route over a grid
built per body size from `Arena.isClear`, planned for its widest turn first.
The face-slide below is now only the fallback when walking straight.

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
- **Enemy overlap with cover: measured clean, with limits** (2026-10-23).
  Over rooms 1–4 of Level 1 (every archetype there), enemies' visible
  meshes (Body, Decor, Eyes; not the Shadow disc or the invisible Hitbox)
  never reached into an obstacle's box: 0 of about 13,000 samples by
  their box corners, an upper bound for round bodies, and hitbox corners
  0 of 5,180. The earlier 0.59–0.62 stud readings predate the arena art
  and counted ground rings. Not measured: rooms 5–10, and the arena art
  itself, which can be larger or smaller than its obstacle box. Measure
  per part, client-side, answering the card screen, before fixing.

**Studio test keys** (`client/DevKeys`, honoured by the server only in
Studio): **M** — the next card hand includes a Mythic; **L** — a Legendary;
**V** / **B** — preview the Victory / Defeat end screen, on this client only.
**C** — switch class (Ranger → Arcanist → Warden, `Config/Classes`): the loadout
and the weapon in hand change at once.
From a probe, `Remotes.DebugRoom:FireServer(10)` jumps the run to a room
(Studio only), to test the boss without fighting through the level.
From a probe, `Remotes.DebugGrant:FireServer("Cleave")` grants one level of
any card (Studio only), to test a card's effect without drafting it.
**K** — spawn a wilf (`Remotes.DebugSpawnEnemy`, any `Balance.Enemies` key from a probe).
**P** — the pets the owner imported follow you, playing their own clips
(`Fx/PetPreview`, built by `Server/Dev/PetPreview` from `Config/PetModels`); P again
puts them away. A look only, until Phase 6's pet system.
**O** — the playtest sandbox (owner, 2026-10-24), also the SANDBOX tab on the left edge
(`UI/SandboxMenu`, `Config/Sandbox`): ENTER turns the room into training dummies that
never die or hit back (`EnemyConfig.dummy`) with every player untouchable and the run
held (`RoomController.enterSandbox`); LEAVE starts the stage over. Any weapon in hand
(`Remotes.DebugWeapon`, held as its class, kept for the run like the class) and any
one pet at heel (`PetPreview.show`). A new `Config/Weapons` entry must be listed in
`Config/Sandbox` (`tests/Sandbox.spec`).
**`DevTier`** — a Workspace attribute ("Low", "Medium", "High") set in Edit before Play
plays as that device tier (`client/Device`, Studio only), to measure a phone's budgets
(`docs/PERFORMANCE.md`, `tools/studio/perf_room.luau`).
From a probe, `Remotes.DebugForceMythic:FireServer("Legendary")` does the
same without the MCP keyboard tool, which reports as a gamepad and flips the
draft into its controller layout.

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
  most, the next found turned hitbox corners 0.62 studs into pillars. A
  later sweep of rooms 1–4 found none — see "Known rough edges".
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
- **Threads spawned by an `execute_luau` probe die when it returns.** A
  background sampler started in one call records nothing; sample inside the
  call that waits, or time a `screen_capture`.
- **`user_mouse_input` drives the GUI for real**: `moveTo` an
  `instance_path` such as `LocalPlayer.PlayerGui.DraftScreen.Panel...`,
  then click, or `mouseButtonDown` / wait / `mouseButtonUp` for a hold.
  Play-mode captures do show the GUI (and the 3D view, these days).
- To move the character from a probe, call `Humanoid:Move` from
  `RunService.Stepped`: `MoveController` resets it every RenderStepped, and
  a teleport does not count as moving for the move-or-shoot rule.
- **Studio's phone emulator can be used for layout checks**, but its input
  flags lie: touch only at first, then mouse and keyboard too once the
  window has focus. Detect a phone by screen size (`Device.isPhone`), never
  by which inputs are present. It cannot be rotated over MCP.
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

**9. Every generated image goes through Codex.**
Concept art, reference sheets, icons, card art, textures — anything generated. Always
`codex exec`, with the prompt on stdin and `-i` for reference images, signed in with the
owner's ChatGPT account. Never another image generator, and never hand-drawn SVG standing in
for art. Sheets go in `assets/concepts/`; the look is the **blocky** style for everything new.
Owner's rule, restated 2026-10-24. The pipeline is `docs/PIPELINES.md` §8.

**10. 3D models are designed in the browser, through Claude Design.**
The route: Codex reference sheets (rule 9) → Claude Design opened in the owner's Chrome
(Claude in Chrome tools, `mcp__claude-in-chrome__*`, each agent in its own tab group) →
one agent per model, building it until it matches its sheet 1:1 → GLB exported → that
kind's pipeline (`docs/PIPELINES.md`). Every 3D model goes this way: enemies, pets,
weapons, effects, arenas and ambience. Never invent a look without a reference sheet.

Blender was tried for this on 2026-10-24 and **paused** the same day (owner: "scrap blender
for now"): the Blender MCP stays set up (`~/.claude.json`, the `blender-mcp` add-on;
`C:\Users\dabur\blender-mcp\start_mcp.py` restarts it), and its build scripts and render
comparisons are on branch `phase-3/blender-swords`, but no model is made there until the
owner says otherwise.

**11. Every word on screen is in the blocky font.**
Press Start 2P, Roblox's `Enum.Font.Arcade` (`Font.fromEnum(Enum.Font.Arcade)` for a
`FontFace`): HUD, cards, end screens, banners, damage numbers, billboards, dev labels, all
of it (owner, 2026-10-24: "anywhere there is writing it should be in a blocky font … have
it as a rule going forward"). The room sign's own pixel font (`Config/PixelFont`) counts.
`tools/check.sh` fails on any other font.

**12. Every Legendary and Mythic glows.**
Weapons, skins, pets, anything with a rarity (owner, 2026-10-24: "anything that is a legendary
or a mythic NEEDS a glow to it"). A Mythic's glow cycles through the rainbow. Weapons: their
glow parts are Neon with a light (`Combat/HeldWeapon`), a Mythic's turned round the hue wheel
(`Fx/WeaponGlow`); `skins_to_luau.py` gives every Epic and up a glow. Pets: `Config/PetAuras`
lists every Legendary and Mythic pet.

**13. Arenas and models match their reference 1:1 in the game.**
Colours, brightness, pieces and layout, as seen in Studio, against the reference sheet they were
built from (owner, 2026-10-25: "it looks 1 to 1 with the reference pick ... if the arena does
not match 1 to 1 then redo it"). Before calling one done, screenshot it in a playtest beside its
sheet and compare, sampling colours from both; if it does not match, redo it. A Claude Design
GLB's colours are linear: bundle kits with `kit_bundle.py --srgb`, or they come in dark.

**14. Weapons are pictured in 2D.**
Every picture of a weapon on screen (menus, cards, the sandbox, rewards, and later the
blacksmith and gear selection) uses the 2D weapon art, never a render or ViewportFrame of the
3D model (owner, 2026-10-25: "anytime pictures of weapons are on screen they are going to use
the 2d weapon models because i like those more than the 3d models"). The 2D art is the blocky
Codex weapon art (`assets/concepts/blocky/weapons/`); cut an icon from it or have Codex draw a
single view in the same style, upload it (Studio MCP `upload_image`) and show it as an
ImageLabel. The 3D models stay for the weapon in hand in the world.

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
