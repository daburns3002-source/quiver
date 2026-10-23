"""Split the glades' merged forests into one mesh per tree, so each tree can
sway on its own in the gusts (Fx/ForestAmbience; owner, 2026-10-23).

    uv run --with trimesh --with numpy --with scipy --with networkx \
        python -I split_trees.py

Reads the `Trees` mesh of each forest's arena model (below) - one mesh of
every tree, slimmed by optimise_arena.py into many loose pieces. Each brown
piece is a trunk, one per tree; every green piece goes to the trunk nearest
it across the ground. Writes, beside this script:

- mossy_glade_trees_roblox.glb: every tree as its own mesh, named
  `<Forest>_Tree_<nn>`, in place (vertex colours kept). The owner imports it
  once in Studio (File -> Import 3D); each becomes a MeshPart.
- mossy_glade_trees.json: for each forest, the merged mesh's bounds, and for
  each tree its name, bounds centre, size and trunk base (where it sways
  from), in the model's own units. trees_to_luau.py turns that and the
  imported mesh ids into src/shared/Config/ArenaTrees.luau.
"""
import json
import pathlib

import numpy as np
import trimesh

HERE = pathlib.Path(__file__).parent

#: Forest name -> the arena model whose `Trees` mesh it is. The boss glade's
#: forest stands round every room; the log glade's runs past either side.
FORESTS = {
    "Boss": HERE / "mossy_glade_boss_roblox.glb",
    "Wide": HERE / "mossy_glade_log_roblox.glb",
}


def split(path: pathlib.Path):
    trees = trimesh.load(path, force="scene").geometry["Trees"]
    pieces = trees.split(only_watertight=False)
    colours = np.array([p.visual.vertex_colors[:, :3].astype(float).mean(0) for p in pieces])
    is_trunk = colours[:, 0] > colours[:, 1]
    trunks = [p for p, t in zip(pieces, is_trunk) if t]
    trunk_xz = np.array([p.bounds.mean(0)[[0, 2]] for p in trunks])
    groups = [[t] for t in trunks]
    for piece, trunk in zip(pieces, is_trunk):
        if trunk:
            continue
        centre = piece.bounds.mean(0)[[0, 2]]
        nearest = int(np.argmin(((trunk_xz - centre) ** 2).sum(1)))
        groups[nearest].append(piece)
    out = []
    for trunk, group in zip(trunks, groups):
        mesh = trimesh.util.concatenate(group)
        base = trunk.bounds.mean(0)
        base[1] = trunk.bounds[0][1]
        out.append((mesh, base))
    # A steady order, south-west to north-east, so names do not shuffle.
    out.sort(key=lambda m: (round(float(m[1][2]), 1), round(float(m[1][0]), 1)))
    return trees.bounds, out


def main():
    scene = trimesh.Scene()
    manifest = {}
    for forest, path in FORESTS.items():
        bounds, trees = split(path)
        entries = []
        for index, (mesh, base) in enumerate(trees, start=1):
            name = f"{forest}_Tree_{index:02d}"
            scene.add_geometry(mesh, node_name=name, geom_name=name)
            entries.append({
                "name": name,
                "centre": mesh.bounds.mean(0).round(4).tolist(),
                "size": mesh.extents.round(4).tolist(),
                "base": np.asarray(base).round(4).tolist(),
                "triangles": int(len(mesh.faces)),
            })
        manifest[forest] = {"bounds": np.asarray(bounds).round(4).tolist(), "trees": entries}
        print(forest, len(entries), "trees,", sum(e["triangles"] for e in entries), "triangles")
    scene.export(HERE / "mossy_glade_trees_roblox.glb")
    (HERE / "mossy_glade_trees.json").write_text(
        json.dumps(manifest, indent=1) + "\n", encoding="utf-8", newline="\n"
    )


main()
