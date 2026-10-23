# Handoff: Leaf Bow — R15 weapon, animations and shooting

## Overview
A player bow for an Archero-style Roblox game (Mossy Glade set). This bundle has everything needed to get it working on an **R15** character:
- the bow and arrow meshes (`.glb`, Roblox-ready),
- four R15 animations (Hold, Draw, Aim, Fire) as KeyframeSequences in a `.rbxmx` model file,
- two Luau scripts: one welds the bow to the LeftHand, one plays the animations, draws a live string and fires arrows.

The goal for Claude Code is to **integrate these into the game's existing Roblox project** (Rojo or plain Studio), hook up damage and targeting, and adjust as needed. The `.lua` and `.rbxmx` files are working starting points, not final production code. They have **not been run in Studio yet**.

## Fidelity
High fidelity for the meshes (final shape, colours and part names). The animations are a solid first pass: arm poses were solved with IK on a blocky R15 stand-in (shoulder 2 studs wide, standard R15 joint offsets). Expect small hand-position tweaks in the Animation Editor on real avatars.

## Folder contents
```
assets/
  leaf_bow_roblox.glb      bow — 12 MeshParts, baked colour textures, every mesh < 20k tris
  leaf_arrow_roblox.glb    arrow — 5 MeshParts
roblox/
  LeafBow_R15_Kit.rbxmx    Folder "LeafBowKit": LeafBowAnimations (4 KeyframeSequences) + both scripts
  LeafBowEquip.server.lua  same server script as inside the kit (for Rojo / source control)
  LeafBowAnimator.client.lua same client script as inside the kit
  leaf_bow_animations.json raw keyframes (joint quaternions per key), useful if you want to rebuild or edit the animations in code
source/                    HTML/JS prototype the assets were generated from (reference only)
  Leaf Bow.html            model sheet + draw/fire preview
  Leaf Bow R15.html        R15 animation preview + kit export
  leaf-bow-model.js        bow/arrow geometry, Roblox bake
  r15-bow-anims.js         R15 rig, IK, keyframes, .rbxmx + Luau generation
  moss-slime-model.js      shared bake helper (vertex colours → texture)
  three-d-stage.js         3D viewer used by the HTML pages
reference/leaf_bow_concept.png  original concept art
```

## Studio setup
1. **Import meshes**: File → Import 3D → `assets/leaf_bow_roblox.glb`, then `leaf_arrow_roblox.glb`. Keep the default orientation. Rename the resulting Models to **`LeafBow`** and **`LeafArrow`** and move both into **ReplicatedStorage**. The bow must keep a MeshPart named **`Grip`**.
2. **Insert the kit**: right-click ServerStorage → Insert from File → `roblox/LeafBow_R15_Kit.rbxmx`.
3. Move `LeafBowAnimations` → **ReplicatedStorage**. Move `LeafBowEquip` (Script) and `LeafBowAnimator` (LocalScript) → **StarterPlayer → StarterCharacterScripts**.
4. Play-test. In Studio the client loads animations straight from the KeyframeSequences via `KeyframeSequenceProvider:RegisterKeyframeSequence`. That **only works in Studio**.
5. **Before publishing**: right-click each `Bow_*` KeyframeSequence → Save to Roblox, and paste the resulting `rbxassetid://` ids into `ANIM_IDS` at the top of `LeafBowAnimator`.

With Rojo: map `roblox/*.lua` into `StarterPlayer/StarterCharacterScripts`, and keep the KeyframeSequences/meshes as `.rbxm`/`.rbxmx` model files (or publish the animations and use ids only).

## Conventions
- **Units**: model units × `StudsPerUnit` = studs. The equip script scales the bow so it's **4.22 studs tip to tip** (`BOW_HEIGHT`) and sets the attribute `StudsPerUnit` on the bow model (≈ 3.8).
- **Bow axes** (model space): origin = grip centre, **−Z = shooting direction**, +Y = up, the string is on the +Z side, and the arrow rests on the −X side.
- **Weld**: `LeftHand → Grip`, `C0 = CFrame.new(0, -0.15, 0) * CFrame.Angles(-π/2, 0, 0)`. With the hand pointing down, the bow sits upright and faces forward.
- A `BowOrigin` Attachment is created on `Grip` at the model origin. The client uses it to place the string and arrow.

Key bow points (model units, from `leaf-bow-model.js`):
| Point | Value |
|---|---|
| String anchor, top | (0, 0.4070, 0.1685) |
| String anchor, bottom | (0, −0.4001, 0.1701) |
| Rest nock (string centre) | (−0.045, 0.108, 0.1691) |
| Arrow rest on riser | (−0.045, 0.108, −0.05) |
| Arrow length | 0.864 |
| Bow height | 1.1105 |

## Animations
All are R15 KeyframeSequences. Poses are relative to the default Motor6D C0/C1.

| Name | Length | Loop | Priority | Joints | Notes |
|---|---|---|---|---|---|
| Bow_Hold | 2.4 s | yes | Action | both arms (shoulder, elbow, wrist) | bow held low and forward. Arms only, so it layers over walk/run |
| Bow_Draw | 0.45 s | no | Action2 | full body | turns side-on (Root Y −35°, Waist −30°, Neck +55°), raises the bow. Marker **`Nock`** at 0.16 s = right hand reaches the string. Ends at full draw by the chin |
| Bow_Aim | 1.2 s | yes | Action2 | full body | holds full draw with a slight sway |
| Bow_Fire | 0.42 s | no | Action2 | full body | marker **`Release`** at 0.03 s, then the right hand flicks back and the bow arm drops |

Keyframe times and markers come from `r15-bow-anims.js → bakeAnimations()`. Easing between keys is Cubic InOut.

## Runtime behaviour (LeafBowAnimator)
State machine: `idle → drawing → aiming → firing → idle`.
- **idle**: Bow_Hold plays all the time.
- **startDraw()**: plays Bow_Draw. At the `Nock` marker it sets `engaged = true` and the arrow appears.
- When Draw finishes: state is aiming and Bow_Aim loops.
- **release()**: plays Bow_Fire. At the `Release` marker it clones the arrow and moves it along its LookVector at `ARROW_SPEED` (90 studs/s) up to `ARROW_RANGE` (80 studs), calls `onShot(origin, direction)`, and the string wobbles (amplitude 0.07·S, decay e^(−9t), frequency 55 rad/s, 0.6 s).
- **Auto-fire** (`AUTO_FIRE = true`, Archero style): draws whenever `humanoid.MoveDirection` ≈ 0 and `hasTarget()` is true; releases after `AIM_TIME` (0.12 s) at full draw; moving cancels.
- Manual mode: MouseButton1 / ButtonR2 hold to draw, release to fire.
- **String**: the exported `String_Upper` / `String_Lower` meshes are hidden. Two cylinder Parts in `workspace.CurrentCamera` are rebuilt every RenderStepped from `BowOrigin` × anchors → nock point. The nock point is `RightHand.CFrame * (0, −0.1, 0)` while engaged, otherwise the rest nock.
- The nocked arrow points from the nock towards the arrow rest.

## TODO for integration
- `hasTarget()`: return whether an enemy is alive in the room.
- `onShot(origin, direction)`: fire a RemoteEvent; the server should raycast or spawn the projectile and apply damage. The current flying arrow is a client-only visual.
- Face the nearest enemy while aiming (e.g. set `HumanoidRootPart` CFrame or use `AlignOrientation`). Not included.
- The live string and nocked arrow are **local only**. To show them to other players, run the same RenderStepped logic in a LocalScript for every character holding a bow, or replicate a "draw amount" attribute.
- Check Bow_Hold on your avatar scale (R15 proportions vary). If the bow clips the leg, adjust the LeftWrist rotation in the Animation Editor.
- Upgrade cards (Multishot, Rear Arrow, Diagonal, etc.) should spawn extra arrows in `launch()` with rotated directions.

## Bow mesh parts
`Riser`, `Grip`, `Limb_Upper`, `Limb_Lower`, `Leaf_Upper`, `Leaf_Lower`, `Leaf_Wrap_Upper`, `Leaf_Wrap_Lower` (cream string wrap), `Gold_Trim`, `Gold_Trim_Upper`, `Gold_Trim_Lower`, `Gem`, `String_Upper`, `String_Lower`.
Arrow: `Shaft`, `Arrowhead`, `Fletching`, `Arrow_Wraps`, `Nock`.
Gold and steel parts have metalness 0.6–0.7. The gem uses its colour map as emissive. Add a PointLight in Studio for extra glow if needed.

## Colours
| Name | Hex |
|---|---|
| Bow wood | #C87A32 |
| Dark wood | #6B4226 |
| Gold | #C9A23A |
| Grip green | #3F6B3A |
| Leaf green | #8DC04E |
| Bowstring / cream | #EDE3CC (string Part uses RGB 236, 226, 199) |
| Steel | #9AA0A8 |

## Regenerating
Open `source/Leaf Bow R15.html` in a browser (serve the folder over http). It rebuilds the rig, solves the IK and offers **Download Roblox kit (.rbxmx)**. `source/Leaf Bow.html` re-exports the `.glb` files. To change poses, edit the `defs` table in `r15-bow-anims.js → bakeAnimations()` (hand targets in studs, body joint angles in degrees).
