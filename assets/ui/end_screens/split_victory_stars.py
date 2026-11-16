"""Cuts Victory's hero picture into the trophy and its three stars.

    python -I assets/ui/end_screens/split_victory_stars.py

`art/hero_victory.png` has three gold stars over the trophy, whatever the
win earned (the every-class run-through, 2026-11-16). This writes the same
picture with the stars taken out (`art/hero_victory_trophy.png`, same size, so
it stands where the old one did) and each star by itself
(`art/hero_star_left.png`, `_mid`, `_right`), and prints where each star sits
in the picture as shares of its width and height, for `Config/EndScreenTheme`.
`UI/EndScreen` then draws the stars itself, gold only for the ones earned.
"""

from collections import deque
from pathlib import Path

from PIL import Image

ART = Path(__file__).parent / "art"
# the stars are whole above this line of the picture; the trophy starts under it
STAR_FLOOR = 216


def components(alpha, width, height):
    """Connected pieces of the picture, as lists of (x, y)."""
    seen = bytearray(width * height)
    out = []
    for start in range(width * height):
        if seen[start] or alpha[start] < 40:
            continue
        seen[start] = 1
        queue = deque([start])
        piece = []
        while queue:
            at = queue.popleft()
            piece.append(at)
            x, y = at % width, at // width
            for nx, ny in ((x + 1, y), (x - 1, y), (x, y + 1), (x, y - 1)):
                if 0 <= nx < width and 0 <= ny < height:
                    n = ny * width + nx
                    if not seen[n] and alpha[n] >= 40:
                        seen[n] = 1
                        queue.append(n)
        out.append(piece)
    return out


def main():
    hero = Image.open(ART / "hero_victory.png").convert("RGBA")
    width, height = hero.size
    alpha = hero.getchannel("A").tobytes()
    stars = []
    for piece in components(alpha, width, height):
        ys = [at // width for at in piece]
        if len(piece) > 2000 and max(ys) < STAR_FLOOR:
            stars.append(piece)
    assert len(stars) == 3, f"found {len(stars)} stars, not 3"
    stars.sort(key=lambda piece: min(at % width for at in piece))
    trophy = hero.copy()
    pixels = trophy.load()
    for name, piece in zip(("left", "mid", "right"), stars):
        xs = [at % width for at in piece]
        ys = [at // width for at in piece]
        # a margin for the soft edge round each piece
        box = (
            max(min(xs) - 3, 0),
            max(min(ys) - 3, 0),
            min(max(xs) + 4, width),
            min(max(ys) + 4, height),
        )
        star = Image.new("RGBA", (box[2] - box[0], box[3] - box[1]), (0, 0, 0, 0))
        source = hero.load()
        target = star.load()
        own = set(piece)
        for x in range(box[0], box[2]):
            for y in range(box[1], box[3]):
                r, g, b, a = source[x, y]
                # the star's own pixels and its soft edge, never the trophy's top
                if a > 0 and (y * width + x in own or a < 40):
                    target[x - box[0], y - box[1]] = (r, g, b, a)
                    pixels[x, y] = (r, g, b, 0)
        star.save(ART / f"hero_star_{name}.png")
        print(
            name,
            star.size,
            "at",
            [round(v, 4) for v in (
                box[0] / width,
                box[1] / height,
                (box[2] - box[0]) / width,
                (box[3] - box[1]) / height,
            )],
        )
    trophy.save(ART / "hero_victory_trophy.png")
    print("trophy", trophy.size)


main()
