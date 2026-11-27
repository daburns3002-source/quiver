"""The Assassin's 22 dagger imports, as Studio holds them (2026-11-17).

    python -I assets/models/weapons/blocky/daggers/write_skin_imports.py

The owner imported `Downloads\\assassin_daggers_import` (22 Tripo models,
one dagger each, one MeshPart whose SurfaceAppearance colour map is its
texture); read in Studio's Edit datamodel and moved to
`ServerStorage.Imports`. Writes `skin_imports.json` beside this file in the
shape `skins_to_luau.py` reads: key -> its one part (mesh id, texture,
size, at the model's centre) and the model's size.
"""
import json
import pathlib

# key: mesh id, texture (colour map) id, size x, y, z
ROWS = {
    "SplinterDaggers": (109981035122608, 123337694391679, 0.2712, 0.9795, 0.2567),
    "BrambleShivs": (112072754755619, 135404268248545, 0.3071, 0.9807, 0.2278),
    "FireflyFangs": (125647619952354, 137655955437413, 0.2414, 0.9797, 0.1993),
    "GladeFoxClaws": (117405917457037, 79019869679128, 0.2993, 0.9832, 0.2731),
    "EmberWilfFangs": (92784496611629, 109622119484117, 0.2823, 0.9831, 0.3052),
    "GlimmerhornDaggers": (96513730674225, 135921372690096, 0.5442, 0.9823, 0.2134),
    "HedgePrickers": (121273305347098, 118644019151961, 0.3088, 0.9774, 0.2126),
    "TuskKnives": (136473741539690, 112310444935977, 0.3128, 0.9783, 0.175),
    "BurrfangDaggers": (109246360782906, 96564476510507, 0.3173, 0.9811, 0.2153),
    "SilkfangDaggers": (117721840855836, 99600975463545, 0.3508, 0.9782, 0.2156),
    "LurkerClaws": (76588552074579, 138528147342659, 0.4077, 0.9833, 0.1795),
    "DriftwoodDirks": (108529956253947, 120432794917352, 0.3639, 0.981, 0.1681),
    "BarnacleKnives": (140173091377064, 120141022136704, 0.3198, 0.9789, 0.22),
    "EeltoothDaggers": (88277814709938, 134472793818377, 0.36, 0.9796, 0.1511),
    "TollbellDaggers": (90065675724031, 80272304011974, 0.3316, 0.9791, 0.2352),
    "RiptideFangs": (72842948577032, 119440703225958, 0.3829, 0.9821, 0.1961),
    "MossShivs": (137107027765402, 104305608141564, 0.2998, 0.9803, 0.2154),
    "SporeFangs": (112465728947288, 96548517342191, 0.3186, 0.9805, 0.2274),
    "GlowcapKris": (74062370504959, 72682821735921, 0.303, 0.9793, 0.1823),
    "ToadtongueDaggers": (86671544277404, 85495479463592, 0.335, 0.9799, 0.2064),
    "PrismStingers": (132291881011733, 70588723273817, 0.3698, 0.9864, 0.2304),
    "GoldenDaggers": (138098743412792, 126966074841057, 0.4029, 0.9796, 0.1951),
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
    print(len(out), "daggers")


if __name__ == "__main__":
    main()
