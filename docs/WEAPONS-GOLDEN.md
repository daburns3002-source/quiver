# Weapons — the golden weapons (class level 10)

**Approved by the owner 2026-11-14**, picture by picture: the Golden Bow (redone once: "make
the bow strong thicker", its string now a thick gold bar), the Golden Staff, the Golden Blade (redone once: "make the handle a
little smaller and the blade a little longer"). Pictures and prompts in
`assets/concepts/blocky/weapons/skins/golden/` (earlier takes in `options/`).

**In the game since 2026-11-14.** Class levels shipped first (owner: "Ship levels first");
the owner then imported the three models and they were wired the same day. Seen in Studio
Play: each in hand against its picture (the bow's hand on its brown grip, limbs forward, the
gold bar string behind; the staff held on its wrap, crown and sapphire up; the blade held on
its handle between pommel and guard), each with its gold light and motes; a run with the level
numbers lowered in Studio only took the Ranger to level 10, gave the Golden Bow with its card,
put it on, and the next run held it and fired gold glowing shots with pale fins; Gear's card
for it reads DAMAGE x1.75 with no tier, copies or MERGE. Not seen: the staff's orbs and the
blade's cleave in a fight, and any of it on a phone.

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
5. The owner imported the three GLBs in Studio (2026-11-14, as `gold_golden_bow_8k_clean`,
   `gold_golden_staff`, `gold_golden_blade`; moved to `ServerStorage.Imports` once read). Their
   mesh and texture ids are in `assets/models/weapons/blocky/golden/skin_imports.json` and
   `skins_to_luau.py` (its `GOLDEN` list) writes them into `Config/Weapons` and the sandbox
   menu, each with a gold `aura`, `shotGlow` or `trailGlow` (rule 12). Grips, measured from the
   GLBs: the bow's riser is on +X (yaw a quarter turn), gripped at its middle; the staff 43% up,
   on its wrap; the blade 17.5% up, its handle running from 10% to 25% under the guard.

## Golden Daggers (the Assassin), drawn 2026-11-16

The Assassin's class level 10 gives no weapon yet (`Config/ClassLevels.waiting`). Codex's front
view, after the Golden Blade: `assets/concepts/blocky/weapons/skins/golden/golden_daggers.png`, a
gold dagger with a white-gold edge, a winged guard with a square ruby, a leather hilt and a gold
block pommel. Each picture is **one** dagger, not the pair: the game holds a copy in each hand (`Config/Weapons` `offhand`). Prompts: `assets/concepts/blocky/weapons/skins/dagger_prompts.py`; all eleven on one sheet: `daggers_contact_2026_11_16.jpg`. **Modelled in Tripo on 2026-11-16** (owner: "Yes, model them", then "8k textures"): HD model, 4,000 triangles, 8K texture, 65 credits each, 715 for the eleven. The jobs are in `assets/models/weapons/blocky/daggers_tripo_2026_11_16.json`; the GLBs are not in git, as no Tripo export is: `name_daggers_glb.py` names them for the Import Queue in `Downloads\assassin_daggers_import`, each one textured mesh with UVs. Shop and gear pictures (two copies crossed in a V): `assets/ui/shop/new_dagger_icons.py`. **Not imported, so not wired.** Once modelled and imported it joins `skins_to_luau.py`'s `GOLDEN` list and
`ClassLevels.weapons`, and the Assassin leaves `waiting`.
