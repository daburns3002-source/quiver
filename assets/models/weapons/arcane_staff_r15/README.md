# Handoff: Arcane Staff — R15 weapon, animations and casting

## Overview
A player staff for an Archero-style Roblox game (Mossy Glade set). This bundle has everything needed to get it working on an **R15** character:
- the staff and bolt meshes (`.glb`, Roblox-ready),
- four R15 animations (Hold, Charge, Channel, Cast) as KeyframeSequences in a `.rbxmx` model file,
- two Luau scripts: one welds the staff to the RightHand, one plays the animations, charges the orb (spin, swell, glow) and fires bolts.

The goal for Claude Code is to **integrate these into the game's existing Roblox project** (Rojo or plain Studio), hook up damage and targeting, and adjust as needed. The `.lua` and `.rbxmx` files are working starting points, not final production code. They have **not been run in Studio yet**.

## Fidelity
High fidelity for the meshes (final shape, colours and part names). The animations are a solid first pass: arm poses were solved with IK on a blocky R15 stand-in (shoulders 2 studs wide, standard R15 joint offsets). Expect small hand-position tweaks in the Animation Editor on real avatars.

## Folder contents
```
assets/
  arcane_staff_roblox.glb   staff — 10 MeshParts, baked colour textures, ~7.7k tris total (largest mesh 2.8k)
  arcane_bolt_roblox.glb    bolt projectile — 1 MeshPart
roblox/
  ArcaneStaff_R15_Kit.rbxmx Folder "ArcaneStaffKit": ArcaneStaffAnimations (4 KeyframeSequences) + both scripts
  ArcaneStaffEquip.server.lua   same server script as inside the kit (for Rojo / source control)
  ArcaneStaffAnimator.client.lua same client script as inside the kit
  arcane_staff_animations.json  raw keyframes (joint quaternions per key)
source/                     HTML/JS prototype the assets were generated from (reference only)
  Arcane Staff.html         model sheet + charge/cast preview
  Arcane Staff R15.html     R15 animation preview + kit export
  arcane-staff-model.js     staff/bolt geometry, Roblox bake
  r15-staff-anims.js        staff keyframes (IK goals) + Luau generation
  r15-bow-anims.js          shared R15 rig, IK solver, sampler, .rbxmx writer
  leaf-bow-model.js         shared geometry helpers
  moss-slime-model.js       shared bake helper (vertex colours → texture)
  three-d-stage.js          3D viewer used by the HTML pages
reference/arcane_staff_concept.png  original concept art
```

## Studio setup
1. **Import meshes**: File → Import 3D → `assets/arcane_staff_roblox.glb`, then `arcane_bolt_roblox.glb`. Keep the default orientation. Rename the Models **`ArcaneStaff`** and **`ArcaneBolt`** and move both into **ReplicatedStorage**. The staff must keep MeshParts named **`Shaft`**, **`Orb`** and **`Orbit_Orb_1..3`**.
2. **Insert the kit**: right-click ServerStorage → Insert from File → `roblox/ArcaneStaff_R15_Kit.rbxmx`.
3. Move `ArcaneStaffAnimations` → **ReplicatedStorage**. Move `ArcaneStaffEquip` (Script) and `ArcaneStaffAnimator` (LocalScript) → **StarterPlayer → StarterCharacterScripts**.
4. Play-test. In Studio the client loads animations straight from the KeyframeSequences via `KeyframeSequenceProvider:RegisterKeyframeSequence`. That **only works in Studio**.
5. **Before publishing**: right-click each `Staff_*` KeyframeSequence → Save to Roblox, and paste the `rbxassetid://` ids into `ANIM_IDS` at the top of `ArcaneStaffAnimator`.

With Rojo: map `roblox/*.lua` into `StarterPlayer/StarterCharacterScripts`, and keep the KeyframeSequences/meshes as model files (or publish the animations and use ids only).

## Conventions
- **Units**: the equip script scales the staff to **4.67 studs** from spike tip to the top orbit orb (`STAFF_HEIGHT`), which is 3.4 studs per model unit. It stores `StudsPerUnit` as an attribute on the staff.
- **Staff axes** (model space): origin = grip point (mid-shaft), +Y = up the staff, **−Z = casting direction**. The star badges and crescents face −Z.
- **Weld**: `RightHand → Shaft`, `C0 = CFrame.new(0, -0.1, 0) * CFrame.Angles(-π/2, 0, 0)`, `C1 = CFrame.new(-SHAFT_CENTER * S)` with `SHAFT_CENTER = (0, 0.0344, 0)` model units. With the hand pointing forward, the staff stands upright.
- All other parts are attached to `Shaft` with WeldConstraints, **except** `Orbit_Orb_1..3`. Those get a `Weld` named `OrbitWeld` to `Orb` so the client can spin them by changing `C0`.
- Orbit ring axis in Orb space: `ORBIT_AXIS = (0, −0.3146, 0.9492)`.
- A `StaffOrigin` Attachment is created on `Shaft` at the model origin.

## Animations
All are R15 KeyframeSequences. Poses are relative to the default Motor6D C0/C1. Easing between keys is Cubic InOut.

| Name | Length | Loop | Priority | Joints | Notes |
|---|---|---|---|---|---|
| Staff_Hold | 2.4 s | yes | Action | both arms | staff upright in the right hand, slightly forward. Off arm relaxed. Arms only, so it layers over walk/run |
| Staff_Charge | 0.5 s | no | Action2 | full body | steps into a stance (Root Y +12°, front knee bent), raises the staff forward (~29° tilt); the off hand comes up in front of the chest |
| Staff_Channel | 1.2 s | loop | Action2 | full body | holds the charged pose with a gentle bob/sway |
| Staff_Cast | 0.45 s | no | Action2 | full body | thrusts the staff forward (~46° tilt) and pushes the off-hand palm out with a 9° waist lean. Marker **`Cast`** at 0.08 s. Recovers towards Hold by 0.45 s |

## Runtime behaviour (ArcaneStaffAnimator)
State machine: `idle → charging → channeling → casting → idle`.
- **idle**: Staff_Hold plays all the time.
- **startCharge()**: plays Staff_Charge. When it finishes, Staff_Channel loops.
- **charge** goes 0 → 1 over 0.7 s while charging or channeling, eased as `c = 1 − (1 − charge)²`. Per frame (RenderStepped):
  - orbit spin speed = `0.9 + 7c` rad/s around `ORBIT_AXIS`;
  - orbit radius × `(1 − 0.22c)`;
  - orb size × `grow × (1 + 0.12c) × (1 + 0.08c·sin(30t))`;
  - PointLight brightness = `1 + 4c` and range = `8 + 6c` (colour RGB 80, 170, 255).
- **release()**: plays Staff_Cast. At the `Cast` marker it spawns `ArcaneBolt` (Neon, PointLight, Trail) at `Orb.Position`. The bolt flies along the HumanoidRootPart LookVector, flattened to the ground plane, at `BOLT_SPEED` 55 studs/s for up to `BOLT_RANGE` 70 studs, and the script calls `onCast(origin, direction, power)`. Its diameter is `0.1·S·(0.55 + 0.6·power)` studs. After casting, the orb shrinks to 45% and regrows at 1.6/s.
- Releasing within 0.15 s of starting a charge cancels it with no cast.
- **Auto-cast** (`AUTO_CAST = true`, Archero style): charges whenever `humanoid.MoveDirection` ≈ 0 and `hasTarget()` is true; casts `CHANNEL_TIME` (0.15 s) after reaching full charge; moving cancels.
- Manual mode: MouseButton1 / ButtonR2 hold to charge, release to cast.

## TODO for integration
- `hasTarget()`: return whether an enemy is alive in the room.
- `onCast(origin, direction, power)`: fire a RemoteEvent; the server should spawn or raycast the real projectile and apply damage. The current flying bolt is a client-only visual.
- Face the nearest enemy while charging (set the HumanoidRootPart CFrame or use `AlignOrientation`). Not included.
- The orb pulse and orbit spin are **local only** (client-side Weld.C0 and Size changes). To show them to other players, run the same RenderStepped logic in a LocalScript for every character holding a staff, or replicate a "charge" attribute.
- The Orb is exported solid. Set `Transparency` ≈ 0.15–0.25 and/or `Material = Glass` in Studio for a see-through look.
- Upgrade cards (Multishot, Ricochet, Piercing, etc.) should spawn extra bolts in `launch()` with rotated directions.

## Staff mesh parts
`Shaft`, `Spiral` (silver ribbon), `Silver_Trim` (spike, ferrule, collars, crescents, star badges), `Head_Cup` (navy cup + back fins), `Gems` (all blue inlays + cage crystals), `Orb`, `Orbit_Ring`, `Orbit_Orb_1`, `Orbit_Orb_2`, `Orbit_Orb_3`. Bolt: `Bolt`.
Silver parts have metalness 0.75. Gems, Orb, Orbit and Bolt use their colour map as emissive.

## Colours
| Name | Hex |
|---|---|
| Navy wood | #2E3272 |
| Violet | #5B4AA8 |
| Arcane blue | #1F8FEA |
| Glow cyan | #8FE3FF |
| Silver | #C4C8D2 |
| Gunmetal | #5C6270 |
| Moon white | #E3E7F2 |

## Regenerating
Open `source/Arcane Staff R15.html` in a browser (serve the folder over http). It rebuilds the rig, solves the IK and offers **Download Roblox kit (.rbxmx)**. `source/Arcane Staff.html` re-exports the `.glb` files. To change poses, edit `defs` in `r15-staff-anims.js → bakeStaffAnimations()`: hand targets are offsets from the shoulder in studs, staff direction is given as an "up" vector, and body joint angles are in degrees.
