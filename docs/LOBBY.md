# Lobby — design and acceptance standard

Phase 5. See `docs/ROADMAP.md`.

The lobby is the first thing a new player sees and the room they return to between every run.
It carries the art direction, so unlike every other phase it gets its art pass **in-phase**
rather than waiting for Phase 8.

## Status: blocked

Nothing has been built. Two things are missing before work can start:

1. **The reference images.** They have been described but not shared into the project. Drop
   them in `assets/reference/lobby/` and they become the spec.
2. **The Studio MCP connection.** Without it I cannot build geometry in Studio, run a playtest,
   or take the screenshots the review standard below depends on. See `docs/SETUP.md`.

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
