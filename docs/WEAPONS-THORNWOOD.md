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
| Mythic | **Nightbarb Bow** | **Blackspine Staff** | **Briarbreaker Blade** |

---

**The Mythics are the masculine set** (owner, 2026-10-26: "the mythic
weapons for this one should be masculine and really cool. the gladeheart
mythics are cool for area 1 and are more feminine. i want a more masculine
design for these ones"). Area 1's Glade Spirit Bow, Worldroot Staff and
Gladeheart Blade are elegant (flowers, leaves, pastel sparkle); Thornwood's
are their opposite: heavy and angular, in blackened bramble wood, dark iron
and obsidian, with tusks, thorn spikes and a fierce boar-head emblem, and
their Mythic rainbow is fierce energy (cracks, runes, edge glow, flame-like
wisps). Redesigned and renamed by Codex the same day; the first drafts
(Prism Thistle Bow, Rainbow Burr Staff, Crownspike Blade) are kept as
`*_old_views.png`.

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

**Ironwrath Bow** (Mythic) `old/ironwrath_bow_views.png` (superseded by the Nightbarb Bow).
A massive recurve war bow: thick angular limbs of blackened bramble wood
armoured in dark iron plates, ivory tusk hooks at the tips, jagged cream
thorn spikes along the limbs, a fierce iron boar-head emblem above the
leather grip. Rainbow energy burns through cracks in the limbs and the
emblem's eyes; the string is rainbow light; flame-like rainbow wisps stream
off the tips.
*Projectile:* a heavy black arrow with a barbed obsidian head, a blazing
rainbow core and a short jagged rainbow trail.
*Effect:* "Thistle arrows: every third hit erupts into jagged thorns around
the target." (Thorn Burst: 60% weapon damage to the target and enemies near
it; a burst cannot set off another.)

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

**Ruinmaul Staff** (Mythic) `old/ruinmaul_staff_views.png` (superseded by the Blackspine Staff).
A long straight shaft of blackened bramble wood bound in dark iron, a pointed
iron foot, and on top a heavy squared mace-like head of dark iron and
obsidian with ivory tusk flanges and cream thorn spikes, plum and olive-gold
trim. Carved runes blaze rainbow and rainbow fire vents from cracks in the
head.
*Projectile:* a dense obsidian orb with burr studs and molten rainbow
cracks, trailing a tight tongue of rainbow flame.
*Effect:* "Burr blight: every orb poisons its target, stacking with repeated
hits." (Each stack 30% weapon damage over 3 s, up to five; poison sets off no
other hit effects.)

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

**Havocjaw Blade** (Mythic) `old/havocjaw_blade_views.png` (superseded by the Briarbreaker Blade).
A very broad cleaver-like greatsword: a flat black obsidian blade with a thick
dark-iron spine, angular cream thorn teeth along the back edge, plum inlays;
the crossguard a fierce iron boar head whose ivory tusks sweep up the blade;
leather grip, heavy iron pommel with a rainbow gem. Rainbow energy sears
through cracks across the blade and runs the whole cutting edge, flaring
into flame-like wisps.
*Effect:* "Ruin cracks: the slam makes struck enemies take more damage."
(Enemies the slam hits take 30% more damage from players and pets for 4 s;
refreshes, does not stack.)

## The Mythics: the owner's picks (2026-10-26: "briarbreaker, blackspine, and nightbarb bow")

The Thornwood Mythics are the **Nightbarb Bow**, the **Blackspine Staff** and the **Briarbreaker Blade** (sheets beside the others in `weapons/skins/thornwood/`). The unpicked takes, the Dreadbriar Staff and the Gloamspike Blade, are kept in `options/`; the Blackbriar Siege Bow was never drawn. The Mythic entries in the class sections above (Ironwrath, Ruinmaul, Havocjaw) are superseded and their sheets are in `old/`.

### The takes, as offered

The owner, after the Ironwrath Bow, Ruinmaul Staff and Havocjaw Blade
(2026-10-26): "try again on the weapons". So two takes per class, written
and drawn by Codex: darker and more grounded, like a top-tier dark-fantasy
hero's item, a bold heavy silhouette that reads at a glance, a restrained
palette (blackened iron, obsidian, bone, deep bramble red-purple) with the
Mythic rainbow as one fierce accent only, no faces. Sheets in
`assets/concepts/blocky/weapons/skins/thornwood/options/`, side by side in
`options/options_contact.png` (top row take A, bottom row take B). The
earlier drafts are in `old/` (Ironwrath, Ruinmaul, Havocjaw) and
`*_old_views.png` (Prism Thistle, Rainbow Burr, Crownspike). Each class
keeps its effect whichever take is picked:

- Bow: "Thistle arrows: every third hit erupts into jagged thorns around
  the target." (Thorn Burst, 60% weapon damage around the target.)
- Staff: "Burr blight: every orb poisons its target, stacking with repeated
  hits." (30% over 3 s, up to five stacks.)
- Blade: "Ruin cracks: the slam makes struck enemies take more damage."
  (+30% damage taken for 4 s.)

| Class | Take A | Take B |
|---|---|---|
| Bow | **Blackbriar Siege Bow**: a giant, thick recurve of blocky blackened-iron plates over red-purple bramble bindings, bone wedges at the tips; rainbow: one core gem above the grip. Arrow: heavy black, bone tip. `blackbriar_siege_bow_views.png` | **Nightbarb Bow**: long, lean predator bow, obsidian limbs with swept-back fins and hooked tips, bone inlays, red-purple grip; rainbow: a row of runes down each limb. Arrow: slender obsidian, needle bone point, rainbow streak. `nightbarb_bow_views.png` (**picked**) |
| Staff | **Dreadbriar Staff**: a war-maul, a heavy spiked iron hammer head with bone end plates on a long red-purple-wrapped shaft, iron spike foot; rainbow: one square core gem in the hammer. Orb: dark purple core in four floating iron segments. `options/dreadbriar_staff_views.png` | **Blackspine Staff**: tall thorned scepter-spear, an obsidian spearhead between two hooked bone prongs, bone thorns up the wrapped shaft; rainbow: fire along one edge of the spearhead. Orb: dark violet with three bone splinters and a rainbow flame trail. `blackspine_staff_views.png` (**picked**) |
| Blade | **Briarbreaker Blade**: broad slab cleaver, an iron-framed obsidian face with stepped iron teeth on its spine, wrapped in thorned bramble, heavy block crossguard; rainbow: one gem at the blade's base. `briarbreaker_blade_views.png` (**picked**) | **Gloamspike Blade**: long jagged greatsword, a spear point and staggered obsidian and bone barbs down both edges, a spiked crossguard; rainbow: a line of runes down the centre rib. `options/gloamspike_blade_views.png` |

## Open decisions (the owner's)

1. Which of these to keep, rename or redraw. ~~Which Mythic take per class~~: decided, the Nightbarb Bow, Blackspine Staff and Briarbreaker Blade (owner, 2026-10-26).
2. The six effects and their numbers (each a new card except Root Hold).
3. Whether the Epic blades get anything beyond their glow, as the Epic bows
   and staffs get projectiles.
