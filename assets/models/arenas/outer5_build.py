"""The Windswept Cliffs' outer arena (area 5, docs/WINDSWEPT-CLIFFS.md): the
scenery past each room's walls, built block by block after its sheet
(assets/concepts/blocky/arenas/area05_windswept_cliffs.jpg) the way
outer34_build.py builds areas 3 and 4, in the same frame and with the same
rules (room frame, 1 unit = 1 stud, nothing in the hole or over 1.5 studs in
a gate lane, sRGB vertex colours, one node per part, glowing parts white and
named by prefix).

    python -I outer5_build.py            # windswept_cliffs_outer_arena_roblox.glb
    python -I outer5_build.py --preview out.png

The room is a slate plateau with nothing round it but sky: its own cliff
falls away under the walls into a sea of cloud far below, grey-blue slate
spires stand up out of the cloud with short bright grass on their tops,
prayer flags (red, yellow, green, blue) are strung on posts along the near
spires, pale-blue wind streaks blow past, and a plank bridge leaves each
gate for the next plateau.
"""

import importlib.util
import math
import pathlib
import sys

HERE = pathlib.Path(__file__).resolve().parent
spec = importlib.util.spec_from_file_location("outer34", HERE / "outer34_build.py")
o34 = importlib.util.module_from_spec(spec)
spec.loader.exec_module(o34)

Scene, jit, blocked, TOP, HOLE, GATE = o34.Scene, o34.jit, o34.blocked, o34.TOP, o34.HOLE, o34.GATE

# from the sheet
SLATE = [(112, 128, 160), (96, 110, 142), (128, 144, 176), (84, 96, 126)]
SLATE_TOP = (146, 162, 194)
GRASS = [(110, 190, 60), (132, 206, 72), (92, 168, 52)]
CLOUD = [(236, 240, 248), (222, 230, 244), (246, 248, 252)]
CLOUD_SHADE = (196, 208, 228)
WOOD = (150, 98, 56)
WOOD_DARK = (112, 72, 40)
ROPE = (196, 168, 120)
FLAGS = [(222, 58, 52), (246, 200, 48), (82, 168, 70), (58, 110, 210)]
CLOUD_Y = -16.0


def cloud_sea(s):
    """Lumpy cloud far under the plateau: tiles of puffs over the whole
    extent, in four parts, with the hole's own shaft left open under the
    room (it is the cliff's)."""
    rng = s.rng
    quads = {}
    for i in range(o34.NX):
        for j in range(o34.NZ):
            x = o34.X0 + o34.TILE * (i + 0.5)
            z = o34.Z0 + o34.TILE * (j + 0.5)
            if abs(x) < HOLE[0] + 3 and abs(z) < HOLE[1] + 3:
                continue
            key = ("N" if z < 0 else "S") + ("W" if x < 0 else "E")
            o = quads.get(key)
            if not o:
                o = quads[key] = s.new(f"Cloud{key}", "Clouds")
            h = rng.uniform(0.6, 2.4)
            o.box(x - 1.5, CLOUD_Y - 1, z - 1.5, x + 1.5, CLOUD_Y + h, z + 1.5, CLOUD[rng.randrange(3)] if h > 1 else CLOUD_SHADE)


def cliff_skirt(s):
    """The plateau's own cliff under the walls: slate blocks stepping down
    from the floor to the cloud, ragged, with grass on the lip."""
    rng = s.rng
    rx, rz = HOLE

    def block(x, z, w, d):
        if blocked(x, z) and abs(x) < GATE + 1:
            return
        o = s.new("Cliff", "Cliff")
        y = TOP
        depth = rng.uniform(10, 15)
        steps = 3
        for k in range(steps):
            f = 1 - k * 0.18
            hh = depth / steps
            o.cube(x, y - hh, z, w * f, hh, d * f, jit(rng, SLATE[rng.randrange(4)], 6))
            y -= hh
        if rng.random() < 0.7:
            o.cube(x, TOP - 0.3, z, w * 0.9, 0.3, d * 0.9, GRASS[rng.randrange(3)])

    a = -rx - 2
    while a < rx + 2:
        w = rng.uniform(3, 5)
        if not abs(a + w / 2) < GATE + 1.5:
            block(a + w / 2, -rz - 1.6, w, 3.2)
            block(a + w / 2, rz + 1.6, w, 3.2)
        a += w
    a = -rz - 2
    while a < rz + 2:
        d = rng.uniform(3, 5)
        block(-rx - 1.6, a + d / 2, 3.2, d)
        block(rx + 1.6, a + d / 2, 3.2, d)
        a += d


def spire(s, cx, cz, h, w=4.0, flags=False):
    """A slate pillar out of the cloud with grass on top."""
    if blocked(cx, cz, w / 2 + 1):
        return
    rng = s.rng
    o = s.new("Spire", "Spires")
    y = CLOUD_Y - 1
    top = TOP + h
    steps = 3
    for k in range(steps):
        f = 1 - k * 0.14
        hh = (top - y) / steps
        o.cube(cx + rng.uniform(-0.3, 0.3), y, cz + rng.uniform(-0.3, 0.3), w * f, hh, w * f, jit(rng, SLATE[rng.randrange(4)], 6))
        y += hh
    cap = w * (1 - (steps - 1) * 0.14)
    o.cube(cx, y, cz, cap * 0.92, 0.5, cap * 0.92, GRASS[rng.randrange(3)])
    for _ in range(rng.randint(1, 3)):
        o.cube(cx + rng.uniform(-cap / 3, cap / 3), y + 0.5, cz + rng.uniform(-cap / 3, cap / 3), 0.6, 0.5, 0.6, GRASS[rng.randrange(3)])
    # a ledge block or two stepping off its side
    for _ in range(rng.randint(0, 2)):
        side = rng.choice((-1, 1))
        ly = rng.uniform(CLOUD_Y + 4, top - 3)
        o.cube(cx + side * (w * 0.55), ly, cz + rng.uniform(-1, 1), w * 0.4, rng.uniform(1.5, 3), w * 0.5, SLATE[rng.randrange(4)])
    if flags:
        post_with_flags(s, cx - cap * 0.35, cz, y + 0.5, cx + cap * 0.35, cz)
    return y


def post_with_flags(s, x0, z0, y, x1, z1):
    """Two wooden posts and a string of prayer flags between them."""
    o = s.new("Flags", "Flags")
    for x, z in ((x0, z0), (x1, z1)):
        o.cube(x, y, z, 0.3, 2.4, 0.3, WOOD)
    n = max(3, int(math.hypot(x1 - x0, z1 - z0) / 0.7))
    for k in range(n):
        t = (k + 0.5) / n
        x = x0 + (x1 - x0) * t
        z = z0 + (z1 - z0) * t
        sag = 0.5 * math.sin(math.pi * t)
        o.cube(x, y + 2.2 - sag, z, 0.08, 0.06, 0.08, ROPE)
        o.cube(x, y + 1.7 - sag, z, 0.5, 0.5, 0.08, FLAGS[k % 4])


def bridge(s, sign):
    """Planks out of a gate (north sign -1, south +1) to the next plateau, at
    the floor, with rope rails on low posts (under 1.5 studs in the lane)."""
    o = s.new("Bridge", "Bridges")
    z = sign * (HOLE[1] + 0.2)
    end = sign * 52
    k = 0
    while (end - z) * sign > 0:
        o.box(-2.2, TOP - 0.35, z, 2.2, TOP - 0.05, z + sign * 0.9, WOOD if k % 2 else WOOD_DARK)
        z += sign * 1.0
        k += 1
    for x in (-2.5, 2.5):
        zz = sign * (HOLE[1] + 1)
        while (end - zz) * sign > 0:
            o.cube(x, TOP - 0.3, zz, 0.3, 1.3, 0.3, WOOD_DARK)
            zz += sign * 4
        o.box(x - 0.06, TOP + 0.85, sign * (HOLE[1] + 1), x + 0.06, TOP + 0.95, end, ROPE)
    # the next plateau's lip, beyond the lane
    p = s.new("Plateau", "Cliff")
    z0 = sign * 52
    p.box(-14, TOP - 12, z0, 14, TOP, z0 + sign * 9, SLATE[1])
    p.box(-13.5, TOP, z0 + sign * 0.5, 13.5, TOP + 0.3, z0 + sign * 8.5, GRASS[0])
    for x in (-10, -5, 5, 10):
        p.cube(x, TOP + 0.3, z0 + sign * 2, 2.4, 1.8, 2.4, SLATE[2])


def wind(s, cx, y, cz, length, along_x=True):
    """A glowing streak of wind, in steps."""
    o = s.new("Wind", "Wind", glow=True)
    for k in range(4):
        off = k * length / 4
        w = length / 4 + 0.4
        if along_x:
            o.box(cx + off, y + 0.25 * math.sin(k), cz, cx + off + w, y + 0.25 * math.sin(k) + 0.18, cz + 0.35, (255, 255, 255))
        else:
            o.box(cx, y + 0.25 * math.sin(k), cz + off, cx + 0.35, y + 0.25 * math.sin(k) + 0.18, cz + off + w, (255, 255, 255))


def windswept():
    s = Scene(5)
    rng = s.rng
    cloud_sea(s)
    cliff_skirt(s)
    bridge(s, -1)
    bridge(s, 1)
    # Spires off the sheet: tall ones behind the north wall and down the
    # sides, short ones near the walls, a few far out; prayer flags on the
    # near ones as the sheet strings them.
    near = [(-27, -26, 7, True), (27, -22, 8, True), (-28, 10, 6, True), (28, 16, 7, True), (-26, 32, 5, False), (26, 34, 6, False)]
    for x, z, h, f in near:
        spire(s, x, z, h, rng.uniform(4.5, 6.0), flags=f)
    far = [(-44, -44, 14), (-20, -50, 16), (22, -48, 12), (46, -40, 18), (-52, -12, 10), (54, 0, 13),
           (-48, 22, 9), (50, 28, 11), (-36, 50, 8), (36, 52, 9), (-64, -30, 12), (66, -18, 15), (-62, 44, 7), (64, 46, 8)]
    for x, z, h in far:
        spire(s, x, z, h, rng.uniform(4, 7))
    for _ in range(18):
        x, z = rng.uniform(-74, 74), rng.uniform(-58, 58)
        if not blocked(x, z, 6):
            spire(s, x, z, rng.uniform(-6, 2), rng.uniform(2, 3.5))
    # floating rocks
    for _ in range(8):
        x, z = rng.uniform(-70, 70), rng.uniform(-56, 56)
        if blocked(x, z, 5):
            continue
        o = s.new("Float", "Spires")
        y = rng.uniform(2, 9)
        o.cube(x, y, z, 2.2, 1.2, 2.0, SLATE[rng.randrange(4)])
        o.cube(x, y - 0.8, z, 1.4, 0.8, 1.2, SLATE[3])
        o.cube(x, y + 1.2, z, 1.8, 0.3, 1.6, GRASS[rng.randrange(3)])
    # wind streaks blowing across, outside the room
    for x, y, z, l, ax in [(-60, 3, -30, 14, True), (30, 5, -45, 16, True), (-70, 2, 20, 12, True), (40, 4, 40, 14, True),
                           (-40, 6, -56, 12, True), (58, -2, 10, 12, False), (-58, 1, -10, 12, False)]:
        if not blocked(x, z, 2):
            wind(s, x, y, z, l, ax)
    return s


if __name__ == "__main__":
    scene = windswept()
    scene.check()
    if "--preview" in sys.argv:
        o34.preview(scene, sys.argv[sys.argv.index("--preview") + 1], {"Wind": (200, 236, 255)})
    else:
        scene.glb(HERE / "windswept_cliffs_outer_arena_roblox.glb")
        print("wrote windswept_cliffs_outer_arena_roblox.glb")
