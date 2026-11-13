"""Icons for the four Mossy Glade weapons redesigned for their Tripo models
(2026-11-13): the shop picture and the gear screen's outlined icon.

    python -I assets/ui/shop/glade_redesign_icons.py

Reads the approved Codex front view each Tripo model was made from
(assets/concepts/blocky/weapons/tripo_remake/<name>_<pick>.png), keys out
the grey as bogheart_icons.py does, and writes:

- assets/ui/shop/icons/<Weapon>.png, leaned TILT degrees right like every
  other shop icon;
- assets/ui/gear/outlined/<Weapon>.png, the same with the gear icons' bold
  dark outline (owner, 2026-10-26: "they need to have a border around them").
"""

import pathlib
import sys

import numpy as np
from PIL import Image
from scipy import ndimage

sys.path.insert(0, str(pathlib.Path(__file__).resolve().parent))
from bogheart_icons import PAD, SIZE, TILT, fit, key_out

HERE = pathlib.Path(__file__).resolve().parent
REPO = HERE.parents[2]
ART = REPO / "assets/concepts/blocky/weapons/tripo_remake"
OUTLINE = (24, 16, 10)
THICK = 5

PICKS = {
    "ThornBlade": "thorn_blade_b",
    "GladeSpiritBow": "glade_spirit_bow_m",
    "WorldrootStaff": "worldroot_staff_l",
    "GladeheartBlade": "gladeheart_blade_l",
}


def outlined(img: Image.Image) -> Image.Image:
    # shrink a little so the outline fits inside the square
    inner = img.resize((SIZE - 4 * THICK, SIZE - 4 * THICK), Image.LANCZOS)
    base = Image.new("RGBA", (SIZE, SIZE), (0, 0, 0, 0))
    base.paste(inner, (2 * THICK, 2 * THICK), inner)
    a = np.asarray(base)[..., 3] > 60
    ring = ndimage.binary_dilation(a, iterations=THICK)
    out = np.zeros((SIZE, SIZE, 4), np.uint8)
    out[ring] = (*OUTLINE, 255)
    back = Image.fromarray(out, "RGBA")
    back.alpha_composite(base)
    return back


def main() -> None:
    shop = HERE / "icons"
    gear = REPO / "assets/ui/gear/outlined"
    gear.mkdir(parents=True, exist_ok=True)
    for name, stem in PICKS.items():
        cut = key_out(Image.open(ART / f"{stem}.png"))
        cut = cut.crop(cut.getchannel("A").getbbox())
        cut = cut.rotate(-TILT, resample=Image.BICUBIC, expand=True)
        icon = fit(cut)
        icon.save(shop / f"{name}.png")
        outlined(icon).save(gear / f"{name}.png")
        print(name)


if __name__ == "__main__":
    main()
