# Worldroot Staff rainbow (Mythic)

The Worldroot Staff is the Arcanist's Mythic skin (`docs/PETS-FOREST.md`). Its glowing parts carry
a stepped rainbow so it reads as the best staff in the game from the top-down camera. The rainbow
is modelled in Claude Design; **the moving colour is done in code**, which is a later pass.

- Claude Design project: [Worldroot Staff](https://claude.ai/design/p/19d15d52-6166-450e-ae11-7e005f2c4287?file=Worldroot+Staff.html)
  (the bolt is its second page, `Worldroot Bolt.html`)
- Staff GLB: `wpn_worldroot_staff.glb` (owner's Downloads, replaces the PR #215 export)
- Bolt GLB: `wpn_worldroot_staff_bolt.glb` (owner's Downloads, replaces the PR #215 export)
- Sheet: `assets/concepts/blocky/weapons/skins/forest/worldroot_staff_views.png`

## What a GLB can and cannot carry

The GLBs hold each glowing part's shape and one flat base colour with a matching emissive glow.
They cannot carry a colour that moves, and Roblox's importer drops materials anyway: the pipeline
reads each part's colour from the GLB (`tools/imports_to_luau.py`). So every glowing part is its
own mesh with one solid colour and a `Rainbow_` name, and in game the code will:

1. find every descendant whose name starts with `Rainbow_`,
2. set it to `Enum.Material.Neon`,
3. each frame set its hue to `(baseHue − speed · t) mod 360`, keeping saturation and value.

Because the base hues step along each chase below, subtracting time makes each colour **travel
along the chase** (up the staff, round the halo, back along the tail) instead of every part flashing
together. A speed of about 120°/s is what the Claude Design viewer's `HUE CYCLE` preview uses.

Everything else (roots, shaft core, gold band, foot spike, leaves) is unchanged from PR #215 and
does not glow.

## Palette

| Hue | Hex | | Hue | Hex |
|---|---|---|---|---|
| 0 | `#FF2B2B` | | 180 | `#2BF2FF` |
| 30 | `#FF8F2B` | | 210 | `#2B9CFF` |
| 60 | `#FFF22B` | | 240 | `#3B5BFF` |
| 90 | `#95FF2B` | | 270 | `#9A2BFF` |
| 120 | `#2BFF4A` | | 300 | `#FF2BE0` |
| 150 | `#2BFFA6` | | 330 | `#FF2B85` |

Each part's base colour is in the GLB, so the code can take its base hue straight from the imported
part (`Color3:ToHSV`) and needs no copy of this table.

## Staff: `wpn_worldroot_staff.glb`

2,644 triangles, 54 meshes, 25 of them glowing. All glowing parts are opaque.

**Spine chase**, from the foot up into the orb. Hue steps 60° per part, so with `baseHue − speed · t`
the colours climb the staff and roll through the orb.

| Order | Part | Base hue | Base colour | Where |
|---|---|---|---|---|
| 1 | `Rainbow_Foot` | 120 | `#2BFF4A` green | crystal in the foot spike |
| 2 | `Rainbow_Shard_1` | 180 | `#2BF2FF` cyan | lowest shaft shard |
| 3 | `Rainbow_Shard_2` | 240 | `#3B5BFF` blue | middle shaft shard |
| 4 | `Rainbow_Shard_3` | 300 | `#FF2BE0` magenta | top shaft shard |
| 5 | `Rainbow_Orb_1` | 0 | `#FF2B2B` red | orb slice at its bottom-front-left corner |
| 6 | `Rainbow_Orb_2` | 60 | `#FFF22B` yellow | orb slice |
| 7 | `Rainbow_Orb_3` | 120 | `#2BFF4A` green | orb slice |
| 8 | `Rainbow_Orb_4` | 180 | `#2BF2FF` cyan | orb slice |
| 9 | `Rainbow_Orb_5` | 240 | `#3B5BFF` blue | orb slice |
| 10 | `Rainbow_Orb_6` | 300 | `#FF2BE0` magenta | orb slice at its top-back-right corner |

The orb is the sheet's crystal cube cut into six slices across its body diagonal, so every face shows
diagonal stripes and the rainbow reads from the top-down camera as well as from the front. (Sliced
horizontally, the camera saw only the top slab.)

**Halo chase**, round the ring. Twelve straight segments of a 12-sided ring, tilted back 30° so it
opens into an ellipse from above. Numbered from the top, clockwise as seen from the front; hue steps
30° per segment, so one full rainbow runs round the ring and turns as it cycles.

| Order | Part | Base hue | Base colour |
|---|---|---|---|
| 1 | `Rainbow_Halo_01` (top) | 0 | `#FF2B2B` |
| 2 | `Rainbow_Halo_02` | 30 | `#FF8F2B` |
| 3 | `Rainbow_Halo_03` | 60 | `#FFF22B` |
| 4 | `Rainbow_Halo_04` | 90 | `#95FF2B` |
| 5 | `Rainbow_Halo_05` | 120 | `#2BFF4A` |
| 6 | `Rainbow_Halo_06` | 150 | `#2BFFA6` |
| 7 | `Rainbow_Halo_07` (bottom) | 180 | `#2BF2FF` |
| 8 | `Rainbow_Halo_08` | 210 | `#2B9CFF` |
| 9 | `Rainbow_Halo_09` | 240 | `#3B5BFF` |
| 10 | `Rainbow_Halo_10` | 270 | `#9A2BFF` |
| 11 | `Rainbow_Halo_11` | 300 | `#FF2BE0` |
| 12 | `Rainbow_Halo_12` | 330 | `#FF2B85` |

**Satellites**, the three cubes riding the halo. Not a chase: they sit 120° apart and stay 120° apart
as they cycle, keeping the sheet's cyan, yellow and magenta at rest.

| Part | Base hue | Base colour | Where (front view) |
|---|---|---|---|
| `Rainbow_Sat_Top` | 180 | `#2BF2FF` cyan | top of the halo |
| `Rainbow_Sat_Left` | 60 | `#FFF22B` yellow | left |
| `Rainbow_Sat_Right` | 300 | `#FF2BE0` magenta | right |

Unchanged and not glowing: `root_cradle_*` (5), `shaft_root_1`–`3`, `shaft_core`, `gold_band`,
`foot_spike`, `leaf_01`–`leaf_18`.

## Bolt: `wpn_worldroot_staff_bolt.glb`

246 triangles, 13 meshes, all glowing. Flies along −Z. The bolt is a small copy of the staff's orb,
so staff and projectile read as one set.

**Bolt and tail chase**, from the cube back along the tail. Hue steps 60° per part, so colours
stream out of the bolt and back down the tail.

| Order | Part | Base hue | Base colour | Opacity |
|---|---|---|---|---|
| 1 | `Rainbow_Bolt_1` | 0 | `#FF2B2B` red | 1 (bottom-leading corner) |
| 2 | `Rainbow_Bolt_2` | 60 | `#FFF22B` yellow | 1 |
| 3 | `Rainbow_Bolt_3` | 120 | `#2BFF4A` green | 1 |
| 4 | `Rainbow_Bolt_4` | 180 | `#2BF2FF` cyan | 1 |
| 5 | `Rainbow_Bolt_5` | 240 | `#3B5BFF` blue | 1 |
| 6 | `Rainbow_Bolt_6` | 300 | `#FF2BE0` magenta | 1 (top-trailing corner) |
| 7 | `Rainbow_Tail_1` | 0 | `#FF2B2B` | 0.80 (touching the cube) |
| 8 | `Rainbow_Tail_2` | 60 | `#FFF22B` | 0.72 |
| 9 | `Rainbow_Tail_3` | 120 | `#2BFF4A` | 0.63 |
| 10 | `Rainbow_Tail_4` | 180 | `#2BF2FF` | 0.55 |
| 11 | `Rainbow_Tail_5` | 240 | `#3B5BFF` | 0.46 |
| 12 | `Rainbow_Tail_6` | 300 | `#FF2BE0` | 0.38 |
| 13 | `Rainbow_Tail_7` | 0 | `#FF2B2B` | 0.30 (furthest back) |

The tail cubes keep their fading opacity; the code should keep each part's transparency and change
only its hue. If the tail becomes a particle trail in game (see `docs/weapons/staffs.md`), delete
the `Tail` group and give the particles the same hue cycle.

## Previewing it

Both Claude Design pages have a `HUE CYCLE` button (hue = base − 120°/s, every `Rainbow_` part)
and a `GAME` camera, 50° above horizontal. Neither is in the GLBs.
