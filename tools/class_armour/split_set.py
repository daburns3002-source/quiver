"""Cuts a class armour set from Claude Design (`<class>_set.glb`: the set worn
by a grey blocky avatar) into the pieces `Config/ClassOutfits` names, one
closed mesh a piece, ready for the owner's Studio import.

    lune run tools/class_armour/dump_plan.luau . plan.json
    python -I tools/class_armour/split_set.py assets/models/armour/ranger_set.glb \
        plan.json Ranger assets/models/armour \
        [--front +z|-z|auto] [--body REGEX] [--sheet <class>_views.png]
        [--keep-colours] [--regions] [--stem NAME] [--assign FILE.json]

`--regions` is for a set built from its reference sheet rather than a block
plan (the 2026-11-13 remake): the pieces are the body's own parts (Head,
Chest with its shoulders, Back, Waist, each UpperArm, Forearm, Thigh, Shin
and Foot), Design's colours are kept, and every glowing block becomes a
glow. `--stem` names the output files (`ranger_male`), and `--assign` is a
JSON object of mesh-name patterns to pieces for a mesh that must go whole
to a piece wherever it stands (`{"braid": "Head"}`).

Writes `<class>_pieces.glb` (one mesh a piece, named as in the config, front
at -Z, in studs, vertex colours in sRGB), `<class>_pieces.json` (each
piece's body part, its size and its centre from that part's centre) and
`<class>_pieces.png` (the pieces file drawn on the standard body, under the
reference sheet when `--sheet` is given). Needs numpy, scipy and Pillow.

How it works. A Design set is built from stepped cubes, so every face lies
on an axis: the script refuses anything else. That lets it work in cells
instead of cutting triangles.

1. The grey body (meshes whose name matches `--body`) is measured and
   dropped. Each of its six regions (head, torso, each arm, each leg) is
   mapped onto the same region of the standard blocky R15 body
   (`ClassOutfits.standard`), and every armour mesh is moved by the map of
   the region it sits on: the armour then wraps the real body as tightly as
   it wrapped Design's, whose torso is a little shorter.
2. Each connected solid is turned into cells on the grid of its own corner
   coordinates (a winding count along X says which cells are inside).
3. A solid goes to the plan piece whose blocks hold it (cell by cell, the
   piece each cell is deepest inside or nearest to). One that spans two
   pieces (a boot and its sole made as one, a tunic that runs down over the
   hips) is cut where the plan's pieces meet, cell by cell.
4. A piece's solids are joined into one occupancy grid and its outside
   faces written again, one rectangle a flat patch of one colour: no inside
   faces, no holes at a cut (a cut is capped), and no edge left half
   matched (a rectangle whose edge carries a neighbour's corner is fanned
   from its middle). Each face takes the colour of the Design face it lies
   on; a cap takes its solid's main colour. A colour that is plainly one
   of the plan's takes the plan's value (those were tuned in the game);
   `--keep-colours` leaves Design's. A mesh is one material, so a glowing
   block (a crystal) is also written to the JSON as a box (`glow`) for the
   game to wear over the mesh as Neon.

Nothing is cut out of a body: that was the fault of the class bodies taken
out on 2026-11-07 (docs/FIXES.md, "Holes in the player bodies").
"""

import json
import math
import pathlib
import re
import struct
import sys

import numpy as np
from scipy.sparse import coo_matrix
from scipy.optimize import linear_sum_assignment
from scipy.sparse.csgraph import connected_components

EPS = 1e-4
HEIGHT = 5.183  # the standard body, feet to the top of the head
WHOLE = 0.85  # a solid this much inside one piece goes to it uncut
SNAP = 80  # a Design colour this near a plan colour (sum over R, G, B of 255) becomes it
REGIONS = {
    "Head": ["Head"],
    "Torso": ["UpperTorso", "LowerTorso"],
    "RightArm": ["RightUpperArm", "RightLowerArm", "RightHand"],
    "LeftArm": ["LeftUpperArm", "LeftLowerArm", "LeftHand"],
    "RightLeg": ["RightUpperLeg", "RightLowerLeg", "RightFoot"],
    "LeftLeg": ["LeftUpperLeg", "LeftLowerLeg", "LeftFoot"],
}

# The body parts whose pieces a mesh on each region may become. A shoulder
# plate is drawn on the arm and worn on the chest (a raised arm turns under
# it), so an arm's meshes may go to the chest's pieces too.
WEARS = {
    "Head": ["Head"],
    "Torso": ["UpperTorso", "LowerTorso"],
    "RightArm": ["RightUpperArm", "RightLowerArm", "UpperTorso"],
    "LeftArm": ["LeftUpperArm", "LeftLowerArm", "UpperTorso"],
    "RightLeg": ["RightUpperLeg", "RightLowerLeg", "RightFoot"],
    "LeftLeg": ["LeftUpperLeg", "LeftLowerLeg", "LeftFoot"],
}

# ---------------------------------------------------------------- GLB in/out

COMPONENT = {5120: "b", 5121: "B", 5122: "h", 5123: "H", 5125: "I", 5126: "f"}
WIDTH = {"SCALAR": 1, "VEC2": 2, "VEC3": 3, "VEC4": 4, "MAT4": 16}


def _chunks(path):
    data = pathlib.Path(path).read_bytes()
    off, gltf, binary = 12, None, b""
    while off < len(data):
        length, kind = struct.unpack_from("<II", data, off)
        chunk = data[off + 8 : off + 8 + length]
        if kind == 0x4E4F534A:
            gltf = json.loads(chunk)
        elif kind == 0x004E4942:
            binary = chunk
        off += 8 + length
    return gltf, binary


def _accessor(gltf, binary, index):
    acc = gltf["accessors"][index]
    view = gltf["bufferViews"][acc["bufferView"]]
    kind, width = COMPONENT[acc["componentType"]], WIDTH[acc["type"]]
    item = np.dtype("<" + kind)
    stride = view.get("byteStride") or item.itemsize * width
    start = view.get("byteOffset", 0) + acc.get("byteOffset", 0)
    raw = np.frombuffer(binary, np.uint8, count=stride * (acc["count"] - 1) + item.itemsize * width, offset=start)
    rows = np.lib.stride_tricks.as_strided(raw, (acc["count"], item.itemsize * width), (stride, 1))
    out = np.ascontiguousarray(rows).view(item).reshape(acc["count"], width).astype(np.float64)
    if acc.get("normalized"):
        out /= np.iinfo(item).max
    return out


def _local(node):
    if "matrix" in node:
        return np.array(node["matrix"], float).reshape(4, 4).T
    m = np.eye(4)
    x, y, z, w = node.get("rotation", [0, 0, 0, 1])
    m[:3, :3] = [
        [1 - 2 * (y * y + z * z), 2 * (x * y - z * w), 2 * (x * z + y * w)],
        [2 * (x * y + z * w), 1 - 2 * (x * x + z * z), 2 * (y * z - x * w)],
        [2 * (x * z - y * w), 2 * (y * z + x * w), 1 - 2 * (x * x + y * y)],
    ]
    m[:3, :3] *= np.array(node.get("scale", [1, 1, 1]), float)
    m[:3, 3] = node.get("translation", [0, 0, 0])
    return m


def read_glb(path):
    """Every mesh node as world-space triangles with a linear colour and a
    glow flag a triangle: [{name, tris (n,3,3), colour (n,3), glow (n,)}]."""
    gltf, binary = _chunks(path)
    out = []

    def walk(index, parent):
        node = gltf["nodes"][index]
        world = parent @ _local(node)
        if "mesh" in node:
            tris, colours, glows = [], [], []
            for prim in gltf["meshes"][node["mesh"]]["primitives"]:
                pos = _accessor(gltf, binary, prim["attributes"]["POSITION"])
                pos = pos @ world[:3, :3].T + world[:3, 3]
                if "indices" in prim:
                    faces = _accessor(gltf, binary, prim["indices"]).astype(int).reshape(-1, 3)
                else:
                    faces = np.arange(len(pos)).reshape(-1, 3)
                mat = gltf["materials"][prim["material"]] if "material" in prim else {}
                base = np.array(mat.get("pbrMetallicRoughness", {}).get("baseColorFactor", [1, 1, 1, 1])[:3], float)
                colour = np.tile(base, (len(faces), 1))
                if "COLOR_0" in prim["attributes"]:
                    vertex = _accessor(gltf, binary, prim["attributes"]["COLOR_0"])[:, :3]
                    colour = colour * vertex[faces].mean(axis=1)
                strength = mat.get("extensions", {}).get("KHR_materials_emissive_strength", {}).get("emissiveStrength", 1)
                glow = max(mat.get("emissiveFactor", [0, 0, 0])) * strength > 0.05
                tris.append(pos[faces])
                colours.append(colour)
                glows.append(np.full(len(faces), glow))
            out.append({
                "name": node.get("name", f"node{index}"),
                "tris": np.concatenate(tris),
                "colour": np.concatenate(colours),
                "glow": np.concatenate(glows),
            })
        for child in node.get("children", []):
            walk(child, world)

    for root in gltf["scenes"][gltf.get("scene", 0)]["nodes"]:
        walk(root, np.eye(4))
    return out


def write_glb(path, meshes):
    """`meshes`: [{name, centre, pos (n,3) from the centre, normal (n,3),
    colour (n,4) uint8 sRGB, faces (m,3)}], one node and one mesh each."""
    gltf = {
        "asset": {"version": "2.0", "generator": "tools/class_armour/split_set.py"},
        "scene": 0,
        "scenes": [{"nodes": list(range(len(meshes)))}],
        "nodes": [], "meshes": [], "accessors": [], "bufferViews": [],
        "materials": [{"name": "VertexColour", "pbrMetallicRoughness": {"metallicFactor": 0, "roughnessFactor": 1}}],
        "buffers": [{}],
    }
    blob = bytearray()

    def add(array, kind, target, normalized=False, bounds=False):
        raw = array.tobytes()
        gltf["bufferViews"].append({"buffer": 0, "byteOffset": len(blob), "byteLength": len(raw), "target": target})
        blob.extend(raw + b"\0" * (-len(raw) % 4))
        acc = {
            "bufferView": len(gltf["bufferViews"]) - 1,
            "componentType": {"f4": 5126, "u1": 5121, "u4": 5125}[array.dtype.str[1:]],
            "count": len(array), "type": kind,
        }
        if normalized:
            acc["normalized"] = True
        if bounds:
            acc["min"], acc["max"] = array.min(0).tolist(), array.max(0).tolist()
        gltf["accessors"].append(acc)
        return len(gltf["accessors"]) - 1

    for index, mesh in enumerate(meshes):
        prim = {
            "attributes": {
                "POSITION": add(mesh["pos"].astype("<f4"), "VEC3", 34962, bounds=True),
                "NORMAL": add(mesh["normal"].astype("<f4"), "VEC3", 34962),
                "COLOR_0": add(mesh["colour"].astype(np.uint8), "VEC4", 34962, normalized=True),
            },
            "indices": add(mesh["faces"].astype("<u4").reshape(-1), "SCALAR", 34963),
            "material": 0,
        }
        gltf["meshes"].append({"name": mesh["name"], "primitives": [prim]})
        gltf["nodes"].append({"name": mesh["name"], "mesh": index, "translation": [float(v) for v in mesh["centre"]]})
    gltf["buffers"][0]["byteLength"] = len(blob)
    text = json.dumps(gltf, separators=(",", ":")).encode()
    text += b" " * (-len(text) % 4)
    total = 12 + 8 + len(text) + 8 + len(blob)
    with open(path, "wb") as handle:
        handle.write(struct.pack("<III", 0x46546C67, 2, total))
        handle.write(struct.pack("<II", len(text), 0x4E4F534A) + text)
        handle.write(struct.pack("<II", len(blob), 0x004E4942) + bytes(blob))


# ------------------------------------------------------------------ geometry


def to_srgb(linear):
    linear = np.clip(np.asarray(linear, float), 0, 1)
    return np.where(linear <= 0.0031308, linear * 12.92, 1.055 * np.power(linear, 1 / 2.4) - 0.055)


def solids(tris):
    """Which connected solid each triangle belongs to (corners welded)."""
    _, ids = np.unique(np.round(tris.reshape(-1, 3) / EPS).astype(np.int64), axis=0, return_inverse=True)
    ids = ids.reshape(-1, 3)
    count = ids.max() + 1
    rows = np.concatenate([ids[:, 0], ids[:, 1]])
    cols = np.concatenate([ids[:, 1], ids[:, 2]])
    _, label = connected_components(coo_matrix((np.ones(len(rows)), (rows, cols)), (count, count)), directed=False)
    return label[ids[:, 0]]


def facing(tris):
    """Each triangle's axis (0, 1, 2) and the sign of its normal on it; -1
    for a triangle that lies on no axis or has no area."""
    normal = np.cross(tris[:, 1] - tris[:, 0], tris[:, 2] - tris[:, 0])
    length = np.linalg.norm(normal, axis=1)
    axis = np.abs(normal).argmax(axis=1)
    rows = np.arange(len(tris))
    flat = np.ptp(tris[rows, :, axis], axis=1) < EPS
    ok = (length > 1e-12) & flat
    return np.where(ok, axis, -1), np.sign(normal[rows, axis]), length


def lines(values, extra=()):
    """Sorted grid coordinates, near-equal ones merged."""
    values = np.sort(np.concatenate([np.ravel(values), np.asarray(extra, float)]))
    keep = np.concatenate([[True], np.diff(values) > EPS])
    return values[keep]


def samples(grid):
    """A point inside each cell, off its centre: a quad's diagonal runs
    through the centres of the cells along it and would be counted twice."""
    return (
        grid[0][:-1] + np.diff(grid[0]) * 0.5,
        grid[1][:-1] + np.diff(grid[1]) * 0.4142,
        grid[2][:-1] + np.diff(grid[2]) * 0.5774,
    )


def covers(tri2, u, v):
    """Which points of the (u, v) grid a 2D triangle holds."""
    (ax, ay), (bx, by), (cx, cy) = tri2
    uu, vv = np.meshgrid(u, v, indexing="ij")
    d1 = (uu - bx) * (ay - by) - (ax - bx) * (vv - by)
    d2 = (uu - cx) * (by - cy) - (bx - cx) * (vv - cy)
    d3 = (uu - ax) * (cy - ay) - (cx - ax) * (vv - ay)
    neg = (d1 < 0) | (d2 < 0) | (d3 < 0)
    pos = (d1 > 0) | (d2 > 0) | (d3 > 0)
    return ~(neg & pos)


def inside(tris, grid):
    """Which cells of the grid a closed solid fills: the faces across X that
    a ray from the cell to +X leaves through, less those it enters by."""
    axis, sign, _ = facing(tris)
    _, sy, sz = samples(grid)
    count = np.zeros((len(grid[0]), len(sy), len(sz)), np.int32)
    for tri, s in zip(tris[axis == 0], sign[axis == 0]):
        plane = int(np.abs(grid[0] - tri[0, 0]).argmin())
        ys = slice(np.searchsorted(grid[1], tri[:, 1].min() - EPS, "right") - 1, np.searchsorted(grid[1], tri[:, 1].max() - EPS))
        zs = slice(np.searchsorted(grid[2], tri[:, 2].min() - EPS, "right") - 1, np.searchsorted(grid[2], tri[:, 2].max() - EPS))
        ys, zs = slice(max(ys.start, 0), ys.stop), slice(max(zs.start, 0), zs.stop)
        count[plane, ys, zs] += int(s) * covers(tri[:, 1:], sy[ys], sz[zs])
    winding = np.cumsum(count[::-1], axis=0)[::-1][1:]
    return winding != 0


def box_distance(points, lo, hi):
    """How far each point is outside a box (negative: that deep inside)."""
    return np.max(np.maximum(lo - points, points - hi), axis=-1)


def region_pieces(body):
    """The pieces of a set cut by the body alone (`--regions`), for a model
    richer than its block plan: one piece a body part, named for it, plus the
    chest's shoulders (a shoulder guard is drawn over the arm and worn on the
    chest, so a raised arm turns under it) and a back piece (a quiver, a
    cape). Each as {name: (part, [boxes])}; a solid goes to the piece whose
    boxes it is deepest inside."""
    def box(x0, x1, y0, y1, z0, z1):
        return np.array([x0, y0, z0], float), np.array([x1, y1, z1], float)

    head, upper, lower = body["Head"], body["UpperTorso"], body["LowerTorso"]
    shoulder = 0.86  # the first plan's line between a shoulder plate and a sleeve
    back = upper[1][2] + 0.05
    pieces = {
        "Head": ("Head", [box(-4, 4, head[0][1], head[1][1] + 5, -4, 4)]),
        "Chest": ("UpperTorso", [
            box(-1.25, 1.25, upper[0][1], upper[1][1] + 0.4, -1.6, back),
            box(1.0, 3.0, shoulder, 2.4, -1.4, 1.4),
            box(-3.0, -1.0, shoulder, 2.4, -1.4, 1.4),
        ]),
        "Back": ("UpperTorso", [box(-2.0, 2.0, lower[0][1] - 0.7, upper[1][1] + 1.6, back, 3.0)]),
        "Waist": ("LowerTorso", [box(-1.6, 1.6, -2.1, lower[1][1], -1.6, back)]),
    }
    for side, sign in (("Right", 1), ("Left", -1)):
        def limb(part, top=None, bottom=None):
            lo, hi = body[side + part]
            xs = sorted([sign * 0.0 if "Leg" in part or "Foot" in part else sign * 0.95, sign * 3.0])
            return box(xs[0], xs[1], lo[1] if bottom is None else bottom, hi[1] if top is None else top, -1.6, 1.6)

        pieces[side + "UpperArm"] = (side + "UpperArm", [limb("UpperArm")])
        pieces[side + "Forearm"] = (side + "LowerArm", [limb("LowerArm", bottom=body[side + "Hand"][0][1])])
        pieces[side + "Thigh"] = (side + "UpperLeg", [limb("UpperLeg", top=lower[0][1])])
        pieces[side + "Shin"] = (side + "LowerLeg", [limb("LowerLeg")])
        pieces[side + "Foot"] = (side + "Foot", [limb("Foot")])
    return pieces


class Plan:
    def __init__(self, path, cls, regions=False):
        data = json.load(open(path))
        self.body = {b["part"]: (np.array(b["min"]), np.array(b["max"])) for b in data["body"]}
        self.floor = data["floor"]
        self.face = data.get("face", {"halfWidth": 0.45, "bottom": -0.45, "top": 0.3})
        self.pieces, self.part = {}, {}
        if regions:
            for name, (part, boxes) in region_pieces(self.body).items():
                self.pieces[name], self.part[name] = boxes, part
            # no block plan to take tuned colours from: Design's stay, and
            # every glowing block is a glow
            self.colours, self.glowing = [], None
        else:
            for block in data["sets"][cls]:
                self.pieces.setdefault(block["piece"], []).append((np.array(block["min"]), np.array(block["max"])))
                self.part[block["piece"]] = block["part"]
            self.colours = sorted({tuple(int(round(v * 255)) for v in block["colour"]) for block in data["sets"][cls]})
            self.glowing = {tuple(int(round(v * 255)) for v in block["colour"]) for block in data["sets"][cls] if block["glow"]}
        self.names = list(self.pieces)
        self.region = {}
        for name, parts in REGIONS.items():
            lo = np.min([self.body[p][0] for p in parts], axis=0)
            hi = np.max([self.body[p][1] for p in parts], axis=0)
            if name.endswith("Leg"):
                # an R15 thigh runs up inside the hips; the leg Design
                # drew, like the one seen, stops under them
                hi[1] = self.body["LowerTorso"][0][1]
            self.region[name] = (lo, hi)

    def distance(self, points, piece):
        return np.min([box_distance(points, lo, hi) for lo, hi in self.pieces[piece]], axis=0)


def nearest_region(centre, boxes):
    return min(boxes, key=lambda name: float(np.linalg.norm(np.maximum(0, np.maximum(boxes[name][0] - centre, centre - boxes[name][1])))))


def hinted(name, centre):
    """A body mesh's region from its name, when it says (`avatar_upperArm_L`):
    a blocky body's arms touch its torso, so by place alone an arm's middle
    can sit on the torso's edge. Right is +X here, the character's right."""
    low = name.lower()
    side = "Right" if centre[0] > 0 else "Left"
    if re.search(r"arm|hand|wrist|elbow", low):
        return side + "Arm"
    if re.search(r"leg|thigh|shin|calf|knee|foot|feet", low):
        return side + "Leg"
    if re.search(r"head|face|eye|hair|mouth", low):
        return "Head"
    if re.search(r"torso|chest|waist|hip|belly|body", low):
        return "Torso"
    return None


def fit_to_standard(meshes, plan, body_pattern, front, legs_to_middle=False):
    """Moves every armour mesh onto the standard body. Returns the armour
    meshes (body dropped) and a line of notes for the report."""
    body = [m for m in meshes if re.search(body_pattern, m["name"], re.I)]
    armour = [m for m in meshes if not re.search(body_pattern, m["name"], re.I)]
    if not body or not armour:
        raise SystemExit(f"no body or no armour found with --body {body_pattern!r}: {[m['name'] for m in meshes]}")
    points = np.concatenate([m["tris"].reshape(-1, 3) for m in body])
    lo, hi = points.min(0), points.max(0)
    scale = HEIGHT / (hi[1] - lo[1])
    turn = -1.0 if front == "+z" else 1.0
    centres = [(m["tris"].reshape(-1, 3).min(0) + m["tris"].reshape(-1, 3).max(0)) / 2 for m in body]
    mid_z = float(np.median([c[2] for c in centres]))

    def uniform(p):
        q = (p - np.array([(lo[0] + hi[0]) / 2, lo[1], mid_z])) * scale
        q[..., 0] *= turn
        q[..., 2] *= turn
        q[..., 1] += plan.floor
        return q

    # the body's six regions as Design made them
    made = {}
    for mesh in body:
        tris = uniform(mesh["tris"])
        label = solids(tris)
        for one in np.unique(label):
            p = tris[label == one].reshape(-1, 3)
            a, b = p.min(0), p.max(0)
            if np.prod(b - a) < 0.05:  # an eye, a mouth
                continue
            name = hinted(mesh["name"], (a + b) / 2) or nearest_region((a + b) / 2, plan.region)
            old = made.get(name)
            made[name] = (a, b) if old is None else (np.minimum(old[0], a), np.maximum(old[1], b))
    if legs_to_middle:
        # a remade set's legs are drawn apart, its skirt and boots closed
        # on the inner side in the gap: each leg's region runs to the
        # body's middle, so that inner side lands at the standard leg's
        # inner edge instead of past it, where the middle would cut it off
        for name in ("RightLeg", "LeftLeg"):
            if name in made:
                leg_lo, leg_hi = made[name][0].copy(), made[name][1].copy()
                if (leg_lo[0] + leg_hi[0]) > 0:
                    leg_lo[0] = 0.0
                else:
                    leg_hi[0] = 0.0
                made[name] = (leg_lo, leg_hi)
    missing = [name for name in REGIONS if name not in made]
    if missing:
        raise SystemExit(f"the body has no {missing}: found {sorted(made)}")
    out = []
    for mesh in armour:
        tris = uniform(mesh["tris"])
        p = tris.reshape(-1, 3)
        # a mesh that reaches across the body's middle (a belt's skirt, a
        # cape) is on the trunk, however low its middle hangs
        across = p[:, 0].min() < -0.25 and p[:, 0].max() > 0.25
        choice = {name: made[name] for name in (("Head", "Torso") if across else made)}
        region = nearest_region((p.min(0) + p.max(0)) / 2, choice)
        (m_lo, m_hi), (s_lo, s_hi) = made[region], plan.region[region]
        tris = s_lo + (tris - m_lo) * (s_hi - s_lo) / (m_hi - m_lo)
        out.append({**mesh, "tris": tris, "region": region})
    stretch = {name: np.round((plan.region[name][1] - plan.region[name][0]) / (made[name][1] - made[name][0]), 3).tolist() for name in REGIONS}
    return out, {"scale": round(float(scale), 4), "body_meshes": [m["name"] for m in body], "region_stretch": stretch}


# -------------------------------------------------------------------- pieces


def split(armour, plan, assign=()):
    """Every solid as cells, handed to plan pieces; a mesh whose name
    matches one of `assign`'s (pattern, piece) goes to that piece whole,
    wherever it stands (a braid that belongs to the head, a shoulder guard
    to the chest). Returns
    {piece: [(grid, mask, tris, colour index, main colour)]}, the palette
    and report lines."""
    palette = []

    def colour_id(colour, glow):
        key = tuple(np.round(colour, 4)) + (bool(glow),)
        if key not in palette:
            palette.append(key)
        return palette.index(key)

    parts = {name: [] for name in plan.names}
    notes, went, glow = [], {}, {}
    for mesh in armour:
        axis, sign, area = facing(mesh["tris"])
        slanted = int(((axis < 0) & (area > 1e-9)).sum())
        if slanted:
            raise SystemExit(f"{mesh['name']}: {slanted} triangles lie on no axis; this script only cuts stepped cubes")
        keep = axis >= 0
        tris, colours, glows = mesh["tris"][keep], mesh["colour"][keep], mesh["glow"][keep]
        ids = np.array([colour_id(c, g) for c, g in zip(colours, glows)])
        # a solid only ever goes to pieces of the part of the body it is on
        allowed = [name for name in plan.names if plan.part[name] in WEARS[mesh["region"]]]
        forced = next((piece for pattern, piece in assign if re.search(pattern, mesh["name"], re.I)), None)
        if forced is not None and forced not in plan.names:
            raise SystemExit(f"--assign sends {mesh['name']} to {forced}, which is not one of {plan.names}")
        label = solids(tris)
        for one in np.unique(label):
            t, c = tris[label == one], ids[label == one]
            # the solid's glowing blocks (a crystal), each as a box: a mesh
            # is one material, so the game wears these over it as Neon
            lit = []
            for colour in np.unique(c[glows[label == one]]):
                shining = t[c == colour]
                group = solids(shining)
                for g in np.unique(group):
                    corners = shining[group == g].reshape(-1, 3)
                    lit.append((corners.min(0), corners.max(0), int(colour)))
            side = {"RightLeg": 1, "LeftLeg": -1}.get(mesh["region"], 0)
            middle = [[0.0] if side else [], [plan.floor], []]
            h_lo, h_hi = plan.body["Head"]
            h_mid = (h_lo + h_hi) / 2
            window = None
            if mesh["region"] == "Head":
                w = plan.face
                window = (-w["halfWidth"], w["halfWidth"], h_mid[1] + w["bottom"], h_mid[1] + w["top"], h_lo[2])
                middle = [list(window[:2]), [plan.floor, *window[2:4]], [window[4]]]

            def cells(extra):
                grid = [lines(t[:, :, a], list(extra[a]) + middle[a]) for a in range(3)]
                fill = inside(t, grid)
                if side:
                    # Design stands the legs apart to wrap each one; the
                    # standard legs touch, so each leg's armour stops at
                    # the middle and the two never share space
                    fill &= (samples(grid)[0] * side > 0)[:, None, None]
                # and nothing reaches under the floor (a sole drawn under
                # the foot would sink into the ground)
                gx, gy, gz = samples(grid)
                fill &= (gy > plan.floor)[None, :, None]
                if window:
                    # the face window (`ClassOutfits.face`) stays open: a
                    # brow or a collar that dips in front of it is trimmed
                    fill &= ~(
                        ((gx > window[0]) & (gx < window[1]))[:, None, None]
                        & ((gy > window[2]) & (gy < window[3]))[None, :, None]
                        & (gz < window[4])[None, None, :]
                    )
                return grid, fill

            grid, fill = cells([[], [], []])
            if not fill.any():
                notes.append(f"{mesh['name']}: a solid with nothing inside it (an open sheet?) was dropped")
                continue
            sx, sy, sz = samples(grid)
            centres = np.stack(np.meshgrid(sx, sy, sz, indexing="ij"), axis=-1)
            volume = np.einsum("i,j,k->ijk", np.diff(grid[0]), np.diff(grid[1]), np.diff(grid[2])) * fill
            # each cell belongs to the plan piece it is deepest inside (or
            # nearest to); a solid nearly all in one piece goes to it whole
            nearest = np.argmin(np.stack([plan.distance(centres, name) for name in allowed]), axis=0)
            share = {name: float(volume[nearest == i].sum() / volume.sum()) for i, name in enumerate(allowed)}
            best = forced or max(share, key=share.get)
            if forced:
                share = {forced: 1.0}
            areas = np.linalg.norm(np.cross(t[:, 1] - t[:, 0], t[:, 2] - t[:, 0]), axis=1)
            main = int(np.bincount(c, weights=areas).argmax())
            if share[best] >= WHOLE:
                parts[best].append((grid, fill, t, c, main))
                went.setdefault(mesh["name"], set()).add(best)
                glow.setdefault(best, []).extend(lit)
                continue
            # spans pieces: cut it where the plan's pieces meet
            wanted = [name for name in allowed if share[name] >= 0.05]
            lo, hi = [g[0] for g in grid], [g[-1] for g in grid]
            cuts = [[], [], []]
            for name in wanted:
                for b_lo, b_hi in plan.pieces[name]:
                    for a in range(3):
                        cuts[a] += [v for v in (b_lo[a], b_hi[a]) if lo[a] + EPS < v < hi[a] - EPS]
            grid, fill = cells(cuts)
            sx, sy, sz = samples(grid)
            centres = np.stack(np.meshgrid(sx, sy, sz, indexing="ij"), axis=-1)
            owner = np.argmin(np.stack([plan.distance(centres, name) for name in wanted]), axis=0)
            got = []
            for index, name in enumerate(wanted):
                mask = fill & (owner == index)
                if mask.any():
                    parts[name].append((grid, mask, t, c, main))
                    got.append(name)
            went.setdefault(mesh["name"], set()).update(got)
            for lo, hi, colour in lit:
                near = min(wanted, key=lambda name: float(plan.distance(((lo + hi) / 2)[None], name)[0]))
                glow.setdefault(near, []).append((lo, hi, colour))
            notes.append(f"{mesh['name']}: one solid cut between {', '.join(got)}")
    return parts, palette, notes, {name: sorted(pieces) for name, pieces in went.items()}, glow


def build(piece_parts):
    """One piece's solids as a single closed mesh: (corners, normals,
    colour ids, faces), or None when the piece got nothing."""
    if not piece_parts:
        return None
    grid = [lines(np.concatenate([p[0][a] for p in piece_parts])) for a in range(3)]
    shape = tuple(len(g) - 1 for g in grid)
    fill = np.zeros(shape, bool)
    main = np.full(shape, -1, np.int32)
    mid = [(g[:-1] + g[1:]) / 2 for g in grid]
    for part_grid, mask, _, _, colour in piece_parts:
        index = []
        for a in range(3):
            i = np.searchsorted(part_grid[a], mid[a], "right") - 1
            ok = (mid[a] > part_grid[a][0]) & (mid[a] < part_grid[a][-1])
            index.append((np.clip(i, 0, mask.shape[a] - 1), ok))
        here = mask[np.ix_(index[0][0], index[1][0], index[2][0])]
        here &= index[0][1][:, None, None] & index[1][1][None, :, None] & index[2][1][None, None, :]
        main[here & ~fill] = colour
        fill |= here
    tris = np.concatenate([p[2] for p in piece_parts])
    ids = np.concatenate([p[3] for p in piece_parts])
    axis_of, sign_of, _ = facing(tris)
    pad = np.pad(fill, 1)
    # the colour of every outside face: [axis][side] -> ids, -1 where none
    face = [[None, None] for _ in range(3)]
    for a in range(3):
        others = [b for b in range(3) if b != a]
        s_other = [samples(grid)[b] for b in others]
        for side, step in ((0, -1), (1, 1)):
            neighbour = np.roll(pad, -step, axis=a)[1:-1, 1:-1, 1:-1]
            shown = fill & ~neighbour
            colour = np.where(shown, main, -1)
            for plane in np.unique(np.nonzero(shown)[a]):
                at = grid[a][plane + side]
                on = (axis_of == a) & (np.abs(tris[:, 0, a] - at) < EPS)
                take = [slice(None)] * 3
                take[a] = plane
                want = shown[tuple(take)]
                got = np.full(want.shape, -1, np.int32)
                for pick in (sign_of == step, sign_of != step):  # the face looking the right way first
                    for tri, c in zip(tris[on & pick], ids[on & pick]):
                        hit = covers(tri[:, others], s_other[0], s_other[1]) & want & (got < 0)
                        got[hit] = c
                layer = colour[tuple(take)]
                layer[got >= 0] = got[got >= 0]
            face[a][side] = colour
    # one rectangle for every flat patch of one colour
    rects = []  # (axis, side, plane index, b0, b1, c0, c1, colour)
    for a in range(3):
        b, c = [(1, 2), (2, 0), (0, 1)][a]
        for side in (0, 1):
            ids = np.moveaxis(face[a][side], (a, b, c), (0, 1, 2))
            for plane in range(ids.shape[0]):
                layer = ids[plane].copy()
                for i, j in zip(*np.nonzero(layer >= 0)):
                    colour = layer[i, j]
                    if colour < 0:
                        continue
                    i1 = i + 1
                    while i1 < layer.shape[0] and layer[i1, j] == colour:
                        i1 += 1
                    j1 = j + 1
                    while j1 < layer.shape[1] and (layer[i:i1, j1] == colour).all():
                        j1 += 1
                    layer[i:i1, j:j1] = -1
                    rects.append((a, side, plane + side, i, i1, j, j1, int(colour)))
    # a rectangle whose edge carries a neighbour's corner is fanned from
    # its middle through that corner, so no edge is left half-matched
    def corner(a, plane, i, j):
        index = [0, 0, 0]
        index[a], index[(a + 1) % 3], index[(a + 2) % 3] = plane, i, j
        return tuple(index)

    known = set()
    for a, side, plane, i0, i1, j0, j1, _ in rects:
        known.update(corner(a, plane, i, j) for i in (i0, i1) for j in (j0, j1))
    corners, normals, colours, faces = [], [], [], []
    for a, side, plane, i0, i1, j0, j1, colour in rects:
        ring = [(i, j0) for i in range(i0, i1)] + [(i1, j) for j in range(j0, j1)]
        ring += [(i, j1) for i in range(i1, i0, -1)] + [(i0, j) for j in range(j1, j0, -1)]
        ring = [p for p in ring if p in ((i0, j0), (i1, j0), (i1, j1), (i0, j1)) or corner(a, plane, *p) in known]
        if not side:
            ring = ring[::-1]
        points = np.array([[grid[x][corner(a, plane, *p)[x]] for x in range(3)] for p in ring])
        base = len(corners)
        if len(ring) == 4:
            corners.extend(points)
            faces += [(base, base + 1, base + 2), (base, base + 2, base + 3)]
        else:
            corners.extend(points)
            corners.append((points.min(0) + points.max(0)) / 2)
            hub = base + len(ring)
            faces += [(hub, base + n, base + (n + 1) % len(ring)) for n in range(len(ring))]
        added = len(corners) - base
        normal = np.zeros(3)
        normal[a] = 1 if side else -1
        normals.extend([normal] * added)
        colours.extend([colour] * added)
    return np.array(corners), np.array(normals), np.array(colours), np.array(faces)


def face_blocked(plan, corners, faces):
    """How much of the face window (`ClassOutfits.face`) a head piece stands
    in front of, and the window left clear, in the head's space:
    (share 0..1, [x0, x1, y0, y1])."""
    lo, hi = plan.body["Head"]
    mid = (lo + hi) / 2
    w = plan.face
    x = np.linspace(-w["halfWidth"], w["halfWidth"], 91)[:-1] + w["halfWidth"] / 90
    y = np.linspace(w["bottom"], w["top"], 76)[:-1] + (w["top"] - w["bottom"]) / 150
    blocked = np.zeros((len(x), len(y)), bool)
    tri = corners[faces]
    flat = np.ptp(tri[:, :, 2], axis=1) < EPS  # faces that look along Z
    for t in tri[flat & (tri[:, 0, 2] < lo[2] - EPS)]:
        blocked |= covers(t[:, :2] - np.array([0, mid[1]]), x, y)
    clear = np.nonzero(~blocked)
    if not len(clear[0]):
        return 1.0, None
    window = [x[clear[0].min()], x[clear[0].max()], y[clear[1].min()], y[clear[1].max()]]
    return round(float(blocked.mean()), 3), np.round(window, 2).tolist()


def open_edges(corners, faces):
    """Edges of the welded mesh that are not matched by one running the
    other way: 0 for a closed solid."""
    _, ids = np.unique(np.round(corners / EPS).astype(np.int64), axis=0, return_inverse=True)
    f = ids[faces]
    edges = np.concatenate([f[:, [0, 1]], f[:, [1, 2]], f[:, [2, 0]]])
    count = {}
    for a, b in edges:
        count[(a, b)] = count.get((a, b), 0) + 1
    return sum(1 for (a, b), n in count.items() if count.get((b, a), 0) != n)


# -------------------------------------------------------------------- picture

VIEWS = [("FRONT", 0, 8), ("THREE-QUARTER", 35, 14), ("SIDE", 90, 8), ("BACK", 180, 8)]
W, H, SCALE = 520, 720, 98.0
LIGHT = np.array([-0.35, 0.85, -0.4]) / np.linalg.norm([-0.35, 0.85, -0.4])
SKIN, CLOTH = (0.953, 0.776, 0.627), (0.62, 0.65, 0.70)
SHIRT, TROUSERS, EYE, MOUTH = (0.36, 0.52, 0.72), (0.30, 0.32, 0.40), (0.2, 0.14, 0.1), (0.6, 0.35, 0.3)


def view_matrix(yaw, pitch):
    y, p = math.radians(yaw), math.radians(pitch)
    ry = np.array([[math.cos(y), 0, math.sin(y)], [0, 1, 0], [-math.sin(y), 0, math.cos(y)]])
    rx = np.array([[1, 0, 0], [0, math.cos(p), math.sin(p)], [0, -math.sin(p), math.cos(p)]])
    return rx @ np.diag([-1.0, 1.0, 1.0]) @ ry


def box_tris(lo, hi):
    lo, hi = np.array(lo, float), np.array(hi, float)
    out = []
    for a in range(3):
        b, c = [(1, 2), (2, 0), (0, 1)][a]
        for side in (0, 1):
            quad = np.tile(lo, (4, 1))
            quad[:, a] = hi[a] if side else lo[a]
            quad[1, b] = quad[2, b] = hi[b]
            quad[2, c] = quad[3, c] = hi[c]
            if not side:
                quad = quad[::-1]
            out += [quad[[0, 1, 2]], quad[[0, 2, 3]]]
    return np.array(out)


def draw(tris, colours, yaw, pitch):
    """A plain z-buffer: the same views and light as plan_views.py."""
    m = view_matrix(yaw, pitch)
    image = np.full((H, W, 3), 0.93)
    depth = np.full((H, W), np.inf)
    normal = np.cross(tris[:, 1] - tris[:, 0], tris[:, 2] - tris[:, 0])
    normal /= np.maximum(np.linalg.norm(normal, axis=1, keepdims=True), 1e-12)
    cam = tris @ m.T
    for tri, n, rgb in zip(cam, normal, colours):
        if (m @ n)[2] >= -1e-6:
            continue
        shade = 0.55 + 0.45 * max(0.0, float(n @ LIGHT) * 0.5 + 0.5)
        px, py, pz = W / 2 + tri[:, 0] * SCALE, H / 2 - (tri[:, 1] - 0.33) * SCALE, tri[:, 2]
        x0, x1 = max(int(px.min()), 0), min(int(px.max()) + 1, W - 1)
        y0, y1 = max(int(py.min()), 0), min(int(py.max()) + 1, H - 1)
        d = (py[1] - py[2]) * (px[0] - px[2]) + (px[2] - px[1]) * (py[0] - py[2])
        if x0 > x1 or y0 > y1 or abs(d) < 1e-9:
            continue
        gx, gy = np.meshgrid(np.arange(x0, x1 + 1) + 0.5, np.arange(y0, y1 + 1) + 0.5)
        a = ((py[1] - py[2]) * (gx - px[2]) + (px[2] - px[1]) * (gy - py[2])) / d
        b = ((py[2] - py[0]) * (gx - px[2]) + (px[0] - px[2]) * (gy - py[2])) / d
        c = 1 - a - b
        z = a * pz[0] + b * pz[1] + c * pz[2]
        sub = depth[y0 : y1 + 1, x0 : x1 + 1]
        hit = (a >= 0) & (b >= 0) & (c >= 0) & (z < sub)
        sub[hit] = z[hit]
        image[y0 : y1 + 1, x0 : x1 + 1][hit] = np.clip(np.array(rgb) * shade, 0, 1)
    return image


def picture(pieces_glb, plan, sheet, out, title):
    """The written pieces file, read back and drawn on the standard body."""
    from PIL import Image, ImageDraw

    tris, colours = [], []
    for part, (lo, hi) in plan.body.items():
        t = box_tris(lo, hi)
        tris.append(t)
        bare = part == "Head" or part.endswith("Hand") or part.endswith("Arm")
        legs = "Leg" in part or "Foot" in part or part == "LowerTorso"
        colours.append(np.tile(SKIN if bare else TROUSERS if legs else SHIRT, (len(t), 1)))
        if part == "Head":
            # a stand-in body is a person (owner, 2026-11-12): it has a face
            cy, front = (lo[1] + hi[1]) / 2, lo[2]
            features = [([s * 0.22 - 0.07, cy - 0.02, front - 0.012], [s * 0.22 + 0.07, cy + 0.2, front], EYE) for s in (-1, 1)]
            features.append(([-0.12, cy - 0.3, front - 0.012], [0.12, cy - 0.25, front], MOUTH))
            for f_lo, f_hi, colour in features:
                t = box_tris(f_lo, f_hi)
                tris.append(t)
                colours.append(np.tile(colour, (len(t), 1)))
    gltf, binary = _chunks(pieces_glb)
    for node in gltf["nodes"]:
        prim = gltf["meshes"][node["mesh"]]["primitives"][0]
        pos = _accessor(gltf, binary, prim["attributes"]["POSITION"]) + np.array(node["translation"])
        col = _accessor(gltf, binary, prim["attributes"]["COLOR_0"])[:, :3]
        faces = _accessor(gltf, binary, prim["indices"]).astype(int).reshape(-1, 3)
        tris.append(pos[faces])
        colours.append(col[faces[:, 0]])
    tris, colours = np.concatenate(tris), np.concatenate(colours)
    row = Image.new("RGB", (W * len(VIEWS), H + 40), (237, 237, 237))
    pen = ImageDraw.Draw(row)
    for index, (label, yaw, pitch) in enumerate(VIEWS):
        row.paste(Image.fromarray((draw(tris, colours, yaw, pitch) * 255).astype(np.uint8)), (W * index, 40))
        pen.text((W * index + 16, 12), f"{title} - {label}", fill=(40, 40, 40))
    if sheet:
        top = Image.open(sheet).convert("RGB")
        top = top.resize((row.width, round(top.height * row.width / top.width)))
        both = Image.new("RGB", (row.width, top.height + row.height), (237, 237, 237))
        both.paste(top, (0, 0))
        both.paste(row, (0, top.height))
        row = both
    row = row.resize((1400, round(row.height * 1400 / row.width)))  # a check picture, kept small in the repo
    row.save(out, optimize=True)


# ----------------------------------------------------------------------- main


def main(argv):
    flags = {
        "--front": "+z", "--body": r"^(avatar|body)", "--sheet": None, "--keep-colours": False,
        "--regions": False, "--stem": None, "--assign": None,
    }
    plain = []
    it = iter(argv)
    for arg in it:
        if arg in ("--keep-colours", "--regions"):
            flags[arg] = True
        elif arg in flags:
            flags[arg] = next(it)
        else:
            plain.append(arg)
    set_glb, plan_path, cls, out_dir = plain
    plan = Plan(plan_path, cls, flags["--regions"])
    assign = list(json.load(open(flags["--assign"])).items()) if flags["--assign"] else []
    source = read_glb(set_glb)
    want = flags["--front"]
    fronts = ["+z", "-z"]
    tries = []
    for front in fronts:
        armour, fit = fit_to_standard(source, plan, flags["--body"], front, flags["--regions"])
        # how far the armour's corners stand from the plan's blocks: the
        # plan has a back (a cloak, a drooping hat) and toes, so the
        # wrong way round fits worse
        corners = np.concatenate([m["tris"].reshape(-1, 3) for m in armour])
        miss = float(np.maximum(np.min([plan.distance(corners, name) for name in plan.names], axis=0), 0).mean())
        fit["front"], fit["miss"] = front, round(miss, 4)
        tries.append((miss, armour, fit))
    best = min(tries, key=lambda t: t[0])
    _, armour, fit = best if want == "auto" else next(t for t in tries if t[2]["front"] == want)
    fit["miss_other_way"] = next(round(t[0], 4) for t in tries if t[2] is not fit)
    turned_note = None if best[2] is fit or flags["--regions"] else f"the set fits the plan better facing {best[2]['front']} ({best[0]:.4f} against {fit['miss']}): check --front"
    parts, palette, notes, went, glow = split(armour, plan, assign)
    if turned_note:
        notes.append(turned_note)
    # The plan's colours are the ones tuned in the game (the steel and the
    # crystals were toned down once for glare), so a Design colour that is
    # plainly one of them takes its value; a colour the plan does not have
    # (a pale top edge) stays as Design made it.
    # Two Design colours never share one plan colour (a white top edge and
    # the steel under it stay apart): the pairing is the cheapest one to one.
    made = [tuple(int(round(v * 255)) for v in to_srgb(entry[:3])) for entry in palette]
    shade, snapped = dict(enumerate(made)), {}
    if plan.colours and made:
        gap = np.array([[sum(abs(a - b) for a, b in zip(rgb, c)) for c in plan.colours] for rgb in made], float)
        rows, cols = linear_sum_assignment(np.where(gap <= SNAP, gap, 1e4))
        for row, col in zip(rows, cols):
            if gap[row, col] <= SNAP and not flags["--keep-colours"]:
                shade[row] = plan.colours[col]
    for index, rgb in enumerate(made):
        snapped["#%02X%02X%02X" % rgb] = "#%02X%02X%02X" % shade[index]
    meshes, report, total = [], {}, 0
    for name in plan.names:
        built = build(parts[name])
        if built is None:
            if not flags["--regions"] or name != "Back":
                notes.append(f"{name}: NOTHING in the model fell to this piece")
            continue
        corners, normals, colour_ids, faces = built
        lo, hi = corners.min(0), corners.max(0)
        centre = (lo + hi) / 2
        b_lo, b_hi = plan.body[plan.part[name]]
        rgb = np.array([shade[i] for i in colour_ids], float)
        rgba = np.concatenate([rgb, np.full((len(rgb), 1), 255)], axis=1)
        meshes.append({"name": name, "centre": centre, "pos": corners - centre, "normal": normals, "colour": rgba, "faces": faces})
        gaps = open_edges(corners, faces)
        p_lo = np.min([b[0] for b in plan.pieces[name]], axis=0)
        p_hi = np.max([b[1] for b in plan.pieces[name]], axis=0)
        report[name] = {
            "part": plan.part[name],
            "size": np.round(hi - lo, 4).tolist(),
            "at": np.round(centre - (b_lo + b_hi) / 2, 4).tolist(),
            "triangles": len(faces),
            "open_edges": gaps,
            "glows": sorted({"#%02X%02X%02X" % shade[i] for i in set(colour_ids.tolist()) if palette[i][3]}),
            # the glowing blocks the plan also has glowing (its tuned Neon
            # colour), from the body part's centre like the piece itself
            "glow": [
                {
                    "size": np.round(g_hi - g_lo, 4).tolist(),
                    "at": np.round((g_lo + g_hi) / 2 - (b_lo + b_hi) / 2, 4).tolist(),
                    "colour": "#%02X%02X%02X" % shade[colour],
                }
                for g_lo, g_hi, colour in glow.get(name, [])
                if plan.glowing is None or shade[colour] in plan.glowing
            ],
            "plan_size": np.round(p_hi - p_lo, 3).tolist(),
            "from_plan": {"min": np.round(lo - p_lo, 3).tolist(), "max": np.round(hi - p_hi, 3).tolist()},
        }
        total += len(faces)
        if plan.part[name] == "Head":
            share, window = face_blocked(plan, corners, faces)
            report[name]["face_blocked"], report[name]["face_clear"] = share, window
            if share > 0.02:
                notes.append(f"{name}: stands in front of {share:.0%} of the face window; clear x {window and window[:2]}, y {window and window[2:]} of +-{plan.face['halfWidth']}, {plan.face['bottom']}..{plan.face['top']}")
    out = pathlib.Path(out_dir)
    stem = flags["--stem"] or cls.lower()
    write_glb(out / f"{stem}_pieces.glb", meshes)
    json.dump(
        {"class": cls, "units": "studs", "front": "-Z", "source": pathlib.Path(set_glb).name, "fit": fit, "triangles": total, "colours": snapped, "pieces": report, "meshes": went, "notes": notes},
        open(out / f"{stem}_pieces.json", "w"), indent="\t",
    )
    picture(out / f"{stem}_pieces.glb", plan, flags["--sheet"], out / f"{stem}_pieces.png", f"{stem.upper().replace('_', ' ')} PIECES")
    print(f"{stem}: {len(meshes)}/{len(plan.names)} pieces, {total} triangles")
    for name, row in report.items():
        print(f"  {name:14s} {row['part']:14s} tris {row['triangles']:5d} open {row['open_edges']} size {row['size']} plan {row['plan_size']} off min {row['from_plan']['min']} max {row['from_plan']['max']}")
    print("  colours:", ", ".join(f"{a}->{b}" if a != b else a for a, b in snapped.items()))
    print("  fit:", fit)
    for name, pieces in went.items():
        print(f"  mesh {name} -> {', '.join(pieces)}")
    for note in notes:
        print("  note:", note)
    bad = [name for name, row in report.items() if row["open_edges"]]
    wanted = [name for name in plan.names if not (flags["--regions"] and name == "Back")]
    if bad or any(name not in report for name in wanted) or total >= 10000:
        raise SystemExit(f"FAILED: open {bad}, pieces {len(meshes)}/{len(plan.names)}, triangles {total}")


if __name__ == "__main__":
    main(sys.argv[1:])
