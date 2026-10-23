# Handoff: Ruby Greatsword — two-handed R15 weapon, combo animations and hit box

## Overview
A two-handed greatsword for an Archero-style Roblox game (Mossy Glade set). This bundle has everything needed to get it working on an **R15** character:
- the greatsword mesh (`.glb`, Roblox-ready),
- six R15 animations as KeyframeSequences in a `.rbxmx`: a shoulder-rest Hold, a blade-dragging Walk, and a 3-hit heavy combo,
- two Luau scripts: one welds the sword to the RightHand and adds a swing Trail; one plays the idle and the combo, toggles the trail and runs a hit box on each swing.

The goal for Claude Code is to **integrate these into the game's existing Roblox project** (Rojo or plain Studio), hook up damage and targeting, and adjust as needed. The `.lua` and `.rbxmx` files are working starting points, not final production code. They have **not been run in Studio yet**.

## Fidelity
High fidelity for the mesh (final shape, colours and part names). The animations are a solid first pass: poses were solved with IK on a blocky R15 stand-in (shoulders 2 studs wide, standard R15 joint offsets). The **left hand** is solved onto the lower grip from the right hand's sword pose, and stays within about 0.13 studs of it. Expect small tweaks in the Animation Editor on real avatars, especially where the right hand lands up to ~0.2 studs from its target at the extremes of a swing.

## Folder contents
```
assets/
  ruby_greatsword_roblox.glb   8 MeshParts, baked colour textures, ~4.0k tris total
roblox/
  RubySword_R15_Kit.rbxmx      Folder "RubySwordKit": RubySwordAnimations (5 KeyframeSequences) + both scripts
  RubySwordEquip.server.lua    same server script as inside the kit
  RubySwordAnimator.client.lua same client script as inside the kit
  ruby_greatsword_animations.json  raw keyframes (joint quaternions per key)
source/                        HTML/JS prototype (reference only)
  Ruby Sword.html              model sheet + swing/trail preview
  Ruby Sword R15.html          R15 animation preview + kit export
  ruby-sword-model.js          sword geometry, swing trail, Roblox bake
  r15-sword-anims.js           greatsword keyframes (IK goals) + Luau generation
  r15-bow-anims.js             shared R15 rig, IK solver, sampler, .rbxmx writer
  leaf-bow-model.js, moss-slime-model.js, three-d-stage.js   shared helpers / viewer
reference/ruby_greatsword_concept.png
```

## Studio setup
1. **Import**: File → Import 3D → `assets/ruby_greatsword_roblox.glb`. Keep the default orientation. Rename the Model **`RubySword`** and move it into **ReplicatedStorage**. It must keep a MeshPart named **`Grip`**.
2. **Insert the kit**: right-click ServerStorage → Insert from File → `roblox/RubySword_R15_Kit.rbxmx`.
3. Move `RubySwordAnimations` → **ReplicatedStorage**. Move `RubySwordEquip` (Script) and `RubySwordAnimator` (LocalScript) → **StarterPlayer → StarterCharacterScripts**.
4. Play-test. In Studio the animations load straight from the KeyframeSequences (`KeyframeSequenceProvider`). That **only works in Studio**.
5. **Before publishing**: right-click each `Sword_*` KeyframeSequence → Save to Roblox, and paste the ids into `ANIM_IDS` at the top of `RubySwordAnimator`.

## Conventions
- **Size**: the equip script scales the model to **5.05 studs** from pommel to tip (`SWORD_HEIGHT`), which is 4.0 studs per model unit. It stores `StudsPerUnit` as an attribute on the model.
- **Model axes**: origin = grip centre, blade along **+Y**, flats face ±Z, edges along ±X.
- **Two-handed grip**: the **RightHand** holds the upper grip (model Y = +0.062) and the **LeftHand** holds the lower grip (model Y = −0.07).
  - The RightHand is welded: `C0 = CFrame.new(0, -0.1, 0) * CFrame.Angles(-π/2, 0, 0) * CFrame.Angles(0, π/2, 0)` and `C1 = CFrame.new((GRIP_POINT − GRIP_CENTER) * S)`, with `GRIP_CENTER = (0, −0.0041, 0)`. This puts the blade along the hand's −Z and the cutting edge along the hand's −Y.
  - The LeftHand is **not** welded. The animations place it on the lower grip.
- **Attachments on `Grip`**: `SwordOrigin` (model origin), `TrailBase` (25% up the blade, model Y 0.4400) and `TrailTip` (model Y 1.0216).
- **Trail** `SwingTrail` between them: red gradient RGB 255,120,100 → 216,35,47, Lifetime 0.16, LightEmission 0.8, **Enabled = false** by default.

## Animations
All are R15 KeyframeSequences. Poses are relative to the default Motor6D C0/C1. Easing between keys is Cubic InOut. Every slash has the markers **`TrailOn`**, **`Hit`** and **`TrailOff`**.

| Name | Length | Loop | Priority | Joints | Keys / markers |
|---|---|---|---|---|---|
| Sword_Hold | 2.4 s | yes | Action | both arms | standing idle: blade resting on the right shoulder, held in both hands at the chest |
| Sword_Walk | 1.0 s | yes | Action | full body | one-handed drag: the right arm hangs back with the blade trailing behind at ~35° and the tip on the ground (solved per key so the tip touches y≈0). Heavy forward-leaning stride (hips ±30°, waist lean 12°, torso counter-twist ±9°, bob 0.16), and the left arm swings opposite the left leg. Natural speed ≈ 6 studs/s |
| Sword_Slash_A | 0.75 s | no | Action2 | full body | heavy horizontal sweep, right → left. Wind-up at the right hip (TrailOn 0.20), Hit 0.33, follow-through to the left hip (TrailOff 0.46), recover to guard by 0.75 |
| Sword_Slash_B | 0.70 s | no | Action2 | full body | rising diagonal backswing, low-left → high-right. TrailOn 0.18, Hit 0.30, TrailOff 0.42, guard by 0.70 |
| Sword_Slash_C | 0.95 s | no | Action2 | full body | overhead slam: blade raised behind the head (TrailOn 0.30), slam to forward-down with a crouch (Hit 0.44), ground impact (TrailOff 0.56), back to the shoulder rest by 0.95 |

## Runtime behaviour (RubySwordAnimator)
- Sword_Hold loops at Action priority while standing. Slashes play over it at Action2 and are not looped.
- **Walk**: on Heartbeat, if `MoveDirection` > 0.05, planar velocity > 0.5 and the character is grounded (and not swinging), Hold → Walk is crossfaded over 0.25 s. Its speed is set with `AdjustSpeed(clamp(planarSpeed / WALK_ANIM_SPEED, 0.6, 2.2))`, where `WALK_ANIM_SPEED` = 6. Stopping crossfades back to Hold. Sword_Walk is full-body at Action priority, so it **overrides the default Animate walk/run**. Starting a swing stops Walk.
- **Drag sparks**: the server adds a `DragTip` Attachment at the blade tip with a `DragSparks` ParticleEmitter (orange, LightEmission 1, rate 45, gravity −35). The client enables it only while Walk plays.
- `attack()` plays `COMBO[comboIndex]` (A → B → C → A …) with a 0.05 s fade and `SPEED` (1.0; raise it for attack-speed upgrades). It is ignored while a swing is playing.
- The combo resets to A if more than `COMBO_RESET` (0.6 s) passes after a swing ends.
- `TrailOn` / `TrailOff` set `SwingTrail.Enabled`. `Stopped` also turns the trail off.
- `Hit`: `workspace:GetPartBoundsInBox(HumanoidRootPart.CFrame * CFrame.new(0, 0, −HITBOX.Z/2), HITBOX, params)` with `HITBOX = (9, 6, 8)` studs, excluding the character. It collects living Humanoids, de-duplicated, and calls `onHit(humanoids, swingName)`.
- **Auto-attack** (`AUTO_ATTACK = true`, Archero style): attacks whenever `humanoid.MoveDirection` ≈ 0 and `hasTarget()` is true. Manual mode is MouseButton1 / ButtonR2.

## TODO for integration
- `hasTarget()`: return whether an enemy is alive in the room.
- `onHit(humanoids, swing)`: fire a RemoteEvent; the server must re-validate the range or hit box and apply damage. Consider extra damage on Slash_C.
- Face the nearest enemy before each swing (set the HumanoidRootPart CFrame or use `AlignOrientation`). Not included.
- A two-hander usually slows movement while swinging: lower `humanoid.WalkSpeed` between `TrailOn` and the end of the swing if wanted.
- With the default WalkSpeed 16 the walk plays at ~2.2× (clamped), which looks rushed for a drag. Set `humanoid.WalkSpeed` to ~8–10 while the greatsword is equipped for the intended heavy feel, or raise `WALK_ANIM_SPEED`.
- Optional: add a looping metal-scrape Sound on `DragTip`, played while `DragSparks.Enabled`.
- No separate run cycle. If the game has sprint, add a faster variant or reuse Walk with a higher AdjustSpeed.
- Add impact VFX/SFX on `Hit` (e.g. a ParticleEmitter burst at the hit box front, and camera shake on Slash_C).
- The trail is enabled from the client. Trails on character parts replicate visually, but if you want the server to own it, move the Enabled toggling to the server via the markers.

## Mesh parts
`Blade`, `Fuller` (red inlay), `Gold_Trim` (fuller border, guard diamond frames, crescents, collars, pommel ring + spikes), `Guard` (gunmetal block), `Horns` (red curls), `Grip` (leather wrap, weld root), `Pommel` (gunmetal disc), `Gems` (guard rubies + pommel rubies).
Gold has metalness 0.7. The Blade has metalness 0.3. Guard and Pommel have metalness 0.45. Gems use their colour map as emissive.

## Colours
| Name | Hex |
|---|---|
| Blade steel | #E6E8EC |
| Ruby red | #D8232F |
| Deep red | #8E1420 |
| Gunmetal | #45474F |
| Gold | #E4B25A |
| Leather | #8E2A2A |
| Dark leather | #4A2A26 |

## Regenerating
Open `source/Ruby Sword R15.html` in a browser (serve the folder over http) and use **Download Roblox kit (.rbxmx)**. `source/Ruby Sword.html` re-exports the `.glb`. To change poses, edit `defs` in `r15-sword-anims.js → bakeSwordAnimations()`. Right-hand targets are offsets from the right shoulder in studs, blade/edge directions are vectors, and body angles are in degrees. The left hand is always re-solved onto the lower grip.

## Mythic upgrades (Earthbreaker + Meteor)
`roblox/MythicAbilities.server.lua` is the same file in the Greatsword and Arcane Staff bundles. Install it once, as a Script in ServerScriptService. It creates `ReplicatedStorage.MythicRemotes`, then validates and applies damage and VFX for both abilities.
- **Ownership:** `ownsMythic(player, name)` checks the player attribute `Mythic_Earthbreaker` / `Mythic_Meteor`.
- **Damage:** `baseDamage(player)` reads the player attribute `BaseDamage` (default 10).
- **Targets:** `isEnemy(model)` counts any non-player Humanoid.
- **Swap these three helpers for your own systems.**

**Earthbreaker (Greatsword):** `Sword_Earthbreaker`, 1.3 s, Action4, with markers `Leap` 0.20, `TrailOn` 0.50, `Impact` 0.56 and `TrailOff` 0.62.
1. When a dash ends, your dash code fires `character.EarthbreakerSlam:Fire(dashEndPosition)`.
2. The animator plays the slam. On `Leap` it pushes the HumanoidRootPart to the end point over 0.36 s. The vertical arc is in the animation.
3. On `Impact` it fires `MythicRemotes.Earthbreaker`.
4. The server then deals 1.5× base damage in radius 7 and leaves glowing cracks. Rock spikes erupt every 0.5 s for 3 s, each tick dealing 0.4× base damage in the same radius.

**Meteor (Arcanist):** `Staff_Meteor`, 1.25 s, Action4, with markers `Summon` 0.30 and `Point` 0.70.
1. Fire `character.CastMeteor:Fire(targetPosition)` when the mythic triggers.
2. The animator turns to the target and plays the cast. On `Summon` it fires `MythicRemotes.Meteor`.
3. The server shows a red warning circle (radius 6) that fills over **0.9 s** while the meteor falls.
4. On impact it deals **4× base damage** in radius 6, with a flash, shockwave and fading scorch.

**Preview:** the **Earthbreaker (mythic)** button in `source/Ruby Sword R15.html`, and the **Meteor (mythic)** button in `source/Arcane Staff R15.html`.
**Not specified, so I picked values:** Earthbreaker radius 7, slam 1.5×, ticks 0.4×. All are in the `EARTHBREAKER` table.

## Red slash VFX + reworked combo
**The combo was reworked so every swing has more weight:**
- **Slash_A** (0.85 s): coils and holds before swinging, steps in fast for the strike, overshoots and settles.
- **Slash_B** (0.82 s): coils low, then makes a rising backswing with a step, overshooting high.
- **Slash_C** (1.05 s): raises the sword and hangs at the top, steps into the slam and crouches, recoils with a bounce, then recovers.

The markers are still `TrailOn`, `Hit` and `TrailOff`. If you already saved the animations to Roblox, re-publish them.

**Slash crescents:** `assets/ruby_slash_fx.glb` has three crescent MeshParts (`Slash_A`, `Slash_B`, `Slash_C`). Each one is shaped to its swing's blade path, using a red gradient texture (also included separately as `ruby_slash_texture.png`).

**Setup:**
1. Import the .glb.
2. Put the three parts in a Folder or Model named **`RubySlashFX`** in ReplicatedStorage.
3. Check that each part kept its texture. If it didn't, set TextureID to the uploaded PNG.

**In game:** on each swing's `Hit` marker, `RubySwordAnimator` clones the matching crescent and places it at `HumanoidRootPart.CFrame * centre`. It sets the size from the `SLASH` table, adds a red PointLight, and fades it out over 0.26 s while it grows 8%. In the browser preview, the crescent instead builds along with the blade from `TrailOn` to `TrailOff`.
