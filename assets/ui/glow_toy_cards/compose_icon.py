"""Put a card icon Codex redrew onto its rarity tile.

    python -I assets/ui/glow_toy_cards/compose_icon.py <icon> <rarity>

Reads assets/concepts/blocky/ui/cards/<icon>_raw.png (one icon on flat
magenta, as Codex draws them; the prompt beside it), keys the magenta out
and writes icons_transparent/<icon>.png (the icon alone, 512 px, as big as
the set's) and icons/<icon>.png (the icon on tiles_blank/<rarity>.png, in
the tile's window where the set's own icons sit). <icon> is the file name
the set uses (diagonalarrows, multishot); <rarity> a tiles_blank name.

A Legendary or Mythic icon glows on its tile (CLAUDE.md rule 12): a soft
halo out of the icon's own outline, gold for a Legendary and running round
the rainbow for a Mythic.
"""

import pathlib
import sys

import colorsys

import numpy as np
from PIL import Image, ImageFilter
from scipy import ndimage

HERE = pathlib.Path(__file__).resolve().parent
RAW = HERE.parents[2] / "assets/concepts/blocky/ui/cards"
SIZE = 512
# the icon alone fills this much of its 512 px square, like the set's
ALONE = 470
# the tile's window, measured from the set's own icons: its centre and the
# largest side an icon takes in it
WINDOW_CENTRE = (258, 243)
WINDOW = 300


def key_out(img: Image.Image) -> Image.Image:
    rgb = np.asarray(img.convert("RGB")).astype(np.float32)
    r, g, b = rgb[..., 0], rgb[..., 1], rgb[..., 2]
    key = np.minimum(r, b) - g
    labels, _ = ndimage.label(key > 110)
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
    img = Image.fromarray(rgba, "RGBA")
    box = img.getchannel("A").point(lambda a: 255 if a > 40 else 0).getbbox()
    return img.crop(box) if box else img


def fitted(icon: Image.Image, side: int) -> Image.Image:
    scale = side / max(icon.size)
    return icon.resize((round(icon.size[0] * scale), round(icon.size[1] * scale)), Image.LANCZOS)


GOLD = (255, 205, 70)
HALO_BLUR = 12
HALO_STRENGTH = 0.9


def halo(icon: Image.Image, rarity: str) -> Image.Image | None:
    """The icon's glow, as big as the icon, or None for a rarity without."""
    if rarity not in ("legendary", "mythic"):
        return None
    pad = HALO_BLUR * 3
    alpha = Image.new("L", (icon.size[0] + pad * 2, icon.size[1] + pad * 2), 0)
    alpha.paste(icon.getchannel("A"), (pad, pad))
    alpha = alpha.filter(ImageFilter.MaxFilter(9)).filter(ImageFilter.GaussianBlur(HALO_BLUR))
    a = np.asarray(alpha).astype(np.float32) * HALO_STRENGTH
    h, w = a.shape
    if rarity == "mythic":
        yy, xx = np.mgrid[0:h, 0:w]
        hue = (np.arctan2(yy - h / 2, xx - w / 2) / (2 * np.pi)) % 1
        rgb = np.vectorize(lambda t: colorsys.hsv_to_rgb(t, 0.75, 1.0), otypes=[float, float, float])(hue)
        colour = np.dstack(rgb) * 255
    else:
        colour = np.ones((h, w, 3)) * np.array(GOLD)
    out = Image.fromarray(np.dstack([colour, np.clip(a, 0, 255)]).astype(np.uint8), "RGBA")
    return out


def main() -> None:
    name, rarity = sys.argv[1], sys.argv[2]
    icon = key_out(Image.open(RAW / f"{name}_raw.png"))

    alone = Image.new("RGBA", (SIZE, SIZE), (0, 0, 0, 0))
    big = fitted(icon, ALONE)
    alone.paste(big, ((SIZE - big.size[0]) // 2, (SIZE - big.size[1]) // 2))
    alone.save(HERE / "icons_transparent" / f"{name}.png")

    tile = Image.open(HERE / "tiles_blank" / f"{rarity}.png").convert("RGBA")
    small = fitted(icon, WINDOW)
    x = WINDOW_CENTRE[0] - small.size[0] // 2
    y = WINDOW_CENTRE[1] - small.size[1] // 2
    glow = halo(small, rarity)
    if glow:
        tile.alpha_composite(glow, (x - HALO_BLUR * 3, y - HALO_BLUR * 3))
    tile.alpha_composite(small, (x, y))
    tile.save(HERE / "icons" / f"{name}.png")
    print(name, rarity)


if __name__ == "__main__":
    main()
