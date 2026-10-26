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
starts that area's run (Mossy Glade: the Mossy Glade Run; Thornwood: Level 2); from there the end
screen's NEXT LEVEL and TRY AGAIN carry on as before (`Balance.campaign`). Nothing leads back to
the lobby after a run yet. Data in `Config/Lobby`, built by
`Run/Lobby`, the run's state `Lobby` in `Run/RoomController` (`beginStage`, `inLobby`), the stage
a portal picked published as the Workspace's `Stage` (`Util/CurrentStage`). The camera follows
the player across the clearing, the lobby plays its Mossy Glade music, and the banner reads
"Lobby". The stations are scenery until their features are built. With several players in the
server, the first to step into a portal takes everyone.

**The art** (in progress): one Claude Design agent per group of pieces builds the kit to the
sheet 1:1, bundled like an arena kit into `assets/models/lobby/lobby_kit` for one owner import;
until then the clearing is lawn, dirt paths and invisible walls.

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
