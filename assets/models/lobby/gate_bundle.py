"""Bundle the Endless Rift Gate (Claude Design GLB) into one GLB for a single
Studio import, as two meshes:

    uv run --with trimesh --with numpy --with scipy --with networkx --with pillow \
        python -I gate_bundle.py <endless_rift_gate.glb> <out.glb>

- `Gate`: the stone, its border and the dark veil, drawn as it is.
- `Gate_Glow`: what glows in the build (runes, the infinity sign, the
  crystals), drawn Neon.
- `Gate_Soulstone`: the floating Soulstone and its shards, apart, because Neon
  drew its lilac and purple white and pink (seen in Studio, 2026-11-19); the
  game picks its material. The build bobs it 0.035 studs, too little to see,
  so the game holds it still.

The build's `Vortex` (its turning funnel) is left out: the game draws every
portal's vortex from a sheet (`Config/Lobby.portalVortex`). Each part's
colour is baked onto its vertices (Roblox draws vertex colours), sRGB as
Roblox reads them. Every material in the build has a faint emissive, so
what glows is chosen by material name, not by emissive.

Prints each mesh's size and its middle, in studs (the gate is 20 tall), from
the middle of the gate's foot: `Config/Lobby.portalModels["Endless"]`.
"""
import pathlib
import sys

import numpy as np
import trimesh

SRC, OUT = pathlib.Path(sys.argv[1]), pathlib.Path(sys.argv[2])
HEIGHT = 20  # studs, the build's own size
GLOW = {"RiftGlow", "Crystal", "CrystalShade", "CrystalTip"}


def to_srgb(c: np.ndarray) -> np.ndarray:
    lin = c[:3].astype(float) / 255
    srgb = np.where(lin <= 0.0031308, lin * 12.92, 1.055 * np.power(lin, 1 / 2.4) - 0.055)
    return np.append((srgb * 255).round().clip(0, 255), c[3]).astype(np.uint8)


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


def material_name(geometry) -> str:
    material = getattr(geometry.visual, "material", None)
    return str(getattr(material, "name", "") or "")


scene = trimesh.load(SRC, force="scene")
parents = scene.graph.transforms.parents


def lineage(node: str) -> list[str]:
    names = []
    while node is not None:
        names.append(str(node))
        node = parents.get(node)
    return names


groups: dict[str, list] = {"Gate": [], "Gate_Glow": [], "Gate_Soulstone": []}
dropped = 0
for node in scene.graph.nodes_geometry:
    transform, name = scene.graph[node]
    line = lineage(node)
    if any(n.startswith("Vortex") for n in line):
        dropped += 1
        continue
    source = scene.geometry[name]
    material = material_name(source)
    g = source.copy()
    g.apply_transform(transform)
    g.visual = trimesh.visual.ColorVisuals(g, vertex_colors=np.tile(to_srgb(colour_of(source)), (len(g.vertices), 1)))
    if any(n == "Soulstone" for n in line) or material.startswith("Soulstone"):
        groups["Gate_Soulstone"].append(g)
    elif material in GLOW:
        groups["Gate_Glow"].append(g)
    else:
        groups["Gate"].append(g)

whole = trimesh.util.concatenate([g for parts in groups.values() for g in parts])
lo, hi = whole.bounds
shift = -np.array([(lo[0] + hi[0]) / 2, lo[1], (lo[2] + hi[2]) / 2])
scale = HEIGHT / (hi[1] - lo[1])
print(f"left out {dropped} vortex meshes; build units to studs x{scale:.4f}")
bundle = trimesh.Scene()
for label, parts in groups.items():
    if not parts:
        print(label, "EMPTY")
        continue
    mesh = trimesh.util.concatenate(parts)
    mesh.apply_translation(shift)
    bundle.add_geometry(mesh, node_name=label, geom_name=label)
    a, b = mesh.bounds
    size = np.round((b - a) * scale, 3).tolist()
    middle = np.round((a + b) / 2 * scale, 3).tolist()
    print(f"{label}: {len(mesh.faces)} triangles, size {size}, middle {middle}")
    if label == "Gate_Soulstone":
        for part in parts:
            print("   colour", part.visual.vertex_colors[0][:3].tolist())
bundle.export(OUT)
print("wrote", OUT)
