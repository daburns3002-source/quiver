"""Cut each weapon's THREE-QUARTER view out of the reference sheet its 3D
model was built from (owner, 2026-10-25: "use the 2d reference sheet 3/4
view pictures that have already been created that the 3d models were
modeled off"), as the shop's icons.

    python -I assets/ui/shop/three_quarter.py

Reads assets/concepts/blocky/weapons/skins/forest/<name>_views.*, finds the
rightmost tall object in the sheet's top row (the three-quarter view, as
every sheet lays it out), keys out the light grey background, keeps the
weapon and the sparkles round it (not its label), and writes
assets/ui/shop/icons/<Weapon>.png at 256 px. A weapon with no sheet keeps
its Codex icon from cutout.py.
"""

import pathlib

import numpy as np
from PIL import Image
from scipy import ndimage

ROOT = pathlib.Path(__file__).resolve().parents[3]
SHEETS = ROOT / "assets/concepts/blocky/weapons/skins/forest"
OUT = pathlib.Path(__file__).resolve().parent / "icons"
SIZE = 256
PAD = 0.06

WEAPONS = {
    "TwigBow": "twig_bow_views.jpg",
    "FireflyBow": "firefly_bow_views.png",
    "MossSlimeBow": "moss_slime_bow_views.png",
    "EmberFangBow": "ember_fang_bow_views.png",
    "GladeSpiritBow": "glade_spirit_bow_views.png",
    "BranchStaff": "branch_staff_views.jpg",
    "ToadstoolStaff": "toadstool_staff_views.png",
    "LanternStaff": "lantern_staff_views.png",
    "HootmossStaff": "hootmoss_staff_views.png",
    "SlimeCrownStaff": "slime_crown_staff_views.png",
    "WorldrootStaff": "worldroot_staff_views.png",
    "TimberBlade": "timber_blade_views.jpg",
    "MossstoneBlade": "mossstone_blade_views.png",
    "ThornBlade": "thorn_blade_views.png",
    "BroodsplitBlade": "broodsplit_blade_views.png",
    "EmberfangBlade": "emberfang_blade_views.png",
    "GladeheartBlade": "gladeheart_blade_views.png",
}


def cut(path: pathlib.Path) -> Image.Image:
    rgb = np.asarray(Image.open(path).convert("RGB")).astype(np.float32)
    h, w, _ = rgb.shape
    border = np.concatenate([rgb[0], rgb[-1], rgb[:, 0], rgb[:, -1]])
    bg = np.median(border, axis=0)
    # how far each pixel is from the grey, and how coloured it is
    dist = np.linalg.norm(rgb - bg, axis=2)
    sat = rgb.max(axis=2) - rgb.min(axis=2)
    fg = (dist > 55) | (sat > 45)
    # the detail panels and colour swatches under the top row: the first row
    # past the middle that is mostly foreground; nothing below it counts
    cut = h
    for y in range(int(h * 0.5), h):
        # a panel's top edge or the swatch strip spans nearly the whole width
        if fg[y].mean() > 0.85:
            cut = y
            break
    fg[cut:] = False
    # objects: foreground grown a touch, so a view's pieces join up but not
    # its label, the title or the next view
    grown = ndimage.binary_dilation(fg, iterations=2)
    labels, count = ndimage.label(grown)
    best = None
    for index, region in enumerate(ndimage.find_objects(labels), start=1):
        ys, xs = region
        tall = ys.stop - ys.start
        # a top-row view: starts in the top half, at least a third of the sheet tall
        if ys.start < h * 0.5 and tall > h * 0.33 and (xs.stop - xs.start) < w * 0.5:
            centre = (xs.start + xs.stop) / 2
            if best is None or centre > best[0]:
                best = (centre, index, region)
    if best is None:
        raise SystemExit(f"no three-quarter view found in {path.name}")
    _, index, (ys, xs) = best
    main = (labels == index) & fg
    area = main.sum()
    # coloured sparkles close round it (not the black label or title)
    margin = int(max(ys.stop - ys.start, xs.stop - xs.start) * 0.08)
    y0, y1 = max(ys.start - margin, 0), ys.stop
    x0, x1 = max(xs.start - margin, 0), min(xs.stop + margin, w)
    small, n = ndimage.label(fg)
    keep = main.copy()
    for j, region in enumerate(ndimage.find_objects(small), start=1):
        if region is None:
            continue
        ry, rx = region
        if ry.start >= y0 and ry.stop <= y1 and rx.start >= x0 and rx.stop <= x1:
            piece = small == j
            if piece.sum() < area * 0.015 and sat[piece].mean() > 50:
                keep |= piece
    # no label or floor shadow: in the bottom band of the view, drop the
    # black text and the flat grey of the shadow (the weapon is coloured)
    band = ys.stop - int((ys.stop - ys.start) * 0.12)
    value = rgb.max(axis=2)
    flat = (sat < 30) & ((value < 110) | ((value < 205) & (sat < 16)))
    keep[band:] &= ~flat[band:]
    keep = ndimage.binary_opening(keep, iterations=1) | (keep & (sat > 60))
    # soft edge: a pixel's alpha by how far it is from the grey
    alpha = np.clip((dist - 18) / 30, 0, 1)
    alpha = np.where(ndimage.binary_dilation(keep, iterations=2), alpha, 0)
    alpha[keep] = np.maximum(alpha[keep], 0.9)
    rgba = np.dstack([rgb, alpha * 255]).astype(np.uint8)
    img = Image.fromarray(rgba, "RGBA").crop((x0, y0, x1, y1))
    box = img.getchannel("A").point(lambda a: 255 if a > 40 else 0).getbbox()
    return img.crop(box) if box else img


def main() -> None:
    OUT.mkdir(exist_ok=True)
    for weapon, sheet in WEAPONS.items():
        img = cut(SHEETS / sheet)
        side = int(max(img.size) * (1 + 2 * PAD))
        square = Image.new("RGBA", (side, side), (0, 0, 0, 0))
        square.paste(img, ((side - img.size[0]) // 2, (side - img.size[1]) // 2))
        square.resize((SIZE, SIZE), Image.LANCZOS).save(OUT / f"{weapon}.png")
        print(weapon)


if __name__ == "__main__":
    main()
