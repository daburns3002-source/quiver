"""Ready the golden weapons' Tripo exports for the owner's Studio import.

    python -I assets/models/weapons/blocky/golden/name_glb.py <exports dir> <out dir>

Reads Tripo's exports (gold_golden_staff.glb, gold_golden_blade.glb, and
the bow as clean_bow_texture.py leaves it, gold_golden_bow_8k_clean.glb) and writes GoldenBow.glb, GoldenStaff.glb and
GoldenBlade.glb, each with its scene, root node and mesh named, so Studio's
Import Queue shows the weapon's name and the import lands under it.
"""

import json
import pathlib
import struct
import sys

NAMES = {
    "gold_golden_bow_8k_clean": "GoldenBow",
    "gold_golden_staff": "GoldenStaff",
    "gold_golden_blade": "GoldenBlade",
}


def main():
    source, target = pathlib.Path(sys.argv[1]), pathlib.Path(sys.argv[2])
    target.mkdir(parents=True, exist_ok=True)
    for stem, name in NAMES.items():
        raw = (source / f"{stem}.glb").read_bytes()
        size = struct.unpack("<I", raw[12:16])[0]
        doc = json.loads(raw[20 : 20 + size])
        rest = raw[20 + size :]
        for scene in doc.get("scenes", []):
            scene["name"] = name
        doc["nodes"][doc["scenes"][0]["nodes"][0]]["name"] = name
        doc["meshes"][0]["name"] = name
        text = json.dumps(doc, separators=(",", ":")).encode()
        text += b" " * (-len(text) % 4)
        with (target / f"{name}.glb").open("wb") as out:
            out.write(struct.pack("<4sII", b"glTF", 2, 12 + 8 + len(text) + len(rest)))
            out.write(struct.pack("<I4s", len(text), b"JSON") + text)
            out.write(rest)
        print(name, len(doc["meshes"]), "mesh")


if __name__ == "__main__":
    main()
