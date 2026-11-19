"""Shop and gear pictures for the themed weapon sets (docs/WEAPONS-THEMED.md).

    python -I assets/ui/shop/set_icons.py

Reads assets/concepts/blocky/weapons/skins/sets/<set>/<name>.png (one
weapon each, flat and upright on light grey: the picture its Tripo model
is made from, rule 14) and writes:

- assets/ui/shop/icons/<Weapon>.png, a 256 px square leaned like every
  other shop icon (the cutting is bogheart_icons.py's);
- assets/ui/gear/outlined/<Weapon>.png, the same with the gear icons' bold
  dark outline.

A dagger's picture is ONE dagger (the model is one, held in each hand), so
the pair is made here, two copies crossed in a V (new_dagger_icons.py).
"""

import pathlib
import sys

from PIL import Image

HERE = pathlib.Path(__file__).resolve().parent
sys.path.insert(0, str(HERE))
import bogheart_icons as cutter  # noqa: E402
from glade_redesign_icons import outlined  # noqa: E402
from new_dagger_icons import crossed, single  # noqa: E402

REPO = HERE.parents[2]
SETS = REPO / "assets/concepts/blocky/weapons/skins/sets"
# set folder -> { Weapon key: (picture, is it a dagger) }
WEAPONS = {
    "neon_circuit": {
        "LivewireBow": ("livewire_bow", False),
        "MainframeStaff": ("mainframe_staff", False),
        "OverclockBlade": ("overclock_blade", False),
        "GlitchDaggers": ("glitch_daggers", True),
    },
}


def main() -> None:
    for folder, weapons in WEAPONS.items():
        for key, (stem, dagger) in weapons.items():
            source = SETS / folder / f"{stem}.png"
            if not source.exists():
                print("missing", source.name)
                continue
            if dagger:
                icon = cutter.fit(crossed(single(source)))
            else:
                cut = cutter.key_out(Image.open(source))
                cut = cut.crop(cut.getchannel("A").getbbox())
                cut = cut.rotate(-cutter.TILT, resample=Image.BICUBIC, expand=True)
                icon = cutter.fit(cut)
            icon.save(HERE / "icons" / f"{key}.png")
            outlined(icon).save(REPO / "assets/ui/gear/outlined" / f"{key}.png")
            print(key)


if __name__ == "__main__":
    main()
