---
name: add-weapon
description: Add or update a class weapon — its model and its R15 animation kit (.rbxmx KeyframeSequences) — or a Mythic/card that plays a weapon clip, through conversion, generated config and a Studio check of its timing markers.
---

# Add a weapon or kit

Follow `docs/PIPELINES.md` §5 (and §6 for a card or Mythic). In short:

1. `/intake` the kit: it lists which clips are new or changed against the repo.
2. Model: `assets/models/weapons/optimise_weapon.py`, owner imports, part ids into `Config/Weapons`.
3. Kit: copy the `.rbxmx` beside its weapon (`git add -f`), `kit_to_json.py <kit> <Prefix_> <out.json>`, then `weapon_animations_to_luau.py` (and StyLua). Name the clips in `Config/Weapons.clips`.
4. Check timing markers against the server (`WeaponTiming`, `ClassCards.spec`), then loop 0 in `docs/PIPELINES.md` and `tools/ship.sh`.
