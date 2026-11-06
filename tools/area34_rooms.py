"""Generate the Drowned Village (area 3) and Bogheart Caverns (area 4) rooms
into src/shared/Config/Balance.luau, between its `BEGIN area34Rooms` and
`END area34Rooms` marks.

    python -I tools/area34_rooms.py

Both areas are built from the owner's kits (`Config/ArenaKits.Drowned`,
`.Bogheart`, 2026-11-05) after their approved reference sheets
(`assets/concepts/blocky/arenas/area03_drowned_village_v2.png`,
`area04_bogheart_caverns_v2.png`, `area04_bogheart_caverns_open.png`).
Every room uses only the sheet's own cover at the sheet's own places, so
each matches its sheet: the variants leave pieces out, never add or move
them. The middle stays open (owner, of the first area 3 sheet: "too
cluttered there is no space to move").

- **Drowned Village**: the well at the centre (on the causeway), two broken
  stone walls to the north and two crate-and-barrel stacks to the south,
  mirrored. The open floor has none of them (owner: "there should also be
  an open floor layout").
- **Bogheart Caverns**: four giant mushrooms, and the stream across the
  middle as four flat water boxes (they block walking, not arrows) with
  the bridge's gap in the centre and a stepping-stone gap near each side
  wall. The open floor is the same room without the stream (owner: "The
  open floor layout should take the water out of the middle and the
  bridge").

Each room is checked as `tools/thornwood_rooms.py` checks Thornwood's: a
body's width between pieces, clear of the start, the exit and the gate's
approach, and a walk from the start to the exit (`tests/RoomPaths.spec`
checks it again in game).

Area 3's rosters are stand-ins until its own enemies are modelled
(`docs/DROWNED-VILLAGE.md`): the Hollow Fisherman, its one finished enemy,
among Thornwood's, and its stage is behind no portal. Area 4 has its own
(2026-11-06): twenty rooms like Thornwood's, nineteen fights of the Spore
Puff, Glowcap and Shellback, then Grandmother Gulp alone in the Bogheart
Heart.
"""
import pathlib
from collections import deque

ROOT = pathlib.Path(__file__).resolve().parents[1]
BALANCE = ROOT / "src" / "shared" / "Config" / "Balance.luau"
BEGIN = "--[[ BEGIN area34Rooms"
END = "-- END area34Rooms"

HALF_X, HALF_Z = 35 / 2, 58 / 2
START = (0.0, 23.0)
EXIT = (0.0, -26.5)
PLAYER_RADIUS = 1.5
GAP = 3.6
MAX_COVER = 0.3

# -- Drowned Village, from the sheet (studs from the room's centre) --------
WELL = [(0.0, 0.0, 5.4, 1.6, 5.0)]
RUINS = [(sx * 9.0, -16.0, 4.6, 1.6, 3.2) for sx in (-1, 1)]
CRATES = [(sx * 9.0, 11.0, 5.0, 1.6, 2.5) for sx in (-1, 1)]

# -- Bogheart Caverns ------------------------------------------------------
MUSHROOMS = [(sx * 9.0, sz, 5.0, 4.0, 5.0) for sz in (-17.5, 10.0) for sx in (-1, 1)]
STREAM_Z, STREAM_D, STREAM_H = -2.0, 3.4, 0.4
#: The water between the walls and the stones, the stones and the bridge.
STREAM = [
    ((left + right) / 2, STREAM_Z, right - left, STREAM_H, STREAM_D)
    for left, right in ((-17.5, -15.0), (-11.0, -2.2), (2.2, 11.0), (15.0, 17.5))
]


def fits(pieces):
    """Thornwood's rules (`tools/thornwood_rooms.py`), with no cap on the
    pieces: each room's are its sheet's."""
    cover = sum(w * d for _, _, w, _, d in pieces)
    if cover > MAX_COVER * (2 * HALF_X) * (2 * HALF_Z):
        return False
    for i, (x, z, w, h, d) in enumerate(pieces):
        left = HALF_X - (abs(x) + w / 2)
        if left < -1e-6 or 1e-6 < left < GAP or abs(z) + d / 2 > HALF_Z - GAP:
            return False
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


#: (name, arena, pieces, enemyCount, roster), in the order they are played:
#: each a little harder than the one before.
DROWNED = [
    ("Drowned Village 1", "DrownedOpen", [], 3, "brambleBoar, hollowFisherman"),
    ("Drowned Village 2", "DrownedVillage", WELL + CRATES, 3, "brambleBoar, hollowFisherman"),
    ("Drowned Village 3", "DrownedVillage", WELL + RUINS, 4, "burrThistle, hollowFisherman, brambleBoar"),
    ("Drowned Village 4", "DrownedVillage", WELL + RUINS + CRATES, 4, "hollowFisherman, brambleBoar, burrThistle"),
    ("Drowned Village 5", "DrownedOpen", [], 5, "brambleBoar, hollowFisherman, brambleSow"),
    ("Drowned Village 6", "DrownedVillage", RUINS + CRATES, 5, "hollowFisherman, brambleLurker, burrThistle"),
    ("Drowned Village 7", "DrownedVillage", WELL + CRATES, 5, "brambleSow, hollowFisherman, brambleLurker"),
    ("Drowned Village 8", "DrownedVillage", WELL + RUINS + CRATES, 6, "hollowFisherman, brambleBoar, brambleLurker, burrThistle"),
    ("Drowned Village 9", "DrownedOpen", [], 6, "hollowFisherman, brambleSow, burrThistle, brambleBoar"),
    #: The Old Tollcrab's room, until he is built: an elite fight.
    ("Toll Gate", "DrownedBoss", WELL + RUINS + CRATES, 7, "hollowFisherman, brambleSow, brambleBoar, brambleLurker, burrThistle"),
]

TWO_NORTH = MUSHROOMS[:2]
TWO_SOUTH = MUSHROOMS[2:]
BOGHEART = [
    #: Nineteen fights, Spore Puffs first, then the Glowcap, then the
    #: Shellback, each room a little harder; then Grandmother Gulp alone.
    ("Bogheart Caverns 1", "BogheartOpen", MUSHROOMS, 3, "sporePuff"),
    ("Bogheart Caverns 2", "BogheartStream", STREAM + TWO_SOUTH, 3, "sporePuff, glowcap"),
    ("Bogheart Caverns 3", "BogheartStream", STREAM + MUSHROOMS, 4, "sporePuff, glowcap"),
    ("Bogheart Caverns 4", "BogheartOpen", MUSHROOMS, 4, "glowcap, sporePuff, sporePuff"),
    ("Bogheart Caverns 5", "BogheartStream", STREAM + TWO_NORTH, 4, "shellback, sporePuff"),
    ("Bogheart Caverns 6", "BogheartStream", STREAM + MUSHROOMS, 5, "sporePuff, glowcap, shellback"),
    ("Bogheart Caverns 7", "BogheartOpen", MUSHROOMS, 5, "shellback, sporePuff, glowcap"),
    ("Bogheart Caverns 8", "BogheartStream", STREAM + TWO_SOUTH, 5, "glowcap, sporePuff, sporePuff, shellback"),
    ("Bogheart Caverns 9", "BogheartStream", STREAM + MUSHROOMS, 5, "shellback, glowcap, sporePuff"),
    ("Bogheart Caverns 10", "BogheartOpen", MUSHROOMS, 6, "sporePuff, sporePuff, glowcap, shellback"),
    ("Bogheart Caverns 11", "BogheartStream", STREAM + TWO_NORTH, 6, "glowcap, shellback, sporePuff"),
    ("Bogheart Caverns 12", "BogheartStream", STREAM + MUSHROOMS, 6, "shellback, sporePuff, glowcap, sporePuff"),
    ("Bogheart Caverns 13", "BogheartOpen", MUSHROOMS, 6, "glowcap, glowcap, sporePuff, shellback"),
    ("Bogheart Caverns 14", "BogheartStream", STREAM + TWO_SOUTH, 7, "sporePuff, shellback, glowcap, sporePuff"),
    ("Bogheart Caverns 15", "BogheartStream", STREAM + MUSHROOMS, 7, "shellback, glowcap, sporePuff, sporePuff"),
    ("Bogheart Caverns 16", "BogheartOpen", MUSHROOMS, 7, "glowcap, sporePuff, shellback, sporePuff"),
    ("Bogheart Caverns 17", "BogheartStream", STREAM + TWO_NORTH, 7, "shellback, shellback, glowcap, sporePuff"),
    ("Bogheart Caverns 18", "BogheartStream", STREAM + MUSHROOMS, 8, "sporePuff, glowcap, shellback, sporePuff"),
    ("Bogheart Caverns 19", "BogheartStream", STREAM + MUSHROOMS, 8, "shellback, glowcap, sporePuff, glowcap, sporePuff"),
    ("Bogheart Heart", "BogheartBoss", STREAM + MUSHROOMS, 1, "grandmotherGulp"),
]


def table_lua(var, title, rooms):
    out = [f"local {var}: {{ RoomConfig }} = {{\n"]
    for name, arena, pieces, count, who in rooms:
        assert fits(pieces), name
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
    out.append("}\n")
    return "".join(out)


def main():
    block = (
        "--[[ BEGIN area34Rooms (2026-11-05): the Drowned Village's and Bogheart\n"
        "     Caverns' rooms, generated by `tools/area34_rooms.py` from each area's\n"
        "     reference sheet. Edit the script, not these rows. ]]\n"
        + table_lua("drownedRooms", "Drowned Village", DROWNED)
        + "\n"
        + table_lua("bogheartRooms", "Bogheart Caverns", BOGHEART)
        + END
    )
    text = BALANCE.read_text(encoding="utf-8")
    i, j = text.index(BEGIN), text.index(END) + len(END)
    BALANCE.write_text(text[:i] + block + text[j:], encoding="utf-8", newline="\n")
    print(f"wrote {len(DROWNED)} Drowned Village and {len(BOGHEART)} Bogheart Caverns rooms")


if __name__ == "__main__":
    main()
