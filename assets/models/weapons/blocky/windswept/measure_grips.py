"""Where the hand closes on each Windswept Cliffs weapon, and which way each
bow's riser is: the themed sets' rule (`themed_sets/measure_grips.py`) with
each weapon's kind named here, since several keys do not end in it
(Longbow, Cleaver, Talon, Claw, Quill, Fang, Eye of the Storm).

    python assets/models/weapons/blocky/windswept/measure_grips.py <glb dir>

Reads <dir>/<Key>.glb and prints `skins_to_luau.py`'s GRIPS rows and each
bow's YAW. Needs numpy and trimesh (not run with -I). The GLBs are not in git.
"""
import importlib.util
import pathlib
import sys

HERE = pathlib.Path(__file__).resolve().parent
spec = importlib.util.spec_from_file_location("themed", HERE.parent / "themed_sets" / "measure_grips.py")
themed = importlib.util.module_from_spec(spec)
spec.loader.exec_module(themed)

KINDS = {
    "SlatewoodBow": "bow", "HarpyBow": "bow", "GalestringLongbow": "bow", "RocsWingBow": "bow", "SkyrenderBow": "bow",
    "CloudspunStaff": "staff", "GustcallerStaff": "staff", "PrayerflagStaff": "staff", "TempestStaff": "staff",
    "EyeOfTheStorm": "staff",
    "LedgestoneBlade": "handle", "RamhornCleaver": "handle", "WindcutterBlade": "handle", "StormtalonBlade": "handle",
    "ThunderheadBlade": "handle",
    "FlintTalon": "handle", "HarpyClaw": "handle", "StormQuill": "handle", "ThunderbeakDagger": "handle", "ZephyrFang": "handle",
}


def main():
    source = pathlib.Path(sys.argv[1])
    grips, yaws = [], []
    for key, kind in KINDS.items():
        grip, note, yaw = getattr(themed, kind)(source / f"{key}.glb")
        print(f"# {key}: {note}")
        grips.append(f'    "{key}": {grip},')
        if yaw is not None:
            yaws.append(f'    "{key}": {yaw},')
    print("\n".join(grips))
    print("\n".join(yaws))


if __name__ == "__main__":
    main()
