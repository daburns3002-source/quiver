"""Slim a Claude Design arena to a Roblox budget, as optimise_enemy.py does
for enemies.

    uv run --with trimesh --with numpy --with pymeshlab --with scipy \
        --with networkx --with pillow python -I optimise_arena.py <in> <out> <arena>

Every part's texture is sampled onto its vertices, since Roblox draws
vertex colours (as the enemies do). Solid pieces - ground, walls, the log,
trees - are decimated. Scattered pieces - grass tufts, clover, flowers,
ferns - are thinned first, keeping a seeded share of whole tufts, because
decimating a blade only collapses it to nothing; what is kept is then
decimated lightly. Parts are merged into a few groups, each under Roblox's
per-mesh triangle limit, and the whole sits centred on X/Z with its floor
at y = 0, unturned (an arena has no face to point).
"""
import sys
import numpy as np
import trimesh
import pymeshlab

SRC, OUT, ARENA = sys.argv[1], sys.argv[2], sys.argv[3]

# Roblox refuses a mesh over 20,000 triangles; groups stay well under.
MESH_LIMIT = 20000

ARENAS = {
    # Act 1's first area (docs/ENEMIES-AND-ARENAS.md), the owner's model.
    # part: (share of tufts kept, triangle budget for what is left). A budget
    # under 1 is instead a grid cell in studs, for flat ground (see `cluster`).
    "mossy_glade": {
        "groups": {
            "Ground": {"Ground_1": (1, 0.55), "Ground_2": (1, 0.55), "Ground_3": (1, 0.55),
                       "Ground_4": (1, 0.55), "Paths": (1, 1200), "Pebbles": (1, 600)},
            "Walls": {"Walls": (1, 5200), "WallMoss": (1, 2400)},
            "Grass": {f"Grass_{i}": (0.3, 1700) for i in range(1, 10)},
            "Groundcover": {"Clover": (0.4, 1600), "Flowers": (0.5, 2400), "Ferns": (0.7, 2000)},
            "Bushes": {"Bushes_1": (1, 2200), "Bushes_2": (1, 2200), "Bushes_3": (1, 2200),
                       "Bushes_4": (1, 900)},
            "Trees": {f"Trees_{i}": (1, 1700) for i in range(1, 7)} | {"TreeTrunks": (1, 1200)},
            "Props": {"Log": (1, 1400), "Stumps": (1, 1800), "Mushrooms": (1, 600),
                      "MushroomStems": (1, 500)},
            "Glow": {"GlowMushrooms": (1, 1600)},
        },
    },
}

settings = ARENAS[ARENA]
scene = trimesh.load(SRC, process=False)
rng = np.random.default_rng(7)


def world(node):
    """The part in world space, its texture sampled onto its vertices (sRGB)."""
    T, gname = scene.graph[node]
    src = scene.geometry[gname]
    colour = getattr(src.visual, "vertex_attributes", {}).get("color")
    if colour is not None:
        lin = np.clip(np.asarray(colour, dtype=np.float64)[:, :3], 0, 1)
        srgb = np.where(lin <= 0.0031308, lin * 12.92, 1.055 * np.power(lin, 1 / 2.4) - 0.055)
    else:
        srgb = np.asarray(src.visual.to_color().vertex_colors, dtype=np.float64)[:, :3] / 255.0
    g = trimesh.Trimesh(vertices=trimesh.transform_points(src.vertices, T), faces=src.faces, process=False)
    return g, srgb


def thin(g, srgb, share):
    """Keep a seeded `share` of the part's separate tufts, whole."""
    if share >= 1:
        return g, srgb
    welded = trimesh.Trimesh(g.vertices, g.faces, process=False)
    welded.merge_vertices()
    comps = trimesh.graph.connected_components(welded.face_adjacency, nodes=np.arange(len(g.faces)), min_len=1)
    keep = [c for c in comps if rng.random() < share]
    faces = np.concatenate(keep) if keep else np.array([], dtype=int)
    sub = g.faces[faces]
    used, inverse = np.unique(sub, return_inverse=True)
    return trimesh.Trimesh(g.vertices[used], inverse.reshape(-1, 3), process=False), srgb[used]


def decimate(g, srgb, target):
    ms = pymeshlab.MeshSet()
    ms.add_mesh(pymeshlab.Mesh(vertex_matrix=g.vertices, face_matrix=g.faces,
                               v_color_matrix=np.hstack([srgb, np.ones((len(srgb), 1))])))
    ms.meshing_merge_close_vertices(threshold=pymeshlab.PercentageValue(0.01))
    if len(g.faces) > target:
        ms.meshing_decimation_quadric_edge_collapse(targetfacenum=int(target), preservenormal=True,
                                                    preservetopology=False, preserveboundary=True,
                                                    qualitythr=0.4)
    m = ms.current_mesh()
    out = trimesh.Trimesh(vertices=m.vertex_matrix(), faces=m.face_matrix(), process=False)
    out.visual = trimesh.visual.ColorVisuals(
        out, vertex_colors=(np.clip(m.vertex_color_matrix(), 0, 1) * 255).astype(np.uint8))
    return out


def cluster(g, srgb, cell):
    """Flat ground, rebuilt on an even grid of `cell` studs. Decimating it
    folds a flat floor into a few huge triangles (one ran 14 studs), and
    since its colour lives on its vertices, the painted floor smears across
    them. An even grid keeps the paint where it was."""
    ms = pymeshlab.MeshSet()
    ms.add_mesh(pymeshlab.Mesh(vertex_matrix=g.vertices, face_matrix=g.faces,
                               v_color_matrix=np.hstack([srgb, np.ones((len(srgb), 1))])))
    ms.meshing_merge_close_vertices(threshold=pymeshlab.PercentageValue(0.01))
    ms.meshing_decimation_clustering(threshold=pymeshlab.PureValue(cell))
    m = ms.current_mesh()
    out = trimesh.Trimesh(vertices=m.vertex_matrix(), faces=m.face_matrix(), process=False)
    out.visual = trimesh.visual.ColorVisuals(
        out, vertex_colors=(np.clip(m.vertex_color_matrix(), 0, 1) * 255).astype(np.uint8))
    return out


parts = {node: world(node) for node in scene.graph.nodes_geometry}
groups = {}
claimed = set()
for group, members in settings["groups"].items():
    pieces = []
    for name, (share, budget) in members.items():
        g, srgb = parts[name]
        kept, kept_srgb = thin(g, srgb, share)
        slim = cluster(kept, kept_srgb, budget) if budget < 1 else decimate(kept, kept_srgb, budget)
        print(f"{group:12s} {name:16s} {len(g.faces):6d} -> {len(kept.faces):6d} -> {len(slim.faces):5d}")
        pieces.append(slim)
        claimed.add(name)
    groups[group] = trimesh.util.concatenate(pieces)
    assert len(groups[group].faces) < MESH_LIMIT, (group, len(groups[group].faces))

for name in parts:
    if name not in claimed:
        print("dropped", name)

# Centred on the floor (not on the trees round it); its ground is already at y = 0.
lo, hi = groups["Ground"].bounds
centre = np.array([(lo[0] + hi[0]) / 2, 0.0, (lo[2] + hi[2]) / 2])
out = trimesh.Scene()
for name, mesh in groups.items():
    mesh.apply_translation(-centre)
    out.add_geometry(mesh, node_name=name, geom_name=name)
out.export(OUT)

total = sum(len(m.faces) for m in groups.values())
print("total tris", total, "groups", {k: len(v.faces) for k, v in groups.items()})
print("bounds", np.round(trimesh.util.concatenate(list(groups.values())).bounds, 2).tolist())
