"""Repaint the stray colours on the Golden Bow's 8K texture gold.

    python -I assets/models/weapons/blocky/golden/clean_bow_texture.py <in.glb> <out.glb>

Tripo's 8K re-texture of the bow (owner, 2026-11-14: "8k texture") painted
colours the picture never showed it (owner: "there are random colors on
it, these need to be fixed"): a teal strip along the inside of the lower
limb, a green smear beside the gem, and brown and pale patches down the
back of the string.

Every face of the bow is gold except the brown grip and the emerald, so:
- a face is the emerald's if it sits where the gem does and its own texels
  are emerald green (the smear beside it is a paler green on gold);
- every texel of any other face outside the grip that is not gold by its
  hue is turned to the limbs' gold at its own brightness;
- the string's texels are all set to that gold, with only a little of
  their own shading left, so no mark survives on it.

The mesh is untouched.
"""

import io
import json
import pathlib
import struct
import sys

import numpy as np
from PIL import Image, ImageDraw

# In the bow's own units (0.979 long, limbs on -x, string on +x).
GRIP = (0.40, 0.57)
GEM_Y = (0.57, 0.70)
GEM_X = (-0.17, -0.02)
GEM_Z = 0.035
STRING_X = 0.085
STRING_Y = (0.17, 0.83)

DTYPES = {5126: np.float32, 5123: np.uint16, 5125: np.uint32, 5121: np.uint8}
WIDTH = {"SCALAR": 1, "VEC2": 2, "VEC3": 3, "VEC4": 4}
LUMA = np.array([0.299, 0.587, 0.114], np.float32)


def read(path):
    raw = pathlib.Path(path).read_bytes()
    size = struct.unpack("<I", raw[12:16])[0]
    doc = json.loads(raw[20 : 20 + size])
    length = struct.unpack("<I", raw[20 + size : 24 + size])[0]
    return doc, raw[28 + size : 28 + size + length]


def accessor(doc, blob, index):
    a = doc["accessors"][index]
    view = doc["bufferViews"][a["bufferView"]]
    start = view.get("byteOffset", 0) + a.get("byteOffset", 0)
    n = WIDTH[a["type"]]
    return np.frombuffer(blob, DTYPES[a["componentType"]], a["count"] * n, start).reshape(-1, n)


def texels(faces, uv, w, h):
    """The texels of `faces`, as a mask."""
    mask = Image.new("L", (w, h), 0)
    draw = ImageDraw.Draw(mask)
    for face in faces:
        draw.polygon([(float(uv[i, 0] % 1) * w, float(uv[i, 1] % 1) * h) for i in face], fill=255, outline=255)
    return np.asarray(mask) > 0


def main():
    doc, blob = read(sys.argv[1])
    prim = doc["meshes"][0]["primitives"][0]
    pos = accessor(doc, blob, prim["attributes"]["POSITION"])
    uv = accessor(doc, blob, prim["attributes"]["TEXCOORD_0"])
    tris = accessor(doc, blob, prim["indices"]).reshape(-1, 3)
    material = doc["materials"][prim["material"]]
    source = doc["textures"][material["pbrMetallicRoughness"]["baseColorTexture"]["index"]]["source"]
    image_view = doc["images"][source]["bufferView"]
    view = doc["bufferViews"][image_view]
    start = view.get("byteOffset", 0)
    image = Image.open(io.BytesIO(blob[start : start + view["byteLength"]])).convert("RGB")
    w, h = image.size
    pixels = np.asarray(image).astype(np.float32)

    corners = pos[tris]
    centre = corners.mean(1)
    top = pos[:, 1].max()
    y = centre[:, 1] / top
    # each face's own colour: its texture at the middle of its UVs
    middle = uv[tris].mean(1) % 1
    own = pixels[np.clip((middle[:, 1] * h).astype(int), 0, h - 1), np.clip((middle[:, 0] * w).astype(int), 0, w - 1)]

    string = (corners[:, :, 0].min(1) > STRING_X) & (y > STRING_Y[0]) & (y < STRING_Y[1])
    grip = (y > GRIP[0]) & (y < GRIP[1]) & ~string
    emerald = (own[:, 1] > 1.6 * own[:, 0]) & (own[:, 1] > 1.6 * own[:, 2]) & (own[:, 1] > 110)
    # on the two flat sides, not the limb's inner face between them
    flat = np.abs(centre[:, 2]) > GEM_Z
    gem = emerald & flat & (y > GEM_Y[0]) & (y < GEM_Y[1]) & (centre[:, 0] > GEM_X[0]) & (centre[:, 0] < GEM_X[1])
    golden = ~grip & ~gem & ~string
    print(f"faces: {int(gem.sum())} gem, {int(grip.sum())} grip, {int(string.sum())} string, {int(golden.sum())} gold")

    kept = texels(tris[grip | gem], uv, w, h)
    on_string = texels(tris[string], uv, w, h)
    on_gold = texels(tris[golden], uv, w, h) & ~kept & ~on_string
    on_string &= ~kept & ~texels(tris[golden], uv, w, h)

    r, g, b = pixels[..., 0], pixels[..., 1], pixels[..., 2]
    # gold by its hue (the limbs' is about 47 degrees; the grip's brown 21,
    # the smear's green 120, the strip's teal 180), light or shaded
    hue = 60.0 * (g - b) / np.maximum(r - b, 1.0)
    is_gold = (r >= g) & (g > b) & (hue > 31) & (hue < 66) & (r > 80)
    reference = np.median(pixels[on_gold & is_gold & (r > 200)], axis=0)
    level = float(reference @ LUMA)

    stray = on_gold & ~is_gold
    shade = np.clip((pixels[stray] @ LUMA) / level, 0.9, 1.05)
    pixels[stray] = np.clip(reference[None, :] * shade[:, None], 0, 255)
    shade = np.clip((pixels[on_string] @ LUMA) / level, 0.94, 1.02)
    pixels[on_string] = np.clip(reference[None, :] * shade[:, None], 0, 255)
    print(f"gold {reference.astype(int).tolist()}: {int(stray.sum())} stray texels, {int(on_string.sum())} on the string")

    packed = io.BytesIO()
    Image.fromarray(pixels.astype(np.uint8), "RGB").save(packed, "JPEG", quality=92)
    doc["images"][source]["mimeType"] = "image/jpeg"

    # every view again, in order, with the new picture in the old one's place
    out = bytearray()
    for index, each in enumerate(doc["bufferViews"]):
        data = (
            packed.getvalue()
            if index == image_view
            else blob[each.get("byteOffset", 0) : each.get("byteOffset", 0) + each["byteLength"]]
        )
        while len(out) % 4:
            out.append(0)
        each["byteOffset"] = len(out)
        each["byteLength"] = len(data)
        out.extend(data)
    while len(out) % 4:
        out.append(0)
    doc["buffers"][0]["byteLength"] = len(out)
    text = json.dumps(doc, separators=(",", ":")).encode()
    text += b" " * (-len(text) % 4)
    with open(sys.argv[2], "wb") as file:
        file.write(struct.pack("<4sII", b"glTF", 2, 12 + 8 + len(text) + 8 + len(out)))
        file.write(struct.pack("<I4s", len(text), b"JSON") + text)
        file.write(struct.pack("<I4s", len(out), b"BIN\x00") + bytes(out))


if __name__ == "__main__":
    main()
