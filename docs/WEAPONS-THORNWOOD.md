# Weapons — Thornwood (Act 1, area 2)

**Design only; nothing here is built; the owner picks.** Ideas written by
Codex (2026-10-26) from the owner's ask: "i need codex to create ideas and
reference sheets for pets and weapons for area 2 now", then reviewed for
name clashes with the Mossy Glade, class silhouettes and tone (two effect
names lightly edited). The Mossy Glade's ladder and its rules are in
`PETS-FOREST.md` ("Weapon skins"); what a weapon is worth is
`src/shared/Config/WeaponStats.luau`.

**The rules they follow.** Per class (Ranger bow, Arcanist staff, Warden
greatsword) one weapon at each of Uncommon (+5% damage), Rare (+15%), Epic
(+25%), Legendary (+40% and an extra effect) and Mythic (+70% and an extra
effect), all times area 2's `areaScale` of 1.125. Every one keeps its
class's silhouette, so it sits in the same hand: a bow is recurve limbs, a
grip and a taut string; a staff is a long straight shaft, a head and a
pointed foot; a blade is a broad greatsword, crossguard, wrapped grip and
pommel. Legendaries and Mythics glow; Mythics glow rainbow. Epic and above
get their own projectile and trail (bows and staffs; blades are melee).
**Each area's Legendary costs coins plus its boss item: here Brood Silk**
(the Broodmother's), which is why the three Legendaries are silk weapons.

**Look.** Blocky voxel, few chunky bevelled parts, Thornwood's palette:
hedge green, bramble plum and maroon, cream thorns, boar brown, and the
Broodmother's purple, olive-gold and magenta
(`assets/concepts/blocky/arenas/area02_thornwood.jpg`, the Thornwood
enemies in `assets/concepts/blocky/enemies/act1/`, `boss02_thornweaver`).

**Effects.** None repeats the Mossy Glade's (Blaze, TrackingEye,
SpellPierce, ChainLightning, Shockwave, Whirlwind). Each would be a new
card carried as the weapon's `innate`, except Root Hold, which can reuse
the Stumpy pet's `Shared/Util/RootHold`. Numbers are starting points.

Reference sheets (Codex): `assets/concepts/blocky/weapons/skins/thornwood/<name>_views.png`,
all fifteen side by side in `contact_sheet.png` there.

| Rarity | Ranger bow | Arcanist staff | Warden blade |
|---|---|---|---|
| Uncommon | Boar Tusk Bow | Hedge Bulb Staff | Boarback Blade |
| Rare | Plum Burr Bow | Burr Totem Staff | Plumguard Blade |
| Epic | Lurker Vine Bow | Lurker Crest Staff | Burrcrest Blade |
| Legendary | Silkweaver Bow | Silk Diadem Staff | Silkbound Blade |
| Mythic | Prism Thistle Bow | Rainbow Burr Staff | Crownspike Blade |

---

## Ranger — bows

**Boar Tusk Bow** (Uncommon) `boar_tusk_bow_views.png`.
Boar-brown recurve limbs with curled cream tusk-shaped tips and two
hedge-green leafy blocks beside the wrapped grip; a plain cream string. Nothing glows.

**Plum Burr Bow** (Rare) `plum_burr_bow_views.png`.
Thick plum recurve limbs with a few big square burr studs, maroon bands
framing a cream-wrapped grip, a taut pale-green string. Nothing glows.

**Lurker Vine Bow** (Epic) `lurker_vine_bow_views.png`.
Angular hedge-green limbs bend round a cream bulb-shaped centre (the Bramble
Lurker) over a brown grip, sparse cream thorns pointing out, a faintly
glowing magenta string.
*Projectile:* a cream thorn arrow with green fletching, a short trail of
fading plum squares.

**Silkweaver Bow** (Legendary, coins + Brood Silk) `silkweaver_bow_views.png`.
Broodmother-purple limbs with olive-gold tip plates, a cream silk-wrapped
grip between two glowing magenta clasps, a luminous silk string; a soft
purple glow.
*Projectile:* a silk-wrapped arrow with a magenta crystal point, trailing two
fine violet silk ribbons.
*Effect:* "Silk arrows: every hit tangles the enemy in slowing webs."
(Web Snare: hits slow 30% for 2 s, refreshed by further hits; bosses slowed
less.)

**Prism Thistle Bow** (Mythic) `prism_thistle_bow_views.png`.
Broad plum limbs in stepped thistle shapes, big cream thorn plates sweeping
out from an olive-gold grip; the string, magenta inset crystals and limb
edges glow rainbow.
*Projectile:* a faceted magenta thorn arrow with a rainbow ribbon trail.
*Effect:* "Thistle arrows: every third hit bursts into thorns around the
target." (Thorn Burst: 60% weapon damage to the target and enemies near it;
a burst cannot set off another.)

## Arcanist — staffs

**Hedge Bulb Staff** (Uncommon) `hedge_bulb_staff_views.png`.
A straight boar-brown shaft holding a square cream bulb between two short
hedge-green brackets, a maroon hand wrap, a cream pointed foot. Nothing
glows.

**Burr Totem Staff** (Rare) `burr_totem_staff_views.png`.
A straight maroon shaft carrying a chunky plum burr cage round a solid
olive-gold orb, cream studs on the head, a long cream pointed foot. Nothing
glows.

**Lurker Crest Staff** (Epic) `lurker_crest_staff_views.png`.
A straight cream shaft ending in a rectangular hedge-green head frame whose
two angular vine brackets hold a softly glowing magenta-plum crystal; maroon
hand wrap, dark-green pointed foot.
*Projectile:* a floating cream seed orb in two green bands, trailing fading
square leaf marks.

**Silk Diadem Staff** (Legendary, coins + Brood Silk) `silk_diadem_staff_views.png`.
A straight purple shaft rising into an olive-gold crown-shaped head (the
Broodmother's crown) holding a glowing magenta orb in thick cream silk
straps; silk-wrapped handhold, gold pointed foot, a soft magenta glow.
*Projectile:* a magenta orb in a cream silk lattice, a narrow trail of
glowing gold squares.
*Effect:* "Diadem roots: every fourth orb roots its target in place."
(Root Hold: the first enemy the fourth orb hits is held 1 s; bosses are
slowed 40% instead. Can reuse `Shared/Util/RootHold`.)

**Rainbow Burr Staff** (Mythic) `rainbow_burr_staff_views.png`.
A straight olive-gold shaft holding a large plum burr frame of six blunt
cream spikes round a floating rainbow prism orb, a rainbow halo ring round
the head; the orb, shaft inlays and the purple pointed foot glow rainbow; a maroon wrap keeps the handhold clear.
*Projectile:* a rainbow prism cube trailing rainbow voxel squares (as drawn;
close to the Worldroot Staff's, so a candidate for a redraw).
*Effect:* "Burr spores: every orb leaves a stacking poison on its target."
(Spore Poison: each hit adds a stack of 30% weapon damage over 3 s, up to
five; cheerful green bubbles; poison sets off no other hit effects.)

## Warden — blades

**Boarback Blade** (Uncommon) `boarback_blade_views.png`.
A broad straight boar-brown greatsword with a flat cream edge and three
chunky green plates down its ridge; short cream tusks for a crossguard, a
maroon-wrapped grip and square brown pommel. Nothing glows.

**Plumguard Blade** (Rare) `plumguard_blade_views.png`.
A broad straight plum greatsword with stepped cream edge plates and a flat
maroon centre panel; a wide hedge-green crossguard, brown-wrapped grip,
cream cube pommel. Nothing glows.

**Burrcrest Blade** (Epic) `burrcrest_blade_views.png`.
A broad straight olive-grey greatsword with a raised plum centre ridge set
with a few big cream burr studs; a rectangular maroon crossguard, green
grip, plum burr pommel, a faintly glowing magenta inset at the blade's base.

**Silkbound Blade** (Legendary, coins + Brood Silk) `silkbound_blade_views.png`.
A broad straight purple greatsword with olive-gold edges and cream silk
bands crossing it below a glowing magenta rune (the Broodmother's); a gold
crossguard shaped like two friendly spider legs, silk-wrapped grip, square
purple pommel. The rune and silk seams glow.
*Effect:* "Boar rush: the slam shoves nearby enemies away from you."
(Boar Rush: the third-blow slam pushes enemies in its area back 8 studs;
bosses resist; walls stop them.)

**Crownspike Blade** (Mythic) `crownspike_blade_views.png`.
A broad straight plum greatsword, two thick cream edge rails framing a column
of big magenta crystal plates; an olive-gold crown-shaped crossguard,
maroon-wrapped grip, gold block pommel. The crystals, edges and pommel inset
glow rainbow.
*Effect:* "Crown cracks: the slam makes struck enemies take more damage."
(Crystal Fracture: enemies the slam hits take 30% more damage from players
and pets for 4 s; refreshes, does not stack.)

## Open decisions (the owner's)

1. Which of these to keep, rename or redraw.
2. The six effects and their numbers (each a new card except Root Hold).
3. Whether the Epic blades get anything beyond their glow, as the Epic bows
   and staffs get projectiles.
