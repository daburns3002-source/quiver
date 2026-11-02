"""Draw the Angel's three views straight from `Config/AngelDesign`.

    python -I assets/concepts/blocky/encounters/angel/views.py

Writes `built_views.png` beside the sheet: FRONT, LEFT SIDE and TOP of the
blocks the game actually builds, to hold against
`angel_views.png` (the Codex sheet the owner approved) without needing
Studio.

It exists because Studio's `screen_capture` has been returning an empty
frame since PR #437, so the usual check for CLAUDE.md rule 13 -- screenshot
the thing in a playtest and compare it with its sheet -- cannot be done.
This is not that check and does not replace it: it is flat orthographic
rectangles with no lighting, drawn from the same numbers the game reads, so
it proves the proportions and the layout and says nothing about how the
thing looks lit in a room.

The parts are axis-aligned boxes, so each view is just rectangles painted
back to front.
"""
import json
import pathlib

from PIL import Image, ImageDraw, ImageFont

HERE = pathlib.Path(__file__).resolve().parent
ROOT = HERE.parents[4]
DESIGN = ROOT / "src" / "shared" / "Config" / "AngelDesign.luau"
OUT = HERE / "built_views.png"

#: Pixels per stud, and the margin round each view.
SCALE = 54
MARGIN = 26
LABEL = 44
BACKGROUND = (203, 203, 203)
INK = (20, 20, 20)

DESIGN_JSON = HERE / "built_parts.json"


def read():
    """Every block the game builds, as (name, size, offset, rgb).

    From `built_parts.json`, which is dumped out of the running config
    rather than parsed out of the Luau, so these are the exact numbers
    `Run/AngelProp` places. Refresh it by running this in Studio against
    `Config/AngelDesign` and pasting the result back:

        for _, p in D.parts do ... end  -- name, size, offset, colour

    `grounded` parts (the pool of light) are left out: they are the floor,
    not the figure.
    """
    out = []
    for row in json.loads(DESIGN_JSON.read_text(encoding="utf-8")):
        if row["grounded"]:
            continue
        out.append((row["name"], tuple(row["size"]), tuple(row["offset"]), tuple(row["rgb"])))
    return out


def shade(rgb, factor):
    return tuple(max(0, min(255, int(c * factor))) for c in rgb)


def draw_view(blocks, across, up, depth, flip_across, title, height_studs, width_studs, ground_line=True):
    """One orthographic view. `across`/`up`/`depth` index into (x, y, z)."""
    w = int(width_studs * SCALE) + MARGIN * 2
    h = int(height_studs * SCALE) + MARGIN * 2 + LABEL
    img = Image.new("RGB", (w, h), BACKGROUND)
    pen = ImageDraw.Draw(img)

    def place(value, size_value, axis_is_up):
        if axis_is_up:
            #: y grows up, the image grows down. In TOP, where the vertical
            #: axis is z and runs either side of nought, the same maths puts
            #: the figure in the middle because `height_studs` is its full
            #: depth.
            middle = 0 if ground_line else height_studs / 2
            return (height_studs - (value + middle + size_value / 2)) * SCALE + MARGIN
        return (value - size_value / 2) * SCALE + width_studs * SCALE / 2 + MARGIN

    #: Back to front, so nearer blocks paint over further ones.
    order = sorted(blocks, key=lambda b: b[2][depth], reverse=True)
    for name, size, offset, rgb in order:
        a = offset[across] * (-1 if flip_across else 1)
        left = place(a, size[across], False)
        topy = place(offset[up], size[up], True)
        right = left + size[across] * SCALE
        bottom = topy + size[up] * SCALE
        #: A flat fill plus a darker edge, so touching blocks stay apart.
        pen.rectangle([left, topy, right, bottom], fill=rgb, outline=shade(rgb, 0.72))

    #: The ground line, in the views that look at the Angel from the side.
    #: Not in TOP, where the floor is the whole picture and a line across
    #: the middle of it means nothing.
    if ground_line:
        ground = place(0, 0, True)
        if 0 < ground < h - LABEL:
            pen.line([(0, ground), (w, ground)], fill=(150, 150, 150), width=2)

    try:
        font = ImageFont.truetype("arialbd.ttf", 26)
    except OSError:
        font = ImageFont.load_default()
    box = pen.textbbox((0, 0), title, font=font)
    pen.text(((w - box[2]) / 2, h - LABEL + 6), title, fill=INK, font=font)
    return img


def main():
    blocks = read()
    tall = max(o[1] + s[1] / 2 for _, s, o, _ in blocks) + 0.4
    wide = max(abs(o[0]) + s[0] / 2 for _, s, o, _ in blocks) * 2 + 0.8
    deep = max(abs(o[2]) + s[2] / 2 for _, s, o, _ in blocks) * 2 + 0.8

    #: FRONT looks down -Z at the face, so +X is drawn to the left.
    front = draw_view(blocks, 0, 1, 2, True, "FRONT", tall, wide)
    #: LEFT SIDE looks along +X; -Z (the face) is drawn to the left.
    side = draw_view(blocks, 2, 1, 0, False, "LEFT SIDE", tall, deep)
    #: TOP looks down: across is x, "up" in the image is z.
    #: TOP looks straight down, so its vertical axis is z and it is
    #: centred rather than standing on a floor.
    top = draw_view(blocks, 0, 2, 1, True, "TOP", deep, wide, ground_line=False)

    pad = 18
    width = front.width + side.width + top.width + pad * 4
    height = max(front.height, side.height, top.height) + pad * 2
    sheet = Image.new("RGB", (width, height), (176, 176, 176))
    x = pad
    for view in (front, side, top):
        sheet.paste(view, (x, pad))
        x += view.width + pad
    sheet.save(OUT)
    print(f"wrote {OUT} from {len(blocks)} blocks")


if __name__ == "__main__":
    main()
