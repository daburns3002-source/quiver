"""Turn the Glitch Daggers' blue edge strips magenta, as their picture has them.

    python -I assets/models/weapons/blocky/neon_circuit/fix_dagger_magenta.py <in.glb> <out.glb>

Tripo modelled the dagger (2026-11-18) with its right-hand light strips a
plain royal blue (hue about 240) where the picture's are magenta: the
Neon Circuit set is cyan and magenta only. Every bright, saturated texel
of a blue hue (225 to 275) is turned to the magenta of the dagger's own
pommel at its own brightness. The cyan strips (hue about 195), the
graphite, the yellow guard and the green chip are left as they are; the
mesh is untouched. The GLB rewrite is clean_bow_texture.py's.
"""

import io
import json
import pathlib
import struct
import sys

import numpy as np
from PIL import Image

BLUE = (225, 275)


def read(path):
    raw = pathlib.Path(path).read_bytes()
    size = struct.unpack("<I", raw[12:16])[0]
    doc = json.loads(raw[20 : 20 + size])
    length = struct.unpack("<I", raw[20 + size : 24 + size])[0]
    return doc, raw[28 + size : 28 + size + length]


def hues(pixels):
    a = pixels / 255.0
    r, g, b = a[..., 0], a[..., 1], a[..., 2]
    top, low = a.max(2), a.min(2)
    sat = np.where(top > 0, (top - low) / np.maximum(top, 1e-6), 0)
    hue = np.degrees(np.arctan2(np.sqrt(3) * (g - b), 2 * r - g - b)) % 360
    return hue, sat, top


def main():
    doc, blob = read(sys.argv[1])
    material = doc["materials"][0]["pbrMetallicRoughness"]
    source = doc["textures"][material["baseColorTexture"]["index"]]["source"]
    image_view = doc["images"][source]["bufferView"]
    view = doc["bufferViews"][image_view]
    start = view.get("byteOffset", 0)
    picture = Image.open(io.BytesIO(blob[start : start + view["byteLength"]])).convert("RGB")
    pixels = np.asarray(picture).astype(np.float32)

    hue, sat, top = hues(pixels)
    bright = (sat > 0.35) & (top > 0.35)
    blue = bright & (hue >= BLUE[0]) & (hue <= BLUE[1])
    pommel = bright & (hue >= 290) & (hue <= 320)
    # the pommel's magenta, brightest half, as the colour to paint
    level = top[pommel]
    magenta = pixels[pommel][level >= np.median(level)].mean(axis=0)
    shade = np.clip(top[blue] / magenta.max() * 255, 0.6, 1.1)
    pixels[blue] = np.clip(magenta[None, :] * shade[:, None], 0, 255)
    print(f"magenta {magenta.astype(int).tolist()}: {int(blue.sum())} blue texels repainted")

    packed = io.BytesIO()
    Image.fromarray(pixels.astype(np.uint8), "RGB").save(packed, "JPEG", quality=92)
    doc["images"][source]["mimeType"] = "image/jpeg"
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
