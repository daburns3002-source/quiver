# Performance: what every model and room costs

Measured 2026-10-25 for the owner's ask that the game run smoothly on mobile,
console and PC with no visible loss of quality or animation. How to take
these numbers again is at the end.

## In short

- **The models are already lean.** Weapons and arena kits are merged to 1–4
  parts each; the kit pieces have only 4–7% of their triangles buried
  inside other blocks and the Bramble Hedge none. Nothing in them is worth a
  re-import.
- **The engine already batches well.** A Thornwood room draws 125–180k
  triangles in 145–270 draw calls, about 2.5–3 ms of GPU on the test PC; six
  clip-driven enemies (174 parts) cost 23 draws between them.
- **The biggest cost was the client's script time, almost all of it in
  `Fx/ModelAnimator`**, which poses every clip-driven enemy, boss, pet and
  effect each frame. It is now **1.9x faster** (2.74 → 1.46 ms a frame for
  20 Thornwood enemies), with every part posed within 0.000004 studs of
  before. Pickups and the target ring stopped reading attributes and
  resizing parts every frame. No model changed, so nothing needs a
  re-import.
- What is left costs either a re-import or something visible, so each one
  is the owner's call: see [Options](#options-the-owner-decides).

## Client frame time

Thornwood room 7 in the sandbox, with 20 clip-driven enemies on top (four of
each Thornwood enemy, each playing a looping clip, 644 parts), on the test
PC. Studio holds 60 fps either way, so what is compared is the work a frame
takes: the script profiler's client script time (only comparable between
these runs, not milliseconds) and the render stats.

| Tier | Code | All client scripts | `ModelAnimator` | Raw part moves | Triangles | Draws | GPU ms |
|---|---|---:|---:|---:|---:|---:|---:|
| High | before | 1.12 | 0.81 | 0.48 | 144k | 137 | 2.5 |
| High | after | 0.65–0.92 | 0.46–0.64 | 0.30 (one batch) | 148–171k | 150–246 | 2.0–2.8 |
| Low | before | 1.27 | 1.06 | 0.59 | 168k | 218 | 2.6 |
| Low | after | 0.84 | 0.62 | 0.30 (one batch) | 161k | 202 | 2.6 |

The profiler's run-to-run noise is about a third (`ForestAmbience` alone
swings between 0.06 and 0.13), so the animator was also timed directly, old
against new, posing the same 20 clones:

| `ModelAnimator`, 20 Thornwood enemies (644 parts) | ms a frame |
|---|---:|
| before | 2.74 |
| after | **1.46** (1.88x faster) |
| largest difference in any part's place, turn or size | 0.0000038 studs |

A phone runs Luau several times slower than the test PC, so in a busy room
this is several milliseconds of a 16.7 ms frame back.

## Rooms

What a room draws, measured in Studio a few seconds after it starts (High
tier). These are the same before and after: the change is in script time,
not in what is drawn.

| Room | Triangles | Draws | GPU ms | Render thread ms | Arena parts (meshes) | Enemies (parts) |
|---|---:|---:|---:|---:|---:|---:|
| Mossy Glade 1 | 146k | 145 | 2.7 | 2.8 | 562 (366) | 0 |
| Mossy Glade 3 | 161k | 151 | 2.5 | 3.3 | 560 (368) | 2 |
| Mossy Glade 6 | 155k | 152 | 2.5 | 3.1 | 558 (366) | 4 |
| Mossy Glade 10, King Bloblin | 160k | 201 | 2.6 | 3.5 | 554 (362) | 1 (73) |
| Thornwood 1 | 125k | 145 | 2.5 | 3.0 | 540 (284) | 0 |
| Thornwood 7 | 155k | 190 | 2.8 | 3.1 | 538 (286) | 2 (76) |
| Thornwood 15 | 144k | 175 | 2.5 | 3.2 | 533 (285) | 0 |
| Thornwood 25 | 179k | 268 | 2.9 | 3.3 | 529 (285) | 6 (212) |
| Thornwood 33 | 164k | 229 | 3.1 | 3.4 | 536 (284) | 4 (150) |
| Thornwood 40, Broodmother | 150k | 384 | 2.8 | 3.1 | 538 (286) | 1 (120) |

Where a Thornwood room's frame goes (room 7, each group hidden in turn):

| Group | Parts | Triangles | Draws |
|---|---:|---:|---:|
| Outer forest (`GladeForest`, every tree its own mesh) | 224 | 63,600 | 100 |
| Walls (Bramble Hedge v2, 2,364 triangles each) | 16 | 33,400 | 2 |
| Enemies (6) | 174 | 22,300 | 23 |
| The player and the weapon in hand | 22 | 15,200 | 8 |
| Fallen logs | 4 | 9,800 | 1 |
| Floor patches | 230 | 2,800 | 0 (batched) |

## Models

### Clip-driven models (enemies, bosses, pets, effects)

Imported with Merge Meshes off, so each GLB primitive is a MeshPart, and each
is posed every frame by `Fx/ModelAnimator`. "If merged" is how many parts
would remain if every primitive riding the same animated joint with the same
kind of material were one mesh (`tools/glb_stats.py`); that needs a
re-import, see the options.

| Kind | Model | Triangles | Parts in game | Animated joints | Clips | If merged |
|---|---|---:|---:|---:|---:|---:|
| boss | Broodmother | 11,536 | 119 | 38 | 12 | 38 |
| boss | King Bloblin | 11,172 | 72 | 29 | 22 | 33 |
| enemy | Bramble Sow | 9,520 | 37 | 17 | 6 | 16 |
| enemy | Bramble Boar | 8,760 | 36 | 12 | 5 | 12 |
| enemy | Bramble Lurker | 8,580 | 29 | 35 | 5 | 8 |
| enemy | Thornling | 704 | 27 | 25 | 5 | 18 |
| enemy | Burr Thistle | 2,336 | 22 | 5 | 4 | 6 |
| pet | Glimmerhorn | 11,356 | 348 | 65 | 5 | 64 |
| pet | Slime Prince | 3,462 | 148 | 48 | 5 | 49 |
| pet | Mossback Snail | 8,160 | 137 | 11 | 5 | 10 |
| pet | Glade Fox | 4,720 | 80 | 13 | 5 | 12 |
| pet | Stumpy | 4,080 | 68 | 8 | 5 | 7 |
| pet | Ember Wilf | 2,160 | 66 | 37 | 4 | 36 |
| pet | Firefly Bun | 3,964 | 59 | 12 | 4 | 18 |
| pet | Hootmoss | 3,102 | 58 | 15 | 5 | 15 |
| pet | Fern Frog | 5,128 | 50 | 8 | 4 | 7 |
| pet | Toadstool Tot | 1,284 | 39 | 7 | 5 | 6 |
| pet | Mosslet | 1,404 | 21 | 5 | 4 | 5 |
| pet | Babacorn | 476 | 14 | 5 | 5 | 4 |
| effects | 40 upgrade and pet effects | 84–3,364 each | 1–33 each | 0–20 | 0–3 | 1–20 |

All 59 together: 149,613 triangles in 1,819 parts, 621 if merged.

### Static models

| Model | Triangles | Parts | Notes |
|---|---:|---:|---|
| Mossy Glade kit (9 pieces) | 5,018 | 9 | 7% buried faces |
| Thornwood kit (5 pieces) | 5,032 | 5 | 4% buried faces |
| Bramble Hedge v2 | 2,364 | 1 | no buried faces; 16 per room |
| Mossy Glade outer forest (`GladeForest`) | 92,522 | 7 chunks (was 252 meshes) | merged 2026-11-27, see below |
| Weapons and skins (35 imports) | 154–4,252 each, 51k in all | 1–5 each | one in hand at a time |
| Round enemies (Moss, Brood, Baby Slime, Splitter Spitter, Ember Wilf) | 3,347–7,515 each | 1–3 each | already merged |

## What changed (no re-import)

- `Shared/Util/ModelClip`: a joint whose whole chain carries no scale is
  posed with Roblox's native CFrames (`deltasInto`, `placeRigid`) instead of
  3x3 tables; a joint that scales keeps the exact affine maths. Only joints
  that carry a part, or lead to one, are posed (a Bramble Lurker poses 9 of
  its 37). Sampling a clip writes into a reused table instead of making three
  per key. `tests/ModelClip.spec` checks every part of every model and clip,
  and a stretched chain, lands where the old maths put it.
- `Fx/ModelAnimator`: every model's parts move in one `BulkMoveTo` a frame.
- `Fx/PickupFx`: each crystal and heart reads its parts once when it drops;
  a frame moves them all in one batch and resizes only while one shrinks
  (sizes were rewritten every frame while they bobbed).
- `Fx/CombatMarkers`: the target ring keeps its segments' angles in a
  table and moves them in one batch.
- `client/Device`: in Studio, the Workspace attribute `DevTier` ("Low",
  "Medium", "High") plays as that tier, so a phone's budgets can be measured.
- `Fx/ProjectileRenderer` and `Fx/SlimeHop`: every live shot, and every
  slime's pieces and shadow, move in one batch a frame.
- `Fx/BroodWheelFx` (the Broodmother's Web Walker, 225 tiles): the web's
  145 tiles were recoloured and re-faded every frame; now only when the
  look changes (the warning's pulse, the fade), so a spin writes none of
  them. The 80 arm tiles move in one batch and keep whether they are inside
  the room in a table instead of an attribute set and read every frame.

## Options the owner decides

1. **Merge clip-driven models' parts per joint (re-import).** The table's
   last column: 1,819 parts to 621, Glimmerhorn 348 → 64, Slime Prince
   148 → 49. The engine's own part moves are now the biggest piece of the
   animator's cost (about 0.30 of 0.62 above), and they scale with parts.
   The catch: merged parts must carry their colours as vertex colours on a
   white part, and code that tints parts by name (eyes, gems, glows, hit
   flashes) must keep those parts apart. It needs every model re-imported
   (File → Import 3D, Merge Meshes off) and its configs regenerated. Not
   started.
2. **Merge the outer forest into a few chunks.** Done 2026-11-27 (the
   owner's pick): see [The outer forest in chunks](#the-outer-forest-in-chunks-2026-11-27).
3. **Shadows off on the Low tier.** Done 2026-11-27 (the owner's pick):
   see [Shadows on the Low tier](#shadows-on-the-low-tier-2026-11-27).
4. **Clean out `ServerStorage.Imports`.** Done 2026-11-27 (the owner's
   pick): see [The place without its imports](#the-place-without-its-imports-2026-11-27).

## The place without its imports (2026-11-27)

`ServerStorage.Imports` held every Studio import once its ids were dumped:
319 models, 47,280 instances, read by nothing in the game (only the dump
scripts in `tools/studio`, for an import not yet dumped). Every server
loaded it. It is saved as `assets/imports/2026-11-27.rbxm` (checked by
loading it back: all 47,280 instances alike in class, path, mesh, texture,
size, colour, material and place) and deleted from the place.

Serialized size (`SerializationService`, every saved service's children,
Edit, on the test PC):

| | Place | `ServerStorage` |
|---|---:|---:|
| Before | 24.32 MB | 13.86 MB |
| After | **15.16 MB** (−38%) | 4.70 MB |

What else is big in the place, left alone here: `ServerStorage.RBX_ANIMSAVES`
(3.65 MB, 260,259 instances: the Animation Editor's saves) and about 107
models other sessions left in the Edit Workspace (`TripoImports`, render
rigs, weapon and pet-effect previews, 6.58 MB), which `Server/Util/WorldSweep`
destroys at every server start but which still ship in the file.

## Shadows on the Low tier (2026-11-27)

`DeviceTiers.enableShadows` existed but nothing read it, so the sun cast
shadows on every device. Now `Main.client` turns its own copy of
`Lighting.GlobalShadows` off on the Low tier only (a touch-only screen whose
short side is under 700 pixels: a phone) and keeps it off; Medium (tablets,
consoles) and High keep shadows, so only phones look different: no shadow
under the player, the enemies, the trees or the walls. Roblox's own graphics
quality already drops shadows on its lowest levels, so a weak phone on
automatic quality looked like this before.

Checked in a Studio Play with `DevTier` "Low": the client's
`GlobalShadows` is off from the start and turned straight back off when
forced on; the server's stays on. **Not measured yet:** what the shadow pass
costs a frame. That needs Studio drawing on screen, and on 2026-11-27 it was
minimized for the whole session. To take it: `DevTier` "Low", Play, and
`tools/studio/perf_room.luau` once with `Lighting.GlobalShadows` forced on
and once as the tier leaves it, same room (the shadow pass does not show in
`RenderBreakdown`'s draws, so compare GPU and render-thread ms).

## The outer forest in chunks (2026-11-27)

Every tree of an area's outer forest (the scenery past the walls) was its
own mesh, 72 to 304 of them, none alike, so none could share a draw.
`tools/forest_chunks.py` merges each forest by how Arena draws it (plain,
matte, each glow tint) and by place into chunks of at most 19,000
triangles, uploaded as meshes; `Config/ForestChunks` puts them in the
rooms in place of the per-tree layout. The trees inside the walls are
untouched. Checked in Studio: each chunk's mesh holds the triangles its
layout says (92,522, 167,150, 43,788 and 35,880 a forest), at its config's
size within 0.001 studs, and the chunks fill the same box as the trees did.
`Fx/ForestAmbience` takes its crowns (what lives on the canopy sits on them) from the
chunks' layout, since there are no crown parts left to read. The outer
trees can no longer sway one by one, which the owner accepted.

| Forest | Meshes before | After | Triangles |
|---|---:|---:|---:|
| Mossy Glade (`GladeForest`) | 252 | 7 | 92,522 |
| Thornwood | 248 | 12 | 167,150 |
| Drowned Village | 72 | 4 | 43,788 |
| Bogheart Caverns | 304 | 6 | 35,880 |

What a room draws of its forest, from the game camera's own view
(`Camera/TopDownCamera`, the focus at five places along the room): the
engine skips a part whose box is wholly outside the view, so a tree out of
sight cost nothing, but a chunk is drawn whole if any of it shows.

| Forest | Screen | Draws, per tree → chunks | Triangles, per tree → chunks |
|---|---|---:|---:|
| Mossy Glade | PC 1920 x 1080 | 93–100 → 7 | 59–60k → 93k |
| Mossy Glade | phone sideways | 39–46 → 6–7 | 30–49k → 76–93k |
| Mossy Glade | phone upright | 33–45 → 7 | 47–49k → 93k |
| Thornwood | PC | 119–125 → 12 | 152k → 167k |
| Thornwood | phone sideways | 51–79 → 8–12 | 71–147k → 101–167k |
| Thornwood | phone upright | 61–64 → 12 | 129–131k → 167k |
| Drowned Village | PC | 33–38 → 4 | 33–36k → 44k |
| Drowned Village | phones | 18–24 → 4 | 20–30k → 44k |
| Bogheart Caverns | PC | 83–93 → 6 | 26–27k → 36k |
| Bogheart Caverns | phones | 29–46 → 6 | 13–23k → 36k |

The glade's PC figures match what Studio drew on 2026-10-25 (100 draws,
about 64k triangles, above). So a room makes 30–120 fewer draws and
draws up to about 45k more triangles. **Not measured:** the GPU and
render-thread time with Studio drawing (it was minimized for the whole
session); take them with `tools/studio/perf_room.luau` on main against
the commit before this one. If triangles turn out to cost a phone more
than the draws saved, smaller chunks (`MAX_TRIS` in the tool) trade some
draws back for culling, and removing a forest's entry from
`Config/ForestChunks` draws it per tree again.

## Loading ahead: the next room and the cards (2026-10-26)

Owner, after a playtest: "next rooms need to preload while playing current
room (very important) … I also want icons to preload as well".

- **The next room is built mid-fight.** `Balance.Run.prepareDelay` (3 s) into
  each room the server builds the next one (`Arena.prepare`) and parks it in
  `ReplicatedStorage.NextArena`, so its ~560 parts reach every client during
  the fight; at the door `Arena.build` only moves it into Workspace. The
  client (`Fx/RoomPreload`) preloads the parked room's meshes and textures and
  the enemies it brings (its `Roster` attribute: meshes, NEW ENEMY! picture
  and sheet, a boss's banner icon and the boss music). Sounds already load at
  join; enemies animate from data, so there are no animation assets.
- **Card images load from the story on** (`UI/Cards/CardPreload`): every
  `CardAssets` image is fetched, the class's first; on tiers with
  `DeviceTiers.warmCardImages` (Medium, High) the class's images are also
  kept drawn off-screen (about 50 MB of video memory), so a hand draws them
  on its first frame. Low only downloads them.

Measured in Studio on the test PC (Mossy Glade run; door = `DebugRoom` to
the next room, which is what walking through it does):

| | Before | After |
|---|---:|---:|
| Server work at the door (room built + enemies spawned) | 10–12 ms | 5–6 ms (49 ms for King Bloblin's room, his model) |
| Building the next room in the background, mid-fight | — | 6–7 ms |
| Next room's content preloaded, after it was parked | — | 0.25–0.73 s (about 6 s before anyone can reach the door) |
| Worst frame on the first door of a fresh Play (room 6 → 7) | 334 ms, once* | 21 ms |
| Worst frame on later doors (content already cached) | 20–37 ms | 21–37 ms |
| A hand of three never-shown icons, until all are drawn | 317–348 ms | 65 ms (all 50 icons fetched before the first hand) |

*Taken once, on main. Later in the session the same door with preparing
switched off (`prepareDelay` = 1e6) also ran 21 ms, so that 334 ms frame
was first-load content or noise, not something every door does on a PC.

What Studio cannot show: the replication saved at the door on a real
network (Studio's server is local, `DataReceiveKbps` reads 0) and a phone's
cold cache. Studio keeps content cached for the whole session, so only
the first door of a session is cold there.

## Not covered yet

- The Thornwood outer forest was being changed by another session during
  this pass; it is measured above but not optimised, and nor is
  `Fx/ForestAmbience` (falling leaves, fireflies, birds: about 0.06–0.13
  above), which moves its parts one by one and is next. The Broodmother's
  model is option 1's biggest boss (119 parts to 38).

## How these were measured

- `python -I tools/glb_stats.py <glb>...`: a GLB's triangles, primitives,
  materials, animated joints and the merge estimate.
- `tools/studio/perf_room.luau` (Client, playing, Studio focused): jumps to a
  room, then the triangles and draws drawn, GPU and render-thread ms, the
  visible parts, and the busiest client scripts.
- Phones' budgets: set `DevTier` on the Workspace to "Low" in Edit, then Play.
- Studio only renders while its window has focus: a frame count of zero or a
  black capture means focus it. A long execute_luau call on the Play client
  that never yields fails with "Target is not reachable".
