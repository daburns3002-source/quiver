#!/usr/bin/env python3
"""Draw a lobby station flat, to hold against its reference sheet.

Studio's `screen_capture` returned a timeout on every call on 2026-11-02, the
same way it returned empty frames for the Angel, so this is how the Egg
Hatchery and the Blacksmith were checked against
`assets/concepts/blocky/lobby/ref_main.png`.

Feed it the rows `tools/studio/dump_station.luau` prints over MCP: one part a
line,

    Name|sx,sy,sz|x,y,z|rx,ry,rz|r,g,b|Shape|Material|Transparency

in the building's OWN frame (+Z the way it faces). It paints them back to
front from the sheet's own three-quarter view, with a flat light so faces
read apart, and writes a PNG.

    python tools/lobby_views.py parts.txt out.png [--yaw -32] [--pitch 34]
"""

import argparse
import math

import numpy as np
from PIL import Image, ImageDraw

# The sheet looks at each station from its front left, a little above the
# roof: these two are read off `ref_main.png`, where a ground axis falls
# about 0.55 of its run and the fronts of the buildings are fully open to
# the camera.
# The camera stands at -Z looking toward +Z, so a building whose own
# front is +Z is turned half round plus the sheet's own swing to face it.
YAW = 148.0
PITCH = 34.0
SCALE = 13.0
SUN = (-0.45, 0.78, -0.44)


def parse(path):
    parts = []
    for line in open(path, encoding="utf-8"):
        line = line.strip()
        if not line or line.startswith("#"):
            continue
        bits = line.split("|")
        name, size, pos, rot, colour, shape = bits[:6]
        transparency = float(bits[7]) if len(bits) > 7 else 0.0
        if transparency > 0.9:
            continue
        dims = [float(v) for v in size.split(",")]
        if shape == "Cylinder":
            # a pillar is a cylinder stood on end: its part size is
            # (height, across, across), so swap back to world X/Y/Z
            dims = [dims[1], dims[0], dims[2]]
        parts.append(
            {
                "name": name,
                "size": dims,
                "pos": [float(v) for v in pos.split(",")],
                "rot": [float(v) for v in rot.split(",")],
                "colour": tuple(int(v) for v in colour.split(",")),
                "shape": shape,
            }
        )
    return parts


def corners(part):
    sx, sy, sz = (v / 2 for v in part["size"])
    yaw = part["rot"][1]
    c, s = math.cos(yaw), math.sin(yaw)
    px, py, pz = part["pos"]
    out = []
    for dx in (-sx, sx):
        for dy in (-sy, sy):
            for dz in (-sz, sz):
                out.append((px + dx * c + dz * s, py + dy, pz - dx * s + dz * c))
    return out


FACES = [
    ((0, 1, 3, 2), (-1, 0, 0)),
    ((4, 6, 7, 5), (1, 0, 0)),
    ((0, 4, 5, 1), (0, -1, 0)),
    ((2, 3, 7, 6), (0, 1, 0)),
    ((0, 2, 6, 4), (0, 0, -1)),
    ((1, 5, 7, 3), (0, 0, 1)),
]


def project(p, yaw, pitch, scale):
    cy, sy = math.cos(math.radians(yaw)), math.sin(math.radians(yaw))
    cp, sp = math.cos(math.radians(pitch)), math.sin(math.radians(pitch))
    x, y, z = p
    rx = x * cy + z * sy
    rz = -x * sy + z * cy
    return (rx * scale, -(y * cp + rz * sp) * scale), rz * cp - y * sp


def shade(colour, normal, yaw):
    cy, sy = math.cos(math.radians(yaw)), math.sin(math.radians(yaw))
    nx, ny, nz = normal
    wx = nx * cy + nz * sy
    wz = -nx * sy + nz * cy
    lit = max(0.0, wx * SUN[0] + ny * SUN[1] + wz * SUN[2])
    k = 0.55 + 0.45 * lit
    return tuple(min(255, int(v * k)) for v in colour)


def draw(parts, path, yaw=YAW, pitch=PITCH, scale=SCALE):
    """Paint the parts into a depth buffer.

    A painter's sort was tried first and could not be made honest: a tall
    box's front face has a nearer centroid than a small thing standing in
    front of its foot, so the Blacksmith's chimney painted itself over its
    own forge fire. Every pixel carries its own depth here, so what is in
    front is what is in front.
    """
    cp, sp = math.cos(math.radians(pitch)), math.sin(math.radians(pitch))
    faces = []
    for part in parts:
        pts = corners(part)
        flat = [project(p, yaw, pitch, scale) for p in pts]
        if part["shape"] in ("Sphere", "Cylinder"):
            (cx, cy), depth = project(part["pos"], yaw, pitch, scale)
            hx = part["size"][0] / 2 * scale
            hz = part["size"][2] / 2 * scale * sp
            hy = part["size"][1] / 2 * scale * cp
            lit = shade(part["colour"], (0, 1, 0), yaw)
            # a round thing is two surfaces, not one: a FLAT cap, whose
            # depth runs straight across it like any other plane, and a
            # curved side that bulges toward the camera. Giving a flat
            # disc one bulge for both put the apron's near edge 23 studs
            # out and laid it over the whole building.
            px, py, pz = part["pos"]
            r = part["size"][0] / 2
            if part["shape"] == "Cylinder":
                top = py + part["size"][1] / 2
                probe = [
                    project(q, yaw, pitch, scale)
                    for q in ((px, top, pz), (px + r, top, pz), (px, top, pz + r))
                ]
                faces.append(
                    ("rect", (cx - hx, cy - hy, cx + hx, cy + hy),
                     shade(part["colour"], (0, 0, 1), yaw), ("round", depth, r, 0.0))
                )
                faces.append(
                    ("oval", (cx - hx, cy - hy - hz, cx + hx, cy - hy + hz), lit,
                     ("affine",) + tuple((q[0][0], q[0][1], q[1]) for q in probe))
                )
            else:
                faces.append(("oval", (cx - hx, cy - hy - hz, cx + hx, cy + hy + hz), lit,
                              ("round", depth, r, part["size"][1] / 2)))
            continue
        for idx, normal in FACES:
            quad = [flat[i] for i in idx]
            faces.append(("quad", [q[0] for q in quad], shade(part["colour"], normal, yaw),
                          [q[1] for q in quad]))

    xs, ys = [], []
    for kind, shape, _, _ in faces:
        if kind == "quad":
            xs += [q[0] for q in shape]
            ys += [q[1] for q in shape]
        else:
            xs += [shape[0], shape[2]]
            ys += [shape[1], shape[3]]
    pad = 24
    w = int(max(xs) - min(xs)) + pad * 2
    h = int(max(ys) - min(ys)) + pad * 2
    ox, oy = pad - min(xs), pad - min(ys)

    rgb = np.zeros((h, w, 3), dtype=np.uint8)
    rgb[:, :] = (126, 196, 86)
    zbuf = np.full((h, w), 1e9, dtype=np.float64)
    gy, gx = np.mgrid[0:h, 0:w]

    def stamp(mask, depth, colour):
        hit = mask & (depth < zbuf)
        zbuf[hit] = depth[hit]
        rgb[hit] = colour

    for kind, shape, colour, depth in faces:
        stencil = Image.new("1", (w, h), 0)
        pen = ImageDraw.Draw(stencil)
        if kind == "quad":
            pts = [(x + ox, y + oy) for x, y in shape]
            pen.polygon(pts, fill=1)
            # depth is affine in screen space under this projection, so
            # three corners fix it exactly
            (x0, y0), (x1, y1), (x2, y2) = pts[0], pts[1], pts[2]
            d0, d1, d2 = depth[0], depth[1], depth[2]
            det = (x1 - x0) * (y2 - y0) - (x2 - x0) * (y1 - y0)
            if abs(det) < 1e-9:
                plane = np.full((h, w), (d0 + d1 + d2) / 3)
            else:
                a = ((d1 - d0) * (y2 - y0) - (d2 - d0) * (y1 - y0)) / det
                b = ((d2 - d0) * (x1 - x0) - (d1 - d0) * (x2 - x0)) / det
                plane = d0 + a * (gx - x0) + b * (gy - y0)
        else:
            x0, y0, x1, y1 = (shape[0] + ox, shape[1] + oy, shape[2] + ox, shape[3] + oy)
            if kind == "oval":
                pen.ellipse([x0, y0, x1, y1], fill=1)
            else:
                pen.rectangle([x0, y0, x1, y1], fill=1)
            if depth[0] == "affine":
                (ax, ay, d0), (bx, by, d1), (ex, ey, d2) = depth[1:]
                ax, ay = ax + ox, ay + oy
                bx, by = bx + ox, by + oy
                ex, ey = ex + ox, ey + oy
                det = (bx - ax) * (ey - ay) - (ex - ax) * (by - ay)
                if abs(det) < 1e-9:
                    plane = np.full((h, w), (d0 + d1 + d2) / 3)
                else:
                    ca = ((d1 - d0) * (ey - ay) - (d2 - d0) * (by - ay)) / det
                    cb = ((d2 - d0) * (bx - ax) - (d1 - d0) * (ex - ax)) / det
                    plane = d0 + ca * (gx - ax) + cb * (gy - ay)
            else:
                _, centre, bulge, bulgeY = depth
                mx, my = (x0 + x1) / 2, (y0 + y1) / 2
                rx = max((x1 - x0) / 2, 1e-6)
                ry = max((y1 - y0) / 2, 1e-6)
                u = ((gx - mx) / rx) ** 2
                v = ((gy - my) / ry) ** 2 if bulgeY else 0.0
                plane = centre - bulge * np.sqrt(np.clip(1.0 - u - v, 0.0, 1.0))
        stamp(np.array(stencil, dtype=bool), plane, colour)

    Image.fromarray(rgb).save(path)
    return (w, h)


if __name__ == "__main__":
    ap = argparse.ArgumentParser()
    ap.add_argument("parts")
    ap.add_argument("out")
    ap.add_argument("--yaw", type=float, default=YAW)
    ap.add_argument("--pitch", type=float, default=PITCH)
    ap.add_argument("--scale", type=float, default=SCALE)
    a = ap.parse_args()
    print(draw(parse(a.parts), a.out, a.yaw, a.pitch, a.scale))
