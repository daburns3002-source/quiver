"""Merge a clip-driven model's meshes per joint (docs/PERFORMANCE.md, option
1 of 2026-10-25, the owner's pick 2026-11-27): every primitive that rides
the same joint (the node Config/ModelClips poses it by) and wears the same
GLB material becomes one mesh, so the game poses and draws one part where
it posed several. Nothing moves or changes colour: the merged mesh sits in
its joint's own frame, keeps its material (so its colour, glow, alpha and
`surface` are the material's, as each member's were), and the clips are
untouched.

    python -I tools/merge_joints.py --report              # every model: parts now and merged
    python -I tools/merge_joints.py <Name>... [--out DIR] # writes DIR/<glb stem>_merged.glb

Kept apart, as they are, because the game finds them by name or treats
them alone:
- eyes (`Eye*`: `EnemyDesigns` tints and lights them by name pattern, and
  King Bloblin's effects find them by their `Eye` attribute);
- any part the game's code looks up by name (`FindFirstChild("Crown")`,
  `Name == "Crown"`: King Bloblin's crown);
- a textured primitive (its UVs and picture are its own);
- a part resting at zero size, or under a joint that does (a clip grows it).
A model is left whole if merging would change which of its parts
`EnemyModel` draws as tucked-away blocks (under a hundredth of its largest).

Each merged mesh is a new node under its joint, named `M_<joint>_<material>`,
which no eye pattern matches. Then: upload or import the merged GLB, read
the mesh ids back, point the model's `glb` in assets/models/model_clips.json
at it, and regenerate with tools/glb_clips_to_luau.py and
tools/imports_to_luau.py.
"""
import json
import pathlib
import re
import struct
import sys

import numpy as np

sys.path.insert(0, str(pathlib.Path(__file__).resolve().parent))
import glb_clips_to_luau as glb  # noqa: E402

ROOT = pathlib.Path(__file__).resolve().parents[1]
MANIFEST = ROOT / "assets" / "models" / "model_clips.json"
KINDS = ("assets/models/enemies/", "assets/models/bosses/", "assets/models/pets/")
GENERATED = ("Config/ImportedModels", "Config/PetModels", "Config/ModelClips")
APART = re.compile(r"^Eye")
# How the game's code finds a part by its name.
LOOKUP = re.compile(r'(?:Name == |name == |FindFirstChild\(|WaitForChild\()"([A-Za-z0-9_]+)"')
TUCKED_SHARE = 0.01
ZERO = 1e-6


def code_names():
    """Every name the game's own (not generated) code looks a child up by."""
    names = set()
    for path in (ROOT / "src").rglob("*.luau"):
        if any(g in path.as_posix() for g in GENERATED):
            continue
        names.update(LOOKUP.findall(path.read_text(encoding="utf-8")))
    return names


def analyse(path, spelled):
    gltf, binary = glb.load(path)
    nodes = gltf["nodes"]
    parent = {}
    for i, n in enumerate(nodes):
        for c in n.get("children", []):
            parent[c] = i
    rest = {i: glb.local_trs(n) for i, n in enumerate(nodes)}
    world = {}

    def world_of(i):
        if i not in world:
            m = glb.affine(*rest[i])
            world[i] = world_of(parent[i]) @ m if i in parent else m
        return world[i]

    animated = {ch["target"]["node"] for a in gltf.get("animations", []) for ch in a["channels"]}
    keep = set()
    for i in animated:
        while i is not None:
            keep.add(i)
            i = parent.get(i)

    def joint_of(i):
        while i is not None and i not in keep:
            i = parent.get(i)
        return i

    def chain_apart(i):
        while i is not None:
            if APART.match(nodes[i].get("name") or ""):
                return True
            i = parent.get(i)
        return False

    mats = gltf.get("materials", [])
    groups, alone = {}, []
    for i, n in enumerate(nodes):
        if "mesh" not in n:
            continue
        name = n.get("name") or f"node{i}"
        j = joint_of(i)
        w = world_of(i)
        flat = np.linalg.norm(w[:3, :3], axis=0).min() < ZERO
        jflat = j is not None and np.linalg.norm(world_of(j)[:3, :3], axis=0).min() < ZERO
        for k, prim in enumerate(gltf["meshes"][n["mesh"]]["primitives"]):
            mi = prim.get("material")
            textured = mi is not None and "baseColorTexture" in mats[mi].get("pbrMetallicRoughness", {})
            if j is None or flat or jflat or textured or chain_apart(i) or name in spelled:
                alone.append((i, k))
            else:
                groups.setdefault((j, mi), []).append((i, k))
    return gltf, binary, nodes, world_of, groups, alone


def sizes(gltf, binary, world_of, members):
    """World size of each (node, primitive)'s box."""
    out = {}
    for i, k in members:
        prim = gltf["meshes"][gltf["nodes"][i]["mesh"]]["primitives"][k]
        acc = gltf["accessors"][prim["attributes"]["POSITION"]]
        scale = np.linalg.norm(world_of(i)[:3, :3], axis=0)
        out[(i, k)] = (np.array(acc["max"]) - np.array(acc["min"])) * scale
    return out


def plan(path, spelled):
    gltf, binary, nodes, world_of, groups, alone = analyse(path, spelled)
    before = sum(len(m) for m in groups.values()) + len(alone)
    after = len(groups) + len(alone)
    return gltf, binary, nodes, world_of, groups, alone, before, after


def tucked_unchanged(gltf, binary, world_of, groups, alone):
    """Whether the parts EnemyModel draws as blocks stay the same ones."""
    every = [m for ms in groups.values() for m in ms] + alone
    size = sizes(gltf, binary, world_of, every)
    largest_before = max(float(s.max()) for s in size.values())
    merged = []
    for members in groups.values():
        lo, hi = None, None
        for i, k in members:
            prim = gltf["meshes"][gltf["nodes"][i]["mesh"]]["primitives"][k]
            p = glb.accessor(gltf, binary, prim["attributes"]["POSITION"])
            w = world_of(i)
            q = p @ w[:3, :3].T + w[:3, 3]
            lo = q.min(0) if lo is None else np.minimum(lo, q.min(0))
            hi = q.max(0) if hi is None else np.maximum(hi, q.max(0))
        merged.append(hi - lo)
    largest_after = max([float(s.max()) for s in merged] + [float(size[m].max()) for m in alone])
    for m in alone:
        s = float(size[m].max())
        if (s < largest_before * TUCKED_SHARE) != (s < largest_after * TUCKED_SHARE):
            return False
    return True


def write(path, out_path, gltf, binary, nodes, world_of, groups, alone):
    gltf = json.loads(json.dumps(gltf))
    blob = bytearray(binary)
    nodes = gltf["nodes"]

    def add(array, kind, comp, target, minmax=False):
        while len(blob) % 4:
            blob.append(0)
        data = array.tobytes()
        gltf["bufferViews"].append({"buffer": 0, "byteOffset": len(blob), "byteLength": len(data), "target": target})
        blob.extend(data)
        acc = {"bufferView": len(gltf["bufferViews"]) - 1, "componentType": comp, "count": len(array), "type": kind}
        if minmax:
            acc["min"] = [float(v) for v in array.min(0)]
            acc["max"] = [float(v) for v in array.max(0)]
        gltf["accessors"].append(acc)
        return len(gltf["accessors"]) - 1

    merged_away = {m for ms in groups.values() if len(ms) > 1 for m in ms}
    old_meshes = gltf["meshes"]
    new_meshes = []
    # every mesh node gets its own mesh holding what stays of it
    for i, n in enumerate(nodes):
        if "mesh" not in n:
            continue
        mesh = old_meshes[n["mesh"]]
        prims = [p for k, p in enumerate(mesh["primitives"]) if (i, k) not in merged_away]
        if prims:
            new_meshes.append({"name": mesh.get("name", n.get("name", "")), "primitives": prims})
            n["mesh"] = len(new_meshes) - 1
        else:
            del n["mesh"]
    gltf["meshes"] = new_meshes

    mats = gltf.get("materials", [])
    for (j, mi), members in sorted(groups.items(), key=lambda kv: (kv[0][0], kv[0][1] if kv[0][1] is not None else -1)):
        if len(members) < 2:
            continue
        to_joint = np.linalg.inv(world_of(j))
        pos, nrm, idx, base = [], [], [], 0
        for i, k in members:
            prim = old_meshes[nodes[i]["mesh"] if "mesh" in nodes[i] else None]["primitives"][k] if False else None
            prim = json_prim(path, i, k)
            rel = to_joint @ world_of(i)
            p = glb.accessor(gltf, bytes(blob), prim["attributes"]["POSITION"])
            p = p @ rel[:3, :3].T + rel[:3, 3]
            if "NORMAL" in prim["attributes"]:
                nm = glb.accessor(gltf, bytes(blob), prim["attributes"]["NORMAL"])
                nm = nm @ np.linalg.inv(rel[:3, :3])
                nm /= np.maximum(np.linalg.norm(nm, axis=1, keepdims=True), 1e-12)
            else:
                nm = np.zeros_like(p)
            if "indices" in prim:
                ix = glb.accessor(gltf, bytes(blob), prim["indices"])[:, 0].astype(np.int64)
            else:
                ix = np.arange(len(p), dtype=np.int64)
            if np.linalg.det(rel[:3, :3]) < 0:
                ix = ix.reshape(-1, 3)[:, ::-1].reshape(-1)
            pos.append(p)
            nrm.append(nm)
            idx.append(ix + base)
            base += len(p)
        attrs = {
            "POSITION": add(np.vstack(pos).astype(np.float32), "VEC3", 5126, 34962, True),
            "NORMAL": add(np.vstack(nrm).astype(np.float32), "VEC3", 5126, 34962),
        }
        indices = add(np.concatenate(idx).astype(np.uint32), "SCALAR", 5125, 34963)
        prim = {"attributes": attrs, "indices": indices}
        if mi is not None:
            prim["material"] = mi
        label = re.sub(r"[^A-Za-z0-9]+", "", mats[mi].get("name", str(mi))) if mi is not None else "plain"
        name = f"M_{nodes[j].get('name') or j}_{label}"
        gltf["meshes"].append({"name": name, "primitives": [prim]})
        nodes.append({"name": name, "mesh": len(gltf["meshes"]) - 1})
        nodes[j].setdefault("children", []).append(len(nodes) - 1)

    while len(blob) % 4:
        blob.append(0)
    gltf["buffers"] = [{"byteLength": len(blob)}]
    js = json.dumps(gltf, separators=(",", ":")).encode()
    js += b" " * (-len(js) % 4)
    body = struct.pack("<II", len(js), 0x4E4F534A) + js + struct.pack("<II", len(blob), 0x004E4942) + bytes(blob)
    out_path.write_bytes(struct.pack("<III", 0x46546C67, 2, 12 + len(body)) + body)


_PRIMS = {}


def json_prim(path, i, k):
    """A member's primitive as the source GLB has it (meshes are rebuilt)."""
    if path not in _PRIMS:
        g, _ = glb.load(path)
        _PRIMS[path] = g
    g = _PRIMS[path]
    return g["meshes"][g["nodes"][i]["mesh"]]["primitives"][k]


def models():
    manifest = json.loads(MANIFEST.read_text())
    return {n: e for n, e in manifest.items() if not n.startswith("_") and e["glb"].startswith(KINDS)}


def main():
    args = sys.argv[1:]
    out_dir = None
    if "--out" in args:
        at = args.index("--out")
        out_dir = pathlib.Path(args[at + 1])
        args = args[:at] + args[at + 2 :]
    spelled = code_names()
    every = models()
    if args == ["--report"] or not args:
        total_b = total_a = 0
        for name, entry in sorted(every.items()):
            path = ROOT / entry["glb"]
            if not path.exists():
                print(f"{name:20} missing {entry['glb']}")
                continue
            g, b, nodes, world_of, groups, alone, before, after = plan(path, spelled)
            ok = tucked_unchanged(g, b, world_of, groups, alone)
            if not ok:
                after = before
            total_b += before
            total_a += after
            print(f"{name:20} {before:4d} -> {after:4d}{'' if ok else '  (left whole: tucked parts would change)'}")
        print(f"{'all':20} {total_b:4d} -> {total_a:4d}")
        return
    for name in args:
        entry = every[name]
        path = ROOT / entry["glb"]
        g, b, nodes, world_of, groups, alone, before, after = plan(path, spelled)
        if not tucked_unchanged(g, b, world_of, groups, alone):
            print(f"{name}: left whole, merging would change its tucked parts")
            continue
        target = (out_dir or path.parent) / f"{path.stem}_merged.glb"
        target.parent.mkdir(parents=True, exist_ok=True)
        write(path, target, g, b, nodes, world_of, groups, alone)
        print(f"{name}: {before} -> {after} parts, wrote {target}")


if __name__ == "__main__":
    main()
