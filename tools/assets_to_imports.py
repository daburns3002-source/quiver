"""Fold tools/studio/dump_assets.luau's lines into
assets/models/model_imports.json, each uploaded model under "OC#<name>",
in the shape dump_models.luau writes, so tools/imports_to_luau.py matches
it to its GLB as it does a File > Import 3D.

    python -I tools/assets_to_imports.py <dump.txt>...

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
    lines = []
    for arg in sys.argv[1:]:
        lines += pathlib.Path(arg).read_text(encoding="utf-8").splitlines()
    for line in lines:
        if not line.strip():
            continue
        fields = line.split("|")
        key, name, mesh = fields[:3]
        if not mesh.startswith("rbxassetid://"):
            mesh = "rbxassetid://" + mesh
        texture, transparency = "", 0.0
        if len(fields) == 7 and fields[6].count(",") == 11:
            # key|name|mesh|texture|transparency|size|12 cframe numbers
            texture, transparency = fields[3], float(fields[4])
            size, cframe = fields[5], [float(v) for v in fields[6].split(",")]
        else:
            # key|name|mesh|size|position[|9 rotation numbers][|T<transparency>:<texture>]
            size = fields[3]
            cframe = [float(v) for v in fields[4].split(",")] + [1, 0, 0, 0, 1, 0, 0, 0, 1]
            for extra in fields[5:]:
                if extra.startswith("T"):
                    transparency, texture = extra[1:].split(":", 1)
                    transparency = float(transparency)
                else:
                    cframe[3:] = [float(v) for v in extra.split(",")]
        found.setdefault(f"OC#{key}", []).append(
            {
                "name": name,
                "meshId": mesh,
                "textureId": texture,
                "color": [0.63922, 0.63529, 0.64706],
                "material": "Plastic",
                "transparency": transparency,
                "size": [float(v) for v in size.split(",")],
                "cframe": cframe,
            }
        )
    for key, parts in found.items():
        dump[key] = {"parts": parts}
        print(f"{key}: {len(parts)} parts")
    DUMP.write_text(json.dumps(dump, indent=1) + "\n", encoding="utf-8", newline="\n")


if __name__ == "__main__":
    main()
