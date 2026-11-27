"""Codex draws the Robux store's icons (rule 9).

    python -I draw.py           the sheet: icons.txt -> icons_raw.png
    python -I draw.py luck      one icon: luck.txt -> luck_raw.png (the Mossy Egg alone as reference)
"""
import re
import shutil
import subprocess
import sys
from pathlib import Path

HERE = Path(__file__).resolve().parent
ROOT = HERE.parents[3]
GENERATED = Path.home() / ".codex" / "generated_images"
REFS = [
    ROOT / "assets/ui/shop/icons/CoinArrow.png",
    ROOT / "assets/ui/shop/icons/Gem.png",
    ROOT / "assets/ui/reveal/design/egg_MossyGlade.png",
    ROOT / "assets/concepts/blocky/pets/forest/01_mosslet_views.png",
]

NAME = sys.argv[1] if len(sys.argv) > 1 else "icons"
if NAME != "icons":
    REFS = [ROOT / "assets/ui/reveal/design/egg_MossyGlade.png"]

args = ["codex", "exec", "--skip-git-repo-check", "-s", "read-only"]
for ref in REFS:
    args += ["-i", str(ref)]
args.append("-")
body = (HERE / f"{NAME}.txt").read_text(encoding="utf-8")
done = subprocess.run(args, input=body, capture_output=True, text=True, encoding="utf-8", shell=True)
log = done.stdout + done.stderr
(HERE / f"{NAME}.log").write_text(log, encoding="utf-8")
match = re.search(r"session id: ([0-9a-f-]+)", log)
images = sorted((GENERATED / match.group(1)).glob("*.png")) if match else []
if images:
    shutil.copy(images[-1], HERE / f"{NAME}_raw.png")
    print("ok")
else:
    print(f"no image; see {NAME}.log")
