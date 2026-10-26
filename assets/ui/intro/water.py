"""The title picture's water as its own layer, for the title screen's
moving water (owner, 2026-10-26: "i want the water in the river to be
moving"), and the points glints may start from.

    python -I assets/ui/intro/water.py

Reads assets/concepts/blocky/ui/intro/title.png (the approved Codex art) and
writes assets/ui/intro/title_water.png: the water's own pixels, brightened,
everything else transparent, cropped to the ponds' box. Prints the box and
a few glint spots (title pixels) for `Config/Intro.water`.
"""

import pathlib

import numpy as np
from PIL import Image
from scipy import ndimage

HERE = pathlib.Path(__file__).resolve().parent
SOURCE = HERE.parents[1] / "concepts" / "blocky" / "ui" / "intro" / "title.png"
BAND = (540, 760)  # the ponds sit between these rows


def mask(rgb: np.ndarray, loose: bool) -> np.ndarray:
    a = rgb / 255
    mx, mn = a.max(2), a.min(2)
    d = mx - mn + 1e-6
    r, g, b = a[..., 0], a[..., 1], a[..., 2]
    h = np.where(mx == r, ((g - b) / d) % 6, np.where(mx == g, (b - r) / d + 2, (r - g) / d + 4)) * 60
    s = d / (mx + 1e-6)
    m = (h > 160) & (h < 220) & (s > (0.12 if loose else 0.22)) & (mx > (0.35 if loose else 0.5))
    m[: BAND[0]] = False
    m[BAND[1] :] = False
    return m


def main() -> None:
    rgb = np.asarray(Image.open(SOURCE).convert("RGB")).astype(np.float32)
    strict = ndimage.binary_opening(mask(rgb, False), iterations=1)
    # the ponds: big strict blobs; the layer: loose water pixels near them
    lab, n = ndimage.label(ndimage.binary_closing(strict, iterations=4))
    sizes = ndimage.sum(strict, lab, range(1, n + 1))
    ponds = np.isin(lab, [i + 1 for i in range(n) if sizes[i] > 150])
    near = ndimage.binary_dilation(ponds, iterations=14)
    layer = mask(rgb, True) & near
    alpha = ndimage.gaussian_filter(layer.astype(np.float32), 1.0)
    ys, xs = np.nonzero(layer)
    x0, x1, y0, y1 = xs.min() - 4, xs.max() + 5, ys.min() - 4, ys.max() + 5
    bright = np.clip(rgb * 1.25 + 30, 0, 255)
    rgba = np.dstack([bright, np.clip(alpha, 0, 1) * 255]).astype(np.uint8)
    Image.fromarray(rgba, "RGBA").crop((x0, y0, x1, y1)).save(HERE / "title_water.png")
    print(f"box x={x0}..{x1} y={y0}..{y1}")
    sy, sx = np.nonzero(ponds & strict)
    rng = np.random.default_rng(7)
    pick = rng.choice(len(sx), size=min(24, len(sx)), replace=False)
    print("spots", sorted((int(sx[i]), int(sy[i])) for i in pick))


if __name__ == "__main__":
    main()
