"""Slim a Claude Design weapon to a Roblox budget, as optimise_enemy.py does
for enemies.

    uv run --with trimesh --with numpy --with pymeshlab --with scipy \
        --with pillow python -I optimise_weapon.py <in> <out> <weapon>

Vertex colours are kept (COLOR_0, linear to sRGB) or textures sampled onto
vertices. Each part is decimated to its budget, then parts are merged into
a few named groups so the game can treat them apart (the gem glows; the
arrow is drawn on its own). Centred on its bounds; not turned, since how a
weapon is held is the game's to decide.
"""
import sys

import numpy as np
import pymeshlab
import trimesh

SRC, OUT, WEAPON = sys.argv[1], sys.argv[2], sys.argv[3]

WEAPONS = {
    # The Ranger's bow (owner's Claude Design model, 67.5k triangles).
    # group: { part: triangle budget }
    "leaf_bow": {
        "Bow": {"Limb_Upper": 700, "Limb_Lower": 700, "Riser": 800, "Grip": 700},
        "Trim": {"Gold_Trim": 900, "Gold_Trim_Upper": 260, "Gold_Trim_Lower": 260},
        "Leaves": {"Leaf_Upper": 600, "Leaf_Lower": 600, "Leaf_Wrap_Upper": 260, "Leaf_Wrap_Lower": 260},
        "Gem": {"Gem": 200},
        "String": {"String_Upper": 24, "String_Lower": 24},
        "Arrow": {"Shaft": 112, "Arrowhead": 8, "Fletching": 300, "Nock": 136, "Arrow_Wraps": 160},
    },
    # The Arcanist's staff (owner's Claude Design model, 86.8k triangles).
    # The orb and gems glow; the ring of orbiting orbs is one mesh, so the
    # game can spin it round the head.
    "arcane_staff": {
        "Staff": {"Shaft": 900, "Spiral": 700, "Head_Cup": 1200},
        "Trim": {"Silver_Trim": 1600},
        "Gems": {"Gems": 600},
        "Orb": {"Orb": 700},
        "Orbits": {"Orbit_Ring": 500, "Orbit_Orb_1": 250, "Orbit_Orb_2": 250, "Orbit_Orb_3": 250},
    },
}

#: The blocky skins (docs/PETS-FOREST.md), Claude Design models of a few
#: hundred to a few thousand triangles whose colours are flat materials.
#: Nothing is decimated: parts are grouped by the start of their node name
#: (trimesh adds a suffix per material, and a group claims what an earlier
#: one left), and `turn` (degrees about Y) puts the model in the game's
#: weapon frame as Studio imports it: long axis up, a bow's string behind
#: (−Z) and its arrow pointing +Z.
BLOCKY = {
    "twig_bow": {
        "turn": 90,
        "groups": {
            "Bow": ["limbs", "grip_", "band_", "nock_knot_", "string_wrap_"],
            "Leaves": ["leaf_"],
            "String": ["string"],
        },
    },
    "branch_staff": {
        "turn": 0,
        "groups": {
            "Staff": ["spike", "collar_", "shaft", "arm_"],
            "Leaves": ["leaf_"],
            "Gems": ["gem_plate_"],
            "Stone": ["stone_cube"],
        },
    },
    "timber_blade": {
        "turn": 0,
        "groups": {
            "Gems": ["guard_gem_front", "guard_gem_back", "pommel_gem_"],
            "Blade": ["blade_"],
            "Guard": ["guard_", "collar_upper"],
            "Grip": ["grip_", "band_pommel", "pommel"],
        },
    },
}

scene = trimesh.load(SRC, process=False)


def linear_to_srgb(lin):
    lin = np.clip(np.asarray(lin, dtype=np.float64), 0, 1)
    return np.where(lin <= 0.0031308, lin * 12.92, 1.055 * np.power(lin, 1 / 2.4) - 0.055)


def world(node):
    T, gname = scene.graph[node]
    src = scene.geometry[gname]
    colour = getattr(src.visual, "vertex_attributes", {}).get("color")
    material = getattr(src.visual, "material", None)
    if colour is not None:
        srgb = linear_to_srgb(np.asarray(colour, dtype=np.float64)[:, :3])
    elif material is not None and getattr(material, "baseColorTexture", None) is None and hasattr(
        material, "baseColorFactor"
    ):
        # a flat material: its factor is linear, 0-255 as trimesh holds it
        base = np.asarray(material.baseColorFactor, dtype=np.float64)[:3] / 255.0
        srgb = np.tile(linear_to_srgb(base), (len(src.vertices), 1))
    else:
        srgb = np.asarray(src.visual.to_color().vertex_colors, dtype=np.float64)[:, :3] / 255.0
    g = trimesh.Trimesh(vertices=trimesh.transform_points(src.vertices, T), faces=src.faces, process=False)
    return g, srgb


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


parts = {n: world(n) for n in scene.graph.nodes_geometry}
groups = {}
claimed = set()


def coloured(g, srgb):
    out = g.copy()
    out.visual = trimesh.visual.ColorVisuals(out, vertex_colors=(np.clip(srgb, 0, 1) * 255).astype(np.uint8))
    return out


if WEAPON in BLOCKY:
    spec = BLOCKY[WEAPON]
    for group, prefixes in spec["groups"].items():
        pieces = []
        for name, (g, srgb) in parts.items():
            if name not in claimed and any(name.startswith(p) for p in prefixes):
                pieces.append(coloured(g, srgb))
                claimed.add(name)
        groups[group] = trimesh.util.concatenate(pieces)
        print(f"{group:8s} {len(pieces):3d} pieces {len(groups[group].faces):5d} tris")
    turn = trimesh.transformations.rotation_matrix(np.radians(spec["turn"]), [0, 1, 0])
    for mesh in groups.values():
        mesh.apply_transform(turn)
for group, members in ({} if WEAPON in BLOCKY else WEAPONS[WEAPON]).items():
    pieces = []
    for name, budget in members.items():
        g, srgb = parts[name]
        slim = decimate(g, srgb, budget)
        print(f"{group:8s} {name:18s} {len(g.faces):6d} -> {len(slim.faces):5d}")
        pieces.append(slim)
        claimed.add(name)
    groups[group] = trimesh.util.concatenate(pieces)
for name in parts:
    if name not in claimed:
        print("dropped", name)

lo, hi = trimesh.util.concatenate(list(groups.values())).bounds
centre = (lo + hi) / 2
out = trimesh.Scene()
for name, mesh in groups.items():
    mesh.apply_translation(-centre)
    out.add_geometry(mesh, node_name=name, geom_name=name)
out.export(OUT)
print("total tris", sum(len(m.faces) for m in groups.values()), {k: len(v.faces) for k, v in groups.items()})
