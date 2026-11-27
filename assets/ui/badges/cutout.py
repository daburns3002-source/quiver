"""Cut the boss badges out of Codex's flat magenta sheet.

    python -I assets/ui/badges/cutout.py

Reads assets/concepts/blocky/ui/badges/badges_a_faces_raw.png (Codex's 2x2
sheet, kept as made; the owner picked version A, faces, 2026-11-12) and writes
one 512 px badge per boss to assets/ui/badges/<area>.png, in the sheet's
order. The keying is the boss banner's (assets/ui/boss_banner/cutout.py).
"""

import importlib.util
import pathlib

from PIL import Image

HERE = pathlib.Path(__file__).resolve().parent
ROOT = HERE.parents[2]
RAW = ROOT / "assets/concepts/blocky/ui/badges/badges_a_faces_raw.png"
AREAS = ["MossyGlade", "Thornwood", "DrownedVillage", "BogheartCaverns"]

spec = importlib.util.spec_from_file_location("banner", ROOT / "assets/ui/boss_banner/cutout.py")
banner = importlib.util.module_from_spec(spec)
spec.loader.exec_module(banner)


def main() -> None:
    whole = Image.open(RAW)
    half = whole.width // 2
    for i, area in enumerate(AREAS):
        x, y = (i % 2) * half, (i // 2) * half
        cell = banner.drop_strays(banner.key_out(whole.crop((x, y, x + half, y + half))))
        made = banner.fit(cell, cell.getbbox())
        made.save(HERE / f"{area}.png", optimize=True)
        print("wrote", (HERE / f"{area}.png").relative_to(ROOT))


if __name__ == "__main__":
    main()
