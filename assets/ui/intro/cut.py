"""Cuts the intro's title picture (assets/concepts/blocky/ui/intro/title.png,
Codex, owner's pick A, 2026-10-25) into two halves under Roblox's 1024 px
image limit, overlapping by OVERLAP px so no seam shows. `Config/Intro`
places them by the same numbers.

    python -I assets/ui/intro/cut.py
"""

from pathlib import Path

from PIL import Image

HERE = Path(__file__).resolve().parent
SOURCE = HERE.parents[1] / "concepts" / "blocky" / "ui" / "intro" / "title.png"
OVERLAP = 8


def main() -> None:
    image = Image.open(SOURCE).convert("RGB")
    width, height = image.size
    half = (width + OVERLAP) // 2
    image.crop((0, 0, half, height)).save(HERE / "title_left.png")
    image.crop((width - half, 0, width, height)).save(HERE / "title_right.png")
    print(f"{width}x{height}: halves {half} wide, right from x={width - half}")


if __name__ == "__main__":
    main()
