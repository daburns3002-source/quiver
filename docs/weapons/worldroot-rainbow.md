# Worldroot Staff glow (Mythic)

The Worldroot Staff is the Arcanist's Mythic skin (`docs/PETS-FOREST.md`). Its crystal parts glow
one fluorescent colour, and in game that **one hue drifts slowly through the colour wheel**: every
glowing part shows the same colour at once, so the whole staff changes colour together. It never
shows several colours at the same time (the owner ruled out rainbow bands). The glow parts are
modelled in Claude Design; **the hue shift is done in code**, which is a later pass.

- Claude Design project: [Worldroot Staff](https://claude.ai/design/p/19d15d52-6166-450e-ae11-7e005f2c4287?file=Worldroot+Staff.html)
  (the bolt is its second page, `Worldroot Bolt.html`)
- Staff GLB: `wpn_worldroot_staff.glb` (owner's Downloads, replaces the PR #215 export)
- Bolt GLB: `wpn_worldroot_staff_bolt.glb` (owner's Downloads, replaces the PR #215 export)
- Sheet: `assets/concepts/blocky/weapons/skins/forest/worldroot_staff_views.png`

## What a GLB can and cannot carry

The GLBs hold each glowing part's shape and one flat colour with a matching emissive glow. They
cannot carry a colour that changes over time, and Roblox's importer drops materials anyway: the
pipeline reads each part's colour from the GLB (`tools/imports_to_luau.py`). So every glowing part
is its own mesh named `Glow_…`, and in game the code will:

1. find every descendant whose name starts with `Glow_`,
2. set it to `Enum.Material.Neon`,
3. give them all one shared colour, `Color3.fromHSV(hue(t), s, v)`, where `hue` starts at the
   starting colour below and drifts slowly, keeping that colour's saturation and value.

All parts take the same hue at the same moment. Keep each part's own transparency (the bolt's tail
fades); change only the colour. The Claude Design viewers' `HUE SHIFT` button previews it at
30°/s.

## Starting colour

Fluorescent cyan **`#22F4FF`** (hue ≈ 184°, saturation ≈ 0.87, value 1). It is the sheet's own
crystal colour, so at rest the staff matches its sheet.

Every glowing part below has the base colour `#22F4FF` and an emissive colour to match. The GLB
stores that colour as linear `(0.02, 0.90, 1.0)` with `KHR_materials_emissive_strength` 2.2.

## Staff: `wpn_worldroot_staff.glb`

2,622 triangles, 38 meshes, 9 of them glowing, all opaque.

| Part | Where |
|---|---|
| `Glow_Orb` | the crystal cube in the root cradle |
| `Glow_Halo` | the 12-sided ring round the orb, tilted back 30° so it opens into an ellipse from above |
| `Glow_Sat_Top` | cube riding the top of the halo |
| `Glow_Sat_Left` | cube riding the halo's left side (front view) |
| `Glow_Sat_Right` | cube riding the halo's right side (front view) |
| `Glow_Shard_1` | lowest crystal shard in the braided shaft |
| `Glow_Shard_2` | middle shaft shard |
| `Glow_Shard_3` | top shaft shard |
| `Glow_Foot` | crystal in the foot spike |

Unchanged and not glowing: `root_cradle_*` (5), `shaft_root_1`–`3`, `shaft_core`, `gold_band`,
`foot_spike`, `leaf_01`–`leaf_18`.

## Bolt: `wpn_worldroot_staff_bolt.glb`

224 triangles, 8 meshes, all glowing. It flies along −Z and shares the staff's single colour, so
staff and projectile glow as one set.

| Part | Where | Opacity |
|---|---|---|
| `Glow_Bolt` | the crystal cube | 1 |
| `Glow_Tail_1` | tail cube touching the bolt | 0.80 |
| `Glow_Tail_2` | | 0.72 |
| `Glow_Tail_3` | | 0.63 |
| `Glow_Tail_4` | | 0.55 |
| `Glow_Tail_5` | | 0.46 |
| `Glow_Tail_6` | | 0.38 |
| `Glow_Tail_7` | furthest back | 0.30 |

If the tail becomes a particle trail in game (see `docs/weapons/staffs.md`), delete the `Tail`
group and drive the particles' colour from the same shared hue.
