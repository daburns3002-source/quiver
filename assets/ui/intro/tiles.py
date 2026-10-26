"""Cut the title pictures into tiles for Roblox (owner, 2026-10-26: "Resolution
of title screen needs to be higher"). Codex cannot draw one image larger than
about 1672 px, so each approved picture is enlarged 2x (Lanczos, then a light
unsharp mask) and cut into a grid of tiles no larger than 1024 px, Roblox's
limit, so every pixel is shown. `Config/Intro.pictures` lists the tiles in
row order with the grid.

    python -I assets/ui/intro/tiles.py

Writes assets/ui/intro/tiles/<name>_<row>_<col>.png.
"""

import pathlib

from PIL import Image, ImageFilter

HERE = pathlib.Path(__file__).resolve().parent
ART = HERE.parents[1] / "concepts" / "blocky" / "ui" / "intro"
OUT = HERE / "tiles"
SCALE = 2
# name: (source, columns, rows)
PICTURES = {
    "title": ("title.png", 4, 2),
    "portrait": ("title_portrait.png", 2, 4),
}


def main() -> None:
    OUT.mkdir(exist_ok=True)
    for name, (source, cols, rows) in PICTURES.items():
        im = Image.open(ART / source).convert("RGB")
        w, h = im.size
        big = im.resize((w * SCALE, h * SCALE), Image.LANCZOS)
        big = big.filter(ImageFilter.UnsharpMask(radius=1.6, percent=60, threshold=2))
        W, H = big.size
        for r in range(rows):
            for c in range(cols):
                box = (W * c // cols, H * r // rows, W * (c + 1) // cols, H * (r + 1) // rows)
                tile = big.crop(box)
                assert max(tile.size) <= 1024, (name, tile.size)
                tile.save(OUT / f"{name}_{r + 1}_{c + 1}.png")
        print(name, (w, h), "->", (W, H), f"{cols}x{rows} tiles")


if __name__ == "__main__":
    main()
