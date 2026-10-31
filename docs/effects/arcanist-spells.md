# Arcanist spell upgrades — in-game effects

Designs for the in-game effect each of three Arcanist upgrades produces.
Built in Claude Design in the blocky language of the game — faceted,
flat-shaded, hard-edged, no smooth curves — against the cards' own icon art
in `assets/concepts/icons/`.

Each design exports a GLB to the owner's Downloads folder. **The owner
imports meshes by hand in Studio** (File → Import 3D), so the file in
Downloads is the deliverable; nothing here touches `src/`.

**One thing to carry into Studio for all three:** the glow in these pages
comes from bright, semi-transparent materials, not from a post-process
bloom, and a GLB carries no emission into Roblox. The white core pieces
(`*_Core`) and the lava seams want `Material = Neon` set on import; the
cyan bodies want Neon or ForceField, and the indigo rims want to stay
SmoothPlastic so they read as a dark edge.

---

## Spell Pierce — Rare

- **Claude Design:** https://claude.ai/design/p/d11d62d1-5bcd-49f2-b2cb-ddcf6cfead54
- **GLB:** `fx_spellpierce.glb`
- **Icon:** `assets/concepts/icons/spell-pierce.png`
- **What it does:** `Stages.pierce` — the orb's `pierce` count rises, so it
  passes through bodies instead of stopping at the first
  (`AbilityEffects`, `Config/Abilities` `SpellPierce`).

**The effect.** The card's icon is a blue orb driving clean through a
target, a crystal lance out the far side and the hole shattered around it,
so the effect had to say *passed through*, never *exploded*. Five pieces,
each fired as the orb crosses a body:

- **Orb** — a faceted icosahedron in bright blue with a white core box and
  four flat indigo blades swept back along the flight line, so it reads as
  a drill rather than a ball. It keeps its size and speed through every
  pierce; shrinking it would say the shot was spent.
- **Pierce lance** — a short, fat crystal spike buried in the far face of
  the body and pointing on down the flight line: nested white core, cyan
  body, indigo rim, stepping down in two hard stages to a stubby four-sided
  pyramid tip. It snaps out in a twentieth of a second, holds, and fades.
  The first pass drew it as a long smooth cyan pencil, which read as a
  dart being fired rather than a wound being opened.
- **Puncture** — a jagged broken-glass star of flat shards on the body's
  entry face. No ring and no circle: the icon's hole is shattered, not
  drilled, and a ring would have read as a splash.
- **Shards** — pale cyan diamonds thrown sideways out of the puncture,
  tumbling and falling.
- **Trail** — eight discrete shrinking cubes dropped at fixed intervals
  behind the orb rather than a continuous ribbon. A stutter trail is blocky
  by construction, where a ribbon would have been the one smooth curve in
  the scene.

The page lays the lane out with three bodies seven studs apart and a
`HOLD ALL THREE` button that freezes every pierce at once, so the whole
effect can be judged in one look rather than one stage at a time, plus a
labelled beauty row of the five pieces on their own.

---

## Chain Lightning — Epic

- **Claude Design:** https://claude.ai/design/p/90ed5249-1954-4838-8ef2-017087ea08b9
- **GLB:** `fx_chainlightning.glb`
- **Icon:** `assets/concepts/icons/chain-lightning.png`
- **What it does:** `Stages.ricochet` — the orb leaves a hit for the
  nearest other enemy within `Balance.Projectile.ricochetRange` (14 studs)
  at 70% of the damage it arrived with, twice at level 1 and three times at
  level 2. Mechanically it is Ricochet; what it needed was a look of its
  own.

**The effect.** The hard part is that a chain is the one thing a language
with no smooth curves is worst at drawing: the obvious answer, a soft arc
between two points, is exactly what this game cannot do. So the bolt is
built, not drawn.

- **Each jump** is five to eight straight box segments laid end to end
  along the line between the two enemies, every joint kicked off that line
  by a random perpendicular offset, so the bolt is a sharp angular zig-zag
  with square kinks and some near-right-angle turns.
- **Each segment** is three nested boxes — a thin white-hot core, a cyan
  body about three times its width, and a deep indigo rim that gives the
  bolt a dark edge against a pale enemy. The segments step in thickness
  from one to the next and are left square and unmitred at their ends, so
  the joints show as hard shoulders and the whole thing reads as faceted
  crystal rather than as a wire. Each jump is fattest where it leaves and
  arrives and thinnest across the middle of its span, which is what makes
  it look thrown rather than drawn. The offsets are re-randomised every
  twentieth of a second while a bolt lives, so it crackles.
- **Each node** — where the chain lands on an enemy — is a faceted blue orb
  with a white core inside a corona of eight four-sided violet pyramids,
  bitten into the top third of the body with a couple of spikes buried in
  it. This spiked orb is the single most recognisable shape on the card
  icon, which is three of them joined by zig-zag bolts, and it is what
  makes the effect legible at a glance.
- **Shards** — pale cyan diamonds drifting and tumbling around the bolts,
  as on the icon.

The page shows the chain at **two, three and five targets** side by side,
with a `HOLD FULL CHAIN` button. Five was the real test: four jumps with
the targets scattered so the chain doubles back and crosses itself, and the
question was whether it still reads as one chain rather than a tangle. It
does — the spiked nodes carry the reading even where the bolts overlap.

The first pass failed on colour: every jump rendered as a flat white noodle
of even thickness, because the cyan and indigo shells were too transparent
to see. If the bolt looks white, it has failed.

---

## Meteor — Mythic (audit, not a build)

- **Claude Design:** https://claude.ai/design/p/e84d8ef5-18c4-41ee-8633-2c3c815413ae
- **GLB:** `fx_meteor.glb` — **the falling rock and its trail only**
- **Icon:** `assets/concepts/icons/meteor.png`
- **What it does:** every fifth cast calls a meteor down on that cast's
  target (`Balance.Player.meteor`: `every = 5`, `delay = 0.9`,
  `radius = 6`, `damage = 4`), already built in PR #169.

The Meteor exists, so this was an audit first. It was a code read against
`origin/main` @ a4ba0cc — Studio was not free to look at it live.

### What is already right, and should not be touched

The **impact** is good and matches the card: a fireball out to the strike
radius, a dark scorch held then faded, and fourteen block debris (seven on
a phone) thrown out on a real gravity integration that skids to rest —
flat Slate blocks in grey-brown, exactly the card's angular chunks. The
server side is sound too: pending strikes survive a draft pause
(`AreaStrikes.step` adds the stood time back), `RoomController` clears
them between rooms, and `DeviceTiers.mythicFxShare` scales the debris
without ever reaching zero.

### What is wrong

**1. The falling rock is a smooth glowing orange ball.**
`TelegraphRenderer.drawMeteor` builds `Enum.PartType.Ball` in Neon
`Balance.Telegraph.meteorColor`, and `MythicFx.meteorRock` welds a larger
Neon ball halo to it. The card is a chunky faceted dark grey-brown boulder
with glowing orange lava in the cracks between its facets — stone with fire
inside it, not a ball of fire. In a game whose whole language is chunky
faceted voxels, the headline Mythic's signature object is the one perfectly
smooth sphere on screen.

**2. The trail is the wrong colour.** `meteorRock`'s embers run
`lavaColor` → `fireColor`, both orange. The card's trail is unmistakably
violet → magenta → electric blue → pale cyan, streaming back off the rock
as angular flame shards with pale cyan diamonds through it. The orange
belongs in the rock's cracks; the trail is the Arcanist's arcane colour.

**3. Every meteor falls from the same direction and never tumbles.**
`rock.Position = ground + Vector3.new(4, meteorHeight, -6)` is a fixed
offset and the tween moves `Position` only, so each meteor in a run enters
on the same line at the same attitude.

**4. The fall does not pause with the run; the strike does.**
`AreaStrikes.step` pushes `landsAt` forward by however long the world stood
still behind a card screen, but `drawMeteor` falls on a `TweenService`
tween under `Debris:AddItem(rock, duration)`, and `Fx/TelegraphRenderer`
never consults `client/RunPaused`. If a draft opens inside the 0.9 s window
— a kill levelling you up mid-flight, which is exactly when a Meteor cast
fires — the rock reaches the ground and is destroyed while the server still
holds the strike, and the impact then fires out of an empty sky. Rare and
cosmetic, but a real desync between what is drawn and what the server
times.

### What was designed

Findings **1 and 2** only — the falling rock and its trail, as a drop-in
replacement for the Neon ball:

- **Rock** — a jittered faceted boulder about three studs across in dark
  grey-brown, with molten veins lit along roughly a third of its edges,
  chosen to run in a few continuous wanders rather than scattered singles,
  varying in thickness along their length, plus two or three solid lava
  blotches bleeding off the edge of a facet into a crack. The rest of the
  stone stays completely dark. An early pass lit *every* edge, which turned
  the rock into an orange wireframe cage; a later one put a ring-shaped
  lava pool in the middle of a front facet, which read as an **eye** — a
  real hazard in a game where every enemy has glowing Neon eyes.
- **Trail** — fourteen to twenty chunky flame wedges and four-sided
  pyramids in overlapping layers, crowded and nearly solid at the rock and
  thinning to a point at the tail, running magenta-violet → royal violet →
  electric blue → pale cyan in roughly equal bands, with pale cyan diamond
  shards through it and five or six dark breakaway chunks tumbling behind,
  each with its own faint seam.

Findings **3 and 4** are code, not art, and are left for the owner — this
work was told to touch no `src/`.
