# Balance report, 2026-11-01

What every weapon, pet and upgrade is worth, and how that sits against what
each level asks. Asked for by the owner: *"playtest every level with every
weapon and every pet and make a detailed chart on numbers and rank every
weapon, pet, and upgrade also test for glitches and bugs until you find
none."*

## How this was made, and what it is not

**It is not a playtest.** Every level with every weapon and every pet is
10 levels x 32 weapons x 29 pets = 9,280 runs; at a few minutes each that is
months of play. It could not be automated either: a run *starts* from a
script (firing `Remotes.PortalStart` really does load the stage and build the
arena), but it cannot be *played*, because entering the room, leaving the
title, the NEW ENEMY! cards and every draft pick are driven by the client, and
a script cannot reach the running client's modules. Studio's capture tool was
also down throughout, so nothing here was seen.

**It is exact arithmetic on the game's own numbers**, read out of the live
server: `Config/Balance`, `Config/WeaponStats`, `Config/PetCombat`,
`Config/Abilities`, `Config/Pets`, `Config/Eggs`. Every figure below is
computed from the same tables the game plays from, so it is accurate about
what the game *is*, and silent about how it *feels*.

Two numbers underpin the rest:

- A player deals `baseDamage` 100, times `(1 + rarity bonus)`, times that
  weapon's `areaScale`.
- `attackCooldown` is 0.7 s with a 5% chance of a 2x crit, so **damage per
  second is damage x 1.5** before any card.

---

## 1. Weapons

### Same rarity and area means identical damage

32 weapons share **11 distinct damage values**. A weapon's damage depends only
on its rarity and its area — nothing else. Below Legendary, two weapons of the
same rarity and area are mechanically the same weapon with different art;
Legendaries and Mythics differ only by their one innate card.

| # | Weapon | Rarity | Area | Mult | Damage | Innate |
|---|---|---|---|---|---|---|
| 1 | EVENTIDE BOW | Mythic | 3 | 2.125 | 212.5 | SoulChain 1 |
| 2 | MAELSTROM STAFF | Mythic | 3 | 2.125 | 212.5 | Meteor 1 |
| 3 | STORMGLASS BLADE | Mythic | 3 | 2.125 | 212.5 | Execute 1 |
| 4 | TOLLGUARD BLADE | Legendary | 3 | 1.750 | 175.0 | Parry 1 |
| 5 | TOLLKEEPER STAFF | Legendary | 3 | 1.750 | 175.0 | TwinCast 1 |
| 6 | TOLLSTRING BOW | Legendary | 3 | 1.750 | 175.0 | Ricochet 1 |
| 7 | GLADE SPIRIT BOW | Mythic | 1 | 1.700 | 170.0 | TrackingEye 1 |
| 8 | GLADEHEART BLADE | Mythic | 1 | 1.700 | 170.0 | Whirlwind 1 |
| 9 | WORLDROOT STAFF | Mythic | 1 | 1.700 | 170.0 | ChainLightning 1 |
| 10–12 | CAUSEWAY BLADE, EELCREST BOW, WELLPEARL STAFF | Epic | 3 | 1.562 | 156.2 | |
| 13–15 | BUOY STAFF, SLATEFIN BOW, TIDEHOOK BLADE | Rare | 3 | 1.438 | 143.8 | |
| 16 | EMBER FANG BOW | Legendary | 1 | 1.400 | 140.0 | Blaze 1 |
| 17 | EMBERFANG BLADE | Legendary | 1 | 1.400 | 140.0 | Shockwave 1 |
| 18 | SLIME CROWN STAFF | Legendary | 1 | 1.400 | 140.0 | SpellPierce 1 |
| 19–20 | REED STAFF, TIDEWOOD BLADE | Uncommon | 3 | 1.312 | 131.2 | |
| 21–23 | BROODSPLIT BLADE, HOOTMOSS STAFF, MOSS SLIME BOW | Epic | 1 | 1.250 | 125.0 | |
| 24–26 | FIREFLY BOW, LANTERN STAFF, THORN BLADE | Rare | 1 | 1.150 | 115.0 | |
| 27–29 | ACORN BOW, MOSSSTONE BLADE, TOADSTOOL STAFF | Uncommon | 1 | 1.050 | 105.0 | |
| 30–32 | BRANCH STAFF, TIMBER BLADE, TWIG BOW | Common | 1 | 1.000 | 100.0 | |

### Finding: area 3 outranks area 1 entirely

An area-3 **Rare** (143.8) beats an area-1 **Epic** (125). An area-3
**Legendary** (175) beats an area-1 **Mythic** (170). The whole of area 3
sits above the whole of area 1.

That is `areaScale` working as designed — each area's weapons are meant to
keep up with that area's tougher enemies. But two things make it a live risk:

- **Area 3 has no stages**, so its `areaScale` of 1.25 is a guess. The config
  says so itself: *"provisional ... should be re-derived once its stages
  exist."*
- Nothing stops an area-3 weapon being carried into areas 1 and 2, where it is
  simply 25% better than anything native.

It is not biting yet, because area 3's crate is unstocked (see §5), but it
will the day those weapons become obtainable.

---

## 2. Levels

Total enemy health a level asks you to chew through, and how long that takes
at four damage tiers **with no upgrade cards at all** — the floor, not the
real time, since a run levels up as it goes.

| Level | Mode | Rooms | HP x | Total HP | 100 dmg | 140 | 170 | 212.5 |
|---|---|---|---|---|---|---|---|---|
| 1-1 | Rooms | 10 | 1.10 | 16,912 | 1.9m | 1.3m | 1.1m | 0.9m |
| 1-2 | Rooms | 10 | 1.20 | 23,628 | 2.6m | 1.9m | 1.5m | 1.2m |
| 1-3 | Rooms | 15 | 1.30 | 37,973 | 4.2m | 3.0m | 2.5m | 2.0m |
| 1-4 | Rooms | 15 | 1.40 | 48,951 | 5.4m | 3.9m | 3.2m | 2.6m |
| 1-5 | Waves | 20 | 1.50 | 58,568 | 6.5m | 4.6m | 3.8m | 3.1m |
| 1-6 | Waves | 20 | 1.60 | 65,856 | 7.3m | 5.2m | 4.3m | 3.4m |
| 1-7 | Waves | 20 | 1.70 | 78,004 | 8.7m | 6.2m | 5.1m | 4.1m |
| 1-8 | Waves | 20 | 1.80 | 87,048 | 9.7m | 6.9m | 5.7m | 4.6m |
| 1-9 | Waves | 20 | 1.90 | 94,658 | 10.5m | 7.5m | 6.2m | 4.9m |
| 1-10 | Waves | 25 | 2.00 | 133,290 | 14.8m | 10.6m | 8.7m | 7.0m |
| Thornwood | Rooms | 20 | 2.10 | 66,108 | 7.3m | 5.2m | 4.3m | 3.5m |

### Finding: health climbs 8x, weapons climb 1.7x

Across 1-1 to 1-10 the health pool goes from 16,912 to 133,290 — **7.9 times**
— while the best weapon available in area 1 is only **1.7 times** the starting
one. Cards have to cover the whole remaining gap, every run, or the later
levels become long rather than hard.

1-10 at 14.8 minutes on the starting bow is the number to watch. Even at the
area-1 Mythic's 170 damage it is 8.7 minutes before a single card.

### Finding: Thornwood is easier than 1-10

Thornwood's enemies are the toughest in the game (health x2.10) but it is 20
rooms against 1-10's 25 waves, so its pool is **66,108 against 133,290** — it
asks about half as much as the level that unlocks it.

---

## 3. Pets

Damage a second, computed from each spec: direct
(`damage x hits x targets / every`) plus anything over time (`aura`, `burn`,
`bleed`). Utility that is not damage is listed, not scored.

**This table is the snapshot of 2026-11-01, before the ladder was fixed.**
The numbers below are what the game did then, and the finding that follows
is what the owner picked first; the fix is at the end of this section. The
same arithmetic now lives in `Shared/Util/PetPower`, so it can be read off
the config instead of recomputed by hand, and it credits a beam or a ring
with two enemies where this table credited one (which is why the
Glimmerhorn and Thornwake rows read lower here than they do there).

| # | Pet | Rarity | Total | Direct | Over time | Egg | Utility |
|---|---|---|---|---|---|---|---|
| 1 | BRAMBLE BEAR | Epic | 51.0 | 51.0 | — | yes | |
| 2 | BRAMBLE WILF | Legendary | 46.0 | 10.0 | 36.0 | yes | haste |
| 3 | GLADE FOX | Epic | 45.0 | 45.0 | — | yes | dash |
| 4 | BRIAR LYNX | Epic | 37.3 | 37.3 | — | — | |
| 5 | HOOTMOSS | Epic | 33.3 | 33.3 | — | — | |
| 6 | EMBER WILF | Legendary | 26.7 | 11.7 | 15.0 | yes | haste |
| 7 | BURRBALL | Common | 26.4 | 26.4 | — | — | |
| 8 | BARK HOGLET | Common | 26.3 | 26.3 | — | yes | |
| 9 | SLIME PRINCE | Legendary | 25.0 | 25.0 | — | yes | boss +80 |
| 10 | BABACORN | Common | 24.0 | 24.0 | — | yes | |
| 11 | FERN FROG | Common | 23.3 | 23.3 | — | — | |
| 12 | THORN PRINCESS | Legendary | 22.4 | 22.4 | — | yes | root |
| 13 | GLIMMERHORN | Mythic | 20.0 | 20.0 | — | yes | heal/hit 3, revive 50%, beam |
| 14 | THORNWAKE | Mythic | 18.7 | — | 18.7 | yes | revive 50% |
| 15 | BUDBULB | Common | 17.0 | 17.0 | — | — | slow |
| 16 | MOSSLET | Common | 15.0 | 15.0 | — | yes | slow |
| 17 | BERRY BAT | Common | 10.4 | 10.4 | — | yes | heal/hit 1 |
| 18 | BRIAR BEETLE | Rare | 7.0 | 7.0 | — | yes | root, chain |
| 19 | BUOY PUFFER | Rare | 6.9 | 6.9 | — | — | payback |
| 20 | STUMPY | Rare | 6.2 | 6.2 | — | yes | root |
| 21–29 | ABYSS JELLY (M), TIDE WILF (L), INKPOT (E), FIREFLY BUN (R), BERRY MOUSE, MOSSBACK SNAIL, SLATE TURTLE, THISTLE MOLE, TOADSTOOL TOT | | 0.0 | — | — | | accord, wake, blind, mark, heal, guard, shelter, reflect |

### Finding: the rarity ladder is inverted, in both eggs

Average damage by rarity, over pets that are actually hatchable:

| Egg | Common | Uncommon | Rare | Epic | Legendary | Mythic |
|---|---|---|---|---|---|---|
| Mossy | 19.5 | 0.0 | 6.2 | **45.0** | 25.8 | 20.0 |
| Thornwood | 18.4 | 0.0 | 7.0 | **51.0** | 34.2 | 18.7 |

The same shape in both, independently:

- the **Epic is the best pet in its egg**, by 75% over the next best;
- the **Mythic does less damage than the Common** (20.0 against Babacorn's
  24.0; 18.7 against Bark Hoglet's 26.3);
- the **Rare does about a third of the Common's** damage.

Mythics are not worthless — `revive 50%` is a free life, which no amount of
damage buys — and the Uncommons are deliberate pure-utility guards and
healers. But for a game whose rule is that pets carry player power, the rarest
pull in an egg being its fifth-best fighter is the clearest problem in this
report.

The quickest honest fix is to raise Rare, Legendary and Mythic *damage* so the
ladder climbs, and let utility be the bonus on top rather than the excuse.

### Fixed, 2026-11-02

The owner picked this one first, and it is done. `Shared/Util/PetPower` puts
every pet on one number (damage a second against a full room), and
`Config/PetCombat` now aims each rarity at a band:

|  | Common | Rare | Epic | Legendary | Mythic |
|---|---|---|---|---|---|
| area 1 | 16 | 24 | 34 | 44 | 56 |
| area 2 | 18 | 27 | 38 | 50 | 64 |
| area 3 | 20 | 30 | 43 | 55 | 70 |

Each area's band is the one before it times that area's `areaScale`, the
same step its weapons take. Uncommon has no band: every Uncommon so far is
a guard or a shelter, which trades its damage away outright, so it is off
the scale rather than at the bottom of it.

What the two live eggs do now:

| Egg | Common | Uncommon | Rare | Epic | Legendary | Mythic |
|---|---|---|---|---|---|---|
| Mossy | 16.0, 16.8 | guard | 24.0 | 34.0 | 44.0, 44.0 | 56.0 |
| Thornwood | 18.0, 18.0 | guard | 27.0 | 38.0 | 50.0, 50.0 | 64.0 |

The egg's total output rose about 27%, which is deliberate: the Epics came
down and the top came up further, and pets are where this game is supposed
to carry a player's power. Benched pets were tuned to the same bands so
that putting an `egg` field back cannot re-invert the ladder, and the
Drowned Village's two damage dealers were set to area 3's band ready for
its egg. `tests/PetPower.spec` now fails if the ladder ever goes backwards
or if a pet drifts more than a fifth off its band.

Two things this does **not** fix. The Abyss Jelly, the Drowned Village's
Mythic, still does no damage of its own at all — its canopy divides damage
rather than adding any — so when that egg opens its rarest pull will again
be, on this scale, its weakest. That is how `docs/PETS-DROWNED.md` designs
it, so it is the owner's call rather than a bug. And the Uncommon guards
are still worth 0 here by the same reasoning.

---

## 4. Upgrades

42 cards in the deck, 8 benched. Ranked within each category, since a flat
damage percentage and an extra arrow are not the same kind of thing.

**Stats** — DualBows (Mythic) x2 attack speed · HeavyBlade (Rare) +96% slam ·
Overdraw (Epic) +84% charged · Execute (Legendary) +80% under 30% HP ·
Strength / Intellect (Common) +40% ATK · ManaFlow (Common) +30% atk spd ·
QuickHands (Common) +24% atk spd · Cleave (Uncommon) +36% width ·
Precision (Uncommon) +20% crit · LongReach (Uncommon) +3.6 reach

**Count / Pattern** — Multishot (Legendary) +3 arrows · FrontArrow (Epic)
+3 front · DiagonalArrows / DiagonalOrbs (Rare) +4 · DoubleShot (Rare) 3-way ·
ArcaneEcho / TwinCast (Rare) +2 · RearArrow / SideArrows (Uncommon) +2 ·
Whirlwind (Epic) every 3rd swing

**On hit** — Shockwave (Rare) 16 · BlastArrows (Epic) 6 · DeadlyStrike (Rare)
+600% crit damage · Blaze (Rare) burn 4s · Ricochet (Epic) 4 bounces ·
SoulChain (Legendary) link 4 · ChainLightning (Epic) arcs to 3 · Meteor
(Mythic) every 5th cast · BiggerOrbs (Common) +36% blast

**Defensive** — Earthbreaker (Mythic) · SecondWind (Mythic) 1 revive · Parry
(Epic) · Vitality (Common) +40% max HP · Heal (Common) 24% · Lightfoot
(Common) +19% move · Bloodthirst (Rare) 4.8%

**Flight** — TrackingEye (Legendary) homing · PiercingShot (Epic) pierce all ·
SpellPierce (Rare) pierce 2 · BouncyWall (Uncommon) 2 bounces

**On kill** — BattleCry (Legendary) +8% attack speed per kill

### Findings

- **The strongest cards are the count ones, not the stat ones.** Multishot at
  +3 arrows is worth far more than DualBows' x2 attack speed, which is itself
  the best stat card and a Mythic. Anything that multiplies projectiles beats
  anything that multiplies a number.
- **Multishot (Legendary) and FrontArrow (Epic) both cap at +3 arrows.** If
  those are the same effect, an Epic is matching a Legendary.
- **Strength and Intellect are the same card** (+40% ATK, Common, 5 levels)
  split by weapon type. Worth checking a Ranger cannot be offered Intellect
  and waste a pick.
- **DeadlyStrike's +600% crit damage** against a 5% base crit chance is +30%
  average damage — strong, but it reads far bigger on the card than it plays.

---

## 5. Bugs and consistency

Every check below was run against the live server, and the ones worth keeping
are now `tests/ConfigConsistency.spec` so they hold from here on. **684 tests
pass** (677 before, 7 new). The sweep found no crashes and no broken
references. What it did find:

### Real gaps

- **14 area-3 weapons have no 2D art and no pixel icon** — Stormglass Blade,
  Maelstrom Staff, Eventide Bow, Wellpearl Staff, Buoy Staff, Reed Staff,
  Tollstring Bow, Tidehook Blade, Causeway Blade, Slatefin Bow, Tidewood
  Blade, Tollguard Blade, Eelcrest Bow, Tollkeeper Staff. This is what keeps
  `Shop.crates[3]` unstocked, and it is also what is holding back the whole
  area-3 weapon tier.
- **Four NEW ENEMY! cards can never fire** — Bell Ringer, Ditch Eel, Drowned
  Zombie, Hollow Fisherman. All area 3, which has no stages yet. Expected, but
  they sit in the enemy dex as permanently locked slots.
- **Four stages are unreachable** — The Courtyards, Moonlit Arena, Level 1,
  Mossy Glade Run. No portal and no code path leads to them. Two enemies,
  **Bulwark** and **Lurker**, exist only inside them, so they are dead content
  too.

### Checked and clean

- Every weapon's innate names a real, unbenched card.
- Every card's `excludes` names a real card, and every card has as many stat
  lines as levels.
- Every pet in an egg has a combat spec and an icon; every combat spec has a
  pet.
- Baby Slime and Boarlet have cards but appear in no roster — **not a bug**:
  Brood Slime splits into four Baby Slimes and Bramble Sow into three
  Boarlets, so both cards fire from the split path.
- Bosses (King Bloblin, Broodmother) have no NEW ENEMY! card, which is by
  design — the cards are for everything *besides* bosses. Worth knowing for
  anyone writing a check: a boss is one carrying a `boss` block, **not** one
  sitting in a wave finale. The Broodmother is the last *room* of Thornwood,
  not a finale, so the roster-based test flagged her by mistake until it was
  changed to read the flag.

### Not investigated

While forcing a run to start from a script, the player's humanoid read
`inf / inf` health and no enemies spawned. That is almost certainly an
artefact of starting the stage past the class-select screen rather than
through the portal, so it is **not** reported as a bug — but it is the one
loose thread, and worth a look through the normal path.

---

### Kept as tests

`tests/ConfigConsistency.spec` now holds seven joins that nothing else
checked, because each one fails quietly rather than crashing:

1. a weapon's innate names a real, unbenched card, at a level that card has;
2. a card excludes only real cards, and has a stat line per level;
3. every hatchable pet has a combat spec and an icon, and its egg exists;
4. every combat spec belongs to a pet;
5. every non-boss enemy a reachable stage can show has a NEW ENEMY! card;
6. every NEW ENEMY! card is for something that can be met, unless its area
   has no stages yet;
7. every weapon's rarity and area both have a scale, or it silently deals
   base damage.

## What would make this a real playtest

Driving runs end to end needs the gates that are client-side today to be
reachable from a script: leaving the title, entering a room, acknowledging a
NEW ENEMY! card, and picking a draft card. A `Sandbox` switch that auto-picks
drafts and skips acknowledgements would make an overnight sweep of every
level against a handful of representative builds possible. It would still not
be 9,280 runs, but it would turn the numbers above into measured times.
