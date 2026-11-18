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

## Neon Circuit (Legendary) — drawn, not modelled

Chunky toy electronics: matte graphite blocks, cyan and magenta light strips, grey ribbed
grips, a yellow block accent and a small green circuit chip. Front views by Codex
(2026-11-18), in `assets/concepts/blocky/weapons/skins/sets/neon_circuit/`; all four on
`contact_sheet.jpg`. Prompts: `sets/set_prompts.py` (it says "toy prop", never "weapon":
Codex's image filter refused plain bow prompts that day).

| Weapon | Class | Looks like | Card planned |
|---|---|---|---|
| **Livewire Bow** | Ranger | graphite limbs, a cyan strip above and a magenta strip below, yellow tip caps, a thick bar of white-cyan light for a string | Split Shot |
| **Mainframe Staff** | Arcanist | a square shaft with a magenta strip, a monitor-bezel frame holding a floating cyan cube, a cyan and a magenta prong | Arcane Turret |
| **Overclock Blade** | Warden | a broad graphite blade with stepped cyan edges and a magenta groove, a heat-sink guard, a yellow battery pommel with three charge bars | Blade Storm |
| **Glitch Daggers** | Assassin | a short graphite blade whose top steps sideways as if glitched, the top block magenta | Execute |

No weapon carries any of those four cards today, and no other dagger carries Execute
(`tests/WeaponFx.spec`: no two of the Assassin's weapons share an effect).

**Status:** the rules and the set's row are in (`stocked` off, so nothing shows in the game).
Waiting on the owner's look at the four pictures before any Tripo credits are spent.

### Still to do for the set

1. Owner approves the pictures (or says what to redraw).
2. Tripo, image to 3D: Polycount 4,000, 8K texture, 65 credits each, 260 for the four (4,980
   web credits were left on 2026-11-18). GLBs named for the Import Queue; the owner imports.
3. Grips and bow yaw measured per import (`skins_to_luau.py` `GRIPS`, `YAW`), a list for the
   sets in the generator, each with a cyan-and-magenta `aura`; rows in `Config/Sandbox`,
   `Config/WeaponStats` (`set = "NeonCircuit"`, `area = 1`), `Config/WeaponFx`.
4. Shop and gear pictures cut from the front views (two daggers crossed in a V), uploaded,
   ids in `Config/ShopAssets` and `Config/GearAssets`.
5. The SETS shelf at the Blacksmith (`UI/ShopScreen`) and the set's page look in
   `Config/Dex.areas`; `stocked = true`; a Studio check of each weapon in hand.

No new sounds or animations: each weapon uses its class's kit and sounds.

## The sets still to make

Each is four weapons, 260 Tripo credits and one Import Queue batch. Names and looks are
proposals until the owner picks one.

| Set | Look |
|---|---|
| **Starwish** | pastel pink and mint, gold star charms, ribbon wraps, a glowing star gem |
| **Tumbleweed** | worn leather, brass rivets, rope wraps, a tin star |
| **Splash Day** | pool-noodle limbs, inflatable rings, water-blaster yellow and aqua |
| **Coin-Op** | chunky pixels, a joystick grip, 8-bit hearts and coins |
| **Voidglass** | dark purple glass with stars swirling inside, a ringed black orb |
| **Lantern Bloom** | pale wood, paper lanterns, pink blossoms, small bells |
| **Cinderforge** | cracked black rock with lava glowing through the seams |

Once several sets of different rarities exist, a themed crate becomes worth building (one
weapon a class leaves a single set nothing to roll). That is the owner's call when it comes.

## Adding a set

1. A row in `Config/Shop.sets` (key, name, coins, gems), left unstocked.
2. Its four pictures: a block in `sets/set_prompts.py`, run, `contact_sheet.py`, shown to the
   owner before Tripo.
3. Steps 2 to 5 above. `tests/WeaponSets.spec` holds a stocked set to one weapon for every
   open class, one rarity, a card each for a Legendary or Mythic, and a page look.
