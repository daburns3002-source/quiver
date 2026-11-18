"""One sheet of a themed set's four front views, to show the owner.

    python -I contact_sheet.py neon_circuit

Writes `<set>/contact_sheet.jpg`: the set's pictures side by side, each
under its name.
"""
import pathlib
import sys

from PIL import Image, ImageDraw, ImageFont

HERE = pathlib.Path(__file__).parent
TILE = 640
FONT = pathlib.Path.home() / "AppData/Local/Roblox/Versions"


def font(size):
    for path in FONT.glob("*/content/fonts/FredokaOne-Regular.ttf"):
        return ImageFont.truetype(str(path), size)
    return ImageFont.load_default()


def main(folder):
    pictures = sorted(p for p in (HERE / folder).glob("*.png"))
    sheet = Image.new("RGB", (TILE * len(pictures), TILE + 70), (236, 236, 236))
    draw = ImageDraw.Draw(sheet)
    for at, path in enumerate(pictures):
        tile = Image.open(path).convert("RGB").resize((TILE, TILE), Image.LANCZOS)
        sheet.paste(tile, (at * TILE, 70))
        name = path.stem.replace("_", " ").upper()
        draw.text((at * TILE + TILE // 2, 36), name, fill=(40, 40, 48), font=font(40), anchor="mm")
    out = HERE / folder / "contact_sheet.jpg"
    sheet.save(out, quality=88)
    print(out, sheet.size)


if __name__ == "__main__":
    main(sys.argv[1])
