# Warden blade upgrades — effects and animations

Design notes for the four Warden blade cards in `src/shared/Config/Abilities.luau`
(`group = "blade"`, plus `Bloodletting` in `group = "vital"`). Each effect was
designed in Claude Design in the blocky language — faceted, flat-shaded,
hard-edged — against the card's own icon in `assets/ui/glow_toy_cards/icons/`.

Nothing here is wired up. The GLBs sit in the owner's Downloads folder for a hand
import in Studio (File → Import 3D); uploading a mesh is not something we can do
over MCP. No config or `src/client/Fx/` changes belong in this branch.

What each card actually does, for reference (`Combat/MeleeSystem`,
`Shared/Combat/AbilityEffects`):

| id | what the server does |
|---|---|
| `HeavyBlade` | `melee.slamBonus` multiplies the combo's **last** blow only — the slam |
| `Bloodletting` | `melee.lifesteal` heals a share of every blow that lands |
| `Execute` | `melee.executeBonus` multiplies damage to an enemy under `Balance.Player.executeBelow` (30%) health |
| `Earthbreaker` | a dash ends in a leaping slam; `AreaStrikes.zone` erupts the cracked ground every 0.5 s for 3 s |

---

## Heavy Blade — Rare

**Claude Design:** https://claude.ai/design/p/aabfe733-f694-4e64-9c74-a7cd8a8028ba
**GLB:** `fx_heavyblade.glb`

Heavy Blade does not change which blow lands or where — it only makes the third
one, the slam, hit harder. So the effect extends the slam that already exists
(`Fx/SwingTrail`'s circle sweep, `Fx/BladeFx.impact`'s heavy burst and camera
shake) rather than introducing a second motion. The brief was weight in the same
swing.

The model is the slam's impact burst, read from the card icon — which is a blade
driven straight down with gold chevrons bursting out around it:

- **Twelve gold chevrons** in a radial starburst, each a stepped mirrored V with
  its tip pointing dead outward. Six large at radius 3, six small at radius 4.2,
  interleaved at 30°, so it reads as a burst rather than a wheel. This is the
  hero shape and it carries the card's own silhouette.
- **A broken crust ring** of sixteen separated grey-brown slabs at radius 2.6,
  each leaning outward at its own angle and its own height — earth shoved aside.
  Deliberately not a continuous ring: a closed donut reads as a tyre.
- **A slim pale-gold after-image spike** down the centre, six stacked cubes
  tapering to the ground with four thin fins. It stands in for the blade's path,
  not the blade — the player's actual greatsword occupies that space in game, so
  anything solid there reads as a second object parked on the effect.
- **Eight gold crack pips** thrown wide and still in the air.

In game this is a one-shot at the slam's `Hit` marker, on the same beat as the
heavy spark burst and camera shake `BladeFx` already fires.

---

## Bloodletting — Rare

**Claude Design:** https://claude.ai/design/p/7f6bbfa9-581a-4855-b493-1496f9400cb7
**GLB:** `fx_bloodletting.glb`

Lifesteal fires on *every* blow that lands, not just the slam, so this has to be
cheap and quiet enough to repeat three times a combo without becoming noise. It
also has to say where the health went, or it reads as another hit spark.

The icon is a blade, a chunky red heart, and two falling droplets. The model is
that, in motion — life torn out of the enemy and drunk by the Warden:

- **A tear-off burst** at the enemy's end: ten crimson cubes knocked loose in a
  cone opening away from the stream.
- **A stream of fourteen cubes** on a rising-then-falling arc, shrinking
  monotonically from 0.55 at the enemy to 0.18 at the Warden and graduating from
  deep oxblood to hot pink-red. The taper and the colour shift are what make it
  directional; without them it reads as a sausage, not a drain.
- **A voxel heart** at the Warden's chest, the same 8-bit heart silhouette as the
  icon's, the densest and brightest thing in the effect so it is clearly the
  destination. The last cubes of the stream touch its lower face.
- **Three spilled droplets** falling away below the arc.

---

## Execute — Legendary

**Claude Design:** https://claude.ai/design/p/31f03204-0c16-497b-bc8e-b16481d1eb3e
**GLB:** `fx_execute.glb`

The one worth real effort. Execute is a damage multiplier under 30% health, which
on its own is invisible — the player never learns the card is doing anything. So
it is designed as two halves, and the GLB holds both, side by side: **the mark**
at x = −6 and **the drop** at x = +6.

**The tell.** Any enemy under `Balance.Player.executeBelow` wears a hovering
brand: a voxel executioner's cleaver hanging point-down above it, red-headed with
a stepped pale crescent along its edge — the icon's cleaver, exactly. Behind it a
vertical halo of eight gold cubes with one white marker, ticking round like a
clock face. Under it, on the ground, a **broken** dashed gold ring with four gaps
and four taller bone-white posts, and four upright crosshair ticks bracketing it.
Sparse, patient, hovering. A player should read "that one is about to die" from
across the arena without having to find a health bar.

**The payoff.** When an executing blow kills, the brand cashes in: the same
cleaver slams down, scaled up and flashed bone white — red blade waiting, white
blade striking, so the two halves never look like the same object twice. Eighteen
cubes in gold, bone white and dark red burst outward in a wide low cone (the
enemy coming apart), a ground ring of twenty outward-pointing stepped chevrons
spreads the shockwave, six white cubes drift up and away, and a low collar of
dark red cubes sits at the blade's tip.

Volume sits deliberately between the tiers: louder and longer than Heavy Blade's
single burst, well short of Earthbreaker's three seconds of erupting ground. The
brand is the part that carries it — a persistent marker is cheap, and it is what
turns a hidden multiplier into a mechanic the player plays around.

---

## Earthbreaker — Mythic (audit)

**Claude Design (the gap only):** https://claude.ai/design/p/51dac5f7-e571-4c73-bbed-3cda9508a496
**GLB:** `fx_earthbreaker.glb` — the slam's debris only, not a rebuild

Earthbreaker is built and this was an audit, not a build. **The chain is complete
and correct end to end**, and that is the main finding:

- `Input/MoveController` plays the RubySword kit's `earthbreaker` special clip as
  the dash ends (PR #164); the arc is in the animation.
- `Main.server.luau` takes `DashStarted`, checks the session actually holds the
  card and that the dash's own cooldown has elapsed, and schedules the slam at
  `dash.duration + quake.leap` — the clip's `Impact` marker. A client cannot fire
  slams at will.
- `Combat/AreaStrikes` lands the slam (`GroundSlam`) and then opens a zone that
  erupts every `crackEvery` for `crackDuration`.
- `Fx/TelegraphRenderer` draws the slam's shockwave plus a camera shake, the dark
  cracked ground with neon cracks running out from the landing, and an `Erupt`
  shockwave per tick; `Fx/MythicFx.erupt` pushes rock spikes up over a lava glow
  and sinks them again, budgeted by `DeviceTiers.mythicFxShare`.

Nothing in that is missing or wrong. Four things are off against the card's own
art and against what the Meteor Mythic gets, worst first:

1. **The slam itself throws no debris.** This is the real gap. The Meteor's
   landing calls `MythicFx.meteorImpact`, which throws fourteen rocks out of the
   crater under its own gravity. The Warden's slam — the 2.5× hit that is the
   whole point of the card — gets a flat shockwave ring and a camera shake,
   nothing else. The card art shows grey rubble cubes flying off a torn divot of
   grass-topped soil, and none of that happens. **This is the only thing I
   designed**, as `fx_earthbreaker.glb`: fourteen torn grass-and-dirt chunks
   sprayed outward (green cap, brown underside, each tumbled), sixteen pale grey
   stone shards thrown higher and wider to top the silhouette, a low cluster of
   glowing amber cubes where the blade went in, twelve flat grey outward wedges,
   and four orange crack spurs racing away along the ground. Note the debris is
   **grey stone and green sod**, matching the icon — not the brown `rockColor`
   the Meteor shares, which is soil, not bedrock.

2. **The slam has no sound.** `Config/Sounds` has `sword_slam`, but it is wired
   only as the third entry of the sword's `comboSounds` in `Config/Weapons` — the
   ordinary combo slam. The Mythic's leap and its landing are silent apart from
   the camera shake, and the `dash` sound plays at the start of the dash, well
   before the blade lands. A Mythic landing in silence undersells it.

3. **Only the player who owns it sees the leap.** `Fx/WeaponPose` writes Motor6D
   CFrames directly rather than playing through an Animator, so the pose is
   local. In co-op the other players see the shockwave, the cracks and the
   eruptions appear out of nowhere, with no warrior leaping into them.

4. **The slam's tell arrives with the slam.** `GroundSlam` is an impact tell, so
   the warning and the hit are simultaneous. That is right for the player who
   pressed dash, but a co-op partner standing in the landing circle gets no
   notice at all.

(2), (3) and (4) are code changes outside this branch's scope — recorded here,
not acted on. (3) and (4) in particular are co-op correctness, not polish.

I could not look at Earthbreaker in Studio: the owner's place was mid-playtest by
another session throughout this work, and the leap only fires from a real dash
that a probe cannot press. The audit above is from the code and the card art.
