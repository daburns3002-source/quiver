"""Ready a batch of Tripo exports for the Studio import.

    python -I assets/models/weapons/blocky/name_tripo_glb.py <jobs.json> <prefix> <exports dir> <out dir>

Reads the batch's jobs file (`thornwood_tripo_2026_11_18.json`: name ->
`key`, its `Config` name) and Tripo's exports `<prefix><name>.glb`, and
writes one GLB each under its key (`BoarTuskBow.glb`, ...), with its scene,
root node and mesh named, so Studio's Import Queue shows the weapon's name
and the whole folder goes through one Start Import.

Says for each what an import needs to be textured: UVs and an image
(memory: an export with no UVs can never be textured). The daggers' batch
has its own copy of this, `name_daggers_glb.py`.
"""

import json
import pathlib
import struct
import sys


def read(path):
    raw = path.read_bytes()
    size = struct.unpack("<I", raw[12:16])[0]
    return json.loads(raw[20 : 20 + size]), raw[20 + size :]


def write(path, doc, rest):
    text = json.dumps(doc, separators=(",", ":")).encode()
    text += b" " * (-len(text) % 4)
    with path.open("wb") as out:
        out.write(struct.pack("<4sII", b"glTF", 2, 12 + 8 + len(text) + len(rest)))
        out.write(struct.pack("<I4s", len(text), b"JSON") + text)
        out.write(rest)


def main():
    jobs = json.loads(pathlib.Path(sys.argv[1]).read_text(encoding="utf-8"))["jobs"]
    prefix, source, target = sys.argv[2], pathlib.Path(sys.argv[3]), pathlib.Path(sys.argv[4])
    target.mkdir(parents=True, exist_ok=True)
    for stem, job in jobs.items():
        key = job["key"]
        doc, rest = read(source / f"{prefix}{stem}.glb")
        for scene in doc.get("scenes", []):
            scene["name"] = key
        roots = doc["scenes"][0]["nodes"]
        if len(roots) == 1:
            doc["nodes"][roots[0]]["name"] = key
        if len(doc["meshes"]) == 1:
            doc["meshes"][0]["name"] = key
        write(target / f"{key}.glb", doc, rest)
        prims = [p for m in doc["meshes"] for p in m["primitives"]]
        uv = all("TEXCOORD_0" in p["attributes"] for p in prims)
        size = [0, 0, 0]
        tris = 0
        for p in prims:
            acc = doc["accessors"][p["attributes"]["POSITION"]]
            size = [max(s, hi - lo) for s, hi, lo in zip(size, acc["max"], acc["min"])]
            tris += doc["accessors"][p["indices"]]["count"] // 3
        print(
            f"{key:20} meshes {len(doc['meshes'])}  triangles {tris}  uv {uv}  "
            f"images {len(doc.get('images', []))}  size {[round(s, 3) for s in size]}"
        )


if __name__ == "__main__":
    main()
