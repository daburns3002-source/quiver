"""Ready the golden weapons' Tripo exports for the owner's Studio import.

    python -I assets/models/weapons/blocky/golden/fix_glb.py <exports dir> <out dir>

Reads gold_golden_{bow,staff,blade}.glb (Tripo's exports, 2,000 triangles,
2K texture) and writes GoldenBow.glb, GoldenStaff.glb and GoldenBlade.glb,
each with its scene and root node named for the Import Queue.

The bow's string is rebuilt (owner, 2026-11-14: "the string on the tripo
model is trash"): Tripo drew it as a ragged web hanging off the top limb,
so every triangle of it is taken out and a straight square bar is put in
from tip to tip, thick enough to read as a string from the run's camera
("make the bow string thicker") and coloured by one texel of the limbs'
own gold.
"""

import io
import json
import pathlib
import struct
import sys

import numpy as np
from PIL import Image

NAMES = {"bow": "GoldenBow", "staff": "GoldenStaff", "blade": "GoldenBlade"}
# The bow, in its own units (0.977 long, limbs on -x): the limbs stay left
# of LIMB between the tips, the string ran right of it.
LIMB = 0.07
TIPS = (0.16, 0.84)
# The new string: where it runs, how far into each tip block, how thick.
STRING_ENDS = (0.125, 0.875)
STRING_SIDE = 0.03

DTYPES = {5126: np.float32, 5123: np.uint16, 5125: np.uint32, 5121: np.uint8}
WIDTH = {"SCALAR": 1, "VEC2": 2, "VEC3": 3, "VEC4": 4}


def read(path: pathlib.Path):
    raw = path.read_bytes()
    size = struct.unpack("<I", raw[12:16])[0]
    doc = json.loads(raw[20 : 20 + size])
    length = struct.unpack("<I", raw[20 + size : 24 + size])[0]
    return doc, bytearray(raw[28 + size : 28 + size + length])


def accessor(doc, blob, index):
    a = doc["accessors"][index]
    view = doc["bufferViews"][a["bufferView"]]
    start = view.get("byteOffset", 0) + a.get("byteOffset", 0)
    n = WIDTH[a["type"]]
    return np.frombuffer(bytes(blob), DTYPES[a["componentType"]], a["count"] * n, start).reshape(-1, n)


def append(doc, blob, data: np.ndarray, kind: str, component: int, target=None) -> int:
    while len(blob) % 4:
        blob.append(0)
    view = {"buffer": 0, "byteOffset": len(blob), "byteLength": data.nbytes}
    if target:
        view["target"] = target
    blob.extend(data.tobytes())
    doc["bufferViews"].append(view)
    entry = {
        "bufferView": len(doc["bufferViews"]) - 1,
        "componentType": component,
        "count": len(data) if data.ndim > 1 else data.size,
        "type": kind,
    }
    if kind == "VEC3" and component == 5126:
        entry["min"] = [float(v) for v in data.min(0)]
        entry["max"] = [float(v) for v in data.max(0)]
    doc["accessors"].append(entry)
    return len(doc["accessors"]) - 1


def bar(x: float, y0: float, y1: float, side: float):
    """A square bar along y, centred on (x, z = 0): 24 corners, 12 triangles."""
    h = side / 2
    lo, hi = np.array([x - h, y0, -h]), np.array([x + h, y1, h])
    corners, normals, faces = [], [], []
    for axis in range(3):
        for sign in (-1, 1):
            u, v = [a for a in range(3) if a != axis]
            quad = []
            for du, dv in ((0, 0), (1, 0), (1, 1), (0, 1)):
                p = np.zeros(3)
                p[axis] = hi[axis] if sign > 0 else lo[axis]
                p[u] = hi[u] if du else lo[u]
                p[v] = hi[v] if dv else lo[v]
                quad.append(p)
            n = np.zeros(3)
            n[axis] = sign
            # wind so the face looks along its normal
            if np.dot(np.cross(quad[1] - quad[0], quad[2] - quad[0]), n) < 0:
                quad.reverse()
            base = len(corners)
            corners += quad
            normals += [n] * 4
            faces += [[base, base + 1, base + 2], [base, base + 2, base + 3]]
    return np.array(corners, np.float32), np.array(normals, np.float32), np.array(faces, np.uint32)


def gold_texel(doc, blob, pos, uv):
    """The UV of the limb vertex whose colour is the limbs' usual bright gold."""
    material = doc["materials"][doc["meshes"][0]["primitives"][0]["material"]]
    texture = doc["textures"][material["pbrMetallicRoughness"]["baseColorTexture"]["index"]]
    view = doc["bufferViews"][doc["images"][texture["source"]]["bufferView"]]
    start = view.get("byteOffset", 0)
    image = Image.open(io.BytesIO(bytes(blob[start : start + view["byteLength"]]))).convert("RGB")
    pixels = np.asarray(image).astype(np.float32)
    h, w, _ = pixels.shape
    limb = np.flatnonzero(pos[:, 0] < -LIMB)
    px = np.clip((uv[limb, 0] % 1) * w, 0, w - 1).astype(int)
    py = np.clip((uv[limb, 1] % 1) * h, 0, h - 1).astype(int)
    colours = pixels[py, px]
    # gold: red and green high, blue low; the brighter half of those
    gold = (colours[:, 0] > 180) & (colours[:, 1] > 140) & (colours[:, 2] < 110)
    assert gold.sum() > 20, "no gold found on the limbs"
    target = np.percentile(colours[gold], 75, axis=0)
    best = np.linalg.norm(colours - target, axis=1)
    best[~gold] = np.inf
    pick = limb[best.argmin()]
    print("  gold texel", colours[best.argmin()].astype(int).tolist())
    return uv[pick]


def restring(doc, blob):
    prim = doc["meshes"][0]["primitives"][0]
    pos = accessor(doc, blob, prim["attributes"]["POSITION"])
    nrm = accessor(doc, blob, prim["attributes"]["NORMAL"])
    uv = accessor(doc, blob, prim["attributes"]["TEXCOORD_0"])
    tris = accessor(doc, blob, prim["indices"]).reshape(-1, 3).astype(np.uint32)
    stringy = (pos[:, 0] > LIMB) & (pos[:, 1] > TIPS[0]) & (pos[:, 1] < TIPS[1])
    drop = stringy[tris].any(1)
    assert 4 <= drop.sum() <= 400, f"{drop.sum()} string triangles"
    ids = np.flatnonzero(stringy)
    x = float(np.median(pos[ids, 0]))
    top = float(pos[:, 1].max())
    corners, normals, faces = bar(x, STRING_ENDS[0] * top, STRING_ENDS[1] * top, STRING_SIDE)
    all_pos = np.vstack([pos, corners]).astype(np.float32)
    all_nrm = np.vstack([nrm, normals]).astype(np.float32)
    all_uv = np.vstack([uv, np.tile(gold_texel(doc, blob, pos, uv), (len(corners), 1))]).astype(np.float32)
    all_tris = np.vstack([tris[~drop], faces + len(pos)]).astype(np.uint32)
    prim["attributes"]["POSITION"] = append(doc, blob, all_pos, "VEC3", 5126, 34962)
    prim["attributes"]["NORMAL"] = append(doc, blob, all_nrm, "VEC3", 5126, 34962)
    prim["attributes"]["TEXCOORD_0"] = append(doc, blob, all_uv, "VEC2", 5126, 34962)
    prim["indices"] = append(doc, blob, all_tris.reshape(-1), "SCALAR", 5125, 34963)
    print(f"  string: {int(drop.sum())} triangles out, a bar in at x = {x:.3f}")


def write(path: pathlib.Path, doc, blob):
    while len(blob) % 4:
        blob.append(0)
    doc["buffers"][0]["byteLength"] = len(blob)
    text = json.dumps(doc, separators=(",", ":")).encode()
    text += b" " * (-len(text) % 4)
    total = 12 + 8 + len(text) + 8 + len(blob)
    with path.open("wb") as out:
        out.write(struct.pack("<4sII", b"glTF", 2, total))
        out.write(struct.pack("<I4s", len(text), b"JSON") + text)
        out.write(struct.pack("<I4s", len(blob), b"BIN\x00") + bytes(blob))


def main():
    source, target = pathlib.Path(sys.argv[1]), pathlib.Path(sys.argv[2])
    target.mkdir(parents=True, exist_ok=True)
    for stem, name in NAMES.items():
        doc, blob = read(source / f"gold_golden_{stem}.glb")
        print(name)
        if stem == "bow":
            restring(doc, blob)
        for scene in doc.get("scenes", []):
            scene["name"] = name
        doc["nodes"][doc["scenes"][0]["nodes"][0]]["name"] = name
        doc["meshes"][0]["name"] = name
        write(target / f"{name}.glb", doc, blob)


if __name__ == "__main__":
    main()
