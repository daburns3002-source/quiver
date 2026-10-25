"""Clear the rarity word off the blank banners, for live blocky text.

    python -I assets/ui/glow_toy_cards/clear_plates.py

The set's banners_blank/ still carry the rarity in the set's rounded font on
the white plate under the ribbon. Every word on screen is in the blocky font
(CLAUDE.md rule 11), so the card draws the name and the rarity itself
(`UI/Cards/CardBuilder`). This writes banners_live/<rarity>.png: the same art
with the plate's lettering painted over in the plate's white, row by row
between its dark outline.
"""

import pathlib

import numpy as np
from PIL import Image

HERE = pathlib.Path(__file__).resolve().parent
# The plate's white rows in the 984 x 558 banner, and its middle column.
ROWS = range(330, 378)
MIDDLE = 492
OUTLINE = 70


def clear(path: pathlib.Path) -> Image.Image:
    """Each plate row painted white between the dark outline on either side."""
    rgba = np.asarray(Image.open(path).convert("RGBA")).copy()
    for y in ROWS:
        dark = rgba[y, :, :3].max(axis=1) < OUTLINE
        left = MIDDLE
        while left > 0 and not dark[left - 1]:
            left -= 1
        right = MIDDLE
        while right < rgba.shape[1] - 1 and not dark[right + 1]:
            right += 1
        rgba[y, left : right + 1, :3] = 255
        rgba[y, left : right + 1, 3] = 255
    return Image.fromarray(rgba, "RGBA")


def main() -> None:
    out = HERE / "banners_live"
    out.mkdir(exist_ok=True)
    for path in sorted((HERE / "banners_blank").glob("*.png")):
        clear(path).save(out / path.name, optimize=True)
        print("wrote", (out / path.name).relative_to(HERE.parents[2]))


if __name__ == "__main__":
    main()
