"""Cuts the class select pictures out of Codex's flat key colours.

    python -I cut.py

Portraits (`portrait_<class>_<gender>.png`, magenta; `portrait_assassin.png`,
green) become `out/<name>.png`, OUT_W x OUT_H: the card's round medallion is
the bottom OUT_W x OUT_W square of the picture (`Config/ClassSelect.portraitTop`
says how much stands above it), and the hero is cut by the circle there, as the
mock-up's medallions cut the chest, while the top of the picture may stand
past the circle (the Ranger's antlers, the Warden's plume). The Assassin's
blacked-out figure gets its violet rim-light drawn round the silhouette Codex
drew, brighter than Codex's thin line (owner: "make the assassin more
noticeable"). `icons.png` (magenta, 3 x 2 cells of 512) becomes six square
icons.
"""

import os

from PIL import Image, ImageChops, ImageDraw, ImageFilter

HERE = os.path.dirname(os.path.abspath(__file__))
OUT = os.path.join(HERE, "out")
OUT_W, OUT_H = 640, 736  # the medallion is the bottom 640 x 640
SCALE = 1.04  # Codex's square on the medallion's square, a touch larger
RIM = (196, 164, 255)
#: Per picture: (scale, shift right, shift down), shares of the medallion. The
#: Warden is drawn a little smaller and to the right so his bigger sword stays
#: inside the medallion (owner: "make the sword a little bigger").
FIT = {
    "warden_male": (0.91, 0.07, 0.015),
    "warden_female": (0.91, 0.07, 0.015),
}


def key(im, colour):
    """RGBA with the flat key colour taken out and its spill off the edges."""
    im = im.convert("RGB")
    px = im.load()
    w, h = im.size
    out = Image.new("RGBA", (w, h))
    o = out.load()
    kr, kg, kb = colour
    for y in range(h):
        for x in range(w):
            r, g, b = px[x, y]
            d = ((r - kr) ** 2 + (g - kg) ** 2 + (b - kb) ** 2) ** 0.5
            a = min(1.0, max(0.0, (d - 70) / 110))
            if a < 1:
                if colour == (255, 0, 255):
                    spill = min(r, b) - g
                    if spill > 0:
                        r, b = r - spill, b - spill
                else:
                    spill = g - max(r, b)
                    if spill > 0:
                        g = g - spill
            o[x, y] = (r, g, b, int(a * 255 + 0.5))
    return out


def medallion_mask():
    """What of the picture shows: the circle, and above its upper middle
    everything (so what stands up past the medallion shows)."""
    mask = Image.new("L", (OUT_W, OUT_H), 0)
    d = ImageDraw.Draw(mask)
    top = OUT_H - OUT_W
    d.ellipse((0, top, OUT_W - 1, OUT_H - 1), fill=255)
    cy = top + OUT_W / 2
    d.rectangle((0, 0, OUT_W, int(cy - OUT_W * 0.25)), fill=255)
    return mask


def place(cut, fit=(1.0, 0.0, 0.0)):
    """The cut-out on the medallion's frame: bottoms together, centred."""
    scale, right, down = fit
    size = int(OUT_W * SCALE * scale)
    art = cut.resize((size, size), Image.LANCZOS)
    frame = Image.new("RGBA", (OUT_W, OUT_H), (0, 0, 0, 0))
    x = (OUT_W - size) // 2 + int(right * OUT_W)
    frame.alpha_composite(art, (x, OUT_H - size + int(down * OUT_W)))
    alpha = ImageChops.multiply(frame.getchannel("A"), medallion_mask())
    frame.putalpha(alpha)
    return frame


def rim(cut):
    """A crisp violet outline and a soft violet glow round the silhouette."""
    alpha = cut.getchannel("A").point(lambda v: 255 if v > 128 else 0)
    line = alpha.filter(ImageFilter.MaxFilter(21))
    glow = alpha.filter(ImageFilter.MaxFilter(35)).filter(ImageFilter.GaussianBlur(16))
    out = Image.new("RGBA", cut.size, RIM + (0,))
    out.putalpha(ImageChops.lighter(line, glow))
    out.alpha_composite(cut)
    return out


def main():
    os.makedirs(OUT, exist_ok=True)
    for name in os.listdir(HERE):
        if not (name.startswith("portrait_") and name.endswith(".png")):
            continue
        base = name[len("portrait_") : -4]
        src = Image.open(os.path.join(HERE, name))
        if base == "assassin":
            cut = rim(key(src, (0, 255, 0)))
        else:
            cut = key(src, (255, 0, 255))
        place(cut, FIT.get(base, (1.0, 0.0, 0.0))).save(os.path.join(OUT, base + ".png"))
        print("portrait", base)
    icons = key(Image.open(os.path.join(HERE, "icons.png")), (255, 0, 255))
    names = ["range", "power", "speed", "boy", "girl", "lock"]
    for n, name in enumerate(names):
        cell = icons.crop(((n % 3) * 512, (n // 3) * 512, (n % 3 + 1) * 512, (n // 3 + 1) * 512))
        box = cell.getchannel("A").point(lambda v: 255 if v > 40 else 0).getbbox()
        if box:
            cell = cell.crop(box)
        side = max(cell.size) + 16
        square = Image.new("RGBA", (side, side), (0, 0, 0, 0))
        square.alpha_composite(cell, ((side - cell.size[0]) // 2, (side - cell.size[1]) // 2))
        square.resize((256, 256), Image.LANCZOS).save(os.path.join(OUT, "icon_" + name + ".png"))
        print("icon", name)


if __name__ == "__main__":
    main()
