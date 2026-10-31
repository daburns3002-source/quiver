# Warden blade upgrades — effects and animations

Design notes for the four Warden blade cards in `src/shared/Config/Abilities.luau`
(`group = "blade"`, plus `Bloodletting` in `group = "vital"`). Each effect was
designed in Claude Design in the blocky language — faceted, flat-shaded,
hard-edged — against the card's own icon in `assets/ui/glow_toy_cards/icons/`.

Nothing here is wired up. The GLBs sit in the owner's Downloads folder for a hand
import in Studio (File → Import 3D); uploading a mesh is not something we can do
over MCP. No config or `src/client/Fx/` changes belong in this branch.

**Importing these.** All four carry their colour in the vertices, so Studio's
importer needs **vertex colour support switched on** or they come in white — the
same rule as the enemy and arena meshes in PIPELINES.md. They were not exported
with per-part pivots, so each arrives as one model; anything that wants its
pieces tweened separately in Studio (the Execute brand apart from its ring, say)
needs the parts re-pivoted on import or a re-export asking for per-part pivots
at each part's own centre.

Each GLB was checked by exporting it and reading the file back, not by eye:

| GLB | footprint (studs) | origin | on import |
|---|---|---|---|
| `fx_heavyblade.glb` | 10.0 × 9.8 × 1.9 | star's crossing point, base at y = 0 | nothing — drop it in |
| `fx_bloodletting.glb` | 12.5 × 4.6 × 2.0 | **not** at the heart; heart is at (−3.6, 1.2, 0.05) | offset by (+3.6, −1.2, −0.05) to anchor at the chest |
| `fx_execute.glb` | 8.95 × 4.4 × 4.6 (two groups) | between the groups; Mark at x = −2.4, Drop at x = +2.6 | split into two; **scale ×1.9** so the Mark's ring (1.58) fits a 3-stud enemy; floats 0.16 above y = 0, so snap down |
| `fx_earthbreaker.glb` | 11.0 × 11.0 × 4.9 | the hot core, at ground level | nothing — one chunk dips 0.16 below y = 0 and will clip the floor |

None of the four contains line geometry (Roblox's importer only takes triangles,
and line objects are dropped or fail the import), and none has a baked scale or
rotation on its root — Earthbreaker did carry a 1.39× root scale and it was
folded into the geometry before export. Heavy Blade's near-black outline parts
*were* line objects and have been stripped; the other three never had any.

One thing that will not survive the import on its own: the Drop's upward speed
lines in `fx_execute.glb` use faded materials, and Roblox tends to bring those in
fully solid. Set `Transparency` by hand on `bone_streak_fade1` (≈0.4) and
`bone_streak_fade2` (≈0.7) after importing, or the trail reads as a solid bar.

**The project links below expire.** Claude Design is moving to Artifacts and the
version these were built in works only until 2026-12-14. The GLBs are the
durable artefact; anything still needed from the projects themselves should be
pulled out before then.

## Judged at the game camera, not the turntable

Every one of these was reviewed a second time from the camera the player
actually has — 40 studs up, pitched down 57°, 70° FOV, over a `#4E8C3A` grass
floor — and then desaturated to greyscale. **All four failed that review in ways
the default three-quarter viewer had flattered**, and the fixes below are why the
designs look the way they do. Worth repeating for anything else built this way:

- **Red on grass is invisible to colour-blind players.** `#E03848` against
  `#4E8C3A` is 1.07:1 in brightness — the hues are opposites but the luminance is
  identical, so for red-green colour-blind players (roughly one man in twelve)
  Execute's brand and splash simply disappeared. Everything now carries its shape
  on a bone-white rim, never on hue alone.
- **Near-black outlines cannot be relied on.** They are one pixel wide and break
  into noise at real camera distance, so they look like they are carrying an
  effect in the viewer and carry nothing in game.
- **Vertical elements do not read from above.** Heavy Blade's slim gold spike
  foreshortened into a stump and was a white dot at true scale — its own cast
  shadow read better than it did. It became a flat bone-white ground star.
- **Transparency drifts toward the background.** The same spike was 72% opaque
  and rendered greenish-white over grass. Effects are fully opaque now.
- **Contrast can go dark as well as light.** Heavy Blade's dust slabs sat at
  grass brightness (1.1:1) and contributed nothing; taking them *darker* to a
  deep soil brown made them read as a scar torn in the turf.
- **Green debris on a green floor is a trap.** Earthbreaker's torn-sod caps were
  the same hue as the arena and only slightly brighter (145 against a 117 floor),
  so the thing that was supposed to say "lawn" said least. They are now a bright
  yellow-green at 199, with 4% of their pixels within the floor's brightness
  instead of 22%.
- **Size against the real ability radius.** Heavy Blade is 10 studs across for
  `Classes.TimberBlade.swing.slamRadius` = 5, Earthbreaker 11 for
  `Balance.Player.earthbreaker.slamRadius` = 5.5. Earthbreaker stays the larger
  of the two, as the Mythic should.

Named weaknesses that were left alone rather than papered over: the gold in
Heavy Blade and Execute sits at about 2.5:1 against grass and is the softest
element in both, but pushing it brighter turns it pale yellow and costs the
Legendary colour key; the Drop reads as "blade arrived" rather than "blade
falling", because a still can only hint at downward motion and the fall belongs
to the in-game animation; and at 40 studs up a 10-stud effect is simply small on
screen — that is the game's scale, not a fault in the model.

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
- **A broken crust ring** of sixteen separated slabs leaning outward at their own
  angles and heights — earth shoved aside. Deliberately not a continuous ring: a
  closed donut reads as a tyre. They are a deep soil brown rather than the
  grey-brown they started as, because at grass brightness they vanished; dark
  against mid-green separates as well as light does, and a dark scar under a gold
  starburst is the right read for a heavy blow.
- **A bone-white ground star** at the centre — four short arms along the floor
  with a larger cube where they cross, plus a stub of height for lower angles.
  This started as a tall slim after-image spike, which was the right idea from
  the side and useless from above; flat on the ground it is now the brightest
  thing in the effect (4.3:1 against grass) and reads at any angle. It stands in
  for the blade's path, not the blade — the player's greatsword occupies that
  space in game.
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
  dark red to hot pink-red. The taper and the colour shift are what make it
  directional; without them it reads as a sausage, not a drain, and they are the
  cues that survive at every camera angle once the arc itself foreshortens. The
  dark end started as a deep oxblood and had to be lifted — at 2.3:1 its shaded
  faces were as dark as the grass shadows and the far half of the stream was
  swallowed by the floor.
- **A voxel heart** at the Warden's chest, the same 8-bit heart silhouette as the
  icon's, the densest and brightest thing in the effect so it is clearly the
  destination, with a bone-white rim so its shape survives in greyscale. It is
  **pitched back about 55° to face the game camera** rather than standing
  upright: upright, it squashed to half height at the player's viewing angle,
  shrank to a 15-pixel dot at true scale, and went edge-on to a meaningless slab
  whenever the enemy stood below the player. The heart is the whole payload of
  this effect, so it has to present its face. The last cubes of the stream touch
  its lower edge.
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
a stepped pale crescent along its edge — the icon's cleaver, exactly — and a
bone-white rim around its whole silhouette so the shape never depends on the red.
Its edge cubes sit flush with the front face of the blade rather than inset,
because inset they were hidden by the blade's own overhang from above and the
cleaver read as a plain red brick on a stick. Behind it a vertical halo of eight
gold cubes with one white marker, ticking round like a clock face. Under it, on
the ground, a **broken** dashed gold ring with four gaps, four tall bone-white
crosshair posts bracketing it, and a **dotted plumb line** of five tapering gold
cubes running from the blade's tip down to the ring's centre — without it the
2.6-stud gap was dead space and the brand and the ring read as two unrelated
objects rather than one marker. Sparse, patient, hovering. A player should read
"that one is about to die" from across the arena without having to find a health
bar.

**The payoff.** When an executing blow kills, the brand cashes in: the same
cleaver slams down, scaled up and flashed bone white with a gold edge band and a
dark amber lower lip — red blade waiting, white blade striking, so the two halves
never look like the same object twice. Eighteen cubes in gold, bone white and
white-tipped dark red burst outward in a wide low cone (the enemy coming apart),
a ground ring of twenty outward-pointing stepped chevrons spreads the shockwave,
and **three separate vertical speed lines** rise above the blade, spread across
its width and fading upward. The speed lines are there because from a top-down
camera the blade alone cannot say which way it travelled — it just looks like a
pale slab parked above the burst. They are the design agent's idea, and better
than the single centred trail I had asked for, which read as a roof.

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
   sprayed outward (bright green cap, brown underside, each tumbled), sixteen
   pale grey stone shards thrown higher and wider to top the silhouette, a low
   cluster of glowing amber cubes where the blade went in, twelve flat grey
   outward wedges, and four orange crack spurs racing away along the ground. The
   debris is **grey stone and green sod**, matching the icon — not the brown
   `rockColor` the Meteor shares, which is soil, not bedrock. It is 11 studs
   across, matching `slamRadius` 5.5, and its brightness hierarchy against a
   grass floor is deliberate and measured: core 244, cracks 221, sod caps 199,
   pale stone 169, wedges 149, dirt 119, over a floor of 117. The cracks had to
   be pushed well above the stone or they read as more rubble rather than heat
   once hue is taken away.

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
