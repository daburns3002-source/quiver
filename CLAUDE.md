> **Codex Studio preservation, 2026-10-29:** Before connecting Rojo or changing
> the hatchery/chest UI or combat balance, read
> [docs/CODEX-STUDIO-HANDOFF-2026-10-29.md](docs/CODEX-STUDIO-HANDOFF-2026-10-29.md).
> Preserve the approved standalone UI and merged balance changes. The full older
> Studio snapshot must not overwrite newer save-schema, pet or Endless code.

# Arrowborne — builder rulebook

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
Phase plan: `docs/ROADMAP.md`. Lobby spec: `docs/LOBBY.md`. The dexes: `docs/DEX.md`.
The story through the areas ("the bog is rising", owner-approved 2026-11-13): `docs/STORY.md`.
**Classes and world: `docs/WORLD.md`** — since 2026-10-22 the game is three
classes (Ranger, Arcanist, an unlockable melee class; a fourth, the Assassin, since 2026-11-15) across ten areas
in five acts. The game is called Arrowborne (owner, 2026-11-04;
before that Arrow Legends, and Archer Legends on screen). The repo, the
checkout folder and the DataStores keep their old names on purpose. Nothing of it is built yet, and its open decisions are the
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
the shared contract with the intro music, `Config/Music.intro`) to **the title screen,
"The World Tree at night"** (owner, 2026-11-12, picked as Dark 1 from drawn references
after "take inspiration from elden ring and dark souls": the feeling only, dark, quiet and
grand, nothing copied; the painted title before it "looks AI"). **No painted or generated
picture: it is built by hand from flat blocks** (`UI/TitleScene` draws Frames from
`Config/TitleScene`; `Util/TitleLayout` and `tests/TitleScene.spec` hold it on screen at every
shape): a night sky with square stars and a moon, the World Tree in teal with mint lanterns and
warm windows (never a glowing golden tree), far hills, a near-black ridge with a tiny hero
seen from behind, bow on their back, and a pet at their heel (a plain silhouette, not the
player's avatar), the ARROW BORNE logo as live words in pale gold over a streak of light, slow
motes, and the kit's green BEGIN ADVENTURE (`Chunky.button`, with a play triangle), gently
pulsing. Two layouts in points, a phone upright (390 x 844) and on its side (844 x 390); any
other screen scales the layout until its `safe` box fills it and runs the sky and ridge to the
edges. Its one image is the game's soft glow (`GearAssets.fx.glow`). The picture never moves
once up (owner) but for the motes; Roblox's reduced motion stills them and the pulse.
A second pass added a little detail and kept it minimal (owner, 2026-11-12: "i like the minimalist approach but
still needs a little bit more to it"): thin cloud bands, a few plus-shaped stars and one star in five twinkling,
a halo and craters on the moon, a farther row of hills, small stepped pines and village lights on the near ones,
roots, leaf blocks round the crown's edge, lantern strings and a lit doorway on the tree, grass on the ridge and
one lantern post. All of it is numbers in `Config/TitleScene`; `tests/TitleScene.spec` holds each piece on what it
stands on. A third pass made the hero noticeable (owner, the same day: "the player model ... should be a little
bit more noticeable"): half as large again, a bow whose ends stand clear with a line of light along it and its
string, arrows in a quiver, light on the side facing the tree, a pool of the tree's light behind them, and a
scarf that sways, in the hero's own dark colour with a line of light along it (owner: "the color of the scarf
should match the player still"); plus far birds, a rare shooting star, vines and
small windows in the crown, glowing mushrooms and a signpost on the ridge. Every light's glow is the soft round glow picture, never a
square, and every star is a perfect cross on whole pixels (`TitleLayout.cross`; owner, the same day). `IntroCutscene.preview(w, h)` shows it in a phone-sized frame in Studio. BEGIN ADVENTURE plays **the story cutscene**
(`UI/StoryCutscene`, `Config/Story`, `Util/StoryTimeline`, owner 2026-10-25), **animated
as the owner's approved Claude Design clip** (owner, 2026-11-10; `Config/StoryMotion`,
`Util/StoryMotion`, ported number for number from the Design project "King Bloblin's
Roar"): 38 Codex frames from the owner's approved storyboard (`assets/concepts/blocky/ui/story/`)
pan, zoom, shake and dissolve under crisp pixel-block overlays (fireflies, leaves, steam,
droplets, rings, speed lines), a landscape stage on wide screens and the Design's portrait
stage (the same frames, reframed) on tall ones; no video upload (it costs Robux). The frames
still come in on their holds, so the music and sound cues are unchanged: King Bloblin asleep in the
glade with his over-the-top slimy chest, a Slime Soldier brings a WANTED poster
(WANTED: his icon, REWARD: the chest icon, the three class icons signed), he
roars, the heroes (never in a frame with the king) run into the forest, black.
Its calm music (`Config/Music.story`, `assets/audio/music/story_theme.py`) is
scored to the frames' holds, the king's yawn mixed in: change a hold and
re-render and re-upload it. SKIP >> cuts to black. It ends in **the tutorial** until the player has
beaten Mossy Glade 1-1, and in the lobby after that (owner, 2026-10-26: "the tutorial should
play until they have beaten the first level of mossy glade"; `Tutorial.untilBeaten`,
`LevelUnlocks.tutorialOwed`, decided by the server from the saved profile at IntroBegin)
(`Config/Tutorial`, owner 2026-10-25): `Balance.Stages[Balance.tutorialStage]`, five
Mossy Glade rooms (81-85, kept apart from the generated rooms) of Moss Slimes and
Sprout Spitters only, played as a Ranger, won into the lobby. **It cannot be lost** (2026-11-14): a hit
never takes health under `Tutorial.healthFloor` (1; `RunSession`), and room 2's logs stand to the sides so
the lane from the spawn is open (`tests/Tutorial.spec`). Its upgrades are
fixed, the same for everyone (`Util/TutorialHands`, `tests/Tutorial.spec`): a
Common, an Uncommon and a Rare first; on room 3's level-up Multishot (Legendary)
in the middle; Legendaries and Mythics banned from its pool (`Loadout.State.banned`,
which a fixed hand ignores), no rerolls. The rooms' XP lands the level-ups in rooms
1-3, and room 3 is granted the XP it owes if not. `UI/TutorialPrompts` (redone 2026-11-11, owner:
"highlight the important words and have the tutorial clearly explain the controls and have the music quiet
down when there is something on the screen to read") shows one idea at a time in the words for the device in
hand: move, stand still to shoot, the crystals, the dash, the gate out of the first cleared room, and picking
a card over the first hand (`Util/TutorialSteps` decides which, `Config/Tutorial.prompts` has the words; that one
stands in for the draft's own heading, which is put away while the panel makes room: `DraftScreen.setHeading`,
`RunHudRules.draftUnder`; and the draft draws REROLL only when it has a redeal to give). In a
prompt `[..]` marks a control and `*..*` an action, each drawn in its own strong colour chosen for the panel's
ground (`Util/PromptText`); the panel is built from `UI/Chunky`'s palette. The music ducks to `Music.readDuck`
while one is up, and under a NEW ENEMY! screen in the tutorial (`MusicFx.setReading`).
`tests/TutorialPrompts.spec` holds every prompt to the rules; `TutorialPrompts.preview` builds one in a
phone-sized frame for a Studio look. **The room prompt stands outside the arena** (owner, 2026-11-19: "the
tutorial tips need to be on the outer arena so they do not block the arena"), placed every frame by
`Util/ArenaMargin` from the room's corners as the camera shows them (`UI/RunMargin`) and the run HUD's pieces
(`RunHudRules.pieces`): in the right margin on a computer (left only if the right will not hold it), sized to
the margin (words about 13 letters' worth across, up to 36 points). On a phone held upright, whose floor
fills the width and whose forest is mostly under the HUD, a compact card docks against the HUD at the end of
the room the player is nearer (`ArenaMargin.docked`, moving end `Camera.phone.promptSwitch` studs past the
middle) and **the camera pulls back while it is up** (owner, 2026-11-19: "Pull camera back";
`TopDownCamera.keepClear`): eased out to `Camera.phone.promptFitWidth` (48, 1.33x) and moved along the room
just far enough that the end wall stands past the card (`CameraFit.clearFocus`), the player kept
`promptPlayerRoom` points off the card and the HUD (the player wins if both cannot be had). Mid-room the far
end then slides under the top HUD while a prompt is up. First-time tips on an upright phone still ride the
end wall and can cover a strip of floor: their 160-point card does not fit mid-room even pulled back.
`tests/ArenaMargin.spec` holds both with the real camera maths for five computer sizes and three phones.
The run holds still until the story's black has held: the server skips
its step while any player is still on the title (`RunSession.anyAtTitle`,
cleared by `Remotes.IntroBegin`, fired at the story's end), the client holds on
`RunPaused.setTitle` then `setStory`, the room's music and its ROOM sign wait. **The road in is short** (Fable's loop review, 2026-11-11): on a fresh join the server decides
from the profile and tells the client as the `JoinRoute` Player attribute (`Party.ROUTE`,
`Main.server` `routeJoin`): a player who owes the tutorial is teleported to its server behind the
join's loading screen and sees the title and story there (`story` in the teleport data; `seen`
skips the story); one who has beaten 1-1, or won the tutorial before (`SaveSchema` v8
`tutorialDone`), sees the title and no story. Studio cannot teleport, so there the title (and story)
play first and the tutorial starts in place. The tutorial's first win tops coins up to the first egg
(`Tutorial.firstEgg`, `Util/FirstEgg`, `tests/FirstEgg.spec`) and `Fx/HatcheryPointer` points at
the Hatchery until a pet is owned; `UI/TutorialSkip` is SKIP TUTORIAL for a player who has won it
once. **In Studio, set a `SkipIntro` attribute
on Workspace in Edit before Play** to skip it on both sides, for probes that
need the run going, into the lobby (firing `Remotes.IntroBegin` from a probe now
starts the tutorial, as the story's end does).

**Everything new gets a tip, once ever** (owner, 2026-11-13: "there should be a tutorial for everything
new that the player has not done yet. if they have already seen that certain tutorial tip then dont play
it anymore"). One system: the tips are data in `Config/Tips` (one short line each, `[..]` a button and
`*..*` an action as in the tutorial's prompts), the save keeps the ones shown (`SaveSchema` v13
`tipsSeen`), and **the shown-once rule is `Util/TipRules.due` and nowhere else** (`mark` on the server,
`tests/Tips.spec`). A screen only calls `UI/FirstTips.show(key)`: each lobby station as it opens
(`UI/StationScreen`, keyed by station), the portal, the Soulstone shop, a boss once its banner has gone,
a draft with a REROLL, a lost run, an Endless checkpoint; `FirstTips` itself asks for class select while
it is up, for what the profile says is new in the lobby (a first pet, a weapon past the starters, three of
a tier to merge, the first gems, the first boss item) and for the first area past Mossy Glade. Once a tip is on screen the client
sends `Remotes.TipSeen` and the server keeps it (`Wallet.sawTip`). **Since 2026-11-14 a tip goes by itself
after `Tips.showFor` (6 s), holds nothing and takes no keys** (owner, "Build top 5", after the kid playtest
counted 13 tips that each stopped the game for an OK: `docs/PLAYTEST-KID.md`); its OK only sends it away
sooner. Only a tip marked `hold` in `Config/Tips` still waits for OK (`TipRules.holds`): class select's and
REROLL's, each over a screen that is already stopped, and each goes with its screen if the class is chosen
or a card taken under it (`FirstTips` `passed`). One line (`hold = true`) puts a tip back to pausing.
**Tips are spaced** (owner, 2026-11-14: "there needs to be spacing between them, so everything isnt just
popping up one after another"): after a tip has gone the next waits `Tips.gap` (10 s) of quiet, where it
was 0.6 s; a `hold` tip, whose screen is stopped and waiting, only `Tips.holdGap` (`TipRules.spaced`,
`tests/Tips.spec`). A tip a screen asks for (`FirstTips.show`: a station, the portal, a boss) goes before
the ambient ones `look` asks for from the profile (a first pet, gems), which are asked again every second
and lose nothing by waiting. A tip that cannot get its turn within `Tips.patience` (20 s, longer than a
tip's turn and the quiet after it) is let go and asked again the next time its thing happens.
**A lobby screen's tip stands on that screen's title bar** (the run-through, 2026-11-14: under the top HUD
it covered every screen's tabs): the screen asks with its `Spot` (`FirstTips.show(key, FirstTips.header(root,
open))`), the card is placed by `TipRules.over` (centred on the bar, its foot on the bar's foot, so it
reaches up off the panel and never down), it waits `SETTLE` (0.4 s) for the screen's pop to finish before
it is measured, and it is let go, waiting or showing, the moment the screen shuts. **Where a panel stands
too near the top for the card to reach up off it** (the STORE: the card came down over GEMS and PASSES,
the every-class run-through, 2026-11-16) `over` is given the panel's box too and the card goes round the
whole panel: beside it in the wider margin as the upright card, or under it; with no room there either it
stays at the top of the screen. Class select's panel fills the screen, so its tip asks with its CHOOSE YOUR
CLASS plate as its `Spot` and stands on the title, clear of the cards. A wide card's words stand beside its
TIP tag, not under it (`TipPlate.card`: under it they had 32 points, two lines of 13). A tip that holds
nothing goes the moment a hatch or a crate reveal starts under it (`Reveal.busy`). What the profile says
is new waits while a station is open (`InStation`).
**A `hold` tip pauses everything until OK**
(owner, 2026-11-13: "they should be in the outer arena area so it doesnt block the arena, and also pause the
game and have an ok button to dismiss the tip and resume the game. make sure the music quiets as well while
its paused"): its card (`Util/TipPlate.card`, TIP tag, words, a green OK) stands beside the arena, in the side
margin a landscape screen has, or above or below it on an upright phone, clear of the run HUD
(`Util/ArenaMargin`, as the tutorial's room prompt; riding on the end wall as the camera follows; centred
under the top HUD in the lobby, `TipRules.place`). While it is up the client is paused
(`RunPaused.setTip`), the server holds the run (`RunSession.anyReadingTip`, only for a tip the save had never
seen, `Tips.holdMax` 60 s at most, let go by `Remotes.TipClosed`) and the music is down (`MusicFx.setTip`).
OK, Return, Enter or a gamepad's A closes it, **so a probe clears one with a synthetic Return**; that press is the
tip's alone (`FirstTips.takesKeys`, asked by NEW ENEMY!, the portal's START and the draft's A; the tip also keeps
gamepad selection on its OK while up). A phone on its side shows the room edge to edge, so there the card
stands over its foot; an upright phone gets it above or below the room when the camera shows forest there. It waits
while the title, the story, a story beat, an area's loading screen, a boss banner, NEW ENEMY!, MENU's panel
(`RunPaused.covered`), a hatch, the tutorial, or class select (for every tip but its own, drawn over it) is
up; one that cannot show within 12 s is let go, not marked, and asked again next time. The tutorial, NEW ENEMY!, the story beats, a first badge's pop-up and the Hatchery pointer
keep their own flags and are not repeated as tips. A new tip is a line in `Config/Tips` and a `show` call;
never rename a key (it is saved).

**The game is Mossy Glade's ten levels, then Thornwood** (`Balance.campaign = { 7, ..., 16, 4 }`,
owner 2026-10-26): **Mossy Glade 1-1..1-10** (stages 7-16, `level = "1-n"`, the lobby portal's
`levels`, `tests/MossyLevels.spec`): 1-1 and 1-2 ten rooms, 1-3 and 1-4 fifteen (rooms 86-135,
`tools/glade_levels.py`, each ending in a Glade Heart fight without a boss), 1-5..1-9 twenty waves
in one clearing each (the stage's own `fights`, and `elite` on the boss positions; owner, 2026-11-05)
and 1-10 twenty-five rooms, **King Bloblin alone in its last, his only appearance**. Inside a level
enemy health and damage rise every fight (`CombatTuning`, `Run/Waves.damageRamp`,
`docs/DIFFICULTY.md`). Every level is harder than the last: enemy health 1.1 at 1-1 (the old run's
0.8) up 0.1 a level to 2.0, damage 0.75 up 0.03 to 1.02 (owner: "enemy health needs to be scaled
up as well, the game is too easy currently"); Thornwood one step past, 2.1 / 1.05. A won level is
saved (`SaveSchema` v2 `levelsBeaten`, `Wallet.beatLevel`, server-decided in `RoomController`) and
opens the next (`Util/LevelUnlocks`); NEXT LEVEL goes to the portal's next level, and after an area's
last to the first level of the area that win opened (`LevelUnlocks.nextArea`, asked of
`LaunchLocks.portalOpen` for everybody in the run; since 2026-11-16, when the every-class run-through
pressed NEXT LEVEL on 1-10 and stood in the lobby). Only the last level of the last area built is won
into the lobby, and there the button says CONTINUE (`EndScreenRules.goesOn`); TRY AGAIN replays. **Level 2, Thornwood** (stage 4): twenty rooms, the first nineteen
`tools/thornwood_rooms.py` wrote and the Broodmother alone in the Brood Heart (rooms 21-39, 60).
The old twenty-room Mossy Glade run (stage 5, rooms 61-80, `tools/glade_rooms.py`) and Level 1
(stage 3) stay as data behind no portal, King Bloblin taken out of both. The server keeps
the current stage (`RoomController`) and publishes it as Workspace's `Stage`
attribute; read it through `Util/CurrentStage`, never `Balance.stage`
(`tests/Campaign.spec`). In Studio, `Sandbox.startRoom` starts any stage at a
later room.

**Level 1** (`Balance.stage = 3`, owner 2026-10-22): ten Mossy Glade
rooms — logs, pond, boulders, thorns, boss arena, twice. **Slimes**
(Moss Slimes and Brood Slimes), the **Ember Wilf** from room 6 (lunges:
a long charge warned by its eyes flashing red, a quick dash up close; `EnemyConfig.lunges`),
and room 10 was the **Slime King alone** (owner, 2026-10-23) until he moved to
the end of Mossy Glade 1-10 (2026-10-26); it is a Brood Slime fight now
(`tests/Level1.spec.luau`). Each room names
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
cleared, then glowing white-gold with a GO arrow, after Archero 2. While it is open, players walk 1.5× faster (`Balance.Player.exitRush`, `ExitOpen` on Workspace, set by `RoomController`; owner 2026-10-25), and the lobby's gold arrow, half size, held still and leaned back to face the steep camera, bobs low in front of the doorway (the desktop's top bars cover the gate's upper half) with its row of gold tiles running from the player to it (`Fx/DoorPointer`, owner 2026-11-13: "the same way theres an arrow in the lobby pointing to eggs, there should be an arrow pointing to the open door"); it goes when that player reaches the door or the gate shuts. Both pointers are one drawing, `Fx/GoldPointer`, placed by `Util/WayPointer` (`tests/WayPointer.spec`). **The next room is built while this one is played** (`Arena.prepare`, `Balance.Run.prepareDelay`, owner 2026-10-26), parked in `ReplicatedStorage.NextArena` and swapped in at the door; the client preloads it and its enemies (`Fx/RoomPreload`), and every card image from the story on (`UI/Cards/CardPreload`, `DeviceTiers.warmCardImages`); `tests/Preload.spec`, numbers in `docs/PERFORMANCE.md`. Moonlit
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
- **No class bodies** (owner, 2026-11-07): the Tripo class bodies (PR #499, #500) were
  removed; every player wears their own Roblox avatar. The class screen's look is still
  saved but changes nothing in game.
- **No class armour either** (owner, 2026-11-13: "scrap the models on the player entirely"): the class armour sets
  (Outfit C, #555, #563, #564) were taken out the day after they shipped. Every player wears
  their own avatar everywhere, in a run and on the Gear portrait; only the weapon in hand says
  the class (the class select cards show drawn heroes since 2026-11-13, pictures only). Their code, models and tools are in git history.
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
  per area, owner: "codex needs to draw a chest per area"). BACK TO LOBBY sits under
  the main button on both (owner, 2026-11-08; `Remotes.RunLobby`). Since 2026-11-12 the chest
  row is only built when the run paid a chest, an egg or a boss item, and the tutorial's
  Victory says CONTINUE, since it leads to the lobby (`Util/EndScreenRules`).
  **Neither panel is white** (owner, 2026-11-14: "the victory and defeat screens also shouldnt
  have a white background"): Victory's is sea blue, Defeat's slate, as on the sheets, in Lagoon's
  colours (`Config/EndScreenTheme`; `tests/UiPalette.spec` fails a pale panel). No word sits on a
  panel's own fill, so a new line of text there needs a plate under it.
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
  shots (since 2026-11-08 each shooter has its own, `Config/EnemyShots`, drawn by
  `Fx/ProjectileRenderer`; a new shooter brings a new look, `tests/EnemyShots.spec`). Presentation only.
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
(`Fx/SwingTrail`, `Shared/Combat/SwingSweep`). **Blade cleaves** (owner,
2026-11-19, direction A: "the slash that it leaves behind"): a blade with a
`look` in `Config/WeaponFx.cleaves` draws its own card from the owner-approved
Blade Cleaves page instead of the ribbon. `Fx/Cleaves/Canvas` is the page's
canvas code ported (same maths, same seeded hash, page pixels, `GEO.s` to a
stud) writing a draw list; each area's module (`Glade`, ...) is its cards'
`ST` code line for line; `Fx/Cleaves/Painter` lays the list flat over the
ground as pooled Beams (built-in textures for glows, sparkles, rings; 900
beams at most on a strong device, a share on weaker); `Fx/Cleaves/Play` runs
each blow on its own clock from the real `SwingBox` shape, so the cards
still grow the cleave. Presentation only, local. `tests/BladeCleaves.spec`
pins the hash to the page's, each cleave to the ground it hits, the glow of
a Legendary or Mythic, and its end. Offline check without Studio:
`cleave-tools/dump.luau` + `draw.py` in the notes folder draw any area's
cards from the ported code. **Projectile shots** (owner, 2026-11-19, "build
all 49"): a bow or staff with a card in `Config/WeaponFx.shotCards` flies
its own shot from the owner-approved Projectile Shots page
(https://claude.ai/artifact/T2EwHuQhKJosJ95wZSU14n) instead of its `shots`
look. `Fx/ProjectileRenderer` still flies the shot (the server's flight,
its pierce, bounces and homing) but builds it unseen and hands it to
`Fx/Shots/Play`, which samples where it is each frame and runs its card's
code (`Fx/Shots/<Area>`, line for line on `Fx/Shots/Kit`, the page's flight
helpers on the cleaves' `Canvas`): `f` the flight, `h` each hit (through an
enemy, stopped in one or a wall, or out of reach), all laid flat in the
flight plane by `Fx/Cleaves/Painter` in a pool of its own (`Painter.pool`,
700 beams on a strong device). The lowest tier draws no tails and sheds
nothing; past 60% of the pool older shots draw head and hits only, and past
the whole pool a shot shows its flight part, lit in its weapon's colour. Page x
is world X and page y world Z (the camera looks toward -Z), so the cards'
up is the screen's up. `tests/ProjectileShots.spec` holds every shot to its
flight and hits, the glow of a Legendary or Mythic and the beam budget.
Offline check: `projectile-page/compare.py` in the notes folder draws the
page's frames beside the ported code's, card by card. Each weapon
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
wave 2 is designed and has its icons. **Every class has a ladder of four class upgrades, Rare to Mythic** (owner's pick C,
2026-11-13, `docs/CLASS-CARDS.md`): Ranger Sniper Shot, Split Shot, Rain of Arrows, Phoenix Arrow (and Wind Arrows;
Overdraw is benched, Sniper Shot took its place); Arcanist Mana Surge, Elemental Orbs, Arcane Turret, Black Hole (and
Frost Orb, Arcane Shield); Warden Shield Throw, Counter Strike, Blade Storm, Titan's Grip (and Sunder). The new ones are
drawn by `Fx/Upgrades/ClassCardFx`; the pools stay within a card of each other (`tests/ClassCards.spec`). Each class has one Mythic: Dual Bows,
**Meteor** (every 5th cast) and **Earthbreaker** (the dash ends in a slam
and erupting cracks), both resolved by `Combat/AreaStrikes`. They look as the
owner's mythic-fx.js draws them (`Fx/MythicFx`, `Balance.MythicFx`, budgeted
by `DeviceTiers.mythicFxShare`), and the staff plays the kit's Meteor cast
when the server counts one on the player (`Meteors` attribute).

**Thornwood's six cards** (owner, 2026-11-18: "Build the six new"; `docs/CLASS-CARDS.md`): Web Snare and
Thorn Burst (Ranger), Root Hold and Burr Blight (Arcanist), Boar Rush and Ruin Cracks (both melee classes,
on the combo's last blow). Data like any card; four ride a shot through `ClassUpgrades.dress` and
`ProjectileSystem` (`web`, `thorn`, `root`, `blight`), two land in `MeleeSystem.land`; numbers in
`Balance.Player.thornwood`, looks in `Fx/Upgrades/ThornwoodFx`, rules in `tests/ThornwoodCards.spec`.
Each will be a Thornwood Legendary's or Mythic's `innate`.

**The Assassin** (owner, 2026-11-15: "we need to create the assassin class now", yes to option A,
"twin daggers up close"; `Config/Classes.Assassin`): the fourth class, a second melee class on the
Warden's machinery. About two strikes a second, 0.75x a hit, 1.5x the Ranger's health (338), guarded mid-strike as the Warden is (without both it
did not get through 1-1 in Studio, 2026-11-16): a
slash from each hand in a 70 degree arc 8.5 out, then both daggers driven in for 1.5x in a small
circle. A slash shoves an enemy a third as far as a hit usually does (`swing.knock`, a share
`EnemyManager.damage` takes), the stab all the way: full shoves put everything out of the daggers'
own reach, and its phantom blades and shadows shove as lightly for the same reason. It holds the Splinter Daggers (`Config/Weapons.SplinterDaggers`, one model in each hand through `offhand`)
and 21 skins of them (2026-11-17: every pair a Tripo model of ONE dagger at 4,000 triangles and an 8K
texture, `assets/models/weapons/blocky/daggers`; Mossy Glade's five, Thornwood's five, the Drowned
Village's five, Bogheart's five and the Golden Daggers of class level 10), each with its own cleave and,
Legendary and Mythic, an effect no other of its weapons carries (`tests/WeaponFx.spec`); they come from a
DAGGER chest (`Config/Shop.chests`, four now), Thornwood's excepted (not stocked). The Splinter Daggers, whose kit is **written as numbers**,
not keyed in Claude Design (`assets/models/weapons/splinter_daggers_r15/make_kit.py` draws every key
as a stick figure to look the poses over outside Studio; a Design kit can replace its JSON whole).
Its nine sounds (three strikes, the dash's cut, five cards) are one sprite, the owner's picks of round 33 (`assassin_sprite_r33.mp3`, 2026-11-17).
**Its skill is Shadow Dash** (`Classes.dash`, a class's own dash): back in 2.5 s where every other
class waits 4 (`DashCut.cooldown`, the same number for the client's bar and the server's check), it
cuts every enemy within 2.5 studs of the ground it covered for 1.5x a strike, and nothing can hurt
the Assassin from its start until 0.2 s after it ends. The dash is still the client's movement,
and over in an eighth of a second, so the server never sees most of it in time (3.2 studs of 6,
measured): the client sends which way it dashed with `DashStarted` and the server draws the line
itself, a dash long from where the character stands, or as far as a wall or cover lets it
(`Shared/Combat/DashCut`, `tests/DashCut.spec`; the way is all a client says, `DashCut.heading`
makes it a flat direction or nothing), and lands each cut exactly as a swing's blow
lands (`MeleeSystem.strike`: crit, Blaze, Soul Chain, Execute, Sunder), pushing each enemy out from
the line. Drawn by `Fx/Upgrades/AssassinFx`: violet blocks left behind the dasher, a bright slash
along the cut and a cross of cuts on each enemy struck; the kit's `Dash` clip sweeps both blades.
**Its cards** (`docs/CLASS-CARDS.md`; `Config/Abilities`, group `dagger`; numbers in
`Balance.Player.assassin`): ten of its own, Twin Fangs, Backstab, Quickstep, Serrated Edge, Bleed,
Poison Trail, Fan of Knives, Death Mark, Phantom Blades and its Mythic Thousand Cuts, and five
blade cards that are true of any swing, shared with the Warden (Quick Hands, Cleave, Long Reach,
Execute, Sunder), so its pool is 24 like the others'. Backstab (the enemy's own facing,
`EnemyManager.facing`), Serrated Edge and Bleed land in the strike itself; Poison Trail, Fan of
Knives, Death Mark, Phantom Blades and Thousand Cuts are `Combat/AssassinUpgrades`, beside
`ClassUpgrades`; Quickstep moves the server's dash clock back on a kill and tells the client's
(`DashRefund`, `Dash.refund`). Their arithmetic is `Shared/Combat/AssassinRules`
(`tests/AssassinCards.spec`, which also weighs each against the daggers' own damage); the phantom
blades are placed from the server's clock, so every client draws them where the server cuts.
**`Util/ClassList` is the one list of classes**, read off the class select cards: `all()` is every
class there is, `open()` those a player can choose (a card that is not `locked`). The server's
CHOOSE and class switch, class levels, the starter weapons in a new save, what can be owned
(`ShopRules.catalog`), the Dex and the loading tips (`ShopRules.shown`) and Gear's CLASSES tab all
read it, so opening a class is one word on its card. A class whose card is `locked` is played in
Studio only (the C key cycles `ClassList.all()`): no player can choose it, level it or own its
weapons, and nothing about it shows on a screen. **The Assassin's card opened 2026-11-15**: its
hooded hero in colour (Codex, `class_select_b/assassin.sh`; violet, cut by `cut.py`'s
`key_outside`, which takes only the magenta joined to the picture's edge), FAST DAGGERS, A DASH
THAT CUTS, and its bars, which shrank the others' SPEED bars since each is a share of the best.
`SaveSchema` v23 gives every save the Splinter Daggers; a goal WIN AS THE ASSASSIN joined the three;
it levels like the others but has no golden weapon yet (`ClassLevels.waiting`: level 10 gives it
the day one is added); Starfall still asks for floor 50 as the first three classes only. **It has
no DAGGER chest and no skins yet**: the only daggers in the game are its own (the five Mossy Glade
skins are modelled and pictured but not imported; Thornwood and the Drowned Village have none
designed), so its level 3 crate pays gems instead. The Dex's weapon pages are laid out for 24
(`Dex.pageMost`).

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
`SaveSchema.spec` case. Version 2 (2026-10-26) adds `levelsBeaten` (by `StageConfig.level`); a
version 1 profile that had beaten King Bloblin counts 1-1 as beaten.

**Payouts land where the player is looking** (owner's review, 2026-11-11, items 5, 9, 10): the
first clear of a level (`Wallet.beatLevel` returns true) gives its area's egg free
(`Config/Economy.firstClearEgg`, rolled by `Hatchery.grantFree` in `RoomController.complete`); it
fills Victory's chest slot and opens with the hatchery's reveal over the end screen
(`RunSummary.egg`). The boss item shows there too (`RunSummary.item`). Every coin paid is told to
the client (`Remotes.CoinsGained(amount, position?)`): `Fx/CoinDrops` pops a kill's coins out of
the kill and flies them to the GuiObject tagged `CoinCounter` (the top of the screen without one)
and keeps the client-only `CoinsShown` Player attribute, the wallet less the coins in the air,
for a run coin counter to show. Victory's plate says YOU CAN HATCH AN EGG! when the server says the
coins buy an open egg (`RunSummary.canHatch`, `Hatchery.canHatch`); Defeat's is a line on getting
stronger. The portal's level card lists what a level pays (`PortalScreen` `rewardsOf`). Only stages
with a `level` have a first clear (Mossy Glade's ten); `tests/Payouts.spec`.

**Reasons to come back** (owner-approved loop review, 2026-11-11; `Config/Rewards`, `Util/RewardRules`,
`Server/Data/Rewards`, `UI/RewardsScreen`): a 7-day login calendar (a missed day does not reset it), three
daily quests dealt one per group from the day's number, and a one-time starter list (beat 1-1, hatch, equip
a pet, open a crate), paying mostly gems so an Epic is about six days of play; the arithmetic is at the top
of the config and `tests/RewardRules.spec` pins its shape. The client only asks (`Remotes.RewardClaim`, a
kind and a key): quest progress is counted by the server from its own events (`Rewards.note(player, kind,
amount)` in the run, the hatchery and the shop; anything new that should count calls it), the starter list
is read from the saved profile, and the day is the server's clock, published as the Player's `RewardDay`.
The screen opens by itself only once the server says the player stands in the lobby (the Player's `Arrived`,
`RunSession.ARRIVED`): `InLobby` is also true under the title and just before the tutorial starts.
Save version 11 holds it (`rewards`). Each new Dex entry pays `Rewards.dexGems` once ever (`Data/DexPay`,
called by `Wallet.grantWeapon`, `grantPet` and `meetEnemy`), with a toast. Each lobby leaderboard has a
"YOU: #N" row (`Run/BoardYou`, `Util/BoardRank`, `UI/BoardYou`; `docs/LEADERBOARD.md`). Studio:
`Remotes.DebugDay:FireServer(n)` moves the player's reward day on.

**The weekly Endless tournament** (owner, 2026-11-18; `Config/Tournament`, `Util/TournamentRules`, `Run/WeeklyTournament`, `UI/TournamentPrize`, `tests/TournamentRules.spec`; save version 26; `docs/LEADERBOARD.md`). A third lobby board, THIS WEEK'S DELVERS, past DEEPEST DELVERS: this week's top ten (floor and time), the YOU row and a "RESETS IN 2D 4H" countdown. The week is Monday 00:00 UTC to the next; the store is one OrderedDataStore, `EndlessWeekly_v1`, scoped by the week's Monday. **Only server-decided floors count**: `RoomController.clearedFloor` records each floor with the seconds since the run began, and the score is one whole number, floor first and the faster time breaking a tie (level to the tenth: the better place is shared). Written only when it improves, budgeted as the other boards. Each week played is noted in the save (`tournamentWeeks`); once the week and a 300 s grace are over it is paid and taken out of the save in one step (`Wallet.payTournament`), on the next join or at once for a player in the game; a store that cannot be read makes the week wait, never pay a guessed place. The owner's yes to the table (2026-11-18) added the themed sets' weapons ("the new models ... as skins"): #1 picks two and #2-10 one, any set weapon of any set and class not owned, never a reward weapon (`WeaponStats.earned`: the Nebula, Petalfall and Wishcutter Blades, shown as REWARD tiles), on the prize panel (`Remotes.TournamentPick`, checked by `Wallet.pickTournamentWeapon`; owed picks are `tournamentPicks` and are offered again on join; owning all of them pays 300 gems a pick). Nothing rolled, so no random items. A week's winner gets ENDLESS CHAMPION over the name tag for good (`tournamentWins`, the Player's `TournamentWins`). The rules take the time as a number, so the spec runs a week on a fake clock; in Studio, `Remotes.DebugTournament:FireServer("shift")` moves the tournament's clock past the next reset, `("floor", f, s)` records a floor and `("rival", n)` fills the board.

**Victory's three chests, the win streak and the friend bonus** (owner, 2026-11-14; `Config/Rewards.victory`, `streak`, `friendCoins`). *Chests* (`Util/VictoryChestRules`, `Run/VictoryChests`, `UI/VictoryChests`, `tests/VictoryChests.spec`): every campaign level won (not the tutorial, not Endless) rolls three chests **on the server, before the screen shows any**, and keeps them in memory; the summary says only that a pick is owed (`summary.streak`). The client sends which chest, 1 to 3 (`Remotes.VictoryChest`); the offer is taken away before anything is given, then the answer says what was in all three. Each chest is rolled by itself: 62% coins (half to one and a half of the area's clear bonus), 20% 2 to 4 gems, 9% the area's egg, 9% the area's weapon crate (coins instead where the area has none for the class). An offer never picked is dropped; nothing is saved. Victory's buttons wait for the pick. *Win streak* (`Util/RunBonus`, `tests/RunBonus.spec`; `SaveSchema.winStreak`, version 19): each level won in a row adds 10% to the next level's kill and clear coins, up to 50%. **It is on the line from the start**: `Wallet.riskStreak` takes it out of the save as a level starts (`RoomController`'s `startStage`) and `Wallet.bankStreak` writes it back one longer only on the win, so a defeat, leaving the run and leaving the game all end it and quitting keeps nothing. *Friend bonus*: a party of two or more pays 20% more coins (the locked `Coop.partySize()`). All three add to the passes' scale in `RunSession.payEarned`; nothing multiplies. A level's start says the bonuses on the rewards' toast (`Rewards.say`).

**The season pass** (owner, 2026-11-18: "yes all of these create them", tier list "Yes, build it"; `Config/Season`, `Util/SeasonRules`, `Server/Data/Season`, `UI/SeasonTab`, `tests/Season.spec`, `docs/SEASON.md`; save version 28 `season`, `titles`, `title`). A season is a **calendar month by the server's clock, UTC** (keyed "YYYY-MM", dates worked out from the seconds), themed on a themed weapon set; **Season 1 is Starwish, December 2026**, and a month with no entry has none. **Season XP is the server's**: a campaign room cleared 10, a level won 50, an Endless floor 10, a daily quest claimed 100, through `Data/Rewards.note` and the quests' claims (`Rewards.onNote`, set by `Data/Season`); 500 XP a tier, 30 tiers. The **free track** pays coins, gems, eggs or crates every tier (eggs and crates the best open, by `Data/QuestChest`); the **premium track** is **fixed things only, never random** (gems, coins, the season's Legendary trail at tier 15, `Config/Trails` `earn = "Season"`, and its title at tier 30, drawn over the name tag by `UI/NameTags` from the Player's `SeasonTitle`). CLAIM sends `Remotes.SeasonClaim(track, tier)` or `("all")`, one bit a tier, marked and paid in one step. **At the month's end everything reached and not claimed is claimed for the player** (both tracks with premium), on join or within 30 s for anyone playing (`SeasonRules.rollover`); XP and premium do not carry over. **Premium is the "SeasonPass" developer product, 299 Robux** (`Config/RobuxStore`, `season = true`, never on the STORE's shelves), prompted by the server only while a season runs and premium is not bought for it, granted once per receipt by `Data/Purchases` (`Season.grantPremium`); created on the Creator Dashboard 2026-11-19 (id 3733524465). The SEASON tab is REWARDS' fifth (narrower tabs upright, `HatchStand.tabWidth`). Studio: `Remotes.DebugSeason:FireServer(days)` moves the player's season clock on (the Player's `SeasonShift`).

**The gift box and the Dex pages' chests** (owner, 2026-11-14; `Config/Rewards.gift` and `pages`, `tests/Gifts.spec`; save version 20). *Gift box* (`Util/GiftRules`, `profile.gift`): every three campaign levels won fills a gift, an egg one time and a weapon crate the next, opened on the REWARDS screen's DAILY tab (`Remotes.RewardClaim("gift")`, given as the quests' chest is). **No clock in it**: it holds three gifts and counts no win past full; `Data/Rewards.note` counts the win and says GIFT READY. *Dex pages* (`Util/PageRules`, `profile.dexChests`): a chest for each finished page of the Dex (a book's page is an area, `Util/DexBook`), once each, on the GOALS tab after the goals with GO to the Dex Hall (`RewardClaim("page", "Book:Area")`). An area's enemies page pays an egg and a crate; its pets page and its weapons page **are the collection sets** and pay five eggs or five crates and 75 gems. Judged from the save with the Dex's own reading, so a new area's pages appear by themselves once `Config/Dex.areas` has its look. CLAIM ALL takes these too. **A pets page asks only for the pets some egg holds** (`PageRules`' `hatchable`): the Dex lists pets with no egg yet, and a set that asked for those could never be finished; a page with none to hatch has no chest.

**Playtime gifts, the Premium perk and invite rewards** (owner, 2026-11-18: "yes all of these create them"; `docs/PLAYTIME-PREMIUM-INVITES.md`, `Config/Rewards.playtime`, `premium`, `invite`; save version 27). *Playtime gifts* (`Util/PlaytimeRules`, `tests/Playtime.spec`): six gifts open 5, 10, 20, 30, 45 and 60 minutes into a session (coins, then gems, then an egg, the hour's an egg, a crate and gems), claimed on REWARDS' fourth tab, GIFTS (`RewardClaim("playtime", n)`), and by CLAIM ALL; the tab, the lobby badge and CLAIM ALL count them (`RewardRules.readyBy`/`ready`/`claimAll` take the server's time). **The server's clock decides, and the session is saved** (`profile.playtime`), because every run is on a server of its own: a server goes on with the session if the player was held within `gap` (10 min) and starts a new one otherwise; `Data/Rewards` stamps it every 5 s. The lobby's gift button (`UI/PlaytimeButton`, under REWARDS and BADGES) has a ring of blocks filling to the next gift and GIFT READY! pulsing. *Premium* (`Util/PremiumRules`, `Data/Premium`): `Player.MembershipType` read on the server; +10% coins added in `RunSession.payEarned` beside VIP's (`RunBonus.scale`'s fifth argument, nothing multiplies) and a free egg once a reward day, paid as the player reaches a lobby (`profile.premiumDay`); Roblox's own Premium mark on the name tag; non-members see GET PREMIUM (`PromptPremiumPurchase`) on the GIFTS tab. *Invites* (`Util/InviteRules`, `Data/Invites`, `UI/InvitePrompt`): invites carry launch data `invite:<user id>`; a friend's first join ever (`PlayerData.isNew`) writes who invited them (`ReferredByPlayerId` first) into their save, and as they first reach a lobby, if Roblox says the two are friends, they get the welcome and go on the inviter's waiting list (DataStore `Invites`, one key per inviter); the inviter is paid once a friend, at most `cap` (3) a reward day. Studio: `Remotes.DebugPlaytime(n)`, `DebugPremium(on)`, `DebugInvite(userId)`.

**Level stars** (owner, 2026-11-14; `Config/Rewards.stars`, `Util/StarRules`, `tests/Stars.spec`; save version 21). Every campaign level has three stars: the win, finishing with more than half health, and finishing inside its time (25 s a room or 20 s a wave; a first guess to tune from timed clears). **The server decides them** as the level is won (`RoomController` `complete`, from the health it holds and the time it measured; `Wallet.addStars`), and a star once earned is kept: a level's stars are a number, one bit a star, in `profile.levelStars`, so two different wins can make three. A level beaten before this holds its first star (the migration gives it). They show under each open level's button (`UI/PortalScreen` `levelButtons`) and, with what each asks, under Victory's three chests (`summary.stars`). An area's stars open chests at 10, 20 and 30 (`profile.starChests`, `RewardClaim("stars", "Area:Stars")`), each area's next one listed on REWARDS > GOALS with GO to the portal; only the chests an area has levels enough for exist, so a one-level area has none. CLAIM ALL takes them too.

**Hard mode** (owner, 2026-11-18: "yes all of these create them", the numbers and rewards the owner's picks; `Util/HardRules`, `Balance.Hard`, `Config/Rewards.hard`, `tests/HardRules.spec`; save version 24). **Once an area's boss is beaten** its level screen (`UI/PortalScreen`, from its portal or PLAY's area list) has NORMAL / HARD tabs (`Chunky.tab`); on HARD the levels are red and open in order over `profile.hardBeaten` (`HardRules.isOpen`, `LevelUnlocks` over the hard wins), and PLAY sends `Remotes.PortalStart(index, level, true)`. **The server decides**: `Run/Lobby.hardOpen` refuses a hard level whose area boss stands or whose hard level before it is not won, from the saved profile, at the start, again on a party's run server (teleport data `hard`, the leader's own save) and for each member who would come along (`Lobby.startFor`). The run is on hard while the Workspace's `Hard` attribute is true (`RoomController.beginStage(stage, hard)`, read through `CurrentStage.hard`; dropped in the lobby). **Harder**: every enemy's health 2.5x and damage 1.8x (`Balance.Hard`, bosses too) on top of the level's numbers and its ramp, co-op's scaling on top as on normal (`EnemyManager.difficulty`); every fight without a boss has one elite (`HardRules.eliteSlot`, the middle spawn), 2.5x its health, attribute `HardElite`, a gold ELITE plate over it from arrival (`Fx/EnemyHealthBars`). **Better paid**: kill and clear coins +100% (`RunBonus.hard`, added like the streak and friend bonus; the level's start says HARD MODE: +100% COINS), 10 gems on a level's first hard clear and 30 on an area's last (`HardRules.gems`, `Wallet.beatHard`, said on the toast and counted in Victory's gems), and an area's last level won on hard wears its **name-tag frame**: a plate behind the name in the area's portal tint with the kit's outline, the furthest area's, seen by everyone (`HardRules.frame`, the Player's `HardFrame`, set in `Wallet`'s `changed`/`send`; `UI/NameTags`). No free egg on hard (the normal first clear's). **No stars of its own** (`HardRules.starLevel`): an area's 30 stars and their chests are earned on normal and a second set would double them, so a hard win fills the level's normal stars. NEXT LEVEL on hard is the area's next level on hard, and an area's last is won into the lobby (`HardRules.nextIndex`, `EndScreenRules.goesOn(stage, hard)`); the end screen's tab says HARD 1-3 (`summary.hard`). Victory's chests, the streak, quests and the gift box count a hard win as any win. `docs/DIFFICULTY.md`, "Hard mode".
**Codes, the favourite prompt and hatch shout-outs** (owner, 2026-11-18: "yes all of these create them"; `docs/RETENTION-HOOKS.md`; save version 30). *Codes*: a CODES row in the SETTINGS panel; the list is **server-only** (`src/server/Data/CodeList.luau`, never in `src/shared`; `tests/CodeRules.spec` fails if a CodeList replicates), each code a prize (coins, gems, eggs, crates), an optional last day and an optional like goal (`likes`: the code does not exist until the game has that many; the count is the ConfigService key `likes` the owner sets on the Creator Hub, since a server cannot read its own likes; `Data/LikeGoal`); once a player (`profile.codesUsed`, saved before paying), four tries then one per 15 s (`Config/Codes.tries`), rules in `Util/CodeRules`, server in `Data/Codes`. *Favourite*: Roblox's `PromptSetFavorite` with the place id, once ever, after a boss win (`Wallet.beatBoss` -> `Data/Favourite` sets `FavouriteOwed`; `UI/FavouritePrompt` waits for a clear lobby; `profile.favouriteAsked`); **never a reward for it**. *Shout-outs*: every roll that makes a pet or a crate weapon calls `Data/Shoutouts.rolled` after the grant (Hatchery, Shop, EndlessPrizes.crates); a Legendary or Mythic is a banner in the rarity's colour (`UI/Shoutout`, over the station screens, waiting on the player's own reveal) and a chat line for everyone in the server; a Mythic also goes to other servers through MessagingService as a chat line only, gapped both ways, never from Studio. Rules in `Util/ShoutoutRules`, numbers in `Config/Shoutouts`.

**Goals** (`Config/Goals`, `Util/GoalRules`, `tests/Goals.spec`; owner, 2026-11-14): twenty lifetime achievements that never reset, each in three steps (bronze, silver, gold), on the REWARDS screen's GOALS tab under the starter steps, in a list that scrolls; a finished goal leaves the list. They pay **mostly coins, eggs and crates and only a little gems** (a gold step's 20), so the store keeps its price: the spec holds the total under 500 gems. A goal is judged from the save alone: a lifetime counter in `SaveSchema.stats` (version 18; `Goals.counted`), kept by `Data/Rewards.note` as things really happen (so anything new that should count only has to call `Rewards.note`), or something the save already holds (pets owned, the deepest Endless floor, the Dex). Counters began at 0 for everyone on the day they shipped; nothing was invented for old players. `Remotes.RewardClaim("goal", key)` claims the next step, one a press, in order (`profile.goalsClaimed`); its eggs and crates are the best open to the player, given free by `Data/QuestChest` with their reveals (gems instead where there is nothing to give). CLAIM ALL takes every step a goal has reached. To add a goal: an entry in `Goals.goals`, and for a new counter its name in `Goals.counted` and a `Rewards.note` where it happens; no save change.
**The screen has three tabs since 2026-11-14** (owner: "the quests tab is too cluttered", "the quests need
to be clearer", "there should be more rewards"): DAILY (the calendar), QUESTS (today's three and the bonus
chest) and GOALS (the starter steps), each wearing the count of what waits on it (`RewardRules.readyBy`); a fourth,
GIFTS (the playtime gifts, Premium and inviting a friend), since 2026-11-18, the tabs narrowing to fit an upright phone
(`HatchStand.tabWidth`).
A row is a picture of what to do, the words, the bar with its numbers on it, the pay, and one button:
CLAIM, GO or DONE. **GO** closes the screen and stands a gold arrow over where the quest is done
(`Fx/QuestPointer`, `Rewards.places`: a station, or the first portal); it starts nothing for the player.
**Short-attention fixes from the run-through** (2026-11-15). A card is applied `CardTheme.timing.pickApplyAt`
(0.7 s) after it is taken and its celebration, drawn `celebrateLength` (1.56 s) long, plays at that pace
(`leaving.speed` in `UI/Cards/DraftScreen`); a Mythic keeps the full length. `Util/PlayPortal.next` is the
level PLAY's screen starts in one press (CONTINUE, `UI/AreaScreen`): the level its own screen would pick in
the area next up, never a mode (`tests/PlayPortal.spec`). REWARDS opens by itself only for a player with a
level won (`UI/RewardsScreen`). `StageConfig.hitGrace` (0.6 s on the tutorial and 1-1 to 1-3) is the time
after a hit lands in which no other can (`RunSession.applyDamage`, off `lastHurtAt`).

**An encounter room keeps its door line clear** (`Balance.Rooms`, `Balance.encounterLane`, 4 studs; the
run-through, 2026-11-14: a log behind the Angel stopped a player walking straight up): cover within the
lane of the line from the spawn to the door is left out of an Angel room, with its scenery, where
`Balance.Rooms` is put together, so the room tools need no change (`tests/MossyLevels.spec`). The Angel
stands beside the line (`RoomController`), on the side with no cover near her. **Her stat is the draft's
own** (`Loadout.openAngel`): from `candidates` (the player's class, not benched, not banned), drawn by
rarity's weight. **Endless pays `Balance.Endless.floorCoins` (30) a floor cleared** through
`RunSession.payEarned`, and its end screen is its own (`summary.endless`: floor, best, new best,
Soulstones banked; `EndScreenRules.levelTab`, `floorLabel`, `defeatLine`, `tests/EndScreenRules.spec`).
DEFEAT's line is `EndScreenRules.defeatLine`: merge, not hatch, when `summary.petsFull`.

**CLAIM ALL** (`RewardClaim` "all", `RewardRules.claimAll`) takes **everything that waits** in one press (since the 2026-11-14 run-through: "CLAIM ALL does not claim all, and the counts disagree"): the calendar, the quests and then their chest, the starter steps, the gift box, every step a goal has reached, the star chests and the Dex pages' chests. Its number is the lobby badge's (`RewardRules.owedAll` is `ready`). Their eggs and crates are opened together by `Data/QuestChest` and revealed one after the other. **A player who has beaten no boss is not dealt BEAT A BOSS** (`RewardRules.questsFor(day, r)`, `rewards.bossMet`, save version 22): they get that group's next quest, so the chest for all three is always in reach. **The bonus chest** (`Rewards.bonus`, `RewardClaim` "bonus"): claim all three of the
day's quests and it opens, free, an egg one day and a weapon crate the next (`RewardRules.bonusKind`), the
best open to the player, given by `Data/QuestChest` and revealed as a hatch or a crate is
(`Remotes.QuestChest`); save version 17 keeps the day it was opened (`rewards.bonusDay`). **A quest says
how it is going as it happens**: `RewardRules.note` returns the quests that just passed half or reached
their goal, and `Data/Rewards` sends a line for each ("QUEST: DEFEAT 50 ENEMIES 25/50", "QUEST DONE! ...")
on the reward toast, which draws no diamond for a line that pays nothing.

**Experience notifications** (owner, 2026-11-18: "yes all of these create them"; `docs/NOTIFICATIONS.md`,
`Config/Notifications`, rules in `Util/NotifyRules`, save version 25 `notify`): Roblox's opt-in pings. **Built
and switched off: nothing is sent until the owner's steps in that doc are done and they say yes** (`send`,
and each kind's `messageId`, the notification string's Asset ID). The question, GET A PING? (`UI/NotifyPrompt`),
is live: never in a first session, only after a daily reward is claimed (`Rewards.dailyClaimed`) and once the
lobby is quiet with REWARDS put away; Roblox's own prompt only behind YES; NOT NOW waits 3 days, three of them
and never again. As a YES player leaves (`PlayerData.onLeaving`), `Data/Notify` plans at most three messages
(daily reward ready, gift box full, and the event, season and set rotation through `Notify.upcoming(kind,
provider)`: the weekend and the rotation are hooked from `Util/LiveBoosts` and `Util/SetRotation`, the season
hooks itself), one per 20 hours, in the player's evening, none after 14 days away;
the plan waits in a MemoryStore sorted map every server polls (`Data/NotifyQueue`, claimed before it is sent),
and the one Open Cloud call is `Data/NotifySender`, its API key the experience secret `NotifyApiKey`, never in
the repo. `tests/NotifyRules.spec`, `NotifySender.spec` (a stub), `NotifyQueue.spec` (a table for MemoryStore).
Studio never sends (no secrets in a local playtest); `Remotes.DebugNotifyAsk` shows the question there.

**Boss badges** (owner, 2026-11-12: "a blocky circular icon ... for each boss ... like how they do in pokemon
with gym badges"; `Config/BossBadges`, `UI/BadgeCase`): one badge per area boss, the boss's face on a gold-rimmed
medal in the area's colour (Codex's version A, which the owner picked; `assets/concepts/blocky/ui/badges/`, cut by
`assets/ui/badges/cutout.py`). Earned the first time the boss falls, which is `profile.bossesBeaten` and nothing
new; the BADGES button under REWARDS opens the case, an unearned badge dimmed, its boss just showing. A new area's
boss needs its badge drawn from the same prompt: `tests/BossBadges.spec` fails until every area with a boss has one.
The case opens like one (owner, 2026-11-13): the shut lid folds up at its hinge and its velvet inside rises above
the tray with the count on a gold plate. A boss's first win pops its badge up (`Util/BadgeRules.fromWin`): read off
the won run's summary (`item`), never off the profile changing, since Studio's test unlock marks bosses beaten in
the lobby; the case waits for the lobby to be clear (no station, portal, cutscene, story beat or end screen), opens
by itself reading NEW BADGE!, and the badge drops into its slot with sparks and `reveal_rare`.

**The lobby's layout is in plan studs** (owner, 2026-11-12: "a little bigger and more spread out"):
every place on the courtyard in `Config/Lobby` goes through `plan(x, z)`, which multiplies it by
`spread` (1.3); sizes never do. Write a new lobby position as `plan(...)`, never a bare Vector2, and
work out anything that must meet the terrace from `terrace`/`rowDepth`/`terraceAcross` instead
(the outline's terrace corners do). Everything else, including the station screens' reach and the
camera, reads the config, so `spread` alone resizes the lobby. `docs/LOBBY.md`, "Spread out".

**Portals open a screen; the lobby sprints and jumps** (owner, 2026-10-26): walking into a lit
portal opens `UI/PortalScreen` (the area, its levels from `Config/Lobby.portals[i].levels`, START;
Mossy Glade's ten as numbered buttons in two rows of five, locked ones dimmed under a lock, beaten
ones CLEARED), and only its PLAY starts the run, validated by the server against the area and the
levels the player has opened (`Remotes.PortalStart`, `Run/Lobby.levelOpen`, `Util/LaunchLocks`,
`Util/LevelUnlocks`, `tests/Lobby.spec`). Where the player stands does not gate the start; it decides
who comes along: a start in the portal's mouth takes whoever else stands there (`Lobby.startFor`,
`Run/Party`), one from the lobby's PLAY screen nobody from a portal (`Util/PlayPortal.alone`).
**Lobby parties** (owner, 2026-11-19: "make co-op work from the PLAY button too", "have there be a party
system where you can invite someone in the server"; `Util/PartyRules`, `Run/Parties`, `UI/PartyScreen`,
`UI/PartyAsk`, `tests/PartyRules.spec`, `docs/COOP.md` "Parties"): the teal PARTY button in the lobby's
right column opens a panel of the other players in the server, each with INVITE; the invited player gets
PARTY INVITE with ACCEPT and DECLINE (30 s; one invite out and one in at a time; the same pair waits 20 s
after a NO). A party is a leader and members up to `Coop.maxParty`, shown as a card of names under PARTY
and as `PartyLeader` on each Player; LEAVE is on the panel. **The leader's start, from PLAY or a portal,
takes every member** free in the lobby with the level open (on hard, open on hard), then the portal's mouth
as before (a player in another party never); a member who cannot come is told why
(`Remotes.PartyNews`), and **a member who starts a run without the whole party leaves it**. A party that
went whole is carried in the teleport's data (`groups`) to the run server and back, and forms again where
it lands only when every member is there and each one's data names the same party (data passes through
the client). The server owns all of it: the client sends only user ids and yes or no.
The level buttons are drawn in one place, `PortalScreen`'s `levelButtons` (one `node` each, which
returns the button's frame): a badge on a level goes there. In the lobby there is no dash:
Shift / gamepad X / the phone's SPRINT runs (`Config/Lobby.sprint`) and Space / A / JUMP jumps
(`RunSession.allowJump`, `Input/LobbyButtons`); a run still dashes and never jumps.

**The lobby HUD** (Fable's loop review item 3, owner 2026-11-11; `UI/LobbyHud`, `Config/LobbyHud`):
coin and gem pills pinned to the top, a PLAY button, and the fight HUD (health, skill tray, XP bar,
level) put away while `InLobby`. **PLAY opens a choice of area, then level** (owner, 2026-11-14: "when
the player clicks play it shouldnt just tp them instantly to the last portal they went to, there should
be a screen where they can choose the area and then the level"): `UI/AreaScreen` lists every area with a
portal (`Util/PlayPortal.areas`: the built areas, then Endless), each a card with its portal's vortex,
name, act, levels beaten and PLAY; the one to play next (`PlayPortal.pick`: the first open area with a
level not beaten, never Endless, never one still locked) is ringed in gold under NEXT UP, and a locked
one is grey under a padlock with what opens it and only shakes when pressed. An open card goes on to
that area's `UI/PortalScreen` (the same screen its portal opens, here with `< AREAS` to go back), whose
PLAY asks the server. The character is never moved, and nothing is asked of the server until then
(`tests/PlayPortal.spec`). `PortalScreen.isOpen()` is true through both steps, which is what the lobby's
HUD, REWARDS and BADGES wait on. On a touch layout
(upright, or a phone) PLAY and the station button are laid out in points, full width, 64 and 60 tall,
under the phone's JUMP (`tests/LobbyHud.spec`); a wide screen keeps the `[E]` prompt on the sheet.
Both stand on a `Chunky.pointSheet`. The chunky X takes presses over at least 48 points however
small its header draws it (`Chunky.close`).

**Empty hands in the lobby** (owner, 2026-10-25): the server holds no weapon while `InLobby`
(`Main.refreshWeapon`, `HeldWeapon.unequip`) and `Fx/WeaponPose` writes no pose there, so
Roblox's own animation has the arms; the weapon comes back as a run starts.

**The chunky UI** (owner, 2026-11-05: "WE NEED TO DO SEVERE WORK ON THE UI FOR EVERYTHING"; approved
mockups in `assets/concepts/ui_refs/mockups/`, top-game references and the audit beside them): `UI/Chunky`
is the kit (blue panel, gold ribbon title, red corner X, glossy lipped buttons, tabs, currency pills,
rarity tiles, pop-in), laid out in sheet pixels on 1920 x 1080 or, held upright, 1080 x 1920
(`Chunky.sheet`). `HatchStand.chrome` frames a station screen in it. Done: Hatchery, Blacksmith
(crates and store), Gear, Dex. **A Dex book is a page an area** (owner, 2026-11-12: "1 page for
each area with bigger icons on the right page ... themed to match the area"): `Util/DexBook`
`areas` / `inArea` make the pages (every entry has an `area`; a pet's is in `Config/Pets`), the
tiles are fitted as large as the page allows (at most `Dex.pageMost` an area), and
`Config/Dex.areas` is each area's look, sampled off its NEW ENEMY! sheet, whose scenery stands
behind the chosen entry. A new area needs an entry there. Anything pressable bounces
(`Chunky.press`, or a `Chunky.button`) and anything equippable or equipped gleams (`Chunky.gleam`,
owner, 2026-11-05: "the gleam on equippables, the bounce on click").

**The kit's shapes are the owner's major reference of 2026-11-11** ("use this as the major reference
image": a house-tycoon game's store screen; memory `ui-major-reference`), which replaced the royal-blue
panels: a panel with a thick outline, a striped header bar across its top with the title at its left
and a red hexagon X at its right (`Chunky.ribbon` and `Chunky.close` drawn after a `Chunky.panel` become
that header, whatever box they are given), striped buttons outlined in the dark shade of their own
colour (`Chunky.shade`), rarity tiles, currency pills.

**The kit's colours are Lagoon** (owner, 2026-11-12, of the reference's cream, brown and orange: "awful
bland colors. make it have nice soft colors but still have everything be readable", then, of three
palettes drawn with a contrast check, "Lagoon colors"): mint-white panels, deep-sea outlines, a sea-blue
header, leaf-green go (PLAY, EQUIP, CLAIM), a sunny main button with dark words, teal second and coral
station buttons, white words with a dark outline on anything coloured and `Chunky.ink` unstroked on a
panel, card, chip or pill. **`Config/UiPalette` is the one place a UI colour is written** (data only;
what a colour needs worked out, a contrast or the face for a colour that is not the kit's own, is
`Util/UiContrast`): `UI/Chunky`
and `UI/Kit` read it, and so do the end screens (`Config/EndScreenTheme`), the class cards
(`Config/ClassSelect`), the tutorial pop-ups (`Util/PromptText`), the loading tip (`Util/TipPlate`) and
the lobby's JUMP and SPRINT. A screen takes its colours from the kit, never from a hex of its own.
**Readable is a rule**: small words stand 4.5:1 on their ground and big ones 3:1, and
`tests/UiPalette.spec` holds every pair the kit draws (`UiContrast.pairs`) to it. What that needs, and must keep: a button's
face is lit only between its two listed colours and striped with a faint dark wash (a lighter top, a
white stripe or a gloss under the words drops white ones under 3:1); tabs are pale pieces with dark
words (`Chunky.tab` takes no colour); a tile's caption sits on a white chip; coin and gem amounts are
dark; words on a piece of any colour go through `Chunky.textOn` / `Chunky.face`, which picks white or
ink for it, and a plate is lit with `Chunky.light`; a coloured piece's frame is white under the
gradient that carries its colour (the two multiply). The loading tip stands on a white plate with a TIP
tag, not on the picture, three lines tall on an upright phone. `Chunky.navy` is the outline colour (`Chunky.edge`), kept under its old name.
**Effects are in the kit** (owner, the same day: "make sure there are effects as well"): every button
clicks, throws sparks (`Chunky.burst`) and bounces, gold ones carry a sweeping shine, `Chunky.twinkle`
sparkles what is selected or new, `Chunky.count` runs a number up. A screen laid out in screen points
rather than on the station canvas draws on `Chunky.pointSheet` (the run's MENU, the draft's phone tray,
settings, the Soulstone shop). **Not seen in Studio yet** (2026-11-11): the re-skin changes every chunky
screen at once and waits on a look.

**Every purchase plays a burst** (owner, 2026-11-14: "i also want a big ui effect to play whenever someone
purchases something"; `Config/PurchaseFx`, `Util/PurchaseRules`, `UI/PurchaseFx`, `tests/PurchaseRules.spec`).
The server says when, over `Remotes.Purchased`: `Data/Wallet.pay` sends it as it takes a price, and it is the
only place coins, gems and Soulstones are ever taken (a hatch, a crate, a store weapon, a bought trail, the
Soulstone shop), so **a new thing to buy gets the burst by paying through `Wallet.pay`** and a refused
purchase or a gift (a chest's free egg, a goal's crate) plays nothing. The Robux side sends its own: a
product's receipt once it is granted and saved (`Data/Purchases.afterGrant`, once per receipt) and a pass as
Roblox confirms it (`Data/Passes`). The burst is about a second: rings spread from the button pressed (the
last mouse or finger press, or the middle of the screen for Robux and a gamepad), the one coin or diamond
picture bursts out with sparks, a word pops over it, the price shows under the word, or drops out of the
wallet pill when one is on screen (`Chunky.wallet` marks its pills with `Holds`; the Hatchery and the
Blacksmith hide their own while a reveal is pending, so there it is under the word), and the `purchase`
sound and a shake. **Three sizes**: KA-CHING!, BIG BUY! at
2,500 coins, 400 gems or 400 Soulstones, MEGA BUY! for Robux and a Legendary bought outright. **What an egg or
a crate rolled never sizes it**: the burst plays before the reveal and would give the surprise away. Its
layer is over the reveal (185) and takes no input, so it holds nothing up. There is no reduced-effects
setting to follow; its sound follows the sound volume and its shake the vibration switch. **Seen in Studio
Play** (2026-11-14): a hatch, a crate, store weapons, a trail, the Soulstone shop and a made-up Robux
receipt each play it once; a Legendary without its boss items, a trail already held, a Soulstone egg with no
Soulstones and a receipt sent twice play nothing more. Not seen on a phone.

**Screens converted to the reference since** (2026-11-11, owner: "Yes, convert them"): **class select**
(`UI/ClassScreen`, `Config/ClassSelect`, `Util/ClassStats`; owner: "it looks too ai right now") is
**"option B"** since 2026-11-13 (owner: "I LIKE B BUT MAKE SURE THERE IS A CHOICE IN THERE TO SWITCH
GENDER AND ALSO MAKE SURE THE ASSASSIN CLASS IS VISIBLE BUT BLACKE DOUT", then "MAKE THE SWORD A
LITTLE BIGGER AND MAKE THE ASSASSIN MORE NOTICEABLE"; mock-ups and Codex art in
`assets/concepts/blocky/ui/class_select_b/`, cut by its `cut.py`): the CHOOSE YOUR CLASS plate over a
mint panel, four cards in a row (two by two on an upright phone), each a round medallion in the
class's colour holding Codex's head-and-shoulders portrait of its hero, the name on a coloured tag, the
pitch, and RANGE / POWER / SPEED bars with icons read off `Config/Classes` (`Util/ClassStats`: reach,
damage a hit, attacks a second, each a share of the best open class). The picked card wears a yellow
ring; a green CHOOSE is under the row. A BOY / GIRL switch at the panel's top right swaps every portrait
(pictures only) and is saved as the profile's `look`. The Assassin was visible but blacked out: a
silhouette with a violet rim and a padlock, empty bars, and it could not be chosen (until 2026-11-16, when it
opened: see The Assassin; the locked card's drawing stays for the next class shown before it is playable). The **Endless checkpoint**
is a chunky panel of coloured gift tiles. The **draft** keeps its cards and their dark stage (the
owner's card design) and has chunky REROLL / CHOOSE! on every layout. The **end screens** keep their
blocks and motion and take the kit's colours and rounded font (`Config/EndScreenTheme`, read from
`Config/UiPalette`). Still in
their own look: NEW ENEMY! (its pixel card is approved art) and the Studio sandbox menu.

**The run's top HUD** (`UI/RunBanner`, `Util/RunHudRules`, `Config/Hud` `top`; 2026-11-11): a thick XP
bar with the hero's level on a gold badge, the coin counter (`Fx/CoinDrops` flies kill coins to its
`CoinCounter`-tagged icon and counts `CoinsShown` up), the room counter with the stage's rooms as pips
(up to `maxPips`; more keep the counter and name the room), and a status line. On a phone the MENU is a
48-point pause icon at the top left (`UI/ControlMenu`) and the draft, held upright, gets a tray under
its panel with the selected card read out and REROLL / CHOOSE! 56 points tall (`Config/Hud`
`draftUpright`). All in screen points. **One tap or click takes a card** (2026-11-14, `CardTheme.timing.tapGuard`
0.35 s after it is dealt); under the upright tray the first tap reads it and a second takes it; CHOOSE! is
the gamepad's (and the tray's): the panel draws it for a gamepad only (owner, 2026-11-14: "Hide it";
`RunHudRules.draftChoose`), REROLL takes the middle when it is alone, and with neither the panel closes up.

**Settings** (`Config/Settings`, `Util/SettingsRules`, `Server/Data/Settings`, `client/Options`,
`UI/SettingsScreen`, save version 9): music and sound volume in steps and vibration on or off, kept in
the save, read on the client from Player attributes. `Fx/Haptics` shakes the device on a hit taken, a
dash and a level gained. The SETTINGS button is on the lobby's left edge.

**Launch locks** (`Config/Launch.locks`, **on** since 2026-11-19, the week before release: owner,
"make it playable as it will be when it is released", then "Yes, locks on"; `Util/LaunchLocks`): one
switch that makes every area after the first, its egg, and Endless wait on the boss before it
(`atLaunch` in `Config/Lobby` and `Config/Eggs`). Studio's `Config/Sandbox.testUnlock` still opens
areas for a Studio playtest; a live server never honours it. `tests/LaunchLocks.spec` holds both.

**Gear shows what is chosen, and what is grand** (owner, 2026-11-14: "when you click on the box in the
gear screen it should highlight so the player knows which box they are clicking. also it should feel
more grand to own a mythic, legendary or high merge tier"; the look approved in Studio the same day).
`Chunky.select` rings in gold the slot being chosen for (WEAPON on the weapons tab, TRAIL on trails, the
PET slot a pick goes into on pets) and the grid box last pressed. `Chunky.grand` draws an owned item by
`Util/GearGlory.rank` (`tests/GearGlory.spec`): rank 1 for a Legendary or tier A (turning rays and a
breathing glow behind the picture, sparkles), rank 2 for a Mythic or tier S (brighter and faster, stars
rising, the picture breathing; a Mythic's rays run round the rainbow). The greater of rarity and tier
counts, so a Common merged to S is as grand as a Mythic. `Chunky.tier`'s A and S badges shine and S
beats, wherever a tier badge is drawn. A grand item's card opens with a burst of sparks.
**A tier named on a button is its badge, not a bare letter** (owner, 2026-11-14: "where it says merge c
to b it should have the actual letter icons for c and b"): `Chunky.spell(button, colour, parts)` sets
words and `{ tier = "C" }` badges (`Chunky.badge`) in one row on a `Chunky.button`, as the item card's
MERGE button does in all three of its states.

**What goes on by itself** (2026-11-14, the kid playtest): a hatched pet goes into any empty slot open
to the player, rarest first, and never into one they filled (`EggRules.fill`, `Data/Hatchery`); a weapon
from a crate or the store that is strictly stronger than the one held, for the class played, goes in hand
(`ShopRules.upgrade`, `Data/Shop` `takeUp`). **A free crate is a crate** (2026-11-16, the every-class
run-through): every prize crate is rolled by `EndlessPrizes.crates` (a class level's, the quests' chest,
the gift box, a goal's, a star chest's, a Dex page's, Victory's, an Endless milestone's, the Soulstone
shop's), which counts it for OPEN A WEAPON CRATE (`Rewards.note`) and hands what came out to the same
`takeUp` (`EndlessPrizes.takeUp`, set by `Data/Shop`): in the lobby it is in hand at once, during a run
from the next card or the next run. Gear's plate reads ATK, PETS (the slotted pets' damage a
second, `Util/PetPower`, at their merge tier) and HP on one line and pops when ATK + PETS rises; MERGE
leaves the item's card up with its new tier. **A won fight cannot hurt**: as a room, wave or floor is
cleared every enemy shot goes, on the server and on every screen (`RoomController.step`,
`Remotes.ShotsParried` for the whole arena).

**Themed weapon sets** (owner, 2026-11-18: weapons "that are not area specific", in themed lines;
`Config/Shop.sets`, `Util/ShopRules`, `docs/WEAPONS-THEMED.md`, `tests/WeaponSets.spec`): one theme across
one weapon for every class, all of one rarity, belonging to no area. A set's weapon names its set in
`Config/WeaponStats` (`set`; its `area` is 1 and only its scale's), is in **no crate** (so no Endless
prize, victory chest or free crate gives one: they all ask `ShopRules.cratePool`), is sold for its set's
coins and gems (`ShopRules.price`), waits on no boss (`ShopRules.buyable`), and has a Dex page of its own
after every area's once its set is `stocked`. **Every set is an original design for this game**: only a
theme's broad genre, never another game's names, logos, characters or item looks, and no other game is
named in any player-facing text. Eight sets are in the game (2026-11-18): Neon Circuit, then Starwish, Tumbleweed, Splash Day, Coin-Op, Voidglass, Lantern Bloom and Cinderforge, 32 Legendaries on the Blacksmith's SETS tab. The seven after Neon Circuit live in one table, `assets/models/weapons/blocky/themed_sets/sets.py`, which writes their marked blocks in `Config/WeaponStats`, `WeaponFx`, `Dex` and `Shop`; edit it and rerun, never the blocks. A set's Dex page pays `Rewards.setPage` (crates, no gems). **The seven themed daggers carry effects of their own** (owner, 2026-11-18; `docs/CLASS-CARDS.md`, "The themed daggers' seven"): cards with `weaponOnly = true` in `Config/Abilities`, never dealt by a draft or an Angel and in no class's pool, each carried by exactly one weapon (`Combat/AssassinUpgrades`, `Fx/Upgrades/DaggerFx`, numbers in `Balance.Player.daggers`, `tests/ThemedDaggers.spec`). A weapon effect that would tip the class pools out of step is made this way, never `benched`.

**Reward picks** (owner, 2026-11-19: "make sure that the player has a choice BETWEEN THE MYTHICS AND LEGENDARIES FOR ALL CLASSES for the endless rewards and the battlepass", "the space and sakura ones"; `Util/RewardPickRules`, `UI/RewardPick`, `tests/RewardPicks.spec`; save version 29 `rewardPicks`). A reward that gives a themed set's weapon owes a **pick** of the whole set, one weapon for each class: Endless room 100 the Voidglass set (`Balance.Endless.milestones` `pick`; the Nebula Blade a Mythic, the bow, staff and daggers Legendary) and Season 1's premium tier 30 the Lantern Bloom set (`Config/Season` `picks`; the Petalfall Blade a Mythic). `Wallet.owePick` saves it by the reward's id ("Endless:100", "Season:1:premium") and the lobby's pick panel shows the set's four tiles with each class under its weapon, whenever one is owed and the player stands in the lobby (after class select and the tournament's panel; the X puts it off until the next return). **The server decides**: the client sends only the weapon (`Remotes.RewardPick`), and `Wallet.pickReward` gives it only if it belongs to an owed set and can be taken (`RewardPickRules.find`): a weapon held once that is held already cannot be, one that merges comes as another copy. A set with nothing left to take pays `Tournament.pickGems` gems instead. The free tier 30 still gives the Wishcutter Blade alone (`SeasonDef.weapons`).

**Class levels and the golden weapons** (owner, 2026-11-14: "class specific leveling ... when a player gets
to level 10 on a certain class, they should unlock a golden weapon"; `Config/ClassLevels`,
`Util/ClassLevelRules`, `UI/ClassLevelPlate`, `docs/WEAPONS-GOLDEN.md`, `tests/ClassLevels.spec`): each
class has its own lasting level, apart from the run's level (`Config/Progression`), saved as
`SaveSchema` v16 `classLevels` (level and the XP into it). **The server pays it as a run ends**, to the
class played: 10 XP for each room, wave or Endless floor cleared and 50 more for a win
(`RoomController` `noteClear` / `payClassXp`, `Wallet.addClassXp`); a loss or leaving still pays what was
cleared, the tutorial pays nothing, each place counts once, and no client reports any of it. 10 is the
top (3,750 XP, about 20 won runs); levels 2 to 9 give coins or gems, a free weapon crate for the class at 3 and a free egg at 5 (`ClassLevels.gifts`; opened by `RoomController`'s `openClassGifts` as the XP is paid and revealed on the end screen from `gain.prizes`, gems instead where there is none to give; level 7 waits for the class trails' designs); **level 10
gives the class's golden weapon** (Golden Bow, Golden Staff, Golden Blade): Legendary strength at area
1's scale, the one Legendary card of its class
no other weapon carries (Multishot, Homing Orbs, Battle Cry), and `WeaponStats.earned`, which keeps it
out of every crate, the store, Endless prizes and the area Dex pages (`Util/ShopRules`, `Util/DexBook`).
**A weapon that can never be had twice has no merge tier** (owner, 2026-11-14: "for weapons with no
duplicates such as these and the weapons that you get for endless, there should not be a merge tier";
`ShopRules.merges`, false for an `earned` weapon): no tier badge or copy count on its tile, no TIER or
copies line and no MERGE on its Gear card, no tier in its damage (`Wallet.weaponTier`,
`ShopRules.strength`), and the server refuses to merge it or to give a second copy. Endless gives
ordinary crates today, whose weapons do merge; a weapon only Endless gives (the astral set,
`docs/ENDLESS.md`) takes `earned = true` when it is built. It goes on by itself if stronger than the weapon worn (`ShopRules.upgrade`), in hand from
the next run or the lobby; a saved level 10 without its weapon is given it on join
(`Wallet.settleClassWeapons`). The level shows on a plate (round badge, bar) under Gear's power plate
and beside the end screens' panel (under it on an upright screen, `EndScreenRules.levelPlate`), where the
run's XP fills the bar and each level reached pops with its gift, as a LEVEL chip on each class at class
select and on Gear's CLASSES tab, and a golden weapon earned opens its own card over Victory or Defeat.
**In the game since 2026-11-14** (the owner imported the three models): `Config/Weapons` (one textured
mesh each, a gold `aura`, `shotGlow` or `trailGlow`), grips and the bow's yaw measured into
`skins_to_luau.py` (`GOLDEN`, `GRIPS`, `YAW`), each with its own shot or cleave in `Config/WeaponFx`.
The models are Tripo's from Codex front views (`assets/models/weapons/blocky/golden/`): the staff and
blade at 2,000 triangles and 2K; the bow made again from a picture with a thick gold bar for a string
(owner: "the string on the tripo model is trash"), at 4,000 triangles with an 8K texture whose stray
colours `clean_bow_texture.py` repaints gold ("there are random colors on it").

**Weapon textures are kept ready** (owner, 2026-11-14: "preload the weapon textures so they dont show up
pale"; `Fx/WeaponPreload`, `Util/WeaponContent`, `tests/WeaponContent.spec`): a one-mesh weapon carries
its colours in a texture, and one not in video memory is drawn bare for a few seconds when first held.
The client keeps warm (`Preload.warm`, in the lobby and in a run) the textures of every player's `Weapon`
attribute and of its own saved `equipped`, and fetches every owned weapon's as the profile comes or
changes. `Fx/LobbyPreload` still fetches every weapon's in the background, and drops its own warm set
as a run begins.

**The Robux store** (owner, 2026-11-13: "Yes, build them"; `Config/RobuxStore`, `Util/StoreRules`,
`Server/Data/Purchases`, `Server/Data/Passes`, `UI/RobuxStore`, `UI/RobuxOffer`, `docs/ROBUX-STORE.md`):
five gem packs, a starter pack (once a player, offered once as a Victory is left for the lobby with two
levels won, never over NEXT LEVEL: `RobuxStore.starterAfterWins`, marked offered when `RunLobby` answers
it, since 2026-11-14) and a
**15 Robux revive, Robux only, never gems** (owner; not sold in a run's first three rooms,
`RobuxStore.reviveFromRoom`, where a held one can still be used) as developer products; 2x Coins, Extra Pet Slot (PET 3 on
the Gear sheet) and VIP (gold name tag, +10% coins, 25 gems a day) as passes. Never sold: Mythics, boss items,
Starfall, boss badges; no energy, no timers. **Every receipt is granted once**: `ProcessReceipt` looks its
`PurchaseId` up in the save (`SaveSchema` v15 `purchases`), grants and writes it down together, and answers
`PurchaseGranted` only after `PlayerData.saveNow` lands. Prompts are the server's (`Remotes.StoreBuy`). The
revive puts the buyer back into the room they fell in, which starts over with their build (`RoomController.revive`);
in co-op only the buyer, the others sit that room out. The ids are the dashboard's (universe 10772468005,
created 2026-11-14, managed pricing off); an id at 0 shows SOON. The creator's account owns every pass.
Studio: `Remotes.DebugReceipt(key, id)` and `DebugPass(key, on)`.

**Live events** (owner, 2026-11-18: "yes all of these create them"; `docs/LIVE-EVENTS.md`, `Config/LiveEvents`,
`Util/SetRotation`, `Util/LiveBoosts`, `Util/LiveState`, `Server/Data/Boosts`, `Server/Data/Policy`,
`UI/BoostBanner`): all on the server's clock, UTC, a week from Monday 00:00. **Two themed sets a week** on
the SETS tab (with NEW SETS IN ...), the others off the shelf and refused by the server (`ShopRules.buyable`
takes the server's `now`). **Weekend boosts**, Friday 00:00 to Monday 00:00, 2x Luck and 2x Coins weekend
about; the **owner's live event** (the LIVE switch under the lobby banner, user id checked on the server,
MessagingService to every server, MemoryStore for new ones), 30 minutes of either; the **Server Luck**, a 49
Robux product, 15 minutes of 2x luck for the whole server, more time a buy, thanked on the banner, sold on
the Hatchery's odds card and never offered to a player PolicyService restricts paid random items for
(`paidRandom`, `StoreRules.offered`; unknown counts as restricted). **Boosts add and stop at
`LiveEvents.caps`**: luck at most 3x, events at most +1 coin scale (2x), beside the passes, streak and
friend; VIP brings no luck. Luck multiplies the Legendary and Mythic odds and the other rarities pay for it
(`LiveBoosts.odds`, `EggRules.pool(key, luck)`); the egg screen draws the odds at the luck running. Studio:
`Remotes.DebugClock(seconds)` moves the clock for the server and every screen.

**Endless pays in eggs and crates** (owner, 2026-11-11: "MAKE IT MORE LIKE 5 EGGS AND 5 CRATES ... I WANT
IT TO FEEL NECESSARY TO BEAT THESE ROOMS"): each milestone (`Balance.Endless.milestones`) hatches its
eggs and opens its crates for the player on the spot, free, one of each batch sure to be at least its
`rarity` (`Server/Data/EndlessPrizes`, `Util/PrizeRules`, shown by `UI/EndlessPrize`). **A prize egg or
crate is the furthest one the player has reached, by the launch's gates, whichever way the launch switch
is** (`PrizeRules.eggKey`, `PrizeRules.crateIndex(class, bossesBeaten)`; 2026-11-16): a shop may sell
everything in playtest, a gift may not. Before, a new Ranger's class level 3 opened Bogheart's crate, and
with the launch locks on the crates would still have been Bogheart's. **Soulstones buy
eggs and crates** at the Soulstone shop (`Config/SoulstoneShop`, `Util/SoulstoneShopRules`,
`Server/Data/SoulstoneShop`, `UI/SoulstoneShop`), opened from the Endless portal's screen: 100 for the
first area's, doubling an area, 1 or 5 a press.

**The weapon shop** (owner, 2026-10-25; `Config/Shop`, `Util/ShopRules`, `Server/Data/Shop`,
`UI/ShopScreen`): at the lobby's Blacksmith, SHOP (or E) opens CRATES, STORE and MY WEAPONS.
A crate per area for coins (500, 1,000, 2,000, 4,000, 10,000, 20,000) rolls on the server
(Uncommon 60, Rare 28, Epic 11, Mythic 1) one of that area's weapons; a weapon already owned
is one more C copy, saved: three of a merge tier make one of the next, C -> B -> A -> S, each
1.2x the damage before and S 1.5x over A (owner, 2026-10-28; `Util/MergeRules`, MERGE on the
gear screen's item card), and pets merge the same way; the Drowned Village's and Bogheart's crates and stores are stocked
(owner, 2026-11-13), each shut at launch until the boss its area's portal waits on (`Shop.crates[i].atLaunch`,
`ShopRules.crateOpen`, checked on the server), and a Mythic keeps its 1% in a chest that lacks a rarity; every tile of a held weapon or pet wears its best tier as a coloured letter in its bottom left (`Chunky.tier`, `UiPalette.tier`: C bronze, B steel, A gold, S ruby; owner, 2026-11-12); areas with no weapons yet are black silhouettes. The store sells an area's
weapons for gems by rarity, its Legendaries for coins and 3 of its boss's item; Mythics only
come out of crates. EQUIP holds an owned weapon (its class with it), saved, in hand at once in
the lobby. Every weapon picture is the THREE-QUARTER view of the reference sheet its 3D model was
built from (owner: "use the 2d reference sheet 3/4 view pictures"), all turned to the Acorn Bow's
angle (owner, 2026-10-26: "all at the same angle"; `Config/ShopAssets`,
`assets/ui/shop/three_quarter.py`); a new weapon needs one (`Shop.spec`). Studio test remote:
`Remotes.DebugWallet:FireServer(coins, gems, itemsEach)`. In Studio the shop opens by itself on
reaching the lobby, wallet topped up (`Sandbox.openShop`; set it to nil to stop that).

**Trails** (owner, 2026-11-13: "ANOTHER FOR CREATING THE TRAILS"; `Config/Trails`, `Util/TrailRules`,
`Server/Data/Trails`, `Fx/PlayerTrails`): what the Gear sheet's TRAIL slot holds, **looks only**. Three an area,
picked from Codex's sheets (`assets/concepts/blocky/ui/trails/`): Mossy Glade's Leaf Drift, Firefly Wake, Royal
Goo; Thornwood's Bramble Pollen, Crow Feathers, Brood Silk; the Drowned Village's Bubble Stream, Splash Wake, Tide
Bell; Bogheart's Bog Spores, Glowcap Path, Gulp's Bubbles; and one Mythic, **Starfall**. Rare and Epic are bought
for gems on the TRAILS tab (the store's 180 and 450 times the area's number, on sale when the area's crates are);
an area's Legendary is given the first time its boss falls (and on join to anyone who beat it before); Starfall
for reaching Endless floor `Trails.endless.floor` (50) as **each** of the three classes (owner: "a reward for
getting to a certain floor on endless with all 3 classes"; save v14 `endlessClassBest`, counted from the first
run after trails came in). The server grants through `Wallet.grantTrail` / `settleTrails` only, and the worn one
is the Player's `Trail` attribute; every client draws every player's trail itself. **Each look is its Claude Design
build's** (owner, 2026-11-13: "start making the trails in design that were agreed upon earlier"; one Design project
a trail, named on its entry as `design`, every number ported from the build's own code): a ribbon of voxel tiles
laid on a world grid as the player runs (`Trails.tile` studs a tile, ageing a row every `1 / Trails.pace` s), each
tile coloured and sized by its column across the ribbon (edges, bands, heaped foam, gold rails, lumps), fading,
narrowing and dissolving as the build's rows do (Brood Silk's is five silk threads at their own heights instead);
and pieces built of a few blocks (leaves, fireflies, crowns, feathers, bubbles, spray, shards, glowcaps, plus
stars) moved by the build's motion: out, up to a peak and down to settle, sway, tumble, blink and flash. Ribbon
timings in rows, piece timings in the build's seconds. Tiles and blocks are pools (`DeviceTiers.trailShare` of
them), moved in one `BulkMoveTo`; a player beyond 160 studs of the camera lays nothing new. A dash or putting one
on throws a burst; a glowing trail's light breathes. Every Legendary and Mythic trail glows with a light and Neon
(`tests/Trails.spec`). One picture a trail, `Trails.trails[key].icon` (Codex, cut by
`assets/ui/trails/cutout.py`); a new trail needs its icon drawn from the same prompts, and its Design build.

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
2026-10-25). **Since 2026-11-14 the card is off (`NewEnemies.card = false`)**: a first meeting is a NEW!
name tag over the enemy for `tagFor` (2.6 s) and nothing holds (owner, "Build top 5", after the kid
playtest: four cards stopped the first ten minutes, two inside one fight). The sheets stay for the screen's
`Preview` and the Dex; `card = true` brings back what follows: the first time a player meets a kind of non-boss enemy (once per
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

**Chain Lightning is a bolt and Soul Chain a fireball** (owner, 2026-11-11: "chain lightning
should be like the stattik shiv effect ... soul link should be like brand ult"), both built in
code, no imported model. Chain Lightning is still Ricochet's stage, but its arcs leave at
`Balance.Projectile.arcSpeed` (`ShotSpec.arcSpeed`), so each hop lands a few hundredths of a
second after the last; the server marks the hop (`ShotEvent.arc`, `to`) and the client draws a
jagged, forked bolt between the two bodies in place of an orb (`Fx/Upgrades/LightningFx`,
`Util/BoltPath`). Soul Chain links the same enemies for the same share, but each takes it as a
fireball lands on it, leaping to the nearest one next (`Shared/Combat/SoulBounce`,
`Server/Combat/SoulLink`'s queue, `Fx/Upgrades/SoulFireFx`). An effect seen from above must lie
in the ground plane; `tests/ChainSoulFx.spec` holds both.

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
From a probe, `Remotes.DebugRoom:FireServer(10)` jumps the run to a room, or a wave of a Waves
stage (Studio only), to test the boss without fighting through the level; a jumped level still
counts as won, so unlocking can be tested.
From a probe, `Remotes.DebugGrant:FireServer("Cleave")` grants one level of
any card (Studio only), to test a card's effect without drafting it.
**K** — spawn a wilf (`Remotes.DebugSpawnEnemy`, any `Balance.Enemies` key from a probe; a name that is not one,
such as "MossSlime", spawns nothing). `Remotes.RunRestart` does nothing mid-run (only once the run is over), so a
probe's granted cards and spawned enemies pile up in one run. To start a level from a probe, put the character at
its portal's mouth from the Server VM (`Workspace.Lobby.Portal_<i>`, about 7 studs toward the courtyard) and fire
`PortalStart(i, level)` (since 2026-11-14 the start no longer needs the character there: firing
`PortalStart(i, level)` from the Client anywhere in the lobby starts an open level, alone).
**P** — the pets the owner imported follow you, playing their own clips
(`Fx/PetPreview`, built by `Server/Dev/PetPreview` from `Config/PetModels`); P again
puts them away. Each moves as itself (`Config/PetGaits`, `Util/PetGait`: its pace, tilts, hover and fidget, one per pet, pinned by `tests/PetGaits.spec`). A look only, until Phase 6's pet system.
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
  A ViewportFrame is 3D too: on 2026-11-12 the class select cards came back
  empty in a Play capture while each held its figure (a red test block in a
  fresh ViewportFrame was missing as well). Probe the viewport's WorldModel,
  or build the thing in the Edit Workspace, capture there (Edit captures do
  draw 3D, and take a camera position) and delete it.
- **This place's signals are deferred**: a `ChildAdded` or changed-signal
  listener runs a moment after the change, not inside the call that made it.
  A spec that asserts what a listener did waits a step first (`task.wait()`).
- **Never call a client Fx module's `start()` in the Edit datamodel** to
  preview it. Its RenderStepped connection outlives the probe, keeps running
  against the Edit scene's stale `Balance` cache, and logs errors under
  `StarterPlayer.StarterPlayerScripts…` until Studio restarts. Build the
  parts once and capture instead.
- **Threads spawned by an `execute_luau` probe die when it returns.** A
  background sampler started in one call records nothing; sample inside the
  call that waits, or time a `screen_capture`.
- **`user_mouse_input` moves the cursor but its clicks may not land.**
  `moveTo` an `instance_path` such as
  `LocalPlayer.PlayerGui.DraftScreen.Panel...`, then click, or
  `mouseButtonDown` / wait / `mouseButtonUp` for a hold. This has worked; on
  2026-11-03 it did not, in any form, over a dozen attempts on two different
  screens, focused and unfocused, at 15 fps and at 60 — `GetMouseLocation`
  confirmed the cursor sitting inside the button and nothing fired. Note that
  `instance_path` aims at the raw `AbsolutePosition`, which is 58 px above
  where the mouse has to be: add the `GuiService:GetGuiInset()` Y yourself and
  pass x/y. **`user_keyboard_input` is the reliable one** — reach for it
  first. Play-mode captures do show the GUI (and the 3D view, these days).
- **A screen that holds the run cannot be cleared from a probe**, because each
  one keeps the *client's* `RunPaused` set even once the server's hold is
  gone, and `LocalFiring` draws nothing while it is. NEW ENEMY! yields to
  `user_keyboard_input` `Return` (`NewEnemySeen` from a probe clears only the
  server). **The draft does not yield at all**: its ButtonA / ButtonX are
  bound through `ContextActionService` in gamepad mode only, so a synthetic
  ButtonA does nothing, and `AbilityChosen` clears `session.loadout.offer`
  while the screen stays up and stays paused. An open draft is a dead end —
  restart Play. The sandbox is no rig either: it holds the run, so nothing
  fires.
- **To measure a fight, shoot something that cannot die**:
  `DebugSpawnEnemy:FireServer("SlimeKing")` is 6000 health and pays no XP
  until it falls, so no level-up and no draft ever interrupt the window. Stand
  the player nearest it so `Aim` picks it over the room.
- **Studio renders at a hard 15 fps while unfocused**, which inflates any
  frame-rate-dependent measurement about fourfold — record the frame time
  alongside every number so it can be read back. And do setup and measurement
  in **one** `execute_luau` call: Play dies between calls often enough
  ("Target is closed") that multi-call rigs lose their state.
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

- **The Play camera can be posed from a probe.** The lobby's camera follows the
  character and keeps whatever turn `Camera.CFrame` is given, so set
  `CameraMinZoomDistance = 45` on the client, stand the anchored, invisible
  character at `cam + look * 45` from the server, and set `Camera.CFrame` once.
- **To play every level unattended**, use the autopilot in `tools/studio/autoplay/` (its README): it
  shares the game's `require` cache because it is made in Edit, and logs errors, stuck rooms and
  bad states. It sees no visual fault, so sample captures while it runs. Real keys and clicks do
  reach Play through computer use, once Studio has focus: hover before clicking a button.
- **Studio changes can be tested without taking over the Rojo serve**: write the
  changed text into each script's `.Source` from `execute_luau` in Edit. A later
  sync of that file overwrites it, and a new script vanishes on the next Connect.

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

Every client→server remote is listened to in `Net/Inbound` (`Inbound.on`; a `Debug*` one with
`Inbound.debug`, which connects nothing outside Studio): a rate limit per player per remote under
the handler's own checks. `tools/check.sh` fails on an `OnServerEvent` anywhere else. Every
`AnalyticsService` event is sent from `Data/Analytics` (the 2026-11-13 audit, `docs/FIXES.md`).

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

**11. Every word on screen is in the one rounded font.**
Fredoka One, Roblox's `Enum.Font.FredokaOne` (`Chunky.font`; `Font.fromEnum(Enum.Font.FredokaOne)` for a
`FontFace`): HUD, cards, end screens, banners, damage numbers, billboards, dev labels, all of it (owner,
2026-11-11: "the ui font for everything should match the new ui text font, replacing the previous rule").
It replaced the blocky font, Press Start 2P, which the rule named from 2026-10-24 with the rounded one as
its exception. The room sign's own pixel letters (`Config/PixelFont`) are drawn, not typed, and stay.
`tools/check.sh` fails on any other font.

**12. Every Legendary and Mythic glows.**
Weapons, skins, pets, anything with a rarity (owner, 2026-10-24: "anything that is a legendary
or a mythic NEEDS a glow to it"). Since 2026-11-06 a Mythic no longer has to be rainbow; existing rainbow
Mythics stay. Weapons: their glow parts are Neon with a light (`Combat/HeldWeapon`), a rainbow
Mythic's turned round the hue wheel (`Fx/WeaponGlow`); `skins_to_luau.py` gives every Epic and up a glow. Pets: `Config/PetAuras`
lists every Legendary and Mythic pet. Every bow's and staff's shot and every blade's cleave is its own (`Config/WeaponFx`, pinned by `tests/WeaponFx.spec`); a new weapon needs an entry there.

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

**15. One coin and one diamond, everywhere.**
Coins and gems are drawn with the same two pictures wherever they show (owner, 2026-11-12: "make
sure that the coin and diamond icons are universal across the game"; "i like the blue diamond"):
`ShopAssets.coin` and `ShopAssets.gem`, on every screen, the run HUD, the coins a kill throws and
the lobby's price signs. A price or a reward shows the picture beside the number, not the word.
No other config holds a coin or gem picture; `tools/check.sh` fails on one. The coin is the gold
arrow coin ("can you make a coin that has an arrow on it?", then "B gold"), Codex's, cut by
`assets/ui/shop/coin_arrow_cutout.py`. Soulstones are their own currency and keep their own drawn
purple stone (`UI/SoulstoneShop`).

**16. One picture per item, the same on every screen.**
Every weapon and pet has exactly one picture, and every screen that shows it (the crates' and
chests' odds and reveals, Victory's chests, the gift box, the egg screen and its hatch reveal, the
Gear screen, the Dex, the Blacksmith's store and SETS, prize panels) asks `Util/ItemIcons` for it
(owner, 2026-11-19: "MAKE SURE THE ICONS IN THE CHESTS, EGGS, GEAR SCREEN, AND DEX ARE ALL THE
SAME"). A weapon's is its 2D shop art (`ShopAssets.weapons`, rule 14); a pet's is its 2D picture
(`GearAssets.pets`). **Pets are 2D everywhere, the hatch reveal included** (owner's pick A,
2026-11-19), which replaces the 2026-10-31 wish to see them standing at an angle on the egg screen;
the only 3D pets on a screen are the ones beside the hero in the Gear screen's portrait, which is the
player's loadout and not an item's picture. No screen reads `ShopAssets.weapons` or
`GearAssets.pets` itself (`tools/check.sh` fails on one), and `tests/ItemIcons.spec` wants an
uploaded picture for every weapon and pet. A new weapon or pet brings its one picture; the outlined
weapon copies and the option C crate tiles were dropped and must not come back as a second set.

## Code conventions

- `--!strict` at the top of every Luau file. No exceptions.
- Tabs, 100 columns, double quotes — StyLua enforces it; run it before committing.
- One module per file, named after the file. `PascalCase` for modules and types,
  `camelCase` for locals and functions, `SCREAMING_SNAKE` for file-level constants.
- `*.server.luau` → Script, `*.client.luau` → LocalScript, plain `.luau` → ModuleScript.
- Services via `game:GetService()` at the top of the file, never mid-function.
- Config modules end with `table.freeze(...)`.
- Log through `Shared.Util.Log.forTag("Subsystem")` so MCP console reads are greppable.
- Everything that animates runs at the screen's frame rate, not a fixed step (owner,
  2026-11-10: "everything else that animates should be at 60fps"; the story cutscene is
  its own clip). An anchored part the server moves gets the `SmoothMotion` tag
  (`Fx/SmoothMotion` draws it between network updates); a client spring steps by the
  frame's real length, fractions included (`UI/Cards/Motion`, `DraftScreen`).

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
