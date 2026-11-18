"""Icons for Thornwood's fifteen bows, staffs and blades: the shop picture
and the gear screen's outlined icon.

    python -I assets/ui/shop/thornwood_icons.py

Reads the picture each Tripo model was made from
(assets/concepts/blocky/weapons/skins/thornwood/<name>_single.png: one
weapon, flat side-on and upright on light grey; the jobs are in
assets/models/weapons/blocky/thornwood_tripo_2026_11_18.json), keys out the
grey as bogheart_icons.py does, leans it TILT degrees right like every other
shop icon, and writes:

- assets/ui/shop/icons/<Weapon>.png
- assets/ui/gear/outlined/<Weapon>.png, the same with the gear icons' bold
  dark outline.
"""

import json
import pathlib
import sys

from PIL import Image

sys.path.insert(0, str(pathlib.Path(__file__).resolve().parent))
from bogheart_icons import TILT, fit, key_out
from glade_redesign_icons import outlined

HERE = pathlib.Path(__file__).resolve().parent
REPO = HERE.parents[2]
ART = REPO / "assets/concepts/blocky/weapons/skins/thornwood"
JOBS = REPO / "assets/models/weapons/blocky/thornwood_tripo_2026_11_18.json"


def main() -> None:
    shop = HERE / "icons"
    gear = REPO / "assets/ui/gear/outlined"
    for stem, job in json.loads(JOBS.read_text(encoding="utf-8"))["jobs"].items():
        cut = key_out(Image.open(ART / f"{stem}_single.png").convert("RGB"))
        cut = cut.crop(cut.getbbox()).rotate(-TILT, resample=Image.BICUBIC, expand=True)
        icon = fit(cut)
        icon.save(shop / f"{job['key']}.png")
        outlined(icon).save(gear / f"{job['key']}.png")
        print(job["key"])


if __name__ == "__main__":
    main()
