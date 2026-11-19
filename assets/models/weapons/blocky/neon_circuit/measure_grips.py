"""Where the hand closes on each Neon Circuit weapon, and which way the bow's riser is.

    python assets/models/weapons/blocky/neon_circuit/measure_grips.py <dir of the named GLBs>

Prints `skins_to_luau.py`'s GRIPS rows: (x, how far up the length, z), x and
z as fractions of the length from the model's centre. Sampled off each
mesh's surface (a 4,000 triangle mesh has too few vertices to slice by):

- the bow's riser is the bigger of the two lumps across its middle (the
  other is the light-bar string); its side says the bow's YAW;
- the staff's shaft 43% up;
- the blade's and the dagger's handle, the narrow run between pommel and
  guard (the daggers' measure_grips.py rule).

Needs trimesh (not run with -I). The GLBs are not in git.
"""
import pathlib
import sys

import numpy as np
import trimesh


def load(path):
    scene = trimesh.load(path, process=False)
    mesh = scene.to_geometry() if hasattr(scene, "to_geometry") else scene
    points, _ = trimesh.sample.sample_surface(mesh, 150000, seed=1)
    vertices = np.asarray(mesh.vertices)
    lo, hi = vertices.min(0), vertices.max(0)
    length = hi[1] - lo[1]
    return points, (lo + hi) / 2, lo, length


def centred(points, centre, length):
    return [round(float((points[:, i].mean() - centre[i]) / length), 4) for i in (0, 2)]


def bow(path):
    points, centre, lo, length = load(path)
    up = (points[:, 1] - lo[1]) / length
    middle = points[(up >= 0.44) & (up < 0.56)]
    xs = middle[:, 0]
    # two lumps across the middle: split at the widest gap in x
    order = np.sort(xs)
    gap = int(np.argmax(np.diff(order)))
    cut = (order[gap] + order[gap + 1]) / 2
    left, right = middle[xs < cut], middle[xs >= cut]
    riser = left if len(left) > len(right) else right
    x, z = centred(riser, centre, length)
    side = "-X" if riser is left else "+X"
    print(f"  lumps: {len(left)} left, {len(right)} right, gap {order[gap + 1] - order[gap]:.3f}; riser on {side}")
    return [x, 0.5, z]


def staff(path):
    points, centre, lo, length = load(path)
    up = (points[:, 1] - lo[1]) / length
    x, z = centred(points[(up >= 0.40) & (up < 0.46)], centre, length)
    return [x, 0.43, z]


def handle(path):
    points, centre, lo, length = load(path)
    up = (points[:, 1] - lo[1]) / length
    edges = np.linspace(0, 0.6, 31)
    width = np.array([np.ptp(points[(up >= a) & (up < b), 0]) / length for a, b in zip(edges[:-1], edges[1:])])
    narrowest = width[3:20].min()
    low = int(np.argmin(width[3:20])) + 3
    guard = next(i for i in range(4, len(width)) if width[i] >= narrowest * 1.7 and i > low)
    held = [i for i in range(2, guard) if width[i] <= narrowest * 1.3]
    a, b = edges[held[0]], edges[held[-1] + 1]
    print("  widths", " ".join(f"{w:.2f}" for w in width[:20]), f"; handle {a:.2f} to {b:.2f}")
    x, z = centred(points[(up >= a) & (up < b)], centre, length)
    return [x, round(float((a + b) / 2), 4), z]


def main():
    source = pathlib.Path(sys.argv[1])
    for key, measure in (
        ("LivewireBow", bow),
        ("MainframeStaff", staff),
        ("OverclockBlade", handle),
        ("GlitchDaggers", handle),
    ):
        print(key)
        print(f'    "{key}": {tuple(measure(source / f"{key}.glb"))},')


if __name__ == "__main__":
    main()
