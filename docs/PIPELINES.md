# Pipelines: how a new thing gets into the game

Every kind of thing the owner adds, step by step: what **the owner** does
(Claude Design, Codex, Studio imports, Roblox uploads — the parts nothing
automated can do) and what **Claude** does. The project skills
(`.claude/skills/`) run these; ask for one by name (`/intake`,
`/add-enemy`, …) or just send the file and say what it is.

What is in flight right now is in [TRACKER.md](TRACKER.md).

## The tools

| Tool | What it does |
|---|---|
| `python -I tools/intake.py <file>…` | Unpacks a handoff zip into `.intake/` (never the repo), says which files are NEW, CHANGED or already in, which animation clips are new or changed, spots duplicate zips, shows the README, and names the likely pipeline. Start every handoff here. |
| `tools/studio/dump_imports.luau` | Run in Studio (Edit) after an import: every imported MeshPart's mesh id, texture, size and bones, as JSON. Feeds the generators. |
| `python -I tools/sync_probe.py` | Prints a Studio probe that checks every changed script really reached Studio. Run before trusting any test. |
| `tools/studio/run_tests.luau` | Runs the in-Roblox suite (Server, playing). |
| `tools/check.sh` | Every gate: StyLua, Selene, strict types, `rojo build`. |
| `python -I tools/glb_clips_to_luau.py` | The clips inside the Claude Design GLBs listed in `assets/models/model_clips.json` → one data module each in `Config/ModelClips/`. See 10. |
| `tools/ship.sh "<title>" <body.md>` | Gates, push, PR, waits for CI, updates the branch if main moved, merges. |
| `python -I tools/glb_stats.py <file.glb>…` | What a GLB costs: triangles, primitives (each a MeshPart once imported), materials, animated joints, clips, and how many parts would remain if those riding one joint were merged. See 11. |
| `tools/studio/perf_room.luau` | Run on the Client while playing, Studio focused: jumps to a room, then its triangles, draw calls, GPU and render-thread ms, visible parts and busiest client scripts. See 11. |

## 0. The loop every change goes through

1. **Intake** (if something was sent): `tools/intake.py`. Decide the pipeline below.
2. **Branch** off an up-to-date main: `phase-N/short-name`.
3. **Build** it. Config is data in `src/shared/Config`; generated files are regenerated, never hand-edited.
4. **Gates**: `tools/check.sh`.
5. **Studio**: stop Play, run `tools/sync_probe.py`'s probe (all true, or reconnect Rojo), start Play, answer any open card screen, `run_tests.luau`, then playtest the change itself by probe and capture (CLAUDE.md, "Testing over MCP"). Black capture: focus Studio (`focus_studio.ps1`).
6. **Record**: a bug fixed goes in `docs/FIXES.md`; open or finished work in `docs/TRACKER.md`; a new system or rule in `CLAUDE.md`.
7. **Self-review** against `AGENTS.md`, exploitability first; say what it found.
8. **Ship**: `tools/ship.sh`.

## 1. An enemy model (static mesh)

**Owner:** Claude Design model → GLB (or a handoff zip). Later, Studio: File → Import 3D the slimmed GLB.

**Claude:**
1. `optimise_enemy.py <in.glb> <out.glb> <enemy> [model]` (`uv run --with trimesh --with numpy --with pymeshlab --with scipy --with networkx --with pillow python -I …`). Add the enemy to `ENEMIES` in the script: triangle budgets, any part kept `separate` (the King's arms). Output: `assets/models/enemies/<enemy>_roblox.glb` with Body / Eyes / Decor, facing −Z, base at y = 0.
2. Preview it (matplotlib render; the front is azimuth −90) before handing it over.
3. Ask the owner to import it. After: `dump_imports.luau` → mesh ids.
4. `EnemyDesigns`: `shape = "Mesh"` parts, white (vertex colours show), eyes Neon in the act's colour, turned 180° (the importer turns models), the shadow from `shadow(...)`. Fit the archetype's `hitboxSize` in `Balance` to the model; `Balance.spec` keeps arrow height inside every hitbox.
5. A new archetype: its `EnemyConfig` in `Balance` (health on Archero 2's scale, `docs/RESEARCH-archero2.md` §3), into a level's roster, and `EnemyDesigns` under the same `displayName`. Slimes hop if listed in `Balance.SlimeHop`.
6. Playtest: spawn it (`Remotes.DebugSpawnEnemy:FireServer("<Balance.Enemies key>")`), measure that its meshes stay out of cover, and that arrows hit it.

**Pitfalls seen:** colours lost when re-exporting (read the combined file with its root); the face pointing the wrong way (turned by its eyes); a model taller than its hitbox; the Edit datamodel's stale `require` cache (check `.Source`).

## 2. A rigged enemy (skinned mesh with animations)

**Owner:** the rigged GLB → Studio: File → Import 3D with **Rig: Custom** (and animations, if offered). Leave it in Workspace.

**Claude:**
1. `tools/intake.py` the handoff; keep its `.rbxmx` of KeyframeSequences in `assets/models/enemies/<enemy>/` (force-add: `*.rbxmx` is gitignored).
2. After the import: `dump_imports.luau` → the skinned MeshPart's mesh id, texture and bones → `assets/models/enemies/<enemy>/rig.json`.
3. Its generator (copy `ember_wilf/rig_to_luau.py`) → `Config/EnemyRigs.luau`: bones and clips as data. `EnemyModel` builds the bones; `Fx/EnemyRig` plays Run by the hitbox's pace and a Dash fitted to each lunge.
4. Its `EnemyDesigns` body: `meshId`, `textureId`, `rig`, scaled to the hitbox; eyes ride a bone (`bone = "Head"`, `eye = true`).
5. Check in Studio that the bones are built, the legs swing, the eyes stay on the head.

**Pitfalls seen:** a skinned mesh resized without its bones crushes the head into the body (`EnemyRig` scales the bones with every squash); the importer may not bring the clips (use the `.rbxmx`); a tween played twice on one property cancels the first.

## 3. A boss

As an enemy model (1), with its moves: a `boss` block in its `EnemyConfig`, each move a pure timeline in `Enemies/BossMoves` (pinned by `BossMoves.spec`), its body posed by `Enemies/BossBody`, every hit resolved in `EnemyManager` through `RunSession.applyDamage`, and every warning drawn by `TelegraphRenderer`. Port the handoff's motion numbers (its studs × the size ratio), never its `wait()`-based scripts. Room 10 of its level holds it alone (`Level1.spec` is the model).

**A boss whose body plays its own clips** (King Bloblin, 2026-10-24): one Claude Design rig carrying every clip of the fight, played on the beats the server keeps.

**Owner:** imports the merged GLB (File → Import 3D, Merge Meshes off) with its parts separate.

**Claude:**
1. The GLB goes in `assets/models/bosses/<name>/` and into `assets/models/model_clips.json` as `{ "glb": ..., "loops": [...] }`: only the resting clips (Idle, Winded) loop; every beat plays once and holds its last frame. `python -I tools/glb_clips_to_luau.py` → `Config/ModelClips/<Name>`.
2. Dump the import (`tools/studio/dump_models.luau` in Edit; a single import fits one return) into `assets/models/model_imports.json` under a key of its own (`KingBloblin_Fight#43`). `python -I tools/imports_to_luau.py` → `Config/ImportedModels/<Name>` (anything not under `assets/models/pets/`), each part with its GLB material's name (`surface`).
3. `EnemyDesigns.Imported[<displayName>]` names the model and its clips, the eye pattern and colour, and the joint a lash stretches. `EnemyModel.designFor` builds it scaled to fill the hitbox; the design keeps only its shadow. `EnemyDesigns.spec` measures it as built.
4. The boss's `clips` in `Balance` map each phase of each move to a clip (per arm for a lash). The server sets `ModelClip`, `ModelClipAt` (server time the clip began) and `ModelClipSpan` (the seconds it is to last) as each beat starts, and `ModelClipStretch` for the chain; `Fx/ModelAnimator` plays it on every client in step, `BossBody` only keeps the shadow on the floor. `BossClips.spec` pins the order of the clips, that each lasts its phases, and that the chain's fist lands at the lane's end.
5. Effects the GLB cannot carry are code: the warnings and impacts in `Fx/BossFx` (cubes and tiles, numbers in `Balance.Telegraph.king`, decoration scaled by the tier's `bossFxShare`), and the colour beats (eyes, gems, the arm's glow) read off the clip being played.

**Pitfalls seen:**
- **A part tucked away at a thousandth of its size** (his lash links, laid out down the lane at rest) imports clamped to 0.001 studs. `imports_to_luau.py` takes its true size from the GLB, `EnemyModel` sets it as `RestSize`, and `ModelAnimator` scales that, not the clamped size. Left in the bounds, those parts would also shrink him to fit a lane 17 studs long: `EnemyModel` leaves tucked parts out.
- **A node's second primitive imports with "2" on its name** (`Body2`, and `LashLink_1`'s arrives as `LashLink_12`, colliding with the real one). The matcher pairs them by place and size; never trust an import's names past the first primitive.

## 4. An arena

**Owner:** Claude Design arena GLB → later imports the slimmed one.

**Claude:**
1. `optimise_arena.py <in> <out> <arena>`: textures to vertex colours, scattered tufts thinned, merged into a few groups under 20,000 triangles each, scaled ×2.7 into the 35 × 58 room.
2. After the import: `ArenaModels` entry (parts, `surround`, `outsideColor`, `ambience`), cover as obstacle boxes in the level's rooms (`Balance`) at the model's positions, a `PlayerWall` over every piece of cover.
3. **Swaying trees:** `split_trees.py` splits a forest's merged `Trees` mesh into single trees by trunk; owner imports `*_trees_roblox.glb` (Merge Meshes off); `dump_imports.luau` → `tree_ids.json` → `trees_to_luau.py` → `Config/ArenaTrees`. `ArenaTrees.spec` keeps every tree out of the room.
4. **Or a kit** (the blocky Mossy Glade): the owner's pieces, one GLB each → `kit_bundle.py <folder> <out.glb>` merges each piece's parts into one mesh with its colours baked on (glowing parts apart) → the owner imports the one file → ids into `Config/ArenaKits` → an `ArenaModels` entry with `kit` and `lowCover`. `Shared/Util/KitLayout` builds every room from the kit to its own cover boxes; `KitLayout.spec` keeps paths and plants out of cover, the start and the gate.
5. **An outer forest** (the scenery past the walls; the glade's, Thornwood's): Codex master and kit sheets (`assets/concepts/blocky/arenas/area0N_*_ambience*.jpg`) → one Claude Design model in the room's frame at 1 unit = 1 stud with a hole over the room and both gate lanes clear → its own `*.glb` export → optionally `srgb_glb.py <in> <out>` (Claude Design stores vertex colours linear; imported raw, every colour comes in darker and redder than designed, which the owner chose for Thornwood) → the owner imports `*_outer_arena_roblox.glb` (Merge Meshes off) → `tools/studio/dump_forest.luau` (set `FOREST`) → `*_outer_ids.json` → `python -I tools/forest_to_luau.py [thornwood]` → `Config/<Area>Forest`, used as the area's `ArenaModels` `parts`, with its own `Balance.Ambience` entry. Claude Design's live viewer is too heavy for the Chrome tools to screenshot: download the project's archive (Share → Project HTML → archive) and render and export it headless with Playwright.
6. Check: the camera never sees the void, cover blocks walking but low cover not arrows, nothing flickers (two surfaces on one plane).

## 5. A weapon (model and R15 animation kit)

**Owner:** the weapon GLB and its R15 kit (`*_R15_Kit.rbxmx`, KeyframeSequences) from Claude Design.

**Claude:**
1. `optimise_weapon.py` for the model; owner imports it; part ids into `Config/Weapons`. Its glow group (`Gems`, or `Glow` on the Worldroot Staff) gets `glow = true`, so it is drawn Neon (`HeldWeapon`): parts land in it by name (`GLOWS`, never a housing, socket, cap or frame) or because their material glows (emissive 0.45 and up). A projectile's glow group is drawn the same way.
2. `kit_to_json.py <kit.rbxmx> <Prefix_> <out.json>` → the weapon's `*_animations.json` (kit beside it, force-added). Layer one-clip-at-a-time fixes in a small script if the kit layers clips (`leaf_bow_dual_r15/layer_clips.py`).
3. `weapon_animations_to_luau.py` → `Config/WeaponAnimations.luau`; its clips named in `Config/Weapons.clips` (`hold`, `ready`, `aim`, `fire`, `legs`, `special`, `afterFire`).
4. Check in Studio: the joints move as the kit's markers say (`Hit`, `Release`, `Cast`), and the server's timing lands on them (`WeaponTiming`, `ClassCards.spec`).

## 6. A card or Mythic

`Config/Abilities` (data: rarity, levels, stat lines, `classes`, `weapon` for a held-weapon change), its effect as a pipeline stage or an `AbilityEffects` stat — never an `if` on the card's name in combat code — and an area attack through `Combat/AreaStrikes` with its look in `Fx/MythicFx`. Icon: Codex art, uploaded, id in `CardAssets`. `ClassCards.spec` checks the pools.

## 7. A sound

1. Make takes: `assets/audio/synth.py` (from scratch) or `freesound.py` (CC0 only, licence checked per sound; a game's ripped audio is never used, only measured against).
2. Audition page: `build_page.py` → published artifact; the owner's picks save to its database (`ArtifactData`).
3. **One upload per batch:** join the picks into one sprite (`assets/audio/sprite.py`; each sound a `region` of it in `Config/Sounds`). Roblox allows 20 audio uploads a day and 100 a month, and the owner's are scarce: see the budget below.
4. Owner uploads the sprite to Roblox; Claude finds the id (`search_asset`, scope user) and puts it in `Config/Sounds`. An empty id is silent, so hooks are wired first.

**Audio upload budget** (owner, 2026-10-25: "i only have 27 audio uploads left so make sure you keep track of that"): **26 left** (2026-10-25, after the Warden sprite `warden_sprite_r19.mp3`). Before asking for an upload, say what it costs and what would be left; after it, update this line in the same PR. Bundle pending sounds into one upload rather than uploading as each is picked.

## 8. Concept art and images

Codex image generation, always (owner's rule): `codex exec` with the prompt on stdin and `-i` for reference images, signed in with the owner's account. Sheets go in `assets/concepts/`. The look is the **blocky** style (owner, 2026-10-23) for everything new.

**Uploading images needs no owner step** (2026-10-24): serve the PNGs from localhost (`python -m http.server <port> --bind 127.0.0.1` in their folder) and call Studio MCP's `upload_image` with `http://localhost:<port>/<file>.png` paths; it returns the `rbxassetid://` ids. Codex's own sandbox cannot write into a worktree: its image lands in `~/.codex/generated_images/<id>/exec-*.png`, named in its log. Animated icons are 2x2 sheets of 512 px frames (1024 px, Roblox's largest), played with `ImageRectOffset` (`UI/BossBanner`).

## 9. A UI handoff (cards, end screens)

Claude Design's handoff → its frames and assets generated into `Config/Card*` / `Config/EndScreen*` by script (regenerate, never hand-edit), images uploaded and ids in `CardAssets` / `EndScreenAssets`, motion in code from its timeline.

## 10. A Claude Design model's own animations (pets, enemies)

Claude Design's 3D models carry their clips (Idle, Hop, Follow, an attack…) inside the GLB as moves of joint nodes. They have no skin, so Roblox's importer does not bring the clips: they travel as data and the client plays them.

**Owner:** imports the model's GLB as usual (File → Import 3D), keeping its parts' names. No rig, no animation import needed.

**Claude:**
1. Keep the GLB in the repo (`assets/models/pets/forest/<name>.glb`, `assets/models/enemies/...`) and list it in `assets/models/model_clips.json` under the game's name for it (`EmberWilfPet`).
2. `python -I tools/glb_clips_to_luau.py` → `Config/ModelClips/<Name>.luau`: the joints, each mesh's rest place and size, and every clip's keys (thinned to the keys a straight line cannot stand in for). Regenerate, never hand-edit.
3. In the game, the model carries the CollectionService tag `ModelClips` and the attribute `ModelClips = "<Name>"`; its `ModelClip` attribute names the clip to play (the server can set it; it replicates), `ModelClipSpeed` its pace. `Fx/ModelAnimator` does the rest on the client.
4. The animator reads how the import scaled and turned the model from its parts' rest places (`Shared/Util/ModelClip.fit`), so a re-import at another size needs no change. If the parts do not line up with the data (renamed, merged, another model) it leaves the model alone and logs `ModelAnimator` a warning.
5. `tests/ModelClip.spec` pins the data's shape, the fit and how a joint's move reaches its parts.
6. **Pets in Studio before Phase 6:** after the owner imports the pet GLBs (Merge Meshes **off**), run `tools/studio/dump_models.luau` (Edit) and save its JSON as `assets/models/model_imports.json`. Its return can pass 100,000 characters, which a tool result cuts off: keep the JSON in `_G` and read it back in slices. `python -I tools/imports_to_luau.py` → `Config/PetModels/<Name>`. Studio is only trusted for the mesh ids; the script matches each import to its GLB and takes everything else from the GLB (see Pitfalls). In a Studio playtest, **P** builds them (`Server/Dev/PetPreview`, Studio only) and they follow the player playing Idle and Follow (`Fx/PetPreview`).

**Pitfalls seen:**
- **Every Claude Design import is named `AuxScene`** (the GLB's scene name), not after its file. Imports are told apart by their part names.
- **A mesh several nodes share imports once, under the first node's name**: Stumpy's four legs all arrive as `Leg_L_front`. Parts are matched to GLB primitives by place and size and renamed after their nodes.
- **Two primitives of one node become two parts**, each bounded by the vertices its own triangles use (they may share one vertex buffer).
- **Colours are dropped**: every part arrives grey (0.64). They come from the GLB's materials: base colour plus emissive times strength, Neon from a glow of 0.6.
- **A rigged import (joint nodes) places each mesh as if no node were turned**: the Mosslet's tilted leaves lie flat in Studio. Its InitialPoses folder and Motor6Ds hold the turns. A GLB without joints bakes the turn into the mesh instead. The script fits each import to both and places parts at their real rest.
- **A Follow that walks a loop in the viewer** (the root travels and turns round) would circle on the spot in the game, which moves the pet itself. `glb_clips_to_luau.py` plays any clip whose root travels over 0.3 and turns over half round on the spot, dropping that root's sideways travel and its turn about Y. It names each one it stills.
- **A re-export can regroup nodes** (the Glade Fox's runes moved under its tail joint) without moving anything. Parts are paired with nodes by name where the name is unique on both sides, checked by size; only the rest are paired by place. A re-export that adds meshes (open mouths) builds without them until the owner imports it again; the script names what is missing.
- A looping clip read at exactly its length is back at its start (`pose` wraps).
- A turn about an axis through a joint has no travel, so test travel with a lift, not a turn.

## 11. Measuring what it costs (performance)

Every model and room's numbers, and what was done about them: [PERFORMANCE.md](PERFORMANCE.md).

1. A new or changed GLB: `python -I tools/glb_stats.py <glb>`. A clip-driven model's part count is what `Fx/ModelAnimator` moves every frame and what the importer makes (Merge Meshes off keeps every primitive a part); a static one should be merged to a few parts by its optimiser before import, as the kits and weapons are.
2. A room: Play, focus Studio, run `tools/studio/perf_room.luau` with its `ROOM`. Compare against the table in PERFORMANCE.md.
3. A phone's budgets: set the Workspace attribute `DevTier` to `"Low"` in Edit, then Play (`client/Device`, Studio only). Anything a phone cannot afford is a `DeviceTiers` number, never a code path.
4. Per-frame code: move many parts in one `Workspace:BulkMoveTo`, read a model's parts and attributes once when it is built rather than every frame, and only set `Size` when it changes.

**Pitfalls seen:** Studio renders nothing while its window is in the background, so frame counts read zero and captures come back black. A long execute_luau call on the Play client that never yields fails with "Target is not reachable". The script profiler's numbers compare two runs of one scene; they are not milliseconds.

