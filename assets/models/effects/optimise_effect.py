"""Slim a Claude Design upgrade effect for phones, as optimise_weapon.py does
for weapons.

    python -I optimise_effect.py <in.glb> <out.glb> <effect>
    python -I optimise_effect.py --all <in_dir> <out_dir>

Claude Design exports every cube as its own mesh, so an effect came in as up
to 771 parts (Heavy Blade), cloned every time it fires. This merges each
effect into a few meshes:

- Everything that moves together becomes one mesh. A mesh rides its nearest
  "anchor": a node a clip animates, a node named in `split`, a child of a node
  named in `split_children`, or the root. Clips keep playing: anchors keep
  their names and their place in the tree.
- Plain pieces have their material colour baked into vertex colours, so one
  mesh holds any number of colours (Roblox shows vertex colours on a white
  part). Glowing pieces (emissive, imported as Neon) and see-through pieces
  stay apart, one mesh per colour and transparency, because Roblox gives a
  part one material and one transparency.
- A piece resting at zero size (a flash, a lit ring segment, a pour drop,
  hidden until its clip grows it) would import as a crushed mesh, a speck
  however big it is later drawn (docs/FIXES.md, "King Bloblin's lash arm drew
  as pale specks"). Its anchor rests at full size here instead, and every
  clip that does not scale it holds it at its old size, so it still starts
  hidden.
- `keep` extracts named pieces from a design page's staging (Chain
  Lightning's three demo scenes, Spell Pierce's floor grid), each re-centred
  on its own middle so the game can place it.

Only numpy: the glTF is read and written directly, so nodes, names and
animations survive exactly.
"""
import json
import pathlib
import struct
import sys

import numpy as np

#: Per effect: `split` names nodes whose meshes stay apart from their
#: parent's (moved on their own in code); `split_children` splits every child
#: of the named node; `keep` maps a new piece name to the name prefixes of the
#: meshes it takes, and drops everything else.
EFFECTS = {
    "execute": {"split": ["A_the_mark", "mark_clock_ring", "B_the_drop", "drop_cleaver"]},
    "meteor": {"split": ["Rock"]},
    "bloodletting": {"split": ["heart", "tear_off_burst"]},
    "ironskin": {"split_children": ["02_iron_skin"]},
    "steadfast": {"split_children": ["05_steadfast"]},
    "quickhands": {"split_children": ["01_quick_hands"]},
    "longreach": {"split_children": ["long_reach_line"]},
    "soulchain": {"split": ["cap_start", "cap_end"]},
    "strength": {"voxel": ["ArmBandLeft_Cuff", "ArmBandRight_Cuff"], "step": 0.4 / 3},
    "overdraw": {"split": ["shockwave", "ring_large", "ring_medium", "ring_small"]},
    "chainlightning": {
        "keep": {
            "Node": ["Node_2T_01_"],
            "Shard": ["Shard_2T_01"],
        },
        "offset": {"Shard": [0.9, 0.6, 0]},
    },
    "spellpierce": {
        "keep": {
            "Lance": ["Beauty_Lance_01"],
            "Puncture": ["Beauty_Puncture_01"],
            "Shards": ["Beauty_Shards"],
        },
        # laid out along the flight (+Z, the front once imported): the
        # puncture on the body's entry face, the lance out of the far side
        "offset": {"Lance": [0, 0, 0.9], "Puncture": [0, 0, -0.5], "Shards": [0, 0, 0.3]},
    },
}

#: Transparency is grouped to this step: Roblox gives a part one value.
ALPHA_STEP = 0.1
#: A merged mesh over this many triangles is reported.
BUDGET = 2000
#: Glow colours are grouped to 1/GLOW_STEPS: each glowing colour is its own part.
GLOW_STEPS = 6
#: Glow (emissive times strength, linear) from which a part is Neon: the
#: same line as tools/imports_to_luau.py's NEON_GLOW.
NEON_GLOW = 0.6
#: A rest scale under this is "hidden until a clip grows it".
TINY = 0.01

COMPONENT = {5120: np.int8, 5121: np.uint8, 5122: np.int16, 5123: np.uint16, 5125: np.uint32, 5126: np.float32}
WIDTH = {"SCALAR": 1, "VEC2": 2, "VEC3": 3, "VEC4": 4, "MAT4": 16}


def load(path):
    data = pathlib.Path(path).read_bytes()
    n = struct.unpack_from("<I", data, 12)[0]
    gltf = json.loads(data[20 : 20 + n])
    binary = b""
    off = 20 + n
    if off < len(data):
        length = struct.unpack_from("<I", data, off)[0]
        binary = data[off + 8 : off + 8 + length]
    return gltf, binary


def read(gltf, binary, index):
    acc = gltf["accessors"][index]
    view = gltf["bufferViews"][acc["bufferView"]]
    dtype = COMPONENT[acc["componentType"]]
    width = WIDTH[acc["type"]]
    start = view.get("byteOffset", 0) + acc.get("byteOffset", 0)
    stride = view.get("byteStride")
    count = acc["count"]
    item = np.dtype(dtype).itemsize * width
    if stride and stride != item:
        raw = np.frombuffer(binary, np.uint8, count=stride * (count - 1) + item, offset=start)
        rows = np.lib.stride_tricks.as_strided(raw, (count, item), (stride, 1))
        out = np.frombuffer(rows.copy().tobytes(), dtype).reshape(count, width)
    else:
        out = np.frombuffer(binary, dtype, count=count * width, offset=start).reshape(count, width)
    out = out.astype(np.float64)
    if acc.get("normalized"):
        out /= np.iinfo(dtype).max
    return out


def quat_matrix(q):
    x, y, z, w = q
    return np.array(
        [
            [1 - 2 * (y * y + z * z), 2 * (x * y - z * w), 2 * (x * z + y * w)],
            [2 * (x * y + z * w), 1 - 2 * (x * x + z * z), 2 * (y * z - x * w)],
            [2 * (x * z - y * w), 2 * (y * z + x * w), 1 - 2 * (x * x + y * y)],
        ]
    )


def local(node, scale_override=None):
    m = np.eye(4)
    if "matrix" in node:
        return np.array(node["matrix"], dtype=float).reshape(4, 4).T
    s = scale_override if scale_override is not None else node.get("scale", [1, 1, 1])
    m[:3, :3] = quat_matrix(node.get("rotation", [0, 0, 0, 1])) * np.array(s)
    m[:3, 3] = node.get("translation", [0, 0, 0])
    return m


def srgb_to_linear(c):
    return c  # glTF factors and COLOR_0 are already linear


def cull_hidden(pos, col, nrm, idx):
    """Drops the faces where two cubes touch. Strength's cuffs are grids of
    tiny cubes, 7,392 triangles each and worn all run; every face between
    two neighbours is buried, yet drawn. An axis-aligned square face's two
    triangles share its bounding square, so a triangle facing +X and one
    facing -X with the same plane and the same square are a buried pair.
    Only exact pairs go, so the shape is untouched (decimating it instead
    melted the blocks into a blob)."""
    tri = pos[idx.reshape(-1, 3)]
    normal = np.cross(tri[:, 1] - tri[:, 0], tri[:, 2] - tri[:, 0])
    length = np.linalg.norm(normal, axis=1)
    normal = normal / np.maximum(length, 1e-12)[:, None]
    axis = np.abs(normal).argmax(axis=1)
    aligned = np.abs(normal).max(axis=1) > 0.999
    keys = {}
    for t in np.nonzero(aligned)[0]:
        a = axis[t]
        others = [k for k in range(3) if k != a]
        q = np.round(tri[t] / 1e-3).astype(np.int64)
        key = (a, int(q[0, a]), *q[:, others].min(axis=0), *q[:, others].max(axis=0))
        keys.setdefault(key, {1: [], -1: []})[1 if normal[t, a] > 0 else -1].append(t)
    drop = set()
    for sides in keys.values():
        if sides[1] and sides[-1]:
            drop.update(sides[1])
            drop.update(sides[-1])
    keep = np.array([t for t in range(len(tri)) if t not in drop], dtype=np.int64)
    faces = idx.reshape(-1, 3)[keep]
    used = np.unique(faces)
    remap = np.full(len(pos), -1, dtype=np.int64)
    remap[used] = np.arange(len(used))
    return pos[used], col[used], (nrm[used] if nrm is not None else None), remap[faces].ravel().astype(np.uint32)


def voxel_rebuild(pos, nrm, colour, step):
    """Rebuilds a grid of bevelled cubes as plain voxels, outer faces only,
    merged into rectangles per colour (greedy meshing). Each cube is found
    from its big faces: a face as wide as a cube, pushed half a cube inward,
    lands on the cube's cell. Strength's cuffs: 616 bevelled cubes, 7,392
    triangles, worn all run."""
    tri = pos.reshape(-1, 3, 3)
    tcol = colour.reshape(-1, 3, 4).mean(axis=1)
    tn = nrm.reshape(-1, 3, 3).mean(axis=1) if nrm is not None else np.cross(tri[:, 1] - tri[:, 0], tri[:, 2] - tri[:, 0])
    tn /= np.maximum(np.linalg.norm(tn, axis=1, keepdims=True), 1e-12)
    cells = {}
    for t in range(len(tri)):
        n = tn[t]
        a = np.abs(n).argmax()
        if abs(n[a]) < 0.999:
            continue
        ext = tri[t].max(axis=0) - tri[t].min(axis=0)
        others = [k for k in range(3) if k != a]
        if min(ext[others]) < step * 0.5:
            continue  # a bevel strip, not a face
        centre = tri[t].mean(axis=0) - n * step / 2
        cell = tuple(np.round(centre / step).astype(int))  # cubes are centred on the grid
        cells.setdefault(cell, []).append(tcol[t])
    cells = {c: tuple(np.round(np.mean(v, axis=0), 3)) for c, v in cells.items()}
    out_pos, out_col, out_nrm = [], [], []
    for a in range(3):
        u, v = [k for k in range(3) if k != a]
        for d in (1, -1):
            planes = {}
            for c, col in cells.items():
                nb = list(c)
                nb[a] += d
                if tuple(nb) in cells:
                    continue
                planes.setdefault((c[a], col), set()).add((c[u], c[v]))
            for (layer, col), squares in planes.items():
                while squares:
                    su, sv = min(squares)
                    w = 1
                    while (su + w, sv) in squares:
                        w += 1
                    h = 1
                    while all((su + k, sv + h) in squares for k in range(w)):
                        h += 1
                    for k in range(w):
                        for m in range(h):
                            squares.discard((su + k, sv + m))
                    plane = (layer + d / 2) * step
                    corners = []
                    for cu, cv in ((su, sv), (su + w, sv), (su + w, sv + h), (su, sv + h)):
                        q = [0.0, 0.0, 0.0]
                        q[a], q[u], q[v] = plane, (cu - 0.5) * step, (cv - 0.5) * step
                        corners.append(q)
                    normal = [0.0, 0.0, 0.0]
                    normal[a] = float(d)
                    quad = [corners[0], corners[1], corners[2], corners[0], corners[2], corners[3]]
                    # wind so the face points along its normal
                    e1, e2 = np.subtract(quad[1], quad[0]), np.subtract(quad[2], quad[0])
                    if np.dot(np.cross(e1, e2), normal) < 0:
                        quad = [quad[0], quad[2], quad[1], quad[3], quad[5], quad[4]]
                    out_pos += quad
                    out_col += [col] * 6
                    out_nrm += [normal] * 6
    p = np.array(out_pos, dtype=np.float64)
    return p, np.array(out_nrm, dtype=np.float64), np.array(out_col, dtype=np.float64), np.arange(len(p))


def optimise(src, out, effect):
    gltf, binary = load(src)
    nodes = gltf["nodes"]
    config = EFFECTS.get(effect, {})
    parent = {}
    for i, n in enumerate(nodes):
        for c in n.get("children", []):
            parent[c] = i
    name = {i: n.get("name") or f"node{i}" for i, n in enumerate(nodes)}
    roots = list(gltf["scenes"][gltf.get("scene", 0)]["nodes"])

    animated = {ch["target"]["node"] for a in gltf.get("animations", []) for ch in a["channels"]}
    scaled = {}  # node -> animations that carry a scale channel for it
    for ai, a in enumerate(gltf.get("animations", [])):
        for ch in a["channels"]:
            if ch["target"]["path"] == "scale":
                scaled.setdefault(ch["target"]["node"], set()).add(ai)

    # anchors whose rest scale hides them: rest at full size from here on
    unhidden = {}
    for i in animated:
        s = nodes[i].get("scale")
        if s and max(abs(v) for v in s) < TINY:
            unhidden[i] = list(s)

    world = {}

    def world_of(i):
        if i not in world:
            m = local(nodes[i], [1, 1, 1] if i in unhidden else None)
            world[i] = world_of(parent[i]) @ m if i in parent else m
        return world[i]

    anchors = set(animated) | set(roots)
    for i in range(len(nodes)):
        if name[i] in config.get("split", []):
            anchors.add(i)
        if i in parent and name[parent[i]] in config.get("split_children", []):
            anchors.add(i)

    def anchor_of(i):
        while i not in anchors:
            i = parent[i]
        return i

    keep = config.get("keep")

    def piece_of(i):
        # a mesh belongs to a piece when it or any node above it is named so
        while i is not None:
            for piece, prefixes in keep.items():
                if any(name[i].startswith(p) for p in prefixes):
                    return piece
            i = parent.get(i)
        return None

    # gather triangles per (anchor or piece, group)
    groups = {}
    materials = gltf.get("materials", [])
    for i, n in enumerate(nodes):
        if "mesh" not in n:
            continue
        if keep is not None:
            owner = piece_of(i)
            if owner is None:
                continue
            to_owner = world_of(i)
        else:
            owner = anchor_of(i)
            w = world_of(i)
            wa = world_of(owner)
            if abs(np.linalg.det(wa[:3, :3])) < 1e-12:
                continue  # an anchor that is never seen
            to_owner = np.linalg.inv(wa) @ w
        if abs(np.linalg.det(to_owner[:3, :3])) < 1e-15:
            continue  # a piece resting at zero size under a still parent: never drawn
        normal_m = np.linalg.inv(to_owner[:3, :3]).T
        for prim in gltf["meshes"][n["mesh"]]["primitives"]:
            if prim.get("mode", 4) != 4:
                continue
            attrs = prim["attributes"]
            pos = read(gltf, binary, attrs["POSITION"])
            idx = (
                read(gltf, binary, prim["indices"]).astype(np.int64).ravel()
                if "indices" in prim
                else np.arange(len(pos))
            )
            mat = materials[prim["material"]] if "material" in prim else {}
            pbr = mat.get("pbrMetallicRoughness", {})
            base = np.array(pbr.get("baseColorFactor", [1, 1, 1, 1]), dtype=float)
            strength = mat.get("extensions", {}).get("KHR_materials_emissive_strength", {}).get("emissiveStrength", 1)
            emissive = np.array(mat.get("emissiveFactor", [0, 0, 0]), dtype=float) * strength
            colour = np.tile(base, (len(pos), 1))
            if "COLOR_0" in attrs:
                vc = read(gltf, binary, attrs["COLOR_0"])
                if vc.shape[1] == 3:
                    vc = np.hstack([vc, np.ones((len(vc), 1))])
                colour = colour * vc
            # the glow is added to the colour, as tools/imports_to_luau.py does
            colour[:, :3] = np.minimum(colour[:, :3] + emissive, 1)
            alpha = float(np.round(colour[:, 3].mean() / ALPHA_STEP) * ALPHA_STEP) if mat.get("alphaMode") == "BLEND" else 1.0
            # Neon by the importer's own rule (NEON_GLOW); a faint tint is just colour
            glow = emissive.max() >= NEON_GLOW
            if glow:
                tint = tuple(np.round(colour[:, :3].mean(axis=0) * GLOW_STEPS) / GLOW_STEPS)
                key = (owner, "glow", tint, alpha)
            else:
                key = (owner, "plain", None, alpha)
            nr = read(gltf, binary, attrs["NORMAL"]) if "NORMAL" in attrs else None
            if name[i] in config.get("voxel", []):
                pos, nr, colour, idx = voxel_rebuild(pos[idx], nr[idx] if nr is not None else None, colour[idx], config["step"])
            p = (to_owner @ np.hstack([pos, np.ones((len(pos), 1))]).T).T[:, :3]
            g = groups.setdefault(key, {"pos": [], "nrm": [], "col": [], "idx": [], "count": 0})
            g["pos"].append(p)
            if nr is not None:
                nr = nr @ normal_m.T
                nr /= np.maximum(np.linalg.norm(nr, axis=1, keepdims=True), 1e-12)
                g["nrm"].append(nr)
            else:
                g["nrm"].append(None)
            g["col"].append(colour)
            g["idx"].append(idx + g["count"])
            g["count"] += len(pos)

    # the new tree
    if keep is not None:
        out_nodes = [{"name": name[roots[0]], "children": []}]
        owner_index = {}
        for piece in keep:
            centre = None
            parts = [k for k in groups if k[0] == piece]
            if not parts:
                print(f"  warning: no meshes for piece {piece}")
                continue
            allp = np.vstack([p for k in parts for p in groups[k]["pos"]])
            centre = (allp.min(axis=0) + allp.max(axis=0)) / 2
            shift = np.array(config.get("offset", {}).get(piece, [0, 0, 0]), dtype=float)
            for k in parts:
                groups[k]["pos"] = [p - centre + shift for p in groups[k]["pos"]]
            owner_index[piece] = len(out_nodes)
            out_nodes[0]["children"].append(len(out_nodes))
            # part names must be unique across effects: imports are matched by them
            out_nodes.append({"name": f"{name[roots[0]]}_{piece}", "children": []})
        new_roots = [0]
        remap = {}
    else:
        # keep every node on a path to an anchor that holds geometry or moves
        needed = set()
        for key in groups:
            needed.add(key[0])
        needed |= animated
        keep_nodes = set()
        for i in needed:
            while i is not None:
                keep_nodes.add(i)
                i = parent.get(i)
        remap = {}
        order = []

        def visit(i):
            if i in keep_nodes:
                remap[i] = len(order)
                order.append(i)
                for c in nodes[i].get("children", []):
                    visit(c)

        for r in roots:
            visit(r)
        out_nodes = []
        for i in order:
            n = {k: v for k, v in nodes[i].items() if k not in ("mesh", "children")}
            if i in unhidden:
                n["scale"] = [1, 1, 1]
            kids = [remap[c] for c in nodes[i].get("children", []) if c in remap]
            if kids:
                n["children"] = kids
            out_nodes.append(n)
        owner_index = {i: remap[i] for i in needed if i in remap}
        new_roots = [remap[r] for r in roots if r in remap]

    # write buffers
    blob = bytearray()
    views, accessors, meshes, mats = [], [], [], []

    def add(array, ctype, atype, target=None, minmax=False):
        array = np.ascontiguousarray(array)
        while len(blob) % 4:
            blob.append(0)
        views.append({"buffer": 0, "byteOffset": len(blob), "byteLength": array.nbytes, **({"target": target} if target else {})})
        blob.extend(array.tobytes())
        acc = {"bufferView": len(views) - 1, "componentType": ctype, "count": len(array), "type": atype}
        if minmax:
            acc["min"] = array.min(axis=0).tolist()
            acc["max"] = array.max(axis=0).tolist()
        accessors.append(acc)
        return len(accessors) - 1

    per_owner = {}
    culled = [0]

    def owner_name(owner):
        return owner if isinstance(owner, str) else name[owner]

    for key, g in groups.items():
        owner, kind, tint, alpha = key
        if owner not in owner_index:
            continue
        pos = np.vstack(g["pos"]).astype(np.float32)
        col = np.vstack(g["col"]).astype(np.float32)
        idx = np.concatenate(g["idx"]).astype(np.uint32)
        nrm = np.vstack(g["nrm"]).astype(np.float32) if all(n is not None for n in g["nrm"]) else None
        before = len(idx) // 3
        pos, col, nrm, idx = cull_hidden(pos, col, nrm, idx)
        if before - len(idx) // 3:
            culled[0] += before - len(idx) // 3
        if len(idx) // 3 > BUDGET:
            print(f"  note: {owner_name(owner)} is {len(idx) // 3} triangles, over {BUDGET}")
        attrs = {"POSITION": add(pos, 5126, "VEC3", 34962, True)}
        if nrm is not None:
            attrs["NORMAL"] = add(nrm, 5126, "VEC3", 34962)
        material = {"pbrMetallicRoughness": {"metallicFactor": 0, "roughnessFactor": 1}}
        if kind == "glow":
            # base black and the whole colour as emission, so the importer's
            # base + glow comes back to the colour, and reads as Neon
            material["pbrMetallicRoughness"]["baseColorFactor"] = [0, 0, 0, alpha]
            material["emissiveFactor"] = list(tint)
        else:
            col[:, 3] = 1
            attrs["COLOR_0"] = add(col, 5126, "VEC4", 34962)
            material["pbrMetallicRoughness"]["baseColorFactor"] = [1, 1, 1, alpha]
        if alpha < 1:
            material["alphaMode"] = "BLEND"
        mats.append(material)
        meshes.append({"primitives": [{"attributes": attrs, "indices": add(idx, 5125, "SCALAR", 34963), "material": len(mats) - 1}]})
        per_owner.setdefault(owner, []).append((kind, len(meshes) - 1))

    for owner, list_ in per_owner.items():
        oi = owner_index[owner]
        base = out_nodes[oi]["name"]
        for n_, (kind, mi) in enumerate(list_):
            out_nodes[oi].setdefault("children", []).append(len(out_nodes))
            # named for the effect too: imports are matched to effects by part names
            kind_name = "Glow" if kind == "glow" else "Mesh"
            out_nodes.append({"name": f"{effect}_{base}_{kind_name}{n_ + 1}", "mesh": mi})

    # animations, retargeted; hidden anchors held at their old size
    anims = []
    if keep is None:
        for ai, a in enumerate(gltf.get("animations", [])):
            channels, samplers = [], []
            for ch in a["channels"]:
                t = ch["target"]["node"]
                if t not in remap:
                    continue
                s = a["samplers"][ch["sampler"]]
                ins = add(read(gltf, binary, s["input"]).astype(np.float32), 5126, "SCALAR", None, True)
                outs = read(gltf, binary, s["output"]).astype(np.float32)
                o = add(outs, 5126, gltf["accessors"][s["output"]]["type"])
                samplers.append({"input": ins, "output": o, "interpolation": s.get("interpolation", "LINEAR")})
                channels.append({"sampler": len(samplers) - 1, "target": {"node": remap[t], "path": ch["target"]["path"]}})
            for i, old in unhidden.items():
                if ai in scaled.get(i, set()) or i not in remap:
                    continue
                ins = add(np.array([[0.0]], np.float32), 5126, "SCALAR", None, True)
                o = add(np.array([old], np.float32), 5126, "VEC3")
                samplers.append({"input": ins, "output": o, "interpolation": "STEP"})
                channels.append({"sampler": len(samplers) - 1, "target": {"node": remap[i], "path": "scale"}})
            anims.append({"name": a.get("name"), "channels": channels, "samplers": samplers})

    out_gltf = {
        "asset": {"version": "2.0", "generator": "optimise_effect.py"},
        "scene": 0,
        "scenes": [{"nodes": new_roots}],
        "nodes": out_nodes,
        "meshes": meshes,
        "materials": mats,
        "accessors": accessors,
        "bufferViews": views,
        "buffers": [{"byteLength": len(blob)}],
    }
    if anims:
        out_gltf["animations"] = anims
    js = json.dumps(out_gltf, separators=(",", ":")).encode()
    js += b" " * (-len(js) % 4)
    while len(blob) % 4:
        blob.append(0)
    total = 12 + 8 + len(js) + 8 + len(blob)
    data = struct.pack("<III", 0x46546C67, 2, total) + struct.pack("<II", len(js), 0x4E4F534A) + js
    data += struct.pack("<II", len(blob), 0x004E4942) + bytes(blob)
    pathlib.Path(out).write_bytes(data)
    before = sum(1 for n in nodes if "mesh" in n)
    print(
        f"{effect:16} {before:4} meshes -> {len(meshes):3}"
        + (f"  (unhid {len(unhidden)})" if unhidden else "")
        + (f"  (culled {culled[0]} buried triangles)" if culled[0] else "")
    )
    return len(meshes)


def main():
    if sys.argv[1] == "--all":
        src, dst = pathlib.Path(sys.argv[2]), pathlib.Path(sys.argv[3])
        dst.mkdir(parents=True, exist_ok=True)
        for p in sorted(src.glob("fx_*.glb")):
            optimise(p, dst / p.name, p.stem[3:])
    else:
        optimise(sys.argv[1], sys.argv[2], sys.argv[3])


if __name__ == "__main__":
    main()
