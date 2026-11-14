# Weapons — the golden weapons (class level 10)

**Approved by the owner 2026-11-14**, picture by picture: the Golden Bow (redone once: "make
the bow string thicker"), the Golden Staff, the Golden Blade (redone once: "make the handle a
little smaller and the blade a little longer"). Pictures and prompts in
`assets/concepts/blocky/weapons/skins/golden/` (earlier takes in `options/`).

A class's own lasting level (`Config/ClassLevels`, CLAUDE.md "Class levels and the golden
weapons") reaches 10 and gives that class its golden weapon. The owner's calls: Legendary
strength, a gold glow, earned only (never sold, never rolled from a crate), each with the one
Legendary card of its class that no other weapon carries.

| Weapon | Class | Looks like | Built-in card | Shot or cleave (`Config/WeaponFx`) |
|---|---|---|---|---|
| **Golden Bow** | Ranger | gold block limbs, a carved leaf at each tip, brown grip, a square emerald, a thick straight gold string | Multishot 1: a second arrow follows every shot | a spinning gold wedge with pale fins, green sparkles, a long pale-gold tail |
| **Golden Staff** | Arcanist | a gold shaft banded by rings, brown grip, a three-pronged crown holding a square sapphire | Homing Orbs: every orb curves to the nearest enemy | a tumbling gold block ringed by three blue blades, blue sparkles |
| **Golden Blade** | Warden | a broad gold greatsword with a pale edge and a groove, a winged guard with a ruby, a short brown hilt | Battle Cry 1: each kill quickens the swings | a wide gold-to-cream streak throwing red stars upward |

Stats: `Config/WeaponStats` (`rarity = "Legendary"`, `area = 1`, `earned = true`). `earned`
keeps them out of every crate, the store, Endless prizes and the area Dex pages, and off MERGE
(there is only ever one copy); `tests/ClassLevels.spec` holds that.

## How they were made

1. Codex drew one flat front view each (rule 9), with an approved Bogheart Legendary of the
   same kind as the style reference (`run.sh`). That picture is also the weapon's 2D icon
   (rule 14): `python assets/ui/shop/golden_icons.py` cuts `assets/ui/shop/icons/Golden*.png`,
   uploaded, ids in `Config/ShopAssets`.
2. Tripo's web studio, image to 3D, Polycount 2,000, texture 2K: 45 credits each, 135 in all
   (the bow's retry was free). Exported as GLB.
3. `python -I assets/models/weapons/blocky/golden/fix_glb.py <exports> <out>` names each GLB's
   scene and root node for the Import Queue and **rebuilds the bow's string**: Tripo drew it as
   a ragged web off the top limb twice (owner: "the string on the tripo model is trash"), so
   its triangles are taken out and a straight square gold bar is put in from tip to tip,
   coloured by one texel of the limbs' own gold.
4. The owner imports the three GLBs in Studio; their mesh and texture ids are dumped to
   `assets/models/weapons/blocky/golden/skin_imports.json` and `skins_to_luau.py` (its `GOLDEN`
   list) writes them into `Config/Weapons` and the sandbox menu, each with a gold `aura`,
   `shotGlow` or `trailGlow` (rule 12). Grips and the bow's yaw are measured into `GRIPS` /
   `YAW` like every Tripo weapon.
