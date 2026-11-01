# Lobby — design and acceptance standard

Phase 5. See `docs/ROADMAP.md`.

The lobby is the first thing a new player sees and where every adventure starts.
It carries the art direction, so unlike every other phase it gets its art pass **in-phase**
rather than waiting for Phase 8.

## Status: building (2026-10-25)

**The design** is the owner's pick: layout C, "Three Groves", without the egg breeder
(`assets/concepts/blocky/lobby/lobby_three_groves.png`; the other options beside it), with two
rows of portals (owner, 2026-10-25: "make sure there are 2 rows of portals with them being
locked, there should be at least 10 portals for now"; `lobby_portal_rows.png`). A forest
clearing in the Mossy Glade's style: the Egg Hatchery in the west grove; the Blacksmith, Gear
Station and Dex Hall in the east grove; the campfire spawn in the middle; two portal terraces
across the north edge, ten arches in two rows of five (the back row a step up): Mossy Glade and
Thornwood lit at the front row's west end, eight locked for the areas to come; trees, cliffs and waterfalls round the edge.

**The flow** (built): BEGIN ADVENTURE puts players at the campfire; walking into a lit portal
opens its screen (`UI/PortalScreen`, owner 2026-10-26: "need screen for portal entry with the
level selector"): the area, its levels (`portals[i].levels`), and START, which asks the server
(`Remotes.PortalStart`); the server starts the run only for the portal the player stands at, one of
its levels, and a level that player has opened (`Run/Lobby.startFor`, `Util/LevelUnlocks`,
`tests/Lobby.spec`). X, Escape or walking away closes it. **Mossy Glade has ten levels** (owner,
2026-10-26: "2 ROWS OF 5 LEVELS EACH"): numbered buttons 1-1..1-5 over 1-6..1-10
(`levelColumns`), 1-1 always open, each next one opened by beating the one before (saved,
`SaveSchema` v2 `levelsBeaten`), locked ones dimmed under a lock, beaten ones CLEARED in gold, the
picked one's rooms or waves on the line under them. Thornwood keeps its single card (its level, its
boss, two COMING SOON slots up to `levelSlots`). From a run the end screen's NEXT LEVEL goes on to
the portal's next level, and back here after its last (1-10, Thornwood); TRY AGAIN replays. Data in `Config/Lobby`, built by
`Run/Lobby`, the run's state `Lobby` in `Run/RoomController` (`beginStage`, `inLobby`), the stage
a portal picked published as the Workspace's `Stage` (`Util/CurrentStage`). The camera follows
the player across the clearing, the lobby plays its Mossy Glade music, and the banner reads
"Lobby". The stations are scenery until their features are built. With several players in the
server, the first to press START takes everyone.

**Moving in the lobby** (owner, 2026-10-26: "let players sprint and jump in the lobby instead of
dash"): no dash there; Shift, a gamepad's X (or a click of its left stick) or the phone's SPRINT
button runs at `Config/Lobby.sprint` times walking speed, and Space, A or the phone's JUMP jumps
(Roblox's own, `jumpHeight`; `RunSession.allowJump` on the server, `Input/MoveController` and
`Input/LobbyButtons` on the client). A run keeps its dash and never jumps.

**Station spacing** (2026-10-26, the owner: the gear area "almost overlaps with the blacksmith
area"): the Gear Station stands out east and south of the Blacksmith, the Dex Hall and its
lecterns a little further south; `Lobby.spec` keeps every station's footprint 6 studs from every
other's.

**The art** (built, 2026-10-25): twenty Claude Design pieces (four agents: hatchery and campfire;
blacksmith and gear station; dex hall and the portal pieces; the scenery), each compared with the
sheet, in `assets/models/lobby/lobby_kit`, bundled with `kit_bundle.py --srgb` into
`assets/models/lobby/lobby_kit_roblox.glb`, imported by the owner; their mesh ids are
`Config/Lobby.pieces`. Placed and compared in Studio with `lobby_portal_rows.png`. Found on the
way: the place's Baseplate (top at y = 0) reaches under the lobby's north half and fought the lawn
in grey stripes, so the lawn and its floor stand 0.1 above it; the forest round the edge casts no
shadow; the waterfall's and hatchery's glow is drawn lit but not Neon (Neon burned them white).
**v3** (owner, 2026-10-25: "fix everything to look more like the sheet. also lets upscale
everything and have it be the normal roblox camera angle. the portals also should look like their
areas not all look the same. double the map size and length in between everything, change the
camera angle and also add a leaderboard for farthest story completion"; then the blacksmith
"modeled after the blacksmith from elden ring", the egg station's keeper "after the great fairy
from breath of the wild", 2D cards for both, and the three codex books). The sheet is now
`lobby_v3.png`. The clearing is twice the size and every piece twice as big (`scale` 6); in the
lobby the camera is Roblox's own, started behind the player at its usual angle, and walking
follows it (`TopDownCamera`, `MoveController`); a run takes the top-down camera back. Each portal
is its own area's arch with its name built in (`portals[i].arch`). The lawn's scatter (flowers,
bushes, mushrooms, rocks) is laid on a jittered grid, so it spreads evenly. Props: the smith at his
anvil, the Hatchery Fairy, three codex books on lecterns before the Dex Hall. The FARTHEST
ADVENTURERS board shows `Run/StoryLeaderboard` (see `docs/LEADERBOARD.md`). The second import is
`assets/models/lobby/lobby_kit_v3_roblox.glb`. Codex art: `lobby/npcs/` (model sheets and the
cards), `lobby/codex_books.png`, and the 2D codex books with their 6-frame page turns in
`ui/codex/` (for the dexes, not built yet). Still apart from the sheet: the fairy's wings import
solid (vertex colours carry no transparency), and the blacksmith's forge keeps its earlier
left-right layout.

**The Dex Hall** is the owner's own model (2026-11-01: "ok i imported the dex hall i want you
to use", "put the book on top and the book stands on the sides where they belong"). Three
imports, the only meshes in the lobby: the hall, the open book astride its roof and the stand on
each of the two stone pads out front. The hall mesh carries its own porch, columns, wall
lanterns, steps, carpet, counter and shelves, so nothing is drawn over it; a light goes at each
lantern, because one mesh takes one material and a modelled lantern cannot glow by itself.

Everything is measured off the mesh, by raycast against its own collision shape at the size it
is drawn: the ridge stands 14.28 studs over its floor, and the two pads are 0.9 high, 7 wide,
13 studs either side of the middle and 11 forward. The roof book's own box reaches down to the
tip of its ribbon, so its foot is seated 2.2 studs below the ridge to put the covers *on* it
rather than floating. The hall was modelled facing -Z and a building faces south, so the whole
assembly is placed in the hall's frame and turned; the books ride that turn with it. Numbers in
`Config/Lobby.dex`.

`MeshPart.MeshId` cannot be assigned, so the three go through `Util/MeshTemplates` with the rest
of the server's meshes and are cloned; if the hall mesh fails to load nothing is drawn, rather
than three books floating over the lawn.

The nameboards turn with their stations: `signboard` takes a frame rather than a point, since a
board that always faced south would have its back to the lawn on three corners out of four. The
words sit on a part's Front face, which is its -Z, so a board reads out of the frame's -Z — the
Dex Hall's hangs off `base` and not off the turned mesh frame, or it would read out of the back
of the building.

The roof book **rests on the roof**, 4.83 studs below the ridge (owner, 2026-11-01: "the book
needs to rest on the roof like this"). Measured, not guessed: the book was dropped onto the hall
with both at their drawn size and precise collision, and the first thing its underside meets —
ignoring the narrow ridge finial its open covers straddle — is the roof slope at that depth. Its
covers lie on the roof and the gable's peak sits up in the fold of the pages.

**The hall's texture is a stand-in** (owner, 2026-11-01: "use attempt 1").

The hall as modelled could not take one. Its GLB was read directly (`codex hall.glb`): one mesh,
24,395 vertices carrying `POSITION` and `NORMAL` **and nothing else** — no `TEXCOORD_0`, so no
UVs — one material named `material` with no texture, and zero images in the file. A mesh with no
UVs has nowhere to put a texture image, so this was never a setting missed on import.

Roblox's own `generate_texture` was run over it instead, which unwraps a mesh as it paints it:
`Config/Lobby.dex.hall` names that mesh and that texture. Three passes were made, all on clones,
and the first is the one kept. It is **not** the sheet: the roof, the gold edge caps, the cream
panels, the white banded columns, the red carpet, the lit lanterns and the shelves all landed,
but the timbers came out salmon rather than brown and the base plinth red rather than cream. A
second pass fixed those two and lost the cream panels; a third, in Quality mode, remeshed and
never produced a texture at all.

Geometrically it is the same hall — re-measured at 38 across it is 38.00 × 14.28 × 28.01 with its
ridge and pads where they were — but the generator returned it at twice the native scale, which
is why `hall.native` is not the import's own size.

It goes the moment the hall is exported from Tripo **with texturing on**, which writes real UVs
and a real basecolor; that is two ids in the config. The two books prove the route: their intakes
each carry a `.fbm/..._basecolor.jpg` beside the FBX and they came into Studio textured. Until
then the acceptance standard below is **not met** for the hall.

**The layout** (owner, 2026-11-01: "every building should be either northwest, northeast,
southwest, or southeast ... the dex hall is in the southwest, the gear station is in the
northwest, the blacksmith is in the northeast, and the egg hatchery is in the southeast, and
then the portals are at the north"). One station to each corner of the clearing, **every one of
them turned to face the middle**, with the fountain between them and the portal terraces beyond.
They were strung along the east side before, which left the west half of the lawn empty and made
the walk a line rather than a circuit.

The turn is one rule, `Config/Lobby.facing`: a building is modelled facing +Z, so the yaw that
points its front at the origin is the bearing of its own place, negated. Three things read it —
the builder, the egg and crate stands it puts out front (`turnedOffset`, so they come round with
their station), and `Lobby.spec`, which measures each footprint **as it is actually turned**,
since a box off the square covers more lawn than its own width and depth. A station standing in
the middle has no bearing and is left alone.

The two northern buildings stand clear of the portal terraces: the front ledge reaches z =
-50.4 and they reach z = -43.

## What the lobby has to contain

From `docs/PROGRESSION.md`:

- **Area portals in a row**, left to right in unlock order. Cleared ones open and lit, the next
  one visibly locked with its requirement shown, later ones fogged but still visible. A player
  must always be able to see how far the game goes.
- **Egg stands**, one per unlocked area tier
- **Pet inventory and equip**, **gear**, **upgrades**
- **Rebirth plinth** (late)
- Other players visible, pets trailing behind them

## Acceptance standard

Stricter than the usual phase gate. The normal rule is "does the playtest question get a yes";
here the rule is a self-review I have to pass before showing it at all.

Once the lobby is built I examine it directly — fly the camera, playtest it, take screenshots
from the same angles as the reference images, and put them side by side. Then I answer one
question honestly:

> *Does this look 1:1 with the reference images in a low-poly style, and is it as polished as
> I can make it?*

If the answer is no, I keep working. I do not hand it over with a list of caveats. The loop
ends only when I can say:

> *"Yes — I believe the lobby design is 1:1 with the image in the low-poly style, and is as
> polished as I could make it."*

### What I check each pass

- **Layout** — are the elements in the same places and the same relative scale as the reference?
- **Silhouette** — does it read the same at a glance, zoomed out, and on a phone-sized screen?
- **Palette** — sampled against the reference, not eyeballed
- **Proportion** — player-to-building scale, walkway widths, portal heights
- **Low-poly discipline** — flat shading, clean hard edges, no detail that should be texture,
  consistent poly density across props
- **Lighting and mood** — time of day, shadow direction and softness, any glow or emissive
- **Polish** — no z-fighting, no visible seams, no floating or intersecting geometry, nothing
  clipping the player's walk path
- **Performance** — holds frame rate on a mid-range phone with several players and their pets

### Honesty rule

Self-assessment against a reference is exactly where it is easiest to quietly lower the bar. So
the screenshot comparisons go in the PR, and what I could not match gets named explicitly
rather than left for you to notice.
