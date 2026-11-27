"""Thornwood's fifteen bows, staffs and blades, as Studio holds them (2026-11-26).

    python -I assets/models/weapons/blocky/thornwood/write_skin_imports.py

The Tripo exports in `Downloads\\thornwood_weapons_import` (PR #625: one
textured mesh each, 4,000 triangles, 8K texture), uploaded as Model assets
through Open Cloud (`POST /assets/v1/assets`, 2026-11-27) and read in
Studio's Edit datamodel with `game:GetObjects`: each one MeshPart whose
SurfaceAppearance colour map is its texture, sized as its GLB, with the
GLB's x and z negated (a half turn about Y, as Studio's 3D Importer gives).
Model assets: BoarTuskBow 122437086414413, PlumBurrBow 128635064579722,
LurkerVineBow 117238138429183, SilkweaverBow 82351342773801, NightbarbBow
83751407291116, HedgeBulbStaff 136563541228522, BurrTotemStaff
91695680736336, LurkerCrestStaff 74485493471970, SilkDiademStaff
109046530361216, BlackspineStaff 139408935369451, BoarbackBlade
135064837890557, PlumguardBlade 124604843213776, BurrcrestBlade
127590295251935, SilkboundBlade 123228729541588, BriarbreakerBlade
74560882076354. Writes `skin_imports.json` beside this file in
the shape `skins_to_luau.py` reads: key -> its one part (mesh id, texture,
size, at the model's centre) and the model's size.
"""
import json
import pathlib

# key: mesh id, texture (colour map) id, size x, y, z (studs, as Studio sizes the mesh)
ROWS = {
    "BoarTuskBow": (77962333727255, 105525519507283, 0.2725, 0.9797, 0.1628),
    "PlumBurrBow": (86014272638021, 85905059654359, 0.3307, 0.9854, 0.2057),
    "LurkerVineBow": (87550629133726, 90777492796483, 0.3577, 0.9853, 0.1564),
    "SilkweaverBow": (95266328110031, 75527921481531, 0.3643, 0.9817, 0.1361),
    "NightbarbBow": (109499000934241, 125891269086548, 0.3362, 0.9812, 0.1305),
    "HedgeBulbStaff": (132588295643126, 73271034118093, 0.3294, 0.9843, 0.1957),
    "BurrTotemStaff": (76543112191577, 134124316973616, 0.3811, 0.9828, 0.2221),
    "LurkerCrestStaff": (119306784069336, 85849626216785, 0.3949, 0.9814, 0.1624),
    "SilkDiademStaff": (138240697340282, 115043591704604, 0.3420, 0.9790, 0.2618),
    "BlackspineStaff": (87471750172727, 83374859278710, 0.2716, 0.9794, 0.1958),
    "BoarbackBlade": (113402614650273, 70491525351180, 0.4262, 0.9810, 0.1671),
    "PlumguardBlade": (106192581553377, 96057068900034, 0.4250, 0.9783, 0.1492),
    "BurrcrestBlade": (125506236365276, 85372036426503, 0.4868, 0.9806, 0.2914),
    "SilkboundBlade": (113794307409410, 81831311267800, 0.4527, 0.9793, 0.2075),
    "BriarbreakerBlade": (86108481832919, 139116065006999, 0.4300, 0.9812, 0.1657),
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
