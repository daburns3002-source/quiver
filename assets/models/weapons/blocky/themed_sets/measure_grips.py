"""Where the hand closes on each themed-set weapon, and which way each bow's riser is.

    python assets/models/weapons/blocky/themed_sets/measure_grips.py <glb dir> <Key> ...

The Neon Circuit rule (`neon_circuit/measure_grips.py`) for any number of
weapons, the kind read off the key's last word (Bow, Staff, Blade,
Daggers). Prints `skins_to_luau.py`'s GRIPS rows and each bow's YAW:

- a bow's riser is the bigger of the two lumps across its middle (the
  other is its string); riser on -X is a quarter turn back, on +X forward;
- a staff's shaft 43% up;
- a blade's or dagger's handle is the narrow run below its guard: the
  longest run of slices no wider than 1.3 times the narrowest one under
  the guard, so a pommel only a little wider than the grip is left out
  when a narrower run sits above it.

Needs numpy and trimesh (not run with -I). The GLBs are not in git.
"""
import pathlib
import sys

import numpy as np
import trimesh


def load(path):
    scene = trimesh.load(path, process=False)
    mesh = scene.to_geometry() if hasattr(scene, "to_geometry") else scene
    points, _ = trimesh.sample.sample_surface(mesh, 150000, seed=1)
    # only the corners faces use: a cut piece (drop_loose_parts.py) leaves its
    # vertices behind, and Studio sizes the mesh by its faces
    vertices = np.asarray(mesh.vertices)[np.unique(np.asarray(mesh.faces))]
    lo, hi = vertices.min(0), vertices.max(0)
    return points, (lo + hi) / 2, lo, hi[1] - lo[1]


def centred(points, centre, length):
    return [round(float((points[:, i].mean() - centre[i]) / length), 4) for i in (0, 2)]


def bow(path):
    points, centre, lo, length = load(path)
    up = (points[:, 1] - lo[1]) / length
    middle = points[(up >= 0.44) & (up < 0.56)]
    order = np.sort(middle[:, 0])
    gap = int(np.argmax(np.diff(order)))
    cut = (order[gap] + order[gap + 1]) / 2
    left, right = middle[middle[:, 0] < cut], middle[middle[:, 0] >= cut]
    riser = left if len(left) > len(right) else right
    x, z = centred(riser, centre, length)
    side = "-X" if riser is left else "+X"
    note = f"riser {side} ({len(left)} left, {len(right)} right, gap {order[gap + 1] - order[gap]:.3f})"
    return [x, 0.5, z], note, ("-math.pi / 2" if side == "-X" else "math.pi / 2")


def staff(path):
    points, centre, lo, length = load(path)
    up = (points[:, 1] - lo[1]) / length
    x, z = centred(points[(up >= 0.40) & (up < 0.46)], centre, length)
    return [x, 0.43, z], "", None


def handle(path):
    points, centre, lo, length = load(path)
    up = (points[:, 1] - lo[1]) / length
    edges = np.linspace(0, 0.6, 31)
    width = np.array([np.ptp(points[(up >= a) & (up < b), 0]) / length for a, b in zip(edges[:-1], edges[1:])])
    # the guard: the first slice at least twice the narrowest below 40%
    narrowest = width[1:20].min()
    guard = next(i for i in range(2, len(width)) if width[i] >= narrowest * 2 and i > int(np.argmin(width[1:20])) + 1)
    narrow = width[1:guard].min()
    runs, run = [], []
    for i in range(0, guard):
        if width[i] <= narrow * 1.3:
            run.append(i)
        elif run:
            runs.append(run)
            run = []
    if run:
        runs.append(run)
    held = max(runs, key=len)
    a, b = edges[held[0]], edges[held[-1] + 1]
    x, z = centred(points[(up >= a) & (up < b)], centre, length)
    note = f"handle {a:.2f}-{b:.2f}, guard {edges[guard]:.2f}; widths " + " ".join(f"{w:.2f}" for w in width[: guard + 1])
    return [x, round(float((a + b) / 2), 4), z], note, None


def main():
    source = pathlib.Path(sys.argv[1])
    kinds = {"Bow": bow, "Staff": staff, "Blade": handle, "Daggers": handle}
    grips, yaws = [], []
    for key in sys.argv[2:]:
        kind = next(k for k in kinds if key.endswith(k))
        grip, note, yaw = kinds[kind](source / f"{key}.glb")
        print(f"# {key}: {note}")
        grips.append(f'    "{key}": {tuple(grip)},')
        if yaw:
            yaws.append(f'    "{key}": "{yaw}",')
    print("\n".join(grips))
    print("\n".join(yaws))


if __name__ == "__main__":
    main()
