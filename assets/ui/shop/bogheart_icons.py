"""Cut the Bogheart Caverns weapon and pet icons out of Codex's single-view art.

    python -I assets/ui/shop/bogheart_icons.py [root]

`root` is the checkout holding the art (default: this one). Reads
assets/concepts/blocky/weapons/skins/bogheart/<name>.png (each one weapon,
flat side-on and upright on light grey: the picture its Tripo model was
made from, memory `weapon-pictures-are-2d`) and
assets/concepts/blocky/pets/bogheart/<nn>_<name>.png, keys out the grey
background from the border inwards, trims, and writes 256 px squares:

- assets/ui/shop/icons/<Weapon>.png, leaned TILT degrees right like every
  other shop icon (three_quarter.py);
- assets/ui/pets/icons/<Pet>.png, upright;
- assets/ui/reveal/<egg|chest>_<Area>.png, each area's egg and chest
  from assets/concepts/blocky/eggs_chests/ (`GearAssets.areaPictures`).

The files named are the approved picks: the Mythics' option A (the plain
file, which equals `_a`), the daggers' B, the cricket with its fixed legs
the Olm with its eyes and the Glowcap Wilf with its front-right sock.
"""

import pathlib
import sys

import numpy as np
from PIL import Image
from scipy import ndimage

HERE = pathlib.Path(__file__).resolve().parent
REPO = HERE.parents[2]
ROOT = pathlib.Path(sys.argv[1]) if len(sys.argv) > 1 else REPO
WEAPON_ART = ROOT / "assets/concepts/blocky/weapons/skins/bogheart"
PET_ART = ROOT / "assets/concepts/blocky/pets/bogheart"
SHELL_ART = ROOT / "assets/concepts/blocky/eggs_chests"
AREAS = {
    "MossyGlade": "mossy_glade",
    "Thornwood": "thornwood",
    "DrownedVillage": "drowned_village",
    "BogheartCaverns": "bogheart_caverns",
    "WindsweptCliffs": "windswept_cliffs",
    "FrostpeakPass": "frostpeak_pass",
}
SIZE = 256
PAD = 0.06
TILT = 21.3

WEAPONS = {
    "PeatwoodBow": "peatwood_bow",
    "SporestringBow": "sporestring_bow",
    "GlowcapLongbow": "glowcap_longbow",
    "GulpstringBow": "gulpstring_bow",
    "LumenveilBow": "lumenveil_bow",
    "LichenStaff": "lichen_staff",
    "PuffballStaff": "puffball_staff",
    "VentstoneStaff": "ventstone_staff",
    "GrandmothersStaff": "grandmothers_staff",
    "MyceliadStaff": "myceliad_staff",
    "BogironBlade": "bogiron_blade",
    "ShellbackCleaver": "shellback_cleaver",
    "CaplightBlade": "caplight_blade",
    "GulpfangBlade": "gulpfang_blade",
    "DeepglowBlade": "deepglow_blade",
}

PETS = {
    "CaveCricket": "01_cave_cricket_legs",
    "LichenGecko": "02_lichen_gecko",
    "BogBeaver": "03_bog_beaver",
    "Lanternfin": "04_lanternfin",
    "Olm": "05_olm_eyes",
    "GlowcapWilf": "06_glowcap_wilf_sock",
    "Gulpling": "07_gulpling",
    "PrismLeviathan": "08_prism_leviathan",
}


def key_out(img: Image.Image) -> Image.Image:
    rgb = np.asarray(img.convert("RGB")).astype(np.float32)
    h, w, _ = rgb.shape
    border = np.concatenate([rgb[0], rgb[-1], rgb[:, 0], rgb[:, -1]])
    bg_colour = np.median(border, axis=0)
    dist = np.linalg.norm(rgb - bg_colour, axis=-1)
    near = dist < 22
    labels, _ = ndimage.label(near)
    edge_labels = np.unique(np.concatenate([labels[0], labels[-1], labels[:, 0], labels[:, -1]]))
    bg = np.isin(labels, edge_labels[edge_labels > 0])
    # background shut inside the art (a bow's belly, between limb and
    # string): a large, flat patch of exactly the background's grey
    flat = dist < 12
    inner, count = ndimage.label(flat & ~bg)
    if count:
        sizes = ndimage.sum(np.ones_like(dist), inner, range(1, count + 1))
        big = np.flatnonzero(sizes > h * w * 0.002) + 1
        bg |= ndimage.binary_dilation(np.isin(inner, big), iterations=2) & near
    # soften one pixel of edge so the cut does not look jagged
    ring = ndimage.binary_dilation(bg, iterations=1) & ~bg
    alpha = np.where(bg, 0.0, 255.0)
    alpha[ring] = 200.0
    rgba = np.dstack([rgb, alpha]).astype(np.uint8)
    return Image.fromarray(rgba, "RGBA")


def fit(img: Image.Image) -> Image.Image:
    box = img.getchannel("A").point(lambda a: 255 if a > 16 else 0).getbbox()
    img = img.crop(box)
    inner = int(SIZE * (1 - 2 * PAD))
    scale = inner / max(img.size)
    img = img.resize((max(1, round(img.width * scale)), max(1, round(img.height * scale))), Image.LANCZOS)
    out = Image.new("RGBA", (SIZE, SIZE), (0, 0, 0, 0))
    out.paste(img, ((SIZE - img.width) // 2, (SIZE - img.height) // 2), img)
    return out


def main() -> None:
    shop = HERE / "icons"
    pets = REPO / "assets/ui/pets/icons"
    pets.mkdir(parents=True, exist_ok=True)
    for name, stem in WEAPONS.items():
        cut = key_out(Image.open(WEAPON_ART / f"{stem}.png"))
        cut = cut.crop(cut.getchannel("A").getbbox())
        cut = cut.rotate(-TILT, resample=Image.BICUBIC, expand=True)
        fit(cut).save(shop / f"{name}.png")
        print("weapon", name)
    for name, stem in PETS.items():
        fit(key_out(Image.open(PET_ART / f"{stem}.png"))).save(pets / f"{name}.png")
        print("pet", name)
    shells = REPO / "assets/ui/reveal"
    shells.mkdir(parents=True, exist_ok=True)
    for area, stem in AREAS.items():
        for kind in ("egg", "chest"):
            fit(key_out(Image.open(SHELL_ART / f"{kind}_{stem}.png"))).save(shells / f"{kind}_{area}.png")
            print(kind, area)


if __name__ == "__main__":
    main()
