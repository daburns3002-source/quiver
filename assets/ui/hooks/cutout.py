"""Cut the retention hooks' lobby icons out of Codex's sheet.

    python -I assets/ui/hooks/cutout.py

Reads assets/concepts/blocky/ui/hooks/icons_raw.png (3 x 2 on flat magenta,
only the first row's first two cells drawn: the playtime gift, invite a
friend) and writes icons/<Key>.png at 512 px. The keying is the Robux
store's (assets/ui/robux/cutout.py), imported from there.
"""

import importlib.util
import pathlib

from PIL import Image

HERE = pathlib.Path(__file__).resolve().parent
ROOT = HERE.parents[2]
RAW = ROOT / "assets/concepts/blocky/ui/hooks/icons_raw.png"
KEYS = ["Gift", "Invite"]

spec = importlib.util.spec_from_file_location("robux_cutout", ROOT / "assets/ui/robux/cutout.py")
robux = importlib.util.module_from_spec(spec)
spec.loader.exec_module(robux)


def main() -> None:
    (HERE / "icons").mkdir(exist_ok=True)
    whole = Image.open(RAW)
    cell_w, cell_h = whole.width // 3, whole.height // 2
    for i, key in enumerate(KEYS):
        x, y = (i % 3) * cell_w, (i // 3) * cell_h
        piece = robux.drop_strays(robux.key_out(whole.crop((x, y, x + cell_w, y + cell_h)), "magenta"))
        robux.fit(piece).save(HERE / "icons" / f"{key}.png", optimize=True)
        print("wrote", f"icons/{key}.png")


if __name__ == "__main__":
    main()
