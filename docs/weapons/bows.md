# Bow skins — Mossy Glade

The Mossy Glade's bow skins, modelled in Claude Design from their reference sheets
in `assets/concepts/blocky/weapons/skins/forest/`. Each bow and its projectile was
exported as a GLB to the owner's Downloads folder for a hand import in Studio.
Wiring them into `Config/Weapons` comes later.

All of them follow the Acorn Bow's frame: Y up, 1.18 tall, the bow in the YZ plane
with the limbs bowing toward +Z, the string straight on the −Z side, and the grip at
the origin. Projectiles point toward −Z with the nock (back end) at z = 0. Every mesh
is named after its part, and glowing parts (strings, gems, lanterns, crystals) carry
emissive materials.

| Weapon | Rarity | Sheet | Claude Design project | Bow GLB | Projectile GLB |
|---|---|---|---|---|---|
| Ember Fang Bow | Legendary | `ember_fang_bow_views.png` | [Ember Fang Bow Modeling](https://claude.ai/design/p/658c8e19-917b-4af5-b072-c9243d2fc846) | `wpn_ember_fang_bow.glb` (2,524 tris) | `wpn_ember_fang_arrow.glb` (524 tris, 1.86 long) |
| Firefly Bow | Rare | `firefly_bow_views.png` | [Firefly Bow Roblox Model](https://claude.ai/design/p/0328638f-f589-47d4-b72d-43714fbdad96) | `wpn_firefly_bow.glb` (1,620 tris) | `wpn_firefly_dart.glb` (324 tris, 0.75 long) |
| Glade Spirit Bow | Mythic | `glade_spirit_bow_views.png` | [Glade Spirit Bow Design](https://claude.ai/design/p/6f58637c-c222-4ce2-a027-e7666af1cb71) | `wpn_glade_spirit_bow.glb` (1,660 tris) | `wpn_glade_spirit_arrow.glb` (196 tris, 1.86 long) |
| Moss Slime Bow | Epic | `moss_slime_bow_views.png` | [Moss Slime Bow Model](https://claude.ai/design/p/fc966e2e-a85e-4ec6-bf75-2ebe303f3fb3) | `wpn_moss_slime_bow.glb` (2,648 tris) | `wpn_moss_slime_arrow.glb` (572 tris, 1.86 long) |

Each project keeps its earlier rounds as versioned pages (for example `Ember Fang Bow v4.html`).
The exported files are the current `<Weapon> Bow.html` and `<Weapon> Arrow.html` (or `Dart`).

## What is not modelled

The sheets' floating sparkles, butterflies, swirl rings and drifting cubes are effects,
not part of the mesh. They belong in the weapon's VFX pass, along with any bloom on the
emissive parts.

## Next

1. The owner imports each GLB in Studio (File → Import 3D, Merge Meshes off).
2. `optimise_weapon.py`, mesh ids into `Config/Weapons`, and the skin hook-up (`docs/PIPELINES.md` §5).
3. The Firefly's projectile is a short dart (0.75), not an arrow, so its spawn offset and hitbox
   need their own numbers when it is wired in.
