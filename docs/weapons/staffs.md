# Staff skins (Mossy Glade)

Four Arcanist staff skins and their bolts, modelled in Claude Design from their reference sheets in
`assets/concepts/blocky/weapons/skins/forest/`. The GLBs are in the owner's Downloads folder
awaiting a Studio import. Wiring them into `Config/Weapons` is a later pass.

All four share the Toadstool Staff's frame: Y-up, staff along Y, 1.40 tall from the top of the head
to the foot tip, origin halfway down the shaft (the grip), the head's face toward the front camera.
Materials are flat colours with emissive glows, with no textures and no clips. Each staff's
Claude Design project also holds its bolt, as a second page.

| Weapon | Rarity | Claude Design project | Staff GLB (Downloads) | Triangles | Bolt GLB (Downloads) | Triangles |
|---|---|---|---|---|---|---|
| Lantern Staff | Rare | [Lantern Staff](https://claude.ai/design/p/2b23d3e6-f961-45a2-a24a-ca2655da7a08?file=Lantern+Staff.html) | `wpn_lantern_staff.glb` | 2,248 | `wpn_lantern_staff_bolt.glb` | 264 |
| Hootmoss Staff | Epic | [Hootmoss Staff](https://claude.ai/design/p/ffd6d976-ba49-49ef-b4f4-09b2d8032b41?file=Hootmoss+Staff.html) | `wpn_hootmoss_staff.glb` | 2,128 | `wpn_hootmoss_staff_bolt.glb` | 188 |
| Slime Crown Staff | Legendary | [Slime Crown Staff](https://claude.ai/design/p/08e81b66-7e31-435b-a33a-c3b0bd02910c?file=Slime+Crown+Staff.html) | `wpn_slime_crown_staff.glb` | 1,384 | `wpn_slime_crown_staff_bolt.glb` | 176 |
| Worldroot Staff | Mythic | [Worldroot Staff](https://claude.ai/design/p/19d15d52-6166-450e-ae11-7e005f2c4287?file=Worldroot+Staff.html) | `wpn_worldroot_staff.glb` | 2,718 | `wpn_worldroot_staff_bolt.glb` | 236 |

Parts are named by group: Staff (shaft, bands, foot) plus each skin's own groups (Crook, Lanterns
and Leaves; Head, Mushrooms and Vine; Crown, Slime and Head; Orb, Halo, Roots and Leaves).

**Bolts** fly along −Z. Each has two groups: `Bolt`, the projectile itself, and `Tail`, the small
fading cubes the sheets draw behind it. The tail may suit a particle trail better in game; if so,
delete the `Tail` group after import. The Worldroot's tail is the longest (the GLB is 1.04 long
with it, 0.29 without).

**Glows.** The sheets' sparkles and halos of light are not modelled: the viewers' floating
sparkles are left out of the exports, and the soft bloom round the lanterns, eyes and crystals is
the game's to add.
