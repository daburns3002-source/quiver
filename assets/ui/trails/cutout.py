"""Cut the trail icons and the Starfall star out of Codex's sheets.

    python -I assets/ui/trails/cutout.py

Reads assets/concepts/blocky/ui/trails/icons_a_raw.png (3 x 3 on flat
magenta: rows Mossy Glade, Drowned Village, Bogheart Caverns; columns Rare,
Epic, Legendary), icons_b_raw.png (2 x 2 on flat green: Thornwood's three and
Starfall; green because Bramble Pollen is magenta) and star_raw.png (a white
cross on black), and writes icons/<Trail>.png (512 px) and star.png (256 px,
white, its alpha from the light). The keying is the boss banner's
(assets/ui/boss_banner/cutout.py), turned for either key colour.
"""

import pathlib

import numpy as np
from PIL import Image
from scipy import ndimage

HERE = pathlib.Path(__file__).resolve().parent
ROOT = HERE.parents[2]
RAW = ROOT / "assets/concepts/blocky/ui/trails"
SIZE = 512
PAD = 0.04
SHEETS = [
    ("icons_a_raw.png", "magenta", 3, [
        "LeafDrift", "FireflyWake", "RoyalGoo",
        "BubbleStream", "SplashWake", "TideBell",
        "BogSpores", "GlowcapPath", "GulpsBubbles",
    ]),
    ("icons_b_raw.png", "green", 2, ["BramblePollen", "CrowFeathers", "BroodSilk", "Starfall"]),
]


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


def star() -> None:
    grey = np.asarray(Image.open(RAW / "star_raw.png").convert("L")).astype(np.float32)
    alpha = np.clip((grey - 8) / 247, 0, 1)
    white = np.full(grey.shape, 255, np.uint8)
    img = Image.fromarray(np.dstack([white, white, white, (alpha * 255).astype(np.uint8)]), "RGBA")
    img = img.crop(img.getbbox())
    side = max(img.size)
    square = Image.new("RGBA", (side, side), (255, 255, 255, 0))
    square.paste(img, ((side - img.width) // 2, (side - img.height) // 2), img)
    square.resize((256, 256), Image.LANCZOS).save(HERE / "star.png", optimize=True)
    print("wrote", (HERE / "star.png").relative_to(ROOT))


def main() -> None:
    (HERE / "icons").mkdir(exist_ok=True)
    for name, colour, n, keys in SHEETS:
        whole = Image.open(RAW / name)
        cell = whole.width // n
        for i, key in enumerate(keys):
            x, y = (i % n) * cell, (i // n) * cell
            piece = drop_strays(key_out(whole.crop((x, y, x + cell, y + cell)), colour))
            fit(piece).save(HERE / "icons" / f"{key}.png", optimize=True)
            print("wrote", f"icons/{key}.png")
    star()


if __name__ == "__main__":
    main()
