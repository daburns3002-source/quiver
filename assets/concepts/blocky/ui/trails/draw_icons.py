"""Codex draws the trail icons and the Starfall star (rule 9). Usage: python -I draw_icons.py [name ...]"""
import re
import shutil
import subprocess
import sys
from concurrent.futures import ThreadPoolExecutor
from pathlib import Path

HERE = Path(__file__).resolve().parent
GENERATED = Path.home() / ".codex" / "generated_images"
JOBS = {
    "icons_a": ("PURE MAGENTA (#FF00FF)", "magenta or pink", ["glade_raw.png", "drowned_raw.png", "bog_raw.png"]),
    "icons_b": ("PURE GREEN (#00FF00)", "bright pure green", ["thorn_raw.png", "mythic_raw.png"]),
    "star": (None, None, []),
}


def run(name: str) -> str:
    key, keyname, refs = JOBS[name]
    body = (HERE / f"{name}.txt").read_text(encoding="utf-8")
    if key:
        common = (HERE / "_icons_common.txt").read_text(encoding="utf-8")
        body = common.replace("{KEY}", key).replace("{KEYNAME}", keyname) + "\n" + body
    args = ["codex", "exec", "--skip-git-repo-check", "-s", "read-only"]
    for ref in refs:
        args += ["-i", str(HERE / ref)]
    args.append("-")
    done = subprocess.run(args, input=body, capture_output=True, text=True, encoding="utf-8", shell=True)
    log = done.stdout + done.stderr
    (HERE / f"{name}.log").write_text(log, encoding="utf-8")
    match = re.search(r"session id: ([0-9a-f-]+)", log)
    if not match:
        return f"{name}: no session id"
    images = sorted((GENERATED / match.group(1)).glob("*.png"))
    if not images:
        return f"{name}: no image"
    shutil.copy(images[-1], HERE / f"{name}_raw.png")
    return f"{name}: ok"


if __name__ == "__main__":
    names = sys.argv[1:] or list(JOBS)
    with ThreadPoolExecutor(3) as pool:
        for line in pool.map(run, names):
            print(line, flush=True)
