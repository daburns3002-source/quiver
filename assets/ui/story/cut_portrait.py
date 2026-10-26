"""Cuts the story cutscene's portrait frames (raw_portrait/<frame>.png, drawn
by assets/concepts/blocky/ui/story/portrait.py) to exactly 1024 x 1536, kept as
frames_portrait/<frame>.jpg, and into a top and a bottom half under Roblox's
1024 px image limit, overlapping by OVERLAP px, in halves_portrait/ (not kept:
upload them, then the ids go in `Config/Story.portraits`). `Config/Story.portrait`
places them by the same numbers.

    python -I assets/ui/story/cut_portrait.py
"""

import re
from pathlib import Path

from PIL import Image

HERE = Path(__file__).resolve().parent
RAW = HERE.parents[1] / "concepts" / "blocky" / "ui" / "story" / "raw_portrait"
WIDTH, HEIGHT = 1024, 1536
OVERLAP = 8


def fit(image: Image.Image) -> Image.Image:
    """Scales to cover 1024 x 1536 and crops the middle."""
    scale = max(WIDTH / image.width, HEIGHT / image.height)
    size = (round(image.width * scale), round(image.height * scale))
    image = image.resize(size, Image.LANCZOS)
    left, top = (size[0] - WIDTH) // 2, (size[1] - HEIGHT) // 2
    return image.crop((left, top, left + WIDTH, top + HEIGHT))


def main() -> None:
    (HERE / "frames_portrait").mkdir(exist_ok=True)
    (HERE / "halves_portrait").mkdir(exist_ok=True)
    half = (HEIGHT + OVERLAP) // 2
    for source in sorted(p for p in RAW.glob("f*.png") if re.fullmatch(r"f\d\d[a-d]?", p.stem)):
        frame = fit(Image.open(source).convert("RGB"))
        frame.save(HERE / "frames_portrait" / f"{source.stem}.jpg", quality=90)
        frame.crop((0, 0, WIDTH, half)).save(HERE / "halves_portrait" / f"{source.stem}_t.png")
        frame.crop((0, HEIGHT - half, WIDTH, HEIGHT)).save(HERE / "halves_portrait" / f"{source.stem}_b.png")
        print(f"{source.stem}: halves {half} tall, bottom from y={HEIGHT - half}")


if __name__ == "__main__":
    main()
