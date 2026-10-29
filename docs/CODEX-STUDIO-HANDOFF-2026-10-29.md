# Claude Code handoff — 29 October 2026

## Read this before connecting Rojo

The user's approved Codex changes were made in **Archer Legends [TEST]**, place **76446189433435**. The Studio place is based on older game code than `C:/Dev/ArcheroRoblox` on `phase-3/endless-mode`. That repository already has newer pet ownership/equipping, save schema v6, class selection, pity and Endless systems. **Do not replace the repository with the full old Studio source snapshot. Do not roll SaveSchema back to v2.**

The Codex balance edits were three-way merged into the newer repository code. In particular, EnemyManager retains its Endless floor curve and fire-rate calculation; the new Mossy Glade room ramp applies only to the normal story difficulty path.

## Recovery files

- `Archer-Legends-TEST-2026-10-29.rbxl`: exact complete place downloaded from the live Edit datamodel, including imported models and assets. This is the full-place recovery point.
- `studio-sources.json`, `scripts/`, `manifest.json`: all 391 extracted scripts, original instance paths, classes and SHA-256 hashes.
- `HatcheryPetIcons.rbxm`: actual persistent pet preview models.
- `ReusableUITemplates.rbxm`: disabled copies of both approved UI scripts.
- `repo-before/`: the original repository files before the preservation patch.
- `repo-overlay/`: only the approved Codex changes merged onto the newer repository; not an old-source replacement.
- `source-differences.json`, `diffs/`: all other Studio/repository drift, archived for comparison. Most drift represents newer Claude features or mobile work; do not blindly apply it.
- `artifacts/`: design art, selected reward notes, UI templates, balance report and other prior outputs.

The original `.rbxl` is authoritative for full-place restoration. Its extraction used Lune, which warned about an unsupported Terrain metadata property; the original place file itself was not rewritten by Lune.

## Changes to preserve

### Hatchery and weapon chest UI

- Mossy Egg: eight pet cards, visible legendary models, mythic silhouette, rarity colors, white lower-right percentages.
- Existing pixel outline/arcade headings, approved panel art, smooth hover/press, proximity popup, diagonal card gleam behind pet models, animated rarity glow and mythic effects.
- Each pet card smoothly scales on hover/press. Clicking/tapping opens config-driven damage, attack timing and support descriptions. Mobile details fit independently of the hatchery scale.
- Blacksmith weapon chest: separate bows, wands/staves and swords; uses the existing 2D weapon art.
- Hatch/chest previews still use placeholder prices and odds. Do not interpret the UI's preview actions as completed server purchase transactions.
- Preserve the current text appearance as the approved snapshot; the standalone UI scripts predate repository strict/font/style cleanup. Do not silently change their visuals to make lint pass.

Exact runtime instance paths are kept by Rojo:

- `src/standalone/EggHatcheryUI.client.luau` -> `StarterPlayer.StarterPlayerScripts.EggHatcheryUI`
- `src/standalone/WeaponChestUI.client.luau` -> `StarterPlayer.StarterPlayerScripts.WeaponChestUI`
- `assets/studio-codex/HatcheryPetIcons.rbxm` -> `ReplicatedStorage.HatcheryPetIcons`
- `assets/studio-codex/ReusableUITemplates.rbxm` -> `ServerStorage.ReusableUITemplates`

The repository's newer Egg/Gear/Shop screens and backend must be integrated with the approved Codex presentation; avoid displaying two competing menus. This backup does not replace those newer systems or claim that integration has been playtested.

### Balance patch

- Extra Front Arrow, Double Shot, Twin Cast, Arcane Echo and diagonal projectiles: 40% damage. One primary projectile remains full damage.
- Multishot repeat volleys: 50%. Copy scales compound in combinations; dependent damage effects inherit the smaller projectile damage. Enemy default patterns are unchanged.
- Deadly Strike: three ranks, +2/+4/+6 additive critical multiplier (4x/6x/8x total with base 2x crit). Rare rarity unchanged.
- Slime Prince: 50 normal damage, plus 80 boss bonus, giving 130 against bosses.
- Glimmerhorn: 80 beam damage, 3 HP healed per enemy hit, once-per-run 50% HP revive.
- Second Wind wording corrected to 40% HP; actual revive strength unchanged.
- `Config/CombatTuning`: linear +2% of the level's base HP per combat encounter after the first, resetting each level. Angels/Valkyries do not advance it. Bosses and elites count. Sandbox and other areas are excluded.
- Existing between-level HP scaling remains. The old Studio final Slime King increases from 12,000 to 16,800 HP with this ramp.

Focused Studio checks passed before backup: projectile scale combinations, real 40-damage extra hit and 6.4/s burn, pet stats/descriptions, client prediction, room/wave spawn HP, reward skipping and sandbox exclusions. The 1,140-run audit workbook is a **pre-patch** baseline, not a post-patch survival validation.

### Designs and next task

Starforged (Orbit Manta + Astral Arc) is approved for Endless rewards; Riftforged and Lunar Veil are also approved. Aurora Sentinel requires three tails and matching bow fins, with the fox ears atop the front of the head. Preserve the reference sheets and selection notes.

**Gear selection UI, updated in the filesystem project:** gear selection inspired by `https://www.youtube.com/shorts/qSXmLNuy1WY` (Archero 2 gear teardown). Central character preview, rarity-bordered inventory, and exactly four equipment slots: **two pets, one weapon, one trail**. No invented armor, rings, runes, item levels or other absent features. The updated GearScreen keeps the existing character preview, server-owned equip controls and responsive landscape/portrait layout. It now has exactly four slots, larger four-column inventory cards, larger item art, Epic glow, a visible close control and clickable equipment-slot category shortcuts. Clicking a pet slot chooses the target slot; unequip stays in the item details panel. Trails remain locked because their gameplay is not implemented. StyLua, Selene, focused luau-lsp analysis and Rojo build passed. Runtime visual verification and syncing into the older open Studio place remain pending; do not claim the preview build is published or that a playtest passed.

## Continuing safely

1. Start in `C:/Dev/ArcheroRoblox`, read this handoff and the current repository rules.
2. Keep the dated source-preservation commit/branch when creating new feature branches; merge/cherry-pick it if starting from an older branch.
3. `default.project.json` changed to include the standalone UI and model snapshots. Restart `rojo serve` after this structural change, then reconnect Studio.
4. Keep ownership, transactions and damage server-authoritative. Preserve the newer save schema/migrations.
5. Run the usual lint/build/type gates and sync probe before trusting a playtest. Snapshot UI formatting/font compliance remains a follow-up, not an excuse to discard the approved UI.
6. Open the full `.rbxl` only to restore the old complete Studio snapshot. To continue the newer game, use the merged filesystem project instead.

No published Roblox release or GitHub push is implied by this local backup.
