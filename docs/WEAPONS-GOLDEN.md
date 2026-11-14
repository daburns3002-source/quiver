# Weapons — the golden weapons (class level 10)

**Approved by the owner 2026-11-14**, picture by picture: the Golden Bow (redone once: "make
the bow strong thicker", its string now a thick gold bar), the Golden Staff, the Golden Blade (redone once: "make the handle a
little smaller and the blade a little longer"). Pictures and prompts in
`assets/concepts/blocky/weapons/skins/golden/` (earlier takes in `options/`).

**Not in the game yet:** the stats, pictures and rules are (class levels shipped first, owner
2026-11-14: "Ship levels first"); the models wait on the owner's import (step 5 below), and
their `Config/Weapons` entries, grips and `Config/WeaponFx` looks are on branch
`phase-4/golden-weapons`. Until then a level 10 holds its weapon owed.

A class's own lasting level (`Config/ClassLevels`, CLAUDE.md "Class levels and the golden
weapons") reaches 10 and gives that class its golden weapon. The owner's calls: Legendary
strength, a gold glow, earned only (never sold, never rolled from a crate), each with the one
Legendary card of its class that no other weapon carries.

| Weapon | Class | Looks like | Built-in card | Shot or cleave (`Config/WeaponFx`, with the models) |
|---|---|---|---|---|
| **Golden Bow** | Ranger | gold block limbs, a carved leaf at each tip, brown grip, a square emerald, a thick straight gold string | Multishot 1: a second arrow follows every shot | a spinning gold wedge with pale fins, green sparkles, a long pale-gold tail |
| **Golden Staff** | Arcanist | a gold shaft banded by rings, brown grip, a three-pronged crown holding a square sapphire | Homing Orbs: every orb curves to the nearest enemy | a tumbling gold block ringed by three blue blades, blue sparkles |
| **Golden Blade** | Warden | a broad gold greatsword with a pale edge and a groove, a winged guard with a ruby, a short brown hilt | Battle Cry 1: each kill quickens the swings | a wide gold-to-cream streak throwing red stars upward |

Stats: `Config/WeaponStats` (`rarity = "Legendary"`, `area = 1`, `earned = true`). `earned`
keeps them out of every crate, the store, Endless prizes and the area Dex pages. There is only
ever one copy of each, so **they have no merge tier** (owner, 2026-11-14: "for weapons with no
duplicates such as these and the weapons that you get for endless, there should not be a merge
tier"; `ShopRules.merges`): no tier badge or copy count on the tile, no TIER or copies line and
no MERGE on the Gear card, and no tier in the damage. `tests/ClassLevels.spec` holds all of it.

## How they were made

1. Codex drew one flat front view each (rule 9), with an approved Bogheart Legendary of the
   same kind as the style reference (`run.sh`). That picture is also the weapon's 2D icon
   (rule 14): `python assets/ui/shop/golden_icons.py` cuts `assets/ui/shop/icons/Golden*.png`,
   uploaded, ids in `Config/ShopAssets`.
2. Tripo's web studio, image to 3D, Polycount 2,000, texture 2K: 45 credits each, 135 for the
   three. Exported as GLB. The staff and blade stand as made.
3. **The bow was made three times.** From the first picture's thin string Tripo drew a ragged
   web off the top limb, twice (the retry was free; owner: "the string on the tripo model is
   trash"). The picture was redrawn with a thick gold bar for a string and the bow generated
   again at Polycount 4,000 (45 credits): its string came out straight and whole. Its texture
   was then made again at 8K (Tripo's Texture tool on the same model, 30 credits; owner: "8k
   texture"), which painted colours the picture never had (a teal strip inside the lower limb,
   a green smear by the gem, brown patches behind the string; owner: "there are random colors
   on it, these need to be fixed"). `python -I .../golden/clean_bow_texture.py <in> <out>`
   repaints every texel that should be gold and is not, and flattens the string to one gold;
   the mesh is untouched. 210 credits in all.
4. `python -I assets/models/weapons/blocky/golden/name_glb.py <exports> <out>` names each
   GLB's scene, root node and mesh for the Import Queue.
5. The owner imports the three GLBs in Studio; their mesh and texture ids are dumped to
   `assets/models/weapons/blocky/golden/skin_imports.json` and `skins_to_luau.py` (its `GOLDEN`
   list) writes them into `Config/Weapons` and the sandbox menu, each with a gold `aura`,
   `shotGlow` or `trailGlow` (rule 12). Grips and the bow's yaw are measured into `GRIPS` /
   `YAW` like every Tripo weapon.
