"""Turn one of the owner's R15 weapon kits (a Roblox .rbxmx of
KeyframeSequences) into the animation JSON weapon_animations_to_luau.py
reads.

    python -I kit_to_json.py <kit.rbxmx> [prefix] [out.json]

Each `<prefix><Name>` KeyframeSequence becomes clip `<Name>`. The prefix
defaults to `Bow_` and the output to leaf_bow_animations.json beside this
script (the LeafBow kit); the RubySword kit is `Sword_`, into
../ruby_greatsword_r15/ruby_greatsword_animations.json. A Pose's CFrame is
the Motor6D Transform of the joint whose Part1 is the pose's part, so the
part names map to joints below. Poses with Weight 0 only carry the
hierarchy and drive nothing; a joint a clip drives but a keyframe leaves out
is interpolated from that joint's neighbouring keys. The kit eases every key
Cubic InOut, as Fx/WeaponPose plays them.
"""
import json
import math
import pathlib
import sys
import xml.etree.ElementTree as ET

HERE = pathlib.Path(__file__).parent
PREFIX = sys.argv[2] if len(sys.argv) > 2 else "Bow_"
OUT = pathlib.Path(sys.argv[3]) if len(sys.argv) > 3 else HERE / "leaf_bow_animations.json"

JOINTS = {
    "LowerTorso": "Root",
    "UpperTorso": "Waist",
    "Head": "Neck",
    "LeftUpperArm": "LeftShoulder",
    "LeftLowerArm": "LeftElbow",
    "LeftHand": "LeftWrist",
    "RightUpperArm": "RightShoulder",
    "RightLowerArm": "RightElbow",
    "RightHand": "RightWrist",
    "LeftUpperLeg": "LeftHip",
    "LeftLowerLeg": "LeftKnee",
    "LeftFoot": "LeftAnkle",
    "RightUpperLeg": "RightHip",
    "RightLowerLeg": "RightKnee",
    "RightFoot": "RightAnkle",
}
ORDER = list(JOINTS.values())


def prop(item, name):
    for child in item.find("Properties"):
        if child.get("name") == name:
            return child
    return None


def quaternion(m):
    """(x, y, z, w) from a row-major 3x3 rotation."""
    r00, r01, r02, r10, r11, r12, r20, r21, r22 = m
    trace = r00 + r11 + r22
    if trace > 0:
        s = math.sqrt(trace + 1) * 2
        return ((r21 - r12) / s, (r02 - r20) / s, (r10 - r01) / s, s / 4)
    if r00 > r11 and r00 > r22:
        s = math.sqrt(1 + r00 - r11 - r22) * 2
        return (s / 4, (r01 + r10) / s, (r02 + r20) / s, (r21 - r12) / s)
    if r11 > r22:
        s = math.sqrt(1 + r11 - r00 - r22) * 2
        return ((r01 + r10) / s, s / 4, (r12 + r21) / s, (r02 - r20) / s)
    s = math.sqrt(1 + r22 - r00 - r11) * 2
    return ((r02 + r20) / s, (r12 + r21) / s, s / 4, (r10 - r01) / s)


def blend(a, b, u):
    """Normalised lerp between two quaternions, the short way round."""
    if sum(x * y for x, y in zip(a, b)) < 0:
        b = tuple(-x for x in b)
    q = tuple(x + (y - x) * u for x, y in zip(a, b))
    n = math.sqrt(sum(x * x for x in q)) or 1
    return tuple(x / n for x in q)


def at(track, t):
    """A joint's (rotation, position) at `t`, from its own keys."""
    track = sorted(track)
    if t <= track[0][0]:
        return track[0][1], track[0][2]
    for (t0, q0, p0), (t1, q1, p1) in zip(track, track[1:]):
        if t <= t1:
            u = (t - t0) / (t1 - t0) if t1 > t0 else 0
            return blend(q0, q1, u), tuple(a + (b - a) * u for a, b in zip(p0, p1))
    return track[-1][1], track[-1][2]


def clip(sequence):
    frames = []
    tracks = {}
    for keyframe in sequence.findall("Item"):
        if keyframe.get("class") != "Keyframe":
            continue
        t = float(prop(keyframe, "Time").text)
        marker = None
        for item in keyframe.iter("Item"):
            if item.get("class") == "KeyframeMarker":
                marker = prop(item, "Name").text
            if item.get("class") != "Pose":
                continue
            part = prop(item, "Name").text
            if part not in JOINTS or float(prop(item, "Weight").text) == 0:
                continue
            cf = prop(item, "CFrame")
            v = [float(cf.find(k).text) for k in ("X", "Y", "Z", "R00", "R01", "R02", "R10", "R11", "R12", "R20", "R21", "R22")]
            tracks.setdefault(JOINTS[part], []).append((t, quaternion(v[3:]), tuple(v[:3])))
        frames.append((t, marker))
    frames.sort()
    joints = [j for j in ORDER if j in tracks]
    keys = []
    for t, marker in frames:
        rot = {}
        offset = None
        for j in joints:
            q, p = at(tracks[j], t)
            rot[j] = [round(x, 6) for x in q]
            if j == "Root" and any(abs(x) > 1e-6 for x in p):
                offset = [round(x, 6) for x in p]
        keys.append({"t": round(t, 6), "marker": marker, "rot": rot, "rootOffset": offset})
    return {
        "length": max(t for t, _ in frames),
        "loop": prop(sequence, "Loop").text == "true",
        "joints": joints,
        "keys": keys,
    }


def main():
    root = ET.parse(sys.argv[1]).getroot()
    clips = {}
    for item in root.iter("Item"):
        if item.get("class") == "KeyframeSequence":
            name = prop(item, "Name").text
            clips[name.removeprefix(PREFIX)] = clip(item)
    OUT.write_text(json.dumps(clips, indent=1), encoding="utf-8")
    for name, c in clips.items():
        print(name, c["length"], "loop" if c["loop"] else "once", len(c["keys"]), "keys", c["joints"])


main()
