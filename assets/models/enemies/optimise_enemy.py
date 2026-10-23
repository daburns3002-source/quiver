"""Slim a Claude Design enemy model to a Roblox enemy budget.

Usage: optimise_enemy.py <in.glb> <out.glb> <enemy>

Three meshes out: Body (jelly), Eyes (recoloured per act by the game) and
Decor (everything else). Colours become vertex colours either way: a
vertex-coloured part keeps COLOR_0 (linear -> sRGB), a textured part has
its texture sampled onto its vertices. Eye sockets are cut where the eyes
sit behind the body. Turned 180 degrees about Y so the face looks down -Z,
centred on X/Z with its base at y = 0. Per-enemy budgets and tweaks are in
ENEMIES below. First used for the Moss Slime, then the Sprout Spitter.
"""
import sys
import numpy as np
import trimesh
import pymeshlab

SRC, OUT, ENEMY = sys.argv[1], sys.argv[2], sys.argv[3]
scene = trimesh.load(SRC, process=False)

def world(node):
    """The part in world space, with its COLOR_0 carried across: a copy of a
    trimesh geometry drops visual.vertex_attributes, so the colours are read
    from the original and re-attached."""
    T, gname = scene.graph[node]
    src = scene.geometry[gname]
    colour = getattr(src.visual, "vertex_attributes", {}).get("color")
    srgb = None
    if colour is None and getattr(src.visual, "uv", None) is not None:
        # textured: sample the texture at each vertex (already sRGB)
        srgb = np.asarray(src.visual.to_color().vertex_colors, dtype=np.float64)[:, :3] / 255.0
    g = trimesh.Trimesh(vertices=trimesh.transform_points(src.vertices, T), faces=src.faces, process=False)
    g.visual = trimesh.visual.ColorVisuals(g)
    g.visual.vertex_attributes = {"color": colour, "srgb": srgb}
    return g

parts = {node: world(node) for node in scene.graph.nodes_geometry}

def colours(g):
    """COLOR_0 as sRGB 0..255. glTF stores it linear; trimesh keeps it in
    visual.vertex_attributes['color'] when the mesh also has a material."""
    attrs = getattr(g.visual, "vertex_attributes", {})
    if attrs.get("srgb") is not None:
        srgb = np.clip(attrs["srgb"], 0, 1)
        return np.hstack([srgb * 255.0, np.full((len(srgb), 1), 255.0)])
    attr = attrs.get("color")
    if attr is None:
        raise SystemExit("a part has neither COLOR_0 nor a texture - colours would be lost")
    lin = np.clip(np.asarray(attr, dtype=np.float64)[:, :3], 0, 1)
    srgb = np.where(lin <= 0.0031308, lin * 12.92, 1.055 * np.power(lin, 1 / 2.4) - 0.055)
    return np.hstack([srgb * 255.0, np.full((len(srgb), 1), 255.0)])

def decimate(g, target):
    vc = colours(g) / 255.0
    ms = pymeshlab.MeshSet()
    ms.add_mesh(pymeshlab.Mesh(vertex_matrix=g.vertices, face_matrix=g.faces, v_color_matrix=vc))
    # The export has three vertices per triangle; weld them, or nothing collapses.
    ms.meshing_merge_close_vertices(threshold=pymeshlab.PercentageValue(0.01))
    if len(g.faces) > target:
        ms.meshing_decimation_quadric_edge_collapse(targetfacenum=int(target), preservenormal=True, preservetopology=False, preserveboundary=True, qualitythr=0.4)
    m = ms.current_mesh()
    out = trimesh.Trimesh(vertices=m.vertex_matrix(), faces=m.face_matrix(), process=False)
    out.visual = trimesh.visual.ColorVisuals(out, vertex_colors=(np.clip(m.vertex_color_matrix(), 0, 1) * 255).astype(np.uint8))
    return out

def cut_sockets(body, eyes):
    """Open the body over each eye. The eyes sit just behind the jelly's
    front surface, so they only showed through it, tinted green (owner:
    "take the green in the eyes out") - and an opaque body would hide them.
    Faces of the body in front of an eye, inside its outline, are removed."""
    # the two eyes are the two halves of the Eyes mesh, split at x = mid
    mid = (eyes.vertices[:, 0].min() + eyes.vertices[:, 0].max()) / 2
    keep = np.ones(len(body.faces), dtype=bool)
    centres = body.triangles_center
    for side in (eyes.vertices[:, 0] < mid, eyes.vertices[:, 0] >= mid):
        v = eyes.vertices[side]
        lo, hi = v.min(0), v.max(0)
        cx, cy = (lo[0] + hi[0]) / 2, (lo[1] + hi[1]) / 2
        rx, ry = (hi[0] - lo[0]) / 2 * 0.92, (hi[1] - lo[1]) / 2 * 0.92
        inside = ((centres[:, 0] - cx) / rx) ** 2 + ((centres[:, 1] - cy) / ry) ** 2 < 1
        front = centres[:, 2] > lo[2]  # the face is +Z before the turn
        keep &= ~(inside & front)
    print("socket faces removed:", int((~keep).sum()))
    cut = trimesh.Trimesh(vertices=body.vertices, faces=body.faces[keep], process=False)
    cut.visual = trimesh.visual.ColorVisuals(cut)
    cut.visual.vertex_attributes = dict(body.visual.vertex_attributes)
    for k, v in list(cut.visual.vertex_attributes.items()):
        if v is not None:
            cut.visual.vertex_attributes[k] = v
    return cut

parts["Body"] = cut_sockets(parts["Body"], parts["Eyes"])

def shrink(part, factor):
    """Scale a part about the bottom of its stem, so it stays rooted in the
    moss. Owner: "take the big mushroom on the top and make it a little one"."""
    v = part.vertices
    low = v[:, 1] < v[:, 1].min() + 0.02
    base = np.array([v[low, 0].mean(), v[:, 1].min(), v[low, 2].mean()])
    part.vertices = base + (v - base) * factor

ENEMIES = {
    # The owner shrank the slime's big top mushroom ("make it a little one").
    "moss_slime": {
        "shrink": {"Mushroom_1": 0.4},
        "budget": {
            "Body": 1500, "Eyes": 300, "Eye_Catchlights": 60, "Moss": 2500, "Plants": 400,
            "Mushroom_1": 320, "Mushroom_2": 420, "Mushroom_3": 320, "Mushroom_4": 320, "Mushroom_5": 320, "Mushroom_6": 320,
        },
    },
    "sprout_spitter": {
        "shrink": {},
        "budget": {
            "Body": 1500, "Eyes": 300, "Eye_Catchlights": 72, "Moss": 2500, "Plants": 620,
            "Mushroom_1": 424, "Mushroom_2": 424, "Mushroom_3": 424, "Sprout": 708, "Spout": 544,
        },
    },
}
settings = ENEMIES[ENEMY]
for name, factor in settings["shrink"].items():
    shrink(parts[name], factor)
budget = settings["budget"]
slim = {}
for name, g in parts.items():
    if name not in budget:
        print("dropped", name, len(g.faces))
        continue
    slim[name] = decimate(g, budget[name])
    print(f"{name:16s} {len(g.faces):6d} -> {len(slim[name].faces):5d}")

body = slim["Body"]
eyes = slim["Eyes"]
decor = trimesh.util.concatenate([slim[n] for n in slim if n not in ("Body", "Eyes")])

# turn to face -Z, centre on X/Z, base at y = 0
everything = trimesh.util.concatenate([body, eyes, decor])
lo, hi = everything.bounds
centre = np.array([(lo[0] + hi[0]) / 2, lo[1], (lo[2] + hi[2]) / 2])
R = trimesh.transformations.rotation_matrix(np.pi, [0, 1, 0])
for m in (body, eyes, decor):
    m.apply_translation(-centre)
    m.apply_transform(R)

out = trimesh.Scene()
out.add_geometry(body, node_name="Body", geom_name="Body")
out.add_geometry(eyes, node_name="Eyes", geom_name="Eyes")
out.add_geometry(decor, node_name="Decor", geom_name="Decor")
out.export(OUT)
total = len(body.faces) + len(eyes.faces) + len(decor.faces)
b = trimesh.util.concatenate([body, eyes, decor]).bounds
print("total tris", total, "bounds", np.round(b, 3).tolist())
print("eyes centre z", round(float(eyes.bounds.mean(axis=0)[2]), 3), "(negative = facing -Z)")
