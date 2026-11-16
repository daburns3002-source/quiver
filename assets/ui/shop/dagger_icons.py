"""Icons for the Assassin's six Mossy Glade dagger pairs: the shop picture and
the gear screen's outlined icon.

    python -I assets/ui/shop/dagger_icons.py

Reads Codex's sheet of the six pairs
(assets/concepts/blocky/weapons/skins/forest/w4_dagger_skins.png, each pair
crossed in a V on light grey), cuts each pair's cell, keys out the grey as
bogheart_icons.py does, drops the floor shadow and any stray sparkle of the
pair next door, and writes:

- assets/ui/shop/icons/<Weapon>.png, as drawn (a crossed pair is already
  posed, so it is not leaned as the single weapons are);
- assets/ui/gear/outlined/<Weapon>.png, the same with the gear icons' bold
  dark outline.
"""

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
SHEET = REPO / "assets/concepts/blocky/weapons/skins/forest/w4_dagger_skins.png"
# The row of pairs on the 1672 x 941 sheet: top and bottom, and each pair's
# left and right edge.
TOP, BOTTOM = 262, 712
PAIRS = {
    "SplinterDaggers": (20, 275),
    "BrambleShivs": (295, 545),
    "FireflyFangs": (560, 815),
    "GladeFoxClaws": (835, 1085),
    "EmberWilfFangs": (1095, 1375),
    "GlimmerhornDaggers": (1385, 1665),
}


def pair(sheet: Image.Image, left: int, right: int) -> Image.Image:
    cut = key_out(sheet.crop((left, TOP, right, BOTTOM)))
    rgba = np.asarray(cut).copy()
    rgb = rgba[..., :3].astype(np.float32)
    # the floor shadow: a pale grey, a little darker than the background,
    # along the foot of the cell
    spread = rgb.max(axis=-1) - rgb.min(axis=-1)
    shadow = (spread < 16) & (rgb.mean(axis=-1) > 150)
    shadow[: int(rgba.shape[0] * 0.78)] = False
    # and its darker middle, right under the pommels
    under = (spread < 20) & (rgb.mean(axis=-1) > 105)
    under[: int(rgba.shape[0] * 0.9)] = False
    rgba[shadow | under, 3] = 0
    # the pair itself: every piece of any size, so a sparkle stays and a
    # speck does not
    solid = rgba[..., 3] > 60
    labels, count = ndimage.label(ndimage.binary_dilation(solid, iterations=3))
    if count:
        sizes = ndimage.sum(solid, labels, range(1, count + 1))
        keep = np.isin(labels, np.flatnonzero(sizes > sizes.max() * 0.02) + 1)
        rgba[~keep, 3] = 0
    return Image.fromarray(rgba, "RGBA")


def main() -> None:
    shop = HERE / "icons"
    gear = REPO / "assets/ui/gear/outlined"
    gear.mkdir(parents=True, exist_ok=True)
    sheet = Image.open(SHEET)
    for name, (left, right) in PAIRS.items():
        icon = fit(pair(sheet, left, right))
        icon.save(shop / f"{name}.png")
        outlined(icon).save(gear / f"{name}.png")
        print(name)


if __name__ == "__main__":
    main()
