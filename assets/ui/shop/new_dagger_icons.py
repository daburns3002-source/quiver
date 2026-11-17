"""Icons for the Assassin's daggers drawn on 2026-11-16 (Thornwood, the
Drowned Village and the Golden Daggers): the shop picture and the gear
screen's outlined icon.

    python -I assets/ui/shop/new_dagger_icons.py

Codex drew ONE dagger a picture (the 3D model is one dagger, held in each
hand), so the pair is made here: the picture's grey keyed out as
bogheart_icons.py does, then two copies crossed in a V, as the Mossy Glade
pairs are drawn (dagger_icons.py). Writes:

- assets/ui/shop/icons/<Weapon>.png
- assets/ui/gear/outlined/<Weapon>.png, the same with the gear icons' bold
  dark outline.
"""

import json
import pathlib
import sys

import numpy as np
from PIL import Image
from scipy import ndimage

sys.path.insert(0, str(pathlib.Path(__file__).resolve().parent))
from bogheart_icons import fit, key_out
from glade_redesign_icons import outlined

HERE = pathlib.Path(__file__).resolve().parent
REPO = HERE.parents[2]
SKINS = REPO / "assets/concepts/blocky/weapons/skins"
JOBS = REPO / "assets/models/weapons/blocky/daggers_tripo_2026_11_16.json"
# degrees each dagger leans out from upright
LEAN = 24


def single(path: pathlib.Path) -> Image.Image:
    rgba = np.asarray(key_out(Image.open(path).convert("RGB"))).copy()
    solid = rgba[..., 3] > 60
    labels, count = ndimage.label(ndimage.binary_dilation(solid, iterations=3))
    if count:
        sizes = ndimage.sum(solid, labels, range(1, count + 1))
        keep = np.isin(labels, np.flatnonzero(sizes > sizes.max() * 0.02) + 1)
        rgba[~keep, 3] = 0
    cut = Image.fromarray(rgba, "RGBA")
    return cut.crop(cut.getbbox())


def crossed(dagger: Image.Image) -> Image.Image:
    """Two copies in a V: pommels together at the foot, points apart."""
    w, h = dagger.size
    side = int(h * 1.5)
    canvas = Image.new("RGBA", (side, side), (0, 0, 0, 0))
    # each copy on its own square, its pommel at the square's centre, then
    # turned about that centre so the pommels stay together
    for lean, flip in ((LEAN, True), (-LEAN, False)):
        copy = dagger.transpose(Image.FLIP_LEFT_RIGHT) if flip else dagger
        layer = Image.new("RGBA", (side * 2, side * 2), (0, 0, 0, 0))
        layer.alpha_composite(copy, (side - w // 2, side - int(h * 0.94)))
        layer = layer.rotate(lean, resample=Image.BICUBIC, center=(side, side))
        canvas.alpha_composite(layer.crop((side // 2, int(side * 0.4), side // 2 + side, int(side * 0.4) + side)))
    return canvas.crop(canvas.getbbox())


def main() -> None:
    shop = HERE / "icons"
    gear = REPO / "assets/ui/gear/outlined"
    jobs = json.loads(JOBS.read_text(encoding="utf-8"))["jobs"]
    for stem, job in jobs.items():
        icon = fit(crossed(single(SKINS / job["area"] / f"{stem}.png")))
        icon.save(shop / f"{job['key']}.png")
        outlined(icon).save(gear / f"{job['key']}.png")
        print(job["key"])


if __name__ == "__main__":
    main()
