"""Cut the boss icons out of Codex's flat magenta background.

    python -I assets/ui/boss_banner/cutout.py

Reads assets/concepts/blocky/boss_icons/ (Codex's output, kept as made):
  <boss>_raw.png         one portrait  -> assets/ui/boss_banner/icons/<boss>.png (512 px)
  <boss>_attack_raw.png  a 2x2 sheet of attack frames (ready, wind-up, strike,
                         follow-through) -> icons/<boss>_attack.png, 1024 px,
                         four 512 px frames, the sheet `Config/BossBanners` plays.
The frames of a sheet share one crop, so the boss stays put between them.
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


def key_out(img: Image.Image) -> Image.Image:
    rgb = np.asarray(img.convert("RGB")).astype(np.float32)
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
    return Image.fromarray(np.dstack([rgb, alpha * 255]).astype(np.uint8), "RGBA")


def drop_strays(img: Image.Image, share: float = 0.01) -> Image.Image:
    """Clear small bits touching the cell's edge: a neighbour frame's effect
    reaching over the line. The boss itself touches an edge too, but is big."""
    rgba = np.asarray(img).copy()
    labels, count = ndimage.label(rgba[..., 3] > 0)
    edge = np.unique(np.concatenate([labels[0], labels[-1], labels[:, 0], labels[:, -1]]))
    sizes = ndimage.sum(np.ones_like(labels), labels, range(count + 1))
    for lab in edge[edge > 0]:
        if sizes[lab] < share * labels.size:
            rgba[labels == lab, 3] = 0
    return Image.fromarray(rgba, "RGBA")


def fit(img: Image.Image, box: tuple[int, int, int, int]) -> Image.Image:
    """Crop to `box`, pad to a square and scale to SIZE."""
    img = img.crop(box)
    side = int(max(img.size) * (1 + 2 * PAD))
    square = Image.new("RGBA", (side, side), (0, 0, 0, 0))
    square.paste(img, ((side - img.width) // 2, (side - img.height) // 2), img)
    return square.resize((SIZE, SIZE), Image.LANCZOS)


def portrait(path: pathlib.Path) -> Image.Image:
    img = key_out(Image.open(path))
    return fit(img, img.getbbox())


def sheet(path: pathlib.Path) -> Image.Image:
    whole = Image.open(path)
    half = (whole.width // 2, whole.height // 2)
    frames = [
        drop_strays(key_out(whole.crop((x * half[0], y * half[1], (x + 1) * half[0], (y + 1) * half[1]))))
        for y in range(2)
        for x in range(2)
    ]
    boxes = [f.getbbox() for f in frames]
    union = (
        min(b[0] for b in boxes),
        min(b[1] for b in boxes),
        max(b[2] for b in boxes),
        max(b[3] for b in boxes),
    )
    out = Image.new("RGBA", (SIZE * 2, SIZE * 2), (0, 0, 0, 0))
    for i, frame in enumerate(frames):
        out.paste(fit(frame, union), ((i % 2) * SIZE, (i // 2) * SIZE))
    return out


def main() -> None:
    OUT.mkdir(exist_ok=True)
    for path in sorted(RAW.glob("*_raw.png")):
        name = path.stem.removesuffix("_raw")
        made = sheet(path) if name.endswith("_attack") else portrait(path)
        made.save(OUT / f"{name}.png", optimize=True)
        print("wrote", (OUT / f"{name}.png").relative_to(ROOT))


if __name__ == "__main__":
    main()
