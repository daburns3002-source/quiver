"""The story cutscene's portrait frames, for a phone held upright (owner,
2026-10-26: "make it mobile vertical resolution"): Codex reframes each final
16:9 frame (assets/ui/story/frames/<frame>.jpg) to 1024 x 1536, the same art
1:1, cropped at the sides and continued above and below. Within a shot each
frame after the first also gets the shot's previous portrait frame, so they cut
together without a jump. Shots run four at a time, frames within a shot in
order. Output: raw_portrait/<frame>.png.

    python -I assets/concepts/blocky/ui/story/portrait.py            # all
    python -I assets/concepts/blocky/ui/story/portrait.py f11 f13a   # just these
"""

import re
import shutil
import subprocess
import sys
from concurrent.futures import ThreadPoolExecutor
from pathlib import Path

HERE = Path(__file__).resolve().parent
ROOT = HERE.parents[4]
FRAMES = ROOT / "assets" / "ui" / "story" / "frames"
STORY = ROOT / "src" / "shared" / "Config" / "Story.luau"
OUT = HERE / "raw_portrait"
GENERATED = Path.home() / ".codex" / "generated_images"
WORKERS = 4

PROMPT = """Use your image generation tool to make ONE image, exactly 1024 x 1536 (portrait, taller than wide): the FIRST attached image (a 16:9 frame of a 2D blocky pixel-art cutscene) reframed for a phone held upright.

It is the SAME picture, drawn 1:1: the same characters with the same poses, faces and expressions, the same objects, words, colours, chunky pixel style, ink outlines and light. Only the framing changes: the frame's main subject and action are kept whole and fill the width; whatever falls outside at the far left and right is cropped away; and the scene is continued above (more of the same sky, canopy or background) and below (more of the same ground, grass, path) in exactly the same style, so the picture fills the tall frame. Do not add, remove, move or redraw any character, prop or word, and keep any words exactly as they are. No borders, no panels, no new text."""

FOLLOW = """

The SECOND attached image is the previous frame of the same shot, already reframed this way: match its framing exactly (the same crop, scale and position for everything that did not move), so the two frames cut together without a jump."""


def shots() -> list[list[str]]:
    src = STORY.read_text(encoding="utf-8")
    block = src[src.index("shots = {") :]
    return [re.findall(r'picture = "(\w+)"', chunk) for chunk in block.split('name = "')[1:]]


def draw(name: str, previous: str | None) -> str:
    args = ["codex", "exec", "--skip-git-repo-check", "-s", "read-only", "-i", str(FRAMES / f"{name}.jpg")]
    prompt = PROMPT
    if previous:
        args += ["-i", str(OUT / f"{previous}.png")]
        prompt += FOLLOW
    args.append("-")
    done = subprocess.run(args, input=prompt, capture_output=True, text=True, encoding="utf-8", shell=True)
    log = done.stdout + done.stderr
    (OUT / f"{name}.log").write_text(log, encoding="utf-8")
    match = re.search(r"session id: ([0-9a-f-]+)", log)
    images = sorted((GENERATED / match.group(1)).glob("*.png")) if match else []
    if not images:
        return f"{name}: no image"
    shutil.copy(images[-1], OUT / f"{name}.png")
    return f"{name}: ok"


def run_shot(frames: list[str], only: set[str]) -> list[str]:
    lines, previous = [], None
    for name in frames:
        if not only or name in only:
            lines.append(draw(name, previous))
        previous = name
    return lines


def main() -> None:
    OUT.mkdir(exist_ok=True)
    only = set(sys.argv[1:])
    with ThreadPoolExecutor(WORKERS) as pool:
        for lines in pool.map(lambda frames: run_shot(frames, only), shots()):
            for line in lines:
                print(line, flush=True)


if __name__ == "__main__":
    main()
