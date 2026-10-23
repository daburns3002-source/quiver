# Handoff: Forest ambience around the arenas

Subtle background life for the forest arenas. It runs on the client only, so it costs no network traffic, and it never enters the fight area.

Preview: `source/Forest Ambience.html`. Every effect has its own toggle. The trees, bushes and stones in the preview are stand-ins for your real forest assets.

## Effects
| Effect | What it does | Default |
|---|---|---|
| Tree sway + gusts | Each tree sways a little (about 1°, period 9–14 s). A gust band sweeps across the map every ~10 s and makes the trees lean further (3°) as it passes. The canopy bends about 3× more than the trunk. | 30 Hz, trees within 220 studs |
| Bushes / grass | Small sway that follows the same gust band. | — |
| Falling leaves | 3 per second, from random nearby treetops. They flutter and spin down, drift with gusts, land flat, then fade after 2.5 s. Mostly green, with a few yellow and orange. | pool of 60 parts |
| Fireflies | Soft yellow-green sparkles drifting and blinking inside the forest-edge volumes. | ParticleEmitter, rate scales with volume area |
| Ground mist | Very faint, slow, wide smoke puffs low over the forest floor. | ParticleEmitter, 12–18 s life |
| Light shafts | Optional Parts you place. Their transparency breathes slowly. | — |
| Birds | A flock of 6 crosses high over the canopy every 12–25 s, flapping with short glides. | — |
| Butterflies | 6 butterflies flit low around the bushes in nearby edge volumes. | — |

## Setup (Studio)
1. Put `roblox/ForestAmbience.client.lua` in StarterPlayer → StarterPlayerScripts.
2. Tag your scenery with CollectionService:
   - **`ForestTree`** on each tree Model. Set the pivot at the trunk base. Optionally add a child named **`Canopy`** (a Part or Model), which bends more than the trunk.
   - **`ForestBush`** on bushes and grass clumps (Model or Part).
   - **`ForestEdge`** on invisible, anchored, non-colliding box Parts that cover the forest floor just outside the arena ring. Use several around the ring. Fireflies, mist and butterflies live inside these boxes.
   - **`LightShaft`** (optional) on transparent Neon cone or cylinder Parts placed between the trees.
3. To turn everything off (for example on a low-graphics setting), set the workspace attribute **`ForestAmbience`** = false.

## Tuning
Every number is in the `CFG` table at the top of the script: sway and gust strength, gust speed, leaf rate and pool size, the gap between bird flocks, butterfly count, and the cull distance.

## Notes
- Tree sway moves anchored models with `PivotTo` at 30 Hz. Only trees within `MAX_DIST` of the camera are moved, which keeps it cheap for 100+ trees. Trees must not be welded to the ground or to each other.
- Fireflies and mist use built-in Roblox textures (`sparkles_main` and `smoke_main`), so nothing needs uploading.
- Leaves land using a short raycast, so they settle on whatever floor is below them.
