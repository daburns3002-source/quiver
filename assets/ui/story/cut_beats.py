"""Cuts the story beats' Codex stills
(assets/concepts/blocky/ui/story/beats_raw/<still>.png, 1536 x 1024, drawn by
beats.py) to their middle 16:9 band, kept as beats/<still>.jpg, and into two
halves under Roblox's 1024 px image limit, overlapping by OVERLAP px, in
beat_halves/ (not kept: upload them, then the ids go in
`Config/StoryBeats.pictures`). `Config/StoryBeats.picture` places them by the
same numbers as cut.py's.

    python -I assets/ui/story/cut_beats.py
"""

import re
from pathlib import Path

from PIL import Image

HERE = Path(__file__).resolve().parent
RAW = HERE.parents[1] / "concepts" / "blocky" / "ui" / "story" / "beats_raw"
WIDTH, HEIGHT = 1536, 864
OVERLAP = 8


def main() -> None:
    (HERE / "beats").mkdir(exist_ok=True)
    (HERE / "beat_halves").mkdir(exist_ok=True)
    half = (WIDTH + OVERLAP) // 2
    for source in sorted(p for p in RAW.glob("b*.png") if re.fullmatch(r"b\d[a-d]", p.stem)):
        image = Image.open(source).convert("RGB")
        if image.size != (WIDTH, 1024):
            image = image.resize((WIDTH, round(image.height * WIDTH / image.width)), Image.LANCZOS)
        top = (image.height - HEIGHT) // 2
        band = image.crop((0, top, WIDTH, top + HEIGHT))
        band.save(HERE / "beats" / f"{source.stem}.jpg", quality=90)
        band.crop((0, 0, half, HEIGHT)).save(HERE / "beat_halves" / f"{source.stem}_l.png")
        band.crop((WIDTH - half, 0, WIDTH, HEIGHT)).save(HERE / "beat_halves" / f"{source.stem}_r.png")
        print(f"{source.stem}: halves {half} wide, right from x={WIDTH - half}")


if __name__ == "__main__":
    main()
