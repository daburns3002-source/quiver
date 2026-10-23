"""Small, flat-shaded primitives for Roblox. Y is up; faces look down -Z.

Colours are sRGB hex strings. Rotation is XYZ Euler angles in radians.
Primitives return meshes; export groups them by Body / Eyes / Glow / Gold.
"""
from pathlib import Path
import itertools

import numpy as np
import trimesh


def _mesh(vertices, polygons, colour, name, centre=(0, 0, 0), rotation=None):
    vertices = np.asarray(vertices, dtype=float)
    triangles = []
    for polygon in polygons:
        for i in range(1, len(polygon) - 1):
            triangles.append(vertices[[polygon[0], polygon[i], polygon[i + 1]]])
    points = np.asarray(triangles).reshape(-1, 3)
    if rotation is not None:
        matrix = trimesh.transformations.euler_matrix(*rotation)[:3, :3]
        points = points @ matrix.T
    points += np.asarray(centre)
    mesh = trimesh.Trimesh(points, np.arange(len(points)).reshape(-1, 3), process=False)
    rgb = [int(colour.lstrip("#")[i:i + 2], 16) for i in (0, 2, 4)]
    # Match optimise_enemy.py: byte sRGB ColorVisuals, no texture material.
    mesh.visual = trimesh.visual.ColorVisuals(
        mesh, vertex_colors=np.tile(np.array([*rgb, 255], dtype=np.uint8), (len(points), 1)))
    mesh.metadata["part"] = name
    return mesh


def bevelled_box(centre, size, bevel, colour, name="Body", rotation=None):
    """A box with planar edge chamfers and triangular corner facets."""
    half = np.asarray(size, dtype=float) / 2
    if bevel <= 0 or bevel >= min(half):
        raise ValueError("bevel must be positive and smaller than every half-size")
    vertices = []
    for signs in itertools.product((-1, 1), repeat=3):
        for axis in range(3):
            point = half - bevel
            point[axis] = half[axis]
            vertices.append(point * signs)
    vertices = np.asarray(vertices)
    polygons = []
    # Supporting planes: faces, edges, then corners. Sort each outward.
    for normal in itertools.product((-1, 0, 1), repeat=3):
        normal = np.asarray(normal, dtype=float)
        if not normal.any():
            continue
        dots = vertices @ normal
        ids = np.flatnonzero(np.isclose(dots, dots.max()))
        if len(ids) < 3:
            continue
        n = normal / np.linalg.norm(normal)
        u = vertices[ids[0]] - vertices[ids].mean(0)
        u /= np.linalg.norm(u)
        v = np.cross(n, u)
        offsets = vertices[ids] - vertices[ids].mean(0)
        polygons.append(ids[np.argsort(np.arctan2(offsets @ v, offsets @ u))])
    return _mesh(vertices, polygons, colour, name, centre, rotation)


def box(centre, size, colour, name="Body", rotation=None):
    """A plain box, with independent vertices on every triangle."""
    source = trimesh.creation.box(extents=size)
    return _mesh(source.vertices, source.faces, colour, name, centre, rotation)


def prism(centre, outline, depth, colour, name="Body", rotation=None):
    """Extrude a convex XY outline along Z; outline must be counterclockwise."""
    count = len(outline)
    vertices = [(x, y, z) for z in (-depth / 2, depth / 2) for x, y in outline]
    polygons = [list(reversed(range(count))), list(range(count, 2 * count))]
    polygons += [[i, (i + 1) % count, (i + 1) % count + count, i + count]
                 for i in range(count)]
    return _mesh(vertices, polygons, colour, name, centre, rotation)


def wedge(centre, size, colour, name="Body", rotation=None):
    """A triangular prism with a sloping top."""
    x, y, z = np.asarray(size) / 2
    return prism(centre, [(-x, -y), (x, -y), (-x, y)], 2 * z, colour, name, rotation)


def decal(centre, size, colour, name="Eyes", rotation=None):
    """A flat XY quad, outward normal -Z; offset it slightly from its host."""
    x, y = np.asarray(size) / 2
    return _mesh([(-x, -y, 0), (-x, y, 0), (x, y, 0), (x, -y, 0)],
                 [[0, 1, 2, 3]], colour, name, centre, rotation)


def export(parts, path):
    """Write one named mesh per material role, using the enemy GLB format."""
    groups = {}
    for part in parts:
        name = part.metadata["part"]
        if name not in {"Body", "Eyes", "Glow", "Gold"}:
            raise ValueError(f"unknown part role: {name}")
        groups.setdefault(name, []).append(part)
    scene = trimesh.Scene()
    counts = {}
    for name, meshes in groups.items():
        mesh = trimesh.util.concatenate(meshes)
        ranges, start = [], 0
        for part in meshes:
            stop = start + len(part.faces)
            ranges.append([start, stop, part.metadata.get("animation_group", "body")])
            start = stop
        mesh.metadata["animation_groups"] = ranges
        scene.add_geometry(mesh, node_name=name, geom_name=name)
        counts[name] = len(mesh.faces)
    Path(path).parent.mkdir(parents=True, exist_ok=True)
    scene.export(str(path), include_normals=True)
    return counts


def load_meshes(path_glb):
    """Load world-space geometry, preserving GLB mesh extras for animation."""
    scene = trimesh.load(str(path_glb), process=False, force="scene")
    meshes = []
    for node in scene.graph.nodes_geometry:
        transform, key = scene.graph[node]
        mesh = scene.geometry[key].copy()
        mesh.apply_transform(transform)
        mesh.metadata["name"] = key
        meshes.append(mesh)
    return meshes


def draw_meshes(ax, meshes, azimuth=-55, elevation=18, centre=(0, .8, 0), radius=1.2):
    """Orthographic painter: sort ALL triangles far to near for this camera.

    Camera depth increases toward the viewer. No strokes or antialiasing on
    individual polygons: coplanar triangles must not acquire diagonal seams.
    """
    from matplotlib.collections import PolyCollection

    az, el = np.radians([azimuth, elevation])
    toward = np.array([np.cos(el)*np.cos(az), np.sin(el), np.cos(el)*np.sin(az)])
    # a camera looking along -toward with +Y up (the old cross product pointed up down)
    right = np.cross(-toward, [0, 1, 0])
    right /= np.linalg.norm(right)
    up = np.cross(right, -toward)
    light = np.array([-.5, .85, -.7])
    light /= np.linalg.norm(light)
    triangles, colours = [], []
    biases = []
    for mesh in meshes:
        # back faces are never seen; dropping them removes most sort mistakes
        front = mesh.face_normals @ toward > 1e-6
        triangles.append(mesh.triangles[front])
        rgb = mesh.visual.vertex_colors[mesh.faces[front], :3].mean(1) / 255
        shade = .62 + .38 * np.maximum(mesh.face_normals[front] @ light, 0)
        colours.append(np.clip(rgb * shade[:, None], 0, 1))
        # face decals sit on large body faces whose centroids can sort nearer
        bias = .25 if mesh.metadata.get("name") == "Eyes" else 0
        biases.append(np.full(front.sum(), bias))
    triangles = np.concatenate(triangles) - np.asarray(centre)
    depth = triangles.mean(axis=1) @ toward + np.concatenate(biases)
    order = np.argsort(depth, kind="stable")
    projected = np.stack((triangles @ right, triangles @ up), axis=-1)
    ax.add_collection(PolyCollection(projected[order],
        facecolors=np.concatenate(colours)[order], edgecolors="none",
        linewidths=0, antialiaseds=False))
    ax.set_xlim(-radius, radius)
    ax.set_ylim(-radius, radius)
    ax.set_aspect("equal")
    ax.set_axis_off()


def render_frame(meshes, label, centre=(0, 1.05, 0), radius=1.45, pixels=480):
    """Return a Pillow image using the same renderer as the static preview."""
    import matplotlib
    matplotlib.use("Agg")
    import matplotlib.pyplot as plt
    from PIL import Image

    fig, ax = plt.subplots(figsize=(pixels / 100, pixels / 100), dpi=100)
    fig.patch.set_facecolor("#e4e4e4")
    draw_meshes(ax, meshes, centre=centre, radius=radius)
    ax.text(.03, .95, label, transform=ax.transAxes, weight="bold", va="top")
    fig.subplots_adjust(left=0, right=1, bottom=0, top=1)
    fig.canvas.draw()
    result = Image.fromarray(np.asarray(fig.canvas.buffer_rgba()).copy()).convert("RGB")
    plt.close(fig)
    return result


def render_preview(path_glb, path_png):
    """Headless four-view inspection, lit from above and in front."""
    import matplotlib
    matplotlib.use("Agg")
    import matplotlib.pyplot as plt
    meshes = load_meshes(path_glb)
    bounds = np.array([m.bounds for m in meshes])
    low, high = bounds[:, 0].min(0), bounds[:, 1].max(0)
    centre, radius = (low + high) / 2, max(high - low) * .58
    fig = plt.figure(figsize=(16, 4.6), facecolor="#e4e4e4")
    for index, (label, azimuth) in enumerate([
            ("FRONT", -90), ("THREE-QUARTER", -55),
            ("RIGHT SIDE", 0), ("BACK", 90)]):
        ax = fig.add_subplot(1, 4, index + 1)
        ax.set_facecolor("#e4e4e4")
        draw_meshes(ax, meshes, azimuth, 12 if index != 1 else 18, centre, radius)
        ax.text(.5, .015, label, transform=ax.transAxes, ha="center", weight="bold")
    fig.subplots_adjust(left=0, right=1, bottom=0, top=1, wspace=0)
    fig.savefig(str(path_png), dpi=160, facecolor=fig.get_facecolor())
    plt.close(fig)
