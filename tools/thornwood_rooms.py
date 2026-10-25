"""Generate Level 2's forty Thornwood rooms into src/shared/Config/Balance.luau.

    python -I tools/thornwood_rooms.py

After Archero 2's rooms (owner, 2026-10-25: "study this for the map layouts,
actually create me 40 rooms of this area with randomly placed objects but
make sure there is a clear path to the exit every time and make sure the
obstacles are no more than 30"): mostly open floor, a few pieces of cover
each, often in mirrored pairs or a short row, never in the way of the start
or the gate.

Every room is drawn by the Thornwood kit (`KitLayout`): a long box is a
bramble hedge, a squat one a mossy boulder, a flat one a thorn bush (blocks
walking, not arrows). Seeded, so the same forty come out every time. Each
room is checked here before it is kept:

- at most `MAX_PIECES` pieces covering at most `MAX_COVER` of the floor:
  the owner's ceiling is 30% of the room ("30% of the room", 2026-10-25),
  and these stay far under it, as they also asked for "way less" cover
  (the forty come out 0.7-5.8%, 2.4% on average);
- every piece clear of the start, the exit pad and the gate's approach,
  and a body's width from every other piece and from the walls, so nothing
  makes a pocket an enemy or the player can stick in;
- a walk from the start to the exit for a body `PLAYER_RADIUS` wide,
  searched cell by cell (`tests/RoomPaths.spec` checks it again in game).

Rooms 10, 20 and 30 are the boss arena with an elite fight; room 40 is the
Broodmother, alone.
"""
import pathlib
import random
from collections import deque

ROOT = pathlib.Path(__file__).resolve().parents[1]
BALANCE = ROOT / "src" / "shared" / "Config" / "Balance.luau"

HALF_X, HALF_Z = 35 / 2, 58 / 2
START = (0.0, 23.0)
EXIT = (0.0, -26.5)
PLAYER_RADIUS = 1.5
#: Studs between any two pieces, and between a piece and a side wall
#: (or flush against it).
GAP = 3.6
MAX_PIECES = 7
MAX_COVER = 0.09
SEED = 2026_10_25

HEDGE_H, BOULDER_H, BUSH_H = 2.6, 1.6, 0.4

BEGIN = "\t--[[\n\t\tLevel 2 (2026-10-25)"
END_MARK = "\n}\n\nlocal Balance = {"


def hedge(rng, x, z, along_x):
    length = rng.choice([6.0, 7.5, 9.0, 10.5])
    return (x, z, length, HEDGE_H, 3.0) if along_x else (x, z, 3.0, HEDGE_H, length)


def boulder(rng, x, z):
    s = rng.choice([2.6, 3.0, 3.4])
    return (x, z, s, BOULDER_H, s)


def bush(rng, x, z):
    w = rng.choice([3.4, 3.4, 6.8])
    return (x, z, w, BUSH_H, 3.4) if rng.random() < 0.5 else (x, z, 3.4, BUSH_H, w)


def make(rng, kind, x, z):
    if kind == "hedge":
        return hedge(rng, x, z, rng.random() < 0.7)
    if kind == "boulder":
        return boulder(rng, x, z)
    return bush(rng, x, z)


def mirrored(piece):
    x, z, w, h, d = piece
    return (-x, z, w, h, d)


def pattern(rng):
    """One room's pieces, by one of Archero 2's habits."""
    kind = rng.choice(["pair", "row", "centre", "scatter", "pairs", "lane"])
    pieces = []
    if kind == "pair":  # one mirrored pair, sometimes a second
        for _ in range(rng.choice([1, 2])):
            p = make(rng, rng.choice(["boulder", "hedge", "bush"]), rng.uniform(5, 11), rng.uniform(-18, 14))
            pieces += [p, mirrored(p)]
    elif kind == "row":  # a short row of blocks across the room
        z = rng.uniform(-16, 10)
        n = rng.choice([2, 3])
        xs = {2: [-7, 7], 3: [-10, 0, 10]}[n]
        k = rng.choice(["boulder", "boulder", "bush"])
        pieces = [make(rng, k, x, z) for x in xs]
    elif kind == "centre":  # one piece in the middle, a pair further on
        pieces.append(hedge(rng, 0, rng.uniform(-8, 4), True))
        p = boulder(rng, rng.uniform(7, 11), rng.uniform(-20, -12))
        pieces += [p, mirrored(p)]
    elif kind == "pairs":  # two hedges side by side with the way between
        z = rng.uniform(-14, 6)
        p = hedge(rng, rng.uniform(8, 10), z, rng.random() < 0.5)
        pieces += [p, mirrored(p)]
        if rng.random() < 0.6:
            pieces.append(make(rng, "bush", 0, z + rng.choice([-9, 9])))
    elif kind == "lane":  # hedges along the sides, the middle a lane
        for z in rng.sample([-16, -6, 4], 2):
            p = hedge(rng, 11.5, z, False)
            pieces += [p, mirrored(p)]
    else:  # a few pieces anywhere
        for _ in range(rng.randint(2, 5)):
            pieces.append(make(rng, rng.choice(["boulder", "boulder", "hedge", "bush"]),
                               rng.uniform(-12, 12), rng.uniform(-18, 14)))
    return kind, pieces


def fits(pieces):
    if not 1 <= len(pieces) <= MAX_PIECES:
        return False
    cover = sum(w * d for _, _, w, _, d in pieces)
    if cover > MAX_COVER * (2 * HALF_X) * (2 * HALF_Z):
        return False
    for i, (x, z, w, h, d) in enumerate(pieces):
        # inside the room, and flush to a side wall or a body clear of it
        left = HALF_X - (abs(x) + w / 2)
        if left < 0 or 0 < left < GAP or abs(z) + d / 2 > HALF_Z - GAP:
            return False
        # clear of the start, the exit pad and the gate's approach
        for px, pz, r in ((*START, 6), (*EXIT, 6)):
            if abs(px - x) < w / 2 + r and abs(pz - z) < d / 2 + r:
                return False
        if z - d / 2 < -HALF_Z + 9 and abs(x) < w / 2 + 6:
            return False
        for j, (x2, z2, w2, h2, d2) in enumerate(pieces):
            if j <= i:
                continue
            gx = abs(x - x2) - (w + w2) / 2
            gz = abs(z - z2) - (d + d2) / 2
            if max(gx, gz) < GAP:
                return False
    return True


def walkable(pieces, cell=0.5):
    """A body PLAYER_RADIUS wide gets from the start to the exit."""
    nx, nz = int(2 * HALF_X / cell), int(2 * HALF_Z / cell)

    def free(i, j):
        x = -HALF_X + (i + 0.5) * cell
        z = -HALF_Z + (j + 0.5) * cell
        if abs(x) > HALF_X - PLAYER_RADIUS or abs(z) > HALF_Z - PLAYER_RADIUS:
            return False
        return all(
            abs(x - px) >= w / 2 + PLAYER_RADIUS or abs(z - pz) >= d / 2 + PLAYER_RADIUS
            for px, pz, w, _, d in pieces
        )

    def at(p):
        return int((p[0] + HALF_X) / cell), int((p[1] + HALF_Z) / cell)

    start, goal = at(START), at(EXIT)
    seen = {start}
    queue = deque([start])
    while queue:
        c = queue.popleft()
        if c == goal:
            return True
        for di, dj in ((1, 0), (-1, 0), (0, 1), (0, -1)):
            n = (c[0] + di, c[1] + dj)
            if 0 <= n[0] < nx and 0 <= n[1] < nz and n not in seen and free(*n):
                seen.add(n)
                queue.append(n)
    return False


def num(v):
    r = round(v, 2)
    return str(int(r)) if r == int(r) else f"{r:g}"


def obstacles_lua(pieces):
    rows = [
        f"\t\t\t{{ offset = Vector2.new({num(x)}, {num(z)}), size = Vector3.new({num(w)}, {num(h)}, {num(d)}) }},"
        for x, z, w, h, d in pieces
    ]
    return "\t\tobstacles = {\n" + "\n".join(rows) + "\n\t\t},\n" if rows else "\t\tobstacles = {},\n"


#: The boss arena's four corner boulders, the Glade Heart's.
BOSS_ARENA = [(sx * 11.42, sz * 16.18, 3.9, 3.8, 4.4) for sz in (-1, 1) for sx in (-1, 1)]


def roster(n):
    """Who fights in room n (1-40): one new enemy at a time, then mixes."""
    if n < 4:
        return 2 + (n > 1), "brambleBoar"
    if n < 7:
        return 3, "brambleBoar, burrThistle"
    if n < 11:
        return 4, "brambleBoar, burrThistle, brambleSow"
    if n < 14:
        return 4, "brambleBoar, brambleLurker"
    count = min(7, 4 + (n - 14) // 6)
    mixes = [
        "brambleBoar, burrThistle, brambleLurker",
        "brambleBoar, brambleSow, burrThistle",
        "brambleSow, brambleLurker, brambleBoar",
        "burrThistle, brambleLurker, brambleBoar, brambleSow",
    ]
    return count, mixes[n % len(mixes)]


def main():
    rng = random.Random(SEED)
    out = [
        "\t--[[\n"
        "\t\tLevel 2 (2026-10-25): forty Thornwood rooms, generated by\n"
        "\t\t`tools/thornwood_rooms.py` after Archero 2's (owner: \"create me 40\n"
        "\t\trooms of this area with randomly placed objects but make sure there\n"
        "\t\tis a clear path to the exit every time\"): mostly open floor, a few\n"
        "\t\tpieces of cover, a body's width round each. Rooms 10, 20 and 30 are\n"
        "\t\tthe boss arena with an elite fight; 40 is the Broodmother. Edit the\n"
        "\t\tscript, not these rows.\n"
        "\t]]\n"
    ]
    kinds = []
    for n in range(1, 41):
        if n == 40:
            name, arena, pieces, count, who = "Brood Heart", "ThornBoss", BOSS_ARENA, 1, "broodmother"
        elif n % 10 == 0:
            name, arena, pieces = f"Brood Clearing {n // 10}", "ThornBoss", BOSS_ARENA
            count, who = 4 + n // 10, "brambleSow, brambleBoar, burrThistle, brambleLurker"
            if n == 10:
                who = "brambleSow, brambleBoar, burrThistle"
        else:
            for _ in range(10000):
                kind, pieces = pattern(rng)
                if fits(pieces) and walkable(pieces):
                    break
            else:
                raise SystemExit(f"room {n}: no layout fits")
            kinds.append(kind)
            name, arena = f"Thornwood {n}", "ThornHedges"
            count, who = roster(n)
        assert walkable(pieces), name
        out.append(
            "\t{\n"
            f'\t\tname = "{name}",\n'
            f'\t\tarena = "{arena}",\n'
            + obstacles_lua(pieces)
            + f"\t\tenemyCount = {count},\n"
            f"\t\troster = {{ {who} }},\n"
            "\t},\n"
        )
    text = BALANCE.read_text(encoding="utf-8")
    i = text.index(BEGIN)
    j = text.index(END_MARK, i)
    BALANCE.write_text(text[:i] + "".join(out).rstrip("\n") + text[j:], encoding="utf-8", newline="\n")
    print("wrote 40 rooms:", {k: kinds.count(k) for k in sorted(set(kinds))})


if __name__ == "__main__":
    main()
