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
anvil, the Hatchery Fairy, three codex books on lecterns before the Dex Hall.

**Imported models (2026-11-01).** The lawn's trees are the owner's blocky tree
(`Config/Lobby.treeModel`), one MeshPart each where they were a trunk pillar
under three leaf blobs -- so three times as many trees cost *fewer* parts than
before (1,252 in the lobby, down from about 2,152). `tall` is set to what the
built tree came to, so every scatter and ring that places one keeps its
spacing.

**Variety comes from two things, because one mesh has none of its own.** Each
tree is turned a random amount about Y, and its height is stretched by itself
(`treeModel.stretch`, 0.8 to 1.4) apart from how wide it is. Scaling evenly
only makes a tree look nearer or further -- the built trees it replaced hid
that by randomising their crowns too. On the lawn that gives trees from 8.9 to
20.9 studs whose height-to-width ratios span 1.45 to 2.53; before, every tree
had the same ratio.

**Density** (owner: "add more around the lobby"). Weighting trees higher was
not enough on its own: only about a quarter of scatter tries can land, because
the paths, the terrace and the `keep` ring round every building, stand, arch
and board reserve most of the lawn. At a 14-stud cell with 0.6 filled the
whole clearing held 37 scattered things, 15 of them trees. The cell is now 10
with 0.9 filled and a tree reserves 4.2 rather than 6, which gives 24 trees
and about seventy other things. The space test itself is unchanged, so nothing
stands any closer to a building or a path than before.

Each area's arch comes from `Config/Lobby.archModels`, keyed by portal index.
The Mossy Glade's is imported; Thornwood's and the Drowned Village's are
modelled and arrive next, and keep the built stone ring until then. From
`archSilhouetteFrom` (5) on there is no model and none coming, so each stands
as the first area's painted black with its texture dropped (owner: "replace
every portal past 4 with a silhouette of the arena 1 portal until portals are
made for them") -- that includes Endless, which is last of the arches. Giving
a portal its own `archModels` entry is all it takes to stop it being one. The
swirl, the padlock and the colliding legs are unchanged; the legs just turn
invisible behind a model, so a player is held out of the uprights exactly as
before. The FARTHEST
ADVENTURERS board shows `Run/StoryLeaderboard` (see `docs/LEADERBOARD.md`). Both boards stand
south of the spawn facing north (owner, 2026-11-01: "move the leaderboards to behind the player
south of the spawn"), 32 studs back and 39 degrees either side of due south, so a player who
arrives facing the portals has them behind and sees both at once on turning round. They used to
flank the path north of the fountain. `leaderboard.turn` turns a whole board; with none it reads
south, as both did before. The second import is
`assets/models/lobby/lobby_kit_v3_roblox.glb`. Codex art: `lobby/npcs/` (model sheets and the
cards), `lobby/codex_books.png`, and the 2D codex books with their 6-frame page turns in
`ui/codex/` (for the dexes, not built yet). Still apart from the sheet: the fairy's wings import
solid (vertex colours carry no transparency), and the blacksmith's forge keeps its earlier
left-right layout.

**The Dex Hall is built from parts**, like every other station (owner, 2026-11-01: "the dex hall
needs to be remade, use the book stands and the book on the top but make a whole new building",
then "i want you to just use parts already in roblox"). 92 parts: a cream plinth and two steps
with a red carpet over them, a timber frame of posts and beams over cream panels, two white
columns banded in gold, a roof of two slopes meeting a flat top with a gold cap at each corner,
a gable with a timber king post and a gold peak, a lit lantern either side of the porch, and a
counter with a shelf of coloured books inside. Every colour is set outright from the sheet's
palette (`Config/Lobby.dex.colours`), so it matches by construction rather than by a generator's
guess.

Two things stay imported: the open book on the roof and the stand on each of the two pads the
hall builds out front. They were modelled facing -Z, so they take an extra half-turn (`dex.turn`)
on top of the building's own. The book rests on the roof — its bounding box reaches down past
its covers to the tip of the ribbon, so its foot drops 2.35 studs below the roof to put the
covers on it.

**Why it is parts.** The hall the owner modelled came out of Tripo before its texturing step and
so carried no UVs at all — one mesh, 24,395 vertices with `POSITION` and `NORMAL` and nothing
else, one untextured material, no images. A mesh with no UVs has nowhere for a texture to go, so
it could only ever render in one flat colour. Roblox's own `generate_texture` was tried, which
unwraps as it paints and did produce a textured hall, but across three attempts it never got the
sheet's colours right in one pass — the timbers came out salmon, or the cream panels went brown.
Parts have neither problem, and they live in the repo rather than in the place file.

## What the lobby has to contain## What the lobby has to contain

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

## Lobby B (2026-11-04)

The lobby is now a ruined marble courtyard, built to the layout sheet
`assets/concepts/blocky/lobby/palace/lobby_layout_reference.png`, under a blue sky with clouds and
a sun (owner, 2026-11-05). Where this file describes a lawn, sandy paths, lamps or a scatter on the
floor, the sheet replaces it. The numbers are in `Config/Lobby` (`courtyard`, `light`, `sky`,
`motes`); `Run/LobbyCourtyard` builds the ground and ruins and `Run/Lobby` the terrace and buildings.
The courtyard stands `courtyard.drop` studs above the ground past the balustrade, and players are
held inside the balustrade's outline. **The lobby's light wins while players are in it**:
`Atmosphere.lobby` sets it from `InLobby`, and a room's own light comes back as they leave. A test
run in `execute_luau` loads its own copy of `Atmosphere`, so it can leave the room's light showing in
the lobby until `InLobby` next changes; that is the probe, not the game.

**Second pass against the sheet (2026-11-05).** The owner asked again for it to look like the
reference, keeping the blue sky. From the sheet's angle the southern two buildings showed their backs
and the leaderboards their stone backs, so all four buildings now face south, turned `TURN_IN`
(0.25 rad) towards the middle line, and the boards read south: both reverse the owner's 2026-11-01
calls, in favour of the sheet. The buildings stand `buildingScale` (1.25) larger, as the sheet's are
nearly a third of the courtyard's width, and the rows sit further apart so a northern one shows over
a southern roof. The southern buildings' carpets run in under them from the plaza and out from their
doors southward. The titles are two lines, larger, with a thicker outline, over each building's
outer shoulder. The haze is thin and blue (`hazeGlare` 0, which had whitened the trees towards the
sun) and the clock is 9.5, as the warm haze had turned the whole sky grey. The courtyard stands
`courtyard.drop` (18) studs above a darker `forestFloor`, and the brown lawn ledges round it are gone.
Still not matched: the tree import's bright blocky crowns (a textured mesh ignores `Color`, so it
cannot be tinted), and the blacksmith, fairy and arcade vines.

**Trees and backdrop (2026-11-05).** The blocky tree import is replaced by a tree built in code
(`Config/Lobby.tree`), blocky like the loading screens' voxel trees: a square trunk on a flared
foot under a crown of stacked slabs and offset cubes, dark underneath and sunlit on top, each piece
turned a little (owner, 2026-11-05: the round-blob tree "look[s] terrible"). Past the
wood, `Run/LobbyBackdrop` builds the far scenery after the enemy spotlight loading screens (owner:
"there should be mountains and waterfalls"): 18 stepped stone cliffs with grass ledges, hanging moss,
trees and pines on top, stepped falls on four of the northern ones (a stream over the top, a drop of
streaked water down each tier with a foam lip, streaming particles and spray, a run across each
ledge, and a rock-ringed pool that mists), a taller bare ring behind them to close the horizon, and glowing cyan mushrooms on the
forest floor (`Config/Lobby.backdrop`). The ruined tower and aqueduct that stood on the highest
cliff were removed (owner: "get rid of the castle looking object completely"). The lobby is about 5,460 parts with it (the blocky trees are 8 parts each, 284 of them), not measured on a phone.
