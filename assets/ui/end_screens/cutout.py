"""Cut the end screens' art out of Codex's flat magenta backgrounds.

    python -I assets/ui/end_screens/cutout.py

Reads assets/concepts/blocky/ui/end_screens_raw/ (Codex's output, kept as made):
  ribbon_victory.png, ribbon_defeat.png  the title ribbons, blank for live text
  hero_victory.png, hero_defeat.png      the pictures in the middle
  rays_victory.png                       the light rays behind the trophy
  icons.png                              a 4 x 3 grid of icons (NAMES below)
and writes assets/ui/end_screens/art/<name>.png, each cropped to what is drawn
and at most 1024 px on its longer side (Roblox's largest). The crops' sizes
and where they sat in the frame print at the end, for `Config/EndScreenLayout`.
"""

import pathlib

import numpy as np
from PIL import Image
from scipy import ndimage

ROOT = pathlib.Path(__file__).resolve().parents[3]
RAW = ROOT / "assets/concepts/blocky/ui/end_screens_raw"
OUT = pathlib.Path(__file__).resolve().parent / "art"
MAX = 1024
PAD = 4

WHOLE = ["ribbon_victory", "ribbon_defeat", "hero_victory", "hero_defeat", "rays_victory"]
NAMES = [
    ["skull", "hourglass", "heart", "chart"],
    ["coin", "gem", "chevron", "refresh"],
    ["cube", "drop", "star", "sparkle"],
]
ICON = 256


def key_out(img: Image.Image) -> Image.Image:
    """As `assets/ui/boss_banner/cutout.py`: magenta joined to the border goes,
    and near-pure magenta anywhere, with one soft pixel of edge."""
    rgb = np.asarray(img.convert("RGB")).astype(np.float32)
    r, g, b = rgb[..., 0], rgb[..., 1], rgb[..., 2]
    key = np.minimum(r, b) - g
    near = key > 110
    labels, _ = ndimage.label(near)
    border = np.unique(np.concatenate([labels[0], labels[-1], labels[:, 0], labels[:, -1]]))
    bg = np.isin(labels, border[border > 0]) | (key > 170)
    edge = ndimage.binary_dilation(bg, iterations=2) & ~bg
    alpha = np.where(bg, 0.0, 1.0)
    alpha[edge] = np.clip(1.0 - (key[edge] - 30) / 120, 0.0, 1.0)
    spill = edge & (key > 0)
    rgb[..., 0][spill] = np.minimum(r[spill], g[spill] + 30)
    rgb[..., 2][spill] = np.minimum(b[spill], g[spill] + 30)
    return Image.fromarray(np.dstack([rgb, alpha * 255]).astype(np.uint8), "RGBA")


def crop(img: Image.Image) -> Image.Image:
    a = np.asarray(img)[..., 3]
    ys, xs = np.nonzero(a > 8)
    box = (
        max(0, xs.min() - PAD),
        max(0, ys.min() - PAD),
        min(img.width, xs.max() + 1 + PAD),
        min(img.height, ys.max() + 1 + PAD),
    )
    return img.crop(box)


def fit(img: Image.Image, longest: int) -> Image.Image:
    scale = longest / max(img.size)
    if scale >= 1:
        return img
    size = (round(img.width * scale), round(img.height * scale))
    return img.resize(size, Image.NEAREST)


def main() -> None:
    OUT.mkdir(exist_ok=True)
    for name in WHOLE:
        img = fit(crop(key_out(Image.open(RAW / f"{name}.png"))), MAX)
        img.save(OUT / f"{name}.png")
        print(f"{name}: {img.width} x {img.height}")
    sheet = key_out(Image.open(RAW / "icons.png"))
    cw, ch = sheet.width / 4, sheet.height / 3
    for row, names in enumerate(NAMES):
        for col, name in enumerate(names):
            cell = sheet.crop(
                (round(col * cw), round(row * ch), round((col + 1) * cw), round((row + 1) * ch))
            )
            icon = crop(cell)
            # square, centred, so every icon box draws its icon the same size
            side = max(icon.size)
            square = Image.new("RGBA", (side, side))
            square.paste(icon, ((side - icon.width) // 2, (side - icon.height) // 2))
            square.resize((ICON, ICON), Image.NEAREST).save(OUT / f"{name}.png")
            print(f"{name}: {ICON} x {ICON}")


if __name__ == "__main__":
    main()
