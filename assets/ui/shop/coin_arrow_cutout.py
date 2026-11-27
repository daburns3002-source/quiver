"""Cut the arrow coin out of Codex's sheet of four.

    python -I assets/ui/shop/coin_arrow_cutout.py <colour> [out.png]

Reads assets/concepts/blocky/ui/shop/coin_arrow_raw.png (a 2 x 2 grid on
flat magenta: the shop coin with an arrow for its leaf, in COLOURS' order;
the prompt is coin_arrow.prompt.txt beside it) and writes one of them as a
256 px square, to icons/CoinArrow.png unless told where. Keyed, trimmed and
centred exactly as cutout.py does the other shop icons.
"""

import sys
from pathlib import Path

from PIL import Image

sys.path.insert(0, str(Path(__file__).resolve().parent))
from cutout import OUT, PAD, RAW, SIZE, key_out, main_shape  # noqa: E402

COLOURS = ["green", "gold", "white", "red"]


def cut(colour: str) -> Image.Image:
    i = COLOURS.index(colour)
    img = key_out(Image.open(RAW / "coin_arrow_raw.png"))
    cw, ch = img.size[0] // 2, img.size[1] // 2
    cell = img.crop(((i % 2) * cw, (i // 2) * ch, (i % 2 + 1) * cw, (i // 2 + 1) * ch))
    cell = main_shape(cell)
    box = cell.getchannel("A").point(lambda a: 255 if a > 40 else 0).getbbox()
    if box:
        cell = cell.crop(box)
    side = int(max(cell.size) * (1 + 2 * PAD))
    square = Image.new("RGBA", (side, side), (0, 0, 0, 0))
    square.paste(cell, ((side - cell.size[0]) // 2, (side - cell.size[1]) // 2))
    return square.resize((SIZE, SIZE), Image.LANCZOS)


if __name__ == "__main__":
    cut(sys.argv[1]).save(sys.argv[2] if len(sys.argv) > 2 else OUT / "CoinArrow.png")
