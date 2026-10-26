"""Cuts the story cutscene's Codex frames
(assets/concepts/blocky/ui/story/raw/<frame>.png, 1536 x 1024, drawn by
frames.py) to their middle 16:9 band, kept as frames/<frame>.jpg, and into two
halves under Roblox's 1024 px image limit, overlapping by OVERLAP px, in
halves/ (not kept: upload them, then the ids go in `Config/Story.pictures`).
`Config/Story.picture` places them by the same numbers.

    python -I assets/ui/story/cut.py
"""

import re
from pathlib import Path

from PIL import Image

HERE = Path(__file__).resolve().parent
RAW = HERE.parents[1] / "concepts" / "blocky" / "ui" / "story" / "raw"
WIDTH, HEIGHT = 1536, 864
OVERLAP = 8


def main() -> None:
    (HERE / "frames").mkdir(exist_ok=True)
    (HERE / "halves").mkdir(exist_ok=True)
    half = (WIDTH + OVERLAP) // 2
    for source in sorted(p for p in RAW.glob("f*.png") if re.fullmatch(r"f\d\d[a-d]?", p.stem)):
        image = Image.open(source).convert("RGB")
        if image.size != (WIDTH, 1024):
            image = image.resize((WIDTH, round(image.height * WIDTH / image.width)), Image.LANCZOS)
        top = (image.height - HEIGHT) // 2
        band = image.crop((0, top, WIDTH, top + HEIGHT))
        band.save(HERE / "frames" / f"{source.stem}.jpg", quality=90)
        band.crop((0, 0, half, HEIGHT)).save(HERE / "halves" / f"{source.stem}_l.png")
        band.crop((WIDTH - half, 0, WIDTH, HEIGHT)).save(HERE / "halves" / f"{source.stem}_r.png")
        print(f"{source.stem}: halves {half} wide, right from x={WIDTH - half}")


if __name__ == "__main__":
    main()
