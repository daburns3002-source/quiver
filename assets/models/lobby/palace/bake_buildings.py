"""Bake the four palace-lobby buildings for Studio.

    uv run --with trimesh --with numpy --with scipy --with networkx --with pillow \
        python -I bake_buildings.py

Claude Design colours a model with materials, and Roblox's importer drops
those, so a raw export comes in grey (2026-11-04: all four did). This writes
`<name>_roblox.glb` beside each export: colours baked on the vertices as sRGB,
which is how Roblox reads them, in a few meshes instead of 150.

- Body, Roof and Landmark are one mesh each, so none nears the importer's limit.
- A glowing part (emissive) goes in `Glow_<rrggbb>`, one mesh per colour, for the
  game to draw Neon, because a Roblox part has one material.
- `egg_float` stays its own mesh, so the game can bob it.
- Everything keeps the model's own frame: 1 unit = 1 stud, front facing -Z.
"""

import pathlib
import re
import struct
import json

import numpy as np
import trimesh

HERE = pathlib.Path(__file__).resolve().parent
NAMES = ("dex_hall", "weapon_shop", "hatch_eggs", "your_gear")

ROOF = re.compile(r"roof|shingle|deck|ridge|eave|hip|corner|tile", re.I)
LANDMARK = re.compile(
    r"sword|blade|guard|grip|pommel|gem|chimney|rubble|broken|egg_|stand_(left|middle|right)|"
    r"helmet|visor|plume|crest|shield|landmark",
    re.I,
)
# Things whose names match the above but sit at the door, in the shop or on a sill.
GROUND = re.compile(r"prop_|interior|shelf|rack|floor|anvil|barrel|wall_shield|emblem|gable|porch", re.I)


def to_srgb(lin):
    lin = np.asarray(lin, dtype=float)
    return np.where(lin <= 0.0031308, lin * 12.92, 1.055 * np.power(lin, 1 / 2.4) - 0.055)


def group_of(name):
    if name == "egg_float" or name.startswith("egg_float"):
        return "egg_float"
    if GROUND.search(name):
        return "Body"
    if LANDMARK.search(name):
        return "Landmark"
    if ROOF.search(name):
        return "Roof"
    return "Body"


def bake(path):
    scene = trimesh.load(path, force="scene", process=False)
    parts = {}
    for node in scene.graph.nodes_geometry:
        transform, geometry_name = scene.graph[node]
        geometry = scene.geometry[geometry_name]
        material = geometry.visual.material
        base = np.asarray(material.baseColorFactor, dtype=float).ravel()
        if base.max() > 1.0:
            base = base / 255
        emissive = material.emissiveFactor
        glowing = emissive is not None and float(np.max(emissive)) > 0.05
        colour = to_srgb(base[:3])
        rgb = (colour * 255).round().clip(0, 255).astype(np.uint8)
        alpha = 255 if len(base) < 4 else int(round(base[3] * 255))
        name = str(node)
        group = "Glow_%02x%02x%02x" % tuple(rgb) if glowing else group_of(name)
        mesh = trimesh.Trimesh(
            vertices=trimesh.transform_points(geometry.vertices, transform),
            faces=geometry.faces,
            process=False,
        )
        mesh.visual = trimesh.visual.ColorVisuals(
            mesh=mesh, vertex_colors=np.tile(np.append(rgb, alpha), (len(mesh.vertices), 1))
        )
        parts.setdefault(group, []).append(mesh)

    out = trimesh.Scene()
    report = {}
    for group, meshes in sorted(parts.items()):
        merged = trimesh.util.concatenate(meshes)
        out.add_geometry(merged, node_name=group, geom_name=group)
        report[group] = len(merged.faces)
    return out, report


for stem in NAMES:
    scene, report = bake(HERE / f"{stem}.glb")
    target = HERE / f"{stem}_roblox.glb"
    scene.export(target)
    print(stem, sum(report.values()), "tris", target.stat().st_size // 1024, "KB", report)
