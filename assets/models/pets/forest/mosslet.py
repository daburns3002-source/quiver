"""Build Mosslet, the Common forest pet. Run this file to export and preview."""
from pathlib import Path
import sys

import numpy as np

sys.dont_write_bytecode = True
sys.path.insert(0, str(Path(__file__).resolve().parents[2] / "blocky"))
from blocky import bevelled_box, box, decal, export, prism, render_preview


def build():
    parts = [bevelled_box((0, .50, 0), (1.18, 1.0, 1.02), .075, "#AFD33E"),
             bevelled_box((0, 1.015, 0), (1.10, .16, .96), .045, "#506E16")]
    # Small, quiet patches break up the moss without rounding its silhouette.
    for x, z, sx, sz, colour in [(-.35, -.29, .23, .16, "#638421"),
            (.30, .22, .25, .19, "#648920"), (.36, -.32, .18, .13, "#405E12"),
            (-.36, .28, .24, .16, "#789A28")]:
        parts.append(box((x, 1.096, z), (sx, .008, sz), colour))
    mushroom_start = len(parts)
    # One tiny square mushroom, on the viewer's right.
    parts += [box((.30, 1.15, -.07), (.17, .19, .17), "#F2E8C5"),
              bevelled_box((.30, 1.335, -.07), (.30, .26, .27), .018, "#FF8B26")]
    for x, y, s in [(.235, 1.39, .065), (.345, 1.27, .065)]:
        parts.append(decal((x, y, -.220), (s, s), "#FFF3D4", "Body"))
    parts.append(decal((.465, 1.38, -.105), (.05, .065), "#FFF3D4", "Body",
                       (0, -np.pi / 2, 0)))
    parts.append(box((.255, 1.466, -.09), (.065, .004, .06), "#FFF3D4"))
    for part in parts[mushroom_start:]:
        part.metadata["animation_group"] = "mushroom"
    # Broad angular leaves share one rooted point.
    parts.append(box((-.20, 1.14, .06), (.055, .16, .055), "#669818"))
    for outline, colour in [([(-.22, 1.14), (-.49, 1.32), (-.49, 1.49),
                              (-.35, 1.47), (-.17, 1.30)], "#85BD15"),
                            ([(-.22, 1.14), (-.15, 1.36), (.035, 1.48),
                              (.16, 1.49), (.16, 1.34)], "#91C91A")]:
        # Reverse the left leaf's clockwise outline for outward normals.
        area = sum(a[0]*b[1]-b[0]*a[1] for a, b in zip(outline, outline[1:]+outline[:1]))
        parts.append(prism((0, 0, .07), outline if area > 0 else outline[::-1], .075, colour))
        parts[-1].metadata["animation_group"] = "leaves"
    for x in (-.30, .30):
        eye = [(-.125, -.105), (-.08, -.155), (.08, -.155), (.125, -.105),
               (.125, .105), (.075, .155), (-.075, .155), (-.125, .105)]
        parts.append(prism((x, .51, -.534), eye, .018, "#88560B", "Eyes"))
        parts.append(decal((x, .55, -.555), (.175, .16), "#704609"))
        parts.append(decal((x-.045, .59, -.568), (.075, .079), "#FFF9E4"))
        parts.append(decal((x, .305, -.525), (.13, .085), "#F1B50B"))
    # A short polygonal U reads as a smile even at the in-game size.
    angles = np.linspace(np.pi, 2*np.pi, 9)
    for a, b in zip(angles[:-1], angles[1:]):
        p = np.array([.075*np.cos(a), .405+.075*np.sin(a)])
        q = np.array([.075*np.cos(b), .405+.075*np.sin(b)])
        d = q-p
        parts.append(decal((*( (p+q)/2 ), -.525),
                           (np.linalg.norm(d)+.008, .027), "#303A0A",
                           rotation=(0, 0, np.arctan2(d[1], d[0]))))
    return parts


if __name__ == "__main__":
    folder = Path(__file__).resolve().parent
    # build() lays the model out with +X as the viewer's right, but the face
    # looks down -Z, where +X is the viewer's left: mirror to match the sheet
    # (trimesh flips the winding of a mirrored mesh itself).
    mirror = np.diag([-1.0, 1.0, 1.0, 1.0])
    counts = export([part.apply_transform(mirror) for part in build()], folder / "mosslet.glb")
    render_preview(folder / "mosslet.glb", folder / "mosslet_preview.png")
    for name, count in counts.items():
        print(f"{name}: {count} triangles")
    print(f"Total: {sum(counts.values())} triangles")
