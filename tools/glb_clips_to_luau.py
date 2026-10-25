"""Turn the animations inside Claude Design GLBs into
src/shared/Config/ModelClips/<Model>.luau (one data module per model), so the game can play them on the models
the owner imports (Roblox's importer does not bring clips for a model that
has no skin, and these have none: each part rides a joint node).

    python -I tools/glb_clips_to_luau.py

Reads assets/models/model_clips.json, a map of the game's name for a model
to its GLB (relative to the repo), or to { "glb": ..., "loops": [...] } for
a model whose clips do not all loop, and writes one module per model
(removing modules for models no longer listed):

- joints: every animated node and its ancestors, parents first, with its
  rest transform relative to its parent (x, y, z, qx, qy, qz, qw, sx, sy, sz);
- parts: every mesh node by name (the name the importer gives its MeshPart),
  with the joint it rides, its rest centre, rotation and size in the GLB's
  space, so the player can work out how the import was scaled and turned;
- clips: per clip, per joint, the keys of whichever of position, rotation
  and scale it animates, thinned to the keys a straight line between its
  neighbours cannot stand in for. With a "loops" list, each clip carries
  `loops`: whether it repeats, or plays once and holds its last frame (a
  boss's beats). Without one, every clip loops (pets).
  A "moving" list names clips played exactly as made even if they walk a
  path (a pet's one-shot Attack that dashes out and back; see PATH_TRAVEL).

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

#: A clip whose root travels this far sideways (GLB units) and turns this
#: far about Y walks a path in the viewer (a Follow trotting a loop). The
#: game moves the model itself, so such a clip is played on the spot.
PATH_TRAVEL = 0.3
PATH_TURN = math.radians(180)


def twist_y(q):
    """The part of a rotation (x, y, z, w) that turns about Y."""
    t = np.array([0.0, q[1], 0.0, q[3]])
    n = np.linalg.norm(t)
    return t / n if n > 1e-9 else np.array([0.0, 0.0, 0.0, 1.0])


def quat_mul(a, b):
    ax, ay, az, aw = a
    bx, by, bz, bw = b
    return np.array(
        [
            aw * bx + ax * bw + ay * bz - az * by,
            aw * by - ax * bz + ay * bw + az * bx,
            aw * bz + ax * by - ay * bx + az * bw,
            aw * bw - ax * bx - ay * by - az * bz,
        ]
    )


def on_the_spot(tracks, roots, rest):
    """Drops the sideways travel and the turn about Y of a root that walks a
    path, keeping its bob and tilt and everything below it. Returns the
    roots it stilled."""
    stilled = []
    for name in roots:
        t = tracks.get(name)
        if not t or "pos" not in t or "rot" not in t:
            continue
        times, values = t["pos"]
        pos = np.array(values).reshape(-1, 3)
        rtimes, rvalues = t["rot"]
        rot = np.array(rvalues).reshape(-1, 4)
        yaw = [2 * math.atan2(twist_y(q)[1], twist_y(q)[3]) for q in rot]
        yaw = np.unwrap(yaw)
        if max(np.ptp(pos[:, 0]), np.ptp(pos[:, 2])) < PATH_TRAVEL or np.ptp(yaw) < PATH_TURN:
            continue
        base_t, base_q, _ = rest[name]
        pos[:, 0], pos[:, 2] = base_t[0], base_t[2]
        keep = twist_y(base_q)
        rot = np.array([quat_mul(keep, quat_mul(twist_y(q) * [-1, -1, -1, 1], q)) for q in rot])
        t["pos"] = (times, [float(x) for x in pos.reshape(-1)])
        t["rot"] = (rtimes, [float(x) for x in rot.reshape(-1)])
        stilled.append(name)
    return stilled

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


def rebuilt_turn(linear, s):
    """The turn of a node matrix that has a zero-scale axis: an effect piece
    resting shrunk to nothing until its clip grows it. Dividing that axis by
    its length divides by zero, and the NaN reaches the game as a part that
    never appears. The surviving axes still fix the turn, so the missing ones
    are rebuilt from them, right-handed (each axis is the cross product of
    the next two)."""
    ok = s > 1e-9
    r = np.zeros((3, 3))
    for k in range(3):
        if ok[k]:
            r[:, k] = linear[:, k] / s[k]
    if ok.sum() == 2:
        k = int(np.flatnonzero(~ok)[0])
        r[:, k] = np.cross(r[:, (k + 1) % 3], r[:, (k + 2) % 3])
    elif ok.sum() == 1:
        k = int(np.flatnonzero(ok)[0])
        v = r[:, k]
        helper = np.array([1.0, 0.0, 0.0]) if abs(v[0]) < 0.9 else np.array([0.0, 1.0, 0.0])
        a, b = (k + 1) % 3, (k + 2) % 3
        r[:, a] = np.cross(v, helper)
        r[:, a] /= np.linalg.norm(r[:, a])
        r[:, b] = np.cross(v, r[:, a])
    else:
        r = np.eye(3)
    return r


def local_trs(node):
    """A node's rest transform relative to its parent: position, rotation
    quaternion, scale (a matrix is split, assuming no shear)."""
    if "matrix" in node:
        m = np.array(node["matrix"]).reshape(4, 4).T
        t = m[:3, 3]
        s = np.linalg.norm(m[:3, :3], axis=0)
        if (s > 1e-9).all():
            return t, matrix_to_quat(m[:3, :3] / s), s
        return t, matrix_to_quat(rebuilt_turn(m[:3, :3], s)), s
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


def convert(path: pathlib.Path, moving=()):
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

    def turn_of(i):
        """A node's world turn from its rotations alone. Used only for a part
        resting at zero size (an effect's lit or flash piece, hidden until a
        clip grows it): its world matrix has no length left to divide out,
        so the turn comes from the chain of rotations instead."""
        m = quat_to_matrix(rest[i][1])
        return turn_of(parent[i]) @ m if i in parent else m

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
        if (scale > 1e-9).all():
            rot = w[:3, :3] / scale
        else:
            # zero size at rest: see turn_of
            rot = turn_of(i)
        centre = (w @ np.append((lo + hi) / 2, 1))[:3]
        size = (hi - lo) * scale
        parts[name_of[i]] = (joint_of(i), list(centre) + list(matrix_to_quat(rot)), list(size))

    # the joints that can carry a whole model along a path: the top two levels,
    # less a clip's effect pieces (Fx_*, the pets' Attacks), which fly on purpose
    depth = {}
    for jn, jp, _ in joints:
        depth[jn] = depth.get(jp, -1) + 1
    roots = [jn for jn, _, _ in joints if depth[jn] <= 1 and not jn.startswith("Fx_")]
    rest_by_name = {name_of[i]: rest[i] for i in keep}

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
        clip_name = anim.get("name") or f"Clip{len(clips) + 1}"
        stilled = [] if clip_name in moving else on_the_spot(tracks, roots, rest_by_name)
        if stilled:
            print(f"  {path.stem} {clip_name}: walks a path; played on the spot ({', '.join(stilled)})")
        clips[clip_name] = (length, tracks)
    return joints, parts, clips


def entry(value):
    """A manifest value: the GLB's path, the clips that loop (None: all) and
    the clips played as made however far they travel."""
    if isinstance(value, str):
        return value, None, ()
    return value["glb"], value.get("loops"), tuple(value.get("moving", ()))


def render(name, model, loops=None) -> str:
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
        if loops is not None:
            lines.append(f"			loops = {'true' if cn in loops else 'false'},")
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
        rel, loops, moving = entry(rel)
        model = convert(ROOT / rel, moving)
        joints, parts, clips = model
        if loops is not None:
            unknown = sorted(set(loops) - set(clips))
            if unknown:
                raise SystemExit(f"{name}: loops names clips the GLB has not: {', '.join(unknown)}")
        path = OUT / f"{name}.luau"
        path.write_text(render(name, model, loops), encoding="utf-8", newline="\n")
        written.add(path.name)
        keys = sum(len(t[0]) for c in clips.values() for jt in c[1].values() for t in jt.values())
        print(f"{name}: {len(joints)} joints, {len(parts)} parts, {sorted(clips)}, {keys} keys, {path.stat().st_size // 1024} KB")
    for old in OUT.glob("*.luau"):
        if old.name not in written:
            old.unlink()
            print(f"removed {old.name}")


if __name__ == "__main__":
    main()
