"""One-dagger pictures of the daggers designed before the Assassin existed.

    python -I single_dagger_prompts.py [bogheart pictures dir]

Mossy Glade's six daggers were Claude Design models (flat colours, no
texture) and Bogheart's five were modelled as the pair in one mesh; the
owner (2026-11-16, "Yes, remake them") has all eleven remade in Tripo as ONE
dagger each, since the game holds a copy in each hand.

- Mossy Glade: writes a Codex prompt per dagger that redraws the FRONT view
  of its design sheet (`forest/<name>_views.png`) alone and large, and
  `single_daggers_2026_11_16.sh` to run them. Nothing new is designed.
- Bogheart: its pictures already show the pair side by side, so the left
  dagger is cut out and centred on the picture's own grey: the design
  itself, not a redrawing. The pictures are not in git (the main checkout's
  `bogheart/` folder), so pass the folder.
"""
import pathlib
import sys

import numpy as np
from PIL import Image

HERE = pathlib.Path(__file__).parent

FOREST = ["splinter_daggers", "bramble_shivs", "firefly_fangs", "glade_fox_claws", "ember_wilf_fangs", "glimmerhorn_daggers"]
BOGHEART = ["moss_shivs", "spore_fangs", "glowcap_kris", "toadtongue_daggers", "prism_stingers"]

PROMPT = """Generate ONE square image at the highest resolution available and save it in the current directory as {name}_single.png

Image 1 is the design sheet of one of our game's daggers: the same dagger drawn from the front, side, back, top and three-quarter, with labels, a projectile and colour swatches under it.
Redraw its FRONT view only, alone and large: exactly the same dagger, the same shapes, block sizes, colours, materials, wraps, gems and glow, the same proportions. Add nothing and leave nothing out. Keep its blocky voxel style.
View: ONE single dagger only, shown flat side-on, upright with the blade pointing up, straight-on camera, no perspective, centred, filling about 85 percent of the image. No hands, no character. This image will be turned into a 3D model.
Plain flat light-grey background, no scenery, no ground, no shadow, no text, no labels, no swatches, no projectile, no other views, no loose particles or sparkles round it. Even soft lighting.
"""


def cut_left(source: pathlib.Path, target: pathlib.Path):
    image = Image.open(source).convert("RGB")
    rgb = np.asarray(image).astype(np.int32)
    grey = np.median(rgb[:40, :40].reshape(-1, 3), axis=0)
    solid = np.abs(rgb - grey).sum(axis=-1) > 40
    columns = solid.sum(axis=0)
    width = image.size[0]
    # the emptiest column near the middle parts the pair
    middle = slice(int(width * 0.35), int(width * 0.65))
    gap = int(np.argmin(columns[middle])) + middle.start
    assert columns[gap] <= 2, (source.name, int(columns[gap]))
    left = solid[:, :gap]
    rows = np.flatnonzero(left.any(axis=1))
    cols = np.flatnonzero(left.any(axis=0))
    box = (int(cols[0]) - 6, int(rows[0]) - 6, int(cols[-1]) + 7, int(rows[-1]) + 7)
    dagger = image.crop(box)
    side = int(max(dagger.size) / 0.85)
    canvas = Image.new("RGB", (side, side), tuple(int(v) for v in grey))
    canvas.paste(dagger, ((side - dagger.size[0]) // 2, (side - dagger.size[1]) // 2))
    canvas.resize((1254, 1254), Image.LANCZOS).save(target)
    print(target.name, "gap at", gap, "dagger", dagger.size)


def main():
    lines = ["#!/usr/bin/env bash", "# Mossy Glade's six daggers, front view alone, from Codex (rule 9).", 'cd "$(dirname "$0")/forest" || exit 1']
    for name in FOREST:
        (HERE / "forest" / f"{name}_single.txt").write_text(PROMPT.format(name=name), encoding="utf-8", newline="\n")
        lines.append(f'timeout 900 codex exec -i {name}_views.png --skip-git-repo-check < {name}_single.txt 2>&1 | tail -20 > {name}_single.log; echo "=== {name} done"')
    (HERE / "single_daggers_2026_11_16.sh").write_text("\n".join(lines) + "\n", encoding="utf-8", newline="\n")
    if len(sys.argv) > 1:
        source = pathlib.Path(sys.argv[1])
        (HERE / "bogheart").mkdir(exist_ok=True)
        for name in BOGHEART:
            cut_left(source / f"{name}.png", HERE / "bogheart" / f"{name}_single.png")


if __name__ == "__main__":
    main()
