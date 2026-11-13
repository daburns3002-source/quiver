"""Turns a class's Claude Design figure (`<class>_<look>_set.glb`: the outfit
on a blocky avatar with skin, a face and hair) into one mesh for the class
select cards (owner, 2026-11-13: "keep the character select screen with the
class models", the remade figures, not the player's avatar). In a run the
player wears their own avatar; only the cards show these.

    python -I tools/class_figures/figure.py assets/models/class_figures/ranger_male_set.glb         assets/models/class_figures/ranger_male_figure.glb RangerMale

One mesh named `name`, the whole figure as Design built it (no cut, no
re-mesh): every triangle keeps its material's colour as a vertex colour in
sRGB (a glTF base colour is linear; Roblox reads vertex colours as sRGB and
drops the materials), turned to face -Z, scaled so the body (meshes named
`avatar_*`) is the standard blocky body's height, 5.183 studs, standing on
y = 0 and centred on the body. Writes `<out>.json` beside it: the mesh's
size, its centre and where an R15 right hand would be (both from the feet,
in studs, for `Config/ClassFigures`), and its triangle count; Roblox takes
up to 20,000 triangles in a mesh.
"""
import json
import pathlib
import re
import struct
import sys

import numpy as np

HEIGHT = 5.183
LIMIT = 20000

COMPONENT = {5120: "b", 5121: "B", 5122: "h", 5123: "H", 5125: "I", 5126: "f"}
WIDTH = {"SCALAR": 1, "VEC2": 2, "VEC3": 3, "VEC4": 4, "MAT4": 16}


def _chunks(path):
    data = pathlib.Path(path).read_bytes()
    off, gltf, binary = 12, None, b""
    while off < len(data):
        length, kind = struct.unpack_from("<II", data, off)
        chunk = data[off + 8 : off + 8 + length]
        if kind == 0x4E4F534A:
            gltf = json.loads(chunk)
        elif kind == 0x004E4942:
            binary = chunk
        off += 8 + length
    return gltf, binary


def _accessor(gltf, binary, index):
    acc = gltf["accessors"][index]
    view = gltf["bufferViews"][acc["bufferView"]]
    kind, width = COMPONENT[acc["componentType"]], WIDTH[acc["type"]]
    item = np.dtype("<" + kind)
    stride = view.get("byteStride") or item.itemsize * width
    start = view.get("byteOffset", 0) + acc.get("byteOffset", 0)
    raw = np.frombuffer(binary, np.uint8, count=stride * (acc["count"] - 1) + item.itemsize * width, offset=start)
    rows = np.lib.stride_tricks.as_strided(raw, (acc["count"], item.itemsize * width), (stride, 1))
    out = np.ascontiguousarray(rows).view(item).reshape(acc["count"], width).astype(np.float64)
    if acc.get("normalized"):
        out /= np.iinfo(item).max
    return out


def _local(node):
    if "matrix" in node:
        return np.array(node["matrix"], float).reshape(4, 4).T
    m = np.eye(4)
    x, y, z, w = node.get("rotation", [0, 0, 0, 1])
    m[:3, :3] = [
        [1 - 2 * (y * y + z * z), 2 * (x * y - z * w), 2 * (x * z + y * w)],
        [2 * (x * y + z * w), 1 - 2 * (x * x + z * z), 2 * (y * z - x * w)],
        [2 * (x * z - y * w), 2 * (y * z + x * w), 1 - 2 * (x * x + y * y)],
    ]
    m[:3, :3] *= np.array(node.get("scale", [1, 1, 1]), float)
    m[:3, 3] = node.get("translation", [0, 0, 0])
    return m


def read_glb(path):
    """Every mesh node as world-space triangles with a linear colour and a
    glow flag a triangle: [{name, tris (n,3,3), colour (n,3), glow (n,)}]."""
    gltf, binary = _chunks(path)
    out = []

    def walk(index, parent):
        node = gltf["nodes"][index]
        world = parent @ _local(node)
        if "mesh" in node:
            tris, colours, glows = [], [], []
            for prim in gltf["meshes"][node["mesh"]]["primitives"]:
                pos = _accessor(gltf, binary, prim["attributes"]["POSITION"])
                pos = pos @ world[:3, :3].T + world[:3, 3]
                if "indices" in prim:
                    faces = _accessor(gltf, binary, prim["indices"]).astype(int).reshape(-1, 3)
                else:
                    faces = np.arange(len(pos)).reshape(-1, 3)
                mat = gltf["materials"][prim["material"]] if "material" in prim else {}
                base = np.array(mat.get("pbrMetallicRoughness", {}).get("baseColorFactor", [1, 1, 1, 1])[:3], float)
                colour = np.tile(base, (len(faces), 1))
                if "COLOR_0" in prim["attributes"]:
                    vertex = _accessor(gltf, binary, prim["attributes"]["COLOR_0"])[:, :3]
                    colour = colour * vertex[faces].mean(axis=1)
                strength = mat.get("extensions", {}).get("KHR_materials_emissive_strength", {}).get("emissiveStrength", 1)
                glow = max(mat.get("emissiveFactor", [0, 0, 0])) * strength > 0.05
                tris.append(pos[faces])
                colours.append(colour)
                glows.append(np.full(len(faces), glow))
            out.append({
                "name": node.get("name", f"node{index}"),
                "tris": np.concatenate(tris),
                "colour": np.concatenate(colours),
                "glow": np.concatenate(glows),
            })
        for child in node.get("children", []):
            walk(child, world)

    for root in gltf["scenes"][gltf.get("scene", 0)]["nodes"]:
        walk(root, np.eye(4))
    return out


def write_glb(path, meshes):
    """`meshes`: [{name, centre, pos (n,3) from the centre, normal (n,3),
    colour (n,4) uint8 sRGB, faces (m,3)}], one node and one mesh each."""
    gltf = {
        "asset": {"version": "2.0", "generator": "tools/class_armour/split_set.py"},
        "scene": 0,
        "scenes": [{"nodes": list(range(len(meshes)))}],
        "nodes": [], "meshes": [], "accessors": [], "bufferViews": [],
        "materials": [{"name": "VertexColour", "pbrMetallicRoughness": {"metallicFactor": 0, "roughnessFactor": 1}}],
        "buffers": [{}],
    }
    blob = bytearray()

    def add(array, kind, target, normalized=False, bounds=False):
        raw = array.tobytes()
        gltf["bufferViews"].append({"buffer": 0, "byteOffset": len(blob), "byteLength": len(raw), "target": target})
        blob.extend(raw + b"\0" * (-len(raw) % 4))
        acc = {
            "bufferView": len(gltf["bufferViews"]) - 1,
            "componentType": {"f4": 5126, "u1": 5121, "u4": 5125}[array.dtype.str[1:]],
            "count": len(array), "type": kind,
        }
        if normalized:
            acc["normalized"] = True
        if bounds:
            acc["min"], acc["max"] = array.min(0).tolist(), array.max(0).tolist()
        gltf["accessors"].append(acc)
        return len(gltf["accessors"]) - 1

    for index, mesh in enumerate(meshes):
        prim = {
            "attributes": {
                "POSITION": add(mesh["pos"].astype("<f4"), "VEC3", 34962, bounds=True),
                "NORMAL": add(mesh["normal"].astype("<f4"), "VEC3", 34962),
                "COLOR_0": add(mesh["colour"].astype(np.uint8), "VEC4", 34962, normalized=True),
            },
            "indices": add(mesh["faces"].astype("<u4").reshape(-1), "SCALAR", 34963),
            "material": 0,
        }
        gltf["meshes"].append({"name": mesh["name"], "primitives": [prim]})
        gltf["nodes"].append({"name": mesh["name"], "mesh": index, "translation": [float(v) for v in mesh["centre"]]})
    gltf["buffers"][0]["byteLength"] = len(blob)
    text = json.dumps(gltf, separators=(",", ":")).encode()
    text += b" " * (-len(text) % 4)
    total = 12 + 8 + len(text) + 8 + len(blob)
    with open(path, "wb") as handle:
        handle.write(struct.pack("<III", 0x46546C67, 2, total))
        handle.write(struct.pack("<II", len(text), 0x4E4F534A) + text)
        handle.write(struct.pack("<II", len(blob), 0x004E4942) + bytes(blob))


def to_srgb(linear):
    linear = np.clip(np.asarray(linear, float), 0, 1)
    return np.where(linear <= 0.0031308, linear * 12.92, 1.055 * np.power(linear, 1 / 2.4) - 0.055)


def main(argv):
    source, out, name = argv[:3]
    meshes = read_glb(source)
    body = [m for m in meshes if re.match(r"avatar", m["name"], re.I)]
    if not body:
        raise SystemExit(f"no avatar_* body meshes in {source}: {[m['name'] for m in meshes][:10]}")
    points = np.concatenate([m["tris"].reshape(-1, 3) for m in body])
    lo, hi = points.min(0), points.max(0)
    scale = HEIGHT / (hi[1] - lo[1])
    centre = np.array([(lo[0] + hi[0]) / 2, lo[1], (lo[2] + hi[2]) / 2])
    tris = np.concatenate([m["tris"] for m in meshes])
    colour = np.concatenate([m["colour"] for m in meshes])
    tris = (tris - centre) * scale
    # Design faces +Z; the game's front is -Z: half a turn about Y
    tris[..., 0] *= -1
    tris[..., 2] *= -1
    normal = np.cross(tris[:, 1] - tris[:, 0], tris[:, 2] - tris[:, 0])
    length = np.linalg.norm(normal, axis=1)
    keep = length > 1e-12
    tris, colour, normal = tris[keep], colour[keep], normal[keep] / length[keep, None]
    count = len(tris)
    if count > LIMIT:
        raise SystemExit(f"{count} triangles: over Roblox's {LIMIT} a mesh")
    rgb = np.round(to_srgb(colour) * 255)
    rgba = np.concatenate([rgb, np.full((count, 1), 255)], axis=1)
    lo, hi = tris.reshape(-1, 3).min(0), tris.reshape(-1, 3).max(0)
    middle = (lo + hi) / 2
    # where an R15 right hand would be, for the class weapon: the bottom of
    # the body's right arm (the character's right is +X once it faces -Z)
    arms = []
    for mesh in body:
        if re.search(r"arm", mesh["name"], re.I):
            q = (mesh["tris"].reshape(-1, 3) - centre) * scale
            q[:, 0] *= -1
            q[:, 2] *= -1
            if q[:, 0].mean() > 0:
                arms.append(q)
    if not arms:
        raise SystemExit("no right arm among the body meshes (names with 'arm')")
    arm = np.concatenate(arms)
    hand = np.array([(arm[:, 0].min() + arm[:, 0].max()) / 2, arm[:, 1].min() + 0.16, (arm[:, 2].min() + arm[:, 2].max()) / 2])
    write_glb(out, [{
        "name": name,
        "centre": middle,
        "pos": (tris - middle).reshape(-1, 3),
        "normal": np.repeat(normal, 3, axis=0),
        "colour": np.repeat(rgba, 3, axis=0),
        "faces": np.arange(count * 3).reshape(-1, 3),
    }])
    size = np.round(hi - lo, 4).tolist()
    info = {"name": name, "source": pathlib.Path(source).name, "triangles": count, "size": size,
            "centre": np.round(middle, 4).tolist(), "hand": np.round(hand, 4).tolist(),
            "colours": len(np.unique(rgb, axis=0))}
    pathlib.Path(out).with_suffix(".json").write_text(json.dumps(info, indent=1) + "\n")
    print(json.dumps(info))


if __name__ == "__main__":
    main(sys.argv[1:])
