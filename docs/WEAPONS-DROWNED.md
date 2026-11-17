# Weapons — Drowned Village (area 3)

The rarity ladder, read off Codex's reference sheets rather than inferred, and what is
imported so far. Sheets live in `assets/concepts/blocky/weapons/skins/drowned/`; each
`*_views.png` carries its tier in the title, and `contact_sheet.png` shows eleven of them
together.

**They reached `main` on 2026-11-02**, recovered from `phase-3/gear-and-shops` (commit
`bfe0227`), which never merged. That branch not merging is the whole reason all fourteen of
these weapons had no 2D art and no icon, which is what `docs/BALANCE-REPORT.md` S5 calls the
thing holding the area-3 tier back. Every one now has its shop picture in
`Config/ShopAssets`, cut by `assets/ui/shop/three_quarter.py` to the same angle as the other
eighteen. The mini pixel icons for the gear screen are still to come.

Same rules as the other areas (`WEAPONS-THORNWOOD.md`): one weapon per class at each of
Uncommon, Rare, Epic, Legendary and Mythic; Legendaries and Mythics glow, Mythics rainbow; the
area's Legendary costs coins plus the boss item.

## The ladder

| Tier | Bow (Ranger) | Staff (Arcanist) | Blade (Warden) |
|---|---|---|---|
| Uncommon | **— missing —** | Reed Staff | Tidewood Blade |
| Rare | Slatefin Bow | Buoy Staff | Tidehook Blade |
| Epic | Eelcrest Bow | Wellpearl Staff | Causeway Blade |
| Legendary | Tollstring Bow | Tollkeeper Staff | Tollguard Blade |
| Mythic | Eventide Bow | Maelstrom Staff | Stormglass Blade |

Fourteen designed against fifteen slots. **There is no Uncommon bow**, which is a real gap in
the set rather than a missing sheet — staffs and blades both have their full five.

The naming follows the area's cast: *eelcrest* to the Ditch Eel, *tollstring*, *tollkeeper* and
*tollguard* to the Old Tollcrab, *stormglass* and *maelstrom* to the weather.

## What is in Studio

Imported as single textured Tripo meshes (2026-10-30), one part each:

**Ready to wire (9)** — sheet and import both present: Slatefin, Eelcrest, Tollstring,
Reed, Tollkeeper, Wellpearl, Tidewood, Tidehook, Causeway.

**Sheeted, not yet imported (5)** — Buoy Staff, Eventide Bow, Maelstrom Staff,
Stormglass Blade, Tollguard Blade. Note four of these are the Legendary and Mythic tiers, so
the top of every class's ladder is still missing from Studio.

**Imported with no sheet (1)** — `sunken bell sword arena 3`. Nothing in the drowned sheets
matches that name. It may be Tollguard Blade under a working name, given both are bell-themed
and Tollguard is the one blade not imported; the owner should confirm before it is wired.

## Wiring them

The skins block in `Config/Weapons.luau` is generated — `assets/models/weapons/skins_to_luau.py`,
"regenerate, never hand-edit" — from a `skin_imports.json` dump plus the script's own `SKINS`
table. The dump for the first five is at
`assets/models/weapons/blocky/drowned/skin_imports.json`.

Two things block a clean run:

- **The generator cannot emit `textureId`.** It never writes that field. Every existing skin is
  vertex-coloured, with glow applied to parts named `Gems` or `Glow`. Tripo models carry their
  detail in a texture, and `WeaponPart` does support `textureId`, so the generator needs to
  learn it. Until then these come out grey.
- **Glow has nowhere to attach.** A single textured mesh has no `Gems` part, so the
  Legendary/Mythic glow rule and `rainbow = true` need a different hook for textured weapons —
  a whole-part glow, or a separate emissive mesh.

`rarity()` reads the tier from names like `bow_5mythic_glade_spirit_bow`; the Tripo imports are
named "eelcrest bow arena 3", so either they get renamed on import or the `SKINS` table carries
the tier explicitly. The table above is the source either way.

## Daggers (the Assassin), drawn 2026-11-16

The Drowned Village had no daggers (`WEAPONS-BOGHEART.md` says so); the owner, told so on
2026-11-16, said "Ok take care of this". Codex's front views, in
`assets/concepts/blocky/weapons/skins/drowned/`. Each picture is **one** dagger, not the pair: the game holds a copy in each hand (`Config/Weapons` `offhand`). Prompts: `assets/concepts/blocky/weapons/skins/dagger_prompts.py`; all eleven on one sheet: `daggers_contact_2026_11_16.jpg`. **Modelled in Tripo on 2026-11-16** (owner: "Yes, model them", then "8k textures"): HD model, 4,000 triangles, 8K texture, 65 credits each, 715 for the eleven. The jobs are in `assets/models/weapons/blocky/daggers_tripo_2026_11_16.json`; the GLBs are not in git, as no Tripo export is: `name_daggers_glb.py` names them for the Import Queue in `Downloads\assassin_daggers_import`, each one textured mesh with UVs. Shop and gear pictures (two copies crossed in a V): `assets/ui/shop/new_dagger_icons.py`. **Imported and wired 2026-11-17** (owner: "models are in"): mesh and texture ids in `assets/models/weapons/blocky/daggers/skin_imports.json`, grips measured from the GLBs (`measure_grips.py`), written into `Config/Weapons` by `skins_to_luau.py` (its `DAGGERS` list), each held in both hands; stats and effects in `Config/WeaponStats`, a cleave each in `Config/WeaponFx`, pictures uploaded (`Config/ShopAssets`, `Config/GearAssets`).

| Tier | Daggers | Picture |
|---|---|---|
| Uncommon | **Driftwood Dirks**: a chipped slate blade lashed with rope to a driftwood handle | `driftwood_dirks.png` |
| Rare | **Barnacle Knives**: a dark iron blade with a teal edge and three barnacles, rope grip, an iron ring pommel | `barnacle_knives.png` |
| Epic | **Eeltooth Daggers**: a curved eel-blue blade with a pale edge, a yellow fin guard | `eeltooth_daggers.png` |
| Legendary | **Tollbell Daggers**: a bronze bell-metal blade green with verdigris, a small bell for a pommel; glows teal | `tollbell_daggers.png` |
| Mythic | **Riptide Fangs**: a glowing sea-glass crystal blade rising out of a curling wave guard, a pearl pommel; glows teal and white | `riptide_fangs.png` |

Effects: the Tollbell Daggers carry Serrated Edge, the Riptide Fangs Bleed. Sold from the Drowned Village's DAGGER chest.
