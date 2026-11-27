"""The Windswept Cliffs' (area 5) room layouts, after its approved sheet
`assets/concepts/blocky/arenas/area05_windswept_cliffs.jpg` and
docs/WINDSWEPT-CLIFFS.md ("Levels 5-1..5-15"). Imported by
`tools/area_levels.py`, which writes the rooms; checked here with
`tools/area34_rooms.py`'s rules (`fits`, `walkable`).

Pieces are (x, z, w, h, d) in studs from the room's centre, the room 35 x 58
with the start at (0, 23) and the exit at (0, -26.5). A piece no taller than
VOID_H is a drop, not cover (`Balance.Obstacle.void`): nobody walks into it,
arrows fly over it, and a push into it is a fall (`Shared/Util/CliffEdges`).
The kit draws a drop as cloud (`CloudGap`, the stream's role) and puts the
plank bridge in the middle gap, as Bogheart's stream and bridge are.

- **Cliffs Open** (`CliffsOpen`): one wide plateau, no cover (the owner's
  open-floor rule).
- **Twin Peaks** (`CliffsBridge`): two plateaus joined by the bridge, a gap
  across the middle, boulders and flag posts as cover on each.
- **Ledge Path** (`CliffsLedge`): a narrow walkway down the middle with
  drops each side, widening at both ends, a boulder each side of each end.
- **The Roc's peak** (`CliffsBoss`): open, flag posts only at the far
  corners, room for the Roc's dives.
"""

VOID_H = 0.1
BOULDER = (3.6, 2.9, 3.6)
POST = (1.2, 4.0, 1.2)

#: the gap across the middle of Twin Peaks, either side of a 4.8-stud bridge
GAP_Z, GAP_D = -2.0, 5.0
GAP = [
    ((left + right) / 2, GAP_Z, right - left, VOID_H, GAP_D)
    for left, right in ((-17.5, -2.4), (2.4, 17.5))
]
#: Ledge Path's drops: each side of an 11-stud walkway, from z -12 to 8
LEDGE = [(sx * 11.5, -2.0, 12.0, VOID_H, 20.0) for sx in (-1, 1)]


def boulder(x, z):
    return (x, z, *BOULDER)


def post(x, z):
    return (x, z, *POST)


PEAK_COVER = [boulder(sx * 9.0, 13.0) for sx in (-1, 1)] + [boulder(sx * 9.0, -16.0) for sx in (-1, 1)]
PEAK_POSTS = [post(sx * 13.0, 8.0) for sx in (-1, 1)] + [post(sx * 13.0, -12.0) for sx in (-1, 1)]
LEDGE_COVER = [boulder(sx * 10.0, 17.0) for sx in (-1, 1)] + [boulder(sx * 10.0, -20.0) for sx in (-1, 1)]
BOSS_POSTS = [post(sx * 13.0, -19.0) for sx in (-1, 1)]

#: (arena, pieces): the area's layouts, in the order a level cycles them
LAYOUTS = [
    ("CliffsOpen", []),
    ("CliffsBridge", GAP + PEAK_COVER),
    ("CliffsLedge", LEDGE + LEDGE_COVER),
    ("CliffsBridge", GAP + PEAK_POSTS),
    ("CliffsBridge", GAP + PEAK_COVER[:2] + PEAK_POSTS[2:]),
]
ANGEL = ("CliffsOpen", [])
HEART = ("CliffsBoss", BOSS_POSTS)


def is_void(piece):
    return piece[3] <= VOID_H + 1e-9
