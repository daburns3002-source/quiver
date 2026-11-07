"""Splits the Tripo player models into Roblox R15 rigs (Blender, headless).

    blender -b --factory-startup --python tools/player_rigs/split_r15.py -- <low_dir> <out_dir>

Each low-poly Tripo GLB (`assets/concepts/blocky/players/tripo/low`, one
textured mesh in an A-pose, 0.98 m tall, facing -Y) is cut into the 15 R15
body parts plus accessories, every face going whole to one piece, so no
triangle is added and every piece keeps the one texture and its UVs:

- Head: everything above the neck.
- The arms: past a shoulder plane and outside an armpit line, cut at the
  elbow and wrist across the arm.
- The rest: cut by height at the waist, hip, knee and ankle, legs split
  left and right. The skeleton is `SKELETONS` below; each hand's
  centre is found from the mesh (the outermost points in the A-pose).
- Accessories, picked by the texture colour under the face: a Hood or Hat
  (on the Head) and a Cape (on the UpperTorso, so it does not tear between
  the legs). They hang off the part they were cut from, so a colour slip
  never shows.

Writes `<out_dir>/<name>_r15.glb` (pieces named as R15 parts, facing -Z in
glTF, so Roblox's front) and `<out_dir>/<name>_r15.json`: every piece's
centre and size and every joint, in Roblox axes (X right, Y up, -Z front)
and model metres (1 m = 1 stud at import), feet at Y = 0.
`tools/player_rigs/rigs_to_luau.py` turns the JSON plus the Studio mesh ids
into `Config/PlayerModels`.
"""

import bpy
import bmesh
import colorsys
import json
import math
import os
import sys

import numpy as np
from mathutils import Vector

NAMES = [
    "ranger_male", "ranger_female", "arcanist_male", "arcanist_female",
    "warden_male", "warden_female", "assassin_male", "assassin_female",
]

# Model metres, Blender axes, the character's left side (+X). Read off the
# front and side renders (`render_check.py`).
DEFAULT = {
    "neck": 0.665,      # Head above this
    "shoulder": (0.135, 0.605),
    "waist": 0.47,
    "hip": (0.075, 0.385),
    "knee": (0.08, 0.215),
    "ankle": (0.085, 0.075),
    "toe": -0.07,       # Y of the toe tip, the foot runs from the ankle to it
    "armpit": 0.06,     # the armpit, this far under the shoulder joint
    "accessories": {},
}
SKELETONS = {
    "ranger_male": {"accessories": {"Hood": ("Head", "green")}},
    "ranger_female": {"shoulder": (0.12, 0.6), "accessories": {"Hood": ("Head", "green")}},
    "arcanist_male": {"shoulder": (0.145, 0.61), "accessories": {"Hood": ("Head", "blue_gold")}},
    "arcanist_female": {"shoulder": (0.12, 0.6), "neck": 0.655, "accessories": {"Hat": ("Head", "blue_gold_high")}},
    "warden_male": {"shoulder": (0.15, 0.62), "neck": 0.69, "accessories": {"Cape": ("UpperTorso", "red_back")}},
    "warden_female": {"shoulder": (0.13, 0.615), "neck": 0.67, "accessories": {"Cape": ("UpperTorso", "red_back")}},
    "assassin_male": {"accessories": {"Hood": ("Head", "dark")}},
    "assassin_female": {"shoulder": (0.125, 0.6), "accessories": {"Hood": ("Head", "dark")}},
}

ACCESSORY_PARENT = {}


def colour_rule(rule, rgb, c, neck):
    h, s, v = colorsys.rgb_to_hsv(*rgb)
    if rule == "green":
        return 0.17 < h < 0.45 and s > 0.25 and v > 0.12
    if rule == "blue_gold":
        blue = 0.55 < h < 0.75 and s > 0.35
        gold = 0.09 < h < 0.17 and s > 0.45 and v > 0.55
        return blue or gold
    if rule == "blue_gold_high":
        blue = 0.55 < h < 0.75 and s > 0.35
        gold = 0.09 < h < 0.17 and s > 0.45 and v > 0.55
        return (blue or gold) and c.z > neck + 0.08
    if rule == "red_back":
        red = (h < 0.04 or h > 0.93) and s > 0.45 and v > 0.2
        return red and c.y > 0.03
    if rule == "dark":
        return s < 0.25 and v < 0.38
    raise ValueError(rule)


def skeleton(cfg, verts):
    """Joints per side, Blender axes; hands found from the mesh."""
    j = {}
    for side, sx in (("Left", 1), ("Right", -1)):
        # the hand: the outermost points of this side in the A-pose
        xs = verts[:, 0] * sx
        outer = verts[xs > xs.max() - 0.045]
        hand = Vector(outer.mean(axis=0))
        sh = Vector((sx * cfg["shoulder"][0], 0.0, cfg["shoulder"][1]))
        arm = hand - sh
        wrist = sh + arm * 0.84
        elbow = sh + arm * 0.47
        hand_end = sh + arm * 1.08
        hip = Vector((sx * cfg["hip"][0], 0.0, cfg["hip"][1]))
        knee = Vector((sx * cfg["knee"][0], 0.0, cfg["knee"][1]))
        ankle = Vector((sx * cfg["ankle"][0], 0.0, cfg["ankle"][1]))
        toe = Vector((sx * cfg["ankle"][0], cfg["toe"], 0.02))
        j[side] = dict(shoulder=sh, elbow=elbow, wrist=wrist, hand=hand_end,
                       hip=hip, knee=knee, ankle=ankle, toe=toe)
    j["root"] = Vector((0, 0, cfg["hip"][1]))
    j["waist"] = Vector((0, 0, cfg["waist"]))
    j["neck"] = Vector((0, 0, cfg["neck"]))
    return j


def arm_side(cfg, j, c):
    """The arm a point belongs to, or None. Past the shoulder plane (between
    straight out and down the arm) and outside the armpit line (between
    straight down and down the arm), so the A-pose's gap splits arm from
    body."""
    side = "Left" if c.x > 0 else "Right"
    s = j[side]
    sx = 1 if side == "Left" else -1
    sh = s["shoulder"]
    d = (s["hand"] - sh).normalized()
    n_sh = (Vector((sx, 0, 0)) + d).normalized()
    if (c - sh).dot(n_sh) <= 0:
        return None
    pit = sh + Vector((-sx * 0.015, 0, -cfg["armpit"]))
    down = (d + Vector((0, 0, -1))).normalized()
    out = Vector((sx, 0, 0))
    m = (out - down * out.dot(down)).normalized()  # across the line, away from the body
    if (c - pit).dot(m) <= 0 and c.z < sh.z:
        return None
    return side


def classify(cfg, j, c):
    if c.z > cfg["neck"]:
        return "Head"
    side = arm_side(cfg, j, c)
    if side:
        s = j[side]
        d = s["hand"] - s["shoulder"]
        t = (c - s["shoulder"]).dot(d) / d.length_squared
        if t < (s["elbow"] - s["shoulder"]).length / d.length:
            return side + "UpperArm"
        if t < (s["wrist"] - s["shoulder"]).length / d.length:
            return side + "LowerArm"
        return side + "Hand"
    if c.z > cfg["waist"]:
        return "UpperTorso"
    if c.z > cfg["hip"][1]:
        return "LowerTorso"
    side = "Left" if c.x > 0 else "Right"
    if c.z > cfg["knee"][1]:
        return side + "UpperLeg"
    if c.z > cfg["ankle"][1]:
        return side + "LowerLeg"
    return side + "Foot"


def cuts(cfg, j):
    """Every cut as (point, normal, the two pieces it parts)."""
    up = Vector((0, 0, 1))
    out = [
        (j["neck"], up, {"Head", "UpperTorso", "LeftUpperArm", "RightUpperArm"}),
        (j["waist"], up, {"UpperTorso", "LowerTorso"}),
        (j["root"], up, {"LowerTorso", "LeftUpperLeg", "RightUpperLeg"}),
    ]
    for side, sx in (("Left", 1), ("Right", -1)):
        s = j[side]
        sh = s["shoulder"]
        d = (s["hand"] - sh).normalized()
        n_sh = (Vector((sx, 0, 0)) + d).normalized()
        pit = sh + Vector((-sx * 0.015, 0, -cfg["armpit"]))
        down = (d + Vector((0, 0, -1))).normalized()
        o = Vector((sx, 0, 0))
        m = (o - down * o.dot(down)).normalized()
        arm = side + "UpperArm"
        out += [
            (sh, n_sh, {"UpperTorso", arm}),
            (pit, m, {"UpperTorso", "LowerTorso", arm}),
            (s["elbow"], d, {arm, side + "LowerArm"}),
            (s["wrist"], d, {side + "LowerArm", side + "Hand"}),
            (s["knee"], up, {side + "UpperLeg", side + "LowerLeg"}),
            (s["ankle"], up, {side + "LowerLeg", side + "Foot"}),
        ]
    return out


def bisect(me, cfg, j):
    """Splits the faces lying across each cut, so every seam is the cut's
    straight line rather than the zigzag of whole triangles. Only the faces
    of the two pieces a cut parts are split; UVs are carried over."""
    bm = bmesh.new()
    bm.from_mesh(me)
    for co, no, pair in cuts(cfg, j):
        bm.faces.ensure_lookup_table()
        faces = [f for f in bm.faces if classify(cfg, j, f.calc_center_median()) in pair]
        # only faces that straddle the plane
        faces = [f for f in faces if min((v.co - co).dot(no) for v in f.verts) < -1e-6
                 < 1e-6 < max((v.co - co).dot(no) for v in f.verts)]
        if not faces:
            continue
        edges = list({e for f in faces for e in f.edges})
        verts = list({v for f in faces for v in f.verts})
        bmesh.ops.bisect_plane(bm, geom=faces + edges + verts, plane_co=co, plane_no=no)
    bmesh.ops.triangulate(bm, faces=[f for f in bm.faces if len(f.verts) > 3])
    bm.to_mesh(me)
    bm.free()


def close_up(bm, accessory):
    """Closes a piece so nothing shows through it in game (owner, 2026-11-07:
    "there are holes in the female ranger"). A body piece's open cuts get a
    cap, so a bent knee or a turned head shows the cap rather than the
    inside of the shell. An accessory (a thin hood, hat or cape) gets its
    back faces, so it reads from underneath too. Each new face takes the UVs
    of the edge it closes, so it is coloured like what is around it."""
    if accessory:
        dup = bmesh.ops.duplicate(bm, geom=list(bm.faces))
        faces = [g for g in dup["geom"] if isinstance(g, bmesh.types.BMFace)]
        bmesh.ops.reverse_faces(bm, faces=faces)
        return
    # glTF splits vertices along UV seams; weld them (UVs live on the loops,
    # so they survive) or every seam reads as a hole and the real cuts
    # tangle with them, leaving most of them open
    bmesh.ops.remove_doubles(bm, verts=bm.verts, dist=1e-5)
    uv = bm.loops.layers.uv.active
    # each boundary vertex's UV, from a face it already has
    at = {}
    for e in bm.edges:
        if e.is_boundary:
            for v in e.verts:
                if v not in at:
                    at[v] = v.link_loops[0][uv].uv.copy()
    edges = [e for e in bm.edges if e.is_boundary]
    if not edges:
        return
    new = bmesh.ops.holes_fill(bm, edges=edges, sides=0)["faces"]
    if new:
        tri = bmesh.ops.triangulate(bm, faces=new)["faces"]
        for f in tri:
            for loop in f.loops:
                if loop.vert in at:
                    loop[uv].uv = at[loop.vert]
    fan_fill(bm, uv, at)


def fan_fill(bm, uv, at):
    """Fans a cap from the centre of each hole holes_fill left (it skips a
    loop that touches another, where two cuts meet at one vertex). Each new
    triangle runs against the face beside its edge, so it faces outward."""
    left = {e for e in bm.edges if e.is_boundary}
    while left:
        e = left.pop()
        ring = [e]
        start, cur = e.verts[0], e.verts[1]
        while cur is not start:
            nxt = next((x for x in cur.link_edges if x in left), None)
            if nxt is None:
                break
            left.discard(nxt)
            ring.append(nxt)
            cur = nxt.other_vert(cur)
        vs = {v for x in ring for v in x.verts}
        if len(vs) < 3:
            continue
        c = bm.verts.new(sum((v.co for v in vs), Vector()) / len(vs))
        for x in ring:
            a, b = x.verts
            f0 = x.link_faces[0]
            for lp in f0.loops:
                if lp.vert is a and lp.link_loop_next.vert is b:
                    a, b = b, a
                    break
            try:
                f = bm.faces.new((a, b, c))
            except ValueError:
                continue
            for lp in f.loops:
                v = lp.vert if lp.vert is not c else a
                lp[uv].uv = at.get(v, v.link_loops[0][uv].uv)


def to_roblox(v):
    """Blender (X left of the character, -Y front, Z up) to Roblox."""
    return [-v[0], v[2], v[1]]


def run(low_dir, out_dir, only=None):
    os.makedirs(out_dir, exist_ok=True)
    report = []
    for name in NAMES:
        if only and name not in only:
            continue
        cfg = dict(DEFAULT)
        cfg.update(SKELETONS.get(name, {}))
        bpy.ops.wm.read_factory_settings(use_empty=True)
        bpy.ops.import_scene.gltf(filepath=os.path.join(low_dir, name + ".glb"))
        obj = next(o for o in bpy.data.objects if o.type == "MESH")
        bpy.context.view_layer.objects.active = obj
        for o in bpy.data.objects:
            o.select_set(o == obj)
        bpy.ops.object.parent_clear(type="CLEAR_KEEP_TRANSFORM")
        bpy.ops.object.transform_apply(location=True, rotation=True, scale=True)
        me = obj.data
        verts = np.array([v.co[:] for v in me.vertices])
        j = skeleton(cfg, verts)
        bisect(me, cfg, j)

        # the base colour texture, for the accessory colour rules
        mat = me.materials[0]
        img = None
        for n in mat.node_tree.nodes:
            if n.type == "TEX_IMAGE" and n.image and "basecolor" in n.image.name.lower():
                img = n.image
        if img is None:
            img = next(n.image for n in mat.node_tree.nodes if n.type == "TEX_IMAGE")
        w, h = img.size
        px = np.empty(w * h * 4, dtype=np.float32)
        img.pixels.foreach_get(px)
        px = px.reshape(h, w, 4)
        uv = me.uv_layers.active.data

        labels = []
        for poly in me.polygons:
            c = poly.center
            lab = classify(cfg, j, c)
            for acc, (parent, rule) in cfg["accessories"].items():
                if parent == "Head" and lab != "Head":
                    continue
                if parent == "UpperTorso" and (lab == "Head" or "Hand" in lab or "Foot" in lab):
                    continue
                u = sum(uv[li].uv[0] for li in poly.loop_indices) / poly.loop_total
                vv = sum(uv[li].uv[1] for li in poly.loop_indices) / poly.loop_total
                x = min(w - 1, max(0, int((u % 1.0) * w)))
                y = min(h - 1, max(0, int((vv % 1.0) * h)))
                # a byte image's pixels are its stored sRGB values
                rgb = tuple(float(p) for p in px[y, x, :3])
                if colour_rule(rule, rgb, c, cfg["neck"]):
                    lab = acc
            labels.append(lab)

        # one object per piece
        pieces = {}
        for lab in sorted(set(labels)):
            dup = obj.copy()
            dup.data = obj.data.copy()
            dup.name = lab
            dup.data.name = lab
            bpy.context.collection.objects.link(dup)
            bm = bmesh.new()
            bm.from_mesh(dup.data)
            bm.faces.ensure_lookup_table()
            bmesh.ops.delete(bm, geom=[f for f in bm.faces if labels[f.index] != lab], context="FACES")
            bmesh.ops.delete(bm, geom=[v for v in bm.verts if not v.link_faces], context="VERTS")
            close_up(bm, lab in cfg["accessories"])
            bm.to_mesh(dup.data)
            bm.free()
            pieces[lab] = dup
        bpy.data.objects.remove(obj)

        # Roblox's front is -Z in glTF, which is +Y in Blender: turn about Z
        out = {"parts": {}, "joints": {}, "accessories": {}, "tris": 0}
        for lab, o in pieces.items():
            co = np.array([v.co[:] for v in o.data.vertices])
            mn, mx = co.min(axis=0), co.max(axis=0)
            centre = (mn + mx) / 2
            o.data.transform(__import__("mathutils").Matrix.Translation(-Vector(centre)))
            o.location = Vector(centre)
            size = mx - mn
            out["parts"][lab] = {
                "centre": to_roblox(centre),
                "size": [float(size[0]), float(size[2]), float(size[1])],
                "tris": sum(len(p.vertices) - 2 for p in o.data.polygons),
            }
            out["tris"] += out["parts"][lab]["tris"]
        for acc, (parent, _) in cfg["accessories"].items():
            if acc in out["parts"]:
                out["accessories"][acc] = parent
        for side in ("Left", "Right"):
            s = j[side]
            for k in ("shoulder", "elbow", "wrist", "hip", "knee", "ankle"):
                out["joints"][side + k.capitalize()] = to_roblox(s[k])
        out["joints"]["Root"] = to_roblox(j["root"])
        out["joints"]["Waist"] = to_roblox(j["waist"])
        out["joints"]["Neck"] = to_roblox(j["neck"])
        out["height"] = float(verts[:, 2].max())

        # a parent empty named for the model; turn it to face Roblox's front
        root = bpy.data.objects.new(name, None)
        bpy.context.collection.objects.link(root)
        for o in pieces.values():
            o.parent = root
        root.rotation_euler = (0, 0, math.pi)
        bpy.ops.object.select_all(action="DESELECT")
        for o in list(pieces.values()) + [root]:
            o.select_set(True)
        bpy.ops.export_scene.gltf(
            filepath=os.path.join(out_dir, name + "_r15.glb"),
            use_selection=True, export_format="GLB", export_apply=True,
        )
        with open(os.path.join(out_dir, name + "_r15.json"), "w") as f:
            json.dump(out, f, indent=1)
        report.append(f"{name}: {len(pieces)} pieces, {out['tris']} tris, "
                      f"missing {sorted(set(R15) - set(pieces))}, acc {sorted(out['accessories'])}")
    return report


R15 = [
    "Head", "UpperTorso", "LowerTorso",
    "LeftUpperArm", "LeftLowerArm", "LeftHand", "RightUpperArm", "RightLowerArm", "RightHand",
    "LeftUpperLeg", "LeftLowerLeg", "LeftFoot", "RightUpperLeg", "RightLowerLeg", "RightFoot",
]

if __name__ == "__main__":
    argv = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else []
    lines = run(argv[0], argv[1], argv[2:] or None)
    with open(os.path.join(argv[1], "report.txt"), "w") as f:
        f.write("\n".join(lines) + "\n")
