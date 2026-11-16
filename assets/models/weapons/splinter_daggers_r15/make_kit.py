"""The Assassin's twin-dagger R15 kit, written as numbers rather than keyed
by hand in Claude Design (2026-11-15: a first kit so the class can be played;
a Design kit can replace `splinter_daggers_animations.json` whole).

    python -I make_kit.py            writes splinter_daggers_animations.json
    python -I make_kit.py sheet.png  also draws every key as a stick figure

Then `python -I ../weapon_animations_to_luau.py` and StyLua, as for any kit.

Poses are angles in degrees on each joint, in the R15 joints' own frames
(X to the character's right, Y up, Z behind it):

- a shoulder is `pitch` (the arm raised forward from hanging), `heading` (the
  raised arm turned about the upright: + is to the character's left), `side`
  (lifted out sideways: + is to its right) and `twist` (about the arm's own
  length: it decides which way the elbow folds);
- an elbow is how far it folds; a wrist is how far the hand tips the blade:
  0 leaves it square to the forearm (a hammer grip), -90 lays it along the
  forearm, pointing where the fingers do;
- the waist is `turn` (+ to the left) and `lean` (+ forward).

Both daggers are held the same way, blade out of the thumb side of the fist.
The camera looks down on the fight, so the blows lay the blades along the
arms: a blade held upright is a dot from above.
"""
import json
import math
import pathlib
import sys

HERE = pathlib.Path(__file__).parent
OUT = HERE / "splinter_daggers_animations.json"

ARMS = ["LeftShoulder", "LeftElbow", "LeftWrist", "RightShoulder", "RightElbow", "RightWrist"]
BODY = ["Waist", "Neck"] + ARMS


def quat(axis, degrees):
    half = math.radians(degrees) / 2
    s = math.sin(half)
    return (axis[0] * s, axis[1] * s, axis[2] * s, math.cos(half))


def mul(a, b):
    ax, ay, az, aw = a
    bx, by, bz, bw = b
    return (
        aw * bx + ax * bw + ay * bz - az * by,
        aw * by - ax * bz + ay * bw + az * bx,
        aw * bz + ax * by - ay * bx + az * bw,
        aw * bw - ax * bx - ay * by - az * bz,
    )


X, Y, Z = (1, 0, 0), (0, 1, 0), (0, 0, 1)


def shoulder(pitch, heading=0, side=0, twist=0):
    return mul(mul(mul(quat(Y, heading), quat(Z, side)), quat(X, pitch)), quat(Y, twist))


def arm(pitch, heading=0, side=0, twist=0, elbow=0, wrist=0):
    return (shoulder(pitch, heading, side, twist), quat(X, elbow), quat(X, wrist))


def mirror(pose):
    """The other arm's same pose: headings, sides and twists change sign."""
    out = []
    for x, y, z, w in pose:
        out.append((x, -y, -z, w))
    return tuple(out)


def body(turn=0, lean=0):
    waist = mul(quat(Y, turn), quat(X, -lean))
    # the head keeps looking where the fight is
    neck = mul(quat(X, lean * 0.6), quat(Y, -turn * 0.6))
    return waist, neck


def key(t, right, left, torso=None, marker=None):
    rot = {
        "RightShoulder": right[0],
        "RightElbow": right[1],
        "RightWrist": right[2],
        "LeftShoulder": left[0],
        "LeftElbow": left[1],
        "LeftWrist": left[2],
    }
    if torso is not None:
        rot["Waist"], rot["Neck"] = torso
    return {
        "t": t,
        "marker": marker,
        "rot": {name: [round(v, 4) for v in q] for name, q in rot.items()},
        "rootOffset": None,
    }


def clip(length, loop, joints, keys):
    return {"length": length, "loop": loop, "joints": joints, "keys": keys}


# The stance: elbows folded, both blades forward and up, the left held a
# little lower and closer than the right.
GUARD_R = arm(pitch=28, heading=-12, twist=25, elbow=78, wrist=-52)
GUARD_L = mirror(arm(pitch=16, heading=-16, twist=30, elbow=92, wrist=-58))
GUARD_R2 = arm(pitch=31, heading=-10, twist=25, elbow=74, wrist=-50)
GUARD_L2 = mirror(arm(pitch=19, heading=-14, twist=30, elbow=88, wrist=-56))
SQUARE = body()

# Running: leaning in, both arms trailing behind with the blades laid back.
RUN_R = arm(pitch=-58, heading=0, side=14, elbow=14, wrist=-78)
RUN_L = mirror(RUN_R)
RUN_R2 = arm(pitch=-50, heading=0, side=18, elbow=20, wrist=-78)
RUN_L2 = mirror(arm(pitch=-64, heading=0, side=12, elbow=10, wrist=-78))


def slash(mirrored):
    """One dagger cut across the front, from its own side to the other, the
    other dagger pulled in to guard. `mirrored` is the left hand's."""

    def pair(cutting, guarding, turn, lean=0, marker=None, t=0.0):
        torso = body(-turn if mirrored else turn, lean)
        if mirrored:
            return key(t, mirror(guarding), mirror(cutting), torso, marker)
        return key(t, cutting, guarding, torso, marker)

    guard_in = arm(pitch=14, heading=-10, twist=30, elbow=104, wrist=-40)
    return clip(
        0.4,
        False,
        BODY,
        [
            key(0.0, GUARD_R, GUARD_L, SQUARE),
            # wound up: the cutting arm out to its own side, the body turned with it
            pair(arm(72, heading=-62, twist=80, elbow=58, wrist=-70), guard_in, -24, 4, t=0.07),
            pair(arm(80, heading=-38, twist=85, elbow=30, wrist=-84), guard_in, -10, 8, "TrailOn", 0.11),
            # the cut: arm straight, blade along it, passing the middle
            pair(arm(84, heading=6, twist=90, elbow=8, wrist=-90), guard_in, 16, 12, "Hit", 0.14),
            pair(arm(80, heading=42, twist=90, elbow=20, wrist=-88), guard_in, 28, 12, "TrailOff", 0.19),
            pair(arm(70, heading=58, twist=90, elbow=44, wrist=-80), guard_in, 30, 9, t=0.25),
            key(0.4, GUARD_R, GUARD_L, SQUARE),
        ],
    )


def stab():
    """Both daggers drawn back to the hips, then driven forward together."""
    back_r = arm(pitch=-34, heading=-8, side=10, elbow=112, wrist=-86)
    reach_r = arm(pitch=86, heading=6, twist=10, elbow=6, wrist=-90)
    hold_r = arm(pitch=82, heading=7, twist=10, elbow=10, wrist=-90)
    return clip(
        0.44,
        False,
        BODY,
        [
            key(0.0, GUARD_R, GUARD_L, SQUARE),
            key(0.1, back_r, mirror(back_r), body(0, -9)),
            key(0.14, back_r, mirror(back_r), body(0, -8), "TrailOn"),
            key(0.18, reach_r, mirror(reach_r), body(0, 20), "Hit"),
            key(0.24, hold_r, mirror(hold_r), body(0, 18), "TrailOff"),
            key(0.3, hold_r, mirror(hold_r), body(0, 15)),
            key(0.44, GUARD_R, GUARD_L, SQUARE),
        ],
    )


def dash():
    """Shadow Dash: both blades swept out to the sides and back as the dash
    carries the body through."""
    wide_r = arm(pitch=64, heading=-78, twist=90, elbow=6, wrist=-90)
    cross_r = arm(pitch=70, heading=34, twist=90, elbow=38, wrist=-84)
    return clip(
        0.4,
        False,
        BODY,
        [
            key(0.0, cross_r, mirror(cross_r), body(0, 22), "TrailOn"),
            key(0.1, wide_r, mirror(wide_r), body(0, 26), "Hit"),
            key(0.2, wide_r, mirror(wide_r), body(0, 20), "TrailOff"),
            key(0.4, GUARD_R, GUARD_L, SQUARE),
        ],
    )


CLIPS = {
    "Hold": clip(
        2.0,
        True,
        ARMS,
        [key(0.0, GUARD_R, GUARD_L), key(1.0, GUARD_R2, GUARD_L2), key(2.0, GUARD_R, GUARD_L)],
    ),
    "Run": clip(
        0.5,
        True,
        BODY,
        [
            key(0.0, RUN_R, RUN_L, body(0, 16)),
            key(0.25, RUN_R2, RUN_L2, body(0, 13)),
            key(0.5, RUN_R, RUN_L, body(0, 16)),
        ],
    ),
    "Slash_R": slash(False),
    "Slash_L": slash(True),
    "Stab": stab(),
    "Dash": dash(),
}


# --- a stick figure of every key, to look the poses over outside Studio ---

def rotate(q, v):
    x, y, z, w = q
    ux, uy, uz = x, y, z
    cx = uy * v[2] - uz * v[1] + w * v[0]
    cy = uz * v[0] - ux * v[2] + w * v[1]
    cz = ux * v[1] - uy * v[0] + w * v[2]
    return (
        v[0] + 2 * (uy * cz - uz * cy),
        v[1] + 2 * (uz * cx - ux * cz),
        v[2] + 2 * (ux * cy - uy * cx),
    )


def add(a, b):
    return (a[0] + b[0], a[1] + b[1], a[2] + b[2])


IDENT = (0, 0, 0, 1)
BLADE = 1.65  # studs from the fist to the tip, at the weapon's scale


def figure(rot):
    """Line segments (a, b, colour) of the upper body in the root's frame."""
    waist = tuple(rot.get("Waist", IDENT))
    lines = []
    hip = (0, 0, 0)
    chest = add(hip, rotate(waist, (0, 1.2, 0)))
    lines.append((hip, chest, (90, 90, 90)))
    lines.append((chest, add(chest, rotate(mul(waist, tuple(rot.get("Neck", IDENT))), (0, 0.9, 0))), (90, 90, 90)))
    for side, sign, colour in (("Right", 1, (200, 60, 60)), ("Left", -1, (60, 90, 200))):
        s = mul(waist, tuple(rot[side + "Shoulder"]))
        e = mul(s, tuple(rot[side + "Elbow"]))
        h = mul(e, tuple(rot[side + "Wrist"]))
        joint = add(hip, rotate(waist, (sign * 1.0, 1.15, 0)))
        lines.append((chest, joint, (90, 90, 90)))
        elbow = add(joint, rotate(s, (sign * 0.5, -0.73, 0)))
        wrist = add(elbow, rotate(e, (0, -0.76, 0)))
        fist = add(wrist, rotate(h, (0, -0.2, 0)))
        tip = add(fist, rotate(h, (0, 0, -BLADE)))
        lines += [(joint, elbow, colour), (elbow, wrist, colour), (wrist, fist, colour)]
        lines.append((fist, tip, (20, 150, 70)))
    return lines


def sheet(path):
    from PIL import Image, ImageDraw

    cell, scale = 150, 30
    views = (
        ("front", lambda p: (p[0], -p[1]), (0.5, 0.72)),
        ("side", lambda p: (-p[2], -p[1]), (0.4, 0.72)),
        ("top", lambda p: (p[0], p[2]), (0.5, 0.72)),
    )
    rows = sum(1 for _ in CLIPS)
    cols = max(len(c["keys"]) for c in CLIPS.values())
    image = Image.new("RGB", (cols * cell * 3 + 90, rows * cell), (245, 245, 240))
    draw = ImageDraw.Draw(image)
    for row, (name, data) in enumerate(CLIPS.items()):
        draw.text((4, row * cell + 4), name, fill=(0, 0, 0))
        for col, k in enumerate(data["keys"]):
            rot = dict(k["rot"])
            for v, (label, project, centre) in enumerate(views):
                ox = 90 + (col * 3 + v) * cell + centre[0] * cell
                oy = row * cell + centre[1] * cell
                draw.rectangle(
                    [90 + (col * 3 + v) * cell, row * cell, 90 + (col * 3 + v + 1) * cell - 1, (row + 1) * cell - 1],
                    outline=(210, 210, 200),
                )
                if v == 0:
                    draw.text((ox - 60, row * cell + 4), f"{k['t']:.2f} {k['marker'] or ''}", fill=(0, 0, 0))
                for a, b, colour in figure(rot):
                    pa, pb = project(a), project(b)
                    draw.line(
                        [ox + pa[0] * scale, oy + pa[1] * scale, ox + pb[0] * scale, oy + pb[1] * scale],
                        fill=colour,
                        width=3,
                    )
    image.save(path)
    print("drew", path)


if __name__ == "__main__":
    for name, data in CLIPS.items():
        for k in data["keys"]:
            assert set(k["rot"]) == set(data["joints"]), (name, k["t"])
        assert data["keys"][-1]["t"] == data["length"], name
    OUT.write_text(json.dumps(CLIPS, indent=1) + "\n", encoding="utf-8")
    print("wrote", OUT)
    if len(sys.argv) > 1:
        sheet(sys.argv[1])
