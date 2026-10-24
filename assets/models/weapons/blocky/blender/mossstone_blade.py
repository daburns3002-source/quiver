"""The Mossstone Blade (Uncommon), from
assets/concepts/blocky/weapons/skins/forest/mossstone_blade_views.png.

Grey stone blade with a short stepped point, two moss vines up each face with
clover clusters, stone crossguard with moss on its arms, a dark core holding a
gold-framed red gem, a banded brown grip between gold collars, and a round
stone pommel with a gold rim and a moss cross. Run in Blender after blocky.py.
"""

import math
import random

STONE_L, STONE_M, STONE_D = "#C2BFBA", "#8E8C88", "#4A4D50"
BR_D, BR_M = "#4B3226", "#6E4733"
GOLD_L, GOLD = "#E8BE5E", "#C9912A"
G2, G3, G4 = "#6E8A2E", "#8FAE34", "#B3D436"
RED, RED_HI, INK = "#E0343B", "#FF8A8A", "#2E3134"


def build():
    random.seed(7)
    b = Builder("MossstoneBlade")  # noqa: F821 (from blocky.py)

    # blade
    W, T = 0.21, 0.075
    z0, z1 = 0.34, 1.08
    b.box("Blade", (0, 0, (z0 + z1) / 2), (W, T, z1 - z0), STONE_L)
    z = z1
    for i, (w, h) in enumerate([(0.18, 0.05), (0.13, 0.05), (0.08, 0.045), (0.035, 0.035)]):
        b.box("Blade", (0, 0, z + h / 2), (w, T * (1 - 0.15 * i), h), STONE_L if i < 2 else STONE_M)
        z += h
    for side in (-1, 1):
        for _ in range(10):
            b.box(
                "Blade",
                (random.uniform(-0.07, 0.07), side * (T / 2 + 0.002), random.uniform(z0 + 0.04, z1 - 0.02)),
                (random.choice([0.04, 0.06]), 0.006, random.choice([0.03, 0.05])),
                STONE_M,
            )
        for _ in range(5):
            b.box(
                "Blade",
                (random.uniform(-0.06, 0.06), side * (T / 2 + 0.004), random.uniform(z0 + 0.05, z1 - 0.05)),
                (0.035, 0.006, 0.008),
                STONE_D,
            )

    # moss vines: two per face, wandering up, with clover clusters
    def vine(side, seed, x):
        rnd = random.Random(seed)
        z = z0 + 0.02
        while z < z1 + 0.05:
            b.box("Moss", (x, side * (T / 2 + 0.011), z), (0.032, 0.022, 0.032), rnd.choice([G3, G3, G2]))
            if rnd.random() < 0.13:
                cx = x + rnd.choice([-0.032, 0.032])
                for dx, dz in ((0, 0), (0.03, 0), (0, 0.03), (0.03, 0.03)):
                    b.box("Moss", (cx + dx - 0.015, side * (T / 2 + 0.015), z + dz), (0.03, 0.026, 0.03), G4)
            if rnd.random() < 0.07:
                ex = 0.106 if x > 0 else -0.106
                b.box("Moss", (ex, 0, z), (0.028, T + 0.02, 0.04), G3)
            z += 0.031
            x = max(-0.08, min(0.08, x + rnd.choice([-0.031, 0, 0.031, 0, 0])))

    vine(-1, 1, -0.05)
    vine(-1, 2, 0.05)
    vine(1, 3, -0.04)
    vine(1, 4, 0.05)

    # crossguard
    gz = 0.28
    b.box("Guard", (0, 0, gz), (0.5, 0.09, 0.085), STONE_L)
    for sx in (-1, 1):
        b.box("Guard", (sx * 0.235, 0, gz), (0.055, 0.1, 0.105), STONE_M)
        for x, dz in ((0.2, 0.04), (0.24, -0.03), (0.13, 0.045), (0.17, -0.045)):
            b.box("Moss", (sx * x, -0.05, gz + dz), (0.035, 0.03, 0.035), random.choice([G3, G4]))
            b.box("Moss", (sx * x, 0.05, gz - dz), (0.035, 0.03, 0.035), random.choice([G3, G2]))
    b.box("Guard", (0, 0, gz + 0.01), (0.16, 0.11, 0.17), INK)
    b.box("Gold", (0, -0.058, gz + 0.01), (0.12, 0.012, 0.13), GOLD)
    b.box("Gold", (0, -0.062, gz + 0.01), (0.09, 0.012, 0.10), GOLD_L)
    b.box("Gem", (0, -0.068, gz + 0.01), (0.06, 0.016, 0.08), RED)
    b.box("Gem", (0.012, -0.075, gz + 0.025), (0.02, 0.006, 0.02), RED_HI)
    b.box("Gold", (0, 0.058, gz + 0.01), (0.10, 0.012, 0.12), GOLD)
    b.box("Guard", (0, 0.062, gz + 0.01), (0.07, 0.012, 0.09), INK)

    # grip
    b.box("Gold", (0, 0, 0.195), (0.1, 0.1, 0.03), GOLD)
    for i in range(6):
        z = 0.165 - i * 0.04
        b.box("Grip", (0, 0, z), (0.072, 0.072, 0.04), BR_M)
        b.box("Grip", (0, 0, z - 0.017), (0.08, 0.08, 0.008), BR_D)
    b.box("Gold", (0, 0, -0.085), (0.11, 0.11, 0.03), GOLD)

    # pommel
    pz, s = -0.19, 1.3
    b.box("Pommel", (0, 0, pz), (0.2 * s, 0.1, 0.12 * s), STONE_M)
    b.box("Pommel", (0, 0, pz), (0.12 * s, 0.1, 0.2 * s), STONE_M)
    b.box("Pommel", (0, 0, pz), (0.17 * s, 0.105, 0.17 * s), STONE_L)
    for sx, sz in ((1, 1), (1, -1), (-1, 1), (-1, -1)):
        b.box("Gold", (sx * 0.075 * s, -0.055, pz + sz * 0.075 * s), (0.035, 0.01, 0.035), GOLD)
    b.box("Gold", (0, -0.057, pz), (0.11 * s, 0.008, 0.11 * s), GOLD_L)
    b.box("Pommel", (0, -0.061, pz), (0.09 * s, 0.008, 0.09 * s), STONE_D)
    b.box("Moss", (0, -0.067, pz), (0.03, 0.01, 0.085), G3)
    b.box("Moss", (0, -0.067, pz), (0.085, 0.01, 0.03), G3)
    for k in range(7):
        a = k * 0.9 + 0.3
        b.box(
            "Moss",
            (math.cos(a) * 0.125, random.choice([-1, 1]) * 0.035, pz + math.sin(a) * 0.125),
            (0.04, 0.05, 0.04),
            random.choice([G3, G4]),
        )
    b.build()
    return b


blade = build()
print("MossstoneBlade triangles:", blade.triangles())
