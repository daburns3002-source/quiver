"""Cut the reroll dice out of the set's worded Reroll buttons.

    python -I assets/ui/glow_toy_cards/cut_dice.py

The draft's buttons are the set's blank plates with their words written live
in the blocky font (CLAUDE.md rule 11, `UI/Cards/DraftScreen`). The dice the
Reroll art carries beside its word is kept: it is whatever differs between
reroll.png and the blank blue plate left of the word (the same for the grey,
disabled pair), its insides filled, written to buttons_live/dice.png and dice_disabled.png.
"""

import pathlib

import numpy as np
from PIL import Image
from scipy import ndimage

HERE = pathlib.Path(__file__).resolve().parent
# Left of the word, inside the plate's face (804 x 324 art).
AREA = (100, 60, 260, 205)


def cut(worded: str, blank: str) -> Image.Image:
    a = np.asarray(Image.open(HERE / "buttons" / worded).convert("RGBA")).astype(int)
    b = np.asarray(Image.open(HERE / "buttons" / blank).convert("RGBA")).astype(int)
    x0, y0, x1, y1 = AREA
    region = a[y0:y1, x0:x1].copy()
    differs = np.abs(region[..., :3] - b[y0:y1, x0:x1, :3]).sum(axis=2) > 30
    # a face the plate's own colour is still dice: fill inside its outline
    region[..., 3] = np.where(ndimage.binary_fill_holes(differs), 255, 0)
    img = Image.fromarray(region.astype(np.uint8), "RGBA")
    return img.crop(img.getbbox())


def main() -> None:
    out = HERE / "buttons_live"
    out.mkdir(exist_ok=True)
    cut("reroll.png", "blank_blue.png").save(out / "dice.png", optimize=True)
    cut("reroll_disabled.png", "blank_grey.png").save(out / "dice_disabled.png", optimize=True)
    for name in ("dice.png", "dice_disabled.png"):
        print("wrote", out / name, Image.open(out / name).size)


if __name__ == "__main__":
    main()
