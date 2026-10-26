"""Cut the title screen's falling leaves (Codex, assets/concepts/blocky/ui/
intro/leaves_raw.png, a 2x2 grid on magenta) into one 2x2 sheet of 128 px
frames with transparency, assets/ui/intro/leaves.png, which `UI/IntroCutscene`
shows one frame per leaf with ImageRectOffset.

    python -I assets/ui/intro/leaves.py
"""

import pathlib

import numpy as np
from PIL import Image
from scipy import ndimage

HERE = pathlib.Path(__file__).resolve().parent
RAW = HERE.parents[1] / "concepts" / "blocky" / "ui" / "intro" / "leaves_raw.png"
CELL = 128


def main() -> None:
    rgb = np.asarray(Image.open(RAW).convert("RGB")).astype(np.float32)
    r, g, b = rgb[..., 0], rgb[..., 1], rgb[..., 2]
    key = np.minimum(r, b) - g
    lab, _ = ndimage.label(key > 110)
    border = np.unique(np.concatenate([lab[0], lab[-1], lab[:, 0], lab[:, -1]]))
    bg = np.isin(lab, border[border > 0]) | (key > 170)
    alpha = np.where(bg, 0, 255).astype(np.uint8)
    img = Image.fromarray(np.dstack([rgb.astype(np.uint8), alpha]), "RGBA")
    w, h = img.size
    sheet = Image.new("RGBA", (CELL * 2, CELL * 2), (0, 0, 0, 0))
    for i in range(4):
        cell = img.crop(((i % 2) * w // 2, (i // 2) * h // 2, (i % 2 + 1) * w // 2, (i // 2 + 1) * h // 2))
        cell = cell.crop(cell.getchannel("A").getbbox())
        side = int(max(cell.size) * 1.08)
        sq = Image.new("RGBA", (side, side), (0, 0, 0, 0))
        sq.paste(cell, ((side - cell.size[0]) // 2, (side - cell.size[1]) // 2))
        sheet.paste(sq.resize((CELL, CELL), Image.LANCZOS), ((i % 2) * CELL, (i // 2) * CELL))
    sheet.save(HERE / "leaves.png")


if __name__ == "__main__":
    main()
