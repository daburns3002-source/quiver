# Weapons — Drowned Village (area 3)

The rarity ladder, read off Codex's reference sheets rather than inferred, and what is
imported so far. Sheets live in `assets/concepts/blocky/weapons/skins/drowned/` on
`phase-3/gear-and-shops` (commit `bfe0227`); each `*_views.png` carries its tier in the title,
and `contact_sheet.png` shows eleven of them together.

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
