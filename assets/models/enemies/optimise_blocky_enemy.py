"""Ready a blocky Claude Design enemy (assets/models/enemies/blocky/) for
Roblox, as optimise_enemy.py does for the round ones.

    uv run --with trimesh --with numpy --with pymeshlab --with scipy \
        python -I optimise_blocky_enemy.py <in.glb> <out.glb> <enemy>

The blocky models carry their colours as flat materials and their eyes as
their own glowing meshes (`Eye_L`, `Eye_R`, a baby's `Eye_Baby*`, emissive
in the file), with pupils, glints, sockets and rims beside them. Out come:

- Eyes: every glowing eye mesh, which the game draws Neon in the act's colour;
- each part an enemy lists in `separate`, under the name the game moves it
  by (the King's arms, which the Slime Lash throws);
- Body: everything else, colours on its vertices (linear to sRGB), slimmed
  to the enemy's budget when it is over it.

Turned 180 degrees about Y so the face looks down -Z, centred on X/Z with
its base at y = 0, as the round enemies are.
"""
import sys

import numpy as np
import pymeshlab
import trimesh

SRC, OUT, ENEMY = sys.argv[1], sys.argv[2], sys.argv[3]

#: Per enemy: the Body's triangle budget, and parts kept apart by node
#: name prefix -> the name the game knows them by.
ENEMIES = {
    "moss_slime": {"budget": 6000, "separate": {}},
    "mother_slime": {"budget": 6000, "separate": {}},
    "sprout_slime": {"budget": 6000, "separate": {}},
    "king_bloblin": {"budget": 9000, "separate": {"ArmL": "Arm_L", "ArmR": "Arm_R"}},
}
#: Eye pieces that are not the glow.
NOT_GLOW = ("Pupil", "Glint", "Socket", "Rim")

scene = trimesh.load(SRC, process=False)
spec = ENEMIES[ENEMY]


def linear_to_srgb(lin):
    lin = np.clip(np.asarray(lin, dtype=np.float64), 0, 1)
    return np.where(lin <= 0.0031308, lin * 12.92, 1.055 * np.power(lin, 1 / 2.4) - 0.055)


def part(node):
    """The part in world space with its colour on every vertex, and whether
    its material glows."""
    T, gname = scene.graph[node]
    src = scene.geometry[gname]
    material = getattr(src.visual, "material", None)
    colour = getattr(src.visual, "vertex_attributes", {}).get("color")
    if colour is not None:
        srgb = linear_to_srgb(np.asarray(colour, dtype=np.float64)[:, :3])
    elif material is not None and hasattr(material, "baseColorFactor") and material.baseColorFactor is not None:
        base = np.asarray(material.baseColorFactor, dtype=np.float64)[:3] / 255.0
        srgb = np.tile(linear_to_srgb(base), (len(src.vertices), 1))
    else:
        srgb = np.ones((len(src.vertices), 3))
    emissive = getattr(material, "emissiveFactor", None)
    glows = emissive is not None and float(np.max(emissive)) > 0.3
    g = trimesh.Trimesh(vertices=trimesh.transform_points(src.vertices, T), faces=src.faces, process=False)
    g.visual = trimesh.visual.ColorVisuals(g, vertex_colors=(np.clip(srgb, 0, 1) * 255).astype(np.uint8))
    return g, glows


def slim(g, budget):
    if len(g.faces) <= budget:
        return g
    colours = g.visual.vertex_colors[:, :3].astype(np.float64) / 255.0
    ms = pymeshlab.MeshSet()
    ms.add_mesh(pymeshlab.Mesh(vertex_matrix=g.vertices, face_matrix=g.faces,
                               v_color_matrix=np.hstack([colours, np.ones((len(colours), 1))])))
    ms.meshing_merge_close_vertices(threshold=pymeshlab.PercentageValue(0.01))
    ms.meshing_decimation_quadric_edge_collapse(targetfacenum=int(budget), preservenormal=True,
                                                preservetopology=False, preserveboundary=True,
                                                qualitythr=0.5, planarquadric=True)
    m = ms.current_mesh()
    out = trimesh.Trimesh(vertices=m.vertex_matrix(), faces=m.face_matrix(), process=False)
    out.visual = trimesh.visual.ColorVisuals(
        out, vertex_colors=(np.clip(m.vertex_color_matrix()[:, :3], 0, 1) * 255).astype(np.uint8))
    return out


groups = {"Body": [], "Eyes": []}
for node in scene.graph.nodes_geometry:
    g, glows = part(node)
    name = node
    target = "Body"
    for prefix, game_name in spec["separate"].items():
        if name.startswith(prefix):
            target = game_name
    if target == "Body" and name.startswith("Eye") and glows and not any(k in name for k in NOT_GLOW):
        target = "Eyes"
    groups.setdefault(target, []).append(g)

meshes = {k: trimesh.util.concatenate(v) for k, v in groups.items() if v}
meshes["Body"] = slim(meshes["Body"], spec["budget"])

turn = trimesh.transformations.rotation_matrix(np.pi, [0, 1, 0])
everything = trimesh.util.concatenate(list(meshes.values()))
everything.apply_transform(turn)
lo, hi = everything.bounds
shift = np.array([-(lo[0] + hi[0]) / 2, -lo[1], -(lo[2] + hi[2]) / 2])
out = trimesh.Scene()
for name, mesh in meshes.items():
    mesh.apply_transform(turn)
    mesh.apply_translation(shift)
    out.add_geometry(mesh, node_name=name, geom_name=name)
out.export(OUT)
print(ENEMY, {k: len(v.faces) for k, v in meshes.items()}, "size", (hi - lo).round(3).tolist())
