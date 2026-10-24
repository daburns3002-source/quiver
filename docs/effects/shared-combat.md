# Shared combat upgrades: effects and animations

The six upgrades every class can draft — `DeadlyStrike`, `Strength`, `Precision`,
`Blaze`, `Momentum`, `Agility` in `src/shared/Config/Abilities.luau`. This file is
the design for what each one *looks like* in a run. Nothing here is wired up yet:
each effect is a GLB in the owner's Downloads waiting for a hand import in Studio.

**The constraint that shaped all six.** These cards are dealt to Rangers, Arcanists
and Wardens alike, so an effect that lived on the weapon would have to be drawn
three times — once for a bow, once for a staff, once for a sword — and would read
differently each time. None of these does. Every one is anchored to either the
**player's body**, the **enemy**, or the **point of impact**: things all three
classes share. The anchor is named in each section, and it is the first thing to
check if one of these is ever reworked.

**Restraint.** One Common, two Uncommons and three Rares. None of these is a
Legendary and none should look like one: no glow planes, no particles beyond the
burn that already exists, no emissive halos. The cubes are the whole effect. That
also keeps them cheap enough for the lowest device tier, where `Config/DeviceTiers`
turns bloom and trails off.

**Style.** All six were built in Claude Design from the card's own icon
(`assets/ui/glow_toy_cards/icons_transparent/`) plus
`assets/concepts/blocky/arenas/area01_mossy_glade.jpg` as the style reference:
axis-aligned cubes of varied sizes, flat shaded, hard edges, no textures, saturated
colours. Every clip steps between frames rather than easing, because smooth
interpolation reads as a different art style from the rest of the game.

---

## Deadly Strike — Rare, +crit damage

**Project:** https://claude.ai/design/p/8945fcbc-3e33-4a74-a2d1-ffd2d212a47f
**GLB:** `fx_deadlystrike.glb`

**Anchor: the impact point.** Not the weapon, not the player.

Deadly Strike does nothing until a hit crits (`Stages.crit`, its multiplier raised
by the card's level on top of `Balance.Player.critMultiplier`). So the effect fires
only on a crit, which keeps it rare enough to stay a reward rather than wallpaper.
A bone-white voxel skull with square red eyes — the card's icon, built in 3D — snaps
to full size at the point of impact in two stepped frames, holds for 0.12 s with the
red eye cubes one step brighter, then breaks: eight shards fly out and down along
straight lines, spinning in 90° steps, shrinking to nothing. The clip is 0.45 s and
is named `Strike`.

The shards sit flush against the skull at rest, so the model is one solid skull
until the clip plays.

**On the three weapons:** identical, because it is drawn where the damage lands. An
arrow hit, an orb hit and a sword swing each produce the same skull in the same
place. It layers correctly with the crit damage number, which appears at the same
point — the skull is the *reason* that number is big.

---

## Strength — Common, +ATK

**Project:** https://claude.ai/design/p/db1a0713-05cf-4b39-b773-e2a9689de2bc
**GLB:** `fx_strength.glb`

**Anchor: the player's upper arms.**

Strength is a flat damage multiplier with no event to hang an effect on — it has no
moment, it is simply true all the time. So it gets a **persistent tell** rather than
a flash: two chunky red voxel cuffs, `ArmBandLeft` and `ArmBandRight`, that clamp
round the character's upper arms and stay there for the rest of the run. Each cuff
carries a pale grey-white grip bar across its outer face, lifted straight from the
dumbbell in the card icon, so the pair reads as that dumbbell from the game camera.

Two clips. `Settle` (0.35 s, once) plays when the card is drafted or levelled: the
cuffs drop in from a quarter unit above, overshoot one cube-step inward and snap to
rest, the grip bars flashing one step brighter as they land. `Flex` (0.4 s, once) is
the draft moment's push — `FlexRing`, a closed stepped voxel ring, starts small and
pushes outward while its segments flatten and vanish one at a time.

Being the only Common here, it is deliberately the quietest thing in the set: at
rest it is two small bands on the arms and nothing else.

**On the three weapons:** the arms are the same arms whichever hand holds a bow, a
staff or a sword, and the cuffs sit above the elbow, clear of every grip.

---

## Precision — Uncommon, +crit chance

**Project:** https://claude.ai/design/p/703fa969-1eb3-4cd5-a3d8-c2f46acfd048
**GLB:** `fx_precision.glb`

**Anchor: the enemy currently being aimed at.**

Precision raises `Balance.Player.critChance`, which is also a number with no moment
of its own — and it would be invisible next to Deadly Strike if both fired at the
instant of a crit. So Precision reads *before* the shot instead of after it: a flat
voxel reticle lies on the ground under the current target. A closed stepped red ring
2.8 units across, four white pips at twelve, three, six and nine o'clock, and a red
plus at the centre — the card icon, laid flat.

`Track` (2.0 s, looping) turns the ring through 90° in four stepped quarter-turns
while the pips bob in sequence and the centre plus holds still. `Lock` (0.3 s, once)
snaps the four pips one cube-step inward and brightens the ring, then returns to
rest; that is the beat to play as a shot leaves.

Splitting the two power cards this way means a player holding both sees *aim* and
*payoff* as two separate things, which is what the two cards actually are.

**On the three weapons:** it is drawn under the enemy, so it never touches the
player's hands, and it reads the same whether what arrives is an arrow, an orb or a
blade.

---

## Blaze — Rare, burn on hit

**Project:** https://claude.ai/design/p/5d17fdd8-10bb-49b8-a965-8ebbe800565d
**GLB:** `fx_blaze.glb`

**Anchor: the burning enemy. Extends `src/client/Fx/BurnFx.luau`; it does not
replace it.**

`BurnFx` already puts a flame particle emitter on any model carrying the `Burning`
attribute, at `Device.tier().burnParticleRate`. That rate is deliberately never zero
— on the lowest tier a burning enemy still has to look different from one that is
not, or Blaze is invisible there. **Keep all of that.** What is missing is that four
particles a second is a thin read: on the lowest tier Blaze is technically visible
but barely legible.

The fix is geometry, which costs the same on every tier: a voxel ember tuft that
sits on the burning enemy alongside the emitter. Three tapering tongues of cubes —
`FlameLeft`, `FlameCentre`, `FlameRight` — deep red at the roots through orange and
amber to white-hot tips, 42 cubes, 1.6 units wide and 1.8 tall, the side tongues
leaning outward so the trio flares. `Flicker` (0.9 s, looping, 5 stepped frames)
scales each tongue on Y between 0.85 and 1.15 and bobs it, the three out of phase.

So the tuft carries the read on every tier and the existing particles stay as the
richer layer on top. The tuft goes on and off with the same `Burning` attribute and
the same poll `BurnFx` already runs; nothing about when a burn starts or ends
changes.

**On the three weapons:** the flame is on the enemy, which is the one place all
three classes' damage ends up.

---

## Momentum — Rare, attack speed banked while moving

**Project:** https://claude.ai/design/p/423f97ae-4c50-4539-b69d-6feeb03e3261
**GLB:** `fx_momentum.glb`

**Anchor: the player's feet. Two tells, not one.**

Move-or-shoot means nothing fires while you move, so Momentum banks speed over
`Balance.Player.momentum.windup` (0.5 s) of movement and spends it over the
`duration` (2 s) of shooting after you stop. That is two different states, and a
player has to be able to feel both or the card is just a number in a menu. One
effect cannot say both, so there are three clips across two pieces.

**Banking, while moving.** `SpeedSlab` — a single cyan bar three cubes long, taken
from the three cyan speed lines in the card icon. `Bank` (0.5 s, looping) has one
appear small at the heel, snap to full size, slide about 1.5 units backwards and
shrink away. While the player moves these trail off behind them; the bank is filling
when the slabs are coming steadily.

**Charged, standing still with the bank full.** `BankRing` — a closed octagonal ring
of 16 dark slate segments round the player's feet, 2.6 units across, with the icon's
three cyan bars stacked at its centre. `Charged` (0.8 s, looping) lights all 16
segments cyan and runs a one-cube-step wave round the ring. This is the "you have
something to spend" state.

**Spending, during the two seconds of fire.** `Spend` (2.0 s, once) puts the ring
segments out one at a time anticlockwise across exactly those two seconds, while the
three centre bars drop away one every two-thirds of a second. It is a readable
countdown: when the ring is dark the bonus is gone and it is worth moving again.

That loop — move, see the slabs, stop, see the ring lit, shoot, watch it drain — is
the move-or-shoot mechanic made visible, which is the whole point of the card.

**On the three weapons:** all of it is at the feet, below any weapon, and the spend
is tied to the firing cadence rather than to a draw, a cast or a swing.

---

## Agility — Uncommon, dodge chance

**Project:** https://claude.ai/design/p/fa8d1462-a3bd-4355-852e-01434213e72b
**GLB:** `fx_agility.glb`

**Anchor: the player's body.**

Agility is `dodgeChance` — a roll that makes an incoming hit miss. A dodge is the one
moment in the card's life where something actually happens, and without an effect it
is indistinguishable from an enemy attack that simply missed. So the effect fires
only on a successful dodge: the player leaves a pale ice-blue voxel after-image of
themselves, a blocky humanoid 2.2 units tall built from large cubes only — one cube
head, a two-by-two torso, an arm each side, two legs with a gap between them —
caught mid-stride and carrying **no weapon**.

`Dodge` (0.4 s, once): the after-image appears at full colour, slides 1.2 units
backwards along its own facing in three stepped frames while fading, and at the
halfway frame two small cubes pop out behind it and shrink away — the two trailing
cubes from the card icon.

The pale ice blue sits on the top and front faces and the deeper blue on the sides
and back, because the game camera looks down at about 45° and those are the faces a
player sees.

**On the three weapons:** it is a copy of the body with the weapon left off on
purpose, so one silhouette serves all three classes and nothing has to be posed per
weapon.

---

## For the owner

Six GLBs are waiting in `Downloads`, to import by hand (File → Import 3D, Merge
Meshes **off**, so the named nodes survive):

| File | Size | Nodes | Clips |
|---|---|---|---|
| `fx_deadlystrike.glb` | 317 KB | `SkullMark`, `Shards` | `Strike` |
| `fx_strength.glb` | 1.3 MB | `ArmBandLeft`, `ArmBandRight`, `FlexRing` | `Settle`, `Flex` |
| `fx_precision.glb` | 90 KB | `Ring`, `Pips`, `Core` | `Track` (loop), `Lock` |
| `fx_blaze.glb` | 27 KB | `FlameLeft`, `FlameCentre`, `FlameRight` | `Flicker` (loop) |
| `fx_momentum.glb` | 56 KB | `SpeedSlab`, `BankRing` | `Bank` (loop), `Charged` (loop), `Spend` |
| `fx_agility.glb` | 60 KB | `Afterimage`, `TrailCubes` | `Dodge` |

Two things a GLB cannot carry, which will have to be code when these are wired up:

- **Colour changes inside a clip.** The brighter red eyes in `Strike`, the lit ring
  in `Charged` and the brightened ring in `Lock` are all colour swaps. GLB animation
  moves and scales nodes; it does not change materials. Each of those is a `Color3`
  change on the part in Roblox.
- **The fade in `Dodge`.** Same reason — the after-image's fade is a `Transparency`
  tween, not something the clip holds. The clip carries the slide and the cube pop.

`fx_strength.glb` is much the largest of the six because each cuff is a dense grid of
separate cubes; it is worth putting through the slimming step before import if the
triangle count is a problem.
