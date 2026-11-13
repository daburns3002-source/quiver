"""Codex draws the trail reference sheets (rule 9). Usage: python -I draw.py [name ...]"""
import re
import shutil
import subprocess
import sys
from concurrent.futures import ThreadPoolExecutor
from pathlib import Path

HERE = Path(__file__).resolve().parent
UI = HERE.parent
GENERATED = Path.home() / ".codex" / "generated_images"
HERO = UI / "classes" / "class_select_final.png"
SHEETS = {
    "glade": UI / "new_enemy" / "sheet_mossy_glade_a.png",
    "thorn": UI / "new_enemy" / "sheet_thornwood_a.png",
    "drowned": UI / "new_enemy" / "sheet_drowned_village_a.png",
    "bog": UI / "new_enemy" / "sheet_bogheart_caverns_a.png",
    "mythic": None,
}


def run(name: str) -> str:
    prompt = (HERE / "_common.txt").read_text(encoding="utf-8") + "\n" + (HERE / f"{name}.txt").read_text(encoding="utf-8")
    refs = [HERO] + ([SHEETS[name]] if SHEETS[name] else [])
    args = ["codex", "exec", "--skip-git-repo-check", "-s", "read-only"]
    for ref in refs:
        args += ["-i", str(ref)]
    args.append("-")
    done = subprocess.run(args, input=prompt, capture_output=True, text=True, encoding="utf-8", shell=True)
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
    names = sys.argv[1:] or list(SHEETS)
    with ThreadPoolExecutor(5) as pool:
        for line in pool.map(run, names):
            print(line, flush=True)
