"""Ready the Assassin's dagger models for the Studio import.

    python -I assets/models/weapons/blocky/name_daggers_glb.py <exports dir> <out dir>

Reads Tripo's exports of 2026-11-16 (`ad16_<name>.glb`; the jobs in
`daggers_tripo_2026_11_16.json`: the eleven new daggers under `jobs`, and
Mossy Glade's six and Bogheart's five, remade as one dagger each, under
`remake`) and writes one GLB each under its `Config` key
(`GoldenDaggers.glb`, `FireflyFangs.glb`, ...), with its scene, root node
and mesh named, so Studio's Import Queue shows the weapon's name and the
whole folder goes through one Start Import.

Says for each what an import needs to be textured: UVs and an image
(memory: an export with no UVs can never be textured).
"""

import json
import pathlib
import struct
import sys

HERE = pathlib.Path(__file__).parent
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


def name(doc, key, mesh):
    for scene in doc.get("scenes", []):
        scene["name"] = key
    roots = doc["scenes"][0]["nodes"]
    if len(roots) == 1:
        doc["nodes"][roots[0]]["name"] = key
    if mesh and len(doc["meshes"]) == 1:
        doc["meshes"][0]["name"] = key


def report(key, doc):
    prims = [p for m in doc["meshes"] for p in m["primitives"]]
    uv = all("TEXCOORD_0" in p["attributes"] for p in prims)
    colour = any("COLOR_0" in p["attributes"] for p in prims)
    size = [0, 0, 0]
    for p in prims:
        acc = doc["accessors"][p["attributes"]["POSITION"]]
        size = [max(s, hi - lo) for s, hi, lo in zip(size, acc["max"], acc["min"])]
    print(
        f"{key:20} meshes {len(doc['meshes'])}  uv {uv}  images {len(doc.get('images', []))}  "
        f"vertex colours {colour}  size {[round(s, 3) for s in size]}"
    )


def main():
    source, target = pathlib.Path(sys.argv[1]), pathlib.Path(sys.argv[2])
    target.mkdir(parents=True, exist_ok=True)
    listed = json.loads((HERE / "daggers_tripo_2026_11_16.json").read_text(encoding="utf-8"))
    for stem, job in {**listed["jobs"], **listed.get("remake", {})}.items():
        doc, rest = read(source / f"ad16_{stem}.glb")
        name(doc, job["key"], True)
        write(target / f"{job['key']}.glb", doc, rest)
        report(job["key"], doc)


if __name__ == "__main__":
    main()
