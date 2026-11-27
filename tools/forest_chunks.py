"""Merge an area's outer forest into a few chunks, so a room draws it in
about ten draws instead of one per tree (docs/PERFORMANCE.md, option 2,
owner 2026-11-27; the outer trees stop being separate, so they can never
sway one by one).

    python -I tools/forest_chunks.py build glade      # -> ~/Downloads/forest_chunks/glade_chunks.glb
    python -I tools/forest_chunks.py luau <ids.json>  # -> src/shared/Config/ForestChunks.luau

`build` reads the forest as the game draws it today (its per-part config,
`Config/GladeForest` and the rest, the layout tools/forest_to_luau.py wrote)
and the GLB the owner imported it from. Every part is matched to its piece
of the GLB by size and place, so the chunks carry exactly the triangles,
normals and vertex colours the game draws now, at the places the config
puts them (the glade's trees were pushed apart a little by
forest_to_luau's `separate`; the match carries that shift).

Parts are merged by how Arena draws them: plain (SmoothPlastic), matte
(Fabric) and each glow tint (Neon). Within one kind, the parts are split
by place, in halves along the longer side, until each chunk holds at most
19,000 triangles and 60,000 vertices (Roblox takes 20,000 triangles a
mesh).

Each chunk is a node at the origin with its mesh in the room's frame, so it
can be uploaded as it is (Open Cloud, a Model from the .glb) or imported
with File > Import 3D. `luau` then reads `{chunk name: [meshId, size]}`,
the mesh ids and sizes read back in Studio, and writes the chunks' config:
each chunk's offset is the centre of its own box, and the turn Arena gives
every mesh is the importer's own 180 degrees.
"""
import json
import pathlib
import re
import struct
import sys

import numpy as np

ROOT = pathlib.Path(__file__).resolve().parent.parent
OUT_DIR = ROOT / "assets/models/arenas/forest_chunks"
TARGET = ROOT / "src/shared/Config/ForestChunks.luau"
# The chunks' GLBs, rebuilt on demand (not kept in git): by default where
# Studio's Open Cloud uploads may read them (Downloads, approved by the
# owner 2026-11-27); `build --glbs <dir>` puts them elsewhere.
GLB_DIR = pathlib.Path.home() / "Downloads" / "forest_chunks"

FORESTS = {
    "glade": {
        "key": "Glade",
        "config": "src/shared/Config/GladeForest.luau",
        # What the owner imported on 2026-10-24 (docs/arenas/mossy-glade-outer.md),
        # copied here so the chunks can be rebuilt.
        "glb": "assets/models/arenas/mossy_glade_outer_arena.glb",
    },
    "thornwood": {
        "key": "Thornwood",
        "config": "src/shared/Config/ThornwoodForest.luau",
        "glb": "assets/models/arenas/thornwood_outer_arena_roblox.glb",
    },
    "drowned": {
        "key": "Drowned",
        "config": "src/shared/Config/DrownedForest.luau",
        "glb": "assets/models/arenas/drowned_village_outer_arena_roblox.glb",
    },
    "bogheart": {
        "key": "Bogheart",
        "config": "src/shared/Config/BogheartForest.luau",
        "glb": "assets/models/arenas/bogheart_caverns_outer_arena_roblox.glb",
    },
}

MAX_TRIS = 19000
MAX_VERTS = 60000
# A part and its GLB piece: sizes within this, centres within MAX_SHIFT
# (the glade's `separate` moved trees by up to about a stud).
SIZE_TOL = 0.02
MAX_SHIFT = 1.5
# A crown's footprint as ForestAmbience reads it from a CanopyMesh part.
CROWN_PREFIX = "CanopyMesh"

# ---------------------------------------------------------------- GLB in

COMP = {5120: np.int8, 5121: np.uint8, 5122: np.int16, 5123: np.uint16, 5125: np.uint32, 5126: np.float32}
WIDTH = {"SCALAR": 1, "VEC2": 2, "VEC3": 3, "VEC4": 4, "MAT4": 16}


def read_glb(path):
    data = pathlib.Path(path).read_bytes()
    off, js, binary = 12, None, b""
    while off < len(data):
        length, kind = struct.unpack_from("<II", data, off)
        chunk = data[off + 8 : off + 8 + length]
        if kind == 0x4E4F534A:
            js = json.loads(chunk)
        elif kind == 0x004E4942:
            binary = chunk
        off += 8 + length
    return js, binary


def accessor(g, binary, index):
    a = g["accessors"][index]
    view = g["bufferViews"][a["bufferView"]]
    dtype = np.dtype(COMP[a["componentType"]])
    width = WIDTH[a["type"]]
    start = view.get("byteOffset", 0) + a.get("byteOffset", 0)
    stride = view.get("byteStride", 0) or dtype.itemsize * width
    count = a["count"]
    raw = np.frombuffer(binary, dtype=np.uint8, count=stride * (count - 1) + dtype.itemsize * width, offset=start)
    rows = np.lib.stride_tricks.as_strided(raw, shape=(count, dtype.itemsize * width), strides=(stride, 1))
    out = np.ascontiguousarray(rows).view(dtype).reshape(count, width)
    return out, a


def colours(g, binary, index, count):
    if index is None:
        return np.ones((count, 4), np.float32)
    values, a = accessor(g, binary, index)
    values = values.astype(np.float64)
    if a["componentType"] == 5121:
        values /= 255.0
    elif a["componentType"] == 5123:
        values /= 65535.0
    if values.shape[1] == 3:
        values = np.hstack([values, np.ones((len(values), 1))])
    return values.astype(np.float32)


def local_matrix(node):
    if "matrix" in node:
        return np.array(node["matrix"], np.float64).reshape(4, 4).T
    t = np.array(node.get("translation", [0, 0, 0]), np.float64)
    x, y, z, w = node.get("rotation", [0, 0, 0, 1])
    s = np.array(node.get("scale", [1, 1, 1]), np.float64)
    r = np.array(
        [
            [1 - 2 * (y * y + z * z), 2 * (x * y - z * w), 2 * (x * z + y * w)],
            [2 * (x * y + z * w), 1 - 2 * (x * x + z * z), 2 * (y * z - x * w)],
            [2 * (x * z - y * w), 2 * (y * z + x * w), 1 - 2 * (x * x + y * y)],
        ]
    )
    m = np.eye(4)
    m[:3, :3] = r * s
    m[:3, 3] = t
    return m


def pieces(path):
    """Every primitive of every mesh node, in world space."""
    g, binary = read_glb(path)
    nodes = g["nodes"]
    scene = g["scenes"][g.get("scene", 0)]
    out = []

    def walk(i, parent):
        node = nodes[i]
        world = parent @ local_matrix(node)
        if "mesh" in node:
            normal_m = np.linalg.inv(world[:3, :3]).T
            for p in g["meshes"][node["mesh"]]["primitives"]:
                pos, _ = accessor(g, binary, p["attributes"]["POSITION"])
                pos = pos.astype(np.float64) @ world[:3, :3].T + world[:3, 3]
                nrm, _ = accessor(g, binary, p["attributes"]["NORMAL"])
                nrm = nrm.astype(np.float64) @ normal_m.T
                nrm /= np.maximum(np.linalg.norm(nrm, axis=1, keepdims=True), 1e-12)
                col = colours(g, binary, p["attributes"].get("COLOR_0"), len(pos))
                if "indices" in p:
                    idx, _ = accessor(g, binary, p["indices"])
                    idx = idx.reshape(-1).astype(np.int64)
                else:
                    idx = np.arange(len(pos), dtype=np.int64)
                if np.linalg.det(world[:3, :3]) < 0:
                    idx = idx.reshape(-1, 3)[:, ::-1].reshape(-1)
                used = np.unique(idx)
                lo, hi = pos[used].min(0), pos[used].max(0)
                out.append(
                    {
                        "node": node.get("name", ""),
                        "pos": pos,
                        "nrm": nrm,
                        "col": col,
                        "idx": idx,
                        "centre": (lo + hi) / 2,
                        "size": hi - lo,
                    }
                )
        for c in node.get("children", []):
            walk(c, world)

    for root in scene["nodes"]:
        walk(root, np.eye(4))
    return out


# ---------------------------------------------------------------- config in

NUM = r"(-?[\d.]+)"
VEC = rf"Vector3\.new\({NUM}, {NUM}, {NUM}\)"


def config_parts(path):
    text = (ROOT / path).read_text(encoding="utf-8")
    parts = []
    for block in re.findall(r"\t\{\n(.*?)\n\t\},", text, re.S):
        name = re.search(r'name = "([^"]+)"', block).group(1)
        size = [float(v) for v in re.search(rf"size = {VEC}", block).groups()]
        offset = [float(v) for v in re.search(rf"offset = {VEC}", block).groups()]
        tint = re.search(r"tint = Color3\.fromRGB\((\d+), (\d+), (\d+)\)", block)
        parts.append(
            {
                "name": name,
                "size": np.array(size),
                "offset": np.array(offset),
                "glow": "glow = true" in block,
                "matte": "matte = true" in block,
                "tint": tuple(int(v) for v in tint.groups()) if tint else None,
            }
        )
    return parts


def kind_of(part):
    if part["glow"]:
        return "Glow_{}_{}_{}".format(*(part["tint"] or (255, 255, 255)))
    return "Matte" if part["matte"] else "Plain"


# ---------------------------------------------------------------- matching


def match(parts, found):
    """Each config part's GLB piece: same size, nearest centre, each used once."""
    pairs = []
    for i, part in enumerate(parts):
        for j, piece in enumerate(found):
            if np.all(np.abs(piece["size"] - part["size"]) <= SIZE_TOL):
                d = float(np.linalg.norm(piece["centre"] - part["offset"]))
                if d <= MAX_SHIFT:
                    pairs.append((d, i, j))
    pairs.sort()
    taken_i, taken_j, chosen = set(), set(), {}
    for d, i, j in pairs:
        if i in taken_i or j in taken_j:
            continue
        taken_i.add(i)
        taken_j.add(j)
        chosen[i] = (j, d)
    missing = [parts[i]["name"] for i in range(len(parts)) if i not in chosen]
    if missing:
        raise SystemExit(f"no GLB piece for {len(missing)} parts: {missing[:10]}")
    return chosen


# ---------------------------------------------------------------- chunks


def split(items, tris_of, verts_of, pieces=None):
    """Cuts a kind into the fewest chunks that fit a mesh: across the longer
    side, at the share of triangles each side gets, again and again."""
    tris = sum(tris_of(it) for it in items)
    verts = sum(verts_of(it) for it in items)
    if pieces is None:
        pieces = max(-(-tris // int(MAX_TRIS * 0.9)), -(-verts // int(MAX_VERTS * 0.9)), 1)
    if pieces <= 1 or len(items) == 1:
        if (tris > MAX_TRIS or verts > MAX_VERTS) and len(items) > 1:
            return split(items, tris_of, verts_of, 2)
        return [items]
    centres = np.array([it["at"] for it in items])
    spread = centres.max(0) - centres.min(0)
    axis = 0 if spread[0] >= spread[2] else 2
    items = sorted(items, key=lambda it: it["at"][axis])
    left = pieces // 2
    goal = tris * left / pieces
    running, cut = 0, len(items) // 2
    for k, it in enumerate(items):
        running += tris_of(it)
        if running >= goal:
            cut = max(1, min(len(items) - 1, k + 1 if running - goal < tris_of(it) / 2 else k))
            break
    return split(items[:cut], tris_of, verts_of, left) + split(items[cut:], tris_of, verts_of, pieces - left)


def weld(pos, nrm, col, idx):
    """Shares vertices that are the same in place, normal and colour."""
    key = np.round(np.hstack([pos * 1e4, nrm * 1e4, col * 1e5])).astype(np.int64)
    _, first, inverse = np.unique(key, axis=0, return_index=True, return_inverse=True)
    return pos[first], nrm[first], col[first], inverse.reshape(-1)[idx]


def build(forest_name):
    forest = FORESTS[forest_name]
    parts = config_parts(forest["config"])
    found = pieces(ROOT / forest["glb"])
    chosen = match(parts, found)
    worst = max(d for _, d in chosen.values())
    print(f"{forest_name}: {len(parts)} parts matched to {len(found)} GLB pieces, furthest shift {worst:.3f}")

    items = []
    for i, part in enumerate(parts):
        piece = found[chosen[i][0]]
        shift = part["offset"] - piece["centre"]
        used = np.unique(piece["idx"])
        remap = np.full(len(piece["pos"]), -1, np.int64)
        remap[used] = np.arange(len(used))
        items.append(
            {
                "part": part,
                "kind": kind_of(part),
                "at": part["offset"],
                "pos": piece["pos"][used] + shift,
                "nrm": piece["nrm"][used],
                "col": piece["col"][used],
                "idx": remap[piece["idx"]],
            }
        )

    chunks = []
    glows = sorted({it["kind"] for it in items if it["kind"].startswith("Glow")})
    for kind in sorted({it["kind"] for it in items}):
        label = kind if not kind.startswith("Glow") else "Glow" + ("" if glows.index(kind) == 0 else str(glows.index(kind) + 1))
        group = [it for it in items if it["kind"] == kind]
        for n, members in enumerate(split(group, lambda it: len(it["idx"]) // 3, lambda it: len(it["pos"])), 1):
            pos, nrm, col, idx, base = [], [], [], [], 0
            for it in members:
                pos.append(it["pos"])
                nrm.append(it["nrm"])
                col.append(it["col"])
                idx.append(it["idx"] + base)
                base += len(it["pos"])
            p, nm, c, ix = weld(np.vstack(pos), np.vstack(nrm), np.vstack(col), np.concatenate(idx))
            lo, hi = p.min(0), p.max(0)
            first = members[0]["part"]
            chunks.append(
                {
                    "name": f"{forest['key']}{label}_{n}",
                    "kind": kind,
                    "glow": first["glow"],
                    "matte": first["matte"],
                    "tint": first["tint"],
                    "pos": p.astype(np.float32),
                    "nrm": nm.astype(np.float32),
                    "col": c.astype(np.float32),
                    "idx": ix.astype(np.uint32),
                    "centre": (lo + hi) / 2,
                    "size": hi - lo,
                    "members": [it["part"]["name"] for it in members],
                }
            )
    tris = sum(len(c["idx"]) // 3 for c in chunks)
    before = sum(len(it["idx"]) // 3 for it in items)
    assert tris == before, (tris, before)
    for c in chunks:
        print(f"  {c['name']}: {len(c['idx']) // 3} tris, {len(c['pos'])} verts, {len(c['members'])} parts")
    print(f"  {len(parts)} parts -> {len(chunks)} chunks, {tris} triangles")

    OUT_DIR.mkdir(parents=True, exist_ok=True)
    GLB_DIR.mkdir(parents=True, exist_ok=True)
    out = GLB_DIR / f"{forest_name}_chunks.glb"
    write_glb(out, chunks)
    crowns = [
        {
            "x": float(p["offset"][0]),
            "z": float(p["offset"][2]),
            "reach": float(min(p["size"][0], p["size"][2])),
            "top": float(p["offset"][1] + p["size"][1] / 2),
        }
        for p in parts
        if p["name"].startswith(CROWN_PREFIX)
    ]
    layout = {
        "key": forest["key"],
        "chunks": [
            {
                "name": c["name"],
                "glow": c["glow"],
                "matte": c["matte"],
                "tint": c["tint"],
                "centre": [float(v) for v in c["centre"]],
                "size": [float(v) for v in c["size"]],
                "tris": len(c["idx"]) // 3,
                "members": c["members"],
            }
            for c in chunks
        ],
        "crowns": crowns,
    }
    (OUT_DIR / f"{forest_name}_chunks.json").write_text(json.dumps(layout, indent=1) + "\n", newline="\n")
    print(f"  wrote {out}")


# ---------------------------------------------------------------- GLB out


def write_glb(path, chunks):
    blob = bytearray()
    views, accessors, meshes, nodes = [], [], [], []

    def add(array, target, kind, comp, minmax=False):
        while len(blob) % 4:
            blob.append(0)
        data = array.tobytes()
        views.append({"buffer": 0, "byteOffset": len(blob), "byteLength": len(data), "target": target})
        blob.extend(data)
        acc = {"bufferView": len(views) - 1, "componentType": comp, "count": len(array), "type": kind}
        if minmax:
            acc["min"] = [float(v) for v in array.min(0)]
            acc["max"] = [float(v) for v in array.max(0)]
        accessors.append(acc)
        return len(accessors) - 1

    for c in chunks:
        attrs = {
            "POSITION": add(c["pos"], 34962, "VEC3", 5126, True),
            "NORMAL": add(c["nrm"], 34962, "VEC3", 5126),
            "COLOR_0": add(c["col"], 34962, "VEC4", 5126),
        }
        indices = add(c["idx"], 34963, "SCALAR", 5125)
        meshes.append({"name": c["name"], "primitives": [{"attributes": attrs, "indices": indices, "material": 0}]})
        nodes.append({"name": c["name"], "mesh": len(meshes) - 1})
    while len(blob) % 4:
        blob.append(0)
    gltf = {
        "asset": {"version": "2.0", "generator": "tools/forest_chunks.py"},
        "scene": 0,
        "scenes": [{"nodes": list(range(len(nodes)))}],
        "nodes": nodes,
        "meshes": meshes,
        "materials": [{"name": "Vertex", "pbrMetallicRoughness": {"baseColorFactor": [1, 1, 1, 1], "metallicFactor": 0, "roughnessFactor": 1}}],
        "accessors": accessors,
        "bufferViews": views,
        "buffers": [{"byteLength": len(blob)}],
    }
    js = json.dumps(gltf, separators=(",", ":")).encode()
    js += b" " * (-len(js) % 4)
    body = struct.pack("<II", len(js), 0x4E4F534A) + js + struct.pack("<II", len(blob), 0x004E4942) + bytes(blob)
    path.write_bytes(struct.pack("<III", 0x46546C67, 2, 12 + len(body)) + body)


# ---------------------------------------------------------------- config out


def num(v):
    s = f"{v:.3f}"
    return "0.000" if s == "-0.000" else s


def vec(v):
    return f"Vector3.new({num(v[0])}, {num(v[1])}, {num(v[2])})"


def luau(ids_path):
    ids = json.loads(pathlib.Path(ids_path).read_text())
    out = [
        "--!strict",
        "--[[",
        "\tEvery area's outer forest merged into a few chunks (docs/PERFORMANCE.md,",
        "\toption 2, owner 2026-11-27): about ten draws a room instead of one per",
        "\ttree. Generated by tools/forest_chunks.py from each forest's layout",
        "\t(`Config/GladeForest` and the rest, which stay the record of every",
        "\tpart) and the chunks' uploaded mesh ids; regenerate, never hand-edit.",
        "",
        "\t`parts` are ArenaModels.ArenaPart, drawn as every outer part is;",
        "\t`crowns` are the trees' crowns the scenery's life settles on",
        "\t(`Fx/ForestAmbience`), which the merged meshes no longer name:",
        "\teach a crown's centre, its narrower side and the height of its top.",
        "]]",
        "",
        "type Part = {",
        "\tname: string,",
        "\tmeshId: string,",
        "\tsize: Vector3,",
        "\toffset: Vector3,",
        "\tglow: boolean?,",
        "\tmatte: boolean?,",
        "\ttint: Color3?,",
        "\t-- Unused here, but in ArenaModels.ArenaPart, which this must match.",
        "\twater: Color3?,",
        "\tbank: Color3?,",
        "}",
        "",
        "export type Crown = { x: number, z: number, reach: number, top: number }",
        "",
        "export type Forest = { parts: { Part }, crowns: { Crown } }",
        "",
        "local forests: { [string]: Forest } = {",
    ]
    for name in FORESTS:
        layout_path = OUT_DIR / f"{name}_chunks.json"
        if not layout_path.exists():
            continue
        layout = json.loads(layout_path.read_text())
        if not all(c["name"] in ids for c in layout["chunks"]):
            print(f"{name}: not every chunk uploaded yet, left out (drawn part by part)")
            continue
        out.append(f"\t{layout['key']} = {{")
        out.append("\t\tparts = {")
        for c in layout["chunks"]:
            if c["name"] not in ids:
                raise SystemExit(f"no mesh id for {c['name']}")
            mesh_id, size = ids[c["name"]]
            if max(abs(a - b) for a, b in zip(size, c["size"])) > 0.05:
                print(f"warning: {c['name']} uploaded at {size}, built at {c['size']}")
            out.append("\t\t\t{")
            out.append(f'\t\t\t\tname = "{c["name"]}",')
            out.append(f'\t\t\t\tmeshId = "{mesh_id}",')
            out.append(f"\t\t\t\tsize = {vec(c['size'])},")
            out.append(f"\t\t\t\toffset = {vec(c['centre'])},")
            if c["glow"]:
                out.append("\t\t\t\tglow = true,")
            if c["tint"]:
                out.append(f"\t\t\t\ttint = Color3.fromRGB({', '.join(map(str, c['tint']))}),")
            if c["matte"]:
                out.append("\t\t\t\tmatte = true,")
            out.append("\t\t\t},")
        out.append("\t\t},")
        out.append("\t\tcrowns = {")
        for cr in layout["crowns"]:
            out.append(f"\t\t\t{{ x = {num(cr['x'])}, z = {num(cr['z'])}, reach = {num(cr['reach'])}, top = {num(cr['top'])} }},")
        out.append("\t\t},")
        out.append("\t},")
    out.append("}")
    out.append("")
    out.append("return table.freeze(forests)")
    TARGET.write_text("\n".join(out) + "\n", newline="\n")
    print(f"wrote {TARGET.relative_to(ROOT)}")


if __name__ == "__main__":
    if sys.argv[1] == "build":
        names = sys.argv[2:]
        if names[:1] == ["--glbs"]:
            GLB_DIR = pathlib.Path(names[1])
            names = names[2:]
        for name in names or list(FORESTS):
            build(name)
    elif sys.argv[1] == "luau":
        luau(sys.argv[2])
