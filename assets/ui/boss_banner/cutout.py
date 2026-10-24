"""Cut the boss icons out of Codex's flat magenta background.

    python -I assets/ui/boss_banner/cutout.py

Reads assets/concepts/blocky/boss_icons/<boss>_raw.png (Codex's output, kept as
made) and writes assets/ui/boss_banner/icons/<boss>.png: transparent outside
the character, trimmed and padded to a square, 512 px, ready to upload.
Magenta connected to the border is removed, and near-pure magenta anywhere, so
the purple on a boss stays.
"""

import pathlib

import numpy as np
from PIL import Image
from scipy import ndimage

ROOT = pathlib.Path(__file__).resolve().parents[3]
RAW = ROOT / "assets/concepts/blocky/boss_icons"
OUT = pathlib.Path(__file__).resolve().parent / "icons"
SIZE = 512
PAD = 0.04


def cut(path: pathlib.Path) -> Image.Image:
    rgb = np.asarray(Image.open(path).convert("RGB")).astype(np.float32)
    r, g, b = rgb[..., 0], rgb[..., 1], rgb[..., 2]
    # how magenta a pixel is: strong red and blue, little green
    key = np.minimum(r, b) - g
    near = key > 110
    labels, _ = ndimage.label(near)
    border = np.unique(np.concatenate([labels[0], labels[-1], labels[:, 0], labels[:, -1]]))
    # plus pockets of near-pure magenta the outline closes off (between wings, a bell's loop)
    bg = np.isin(labels, border[border > 0]) | (key > 170)
    # soften one pixel of edge, and pull the magenta out of it
    edge = ndimage.binary_dilation(bg, iterations=2) & ~bg
    alpha = np.where(bg, 0.0, 1.0)
    alpha[edge] = np.clip(1.0 - (key[edge] - 30) / 120, 0.0, 1.0)
    spill = edge & (key > 0)
    rgb[..., 0][spill] = np.minimum(r[spill], g[spill] + 30)
    rgb[..., 2][spill] = np.minimum(b[spill], g[spill] + 30)
    rgba = np.dstack([rgb, alpha * 255]).astype(np.uint8)
    img = Image.fromarray(rgba, "RGBA")
    img = img.crop(img.getbbox())
    side = int(max(img.size) * (1 + 2 * PAD))
    square = Image.new("RGBA", (side, side), (0, 0, 0, 0))
    square.paste(img, ((side - img.width) // 2, (side - img.height) // 2), img)
    return square.resize((SIZE, SIZE), Image.LANCZOS)


def main() -> None:
    OUT.mkdir(exist_ok=True)
    for path in sorted(RAW.glob("*_raw.png")):
        name = path.stem.removesuffix("_raw")
        cut(path).save(OUT / f"{name}.png", optimize=True)
        print("wrote", (OUT / f"{name}.png").relative_to(ROOT))


if __name__ == "__main__":
    main()
