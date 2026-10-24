"""Bundle an arena kit's pieces (Claude Design GLBs, one per piece) into one
GLB for a single Studio import, one mesh per piece.

    uv run --with trimesh --with numpy --with scipy --with networkx --with pillow \
        python -I kit_bundle.py <kit folder> <out.glb>

Each piece arrives as many small parts with flat material colours. They are
merged into one mesh per piece, each part's colour baked onto its vertices
(Roblox draws vertex colours, as with the enemies and arenas), placed as
the piece's own scene places them. Parts that glow (an emissive material)
go in a second mesh, `<Piece>_Glow`, for the game to draw Neon. Every piece
sits centred on X/Z with its base at y = 0, in its own units; the game
scales it into the room.
"""
import pathlib
import sys

import numpy as np
import trimesh

SRC, OUT = pathlib.Path(sys.argv[1]), pathlib.Path(sys.argv[2])


def colour_of(geometry) -> np.ndarray:
    material = getattr(geometry.visual, "material", None)
    for attr in ("baseColorFactor", "main_color", "diffuse"):
        value = getattr(material, attr, None)
        if value is not None:
            c = np.asarray(value, dtype=float).ravel()[:4]
            if c.max() <= 1.0:
                c = c * 255
            if len(c) == 3:
                c = np.append(c, 255)
            return c.clip(0, 255).astype(np.uint8)
    return np.array([200, 200, 200, 255], dtype=np.uint8)


def glows(geometry) -> bool:
    material = getattr(geometry.visual, "material", None)
    emissive = getattr(material, "emissiveFactor", None)
    return emissive is not None and float(np.max(emissive)) > 0.05


bundle = trimesh.Scene()
for path in sorted(SRC.glob("*.glb")):
    piece = path.stem.split("_", 1)[-1]  # MossyGlade_WallBlock -> WallBlock
    scene = trimesh.load(path, force="scene")
    solid, glow = [], []
    for node in scene.graph.nodes_geometry:
        transform, name = scene.graph[node]
        g = scene.geometry[name].copy()
        g.apply_transform(transform)
        colour = colour_of(scene.geometry[name])
        g.visual = trimesh.visual.ColorVisuals(g, vertex_colors=np.tile(colour, (len(g.vertices), 1)))
        (glow if glows(scene.geometry[name]) else solid).append(g)
    whole = trimesh.util.concatenate(solid + glow)
    lo, hi = whole.bounds
    shift = -np.array([(lo[0] + hi[0]) / 2, lo[1], (lo[2] + hi[2]) / 2])
    for label, parts in ((piece, solid), (piece + "_Glow", glow)):
        if not parts:
            continue
        mesh = trimesh.util.concatenate(parts)
        mesh.apply_translation(shift)
        bundle.add_geometry(mesh, node_name=label, geom_name=label)
        print(f"{label}: {len(mesh.faces)} triangles, {np.round(mesh.extents, 3).tolist()}")
bundle.export(OUT)
print("wrote", OUT)
