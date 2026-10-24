"""Turn the animations inside Claude Design GLBs into
src/shared/Config/ModelClips/<Model>.luau (one data module per model), so the game can play them on the models
the owner imports (Roblox's importer does not bring clips for a model that
has no skin, and these have none: each part rides a joint node).

    python -I tools/glb_clips_to_luau.py

Reads assets/models/model_clips.json, a map of the game's name for a model
to its GLB (relative to the repo), and writes one module per model
(removing modules for models no longer listed):

- joints: every animated node and its ancestors, parents first, with its
  rest transform relative to its parent (x, y, z, qx, qy, qz, qw, sx, sy, sz);
- parts: every mesh node by name (the name the importer gives its MeshPart),
  with the joint it rides, its rest centre, rotation and size in the GLB's
  space, so the player can work out how the import was scaled and turned;
- clips: per clip, per joint, the keys of whichever of position, rotation
  and scale it animates, thinned to the keys a straight line between its
  neighbours cannot stand in for.

Glb space is glTF's: Y up, the model's front toward +Z, metres as units.
`Shared/Util/ModelClip` samples the clips; `Fx/ModelAnimator` plays them.
"""
import json
import math
import pathlib
import struct

import numpy as np

ROOT = pathlib.Path(__file__).resolve().parents[1]
MANIFEST = ROOT / "assets" / "models" / "model_clips.json"
OUT = ROOT / "src" / "shared" / "Config" / "ModelClips"

#: Keys dropped while the line between their neighbours stays this close:
#: studs at the GLB's size for position and scale, radians for rotation.
POS_TOL = 0.004
ROT_TOL = math.radians(0.6)
SCALE_TOL = 0.004

COMPONENTS = {5120: "b", 5121: "B", 5122: "h", 5123: "H", 5125: "I", 5126: "f"}
WIDTH = {"SCALAR": 1, "VEC2": 2, "VEC3": 3, "VEC4": 4, "MAT4": 16}


def load(path: pathlib.Path):
    data = path.read_bytes()
    gltf, binary, offset = None, b"", 12
    while offset < len(data):
        length, kind = struct.unpack_from("<II", data, offset)
        chunk = data[offset + 8 : offset + 8 + length]
        if kind == 0x4E4F534A:
            gltf = json.loads(chunk)
        elif kind == 0x004E4942:
            binary = chunk
        offset += 8 + length
    return gltf, binary


def accessor(gltf, binary, index):
    acc = gltf["accessors"][index]
    view = gltf["bufferViews"][acc["bufferView"]]
    width = WIDTH[acc["type"]]
    fmt = COMPONENTS[acc["componentType"]]
    size = struct.calcsize(fmt)
    stride = view.get("byteStride", size * width)
    start = view.get("byteOffset", 0) + acc.get("byteOffset", 0)
    out = np.empty((acc["count"], width))
    for i in range(acc["count"]):
        out[i] = struct.unpack_from("<" + fmt * width, binary, start + i * stride)
    if acc.get("normalized") and fmt != "f":
        out /= {"b": 127, "B": 255, "h": 32767, "H": 65535}[fmt]
    return out


def quat_to_matrix(q):
    x, y, z, w = q
    return np.array(
        [
            [1 - 2 * (y * y + z * z), 2 * (x * y - z * w), 2 * (x * z + y * w)],
            [2 * (x * y + z * w), 1 - 2 * (x * x + z * z), 2 * (y * z - x * w)],
            [2 * (x * z - y * w), 2 * (y * z + x * w), 1 - 2 * (x * x + y * y)],
        ]
    )


def matrix_to_quat(m):
    trace = m[0, 0] + m[1, 1] + m[2, 2]
    if trace > 0:
        s = math.sqrt(trace + 1) * 2
        w, x, y, z = 0.25 * s, (m[2, 1] - m[1, 2]) / s, (m[0, 2] - m[2, 0]) / s, (m[1, 0] - m[0, 1]) / s
    elif m[0, 0] > m[1, 1] and m[0, 0] > m[2, 2]:
        s = math.sqrt(1 + m[0, 0] - m[1, 1] - m[2, 2]) * 2
        w, x, y, z = (m[2, 1] - m[1, 2]) / s, 0.25 * s, (m[0, 1] + m[1, 0]) / s, (m[0, 2] + m[2, 0]) / s
    elif m[1, 1] > m[2, 2]:
        s = math.sqrt(1 + m[1, 1] - m[0, 0] - m[2, 2]) * 2
        w, x, y, z = (m[0, 2] - m[2, 0]) / s, (m[0, 1] + m[1, 0]) / s, 0.25 * s, (m[1, 2] + m[2, 1]) / s
    else:
        s = math.sqrt(1 + m[2, 2] - m[0, 0] - m[1, 1]) * 2
        w, x, y, z = (m[1, 0] - m[0, 1]) / s, (m[0, 2] + m[2, 0]) / s, (m[1, 2] + m[2, 1]) / s, 0.25 * s
    q = np.array([x, y, z, w])
    q /= np.linalg.norm(q)
    return q if q[3] >= 0 else -q


def local_trs(node):
    """A node's rest transform relative to its parent: position, rotation
    quaternion, scale (a matrix is split, assuming no shear)."""
    if "matrix" in node:
        m = np.array(node["matrix"]).reshape(4, 4).T
        t = m[:3, 3]
        s = np.linalg.norm(m[:3, :3], axis=0)
        return t, matrix_to_quat(m[:3, :3] / s), s
    return (
        np.array(node.get("translation", [0, 0, 0]), float),
        np.array(node.get("rotation", [0, 0, 0, 1]), float),
        np.array(node.get("scale", [1, 1, 1]), float),
    )


def affine(t, q, s):
    m = np.eye(4)
    m[:3, :3] = quat_to_matrix(q) * s
    m[:3, 3] = t
    return m


def thin(times, values, tol, rotation=False):
    """Keep the first and last key and every key a straight line (or slerp)
    between its kept neighbours cannot stand in for."""
    if len(times) <= 2:
        return list(range(len(times)))

    def err(a, b, i):
        u = (times[i] - times[a]) / max(times[b] - times[a], 1e-9)
        if rotation:
            qa, qb = values[a], values[b] if np.dot(values[a], values[b]) >= 0 else -values[b]
            q = qa * (1 - u) + qb * u
            q /= np.linalg.norm(q)
            d = abs(float(np.dot(q, values[i])))
            return 2 * math.acos(min(1.0, d))
        return float(np.max(np.abs(values[a] * (1 - u) + values[b] * u - values[i])))

    keep = [0]
    a = 0
    for i in range(2, len(times)):
        if any(err(a, i, j) > tol for j in range(a + 1, i)):
            keep.append(i - 1)
            a = i - 1
    keep.append(len(times) - 1)
    return keep


def num(v: float) -> str:
    r = round(float(v), 4)
    if r == 0:
        return "0"
    return f"{r:.4f}".rstrip("0").rstrip(".")


def nums(vs) -> str:
    return "{ " + ", ".join(num(v) for v in vs) + " }"


def convert(path: pathlib.Path):
    gltf, binary = load(path)
    nodes = gltf["nodes"]
    parent = {}
    for i, n in enumerate(nodes):
        for c in n.get("children", []):
            parent[c] = i
    rest = {i: local_trs(n) for i, n in enumerate(nodes)}
    world = {}

    def world_of(i):
        if i not in world:
            m = affine(*rest[i])
            world[i] = world_of(parent[i]) @ m if i in parent else m
        return world[i]

    animated = set()
    for anim in gltf.get("animations", []):
        for ch in anim["channels"]:
            animated.add(ch["target"]["node"])

    # joints: animated nodes and their ancestors, parents first
    keep = set()
    for i in animated:
        while i is not None:
            keep.add(i)
            i = parent.get(i)
    order = []

    def visit(i):
        if i in keep:
            order.append(i)
        for c in nodes[i].get("children", []):
            visit(c)

    for root in gltf["scenes"][gltf.get("scene", 0)]["nodes"]:
        visit(root)
    name_of = {i: nodes[i].get("name") or f"node{i}" for i in range(len(nodes))}

    joints = []
    for i in order:
        t, q, s = rest[i]
        p = parent.get(i)
        while p is not None and p not in keep:
            p = parent.get(p)
        joints.append((name_of[i], name_of[p] if p is not None else "", list(t) + list(q) + list(s)))

    def joint_of(i):
        while i is not None and i not in keep:
            i = parent.get(i)
        return name_of[i] if i is not None else ""

    parts = {}
    for i, n in enumerate(nodes):
        if "mesh" not in n:
            continue
        lo = np.full(3, np.inf)
        hi = np.full(3, -np.inf)
        for prim in gltf["meshes"][n["mesh"]]["primitives"]:
            acc = gltf["accessors"][prim["attributes"]["POSITION"]]
            lo = np.minimum(lo, acc["min"])
            hi = np.maximum(hi, acc["max"])
        w = world_of(i)
        scale = np.linalg.norm(w[:3, :3], axis=0)
        rot = w[:3, :3] / scale
        centre = (w @ np.append((lo + hi) / 2, 1))[:3]
        size = (hi - lo) * scale
        parts[name_of[i]] = (joint_of(i), list(centre) + list(matrix_to_quat(rot)), list(size))

    clips = {}
    for anim in gltf.get("animations", []):
        tracks = {}
        length = 0.0
        for ch in anim["channels"]:
            node = ch["target"]["node"]
            kind = ch["target"]["path"]
            if kind not in ("translation", "rotation", "scale"):
                continue
            sampler = anim["samplers"][ch["sampler"]]
            times = accessor(gltf, binary, sampler["input"])[:, 0]
            values = accessor(gltf, binary, sampler["output"])
            if sampler.get("interpolation") == "CUBICSPLINE":
                values = values[1::3]
            length = max(length, float(times[-1]))
            base = rest[node][{"translation": 0, "rotation": 1, "scale": 2}[kind]]
            tol = {"translation": POS_TOL, "rotation": ROT_TOL, "scale": SCALE_TOL}[kind]
            if kind == "rotation":
                for k in range(1, len(values)):
                    if np.dot(values[k], values[k - 1]) < 0:
                        values[k] = -values[k]
                still = all(abs(float(np.dot(v, base))) > math.cos(tol / 2) for v in values)
            else:
                still = float(np.max(np.abs(values - base))) <= tol
            if still:
                continue
            idx = thin(times, values, tol, rotation=kind == "rotation")
            key = {"translation": "pos", "rotation": "rot", "scale": "scale"}[kind]
            tracks.setdefault(name_of[node], {})[key] = (
                [float(times[k]) for k in idx],
                [float(x) for k in idx for x in values[k]],
            )
        clips[anim.get("name") or f"Clip{len(clips) + 1}"] = (length, tracks)
    return joints, parts, clips


def render(name, model) -> str:
    joints, parts, clips = model
    lines = [
        "--!strict",
        "--[[",
        f"	{name}'s animations. Generated by tools/glb_clips_to_luau.py from the",
        "	GLB named in assets/models/model_clips.json; regenerate, never hand-edit.",
        "",
        "	In the GLB's space (Y up, front toward +Z). `joints` are the animated",
        "	nodes and their ancestors, parents first, each at rest relative to its",
        "	parent (x, y, z, qx, qy, qz, qw, sx, sy, sz). `parts` are the meshes by",
        "	name, each riding a joint, with its rest centre and rotation (x, y, z,",
        "	qx, qy, qz, qw) and size. `clips` hold, per joint, the keys of what it",
        "	animates: `times` and `values` (3 a key for pos and scale, 4 for rot).",
        "	Shaped as `Shared/Util/ModelClip`'s Model; played by `Fx/ModelAnimator`.",
        "]]",
        "",
        "return table.freeze({",
        "	joints = {",
    ]
    for jn, jp, r in joints:
        lines.append(f'		{{ name = "{jn}", parent = "{jp}", rest = {nums(r)} }},')
    lines.append("	},")
    lines.append("	parts = {")
    for pn in sorted(parts):
        j, cf, size = parts[pn]
        lines.append(f'		["{pn}"] = {{ joint = "{j}", cframe = {nums(cf)}, size = {nums(size)} }},')
    lines.append("	},")
    lines.append("	clips = {")
    for cn in sorted(clips):
        length, tracks = clips[cn]
        lines.append(f'		["{cn}"] = {{')
        lines.append(f"			length = {num(length)},")
        lines.append("			joints = {")
        for jn in sorted(tracks):
            lines.append(f'				["{jn}"] = {{')
            for key in ("pos", "rot", "scale"):
                if key in tracks[jn]:
                    times, values = tracks[jn][key]
                    lines.append(f"					{key} = {{ times = {nums(times)}, values = {nums(values)} }},")
            lines.append("				},")
        lines.append("			},")
        lines.append("		},")
    lines.append("	},")
    lines += ["})", ""]
    return "\n".join(lines)


def main():
    manifest = json.loads(MANIFEST.read_text(encoding="utf-8"))
    OUT.mkdir(parents=True, exist_ok=True)
    written = set()
    for name, rel in manifest.items():
        if name.startswith("_"):
            continue
        model = convert(ROOT / rel)
        joints, parts, clips = model
        path = OUT / f"{name}.luau"
        path.write_text(render(name, model), encoding="utf-8", newline="\n")
        written.add(path.name)
        keys = sum(len(t[0]) for c in clips.values() for jt in c[1].values() for t in jt.values())
        print(f"{name}: {len(joints)} joints, {len(parts)} parts, {sorted(clips)}, {keys} keys, {path.stat().st_size // 1024} KB")
    for old in OUT.glob("*.luau"):
        if old.name not in written:
            old.unlink()
            print(f"removed {old.name}")


if __name__ == "__main__":
    main()
