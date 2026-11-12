"""A sketch of the arrow coin, to show Codex where the arrow lies.

Owner, 2026-11-12: "can you make a coin that has an arrow on it?" This is
NOT the game's art (CLAUDE.md rule 9: Codex draws that). It paints the leaf
out of Codex's shop coin (`icons/Coin.png`) with the face's own gold and
blocks in an arrow on the leaf's slant; its green one is
`assets/concepts/blocky/ui/shop/coin_arrow_placement.png`, the second
reference in `coin_arrow.prompt.txt`. `coin_arrow_cutout.py` cuts the coin
Codex drew from it.

    python -I assets/ui/shop/arrow_coin.py <tone> <out.png>

`tone` is one of TONES below.
"""

import sys
from pathlib import Path

import numpy as np
from PIL import Image

HERE = Path(__file__).parent
SOURCE = HERE / "icons" / "Coin.png"

# Light, middle, dark, outline.
TONES = {
    "green": ((170, 255, 20), (52, 216, 0), (10, 160, 0), (0, 0, 0)),
    "gold": ((255, 176, 0), (226, 128, 0), (176, 88, 0), (96, 44, 0)),
    "white": ((255, 255, 255), (232, 238, 250), (176, 190, 216), (0, 0, 0)),
    "red": ((255, 120, 96), (232, 52, 44), (160, 20, 28), (0, 0, 0)),
}

# The arrow, in the picture's pixels: where its middle is, which way its
# tip points (up and to the right, as the leaf did), and its measures.
CENTRE = np.array([118.0, 122.0])
ALONG = np.array([0.734, -0.679])
ACROSS = np.array([0.679, 0.734])
HALF = 58.0
HEAD_LENGTH, HEAD_HALF = 38.0, 26.0
SHAFT_HALF = 6.5
VANE_HALF, VANE_SWEEP, VANE_LENGTH = 20.0, 14.0, 24.0
BLOCK = 4


# The leaf, with its dark outline, pale halo and shadow: an oval on its own
# slant, a little larger than it, and all of it inside the coin's face.
LEAF_CENTRE = np.array([116.5, 123.3])
LEAF_HALF = (58.0, 34.0)
PATCH = 8


def leaf_mask(a: np.ndarray) -> np.ndarray:
    ys, xs = np.mgrid[0 : a.shape[0], 0 : a.shape[1]]
    px, py = xs - LEAF_CENTRE[0], ys - LEAF_CENTRE[1]
    u = px * ALONG[0] + py * ALONG[1]
    v = px * ACROSS[0] + py * ACROSS[1]
    return (a[..., 3] > 128) & ((u / LEAF_HALF[0]) ** 2 + (v / LEAF_HALF[1]) ** 2 <= 1)


def paint_out(a: np.ndarray, mask: np.ndarray) -> np.ndarray:
    """Fills `mask` from its rim inwards with the colours beside it."""
    out = a.astype(float)
    todo = mask.copy()
    while todo.any():
        known = ~todo
        total = np.zeros_like(out[..., :3])
        count = np.zeros(todo.shape)
        for dy, dx in ((1, 0), (-1, 0), (0, 1), (0, -1)):
            k = np.roll(known, (dy, dx), (0, 1))
            total += np.roll(out[..., :3], (dy, dx), (0, 1)) * k[..., None]
            count += k
        rim = todo & (count > 0)
        if not rim.any():
            break
        out[rim, :3] = total[rim] / count[rim][:, None]
        todo &= ~rim
    # in squares, as the rest of the coin is painted
    for y in range(0, mask.shape[0], PATCH):
        for x in range(0, mask.shape[1], PATCH):
            cell = mask[y : y + PATCH, x : x + PATCH]
            if cell.any():
                block = out[y : y + PATCH, x : x + PATCH, :3]
                block[cell] = block[cell].mean(axis=0)
    return out


def in_arrow(u: np.ndarray, v: np.ndarray) -> np.ndarray:
    wide = np.abs(v)
    head = (u >= HALF - HEAD_LENGTH) & (u <= HALF) & (wide <= (HALF - u) / HEAD_LENGTH * HEAD_HALF)
    shaft = (u >= -HALF + 10) & (u <= HALF - HEAD_LENGTH) & (wide <= SHAFT_HALF)
    back = -HALF + 10 - VANE_SWEEP * wide / VANE_HALF
    vane = (wide <= VANE_HALF) & (u >= back) & (u <= back + VANE_LENGTH)
    return head | shaft | vane


def build(tone: str) -> Image.Image:
    light, middle, dark, edge = TONES[tone]
    a = np.array(Image.open(SOURCE).convert("RGBA"))
    out = paint_out(a, leaf_mask(a))

    size = a.shape[0]
    cells = size // BLOCK + 1
    ys, xs = np.mgrid[0:cells, 0:cells]
    px = (xs + 0.5) * BLOCK - CENTRE[0]
    py = (ys + 0.5) * BLOCK - CENTRE[1]
    u = px * ALONG[0] + py * ALONG[1]
    v = px * ACROSS[0] + py * ACROSS[1]
    arrow = in_arrow(u, v)
    rim = np.zeros_like(arrow)
    for dy in (-1, 0, 1):
        for dx in (-1, 0, 1):
            rim |= np.roll(arrow, (dy, dx), (0, 1))
    rim &= ~arrow

    # lit from the top left: the side of the arrow that faces it is light
    shade = np.where(v < -1.5, 0, np.where(v < 5, 1, 2))
    colours = np.array([light, middle, dark], dtype=float)
    for cy in range(cells):
        for cx in range(cells):
            box = (slice(cy * BLOCK, (cy + 1) * BLOCK), slice(cx * BLOCK, (cx + 1) * BLOCK))
            if arrow[cy, cx]:
                out[box[0], box[1], :3] = colours[shade[cy, cx]]
            elif rim[cy, cx]:
                out[box[0], box[1], :3] = edge
    return Image.fromarray(np.clip(out, 0, 255).astype(np.uint8), "RGBA")


if __name__ == "__main__":
    build(sys.argv[1]).save(sys.argv[2])
