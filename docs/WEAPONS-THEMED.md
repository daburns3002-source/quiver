# Weapons — the themed sets (no area)

**Asked for by the owner on 2026-11-18** ("we need to make weapons now for the game that are
not area specific", in themed lines), plan approved the same day ("Neon Circuit, yes").

A themed set is one theme across one weapon for every class: a bow (Ranger), a staff
(Arcanist), a blade (Warden) and a dagger (Assassin; one model, a copy in each hand). It
belongs to no area. **Every set is an original design for this game**, named and drawn in its
own blocky style: a set takes only the broad genre of a theme (neon electronics, a starry
wish, the wild west), never another game's names, logos, characters or the look of any of its
items, and no other game is named anywhere in the game or its store text. A set that could be
mistaken for another game's art is a redo.

## The rules (`Config/Shop.sets`, `Util/ShopRules`, `tests/WeaponSets.spec`)

| | An area's weapon | A set's weapon |
|---|---|---|
| Belongs to | `WeaponStats.area` (its crate, store and Dex page) | `WeaponStats.set`, a `Shop.sets` key |
| Size | six rarities a class | one weapon a class, all of one rarity |
| Damage scale | its area's (`WeaponStats.areaScale`) | the first area's, 1 (`area = 1`, as the golden weapons) |
| Crates | its area's chest for its class | none: no crate, Endless prize, victory chest or free crate (`ShopRules.cratePool`) |
| Store | gems by rarity; a Legendary coins and boss items | its set's coins **and** gems (`ShopRules.price`); a Mythic or an earned one never |
| Waits on | its area's boss, once the launch locks are on | nothing (`ShopRules.buyable`) |
| For sale when | its area is `stocked` | its set is `stocked` (`ShopRules.stocked`) |
| Dex | its area's page | a page a set, after every area's (`DexBook`), once the set is stocked |
| Copies | crates give copies to merge | bought once, as an area's Legendary is |

- A set's rarity is the whole set's. A Legendary or Mythic set glows and each weapon carries a
  card its own class can draw (rule 12; `innate` and `effect` in `Config/WeaponStats`).
- **Robux:** nothing here is sold for Robux. Gems can be bought, and everywhere else gems buy
  nothing above Epic, so a Legendary set's price in coins and gems is the one place they do
  (owner's yes, 2026-11-18). A Mythic set would be earned, never sold (`docs/ROBUX-STORE.md`).
- Prices are starting numbers: 5,000 coins and 300 gems a weapon.

## Neon Circuit (Legendary) — in the game

Chunky toy electronics: matte graphite blocks, cyan and magenta light strips, grey ribbed
grips, a yellow block accent and a small green circuit chip. Front views by Codex
(2026-11-18; the second take bolder, the dagger and sword redrawn on the owner's word) in
`assets/concepts/blocky/weapons/skins/sets/neon_circuit/`, earlier takes in `options/`.
Prompts: `sets/set_prompts.py` (it says "toy prop", never "weapon": Codex's image filter
refused plain bow prompts that day).

| Weapon | Class | Looks like | Card |
|---|---|---|---|
| **Livewire Bow** | Ranger | zigzag lightning limbs, cyan above and magenta below, yellow plug tips, a cyan dial on the grip, a light-bar string | Split Shot |
| **Mainframe Staff** | Arcanist | a boxy retro monitor head, a cyan screen with a magenta pulse line, three yellow keys, cyan and magenta antennae, a yellow plug foot | Arcane Turret |
| **Overclock Blade** | Warden | a two-edged greatsword, cyan edges, a magenta centre strip and fan, a heat-sink guard with yellow capacitors, a battery pommel | Blade Storm |
| **Glitch Daggers** | Assassin | a slim blade cut in five equal slices, the 2nd and 4th slid sideways, cyan left edges and magenta right, a yellow cartridge guard | Execute |

- **Models:** Tripo, 4,000 triangles and an 8K texture each, 260 credits (4,720 left);
  jobs in `assets/models/weapons/blocky/neon_circuit_tripo_2026_11_18.json`. The dagger's
  right-hand strips came out blue and were repainted magenta from the export
  (`neon_circuit/fix_dagger_magenta.py`). Imported by the owner from
  `Downloads
eon_circuit_import`; ids in `neon_circuit/skin_imports.json`.
- **Held:** grips measured from the GLBs (`neon_circuit/measure_grips.py`): the bow's riser
  is on -X (yaw a quarter turn back), the staff 43% up, the blade's handle 21% and the
  dagger's 20% up. In Studio the bow's string side and hands matched the Golden Bow's.
- **Glow:** an `aura` and a shot or swing glow, cyan for the bow and blade, magenta for the
  staff and daggers; square cyan and magenta bolts and pixel-chip swings (`Config/WeaponFx`).
- **Shop:** the SETS tab at the Blacksmith, 5,000 coins and 300 gems each; pictures cut by
  `assets/ui/shop/set_icons.py` (the dagger pair crossed in a V). The Dex has a NEON
  CIRCUIT page after the areas' (`Config/Dex.areas.NeonCircuit`).
- **Not seen yet:** the SETS shelf, the Dex page and the glow on screen (Studio's 3D view was
  not drawing in that Play), and phone size. Each weapon uses its class's kit and sounds.

## Starwish (drawn, waiting on the owner)

Sweet toy wishing-star charms: pastel pink and mint blocks, cream white, gold star charms,
flat chunky ribbon wraps and glowing pale-yellow star gems (owner, 2026-11-18: "make the
next one"). Front views by Codex in `sets/starwish/`, all four on `contact_sheet.jpg`:
**Wishbright Bow**, **Dreamdrop Staff**, **Wishcutter Blade**, **Twinkle Daggers**. Its
rarity, its cards and its `Shop.sets` row wait on the owner's yes; nothing goes to Tripo
before it (260 credits for the four).

## The sets still to make

Drawn by Codex on 2026-11-18 (owner: "make the designs for all first"), each in
`sets/<set>/` with its `contact_sheet.jpg`; prompts in `sets/set_prompts.py`. Each is four
weapons, 260 Tripo credits and one Import Queue batch, and nothing goes to Tripo before the
owner's yes on its pictures. Names and looks are proposals until then.

| Set | Look | Bow, staff, blade, daggers |
|---|---|---|
| **Tumbleweed** | toy cowboy gear: tan leather, honey wood, brass rivets, thick rope, a tin star, a turquoise stone | Saddlehorn Bow (horn limbs), Wagonwheel Staff, Trailboss Blade (horseshoe guard), Spur Daggers (spur-rowel guard) |
| **Splash Day** | summer water toys: pool noodles, striped swim rings, water-blaster yellow and aqua, solid blue water | Noodle Bow, Splashring Staff, Breaker Blade (a surfboard blade), Squirt Daggers (a frozen water jet) |
| **Coin-Op** | toy arcade: glossy red and blue, big 8-bit pixels, arcade buttons, yellow game coins, pixel hearts | Highscore Bow, Joystick Staff, Pixel Blade, Token Daggers (a direction-pad guard) |
| **Voidglass** | toy space crystal: purple see-through glass with stars inside, silver trim, ringed black orbs | Orbit Bow, Starwell Staff, Nebula Blade, Comet Daggers |
| **Lantern Bloom** | spring festival: pale wood, red paper lanterns, pink blossoms, gold bells, red cord and tassels | Blossom Bow, Paperglow Staff, Petalfall Blade, Bellchime Daggers |
| **Cinderforge** | volcano forge: cracked black rock with lava seams, iron bands and rivets, molten cubes | Cinderstring Bow, Forgeheart Staff, Molten Blade (an anvil guard), Embershard Daggers |

Each prompt names what the set must not have (faces, skulls, characters and the like) so it
stays a toy of this game's own and never reads as another game's line.

Once several sets of different rarities exist, a themed crate becomes worth building (one
weapon a class leaves a single set nothing to roll). That is the owner's call when it comes.

## Adding a set

1. A row in `Config/Shop.sets` (key, name, coins, gems), left unstocked.
2. Its four pictures: a block in `sets/set_prompts.py`, run, `contact_sheet.py`, shown to the
   owner before Tripo.
3. Tripo (4,000 triangles, 8K, 65 credits each), the owner's import, then as Neon Circuit:
   grips (`neon_circuit/measure_grips.py`), a list in `skins_to_luau.py`, rows in
   `Config/WeaponStats` (`set`, `area = 1`), `Config/WeaponFx`, pictures
   (`assets/ui/shop/set_icons.py`) uploaded into `ShopAssets` and `GearAssets`, a page look
   in `Config/Dex.areas`, then `stocked = true`. `tests/WeaponSets.spec` holds a stocked set to one weapon for every
   open class, one rarity, a card each for a Legendary or Mythic, and a page look.
