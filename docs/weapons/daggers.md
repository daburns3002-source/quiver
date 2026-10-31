# Duelist dagger skins — Mossy Glade

Five dual-wield dagger skins for the Mossy Glade, modelled in Claude Design
from their reference sheets in `assets/concepts/blocky/weapons/skins/forest/`
(each `<weapon>_views.png`, with `w4_dagger_skins.png` for the pair). Bramble
Shivs, the Uncommon, was made earlier (`assets/models/weapons/blocky/uncommon/`).

Every pair is two identical daggers in the sheets, so each is **one model,
used for both hands** (mirror or duplicate it). Each was compared view by view
against its sheet (front, back, side, three-quarter) and reworked until it
matched before export.

All share BrambleShivs' frame: 0.84 long from tip to pommel, long axis +Y,
blade flat in XY, origin at the middle of the grip; flat material colours,
emissive materials for the glowing parts, no animations.

The GLBs are in the owner's Downloads folder, waiting to be imported by hand
in Studio. Not wired into config or code yet — that is a later pass, with the
projectiles (the sheets' slashes were not modelled here).

| Weapon | Rarity | Claude Design project | GLB (Downloads) | Triangles | Parts |
|---|---|---|---|---|---|
| Splinter Daggers | Common | [a56c5244](https://claude.ai/design/p/a56c5244-e2ae-43c8-8a1b-b05db69a6ca1) | `wpn_splinter_daggers.glb` | 1,588 | Blade, Collar, Guard, Grip, Wraps, Pommel |
| Firefly Fangs | Rare | [67e8370b](https://claude.ai/design/p/67e8370b-0eaf-4b2c-bf9f-d361d73aae1d) | `wpn_firefly_fangs.glb` | 2,052 | Blade, Lantern, Fireflies, Grip, Wraps, Pommel |
| Glade Fox Claws | Epic | [48dd2e91](https://claude.ai/design/p/48dd2e91-e911-424a-a608-adb5c1a343ba) | `wpn_glade_fox_claws.glb` | 2,252 | Blade, Rune, FoxSkull, Flower, Motes, Grip, Wraps, Pommel |
| Ember Wilf Fangs | Legendary | [d07fc624](https://claude.ai/design/p/d07fc624-6b38-43fc-b87c-eede0245aee0) | `wpn_ember_wilf_fangs.glb` | 1,532 | Blade, WilfHead, Embers, Grip, Wraps, Pommel |
| Glimmerhorn Daggers | Mythic | [9470a137](https://claude.ai/design/p/9470a137-fa47-413a-ae40-a0139c4fed2f) | `wpn_glimmerhorn_daggers.glb` | 2,258 | Blade, Rainbow, Antlers, Blossoms, Gem, Guard, Grip, Wraps, Pommel |

Floating bits (Firefly Fangs' fireflies, Glade Fox Claws' motes, Ember Wilf
Fangs' embers) are separate groups so they can be dropped or animated on
import.
