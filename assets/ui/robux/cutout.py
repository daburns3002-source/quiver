"""Cut the Robux store's icons out of Codex's sheet.

    python -I assets/ui/robux/cutout.py

Reads assets/concepts/blocky/ui/robux/icons_raw.png (3 x 2 on flat magenta:
2x Coins, Extra Pet Slot, VIP; Starter Pack, Revive) and writes
icons/<Key>.png at 512 px, the size the Creator Dashboard asks for. The keying
is the trail icons' (assets/ui/trails/cutout.py).
"""

import pathlib

import numpy as np
from PIL import Image
from scipy import ndimage

HERE = pathlib.Path(__file__).resolve().parent
ROOT = HERE.parents[2]
RAW = ROOT / "assets/concepts/blocky/ui/robux/icons_raw.png"
SIZE = 512
PAD = 0.04
KEYS = ["DoubleCoins", "PetSlot", "VIP", "StarterPack", "Revive"]


def key_out(img: Image.Image, colour: str) -> Image.Image:
    rgb = np.asarray(img.convert("RGB")).astype(np.float32)
    r, g, b = rgb[..., 0], rgb[..., 1], rgb[..., 2]
    # how much of the key a pixel is
    key = np.minimum(r, b) - g if colour == "magenta" else g - np.maximum(r, b)
    near = key > 110
    labels, _ = ndimage.label(near)
    border = np.unique(np.concatenate([labels[0], labels[-1], labels[:, 0], labels[:, -1]]))
    bg = np.isin(labels, border[border > 0]) | (key > 170)
    edge = ndimage.binary_dilation(bg, iterations=2) & ~bg
    alpha = np.where(bg, 0.0, 1.0)
    alpha[edge] = np.clip(1.0 - (key[edge] - 30) / 120, 0.0, 1.0)
    spill = edge & (key > 0)
    if colour == "magenta":
        rgb[..., 0][spill] = np.minimum(r[spill], g[spill] + 30)
        rgb[..., 2][spill] = np.minimum(b[spill], g[spill] + 30)
    else:
        rgb[..., 1][spill] = np.minimum(g[spill], np.maximum(r[spill], b[spill]) + 30)
    return Image.fromarray(np.dstack([rgb, alpha * 255]).astype(np.uint8), "RGBA")


def drop_strays(img: Image.Image, share: float = 0.01) -> Image.Image:
    rgba = np.asarray(img).copy()
    labels, count = ndimage.label(rgba[..., 3] > 0)
    edge = np.unique(np.concatenate([labels[0], labels[-1], labels[:, 0], labels[:, -1]]))
    sizes = ndimage.sum(np.ones_like(labels), labels, range(count + 1))
    for lab in edge[edge > 0]:
        if sizes[lab] < share * labels.size:
            rgba[labels == lab, 3] = 0
    return Image.fromarray(rgba, "RGBA")


def fit(img: Image.Image) -> Image.Image:
    box = img.getbbox()
    piece = img.crop(box)
    room = int(SIZE * (1 - 2 * PAD))
    scale = room / max(piece.width, piece.height)
    piece = piece.resize((max(1, round(piece.width * scale)), max(1, round(piece.height * scale))), Image.LANCZOS)
    out = Image.new("RGBA", (SIZE, SIZE), (0, 0, 0, 0))
    out.paste(piece, ((SIZE - piece.width) // 2, (SIZE - piece.height) // 2), piece)
    return out


def main() -> None:
    (HERE / "icons").mkdir(exist_ok=True)
    whole = Image.open(RAW)
    cell_w, cell_h = whole.width // 3, whole.height // 2
    for i, key in enumerate(KEYS):
        x, y = (i % 3) * cell_w, (i // 3) * cell_h
        piece = drop_strays(key_out(whole.crop((x, y, x + cell_w, y + cell_h)), "magenta"))
        fit(piece).save(HERE / "icons" / f"{key}.png", optimize=True)
        print("wrote", f"icons/{key}.png")


if __name__ == "__main__":
    main()
