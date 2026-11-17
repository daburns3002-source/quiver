"""Where the hand closes on each of the Assassin's daggers.

    python assets/models/weapons/blocky/daggers/measure_grips.py <dir of the named GLBs>

A dagger's handle is the narrow run between its pommel and its guard. Reads
each model's width up its lower 60% (sampled off its surface in 2% slices:
a 4,000 triangle mesh has too few vertices to slice by), takes the handle
as the slices no wider than 1.3 times the narrowest below the guard (the
first slice 1.7 times it), and writes its middle to `grips.json` as
`skins_to_luau.py`'s `GRIPS` wants it: (x, how far up the length, z), x and
z as fractions of the length from the model's centre.

Needs trimesh (not run with -I). The GLBs are Tripo's exports as
`name_daggers_glb.py` names them; they are not in git.
"""
import json
import pathlib
import sys

import numpy as np
import trimesh

HERE = pathlib.Path(__file__).parent


def grip(path):
    scene = trimesh.load(path, process=False)
    mesh = scene.to_geometry() if hasattr(scene, "to_geometry") else scene
    points, _ = trimesh.sample.sample_surface(mesh, 150000, seed=1)
    vertices = np.asarray(mesh.vertices)
    lo, hi = vertices.min(0), vertices.max(0)
    length = hi[1] - lo[1]
    centre = (lo + hi) / 2
    up = (points[:, 1] - lo[1]) / length
    edges = np.linspace(0, 0.6, 31)
    width = np.array(
        [np.ptp(points[(up >= a) & (up < b), 0]) / length for a, b in zip(edges[:-1], edges[1:])]
    )
    narrowest = width[3:20].min()
    guard = next(i for i in range(4, len(width)) if width[i] >= narrowest * 1.7 and i > int(np.argmin(width[3:20])) + 3)
    handle = [i for i in range(2, guard) if width[i] <= narrowest * 1.3]
    a, b = edges[handle[0]], edges[handle[-1] + 1]
    fraction = (a + b) / 2
    held = points[(up >= a) & (up < b)]
    x = (held[:, 0].mean() - centre[0]) / length
    z = (held[:, 2].mean() - centre[2]) / length
    return [round(float(x), 4), round(float(fraction), 4), round(float(z), 4)], (round(float(a), 2), round(float(b), 2))


def main():
    source = pathlib.Path(sys.argv[1])
    keys = json.loads((HERE / "skin_imports.json").read_text(encoding="utf-8")).keys()
    out = {}
    for key in keys:
        out[key], span = grip(source / f"{key}.glb")
        print(f"{key:20} {out[key]}  handle {span[0]} to {span[1]}")
    (HERE / "grips.json").write_text(json.dumps(out, indent=1) + "\n", encoding="utf-8")


if __name__ == "__main__":
    main()
