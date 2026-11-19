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
- **Rewards, not for sale** (owner, 2026-11-19): three set blades are earned (`earned`,
  `howEarned` on their Gear card), so the SETS shelf sells their sets' other three weapons.
  The **Nebula Blade** (Voidglass) is a Mythic, Endless room 100's; the **Petalfall Blade**
  (Lantern Bloom) is a Mythic, the season pass's premium tier 30 in Season 1; the
  **Wishcutter Blade** (Starwish) stays Legendary, the free tier 30 in Season 1. Only such an
  earned reward may stand above its set's rarity (`WeaponSets.spec`).
- **Robux:** nothing here is sold for Robux. Gems can be bought, and everywhere else gems buy
  nothing above Epic, so a Legendary set's price in coins and gems is the one place they do
  (owner's yes, 2026-11-18). A Mythic set would be earned, never sold (`docs/ROBUX-STORE.md`).
- Prices are starting numbers: 5,000 coins and 300 gems a weapon.
- **Two sets a week** (since 2026-11-18, [LIVE-EVENTS.md](LIVE-EVENTS.md)): the SETS tab sells
  only the week's two, by the server's clock (Monday 00:00 UTC), with a NEW SETS IN countdown; the
  others are off the shelf until their week comes back, and the server refuses them
  (`Util/SetRotation`). Owned weapons are kept.

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

## The seven other sets — in the game

Starwish (owner, 2026-11-18: "make the next one"), then Tumbleweed, Splash Day, Coin-Op,
Voidglass, Lantern Bloom and Cinderforge ("make the designs for all first"; the Molten Blade
redrawn broader). Pictures by Codex in `sets/<set>/` (each with its `contact_sheet.jpg`,
prompts in `sets/set_prompts.py`); 28 Tripo models, 4,000 triangles and 8K each (1,820
credits, 2,900 left; jobs in `assets/models/weapons/blocky/{starwish,themed_sets,cinderforge}_tripo_2026_11_18.json`),
every one rendered from four sides first. The Starwell Staff came with a loose moon floating
behind its head, cut out by `blocky/themed_sets/drop_loose_parts.py`.

All Legendary, 5,000 coins and 300 gems each on the SETS tab, a Dex page a set. Everything a
set weapon is lives in one table, `assets/models/weapons/blocky/themed_sets/sets.py` (ids,
card, effect line, glow, look), which writes the marked blocks in `Config/WeaponStats`,
`WeaponFx`, `Dex` and `Shop`; `skins_to_luau.py` reads it for `Config/Weapons`. Grips are
measured by `blocky/themed_sets/measure_grips.py`: every bow's riser is on -X; the Splashring
and Paperglow Staffs are held lower, on their own grips under the tank and the lantern. A set's
Dex page pays `Rewards.setPage` (crates, no gems), so the gems every page pays stay under the cap.

| Set | Look | Weapons (card) |
|---|---|---|
| **Starwish** | toy wishing-star charms: pastel pink and mint, cream white, gold stars, flat ribbon wraps, glowing star gems | Wishbright Bow (Blast Arrows), Dreamdrop Staff (Elemental Orbs), Wishcutter Blade (Whirlwind), Twinkle Daggers (*Wishing Star*) |
| **Tumbleweed** | toy cowboy gear: tan leather, honey wood, brass rivets, thick rope, a tin star, a turquoise stone | Saddlehorn Bow (Ricochet), Wagonwheel Staff (Chain Lightning), Trailboss Blade (Battle Cry), Spur Daggers (*Spur Rowel*) |
| **Splash Day** | summer water toys: pool noodles, striped swim rings, water-blaster yellow and aqua, solid blue water | Noodle Bow (Piercing Shot), Splashring Staff (Spell Pierce), Breaker Blade (Shockwave), Squirt Daggers (*Splash Wave*) |
| **Coin-Op** | toy arcade: glossy red and blue, big 8-bit pixels, arcade buttons, yellow game coins, pixel hearts | Highscore Bow (Front Arrow), Joystick Staff (Twin Cast), Pixel Blade (Counter Strike), Token Daggers (*Combo Counter*) |
| **Voidglass** | toy space crystal: purple see-through glass with stars inside, silver trim, ringed black orbs | Orbit Bow (Rain Of Arrows), Starwell Staff (Tracking Eye), Nebula Blade (Parry), Comet Daggers (*Comet Crash*) |
| **Lantern Bloom** | spring festival: pale wood, red paper lanterns, pink blossoms, gold bells, red cord and tassels | Blossom Bow (Multishot), Paperglow Staff (Arcane Turret), Petalfall Blade (Sunder), Bellchime Daggers (*Bell Chime*) |
| **Cinderforge** | volcano forge: cracked black rock with lava seams, iron bands and rivets, molten cubes | Cinderstring Bow (Sniper Shot), Forgeheart Staff (Mana Surge), Molten Blade (Heavy Blade), Embershard Daggers (*Lava Burst*) |

Cards: a set bow, staff or blade carries a card its class draws and that is not benched
(Momentum, Bloodletting and Overdraw were, and were swapped out). **The seven daggers carry
effects of their own** (in italics above; owner, 2026-11-18, "make unique effects for the
daggers now", then yes to the seven put to them): cards only that dagger carries
(`weaponOnly`), never dealt by a draft or an Angel. What each does, its numbers and its look are
in [CLASS-CARDS.md](CLASS-CARDS.md), "The themed daggers' seven". Neon Circuit's Glitch Daggers
keep Execute.

**Not seen yet:** the sets' shelves, Dex pages and glows on screen, and phone size. The hold
was checked by numbers in Studio against the Golden Bow.

Each prompt names what the set must not have (faces, skulls, characters and the like) so it
stays a toy of this game's own and never reads as another game's line. Once sets of
different rarities exist, a themed crate becomes worth building; that is the owner's call.

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
