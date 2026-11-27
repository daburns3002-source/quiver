"""Menu pictures for the Windswept Cliffs' eight pets (2026-11-26), cut the
same way as the Bogheart pets' (`assets/ui/shop/bogheart_icons.py`) from the
Codex art each model was built from (`assets/concepts/blocky/pets/windswept/`),
so the picture matches the model: the big three-quarter view on the left of
each model sheet, and the Gale Wilf's whole recolour of the Glowcap Wilf.

    python -I assets/ui/pets/windswept_icons.py

Writes assets/ui/pets/icons/<Pet>.png, 256 px. Upload each and put its id
in `Config/GearAssets.pets`.
"""
import importlib.util
import pathlib

import numpy as np
from PIL import Image
from scipy import ndimage

HERE = pathlib.Path(__file__).resolve().parent
REPO = HERE.parents[2]
spec = importlib.util.spec_from_file_location("bogheart_icons", REPO / "assets/ui/shop/bogheart_icons.py")
cutter = importlib.util.module_from_spec(spec)
spec.loader.exec_module(cutter)

SHEETS = REPO / "assets/concepts/blocky/pets/windswept"
#: the big view: the left part of a 1672 x 941 sheet, short of the small views
PETS = {
    "WhistleMarmot": ("01_whistle_marmot_views.png", (0, 0, 680, 941)),
    "CliffPuffin": ("02_cliff_puffin_views.png", (0, 0, 850, 941)),
    "WoollyAlpaca": ("03_woolly_alpaca_views.png", (0, 0, 680, 941)),
    "GaleGlider": ("04_gale_glider_views.png", (0, 0, 820, 941)),
    "FlagtailPanda": ("05_flagtail_panda_views.png", (0, 0, 870, 941)),
    "GaleWilf": ("06_gale_wilf_glowcap.png", None),
    "Rocling": ("07_rocling_views.png", (0, 0, 700, 941)),
    "ZephyrWhale": ("08_zephyr_whale_views.png", (0, 0, 900, 941)),
}


def largest(img: Image.Image) -> Image.Image:
    """Only the biggest shape: specks of a neighbouring view go."""
    rgba = np.array(img.convert("RGBA"))
    labels, count = ndimage.label(rgba[:, :, 3] > 24)
    if count > 1:
        sizes = ndimage.sum(np.ones_like(labels), labels, range(1, count + 1))
        keep = 1 + int(np.argmax(sizes))
        near = ndimage.binary_dilation(labels == keep, iterations=6)
        rgba[~near, 3] = 0
    return Image.fromarray(rgba)


def main() -> None:
    out = HERE / "icons"
    out.mkdir(parents=True, exist_ok=True)
    for name, (source, box) in PETS.items():
        img = Image.open(SHEETS / source)
        if box:
            img = img.crop(box)
        cutter.fit(largest(cutter.key_out(img))).save(out / f"{name}.png")
        print("pet", name)


if __name__ == "__main__":
    main()
