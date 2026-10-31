# Ranger power upgrades — effects

The in-game effect or animation for five Ranger upgrades. Each was designed in
Claude Design from that card's own icon, in the game's blocky language: chunky
voxel cubes on a ⅛-stud grid, flat shading, hard edges, saturated colour, no
smoothing and no soft particles. 1 unit = 1 stud. Every part is its own named
mesh with its pivot at its own centre, so the rings, links and step cubes can
be tweened separately in Studio.

Rarity has to read before anything else does. The Mythic is the loudest thing
on screen, the Legendary sits clearly below it and clearly above the two Epics,
and the Uncommon is deliberately the quietest of the five. Each piece was
checked in the project's **Lineup** view (all five side by side at true scale)
and its **Game · 40 up** view, which is the camera the game is actually played
at — the first pass failed there and was reworked.

All five Claude Design scenes live in one project:
**Arrow Legends combat effects** —
https://claude.ai/design/p/19d37a53-15c7-47ef-aa41-a27568945755

The GLBs are in the owner's Downloads folder. Importing a mesh cannot go over
MCP, so the owner imports each by hand in Studio (File → Import 3D). **Vertex
colour support must be switched on in the importer or these import white** —
the colour is in the vertices, as with every other model in this game. Nothing
here changes config or `src/client/Fx/`.

---

## Bouncy Wall — `BouncyWall`, Uncommon

**Effect**, not an animation. The card changes nothing about the archer; it
changes what happens when an arrow meets a wall. `ProjectileFlight` already
reflects the shot, and `ProjectileRenderer` already draws a ring and chips
where a shot meets the arena — but it draws the same ring for a shot the wall
*stopped*. So a bounce currently looks exactly like the failure the renderer's
own comment warns about. This effect is the thing that says the bounce was on
purpose.

A flat faceted chevron — a bold V of five chunky cubes stamped on the wall
plane at the hit point, pointing the way the arrow leaves, in the icon's
saturated yellow over a small white-hot core — and three stepped cubes peeling
off along the outgoing path, each smaller than the last. That stepped trail is
lifted straight from the icon. One colour family, no debris, no glow, about 1.5
studs wide: at the game camera it is a small yellow kick and nothing more,
which is what an Uncommon should be.

The wall is the z = 0 plane; the bounce leaves toward +x and +z. 116 triangles.

GLB: **`fx_bouncywall.glb`**

## Dual Bows — `DualBows`, Mythic

**Effect.** Dual Bows already has everything an animation would give it: the
`LeafBowDual` weapon in `Config/Weapons`, a full kit in `Config/WeaponAnimations`
(Hold, Raise, Aim, Fire_R, Fire_L) and the offhand bow. What it does not have is
a Mythic moment — `Fx/MythicFx` draws the Meteor and Earthbreaker only, so the
Ranger's Mythic is currently the quietest of the three. This is the burst that
blooms out of the archer's chest when both bows loose together, built to the bar
the Meteor's fireball and crater set.

A big crossed X of two faceted arrow-chevrons — chunky orange-brown shafts,
broad wedge arrowheads in bright gold, mint-green fletching wedges — blooming
out of a white-hot core, with a flat teal ring of chunky segment blocks lying
low on the floor behind them and gold cube motes thrown outward. The X is the
icon's two crossed bows, read as the arrows they loose. It lies flat so the X
reads from above.

The first pass put the arrows *inside* the ring and at the game camera it read
as a teal ring with a brown smudge — the crossed arrows, the whole point of the
card, did not read at all. Reworked: the arrows are scaled past the ring, lifted
in front of it and brightened, and the ring was thinned and dimmed to frame them.
It is now plainly the largest and loudest of the five. 1,292 triangles.

GLB: **`fx_dualbows.glb`**

## Overdraw — `Overdraw`, Epic

**Animation**, not an effect. Overdraw is the only one of the five that changes
the shot *before* it is fired — the charge builds over
`Balance.Player.overdrawRamp` seconds of standing still — so the right place for
it is the draw itself, not an explosion. There is nothing for it on the client
today.

Three flat faceted gold rings of chunky segment blocks, sized large, medium and
small, that slide along the arrow toward the bow and snap flush as the charge
fills; a chunky arrowhead with a crown of white-hot cubes growing around it; and
a flat faceted shockwave ring that punches outward on release. Cream, gold and
orange-brown only, after the icon's drawn bow.

The first pass was three rings floating around nothing, so a cream arrow shaft
now runs all the way through them and twelve small gold speed chips trail behind
— the icon's backward-flying chips, and the thing that sells it as charging
rather than decorating. The arrow points along +z with the bow at z = 0, and the
rings are spaced along it ready to slide back. 788 triangles.

GLB: **`fx_overdraw.glb`**

## Blast Arrows — `BlastArrows`, Epic

**Effect** — an impact. The stage is `Stages.splash(radius, 0.5)` in
`AbilityEffects`: a blast at half the arrow's damage, 3 to 6 studs by level,
landing where the arrow does. It wants a moment at the point of impact.

A faceted starburst shell of eight chunky wedge spikes radiating in a flat-ish
dome from a single white-hot centre cube, graded from deep orange at the roots
to bright yellow at the tips, with four saturated red cube shards thrown out
past them and a low flat scorch ring of dark cubes underneath. That is the
icon's sunburst and its red spiky cubes, built in three dimensions. About 5
studs across, so it reads at the radius it represents.

It is a cube explosion, chunky shards and all — deliberately not a soft
fireball, which would not belong next to the Meteor's faceted debris. 804
triangles.

GLB: **`fx_blastarrows.glb`**

## Soul Chain — `SoulChain`, Legendary

**Effect.** `HitFeedback.onSoulLink` already draws something — thin neon bars at
body height between the enemy hit and each enemy sharing the damage. It works,
but a 0.22-stud bar is a beam, and the card's icon is unmistakably a *chain*.
This replaces the bar with the chain the card promises.

Six interlocking square links, each built from eight cubes as a hollow ring,
alternating deep violet and pale lilac exactly as the icon alternates them, with
a bright cyan glowing end cap at each end and lilac motes lifting off the links.
Built to snap taut between two bodies.

Two calls worth recording. With only one cube of space inside each link,
neighbouring links cannot physically hook through each other, so the four side
pieces of each link are bars three cubes long — that leaves room for the links
to interlock and sit taut. And the first pass was too quiet for a Legendary: at
the game camera the deep violet sank into the dark floor and the Epic Blast
Arrows beat it. The violet and lilac were both brightened, the links overlapped
further so they read as one chain rather than a row of brackets, and a cyan
bloom was added at each cap. It now sits clearly above both Epics and clearly
below Dual Bows.

It measures about 10 studs end to end including the end-cap blooms, a little
longer than the 8 asked for; the links can be shortened if a tighter span is
wanted, at the cost of some of the hook-through. 1,056 triangles.

GLB: **`fx_soulchain.glb`**
