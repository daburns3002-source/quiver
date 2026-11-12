"""Draws each class armour set's block plan (`Config/ClassOutfits`) as a
sheet of views: front, three-quarter, side, back and from the fight camera.

    lune run tools/class_armour/dump_plan.luau . plan.json
    python -I tools/class_armour/plan_views.py plan.json assets/concepts/blocky/players/armour

The sheets are the measured plan the Claude Design models are built to and
what Codex is shown when it draws a set's reference sheet. A plain z-buffer
over boxes: no dependencies but numpy and Pillow.
"""

import json
import math
import sys

import numpy as np
from PIL import Image, ImageDraw

SKIN = (0.953, 0.776, 0.627)
CLOTH = (0.62, 0.65, 0.70)
VIEWS = [("FRONT", 0, 8), ("THREE-QUARTER", 35, 14), ("SIDE", 90, 8), ("BACK", 180, 8), ("FIGHT CAMERA", 180, 58)]
W, H, SCALE = 520, 760, 98.0
LIGHT = np.array([-0.35, 0.85, -0.4])
LIGHT = LIGHT / np.linalg.norm(LIGHT)


def view_matrix(yaw, pitch):
    y, p = math.radians(yaw), math.radians(pitch)
    ry = np.array([[math.cos(y), 0, math.sin(y)], [0, 1, 0], [-math.sin(y), 0, math.cos(y)]])
    # the camera looks along +Z from in front of the model (its front is -Z),
    # so the model's right is on the left of the picture; a pitch looks down
    rx = np.array([[1, 0, 0], [0, math.cos(p), math.sin(p)], [0, -math.sin(p), math.cos(p)]])
    flip = np.diag([-1.0, 1.0, 1.0])
    return rx @ flip @ ry


FACES = [  # corner indices (x, y, z bits) and the face's normal
    ((0, 2, 6, 4), (-1, 0, 0)), ((1, 5, 7, 3), (1, 0, 0)),
    ((0, 4, 5, 1), (0, -1, 0)), ((2, 3, 7, 6), (0, 1, 0)),
    ((0, 1, 3, 2), (0, 0, -1)), ((4, 6, 7, 5), (0, 0, 1)),
]


def draw(boxes, yaw, pitch):
    m = view_matrix(yaw, pitch)
    colour = np.full((H, W, 3), 0.93)
    depth = np.full((H, W), np.inf)
    for lo, hi, rgb, glow in boxes:
        corners = np.array([[(hi if i & 1 else lo)[0], (hi if i & 2 else lo)[1], (hi if i & 4 else lo)[2]] for i in range(8)])
        cam = corners @ m.T
        sx = W / 2 + cam[:, 0] * SCALE
        sy = H / 2 - (cam[:, 1] - 0.33) * SCALE
        for quad, normal in FACES:
            n = m @ np.array(normal, float)
            if n[2] >= -1e-6:
                continue
            shade = 1.0 if glow else 0.55 + 0.45 * max(0.0, float(np.array(normal) @ LIGHT) * 0.5 + 0.5)
            for tri in ((quad[0], quad[1], quad[2]), (quad[0], quad[2], quad[3])):
                px, py, pz = sx[list(tri)], sy[list(tri)], cam[list(tri), 2]
                x0, x1 = max(int(px.min()), 0), min(int(px.max()) + 1, W - 1)
                y0, y1 = max(int(py.min()), 0), min(int(py.max()) + 1, H - 1)
                if x0 > x1 or y0 > y1:
                    continue
                gx, gy = np.meshgrid(np.arange(x0, x1 + 1) + 0.5, np.arange(y0, y1 + 1) + 0.5)
                d = (py[1] - py[2]) * (px[0] - px[2]) + (px[2] - px[1]) * (py[0] - py[2])
                if abs(d) < 1e-9:
                    continue
                a = ((py[1] - py[2]) * (gx - px[2]) + (px[2] - px[1]) * (gy - py[2])) / d
                b = ((py[2] - py[0]) * (gx - px[2]) + (px[0] - px[2]) * (gy - py[2])) / d
                c = 1 - a - b
                z = a * pz[0] + b * pz[1] + c * pz[2]
                sub = depth[y0:y1 + 1, x0:x1 + 1]
                hit = (a >= 0) & (b >= 0) & (c >= 0) & (z < sub)
                sub[hit] = z[hit]
                colour[y0:y1 + 1, x0:x1 + 1][hit] = np.clip(np.array(rgb) * shade, 0, 1)
    return Image.fromarray((colour * 255).astype(np.uint8))


def main(plan_path, out_dir):
    plan = json.load(open(plan_path))
    body = []
    for part in plan["body"]:
        bare = part["part"] == "Head" or part["part"].endswith("Hand")
        body.append((part["min"], part["max"], SKIN if bare else CLOTH, False))
        if part["part"] == "Head":
            lo, hi = part["min"], part["max"]
            cy, front = (lo[1] + hi[1]) / 2, lo[2]
            for side in (-1, 1):
                body.append(([side * 0.22 - 0.07, cy - 0.02, front - 0.012], [side * 0.22 + 0.07, cy + 0.2, front], (0.2, 0.14, 0.1), False))
            body.append(([-0.12, cy - 0.3, front - 0.012], [0.12, cy - 0.25, front], (0.6, 0.35, 0.3), False))
    for name, blocks in plan["sets"].items():
        boxes = body + [(b["min"], b["max"], tuple(b["colour"]), b["glow"]) for b in blocks]
        sheet = Image.new("RGB", (W * len(VIEWS), H + 40), (237, 237, 237))
        pen = ImageDraw.Draw(sheet)
        for index, (label, yaw, pitch) in enumerate(VIEWS):
            sheet.paste(draw(boxes, yaw, pitch), (W * index, 40))
            pen.text((W * index + 16, 12), f"{name.upper()} ARMOUR SET - {label}", fill=(40, 40, 40))
        path = f"{out_dir}/{name.lower()}_plan.png"
        sheet.save(path)
        print(path)


if __name__ == "__main__":
    main(sys.argv[1], sys.argv[2])
