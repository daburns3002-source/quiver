"""Cut the weapon shop's icons out of Codex's flat magenta sheets.

    python -I assets/ui/shop/cutout.py

Reads assets/concepts/blocky/ui/shop/<sheet>_raw.png (3 x 2 grids, as Codex
made them) and writes assets/ui/shop/icons/<Name>.png, 256 px squares with
the magenta keyed out, each weapon or icon trimmed and centred. The names
are `Config/Shop`'s and `Config/WeaponStats`'s. Run three_quarter.py after
this: it replaces every weapon that has a reference sheet with that sheet's
three-quarter view (only the Acorn Bow keeps its Codex icon).
"""

import pathlib

import numpy as np
from PIL import Image
from scipy import ndimage

ROOT = pathlib.Path(__file__).resolve().parents[3]
RAW = ROOT / "assets/concepts/blocky/ui/shop"
OUT = pathlib.Path(__file__).resolve().parent / "icons"
SIZE = 256
PAD = 0.06

SHEETS = {
    "bows": ["TwigBow", "AcornBow", "FireflyBow", "MossSlimeBow", "EmberFangBow", "GladeSpiritBow"],
    "staffs": ["BranchStaff", "ToadstoolStaff", "LanternStaff", "HootmossStaff", "SlimeCrownStaff", "WorldrootStaff"],
    "blades": ["TimberBlade", "MossstoneBlade", "ThornBlade", "BroodsplitBlade", "EmberfangBlade", "GladeheartBlade"],
    "ui": ["CrateMossyGlade", "Coin", "Gem", "RoyalJelly", "BroodSilk", "Lock"],
}


def key_out(img: Image.Image) -> Image.Image:
    rgb = np.asarray(img.convert("RGB")).astype(np.float32)
    r, g, b = rgb[..., 0], rgb[..., 1], rgb[..., 2]
    key = np.minimum(r, b) - g
    near = key > 110
    labels, _ = ndimage.label(near)
    border = np.unique(np.concatenate([labels[0], labels[-1], labels[:, 0], labels[:, -1]]))
    bg = np.isin(labels, border[border > 0]) | (key > 170)
    edge = ndimage.binary_dilation(bg, iterations=2) & ~bg
    alpha = np.where(bg, 0.0, 1.0)
    alpha[edge] = 0.85
    # pull the magenta out of the edge pixels
    out = rgb.copy()
    spill = np.clip(key, 0, None)[..., None] * 0.6
    out[edge] = np.clip(out[edge] - np.concatenate([spill, np.zeros_like(spill), spill], -1)[edge], 0, 255)
    rgba = np.dstack([out, alpha * 255]).astype(np.uint8)
    return Image.fromarray(rgba, "RGBA")


def main_shape(cell: Image.Image) -> Image.Image:
    """Only the cell's own icon: its largest shape and whatever lies close
    round it (a gem's sparkles), not a sliver of the neighbouring icon at
    the cell's edge (Codex's grid is not exactly even)."""
    arr = np.asarray(cell).copy()
    solid = arr[..., 3] > 40
    labels, count = ndimage.label(solid)
    if count <= 1:
        return cell
    sizes = ndimage.sum(solid, labels, range(1, count + 1))
    biggest = int(np.argmax(sizes)) + 1
    ys, xs = np.nonzero(labels == biggest)
    margin = int(max(cell.size) * 0.08)
    y0, y1, x0, x1 = ys.min() - margin, ys.max() + margin, xs.min() - margin, xs.max() + margin
    keep = np.zeros(count + 1, bool)
    for index, region in enumerate(ndimage.find_objects(labels), start=1):
        if region is None:
            continue
        ry, rx = region
        inside = ry.start >= y0 and ry.stop <= y1 and rx.start >= x0 and rx.stop <= x1
        keep[index] = inside
    arr[..., 3] = np.where(keep[labels], arr[..., 3], 0)
    return Image.fromarray(arr, "RGBA")


def main() -> None:
    OUT.mkdir(exist_ok=True)
    for sheet, names in SHEETS.items():
        img = key_out(Image.open(RAW / f"{sheet}_raw.png"))
        w, h = img.size
        cw, ch = w // 3, h // 2
        for i, name in enumerate(names):
            cell = img.crop(((i % 3) * cw, (i // 3) * ch, (i % 3 + 1) * cw, (i // 3 + 1) * ch))
            cell = main_shape(cell)
            box = cell.getchannel("A").point(lambda a: 255 if a > 40 else 0).getbbox()
            if box:
                cell = cell.crop(box)
            side = int(max(cell.size) * (1 + 2 * PAD))
            square = Image.new("RGBA", (side, side), (0, 0, 0, 0))
            square.paste(cell, ((side - cell.size[0]) // 2, (side - cell.size[1]) // 2))
            square.resize((SIZE, SIZE), Image.LANCZOS).save(OUT / f"{name}.png")
            print(name)


if __name__ == "__main__":
    main()
