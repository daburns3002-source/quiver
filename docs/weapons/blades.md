# Blade skins (Mossy Glade)

Four Warden sword skins, modelled in Claude Design from their reference sheets in
`assets/concepts/blocky/weapons/skins/forest/`. The GLBs are in the owner's Downloads folder
awaiting a Studio import. Wiring them into `Config/Weapons` is a later pass.

All four share the Mossstone Blade's frame: Y-up, blade toward +Y, flat faces toward ±Z, guard
along X, origin at the grip centre, pommel bottom at y = -0.30 and tip at y = 0.96. Materials are
flat colours, with no textures and no clips.

| Weapon | Rarity | Claude Design project | GLB (Downloads) | Triangles |
|---|---|---|---|---|
| Thorn Blade | Rare | [Thorn Blade](https://claude.ai/design/p/ac018603-be19-454c-859b-c21a97acfbdd?file=Thorn+Blade.html) | `wpn_thorn_blade.glb` | 2,082 |
| Broodsplit Blade | Epic | [Broodsplit Blade v4](https://claude.ai/design/p/75ad8028-69fb-468f-9748-58106cc6699d?file=Broodsplit+Blade+v4.html) | `wpn_broodsplit_blade.glb` | 2,498 |
| Emberfang Blade | Legendary | [Emberfang Blade](https://claude.ai/design/p/a26c3734-2cec-44fd-9039-f423b85b7afd?file=Emberfang+Blade.html) | `wpn_emberfang_blade.glb` | 2,344 |
| Gladeheart Blade | Mythic | [Gladeheart Blade](https://claude.ai/design/p/6c606f1f-fd82-49c3-80e0-7b6b176cd1c2?file=Gladeheart+Blade.html) | `wpn_gladeheart_blade.glb` | 2,998 |

Parts are named by group: Blade, Guard, Grip, Pommel, Gems, plus each skin's own groups (Vine,
Thorns and Mushrooms; SlimeCore and SlimeFaces; LavaCore, Studs, BeastHead and Claws; Branches,
Leaves, Crystals and Flowers).

**Floating bits.** The Broodsplit's loose slime cubes (`SlimeCore/SlimeBits`) and the Emberfang's
ember cubes (`Embers`) are in their GLBs as separate named parts, because the sheets draw them.
In game they may suit a particle emitter better. If so, delete those groups after import.
