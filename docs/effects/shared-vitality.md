# Shared vitality upgrades — effects and animations

The six upgrades every class is dealt: health, regeneration and survival. None
of them fires a projectile, so none of them is visible unless we make it
visible, and an upgrade the player cannot see feels like it did nothing. Each
section below says what the effect is, **when** it fires, and which GLB carries
it.

Designed in Claude Design, blocky house style — faceted, flat-shaded,
hard-edged, saturated flat colour, every piece a cube. Project:
<https://claude.ai/design/p/0a3ca780-809a-4bf0-8a69-ac7c0bc3cdb2>
("Arrow Legends voxel props").

## The vocabulary this has to fit

`Fx/HitFeedback`, `Fx/HitSquash` and the HitVignette already decide how damage
reads: a red flash on the body, a number that falls away, a squash about the
feet, a red flare at the screen edge, a shake. Healing is written here as the
**exact inverse of each of those**, so the two never look like two different
games:

| damage reads as | healing reads as |
| --- | --- |
| red body flash | soft green/white body wash |
| damage number falls | heal number **rises** |
| body squashes down | body **stretches up** (`HitSquash` run with a tall pose) |
| red vignette at the screen edge | a brief green rim, dimmer and slower |
| shake | no shake, ever |

Nothing here is a projectile and nothing here is authoritative. The server has
already decided every heal, every revive and every stat; these are the client's
account of it.

## Lightfoot — Common, +8/16/24% move speed

**GLB:** `fx_lightfoot.glb` — SPEED PUFF.

Two stacked chevron wedges of pale-cyan and white cubes, a cartoon wind-dash
mark, with a single white wing-feather shard riding above them. Pops out wide,
sweeps backwards, shrinks to nothing in about 0.4s.

**When it fires:** continuously while the player is *moving* — one puff shed
behind the feet every fixed distance travelled (distance, not time, so the cue
is tied to speed rather than to a clock, and a standing player makes none).
A heavier double puff plays once the moment the card is taken, so the player
sees what they bought. Stacks make the puffs come closer together, which is the
whole point: at level 3 the player leaves a near-continuous trail.

**Why:** movement speed is the one stat the player feels in their hands within
a second, so the cue only has to confirm it, not announce it. It lives at the
feet and behind, never in front, so it never competes with the aim.

## Vitality — Common, +10–50% max HP

**GLB:** `fx_vitality.glb` — HEART BLOCK.

A chunky voxel heart in saturated red with a white cross set into its face
(the card's icon, in three dimensions). Pops in with an overshoot, beats twice,
settles.

**When it fires:** once, on take — the heart block pops above the player's head
and beats twice while the **health bar's track grows**. The growth is the real
effect and it belongs on the bar, not on the character: the bar lengthens by the
new share with a chunky block snapping onto its end, and that extra segment stays
there for the rest of the run. The character itself shows nothing afterwards.

**Why:** a permanent stat with no moment has to borrow one. The heart block is
the moment; the longer bar is the permanent record, and it is where the player
is already looking when they next take a hit.

## Mending — Uncommon, 1/2/3% HP a second

**GLB:** `fx_mending.glb` — LEAF MOTE.

Three small green voxel leaves around a tiny brown soil cube — the card's sprout,
broken into motes. They rise, turn slowly about the vertical axis, and shrink
out over about 1s.

**When it fires:** **once a second, only while the player is below full health.**
One mote per tick, rising off a shoulder. At full health it goes silent — that
silence is deliberate and is half the information: it tells the player the regen
is being wasted, which is exactly when they should be pushing forward.

**Why:** a regeneration tick that is invisible is indistinguishable from no
regeneration at all. A once-a-second rising mote gives the tick a heartbeat the
player can count, and the rise is the inverse of a falling damage number.

## Bloodthirst — Rare, heal 2/4/6% a kill

**GLB:** `fx_bloodthirst.glb` — LIFE DROP.

A chunky crimson voxel droplet, wide at the base and stepped to a point, with a
small saturated-green voxel plus beside it. The droplet travels a short arc; the
plus flashes and expands as the droplet is absorbed. About 0.8s.

**When it fires:** the instant an enemy **dies** — one droplet per kill, spawned
at the enemy's death position and drawn in to the player's chest, where the plus
flashes on arrival. It rides the death pop `HitFeedback` already plays, half a
beat behind it, so a kill reads as one event and not two.

**Why:** this is the one card in the group with a trigger the player already
causes on purpose. Tying the cue to the corpse and pulling it *inwards* makes the
kill and the heal the same action — and the inward pull is the visual opposite of
damage, which always travels outward from the body.

## Second Wind — **Mythic**, revive once at half HP

**GLB:** `fx_secondwind.glb` — WINGED HEART. The hero piece.

A crimson voxel heart with blocky white and pale-blue wings spread wide either
side and a flat gold voxel halo hovering above — the card's icon, at Mythic
volume. The wings beat once, hard; the heart flares; a ring of small gold cubes
bursts outward and upward off the halo. About 1.6s.

**When it fires:** the instant lethal damage lands and Second Wind spends —
*before* the player stands, not after. The order is: the killing hit lands and
reads as a death for a held beat (the player must believe it), the winged heart
rises out of the body and beats, and the burst off its halo becomes the golden
ring `Fx/ReviveFx` already fires.

**This extends `Fx/ReviveFx` rather than competing with it.** ReviveFx already
owns everything after the burst — the gold ring at `Balance.Revive.clearRadius`,
the white flash, the "REVIVED!" call-out, the ForceField bubble that flickers out
as the server's grace ends, and the clearing of enemy shots. Second Wind adds the
*cause* in front of it: the held beat, the winged heart, the wing-beat, and the
halo burst that hands off into ReviveFx's ring. The call-out changes word —
**"SECOND WIND!"** in the same GothamBlack gold — so the player can tell a spent
Mythic from an ordinary revive. Nothing after the hand-off is duplicated.

**Why:** it is the only card in this group that is allowed to stop the room, and
the only one whose job is emotional rather than informational. The held beat is
the whole design: a revive the player never doubted is a revive they will not
remember.

## Heal — Common, restore 30% now (the Angel's offer, and the filler card)

**GLB:** `fx_heal.glb` — LIFE FLASK.

A blocky potion bottle — white and pale-blue glass cubes, saturated red liquid
filling the lower half, a brown cork cube on top. It tips, pours a short ribbon
of red cubes down out of its neck, and bursts into a few shards. About 1s.

**When it fires:** **once, immediately on pick-up**, and never again — `Heal` is
`instant = true` and carries no level. The flask tips above the player's head,
the ribbon pours down into them, and the body takes a *stretch* (the inverse
`HitSquash` pose) as the health bar fills, with a rising heal number and a brief
green rim.

**Why:** the only instant card in the deck, and usually the one taken when the
player is hurt and frightened. It needs a visible quantity — the poured ribbon is
that quantity, long enough to feel like 30% and short enough not to hold the run
up.

## What is not in this change

No config and no `src/client/Fx/` code: this file and the GLBs are the design.
Wiring each cue to its trigger (`AbilityEffects`, the health-bar growth, the
`ReviveFx` hand-off) is the implementation that follows.
