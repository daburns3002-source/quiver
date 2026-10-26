"""Cut the NEW ENEMY! screens' art out of Codex's images.

    python -I assets/ui/new_enemy/cutout.py

Reads assets/concepts/blocky/ui/new_enemy/ (Codex's output, kept as made):
  blank_<area>_raw.png       the owner's approved sheet for an area
                             (sheet_<area>_a.png) with its picture window,
                             name plate and description box emptied by Codex
  enemies/<enemy>_raw.png    each enemy's 2D blocky picture, on flat magenta
                             (or flat blue for the pink ones, BLUE below)
and writes assets/ui/new_enemy/art/:
  sheet_<area>_top.png, sheet_<area>_bottom.png
      the sheet's two halves, 1024 x 768 each: Roblox shrinks anything over
      1024 px, and the sheet is 1024 x 1536, so it goes up in two. The flat
      dark ground round the card is cut away and the card given a solid ink
      border instead (owner, 2026-10-25: "make sure theres a border on the
      card"), so it sits on the room as a card, not a dark rectangle
  <enemy>.png
      the enemy cut out, 512 px square, standing on the bottom edge and
      centred, so a picture box drawn on the window's ground puts its feet
      there (`Config/NewEnemies` `picture`)
"""

import pathlib

import numpy as np
from PIL import Image
from scipy import ndimage

ROOT = pathlib.Path(__file__).resolve().parents[3]
RAW = ROOT / "assets/concepts/blocky/ui/new_enemy"
OUT = pathlib.Path(__file__).resolve().parent / "art"
AREAS = ["mossy_glade", "thornwood", "drowned_village"]
# drawn on blue, because their own colours are magenta-pink
BLUE = {"burr_thistle", "bramble_lurker"}
SIZE = 512
PAD = 0.03
# the card's border: sheet pixels thick, the sheets' own ink
BORDER = 7
INK = (27, 27, 43)
# how near the sheet's dark ground a pixel must be to be cut away with it
GROUND = 34
# how wide a gap in the frame is sealed, sheet pixels
SEAL = 14


def key_out(img: Image.Image, blue: bool) -> Image.Image:
    """As `assets/ui/boss_banner/cutout.py`: key colour joined to the border
    goes, and near-pure key colour anywhere, with one soft pixel of edge."""
    rgb = np.asarray(img.convert("RGB")).astype(np.float32)
    r, g, b = rgb[..., 0], rgb[..., 1], rgb[..., 2]
    # how much of the key colour a pixel is
    key = b - np.maximum(r, g) if blue else np.minimum(r, b) - g
    near = key > 110
    labels, _ = ndimage.label(near)
    border = np.unique(np.concatenate([labels[0], labels[-1], labels[:, 0], labels[:, -1]]))
    bg = np.isin(labels, border[border > 0]) | (key > 170)
    edge = ndimage.binary_dilation(bg, iterations=2) & ~bg
    alpha = np.where(bg, 0.0, 1.0)
    alpha[edge] = np.clip(1.0 - (key[edge] - 30) / 120, 0.0, 1.0)
    spill = edge & (key > 0)
    if blue:
        rgb[..., 2][spill] = np.minimum(b[spill], np.maximum(r[spill], g[spill]) + 30)
    else:
        rgb[..., 0][spill] = np.minimum(r[spill], g[spill] + 30)
        rgb[..., 2][spill] = np.minimum(b[spill], g[spill] + 30)
    return Image.fromarray(np.dstack([rgb, alpha * 255]).astype(np.uint8), "RGBA")


def drop_specks(img: Image.Image, share: float = 0.002) -> Image.Image:
    """Clear stray specks the key left, keeping every piece of real size."""
    rgba = np.asarray(img).copy()
    labels, count = ndimage.label(rgba[..., 3] > 0)
    sizes = ndimage.sum(np.ones_like(labels), labels, range(count + 1))
    for lab in range(1, count + 1):
        if sizes[lab] < share * labels.size:
            rgba[labels == lab, 3] = 0
    return Image.fromarray(rgba, "RGBA")


def stand(img: Image.Image) -> Image.Image:
    """Crop to what is drawn, then square it with the feet on the bottom edge."""
    img = img.crop(img.getbbox())
    side = int(max(img.size) * (1 + 2 * PAD))
    square = Image.new("RGBA", (side, side), (0, 0, 0, 0))
    square.paste(img, ((side - img.width) // 2, side - img.height), img)
    return square.resize((SIZE, SIZE), Image.LANCZOS)


def card(sheet: Image.Image) -> Image.Image:
    """The sheet with the dark ground round its frame cut away, and an ink
    border round what is left: the frame and the cubes floating by it."""
    rgb = np.asarray(sheet).astype(np.float32)
    corners = np.array([rgb[4, 4], rgb[4, -5], rgb[-5, 4], rgb[-5, -5]])
    ground = np.median(corners, axis=0)
    near = np.abs(rgb - ground).max(axis=2) < GROUND
    labels, _ = ndimage.label(near)
    border = np.unique(np.concatenate([labels[0], labels[-1], labels[:, 0], labels[:, -1]]))
    outside = np.isin(labels, border[border > 0])
    # gaps between the frame's pieces sealed first, so the dark boxes inside
    # it (the Drowned Village's description) stay, then specks dropped
    inside = ndimage.binary_closing(~outside, iterations=SEAL, border_value=0)
    inside = ndimage.binary_fill_holes(inside)
    inside = ndimage.binary_opening(inside, iterations=2)
    ring = ndimage.binary_dilation(inside, iterations=BORDER) & ~inside
    out = np.zeros((*inside.shape, 4), np.uint8)
    out[..., :3] = rgb.astype(np.uint8)
    out[..., 3] = np.where(inside, 255, 0)
    out[ring] = (*INK, 255)
    return Image.fromarray(out, "RGBA")


def main() -> None:
    OUT.mkdir(exist_ok=True)
    for area in AREAS:
        sheet = Image.open(RAW / f"blank_{area}_raw.png").convert("RGB")
        assert sheet.size == (1024, 1536), (area, sheet.size)
        sheet = card(sheet)
        sheet.crop((0, 0, 1024, 768)).save(OUT / f"sheet_{area}_top.png")
        sheet.crop((0, 768, 1024, 1536)).save(OUT / f"sheet_{area}_bottom.png")
        print(f"sheet_{area}: top and bottom")
    for path in sorted((RAW / "enemies").glob("*_raw.png")):
        name = path.name.removesuffix("_raw.png")
        img = drop_specks(key_out(Image.open(path), name in BLUE))
        # how wide the creature is against how tall, for `Config/NewEnemies`
        box = img.getbbox()
        stand(img).save(OUT / f"{name}.png")
        print(f"{name}: {box[2] - box[0]} x {box[3] - box[1]}")


if __name__ == "__main__":
    main()
