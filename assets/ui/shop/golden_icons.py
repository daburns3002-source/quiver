"""Cut the golden weapons' icons out of Codex's single-view art.

    python -I assets/ui/shop/golden_icons.py

Reads assets/concepts/blocky/weapons/skins/golden/<name>.png (each one
weapon, flat side-on and upright on light grey: the picture its Tripo model
was made from, rule 14) and writes assets/ui/shop/icons/<Weapon>.png, a
256 px square leaned like every other shop icon. The cutting is
bogheart_icons.py's.
"""

import pathlib
import sys

from PIL import Image

HERE = pathlib.Path(__file__).resolve().parent
sys.path.insert(0, str(HERE))
import bogheart_icons as cutter  # noqa: E402

ART = HERE.parents[1] / "concepts/blocky/weapons/skins/golden"
WEAPONS = {
    "GoldenBow": "golden_bow",
    "GoldenStaff": "golden_staff",
    "GoldenBlade": "golden_blade",
}


def main() -> None:
    for name, stem in WEAPONS.items():
        source = ART / f"{stem}.png"
        if not source.exists():
            print("missing", source.name)
            continue
        cut = cutter.key_out(Image.open(source))
        cut = cut.crop(cut.getchannel("A").getbbox())
        cut = cut.rotate(-cutter.TILT, resample=Image.BICUBIC, expand=True)
        cutter.fit(cut).save(HERE / "icons" / f"{name}.png")
        print("weapon", name)


if __name__ == "__main__":
    main()
