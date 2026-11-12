"""Writes the class armour sets' imported meshes into
`src/shared/Config/ClassOutfits.luau`, between its `-- <meshes>` marks.

    python -I tools/class_armour/meshes_to_luau.py

Reads `assets/models/armour/armour_ids.json` (each piece's mesh id, read off
the owner's Studio import: the three `<class>_pieces` models, by part name)
and `assets/models/armour/<class>_pieces.json` (each piece's size and its
centre from its body part's centre, and its glowing blocks as boxes, from
`split_set.py`). Studio is only
trusted for the ids. The importer turns a model half round (its -Z comes in
as +Z), so every piece is worn `turned` (the config's `meshed`). Run
`tools/check.sh` after: StyLua lays the long lines out.
"""

import json
import pathlib
import re

ROOT = pathlib.Path(__file__).resolve().parents[2]
ARMOUR = ROOT / "assets/models/armour"
CONFIG = ROOT / "src/shared/Config/ClassOutfits.luau"


def number(value):
    text = f"{value:.4f}".rstrip("0").rstrip(".")
    return "0" if text in ("-0", "") else text


def main():
    ids = json.loads((ARMOUR / "armour_ids.json").read_text())
    lines = []
    for cls in ("Ranger", "Arcanist", "Warden"):
        pieces = json.loads((ARMOUR / f"{cls.lower()}_pieces.json").read_text())["pieces"]
        missing = sorted(set(pieces) ^ set(ids[cls]))
        if missing:
            raise SystemExit(f"{cls}: the import and the pieces file disagree on {missing}")
        lines.append(f"\t{cls} = {{")
        for name, piece in pieces.items():
            size = ", ".join(number(v) for v in piece["size"])
            at = ", ".join(number(v) for v in piece["at"])
            glow = ""
            if piece.get("glow"):
                boxes = []
                for box in piece["glow"]:
                    r, g, b = (int(box["colour"][i : i + 2], 16) for i in (1, 3, 5))
                    box_size = ", ".join(number(v) for v in box["size"])
                    box_at = ", ".join(number(v) for v in box["at"])
                    boxes.append(f"{{ size = Vector3.new({box_size}), at = Vector3.new({box_at}), colour = Color3.fromRGB({r}, {g}, {b}) }}")
                glow = f", glow = {{ {', '.join(boxes)} }}"
            lines.append(f'\t\t{name} = {{ id = "rbxassetid://{ids[cls][name]}", size = Vector3.new({size}), at = Vector3.new({at}){glow} }},')
        lines.append("\t},")
    text = CONFIG.read_text(encoding="utf-8")
    block = "-- <meshes>\n" + "\n".join(lines) + "\n\t-- </meshes>"
    new, count = re.subn(r"-- <meshes>\n.*?-- </meshes>", lambda _: block, text, flags=re.S)
    if count != 1:
        raise SystemExit("ClassOutfits.luau has no `-- <meshes>` ... `-- </meshes>` block")
    CONFIG.write_text(new, encoding="utf-8", newline="\n")
    print(f"wrote {sum(len(v) for v in ids.values())} meshes into {CONFIG.relative_to(ROOT)}")


if __name__ == "__main__":
    main()
