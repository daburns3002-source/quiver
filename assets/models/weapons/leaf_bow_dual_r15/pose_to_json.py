"""Turn a posed R15 rig (a GLB whose arm joints carry a still pose, like the
owner's leaf_bow_dual_r15.glb) into keyframes in the kits' JSON shape, so
weapon_animations_to_luau.py can generate it with the rest.

    python -I pose_to_json.py <posed.glb> <out.json>

A still pose becomes a looping Hold of two identical keys, and a short Fire
(the same pose, with a Release marker at its start), so a weapon held this
way can fire without its arms moving.
"""
import json
import math
import struct
import sys

JOINTS = ["LeftShoulder", "LeftElbow", "LeftWrist", "RightShoulder", "RightElbow", "RightWrist"]


def quaternion(m):
    # glTF matrices are column-major: m[0..2] is the X column, and so on.
    r00, r10, r20 = m[0], m[1], m[2]
    r01, r11, r21 = m[4], m[5], m[6]
    r02, r12, r22 = m[8], m[9], m[10]
    trace = r00 + r11 + r22
    if trace > 0:
        s = math.sqrt(trace + 1.0) * 2
        w, x, y, z = 0.25 * s, (r21 - r12) / s, (r02 - r20) / s, (r10 - r01) / s
    elif r00 > r11 and r00 > r22:
        s = math.sqrt(1.0 + r00 - r11 - r22) * 2
        w, x, y, z = (r21 - r12) / s, 0.25 * s, (r01 + r10) / s, (r02 + r20) / s
    elif r11 > r22:
        s = math.sqrt(1.0 + r11 - r00 - r22) * 2
        w, x, y, z = (r02 - r20) / s, (r01 + r10) / s, 0.25 * s, (r12 + r21) / s
    else:
        s = math.sqrt(1.0 + r22 - r00 - r11) * 2
        w, x, y, z = (r10 - r01) / s, (r02 + r20) / s, (r12 + r21) / s, 0.25 * s
    return [x, y, z, w]


blob = open(sys.argv[1], "rb").read()
length = struct.unpack("<I", blob[12:16])[0]
gltf = json.loads(blob[20:20 + length])
rot = {}
for node in gltf["nodes"]:
    if node.get("name") in JOINTS:
        rot[node["name"]] = quaternion(node.get("matrix", [1, 0, 0, 0, 0, 1, 0, 0, 0, 0, 1, 0, 0, 0, 0, 1]))
missing = [j for j in JOINTS if j not in rot]
assert not missing, missing


def key(t, marker=None):
    return {"t": t, "marker": marker, "rot": rot, "rootOffset": None}


clips = {
    "Hold": {"loop": True, "priority": 2, "length": 2.4, "joints": JOINTS, "keys": [key(0), key(2.4)]},
    "Fire": {"loop": False, "priority": 3, "length": 0.2, "joints": JOINTS, "keys": [key(0, "Release"), key(0.2)]},
}
json.dump(clips, open(sys.argv[2], "w"), indent=1)
print("wrote", sys.argv[2], {j: [round(v, 3) for v in q] for j, q in rot.items()})
