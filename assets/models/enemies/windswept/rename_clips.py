"""Rename a Claude Design GLB's clips to the names the game plays
(`EnemyManager`: Idle, Move, "Attack wind-up", Charge, Death).

    python -I assets/models/enemies/windswept/rename_clips.py <glb> Old=New ...
"""
import json
import struct
import sys

path, pairs = sys.argv[1], dict(a.split("=", 1) for a in sys.argv[2:])
data = open(path, "rb").read()
length = struct.unpack("<I", data[12:16])[0]
gltf = json.loads(data[20 : 20 + length])
for anim in gltf.get("animations", []):
    anim["name"] = pairs.get(anim.get("name"), anim.get("name"))
chunk = json.dumps(gltf, separators=(",", ":")).encode()
chunk += b" " * (-len(chunk) % 4)
rest = data[20 + length :]
out = struct.pack("<III", 0x46546C67, 2, 12 + 8 + len(chunk) + len(rest))
out += struct.pack("<II", len(chunk), 0x4E4F534A) + chunk + rest
open(path, "wb").write(out)
print([a["name"] for a in gltf.get("animations", [])])
