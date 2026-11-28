"""Cut the Windswept Cliffs' twenty weapon pictures out of Codex's single
views (`assets/concepts/blocky/weapons/skins/windswept/<name>.png`, each the
picture its Tripo model was made from, memory `weapon-pictures-are-2d`), the
way `bogheart_icons.py` cuts Bogheart's: grey keyed out from the border in,
trimmed, leaned TILT degrees right like every shop icon, 256 px. The
Assassin's five are two copies of the one dagger crossed in a V, as every
other area's daggers are (`new_dagger_icons.py`: the model is one dagger,
held in each hand).

    python -I assets/ui/shop/windswept_icons.py

Writes assets/ui/shop/icons/<Weapon>.png. Upload each and put its id in
`Config/ShopAssets`.
"""
import importlib.util
import pathlib

from PIL import Image

HERE = pathlib.Path(__file__).resolve().parent
REPO = HERE.parents[2]
spec = importlib.util.spec_from_file_location("bogheart_icons", HERE / "bogheart_icons.py")
cutter = importlib.util.module_from_spec(spec)
spec.loader.exec_module(cutter)
spec = importlib.util.spec_from_file_location("new_dagger_icons", HERE / "new_dagger_icons.py")
daggers = importlib.util.module_from_spec(spec)
spec.loader.exec_module(daggers)

ART = REPO / "assets/concepts/blocky/weapons/skins/windswept"
WEAPONS = {
    "SlatewoodBow": "slatewood_bow", "HarpyBow": "harpy_bow", "GalestringLongbow": "galestring_longbow",
    "RocsWingBow": "rocs_wing_bow", "SkyrenderBow": "skyrender_bow",
    "CloudspunStaff": "cloudspun_staff", "GustcallerStaff": "gustcaller_staff", "PrayerflagStaff": "prayerflag_staff",
    "TempestStaff": "tempest_staff", "EyeOfTheStorm": "eye_of_the_storm",
    "LedgestoneBlade": "ledgestone_blade", "RamhornCleaver": "ramhorn_cleaver", "WindcutterBlade": "windcutter_blade",
    "StormtalonBlade": "stormtalon_blade", "ThunderheadBlade": "thunderhead_blade",
    "FlintTalon": "flint_talon", "HarpyClaw": "harpy_claw", "StormQuill": "storm_quill",
    "ThunderbeakDagger": "thunderbeak_dagger", "ZephyrFang": "zephyr_fang",
}
DAGGERS = {"FlintTalon", "HarpyClaw", "StormQuill", "ThunderbeakDagger", "ZephyrFang"}


def main() -> None:
    out = HERE / "icons"
    for name, stem in WEAPONS.items():
        if name in DAGGERS:
            cutter.fit(daggers.crossed(daggers.single(ART / f"{stem}.png"))).save(out / f"{name}.png")
            print("daggers", name)
            continue
        cut = cutter.key_out(Image.open(ART / f"{stem}.png"))
        cut = cut.crop(cut.getchannel("A").getbbox())
        cut = cut.rotate(-cutter.TILT, resample=Image.BICUBIC, expand=True)
        cutter.fit(cut).save(out / f"{name}.png")
        print("weapon", name)


if __name__ == "__main__":
    main()
