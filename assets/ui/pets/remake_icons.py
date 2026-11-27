"""Menu pictures for the pets remade on 2026-11-11 (#541), cut the same way
as the Bogheart pets' (`assets/ui/shop/bogheart_icons.py`), from the art each
remake was built from, so the picture matches the model in the game (owner,
2026-11-13: "make sure the icons for everything in the gear ui, weapon and
egg ui, and dexes all match"):

- BrambleWilf, EmberWilfPet: Codex's recolours of the Glowcap Wilf that the
  Tripo remakes were made from (memory `wilfs-are-glowcap-recolours`), kept
  in assets/concepts/blocky/pets/wilfs/;
- Thornwake: the three-quarter front view of its sheet, the reference its
  Claude Design remake matched (docs/design-prompts/pet-remakes-2026-11.md).

    python -I assets/ui/pets/remake_icons.py

Writes assets/ui/pets/icons/<Pet>.png, 256 px, upright. Upload each and put
its id in `Config/GearAssets.pets`. The Cave Cricket's picture was already
cut from its remake's reference (`01_cave_cricket_legs`).
"""

import importlib.util
import pathlib

from PIL import Image

HERE = pathlib.Path(__file__).resolve().parent
REPO = HERE.parents[2]
spec = importlib.util.spec_from_file_location("bogheart_icons", REPO / "assets/ui/shop/bogheart_icons.py")
cutter = importlib.util.module_from_spec(spec)
spec.loader.exec_module(cutter)

PETS = REPO / "assets/concepts/blocky/pets"
# (source, crop box in the source or None for the whole picture)
REMAKES = {
    "BrambleWilf": (PETS / "wilfs/bramble_wilf_glowcap.png", None),
    "EmberWilfPet": (PETS / "wilfs/ember_wilf_glowcap.png", None),
    "Thornwake": (PETS / "thornwood/12_thornwake_views.png", (400, 95, 815, 425)),
}


def main() -> None:
    out = HERE / "icons"
    out.mkdir(parents=True, exist_ok=True)
    for name, (source, box) in REMAKES.items():
        img = Image.open(source)
        if box:
            img = img.crop(box)
        cutter.fit(cutter.key_out(img)).save(out / f"{name}.png")
        print("pet", name)


if __name__ == "__main__":
    main()
