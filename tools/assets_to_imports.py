"""Fold tools/studio/dump_assets.luau's lines into
assets/models/model_imports.json, each uploaded model under "OC#<name>",
in the shape dump_models.luau writes, so tools/imports_to_luau.py matches
it to its GLB as it does a File > Import 3D.

    python -I tools/assets_to_imports.py <dump.txt>

An Open Cloud import names each part after its node and drops colours
(imports_to_luau.py takes them from the GLB anyway).
"""
import json
import pathlib
import sys

ROOT = pathlib.Path(__file__).resolve().parents[1]
DUMP = ROOT / "assets" / "models" / "model_imports.json"


def main():
    dump = json.loads(DUMP.read_text(encoding="utf-8"))
    found = {}
    for line in pathlib.Path(sys.argv[1]).read_text(encoding="utf-8").splitlines():
        if not line.strip():
            continue
        key, name, mesh, texture, transparency, size, cframe = line.split("|")
        found.setdefault(f"OC#{key}", []).append(
            {
                "name": name,
                "meshId": mesh,
                "textureId": texture,
                "color": [0.63922, 0.63529, 0.64706],
                "material": "Plastic",
                "transparency": float(transparency),
                "size": [float(v) for v in size.split(",")],
                "cframe": [float(v) for v in cframe.split(",")],
            }
        )
    for key, parts in found.items():
        dump[key] = {"parts": parts}
        print(f"{key}: {len(parts)} parts")
    DUMP.write_text(json.dumps(dump, indent=1) + "\n", encoding="utf-8", newline="\n")


if __name__ == "__main__":
    main()
