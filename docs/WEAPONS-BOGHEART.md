# Weapons — Bogheart Caverns (area 4)

**Approved by the owner 2026-11-06; pictures in `assets/concepts/blocky/weapons/skins/bogheart/` (Mythic options picked: A, daggers B).** Drafted
2026-11-06 alongside `PETS-BOGHEART.md`. Same rules as the other areas
(`WEAPONS-DROWNED.md`, `WEAPONS-THORNWOOD.md`): one weapon per class at Uncommon, Rare, Epic,
Legendary and Mythic; Legendaries and Mythics glow (Mythics no longer need rainbow); the Legendary costs coins
plus the boss item. This ladder also fills the Assassin's daggers, which Drowned Village lacks.
Once approved, each goes through the Tripo route (Codex 2D weapon art first, which also serves
as the weapon picture — memory `weapon-pictures-are-2d`).

Names follow the area's cast: Spore Puff, Glowcap, Shellback, Grandmother Gulp, the poison vents
and the underground lake.

| Tier | Bow (Ranger) | Staff (Arcanist) | Blade (Warden) | Daggers (Assassin) |
|---|---|---|---|---|
| Uncommon | **Peatwood Bow** — dark bog-oak limbs, lichen wraps | **Lichen Staff** — knotted root with a lime lichen head | **Bogiron Blade** — rust-dark iron with moss on the guard | **Moss Shivs** — two short stone knives with moss grips |
| Rare | **Sporestring Bow** — a pink spore-puff grip, one glowing pink knot | **Puffball Staff** — a pink spore puff caged on top, glowing | **Shellback Cleaver** — a broad teal shell-plate blade | **Spore Fangs** — curved pink-tipped fangs, one glowing spot each |
| Epic | **Glowcap Longbow** — teal cap limbs, glowing gill-string | **Ventstone Staff** — a vent rock leaking glowing green smoke | **Caplight Blade** — teal blade with a glowing mushroom-cap guard | **Glowcap Kris** — wavy teal blades with glowing gill edges |
| Legendary | **Gulpstring Bow** — purple toad-skin limbs, gold spectacle rings at the tips | **Grandmother's Staff** — a gold-ringed toad-wood staff topped with a glowing cyan mushroom cluster | **Gulpfang Blade** — purple-and-lime blade, gold spectacle guard | **Toadtongue Daggers** — pink tongue-curl blades with gold rings |
| Mythic | **Lumenveil Bow** — limbs of layered lake-crystal wings, glowing cyan orb grip, string of light | **Myceliad Staff** — twisting pale roots opening into a crown of glowing teal mushrooms round a caged crystal core | **Deepglow Blade** — a glowing lake-crystal greatsword with a gold-and-stone winged guard | **Prism Stingers** — forked glowing cyan crystal fang daggers with gold claw guards |

## Status

**Wired 2026-11-06** (bows, staffs, blades): the low-poly Tripo meshes from
`Workspace/TripoImports/Weapons` in `assets/models/weapons/blocky/bogheart/skin_imports.json`,
generated into `Config/Weapons` by `skins_to_luau.py` (colour map as `textureId`), stats in
`Config/WeaponStats` (area 4; Legendary and Mythic effects: Piercing Shot, Rain of Arrows,
Arcane Echo, Black Hole, Counter Strike, Earthbreaker), pictures in `Config/ShopAssets` cut
from the 2D art by `assets/ui/shop/bogheart_icons.py`. A Legendary's or Mythic's glow is an
`aura` (light and motes round the textured mesh, `Combat/HeldWeapon`); none is rainbow. Not
stocked: the area has no portal or `Config/Economy` entry yet.

**Not wired:** the five daggers (Moss Shivs, Spore Fangs, Glowcap Kris, Toadtongue Daggers,
Prism Stingers). The Assassin exists now (2026-11-16), but **each was modelled as the pair in one
mesh** (`Workspace/TripoImports/Weapons`, 0.63 to 0.79 wide by 0.98 tall), and the game holds one
dagger in each hand (`Config/Weapons` `offhand`), so a pair mesh cannot be held. The low-poly files
are only in Studio; the repo's checkout has the 1.9 million triangle originals
(`assets/concepts/blocky/weapons/skins/bogheart/*.glb`, untracked). **Remade as single daggers in Tripo on 2026-11-16** (owner: "Yes, remake them"; 4,000
triangles, 8K texture, 65 credits each): each from the left dagger of its own picture, cut out
(`assets/concepts/blocky/weapons/skins/bogheart/<name>_single.png`, `single_dagger_prompts.py`),
so the design is unchanged. Jobs in `assets/models/weapons/blocky/daggers_tripo_2026_11_16.json`
(`remake`); shop and gear pictures by `assets/ui/shop/new_dagger_icons.py`. **Imported and wired
2026-11-17**, as the other areas' daggers are (`assets/models/weapons/blocky/daggers`): the Toadtongue
Daggers carry Backstab, the Prism Stingers Phantom Blades, sold from Bogheart's DAGGER chest. The old
pair imports are still in `Workspace/TripoImports/Weapons`; nothing reads them and they can be deleted.
