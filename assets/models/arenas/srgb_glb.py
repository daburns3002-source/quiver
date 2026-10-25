"""Rewrite a Claude Design GLB's vertex colours from linear to sRGB, so Roblox
draws them as designed.

    uv run --with numpy --with pygltflib python -I srgb_glb.py <in.glb> <out.glb>

Claude Design's viewers (three.js) store vertex colours linear, as glTF says
they are: the outer wood's lime #98D516 is written as #50AA02. Roblox reads
vertex colours as sRGB, so imported as they come every colour draws far
darker than the sheet (CLAUDE.md rule 13). `kit_bundle.py --srgb` does this
for kits, whose colours start as material colours; this is the same step for
a model already coloured per vertex, such as an outer forest. Nothing else in
the file changes: nodes, names, origins, meshes and materials stay as they
are (a material's own colour, the berries' magenta, is the game's to tint).
"""
import pathlib
import sys

import numpy as np
import pygltflib

SRC, OUT = pathlib.Path(sys.argv[1]), pathlib.Path(sys.argv[2])

COMPONENTS = {"VEC3": 3, "VEC4": 4}
DTYPES = {5126: np.float32, 5121: np.uint8, 5123: np.uint16}


def to_srgb(lin: np.ndarray) -> np.ndarray:
    return np.where(lin <= 0.0031308, lin * 12.92, 1.055 * np.power(lin, 1 / 2.4) - 0.055)


def main() -> None:
    gltf = pygltflib.GLTF2().load(str(SRC))
    blob = bytearray(gltf.binary_blob())
    done = set()
    for mesh in gltf.meshes:
        for prim in mesh.primitives:
            index = prim.attributes.COLOR_0
            if index is None or index in done:
                continue
            done.add(index)
            acc = gltf.accessors[index]
            view = gltf.bufferViews[acc.bufferView]
            n = COMPONENTS[acc.type]
            dtype = np.dtype(DTYPES[acc.componentType])
            stride = view.byteStride or dtype.itemsize * n
            start = (view.byteOffset or 0) + (acc.byteOffset or 0)
            scale = 1.0 if dtype == np.float32 else float(np.iinfo(dtype).max)
            for i in range(acc.count):
                at = start + i * stride
                rgb = np.frombuffer(blob, dtype, 3, at).astype(np.float64) / scale
                out = (to_srgb(np.clip(rgb, 0, 1)) * scale).astype(dtype)
                blob[at : at + 3 * dtype.itemsize] = out.tobytes()
    gltf.set_binary_blob(bytes(blob))
    gltf.save_binary(str(OUT))
    print(f"{len(done)} colour sets to sRGB -> {OUT}")


if __name__ == "__main__":
    main()
