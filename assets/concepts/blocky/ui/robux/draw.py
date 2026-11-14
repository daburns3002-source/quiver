"""Codex draws the Robux store's icons (rule 9). Usage: python -I draw.py"""
import re
import shutil
import subprocess
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

args = ["codex", "exec", "--skip-git-repo-check", "-s", "read-only"]
for ref in REFS:
    args += ["-i", str(ref)]
args.append("-")
body = (HERE / "icons.txt").read_text(encoding="utf-8")
done = subprocess.run(args, input=body, capture_output=True, text=True, encoding="utf-8", shell=True)
log = done.stdout + done.stderr
(HERE / "icons.log").write_text(log, encoding="utf-8")
match = re.search(r"session id: ([0-9a-f-]+)", log)
images = sorted((GENERATED / match.group(1)).glob("*.png")) if match else []
if images:
    shutil.copy(images[-1], HERE / "icons_raw.png")
    print("ok")
else:
    print("no image; see icons.log")
