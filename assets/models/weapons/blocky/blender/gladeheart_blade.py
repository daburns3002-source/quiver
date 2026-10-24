"""The Gladeheart Blade (Mythic), from
assets/concepts/blocky/weapons/skins/forest/gladeheart_blade_views.png.

A dark teal blade with a glowing cyan core, framed by branches that fork
across its face, a big leaf for a point, leaves and glowing pink crystals
along both edges, white flowers, a rainbow crystal on the front, branch
crossguard with leafy ends and flowers round a rainbow heart (a green leaf on
the back), a gold collar, a vine-wrapped grip and a leafy pommel holding a
rainbow gem. Glowing pieces are the `Crystal` and `Gem` parts (drawn Neon in
the game). Run in Blender after blocky.py.
"""

import math
import random

TEAL, TEAL_D, CYAN, CYAN_L = "#1E5E5C", "#164545", "#19E3EE", "#B8F4FF"
BARK_D, BARK, BARK_L = "#4E3220", "#8A5631", "#B9784A"
LEAF_D, LEAF, LEAF_L = "#2C6E2B", "#56A22E", "#8ACD3D"
PINK, PINK_D, PINK_L = "#EE8CEE", "#A63CCB", "#F8B9F6"
WHITE, PETAL, YELLOW, ORANGE = "#F2EEE6", "#FBD9EC", "#FBD72E", "#F49A2C"
GOLD, GOLD_L = "#D9A13B", "#F1C766"
RAINBOW = ["#FFE14A", "#FF9C3C", "#FF6FB5", "#C66BFF", "#5FB8FF", "#3EEBE0"]


def build():
    random.seed(11)
    b = Builder("GladeheartBlade")  # noqa: F821 (from blocky.py)
    W, T = 0.24, 0.075
    z0, z1 = 0.34, 1.05

    # blade body and glowing core
    b.box("Blade", (0, 0, (z0 + z1) / 2), (W, T, z1 - z0), TEAL)
    for side in (-1, 1):
        b.box("Crystal", (0, side * (T / 2 + 0.002), (z0 + z1) / 2 + 0.03), (0.07, 0.006, z1 - z0 - 0.12), CYAN)
        for _ in range(8):
            b.box(
                "Crystal",
                (random.uniform(-0.025, 0.025), side * (T / 2 + 0.004), random.uniform(z0 + 0.1, z1 - 0.05)),
                (0.012, 0.004, 0.012),
                CYAN_L,
            )
        b.box("Blade", (0, side * (T / 2 + 0.001), z0 + 0.04), (0.16, 0.004, 0.08), TEAL_D)

    # branch frame: an edge rail each side, forking branches across both faces
    for sx in (-1, 1):
        b.box("Branch", (sx * (W / 2 - 0.015), 0, (z0 + z1) / 2), (0.04, T + 0.02, z1 - z0), BARK)
        b.box("Branch", (sx * (W / 2 - 0.005), -0.02, (z0 + z1) / 2), (0.012, T, z1 - z0 - 0.06), BARK_L)
    for side in (-1, 1):
        y = side * (T / 2 + 0.012)
        for z_start, sx in ((0.40, -1), (0.40, 1), (0.62, -1), (0.66, 1), (0.84, -1), (0.88, 1)):
            x = sx * 0.075
            for k in range(4):
                b.box("Branch", (x, y, z_start + k * 0.03), (0.03, 0.02, 0.03), BARK if k % 2 else BARK_D)
                x -= sx * 0.016

    # leaf point: stepped greens
    z = z1
    for w, h, c in ((0.2, 0.06, LEAF), (0.17, 0.06, LEAF), (0.13, 0.06, LEAF_L), (0.08, 0.05, LEAF_L), (0.035, 0.04, LEAF_L)):
        b.box("Leaves", (0, 0, z + h / 2), (w, T + 0.01, h), c)
        z += h
    b.box("Leaves", (0, -T / 2 - 0.006, z1 + 0.12), (0.012, 0.008, 0.2), LEAF_D)  # midrib
    b.box("Leaves", (0, T / 2 + 0.006, z1 + 0.12), (0.012, 0.008, 0.2), LEAF_D)

    # leaves and pink crystals along both edges
    for sx in (-1, 1):
        for zc in (0.38, 0.47, 0.57, 0.66, 0.76, 0.86, 0.96, 1.04):
            zc += random.uniform(-0.015, 0.015)
            b.box("Leaves", (sx * (W / 2 + 0.03), random.uniform(-0.015, 0.015), zc), (0.08, 0.07, 0.06), random.choice([LEAF, LEAF_D, LEAF]))
            b.box("Leaves", (sx * (W / 2 + 0.07), 0, zc + 0.025), (0.04, 0.045, 0.04), LEAF_L)
            b.box("Leaves", (sx * (W / 2 - 0.02), -(T / 2 + 0.02), zc - 0.02), (0.05, 0.02, 0.045), random.choice([LEAF, LEAF_L]))
            b.box("Leaves", (sx * (W / 2 - 0.02), (T / 2 + 0.02), zc + 0.01), (0.05, 0.02, 0.045), random.choice([LEAF, LEAF_D]))
        for zc in ((0.6, 0.92) if sx < 0 else (0.5, 0.78, 1.0)):
            b.box("Crystal", (sx * (W / 2 + 0.05), 0, zc), (0.06, 0.06, 0.1), PINK)
            b.box("Crystal", (sx * (W / 2 + 0.05), -0.015, zc + 0.02), (0.02, 0.02, 0.04), PINK_L)
            b.box("Crystal", (sx * (W / 2 + 0.02), 0.01, zc - 0.03), (0.03, 0.03, 0.03), PINK_D)

    # flowers: four petals round a yellow middle, on the front
    def flower(x, z, y=-(T / 2 + 0.018), s=1.0):
        for dx, dz in ((0.022, 0), (-0.022, 0), (0, 0.022), (0, -0.022)):
            b.box("Flowers", (x + dx * s, y, z + dz * s), (0.024 * s, 0.014, 0.024 * s), WHITE)
        b.box("Flowers", (x, y - 0.004, z), (0.02 * s, 0.016, 0.02 * s), YELLOW)
        b.box("Flowers", (x + 0.004, y - 0.006, z + 0.004), (0.008 * s, 0.01, 0.008 * s), ORANGE)

    flower(-0.07, 0.97, s=1.3)
    flower(0.08, 1.04, s=1.3)
    flower(-0.08, 0.74, s=1.3)

    # rainbow crystal on the front of the blade
    rows = [(0.04, 0.035), (0.08, 0.05), (0.12, 0.06), (0.13, 0.06), (0.12, 0.06), (0.09, 0.05), (0.05, 0.045), (0.025, 0.035)]
    z = 0.5
    for i, (w, h) in enumerate(rows):
        b.box("Crystal", (0, -(T / 2 + 0.02), z + h / 2), (w, 0.03, h), RAINBOW[min(i, len(RAINBOW) - 1)])
        z += h
    b.box("Crystal", (-0.015, -(T / 2 + 0.037), 0.68), (0.02, 0.006, 0.05), "#FFFFFF")

    # crossguard: branch arms, leafy ends, flowers, rainbow heart (leaf on the back)
    gz = 0.3
    b.box("Branch", (0, 0, gz), (0.44, 0.07, 0.06), BARK)
    for sx in (-1, 1):
        b.box("Branch", (sx * 0.17, 0, gz + 0.03), (0.08, 0.06, 0.04), BARK_D)
        for dx, dz, c in ((0.25, 0.0, LEAF), (0.29, 0.05, LEAF_L), (0.22, -0.06, LEAF_D), (0.28, -0.04, LEAF), (0.2, 0.07, LEAF), (0.31, 0.0, LEAF_L), (0.24, 0.09, LEAF_L)):
            b.box("Leaves", (sx * dx, random.uniform(-0.02, 0.02), gz + dz), (0.09, 0.085, 0.075), c)
        flower(sx * 0.13, gz + 0.01, s=0.9)
    heart = [(-0.035, 0.03), (0.035, 0.03), (-0.05, 0.0), (0.0, 0.0), (0.05, 0.0), (-0.025, -0.03), (0.025, -0.03), (0.0, -0.055)]
    for i, (dx, dz) in enumerate(heart):
        b.box("Gem", (dx * 1.45, -0.05, gz + dz * 1.45), (0.072, 0.034, 0.05), RAINBOW[(i + 1) % len(RAINBOW)])
    b.box("Gem", (-0.035, -0.067, gz + 0.035), (0.02, 0.006, 0.015), "#FFFFFF")
    b.box("Leaves", (0, 0.05, gz), (0.1, 0.03, 0.1), LEAF)
    b.box("Leaves", (0, 0.05, gz + 0.06), (0.06, 0.03, 0.05), LEAF_L)

    # gold collar and the vine-wrapped grip
    b.box("Gold", (0, 0, 0.245), (0.11, 0.11, 0.03), GOLD)
    b.box("Gold", (0, -0.056, 0.245), (0.06, 0.006, 0.01), GOLD_L)
    for i in range(6):
        z = 0.205 - i * 0.04
        b.box("Grip", (0, 0, z), (0.07, 0.07, 0.04), BARK if i % 2 else BARK_D)
        a = i * math.pi / 2
        b.box("Leaves", (math.cos(a) * 0.04, math.sin(a) * 0.04, z), (0.03, 0.03, 0.045), LEAF)
    b.box("Gold", (0, 0, -0.05), (0.11, 0.11, 0.03), GOLD)

    # pommel: a ball of leaves round a rainbow gem in a bark ring
    pz = -0.15
    b.box("Leaves", (0, 0, pz), (0.17, 0.11, 0.15), LEAF)
    b.box("Leaves", (0, 0, pz), (0.13, 0.13, 0.19), LEAF_D)
    for k in range(8):
        a = k * math.pi / 4
        b.box("Leaves", (math.cos(a) * 0.095, random.choice([-1, 1]) * 0.02, pz + math.sin(a) * 0.09), (0.05, 0.08, 0.05), random.choice([LEAF, LEAF_L]))
    b.box("Branch", (0, -0.062, pz), (0.11, 0.01, 0.11), BARK)
    for i, (w, h) in enumerate(((0.05, 0.02), (0.08, 0.025), (0.08, 0.025), (0.05, 0.02))):
        b.box("Gem", (0, -0.07, pz + 0.035 - i * 0.023), (w, 0.012, h), RAINBOW[(i * 2) % len(RAINBOW)])
    b.build()
    return b


blade = build()
print("GladeheartBlade triangles:", blade.triangles())
