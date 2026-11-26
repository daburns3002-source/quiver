"""Thornwood's fifteen bows, staffs and blades, as Studio holds them (2026-11-26).

    python -I assets/models/weapons/blocky/thornwood/write_skin_imports.py

The Tripo exports in `Downloads\\thornwood_weapons_import` (PR #625: one
textured mesh each, 4,000 triangles, 8K texture), imported into Studio
and read in its Edit datamodel: each one MeshPart whose SurfaceAppearance
colour map is its texture. Writes `skin_imports.json` beside this file in
the shape `skins_to_luau.py` reads: key -> its one part (mesh id, texture,
size, at the model's centre) and the model's size.
"""
import json
import pathlib

# key: mesh id, texture (colour map) id, size x, y, z (studs, as Studio sizes the mesh)
ROWS = {
}


def main():
    out = {}
    for key, (mesh, texture, x, y, z) in ROWS.items():
        size = [x, y, z]
        out[key] = {
            "parts": [
                {
                    "at": [0, 0, 0],
                    "meshId": f"rbxassetid://{mesh}",
                    "name": "Blade",
                    "size": size,
                    "textureId": f"rbxassetid://{texture}",
                }
            ],
            "size": size,
        }
    path = pathlib.Path(__file__).parent / "skin_imports.json"
    path.write_text(json.dumps(out, indent=1) + "\n", encoding="utf-8")
    print(len(out), "weapons")


if __name__ == "__main__":
    main()
