"""Build the boss-banner audition page (one self-contained HTML file).

    python -I assets/ui/boss_banner/build_page.py <out.html>

Embeds the cut-out icons and attack sheets (`cutout.py`) and the first 7 s of King Bloblin's
theme (its 4.7 s battle intro, cut with ffmpeg) into `page_template.html`,
so each banner plays in time with the music. The owner's picks save to the
published page's database, collection `picks`: `banner` {style},
`icons` {redo: [boss keys]}, `notes` {text}.
"""

import base64
import io
import json
import pathlib
import subprocess
import sys
import tempfile

from PIL import Image

HERE = pathlib.Path(__file__).resolve().parent
ROOT = HERE.parents[2]
THEME = ROOT / "assets/audio/music/boss_b_dive.ogg"

# Acts 1-3's bosses (docs/BOSSES.md): name, the line under it, area, act, colours
BOSSES = [
    ("boss01_king_bloblin", "King Bloblin", "Ruler of the Mossy Glade", "Mossy Glade", "Act 1 · Area 1", "#6cc24a", "#2c5a1d", True),
    ("boss02_broodmother", "The Broodmother", "Queen of the Thornwood", "Thornwood", "Act 1 · Area 2", "#7a4fd6", "#2e1d57", False),
    ("boss03_old_tollcrab", "Old Tollcrab", "Bell of the Drowned Village", "Drowned Village", "Act 2 · Area 3", "#e2673a", "#1f5552", False),
    ("boss04_grandmother_gulp", "Grandmother Gulp", "Hunger of Bogheart Caverns", "Bogheart Caverns", "Act 2 · Area 4", "#9a4fc9", "#3a1f4f", False),
    ("boss05_tempest_roc", "The Tempest Roc", "Storm of the Windswept Cliffs", "Windswept Cliffs", "Act 3 · Area 5", "#f2c230", "#1f3a7a", False),
    ("boss06_rimeheart", "Rimeheart", "the Yeti King of Frostpeak Pass", "Frostpeak Pass", "Act 3 · Area 6", "#5cc8f2", "#1d4a6e", False),
]


def icon_uri(key: str, size: int = 320) -> str:
    img = Image.open(HERE / "icons" / f"{key}.png").resize((size, size), Image.LANCZOS)
    buf = io.BytesIO()
    img.save(buf, "PNG", optimize=True)
    return "data:image/png;base64," + base64.b64encode(buf.getvalue()).decode()


def intro_b64() -> str:
    with tempfile.TemporaryDirectory() as tmp:
        out = pathlib.Path(tmp) / "intro.mp3"
        subprocess.run(
            ["ffmpeg", "-loglevel", "error", "-y", "-i", str(THEME), "-t", "7",
             "-af", "afade=t=out:st=6:d=1", "-c:a", "libmp3lame", "-b:a", "96k", str(out)],
            check=True,
        )
        return base64.b64encode(out.read_bytes()).decode()


def main() -> None:
    out = pathlib.Path(sys.argv[1])
    bosses = [
        {"key": k, "name": n, "title": t, "area": a, "act": act, "tint": tint, "deep": deep,
         "built": built, "icon": icon_uri(k), "sheet": icon_uri(k + "_attack", 640)}
        for k, n, t, a, act, tint, deep, built in BOSSES
    ]
    page = (HERE / "page_template.html").read_text(encoding="utf-8")
    page = page.replace("__BOSSES__", json.dumps(bosses)).replace("__AUDIO__", intro_b64())
    out.write_text(page, encoding="utf-8")
    print(f"wrote {out} ({out.stat().st_size // 1024} KB)")


if __name__ == "__main__":
    main()
