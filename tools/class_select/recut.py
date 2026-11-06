"""Re-cuts class select section pieces from an edited mockup.

    python tools/class_select/recut.py <new_mockup.png> <old_pieces_dir> <out_dir> Name [Name ...]

Each named piece (e.g. RangerM) keeps its old cut: the old piece's alpha (its
slanted section between the gold borders) and its box from `boxes.json`, so
`Config/ClassSelectAssets` keeps every box. Writes `<out_dir>/<Name>.png` and
the whole mockup as `<out_dir>/Base.jpg`.

Checks first that the gold borders did not move: along each piece's two cut
edges, the new mockup must line up with the old one (best horizontal shift 0
or 1 px). It stops otherwise, since the old cut would then slice through a
border.
"""

import json
import os
import sys

import numpy as np
from PIL import Image

OLD_MOCKUP = os.path.join(
    os.path.dirname(os.path.abspath(__file__)),
    "..", "..", "assets", "concepts", "blocky", "ui", "classes", "class_select4.png",
)


def edge_shift(old, new, xs, y):
    """The horizontal shift that best lines up row `y` of both mockups near x."""
    best, best_err = 0, None
    for dx in range(-12, 13):
        err = 0.0
        for x in xs:
            lo, hi = max(0, x - 14), min(old.shape[1], x + 15)
            a = old[y, lo:hi].astype(float)
            b = new[y, max(0, lo + dx):max(0, lo + dx) + (hi - lo)].astype(float)
            if b.shape != a.shape:
                continue
            err += float(np.abs(a - b).mean())
        if best_err is None or err < best_err:
            best, best_err = dx, err
    return best


def main():
    new_path, old_dir, out_dir, names = sys.argv[1], sys.argv[2], sys.argv[3], sys.argv[4:]
    boxes = json.load(open(os.path.join(old_dir, "boxes.json")))
    new_img = Image.open(new_path).convert("RGB")
    assert new_img.size == (1920, 1080), new_img.size
    new = np.asarray(new_img)
    old = np.asarray(Image.open(OLD_MOCKUP).convert("RGB"))
    os.makedirs(out_dir, exist_ok=True)
    bad = []
    for name in names:
        x0, y0, w, h = boxes[name]
        alpha = np.asarray(Image.open(os.path.join(old_dir, name + ".png")))[:, :, 3]
        shifts = []
        for y in range(150, 950, 100):
            cols = np.nonzero(alpha[y] > 128)[0]
            if len(cols) == 0:
                continue
            edges = [x0 + cols[0], x0 + cols[-1]]
            edges = [x for x in edges if 2 < x < 1917]
            if edges:
                shifts.append(edge_shift(old, new, edges, y0 + y))
        print(name, "border shifts", shifts)
        if any(abs(s) > 1 for s in shifts):
            bad.append(name)
        piece = np.dstack([new[y0:y0 + h, x0:x0 + w], alpha])
        Image.fromarray(piece.astype(np.uint8), "RGBA").save(os.path.join(out_dir, name + ".png"))
    new_img.save(os.path.join(out_dir, "Base.jpg"), quality=92)
    if bad:
        print("borders moved under:", bad)
        sys.exit(1)


if __name__ == "__main__":
    main()
