"""Export Mosslet animation data and a GLB-rendered GIF. Run after mosslet.py.

Only numpy, trimesh, matplotlib and Pillow are needed. No Blender/runtime rig.
The GLB keeps its material-role mesh names; face ranges in mesh extras identify
the separately movable leaves and mushroom, including the mushroom's spots.
"""
from pathlib import Path
import json
import sys

import numpy as np

sys.dont_write_bytecode = True
sys.path.insert(0, str(Path(__file__).resolve().parents[2] / "blocky"))
from blocky import load_meshes, render_frame


# Degrees, seconds and model units; XYZ vectors, Y up, front/walk direction -Z.
# Leaf angle = [sideways sway about Z, trailing tilt about X]. Both leaves
# rotate at their shared base. Positive body_pitch leans toward -Z.
# Body offset is world-space; mushroom offset is local, before body scaling.
CLIPS = {
    "IDLE": {
        "duration": 1.6, "loop": True, "body_pitch": 0,
        "keyframes": [
            {"time": 0, "body_offset": [0, 0, 0], "body_scale": [1, 1, 1], "leaf_angle": [8, 0], "mushroom_offset": [0, 0, 0]},
            {"time": .4, "body_offset": [0, 0, 0], "body_scale": [.99, 1.02, .99], "leaf_angle": [0, 0], "mushroom_offset": [0, .02, 0]},
            {"time": .8, "body_offset": [0, 0, 0], "body_scale": [.98, 1.04, .98], "leaf_angle": [-8, 0], "mushroom_offset": [0, 0, 0]},
            {"time": 1.2, "body_offset": [0, 0, 0], "body_scale": [.99, 1.02, .99], "leaf_angle": [0, 0], "mushroom_offset": [0, -.02, 0]},
            {"time": 1.6, "body_offset": [0, 0, 0], "body_scale": [1, 1, 1], "leaf_angle": [8, 0], "mushroom_offset": [0, 0, 0]},
        ],
    },
    "HOP": {
        "duration": .6, "loop": False, "body_pitch": 0,
        "keyframes": [
            {"time": 0, "body_offset": [0, 0, 0], "body_scale": [1, 1, 1], "leaf_angle": [0, 0], "mushroom_offset": [0, 0, 0]},
            {"time": .12, "body_offset": [0, 0, 0], "body_scale": [1.12, .80, 1.12], "leaf_angle": [0, 0], "mushroom_offset": [0, 0, 0]},
            {"time": .30, "body_offset": [0, .6, 0], "body_scale": [.92, 1.15, .92], "leaf_angle": [0, -15], "mushroom_offset": [0, 0, 0]},
            {"time": .45, "body_offset": [0, 0, 0], "body_scale": [1, 1, 1], "leaf_angle": [0, 10], "mushroom_offset": [0, 0, 0]},
            {"time": .52, "body_offset": [0, 0, 0], "body_scale": [1.10, .82, 1.10], "leaf_angle": [0, 10], "mushroom_offset": [0, 0, 0]},
            {"time": .60, "body_offset": [0, 0, 0], "body_scale": [1, 1, 1], "leaf_angle": [0, 0], "mushroom_offset": [0, 0, 0]},
        ],
    },
    "FOLLOW": {
        "duration": .8, "loop": True, "body_pitch": 8,
        "keyframes": [
            {"time": 0, "body_offset": [0, 0, 0], "body_scale": [1.06, .88, 1.06], "leaf_angle": [0, 10], "mushroom_offset": [0, 0, 0]},
            {"time": .1, "body_offset": [0, .15, -.035], "body_scale": [1, 1, 1], "leaf_angle": [0, -8], "mushroom_offset": [0, 0, 0]},
            {"time": .2, "body_offset": [0, .3, -.07], "body_scale": [1, 1, 1], "leaf_angle": [0, -8], "mushroom_offset": [0, 0, 0]},
            {"time": .3, "body_offset": [0, .15, -.035], "body_scale": [1, 1, 1], "leaf_angle": [0, 0], "mushroom_offset": [0, 0, 0]},
            {"time": .4, "body_offset": [0, 0, 0], "body_scale": [1.06, .88, 1.06], "leaf_angle": [0, 10], "mushroom_offset": [0, 0, 0]},
            {"time": .5, "body_offset": [0, .15, -.035], "body_scale": [1, 1, 1], "leaf_angle": [0, -8], "mushroom_offset": [0, 0, 0]},
            {"time": .6, "body_offset": [0, .3, -.07], "body_scale": [1, 1, 1], "leaf_angle": [0, -8], "mushroom_offset": [0, 0, 0]},
            {"time": .7, "body_offset": [0, .15, -.035], "body_scale": [1, 1, 1], "leaf_angle": [0, 0], "mushroom_offset": [0, 0, 0]},
            {"time": .8, "body_offset": [0, 0, 0], "body_scale": [1.06, .88, 1.06], "leaf_angle": [0, 10], "mushroom_offset": [0, 0, 0]},
        ],
    },
}

LEAF_PIVOT = [-.22, 1.14, .07]


def sample(clip, time):
    """Clamp endpoints; cosine ease in-out between adjacent plain keyframes."""
    frames = clip["keyframes"]
    time = float(np.clip(time, 0, clip["duration"]))
    index = min(np.searchsorted([f["time"] for f in frames], time, side="right") - 1,
                len(frames) - 2)
    a, b = frames[max(0, index):max(0, index) + 2]
    u = (time - a["time"]) / (b["time"] - a["time"])
    weight = .5 - .5 * np.cos(np.pi * u)
    return {key: (1 - weight) * np.asarray(a[key]) + weight * np.asarray(b[key])
            for key in ("body_offset", "body_scale", "leaf_angle", "mushroom_offset")}


def rotation_x(degrees):
    c, s = np.cos(np.radians(degrees)), np.sin(np.radians(degrees))
    return np.array([[1, 0, 0], [0, c, -s], [0, s, c]])


def posed_meshes(rest, clip, time):
    pose = sample(clip, time)
    sway, trail = pose["leaf_angle"]
    c, s = np.cos(np.radians(sway)), np.sin(np.radians(sway))
    leaf_rotation = np.array([[c, -s, 0], [s, c, 0], [0, 0, 1]]) @ rotation_x(-trail)
    body_rotation = rotation_x(-clip["body_pitch"])
    result = []
    for original in rest:
        mesh = original.copy()
        vertices = mesh.vertices.copy()
        ranges = mesh.metadata.get("animation_groups")
        if not ranges:
            raise ValueError("GLB has no animation groups; rebuild it with mosslet.py first")
        for start, stop, group in ranges:
            ids = np.unique(mesh.faces[int(start):int(stop)].ravel())
            if group == "leaves":
                vertices[ids] = (vertices[ids] - LEAF_PIVOT) @ leaf_rotation.T + LEAF_PIVOT
            elif group == "mushroom":
                vertices[ids] += pose["mushroom_offset"]
        vertices = (vertices * pose["body_scale"]) @ body_rotation.T
        mesh.vertices = vertices
        result.append(mesh)
    # Pitch about the base centre, then lift just enough to keep its lowest
    # point at the animated ground height (pitch must not bury the front edge).
    bottom = min(mesh.vertices[:, 1].min() for mesh in result)
    offset = pose["body_offset"].copy()
    offset[1] -= bottom
    for mesh in result:
        mesh.apply_translation(offset)
    return result


def main():
    folder = Path(__file__).resolve().parent
    data = {
        "version": 1, "units": "model units, seconds, degrees", "up": "+Y",
        "forward": "-Z", "pivot": [0, 0, 0], "leaf_pivot": LEAF_PIVOT,
        "leaf_angle_axes": ["Z sway", "X trailing tilt"],
        "interpolation": "weight = 0.5 - 0.5*cos(pi*u) between adjacent keys",
        "transform_order": ["leaf rotation about leaf_pivot / mushroom local offset",
                            "body scale about pivot", "body pitch toward -Z",
                            "lift lowest vertex to Y=0", "body offset"],
        "group_source": "GLB mesh extras.animation_groups: [first face, exclusive last face, group]",
        "clips": CLIPS,
    }
    (folder / "mosslet_anim.json").write_text(json.dumps(data, indent=2) + "\n", encoding="utf-8")
    rest = load_meshes(folder / "mosslet.glb")
    frames, durations = [], []
    elapsed = 0.0
    # GIF timing is in centiseconds; distribute rounding to preserve clip lengths.
    for name, repeats in [("IDLE", 2), ("HOP", 1), ("FOLLOW", 2)]:
        clip = CLIPS[name]
        count = round(clip["duration"] * 24)
        for _ in range(repeats):
            for index in range(count):
                time = index * clip["duration"] / count
                frames.append(render_frame(posed_meshes(rest, clip, time), name))
                end = elapsed + clip["duration"] / count
                durations.append(10 * (round(end * 100) - round(elapsed * 100)))
                elapsed = end
    # One shared palette avoids frame-to-frame palette flicker.
    from PIL import Image
    palette = frames[0].quantize(colors=128)
    frames = [frame.quantize(palette=palette, dither=Image.Dither.NONE) for frame in frames]
    frames[0].save(folder / "mosslet_anim.gif", save_all=True,
                   append_images=frames[1:], duration=durations, loop=0, disposal=2,
                   optimize=False)


if __name__ == "__main__":
    main()
