"""Builds the class select mockup from the approved one plus edited sections.

    python tools/class_select/compose.py <old_pieces_dir> <out.png> <edit.png> Name [Name ...] [-- <edit2.png> Name ...]

Starts from `class_select4.png` and takes only the named sections (their old
cut, the piece alpha) from each edited picture, so a Codex edit that re-renders
the whole picture changes nothing outside the sections asked for. Space
outside every section (left of RangerM, right of AssassinF) follows the
section next to it. Then cut the pieces with `recut.py`.
"""

import json
import os
import sys

import numpy as np
from PIL import Image

HERE = os.path.dirname(os.path.abspath(__file__))
OLD = os.path.join(HERE, "..", "..", "assets", "concepts", "blocky", "ui", "classes", "class_select4.png")


def section_mask(old_dir, boxes, name):
    x0, y0, w, h = boxes[name]
    alpha = np.asarray(Image.open(os.path.join(old_dir, name + ".png")))[:, :, 3] > 128
    mask = np.zeros((1080, 1920), bool)
    mask[y0:y0 + h, x0:x0 + w] = alpha
    # the screen edge beyond the outermost sections
    for y in range(1080):
        cols = np.nonzero(mask[y])[0]
        if len(cols) == 0:
            continue
        if name == "RangerM":
            mask[y, :cols[0]] = True
        if name == "AssassinF":
            mask[y, cols[-1]:] = True
    return mask


def main():
    old_dir, out = sys.argv[1], sys.argv[2]
    boxes = json.load(open(os.path.join(old_dir, "boxes.json")))
    result = np.asarray(Image.open(OLD).convert("RGB")).copy()
    groups, current = [], None
    for arg in sys.argv[3:]:
        if arg == "--":
            current = None
        elif current is None:
            current = (arg, [])
            groups.append(current)
        else:
            current[1].append(arg)
    for edit, names in groups:
        pixels = np.asarray(Image.open(edit).convert("RGB"))
        for name in names:
            mask = section_mask(old_dir, boxes, name)
            result[mask] = pixels[mask]
            print(f"{name} from {os.path.basename(edit)}")
    Image.fromarray(result).save(out)


if __name__ == "__main__":
    main()
