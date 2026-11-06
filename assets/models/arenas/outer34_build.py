"""The outer arenas of areas 3 and 4: the scenery past each room's walls,
built block by block after their Codex sheets (owner, 2026-11-05: "THE OUTER
ARENAS NEED TO ALSO BE BUILT FOR ARENA 3 AND 4").

    python -I outer34_build.py drowned   # drowned_village_outer_arena_roblox.glb
    python -I outer34_build.py bogheart  # bogheart_caverns_outer_arena_roblox.glb
    python -I outer34_build.py drowned --preview out.png

Same frame and rules as the Mossy Glade's and Thornwood's outer forests
(docs/arenas/mossy-glade-outer.md): the room's own frame at 1 unit = 1 stud,
origin at the floor's centre, north = -Z, ground top at Y -0.2, extent
x +-76.5 / z +-61, nothing inside the hole (x +-19.5, z +-31), nothing over
1.5 studs in either gate lane (x +-6, |z| 31..37; both areas have a south
gate). Every object is its own node and mesh, so the owner's import (Merge
Meshes off) keeps them apart; vertex colours are written as the sRGB the
game should draw (no srgb_glb.py step). Glowing pieces are their own parts,
named by prefix, white, for forest_to_luau.py to draw Neon in their tint.

Positions are read off the sheets: assets/concepts/blocky/arenas/
area03_drowned_village_ambience_v2.png and area04_bogheart_caverns_ambience.png
(with its kit sheet), the room's walls giving the scale.
"""

import math
import pathlib
import random
import sys

import numpy as np
import trimesh

HERE = pathlib.Path(__file__).resolve().parent
HOLE = (19.5, 31.0)
GATE = 6.0
X0, Z0, TILE = -76.5, -61.0, 3.0
NX, NZ = 51, 40
TOP = -0.2

FACES = [  # normal, four corners as (x,y,z) picks of (min=0,max=1)
    ((1, 0, 0), [(1, 0, 0), (1, 1, 0), (1, 1, 1), (1, 0, 1)]),
    ((-1, 0, 0), [(0, 0, 1), (0, 1, 1), (0, 1, 0), (0, 0, 0)]),
    ((0, 1, 0), [(0, 1, 0), (0, 1, 1), (1, 1, 1), (1, 1, 0)]),
    ((0, -1, 0), [(0, 0, 0), (1, 0, 0), (1, 0, 1), (0, 0, 1)]),
    ((0, 0, 1), [(0, 0, 1), (1, 0, 1), (1, 1, 1), (0, 1, 1)]),
    ((0, 0, -1), [(1, 0, 0), (0, 0, 0), (0, 1, 0), (1, 1, 0)]),
]


class Obj:
    """One part: boxes, each (x0, y0, z0, x1, y1, z1, rgb)."""

    def __init__(self, name, group, glow=None):
        self.name, self.group, self.glow = name, group, glow
        self.boxes = []

    def box(self, x0, y0, z0, x1, y1, z1, col):
        self.boxes.append((min(x0, x1), min(y0, y1), min(z0, z1), max(x0, x1), max(y0, y1), max(z0, z1), col))

    def cube(self, cx, y0, cz, w, h, d, col):
        self.box(cx - w / 2, y0, cz - d / 2, cx + w / 2, y0 + h, cz + d / 2, col)

    def mesh(self):
        v, n, c, f = [], [], [], []
        for x0, y0, z0, x1, y1, z1, col in self.boxes:
            lo, hi = (x0, y0, z0), (x1, y1, z1)
            for normal, corners in FACES:
                base = len(v)
                for k in corners:
                    v.append([hi[i] if k[i] else lo[i] for i in range(3)])
                    n.append(normal)
                    c.append([*((255, 255, 255) if self.glow else col), 255])
                f += [[base, base + 2, base + 1], [base, base + 3, base + 2]]
        return trimesh.Trimesh(
            vertices=np.array(v, float),
            faces=np.array(f, int),
            vertex_normals=np.array(n, float),
            vertex_colors=np.array(c, np.uint8),
            process=False,
        )


def jit(rng, col, amt=10):
    d = rng.randint(-amt, amt)
    return tuple(max(0, min(255, ch + d)) for ch in col)


def blocked(x, z, pad=0.0):
    """Inside the hole or a gate lane."""
    if abs(x) < HOLE[0] + pad and abs(z) < HOLE[1] + pad:
        return True
    return abs(x) < GATE + pad and abs(z) < 37 + pad


class Scene:
    def __init__(self, seed):
        self.rng = random.Random(seed)
        self.objs = []
        self.counts = {}

    def new(self, prefix, group, glow=None):
        self.counts[prefix] = self.counts.get(prefix, 0) + 1
        o = Obj(f"{prefix}_{self.counts[prefix]:03d}", group, glow)
        self.objs.append(o)
        return o

    def ground(self, tones, rare, patch=None, keep_out=None):
        """Four quadrants of tiles round the hole, the room's floor carried
        out (each 1 stud deep, top at TOP); `patch(x, z)` may give a colour."""
        quads = {}
        for i in range(NX):
            for j in range(NZ):
                x, z = X0 + TILE * (i + 0.5), Z0 + TILE * (j + 0.5)
                if abs(x) < HOLE[0] and abs(z) < HOLE[1]:
                    continue
                key = ("N" if z < 0 else "S") + ("W" if x < 0 else "E")
                o = quads.get(key)
                if not o:
                    o = quads[key] = Obj(f"Ground_{key}", "Ground")
                    self.objs.append(o)
                r = self.rng.random()
                col = patch(x, z) if patch else None
                if col is None:
                    col = rare[self.rng.randrange(len(rare))] if r < 0.08 else tones[self.rng.randrange(len(tones))]
                # one flat top: any step between tiles draws as a seam line
                o.box(x - 1.5, TOP - 1, z - 1.5, x + 1.5, TOP, z + 1.5, col)

    def glb(self, out):
        """Writes the GLB by hand: one node and mesh per part under one node
        per group, with float vertex colours. trimesh writes them as
        normalised bytes, which the Studio importer read as linear and drew
        about half as bright (2026-11-05); the Claude Design and kit GLBs
        that import as designed carry floats."""
        import json
        import struct

        blob = bytearray()
        views, accessors, meshes, nodes = [], [], [], []

        def add(data, target, count, kind, ctype, lo=None, hi=None):
            while len(blob) % 4:
                blob.append(0)
            views.append({"buffer": 0, "byteOffset": len(blob), "byteLength": len(data), "target": target})
            blob.extend(data)
            acc = {"bufferView": len(views) - 1, "componentType": ctype, "count": count, "type": kind}
            if lo is not None:
                acc["min"], acc["max"] = lo, hi
            accessors.append(acc)
            return len(accessors) - 1

        groups = {}
        for o in self.objs:
            m = o.mesh()
            v = np.asarray(m.vertices, np.float32)
            n = np.asarray(m.vertex_normals, np.float32)
            c = (np.asarray(m.visual.vertex_colors, np.float32)[:, :3] / 255.0).astype(np.float32)
            f = np.asarray(m.faces, np.uint32)
            pos = add(v.tobytes(), 34962, len(v), "VEC3", 5126, v.min(0).tolist(), v.max(0).tolist())
            nor = add(n.tobytes(), 34962, len(n), "VEC3", 5126)
            col = add(c.tobytes(), 34962, len(c), "VEC3", 5126)
            idx = add(f.tobytes(), 34963, f.size, "SCALAR", 5125)
            meshes.append({"name": o.name, "primitives": [{"attributes": {"POSITION": pos, "NORMAL": nor, "COLOR_0": col}, "indices": idx, "material": 0}]})
            nodes.append({"name": o.name, "mesh": len(meshes) - 1})
            groups.setdefault(o.group, []).append(len(nodes) - 1)
        roots = []
        for g, kids in groups.items():
            nodes.append({"name": g, "children": kids})
            roots.append(len(nodes) - 1)
        while len(blob) % 4:
            blob.append(0)
        doc = {
            "asset": {"version": "2.0", "generator": "outer34_build.py"},
            "scene": 0,
            "scenes": [{"nodes": roots}],
            "nodes": nodes,
            "meshes": meshes,
            "materials": [{"name": "Vertex", "pbrMetallicRoughness": {"baseColorFactor": [1, 1, 1, 1], "metallicFactor": 0, "roughnessFactor": 1}}],
            "accessors": accessors,
            "bufferViews": views,
            "buffers": [{"byteLength": len(blob)}],
        }
        js = json.dumps(doc, separators=(",", ":")).encode()
        js += b" " * (-len(js) % 4)
        total = 12 + 8 + len(js) + 8 + len(blob)
        out.write_bytes(
            struct.pack("<III", 0x46546C67, 2, total)
            + struct.pack("<II", len(js), 0x4E4F534A)
            + js
            + struct.pack("<II", len(blob), 0x004E4942)
            + bytes(blob)
        )

    def check(self):
        bad = []
        for o in self.objs:
            if o.group == "Ground":
                continue
            for x0, y0, z0, x1, y1, z1, _ in o.boxes:
                inside_hole = x1 > -HOLE[0] and x0 < HOLE[0] and z1 > -HOLE[1] and z0 < HOLE[1]
                lane = x1 > -GATE and x0 < GATE and ((z0 < -31 and z1 > -37) or (z1 > 31 and z0 < 37)) and y1 > 1.5
                if inside_hole or lane:
                    bad.append(o.name)
                    break
        tris = max(len(o.boxes) * 12 for o in self.objs)
        top = max(b[4] for o in self.objs for b in o.boxes)
        print(f"{len(self.objs)} parts, {sum(len(o.boxes) for o in self.objs)} boxes, biggest {tris} tris, top Y {top:.1f}")
        if bad:
            raise SystemExit(f"in the hole or a gate lane: {bad}")


# ---------------------------------------------------------------- pieces


def rock(s, o, cx, cz, w, h, d, cols, moss=None, steps=3, top=None):
    """A stack of stepped blocks narrowing upward, with moss on top."""
    rng = s.rng
    y = TOP
    for k in range(steps):
        f = 1 - k * 0.22
        hh = h / steps
        o.cube(cx + rng.uniform(-0.3, 0.3) * k, y, cz + rng.uniform(-0.3, 0.3) * k, w * f, hh, d * f, jit(rng, cols[k % len(cols)], 6))
        y += hh
    if moss:
        o.cube(cx, y - 0.2, cz, w * (1 - (steps - 1) * 0.22) * 0.8, 0.35, d * (1 - (steps - 1) * 0.22) * 0.7, moss)
    return y


def ripple(o, cx, cz, r, col, w=0.25):
    """A flat square ring on the water round something standing in it."""
    y0, y1 = TOP + 0.02, TOP + 0.08
    o.box(cx - r, y0, cz - r, cx + r, y1, cz - r + w, col)
    o.box(cx - r, y0, cz + r - w, cx + r, y1, cz + r, col)
    o.box(cx - r, y0, cz - r, cx - r + w, y1, cz + r, col)
    o.box(cx + r - w, y0, cz - r, cx + r, y1, cz + r, col)


# ================================================================ area 3

W3 = dict(
    water=[(22, 188, 196), (16, 180, 190), (30, 196, 200), (12, 172, 184)],
    glint=[(110, 222, 224), (70, 208, 214)],
    ring=(96, 216, 220),
    stone=[(150, 156, 166), (170, 175, 184), (128, 134, 146)],
    moss=(104, 178, 44),
    roof=[(84, 108, 164), (98, 124, 182), (70, 92, 142)],
    timber=(176, 96, 46),
    timber_dk=(128, 68, 34),
    hole=(34, 30, 34),
    dead=[(116, 106, 100), (98, 90, 86)],
    rope=(226, 208, 164),
    boat=(152, 86, 44),
    boat_in=(118, 64, 34),
    reed=[(96, 186, 44), (140, 214, 60)],
    iron=(70, 62, 58),
    bell=(214, 150, 40),
    crab=(170, 100, 50),
)


def sunken_house(s, cx, cz, yaw, size=1.0):
    """An A-frame roof sunk to its eaves: blue tiles in steps, timber gable
    ends and ridge, a broken dark hole, moss on the eaves."""
    o = s.new("House", "Houses")
    rng = s.rng
    L, W, H = 11 * size, 9 * size, 7 * size  # along the ridge, across, high
    rows = 5
    pts = []
    for k in range(rows):
        inset = W / 2 * k / rows
        y0 = TOP + H * k / rows
        for side in (-1, 1):
            a = side * (W / 2 - inset)
            b = side * (W / 2 - inset - W / 2 / rows - 0.3)
            for seg in range(4):
                l0 = -L / 2 + 0.8 + (L - 1.6) * seg / 4
                l1 = l0 + (L - 1.6) / 4 - 0.1
                if k == 2 and side == 1 and seg == 1:
                    pts.append((min(a, b), y0, l0, max(a, b), y0 + H / rows * 0.6, l1, W3["hole"]))
                    continue
                pts.append((min(a, b), y0, l0, max(a, b), y0 + H / rows + 0.15, l1, jit(rng, W3["roof"][rng.randrange(3)], 6)))
    # gable timbers at both ends, ridge beam
    for e in (-1, 1):
        l = e * (L / 2 - 0.4)
        for k in range(rows + 1):
            inset = W / 2 * k / rows
            y0 = TOP + H * k / rows
            for side in (-1, 1):
                a = side * (W / 2 - inset + 0.3)
                pts.append((min(a, a - side * 1.1), y0, l - 0.45, max(a, a - side * 1.1), y0 + H / rows + 0.2, l + 0.45, W3["timber"]))
        pts.append((-W / 2 + 1.6, TOP, l - 0.3, W / 2 - 1.6, TOP + H * 0.45, l + 0.3, W3["timber_dk"]))
    pts.append((-0.6, TOP + H - 0.1, -L / 2, 0.6, TOP + H + 0.9, L / 2, W3["timber"]))
    for k in range(4):
        side = rng.choice((-1, 1))
        l = rng.uniform(-L / 2 + 1, L / 2 - 1)
        pts.append((side * (W / 2 - 0.2), TOP, l - 0.5, side * (W / 2 - 1.2), TOP + 1.1, l + 0.5, W3["moss"]))
    c, sn = math.cos(yaw), math.sin(yaw)
    for x0, y0, z0, x1, y1, z1, col in pts:
        # yaw is a multiple of 90 degrees, so the boxes stay axis aligned
        ax, az = x0 * c - z0 * sn, x0 * sn + z0 * c
        bx, bz = x1 * c - z1 * sn, x1 * sn + z1 * c
        o.box(cx + ax, y0, cz + az, cx + bx, y1, cz + bz, col)
    ripple(o, cx, cz, max(L, W) / 2 + 0.4, W3["ring"])


def dead_tree(s, cx, cz, h=12, net=False):
    o = s.new("Tree", "Trees")
    rng = s.rng
    col = W3["dead"]
    o.cube(cx, TOP, cz, 2.6, 1.2, 2.6, col[1])
    o.cube(cx, TOP, cz, 1.8, h * 0.6, 1.8, col[0])
    for side, lift in ((-1, 0.5), (1, 0.62)):
        y = TOP + h * lift
        o.cube(cx + side * 1.4, y, cz, 1.2, 1.2, 1.2, col[0])
        o.cube(cx + side * 2.4, y + 1.0, cz, 1.2, h * 0.38, 1.2, col[0])
        o.cube(cx + side * 3.2, y + h * 0.3, cz, 1.0, 1.0, 1.0, col[1])
    o.cube(cx, TOP + h * 0.6, cz, 1.2, h * 0.4, 1.2, col[1])
    if net:
        for k in range(6):
            o.cube(cx + 1.8 + k * 0.45, TOP + h * 0.55 - k * 0.5, cz + 0.6, 0.35, 0.35, 0.35, W3["rope"])
        for gx in range(3):
            for gy in range(3):
                o.cube(cx + 2.4 + gx * 0.7, TOP + h * 0.2 + gy * 0.7, cz + 0.9, 0.12, 0.7, 0.12, W3["rope"])
                o.cube(cx + 2.4 + gx * 0.7, TOP + h * 0.2 + gy * 0.7, cz + 0.9, 0.7, 0.12, 0.12, W3["rope"])
    ripple(o, cx, cz, 2.6, W3["ring"])
    for _ in range(3):
        a = rng.uniform(0, math.tau)
        reed_clump(o, cx + math.cos(a) * 2.6, cz + math.sin(a) * 2.6, rng)


def reed_clump(o, cx, cz, rng, n=4):
    for _ in range(n):
        x, z = cx + rng.uniform(-0.9, 0.9), cz + rng.uniform(-0.9, 0.9)
        h = rng.uniform(1.6, 3.2)
        o.cube(x, TOP, z, 0.55, h, 0.55, W3["reed"][rng.randrange(2)])


def lantern_post(s, cx, cz, face=1):
    o = s.new("Post", "Props")
    o.cube(cx, TOP, cz, 0.9, 7.5, 0.9, W3["timber"])
    o.cube(cx, TOP, cz, 1.6, 0.8, 1.6, W3["timber_dk"])
    o.cube(cx + face * 1.0, TOP + 7.0, cz, 2.6, 0.6, 0.6, W3["timber"])
    o.cube(cx + face * 2.0, TOP + 5.2, cz, 1.3, 0.3, 1.3, W3["iron"])
    o.cube(cx + face * 2.0, TOP + 6.75, cz, 1.3, 0.3, 1.3, W3["iron"])
    g = s.new("Lamp", "Props", glow=True)
    g.cube(cx + face * 2.0, TOP + 5.5, cz, 1.0, 1.25, 1.0, None)
    ripple(o, cx, cz, 1.4, W3["ring"])


def rowboat(s, cx, cz, along_x=True, yaw_flip=False):
    o = s.new("Boat", "Props")
    L, W = 8.0, 3.4
    pts = [
        (-L / 2 + 1, -W / 2, L / 2 - 1, W / 2, 0.9, W3["boat"]),
        (-L / 2, -W / 2 + 0.7, -L / 2 + 1, W / 2 - 0.7, 0.9, W3["boat"]),
        (L / 2 - 1, -W / 2 + 0.7, L / 2, W / 2 - 0.7, 0.9, W3["boat"]),
        (-L / 2 + 1.5, -W / 2 + 0.5, L / 2 - 1.5, W / 2 - 0.5, 1.0, W3["boat_in"]),
        (-0.4, -W / 2 + 0.5, 0.4, W / 2 - 0.5, 1.05, W3["boat"]),
        (1.6, -W / 2 + 0.5, 2.2, W / 2 - 0.5, 1.05, W3["boat"]),
        (-2.5, -0.9, 1.5, -0.6, 1.15, W3["timber"]),
    ]
    for a0, b0, a1, b1, h, col in pts:
        if along_x:
            o.box(cx + a0, TOP, cz + b0, cx + a1, TOP + h, cz + b1, col)
        else:
            o.box(cx + b0, TOP, cz + a0, cx + b1, TOP + h, cz + a1, col)
    ripple(o, cx, cz, L / 2 + 0.8, W3["ring"])


def crab_pot(s, cx, cz):
    o = s.new("Pot", "Props")
    for k in range(4):
        o.cube(cx - 1.05 + k * 0.7, TOP, cz, 0.18, 1.6, 2.2, W3["crab"])
    for k in range(3):
        o.cube(cx, TOP + k * 0.7, cz, 2.3, 0.18, 2.2, W3["crab"])
    o.cube(cx, TOP, cz, 2.3, 0.3, 2.3, W3["timber_dk"])
    ripple(o, cx, cz, 1.7, W3["ring"])


def barrel(s, cx, cz):
    o = s.new("Barrel", "Props")
    o.cube(cx, TOP, cz, 1.8, 2.2, 1.8, W3["timber"])
    o.cube(cx, TOP + 0.4, cz, 1.95, 0.25, 1.95, W3["iron"])
    o.cube(cx, TOP + 1.6, cz, 1.95, 0.25, 1.95, W3["iron"])
    o.cube(cx, TOP + 2.2, cz, 1.4, 0.1, 1.4, W3["timber_dk"])
    ripple(o, cx, cz, 1.5, W3["ring"])


def rocks(s, cx, cz, big=1.0):
    o = s.new("Rock", "Rocks")
    rng = s.rng
    for k in range(rng.randint(2, 4)):
        w = rng.uniform(1.6, 3.2) * big
        o.cube(cx + rng.uniform(-1.5, 1.5) * big, TOP, cz + rng.uniform(-1.2, 1.2) * big, w, rng.uniform(1.2, 3.0) * big, w * rng.uniform(0.8, 1.1), jit(rng, W3["stone"][k % 3], 6))
    o.cube(cx, TOP, cz + 1.2 * big, 1.2, 0.5, 1.2, W3["moss"])
    reed_clump(o, cx + 2 * big, cz + 1.4 * big, rng, 3)
    ripple(o, cx, cz, 2.6 * big, W3["ring"])


def net_fence(s, cx, cz, along_x=True):
    o = s.new("Fence", "Props")
    span = 7.0
    for e in (-1, 1):
        x, z = (cx + e * span / 2, cz) if along_x else (cx, cz + e * span / 2)
        o.cube(x, TOP, z, 0.8, 5.5, 0.8, W3["timber"])
        o.cube(x, TOP + 5.5, z, 1.0, 0.5, 1.0, W3["rope"])
    for k in range(9):
        t = -span / 2 + span * k / 8
        sag = 4.8 - 0.6 * math.sin(math.pi * k / 8)
        x, z = (cx + t, cz) if along_x else (cx, cz + t)
        o.cube(x, TOP + sag, z, 0.45, 0.4, 0.45, W3["rope"])
        if 1 <= k <= 7:
            o.cube(x, TOP + 1.2, z, 0.12, sag - 1.2, 0.12, W3["rope"])
    for r in range(4):
        y = TOP + 1.2 + r * 0.85
        if along_x:
            o.box(cx - span / 2 + 0.9, y, cz - 0.06, cx + span / 2 - 0.9, y + 0.12, cz + 0.06, W3["rope"])
        else:
            o.box(cx - 0.06, y, cz - span / 2 + 0.9, cx + 0.06, y + 0.12, cz + span / 2 - 0.9, W3["rope"])
    ripple(o, cx, cz, 1.2, W3["ring"])


def bell_tower(s, cx, cz):
    """The leaning stone bell tower, its blue cap and gold bell."""
    o = s.new("Tower", "Landmarks")
    rng = s.rng
    lean = 0.12  # studs of x per stud up
    base = 9.0
    for k in range(9):
        y = TOP + k * 2.0
        off = lean * (y - TOP)
        w = base - 0.3 * k
        if k < 5:
            o.cube(cx + off, y, cz, w, 2.0, w, jit(rng, W3["stone"][k % 3], 5))
        else:
            for sx, sz in ((-1, -1), (1, -1), (-1, 1), (1, 1)):
                o.cube(cx + off + sx * (w / 2 - 0.9), y, cz + sz * (w / 2 - 0.9), 1.8, 2.0, 1.8, jit(rng, W3["stone"][k % 3], 5))
        if k % 2 == 0:
            o.cube(cx + off - w / 2 + 0.6, y + 0.4, cz + rng.uniform(-2, 2), 0.5, 1.4, 1.6, W3["moss"])
    y = TOP + 18
    off = lean * 18
    o.cube(cx + off, y, cz, base - 2.2, 0.8, base - 2.2, W3["stone"][1])
    for k in range(3):
        o.cube(cx + off + lean * k, y + 0.8 + k * 1.1, cz, base - 2.2 - k * 2, 1.1, base - 2.2 - k * 2, W3["roof"][k % 2])
    o.cube(cx + lean * 12, TOP + 12.0, cz, 0.4, 3.6, 0.4, W3["iron"])
    o.cube(cx + lean * 12, TOP + 11.6, cz, 0.3, 0.3, 0.3, W3["iron"])
    b = W3["bell"]
    o.cube(cx + lean * 11, TOP + 10.6, cz, 2.6, 0.6, 2.6, b)
    o.cube(cx + lean * 11, TOP + 11.2, cz, 2.0, 1.4, 2.0, b)
    o.cube(cx + lean * 11, TOP + 12.6, cz, 1.2, 0.6, 1.2, b)
    for _ in range(6):
        a = rng.uniform(0, math.tau)
        r = rng.uniform(5.5, 7.5)
        o.cube(cx + math.cos(a) * r, TOP, cz + math.sin(a) * r, 1.6, rng.uniform(0.8, 1.8), 1.6, jit(rng, W3["stone"][0], 6))
    ripple(o, cx, cz, 7.0, W3["ring"])


def toll_arch(s, cx, cz):
    """The stone toll gate with its lantern, and the broken causeway out of it."""
    o = s.new("Arch", "Landmarks")
    rng = s.rng
    for side in (-1, 1):
        x = cx + side * 4.5
        for k in range(4):
            o.cube(x + rng.uniform(-0.2, 0.2), TOP + k * 2.2, cz, 2.8, 2.2, 3.0, jit(rng, W3["stone"][k % 3], 6))
        o.cube(x - side * 0.3, TOP + 1.0, cz - 1.6, 0.6, 3.0, 0.5, W3["moss"])
    for k in range(5):
        o.cube(cx - 4.0 + k * 2.0, TOP + 8.8 + (0.6 if k in (1, 2, 3) else 0), cz, 2.0, 1.8, 3.0, jit(rng, W3["stone"][k % 3], 6))
    o.cube(cx, TOP + 7.6, cz, 7.0, 0.7, 0.7, W3["timber"])
    o.cube(cx, TOP + 6.1, cz - 0.2, 0.25, 1.5, 0.25, W3["iron"])
    o.cube(cx, TOP + 4.6, cz - 0.2, 1.3, 0.3, 1.3, W3["iron"])
    g = s.new("Lamp", "Landmarks", glow=True)
    g.cube(cx, TOP + 4.9, cz - 0.2, 1.0, 1.2, 1.0, None)
    # the causeway, broken, heading south-east toward the room
    tiles = [(0, 2.5), (1, 2.5), (0, 3.5), (1, 3.5), (1.3, 4.5), (2.3, 4.5), (2.6, 5.5), (3.6, 5.5), (4.4, 6.5), (5.4, 7.3), (6.5, 8.0)]
    for tx, tz in tiles:
        if rng.random() < 0.85:
            o.cube(cx - 1.5 + tx * 1.9, TOP, cz + tz * 1.9, 1.75, 0.45, 1.75, jit(rng, W3["stone"][1], 8))
    ripple(o, cx, cz, 6.0, W3["ring"])


def raft(s, cx, cz):
    o = s.new("Raft", "Props")
    for k in range(5):
        o.cube(cx - 2.4 + k * 1.2, TOP, cz, 1.05, 0.6, 5.2, jit(s.rng, W3["boat"], 8))
    for e in (-1.6, 1.6):
        o.cube(cx, TOP + 0.6, cz + e, 6.0, 0.3, 0.6, W3["timber_dk"])
    ripple(o, cx, cz, 3.6, W3["ring"])


def planks(s, cx, cz):
    o = s.new("Plank", "Props")
    o.cube(cx, TOP, cz, 3.6, 0.4, 0.9, W3["boat"])
    o.cube(cx + 0.8, TOP, cz + 1.1, 3.0, 0.4, 0.9, W3["boat_in"])


def drowned():
    s = Scene(3)
    rng = s.rng

    def water(x, z):
        # pale glint streaks across the open water
        if rng.random() < 0.05:
            return W3["glint"][rng.randrange(2)]
        return None

    s.ground(W3["water"], [(40, 204, 206)], water)
    # Off the sheet: (px - 818) / 12.4, (py - 455) / 9.4.
    for cx, cz, yaw, sz in [
        (-44, -32, math.pi / 2, 1.0), (-10, -43, math.pi / 2, 0.85), (27, -25, 0, 0.75),
        (60, -6, math.pi / 2, 1.0), (38, 4, math.pi / 2, 1.0), (-26, 42, math.pi / 2, 1.0),
        (-66, 44, 0, 0.9), (68, 46, math.pi / 2, 0.9), (34, -52, math.pi / 2, 0.8),
    ]:
        sunken_house(s, cx, cz, yaw, sz)
    for cx, cz, h, net in [(-56, -43, 13, True), (-58, -19, 12, True), (-32, 2, 9, False), (12, -50, 8, False), (46, 33, 12, True), (70, 20, 10, False), (-70, 30, 9, False)]:
        dead_tree(s, cx, cz, h, net)
    for cx, cz, face in [(-40, -9, 1), (24, -36, 1), (33, 33, -1), (-36, 22, 1)]:
        lantern_post(s, cx, cz, face)
    for cx, cz, ax in [(-29, -20, True), (31, 16, True), (22, 42, True), (-62, 54, False)]:
        rowboat(s, cx, cz, ax)
    for cx, cz in [(31, -8), (-30, 17), (8, 50)]:
        crab_pot(s, cx, cz)
    for cx, cz in [(29, 2), (-43, 38), (-20, 52), (45, -40)]:
        barrel(s, cx, cz)
    for cx, cz, big in [
        (-58, 31, 1.4), (-25, -12, 0.9), (35, -40, 1.0), (62, -36, 1.0), (6, 42, 0.9),
        (-12, -36, 0.8), (-62, 4, 0.9), (60, -19, 0.8), (-63, 19, 0.8), (72, 0, 1.0), (-72, -54, 1.2), (52, 55, 1.0),
    ]:
        rocks(s, cx, cz, big)
    net_fence(s, -50, -6, True)
    net_fence(s, 55, 9, False)
    bell_tower(s, 42, -30)
    toll_arch(s, -47, 9)
    raft(s, 58, 23)
    for cx, cz in [(55, 39), (56, -20), (-14, 56)]:
        planks(s, cx, cz)
    # reed clumps scattered over the open water, a few per part
    spots = []
    while len(spots) < 110:
        x, z = rng.uniform(-74, 74), rng.uniform(-59, 59)
        if blocked(x, z, 2.5) or (abs(x) < 29 and abs(z) < 26):
            continue
        if any(abs(x - b[0]) < 3 and abs(z - b[2]) < 3 for o in s.objs if o.group != "Ground" for b in o.boxes[:1]):
            continue
        spots.append((x, z))
    for k in range(0, len(spots), 10):
        o = s.new("Reeds", "Reeds")
        for x, z in spots[k : k + 10]:
            reed_clump(o, x, z, rng, rng.randint(3, 6))
    # the wall band: reeds at the room's outer wall feet, clear of the houses
    o = s.new("Reeds", "Reeds")
    for z in range(-29, 30, 4):
        for side in (-1, 1):
            if abs(z) > 25:
                reed_clump(o, side * 21.0, z, rng, 3)
    for x in range(-18, 19, 4):
        for side in (-1, 1):
            if abs(x) > 7.5:
                reed_clump(o, x, side * 32.4, rng, 3)
    return s


# ================================================================ area 4

B4 = dict(
    floor=[(62, 66, 86), (70, 74, 94), (58, 62, 80), (66, 70, 92)],
    floor_far=[(52, 56, 72), (48, 52, 68)],
    moss=[(96, 128, 36), (110, 142, 42), (82, 112, 34)],
    rock=[(62, 66, 86), (78, 82, 104), (92, 96, 120)],
    stem=(186, 232, 216),
    plank=(150, 94, 54),
    plank_dk=(112, 68, 38),
    root=(156, 84, 30),
    stone=(108, 114, 136),
    bog=(46, 92, 52),
    dark=(14, 14, 20),
)


def bog_floor(s):
    rng = s.rng
    moss_cells = set()
    for _ in range(70):
        x, z = rng.randrange(NX), rng.randrange(NZ)
        for _ in range(rng.randint(2, 6)):
            moss_cells.add((x, z))
            x += rng.choice((-1, 0, 1))
            z += rng.choice((-1, 0, 1))

    def patch(x, z):
        i, j = int((x - X0) // TILE), int((z - Z0) // TILE)
        if (i, j) in moss_cells:
            return B4["moss"][rng.randrange(3)]
        if max(abs(x) - 50, abs(z) - 42) > 0:
            return B4["floor_far"][rng.randrange(2)]
        return None

    s.ground(B4["floor"], [(76, 80, 102)], patch)


def column(s, cx, cz, h, w=4.0, moss=True, glow=True, roots=False):
    """A tall slate rock column of stacked offset blocks."""
    o = s.new("Column", "Rocks")
    rng = s.rng
    o.cube(cx, TOP, cz, w + 1.6, 1.4, w + 1.4, jit(rng, B4["rock"][0], 5))
    y = TOP
    k = 0
    while y < TOP + h:
        hh = rng.uniform(1.8, 3.2)
        ww = w * rng.uniform(0.8, 1.05)
        o.cube(cx + rng.uniform(-0.4, 0.4), y, cz + rng.uniform(-0.4, 0.4), ww, min(hh, TOP + h - y), ww * rng.uniform(0.85, 1.1), jit(rng, B4["rock"][k % 3], 5))
        y += hh
        k += 1
    for _ in range(rng.randint(1, 3)):
        o.cube(cx + rng.uniform(-w / 3, w / 3), TOP + rng.uniform(2, h - 1), cz - w / 2 - 0.05, w * 0.5, rng.uniform(1.0, 2.6), 0.4, B4["moss"][rng.randrange(3)])
    if moss:
        o.cube(cx, TOP + h - 0.1, cz, w * 0.8, 0.4, w * 0.7, B4["moss"][1])
    if roots:
        for k in range(3):
            x = cx - w / 3 + k * w / 3
            o.cube(x, TOP + h * 0.45, cz + w / 2 + 0.3, 0.35, h * 0.4, 0.35, B4["root"])
    if glow:
        mushrooms(s, cx + w / 2 + 0.6, cz + w / 2 + 0.4, small=True)


def mushrooms(s, cx, cz, small=False):
    """A little cluster of glowing caps on pale stems."""
    rng = s.rng
    o = s.new("Cluster", "Mushrooms")
    caps = s.new("GlowCap", "Mushrooms", glow=True)
    o.cube(cx, TOP, cz, 2.0, 0.5, 2.0, B4["rock"][0])
    for k in range(2 if small else 3):
        x, z = cx + rng.uniform(-0.7, 0.7), cz + rng.uniform(-0.7, 0.7)
        h = rng.uniform(0.6, 1.2)
        o.cube(x, TOP + 0.5, z, 0.3, h, 0.3, B4["stem"])
        caps.cube(x, TOP + 0.5 + h, z, 0.75, 0.45, 0.75, None)


def giant(s, cx, cz, h=9.0, cap=7.0, base=True):
    """A giant glowing mushroom: pale stem, cyan cap, mossy slate base."""
    o = s.new("Giant", "Trees")
    caps = s.new("GlowCap", "Trees", glow=True)
    rng = s.rng
    if base:
        for _ in range(5):
            a = rng.uniform(0, math.tau)
            o.cube(cx + math.cos(a) * 1.8, TOP, cz + math.sin(a) * 1.8, 1.4, rng.uniform(0.6, 1.2), 1.4, jit(rng, B4["rock"][0], 5))
        o.cube(cx, TOP, cz, 3.6, 0.5, 3.6, B4["moss"][0])
    o.cube(cx, TOP, cz, cap * 0.32, h, cap * 0.32, B4["stem"])
    caps.cube(cx, TOP + h, cz, cap, cap * 0.32, cap, None)
    caps.cube(cx, TOP + h + cap * 0.32, cz, cap * 0.75, cap * 0.16, cap * 0.75, None)


def grove(s, cx, cz, scale=1.0):
    giant(s, cx, cz, 9 * scale, 7 * scale)
    giant(s, cx + 5.5 * scale, cz + 1.5 * scale, 5.5 * scale, 4.5 * scale)
    giant(s, cx - 4.5 * scale, cz + 3.5 * scale, 4.0 * scale, 3.6 * scale)
    mushrooms(s, cx + 2.5, cz + 4.5)


def sprout(s, cx, cz):
    """A lime-green glowing bog sprout on a little mossy mound."""
    rng = s.rng
    o = s.new("Mound", "Bog")
    g = s.new("Sprout", "Bog", glow=True)
    o.cube(cx, TOP, cz, 3.0, 0.6, 3.0, B4["rock"][0])
    o.cube(cx, TOP + 0.6, cz, 2.2, 0.4, 2.2, B4["moss"][1])
    o.cube(cx - 1.6, TOP, cz + 0.8, 1.4, 0.4, 1.4, B4["bog"])
    for dx, h, sz in ((0, 1.8, 0.9), (0.9, 1.1, 0.7)):
        g.cube(cx + dx, TOP + 1.0, cz, 0.4, h, 0.4, None)
        g.cube(cx + dx, TOP + 1.0 + h, cz, sz, sz, sz, None)
    for _ in range(2):
        g.cube(cx + rng.uniform(-1, 1), TOP + 1.0, cz + rng.uniform(-1, 1), 0.3, 0.6, 0.3, None)


def cave_mouth(s, cx, cz):
    """An outer rock wall with a black cave mouth opening south, toward the
    camera, as the sheet draws both side tunnels."""
    o = s.new("Cave", "Landmarks")
    rng = s.rng
    for dx in range(-6, 7, 2):
        for k in range(5):
            if abs(dx) <= 2 and k < 3:
                continue
            o.cube(cx + dx, TOP + k * 2.4, cz + rng.uniform(-0.3, 0.3), 2.0, 2.4, 5.0, jit(rng, B4["rock"][k % 3], 5))
    o.cube(cx, TOP, cz - 0.8, 5.0, 7.2, 3.4, B4["dark"])
    o.cube(cx + 4, TOP + 12, cz, 5, 0.5, 4.4, B4["moss"][0])
    o.cube(cx - 5.5, TOP + 3, cz + 2.55, 1.6, 4.0, 0.3, B4["moss"][1])
    mushrooms(s, cx - 3.6, cz + 3.4, small=True)
    mushrooms(s, cx + 3.6, cz + 3.4, small=True)


def rubble(s, cx, cz):
    o = s.new("Rubble", "Rocks")
    rng = s.rng
    for _ in range(rng.randint(3, 5)):
        w = rng.uniform(0.8, 1.8)
        o.cube(cx + rng.uniform(-1.6, 1.6), TOP, cz + rng.uniform(-1.6, 1.6), w, w * rng.uniform(0.6, 1.2), w, jit(rng, B4["rock"][1], 6))
    o.cube(cx, TOP, cz, 1.6, 1.8, 1.6, B4["rock"][2])
    o.cube(cx, TOP + 1.8, cz, 1.2, 0.3, 1.2, B4["moss"][0])


def stalagmites(s, cx, cz):
    o = s.new("Spire", "Rocks")
    rng = s.rng
    o.cube(cx, TOP, cz, 5.0, 1.0, 4.0, B4["rock"][0])
    for dx, dz, h in ((-1.2, 0, 8.0), (1.2, 0.6, 5.0), (0.2, -1.2, 3.4)):
        o.cube(cx + dx, TOP, cz + dz, 1.6, h * 0.6, 1.6, jit(rng, B4["rock"][1], 5))
        o.cube(cx + dx, TOP + h * 0.6, cz + dz, 1.0, h * 0.4, 1.0, jit(rng, B4["rock"][2], 5))


def stream(s, path, width=3.4):
    """Glowing water along a path of axis-aligned runs, with slate banks."""
    banks = s.new("Bank", "Water")
    water = s.new("GlowWater", "Water", glow=True)
    for (x0, z0), (x1, z1) in zip(path, path[1:]):
        lo_x, hi_x = min(x0, x1) - width / 2, max(x0, x1) + width / 2
        lo_z, hi_z = min(z0, z1) - width / 2, max(z0, z1) + width / 2
        water.box(lo_x, TOP - 0.3, lo_z, hi_x, TOP + 0.05, hi_z, None)
        if x0 == x1:
            for e in (-1, 1):
                banks.box(x0 + e * width / 2, TOP, lo_z, x0 + e * (width / 2 + 0.8), TOP + 0.45, hi_z, B4["rock"][1])
        else:
            for e in (-1, 1):
                banks.box(lo_x, TOP, z0 + e * width / 2, hi_x, TOP + 0.45, z0 + e * (width / 2 + 0.8), B4["rock"][1])


def pool(s, x0, z0, x1, z1, stones=()):
    banks = s.new("Bank", "Water")
    water = s.new("GlowWater", "Water", glow=True)
    water.box(x0, TOP - 0.3, z0, x1, TOP + 0.05, z1, None)
    rng = s.rng
    x = x0 - 1
    while x < x1 + 1:
        for z in (z0 - 0.5, z1 + 0.5):
            if rng.random() < 0.8:
                banks.cube(x, TOP, z, 1.6, rng.uniform(0.4, 0.9), 1.4, jit(rng, B4["rock"][1], 6))
        x += 1.7
    z = z0
    while z < z1:
        for xx in (x0 - 0.5, x1 + 0.5):
            if rng.random() < 0.8:
                banks.cube(xx, TOP, z, 1.4, rng.uniform(0.4, 0.9), 1.6, jit(rng, B4["rock"][1], 6))
        z += 1.7
    for sx, sz in stones:
        banks.cube(sx, TOP, sz, 1.8, 0.35, 1.4, B4["stone"])


def bridge(s, cx, cz, along_x=False):
    """The room's plank bridge, crossing a north-south or east-west run."""
    o = s.new("Bridge", "Water")
    L, W = 5.6, 3.0
    for k in range(5):
        t = -L / 2 + 0.56 + k * (L - 1.12) / 4
        if along_x:
            o.cube(cx + t, TOP + 0.5, cz, 1.0, 0.35, W, jit(s.rng, B4["plank"], 6))
        else:
            o.cube(cx, TOP + 0.5, cz + t, W, 0.35, 1.0, jit(s.rng, B4["plank"], 6))
    for a in (-1, 1):
        for b in (-1, 1):
            x, z = (cx + a * L / 2, cz + b * W / 2) if along_x else (cx + b * W / 2, cz + a * L / 2)
            o.cube(x, TOP, z, 0.8, 1.4, 0.8, B4["plank_dk"])
            o.cube(x, TOP + 1.4, z, 0.9, 0.3, 0.9, (196, 150, 70))
    for e in (-1, 1):
        if along_x:
            o.box(cx - L / 2, TOP + 0.3, cz + e * (W / 2 - 0.2), cx + L / 2, TOP + 0.55, cz + e * (W / 2), B4["plank_dk"])
        else:
            o.box(cx + e * (W / 2 - 0.2), TOP + 0.3, cz - L / 2, cx + e * (W / 2), TOP + 0.55, cz + L / 2, B4["plank_dk"])


def rim(s, edge, a0, a1, rng_h, depth=(6, 12)):
    """A broken band of rock columns and walls along one outer edge."""
    rng = s.rng
    a = a0
    while a < a1:
        w = rng.uniform(3.5, 6.0)
        d = rng.uniform(*depth)
        h = rng.uniform(*rng_h)
        if edge in ("N", "S"):
            z = (-61 if edge == "N" else 61) + (d / 2 if edge == "N" else -d / 2)
            o = s.new("Wall", "Rocks")
            o.box(a, TOP, z - d / 2, a + w, TOP + h, z + d / 2, jit(rng, B4["rock"][rng.randrange(3)], 5))
            o.box(a + 0.4, TOP + h, z - d / 2 + 0.6, a + w - 0.4, TOP + h + 0.4, z + d / 2 - 0.6, B4["moss"][rng.randrange(3)] if rng.random() < 0.5 else B4["rock"][2])
            if rng.random() < 0.35:
                face = z + (d / 2 if edge == "N" else -d / 2)
                for k in range(3):
                    o.cube(a + w * (k + 1) / 4, TOP + h * 0.5, face, 0.35, h * 0.45, 0.35, B4["root"])
        else:
            x = (-76.5 if edge == "W" else 76.5) + (d / 2 if edge == "W" else -d / 2)
            o = s.new("Wall", "Rocks")
            o.box(x - d / 2, TOP, a, x + d / 2, TOP + h, a + w, jit(rng, B4["rock"][rng.randrange(3)], 5))
            o.box(x - d / 2 + 0.6, TOP + h, a + 0.4, x + d / 2 - 0.6, TOP + h + 0.4, a + w - 0.4, B4["moss"][rng.randrange(3)] if rng.random() < 0.5 else B4["rock"][2])
        a += w + rng.uniform(-0.6, 0.4)


def bogheart():
    s = Scene(4)
    rng = s.rng
    bog_floor(s)
    # Off the sheet: (px - 838) / 14.5, (py - 470) / 10.5.
    # The glowing stream leaving the room at z -2 both sides.
    stream(s, [(-21.2, -2), (-36, -2), (-36, 12)])
    pool(s, -52, 12, -32, 26, stones=[(-44, 16), (-41, 19), (-38, 22)])
    stream(s, [(-36, -2), (-48, -2), (-48, -11)])
    bridge(s, -29, -2, along_x=False)
    stream(s, [(21.2, -2), (50, -2), (50, -5)])
    bridge(s, 37, -2, along_x=False)
    stream(s, [(24, -2), (24, -14)])
    pool(s, 22, -22, 44, -15, stones=[(30, -18), (34, -19), (38, -18)])
    stream(s, [(44, -18), (60, -18), (60, 4)])
    stream(s, [(-60, 30), (-60, 48), (-40, 48)])
    pool(s, -40, 44, -28, 54)
    # side cave mouths, the stream running out of them
    cave_mouth(s, -48, -14)
    cave_mouth(s, 50, -8)
    # giant mushroom groves
    grove(s, -34, -31, 1.0)
    grove(s, 26, -38, 0.85)
    grove(s, 47, 11, 0.9)
    grove(s, -30, 33, 1.05)
    grove(s, 27, 36, 0.8)
    giant(s, -66, 4, 7, 5.5)
    giant(s, 66, 30, 8, 6)
    giant(s, 0, 50, 6, 5)
    # bog sprouts
    for cx, cz in [(-45, 4), (-25, 12), (-28, -12), (-9, -45), (23, -29), (33, -27), (33, 6), (52, 23), (-46, 32), (16, 45), (-60, -30), (62, -44)]:
        sprout(s, cx, cz)
    # rock columns: the outer rims and inner clusters
    rim(s, "N", -76.5, 76.5, (8, 15))
    rim(s, "W", -49, 49, (8, 14))
    rim(s, "E", -49, 49, (8, 14))
    rim(s, "S", -76.5, 76.5, (7, 13), depth=(5, 9))
    for cx, cz, h, roots in [
        (-60, -40, 14, True), (-40, -44, 12, False), (-22, -44, 10, True), (12, -44, 11, True), (36, -46, 13, False),
        (58, -36, 14, True), (-64, -20, 12, False), (-66, 18, 11, True), (64, -24, 12, False), (36, 20, 12, False),
        (40, 28, 10, True), (62, 40, 13, False), (-54, 42, 11, False), (-16, 46, 9, False), (44, 48, 10, True),
    ]:
        column(s, cx, cz, h, rng.uniform(3.5, 5.0), roots=roots)
    for cx, cz in [(-24, -24), (24, 24), (-56, 6), (56, -4), (8, -48)]:
        stalagmites(s, cx, cz)
    for cx, cz in [(-24, 22), (22, 12), (-40, -24), (40, -30), (-12, 38), (10, 38), (-14, -38), (52, 34), (-66, -8)]:
        rubble(s, cx, cz)
    # wall band: small glowing clusters at the room's outer wall feet
    for z in (-26, -14, 8, 20):
        for side in (-1, 1):
            mushrooms(s, side * 21, z, small=True)
    for x in (-15, -9, 9, 15):
        for side in (-1, 1):
            mushrooms(s, x, side * 32.6, small=True)
    return s


# ================================================================ preview


def preview(s, out, tints):
    """Painter's-algorithm render of every box face from a steep three-quarter
    view from the south, for holding against the sheet."""
    from PIL import Image, ImageDraw

    W, H = 1672, 941
    pitch = math.radians(58)
    scale = 10.8
    light = np.array([0.35, 0.85, 0.4])
    light /= np.linalg.norm(light)
    polys = []
    for o in s.objs:
        tint = tints.get(o.name.split("_")[0]) if o.glow else None
        for x0, y0, z0, x1, y1, z1, col in o.boxes:
            lo, hi = (x0, y0, z0), (x1, y1, z1)
            base = np.array(tint or col, float)
            for normal, corners in FACES:
                if normal[2] == -1 or normal[1] == -1:
                    continue  # faces away from a camera south of and above the scene
                pts = []
                depth = 0
                for k in corners:
                    p = [hi[i] if k[i] else lo[i] for i in range(3)]
                    sx = W / 2 + p[0] * scale
                    sy = H / 2 + (p[2] * math.sin(pitch) - p[1] * math.cos(pitch)) * scale
                    pts.append((sx, sy))
                    depth += p[2] * math.cos(pitch) + p[1] * math.sin(pitch)
                shade = 1.0 if tint else 0.55 + 0.45 * max(0, float(np.dot(normal, light)))
                polys.append((depth / 4, pts, tuple(int(min(255, c * shade)) for c in base)))
    polys.sort(key=lambda p: p[0])
    img = Image.new("RGB", (W, H), (210, 212, 216))
    d = ImageDraw.Draw(img)
    # the room, flat, so the outside reads against it
    rx, rz = HOLE
    d.polygon([(W / 2 + x * rx * scale, H / 2 + z * rz * math.sin(pitch) * scale) for x, z in ((-1, -1), (1, -1), (1, 1), (-1, 1))], fill=(120, 120, 130))
    for _, pts, col in polys:
        d.polygon(pts, fill=col)
    img.save(out)


AREAS = {
    "drowned": (drowned, "drowned_village_outer_arena_roblox.glb", {"Lamp": (255, 196, 110)}),
    "bogheart": (bogheart, "bogheart_caverns_outer_arena_roblox.glb", {"GlowCap": (90, 230, 240), "Sprout": (190, 240, 60), "GlowWater": (60, 220, 230)}),
}

if __name__ == "__main__":
    build, name, tints = AREAS[sys.argv[1]]
    scene = build()
    scene.check()
    if "--preview" in sys.argv:
        preview(scene, sys.argv[sys.argv.index("--preview") + 1], tints)
    else:
        scene.glb(HERE / name)
        print(f"wrote {name}")
