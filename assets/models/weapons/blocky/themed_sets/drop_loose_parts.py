"""Find, and optionally cut out, loose pieces floating apart from a Tripo model.

    python -I assets/models/weapons/blocky/themed_sets/drop_loose_parts.py <in.glb>            (list)
    python -I assets/models/weapons/blocky/themed_sets/drop_loose_parts.py <in.glb> <out.glb> <n> ...  (cut)

Tripo sometimes leaves a small piece floating free of the model: the Starwell
Staff (2026-11-18) came with a pale moon hanging loose behind its head, seen
only from the side. Faces are grouped into pieces by shared corner positions
(UV seams split vertices, so corners are matched by place, not index); listed
biggest first with each piece's box and its gap to the biggest. Cutting
rewrites only the index list, so the texture and the vertices stay as they
are (the GLB rewrite is fix_dagger_magenta.py's).
"""

import json
import pathlib
import struct
import sys

import numpy as np

KIND = {5121: np.uint8, 5123: np.uint16, 5125: np.uint32, 5126: np.float32}
WIDTH = {"SCALAR": 1, "VEC2": 2, "VEC3": 3, "VEC4": 4}


def read(path):
    raw = pathlib.Path(path).read_bytes()
    size = struct.unpack("<I", raw[12:16])[0]
    doc = json.loads(raw[20 : 20 + size])
    length = struct.unpack("<I", raw[20 + size : 24 + size])[0]
    return doc, raw[28 + size : 28 + size + length]


def accessor(doc, blob, index):
    a = doc["accessors"][index]
    view = doc["bufferViews"][a["bufferView"]]
    start = view.get("byteOffset", 0) + a.get("byteOffset", 0)
    count = a["count"] * WIDTH[a["type"]]
    data = np.frombuffer(blob, KIND[a["componentType"]], count, start)
    return data.reshape(a["count"], WIDTH[a["type"]]) if WIDTH[a["type"]] > 1 else data


def pieces(points, faces):
    key = {}
    weld = np.array([key.setdefault(tuple(np.round(p, 5)), len(key)) for p in points])
    parent = list(range(len(key)))

    def find(x):
        while parent[x] != x:
            parent[x] = parent[parent[x]]
            x = parent[x]
        return x

    for a, b, c in weld[faces]:
        ra, rb, rc = find(a), find(b), find(c)
        parent[rb] = ra
        parent[find(rc)] = ra
    root = np.array([find(weld[f[0]]) for f in faces])
    groups = {}
    for i, r in enumerate(root):
        groups.setdefault(r, []).append(i)
    return sorted(groups.values(), key=len, reverse=True)


def main():
    doc, blob = read(sys.argv[1])
    prim = doc["meshes"][0]["primitives"][0]
    points = accessor(doc, blob, prim["attributes"]["POSITION"])
    faces = accessor(doc, blob, prim["indices"]).reshape(-1, 3)
    groups = pieces(points, faces)
    main_box = points[faces[groups[0]].ravel()]
    lo, hi = main_box.min(0), main_box.max(0)
    for n, g in enumerate(groups[:12]):
        p = points[faces[g].ravel()]
        gap = np.maximum(0, np.maximum(lo - p.max(0), p.min(0) - hi))
        print(f"{n:2} faces {len(g):5}  min {np.round(p.min(0), 3)}  max {np.round(p.max(0), 3)}  gap {np.round(gap, 3)}")
    print(len(groups), "pieces")
    if len(sys.argv) < 4:
        return
    cut = {i for n in sys.argv[3:] for i in groups[int(n)]}
    keep = np.array([f for i, f in enumerate(faces) if i not in cut], dtype=np.uint32).ravel()
    index_view = doc["accessors"][prim["indices"]]["bufferView"]
    doc["accessors"][prim["indices"]].update(componentType=5125, count=int(keep.size), byteOffset=0)
    packed = keep.tobytes()
    out = bytearray()
    for i, each in enumerate(doc["bufferViews"]):
        data = packed if i == index_view else blob[each.get("byteOffset", 0) : each.get("byteOffset", 0) + each["byteLength"]]
        while len(out) % 4:
            out.append(0)
        each["byteOffset"] = len(out)
        each["byteLength"] = len(data)
        out.extend(data)
    while len(out) % 4:
        out.append(0)
    doc["buffers"][0]["byteLength"] = len(out)
    text = json.dumps(doc, separators=(",", ":")).encode()
    text += b" " * (-len(text) % 4)
    with open(sys.argv[2], "wb") as file:
        file.write(struct.pack("<4sII", b"glTF", 2, 12 + 8 + len(text) + 8 + len(out)))
        file.write(struct.pack("<I4s", len(text), b"JSON") + text)
        file.write(struct.pack("<I4s", len(out), b"BIN\x00") + bytes(out))
    print(f"cut {len(cut)} faces, kept {keep.size // 3}")


if __name__ == "__main__":
    main()
