"""Generate Thornwood 2-1..2-10, the Drowned Village 3-1..3-15 and Bogheart
Caverns 4-1..4-15 into src/shared/Config/Balance.luau: their rooms between
the `BEGIN areaLevelRooms` and `END areaLevelRooms` marks, and their stages
between `BEGIN areaLevelStages` and `END areaLevelStages`.

    python -I tools/area_levels.py

The owner (2026-11-13): "the levels for each area also need to be
lengthened. there is 10 levels for area 1, there should also be 10 for area
2, 15 for 3, 15 for 4", and "bosses should be in the last room of the last
level". So each area is now a run of levels the way Mossy Glade 1-1..1-10
is (`tools/glade_levels.py`), and its boss (the Broodmother, the Old
Tollcrab, Grandmother Gulp) stands alone in the last room of its last level
and nowhere else. Every other level ends in a fight in the boss's arena,
without the boss, as each glade level ends in the Glade Heart.

The owner gave the level counts, not the rooms in each: those follow area
1's (ten-room levels first, rising to a twenty-five-room last). Every 9th
room of a block of ten is an Angel room, as the glade's are (`BLOCK` and
`ANGEL_AT`, pinned against `Balance.Waves` by `tests/MossyLevels.spec`).

Each room's layout is its area's own: Thornwood's are drawn as
`tools/thornwood_rooms.py` draws them, the Drowned Village's and Bogheart's
are the variants of their reference sheets `tools/area34_rooms.py` uses.
Rosters are each area's enemies (the Drowned Village's still Thornwood's
with the Hollow Fisherman, until its own are modelled), one mix a level,
the area's mixes in order across its levels. A room's count never falls
within a level, so neither does the health it brings (owner, 2026-11-05:
"the levels should scale difficulty per room").

Stage difficulty climbs a level at a time to the number each area was tuned
to (2026-11-13 balance review), which its last level keeps, so each boss is
met exactly as hard as before. Seeded, so the same rooms come out every time.
"""
import importlib.util
import pathlib
import random

ROOT = pathlib.Path(__file__).resolve().parents[1]
BALANCE = ROOT / "src" / "shared" / "Config" / "Balance.luau"


def _load(name):
    spec = importlib.util.spec_from_file_location(name, ROOT / "tools" / f"{name}.py")
    module = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(module)
    return module


thorn = _load("thornwood_rooms")
a34 = _load("area34_rooms")

SEED = 2026_11_13
ROOMS_BEGIN = "--[[ BEGIN areaLevelRooms"
ROOMS_END = "-- END areaLevelRooms\n"
ROOMS_ANCHOR = "local rooms: { RoomConfig } = {"
STAGES_BEGIN = "\t\t--[[ BEGIN areaLevelStages"
STAGES_END = "\t\t-- END areaLevelStages\n"
STAGES_ANCHOR = "\t} :: { StageConfig },"

BLOCK = 10
ANGEL_AT = 9

def thorn_layout(rng, light=False):
    for _ in range(10000):
        kind, pieces = thorn.pattern(rng)
        if light and kind in ("scatter", "lane"):
            continue
        if thorn.fits(pieces) and thorn.walkable(pieces):
            return "ThornHedges", pieces
    raise SystemExit("no Thornwood layout fits")


D = a34
DROWNED_LAYOUTS = [
    ("DrownedOpen", []),
    ("DrownedVillage", D.WELL + D.CRATES),
    ("DrownedVillage", D.WELL + D.RUINS),
    ("DrownedVillage", D.RUINS + D.CRATES),
    ("DrownedVillage", D.WELL + D.RUINS + D.CRATES),
]
BOGHEART_LAYOUTS = [
    ("BogheartOpen", D.MUSHROOMS),
    ("BogheartStream", D.STREAM + D.TWO_SOUTH),
    ("BogheartStream", D.STREAM + D.MUSHROOMS),
    ("BogheartStream", D.STREAM + D.TWO_NORTH),
]

#: Each area: its name in the rooms, its level prefix, its rooms per level,
#: its layouts, its boss room, its mixes (two a level, in order), and the
#: stage numbers its first level starts at and its last keeps.
AREAS = [
    {
        "key": "thorn",
        "area": "Thornwood",
        "title": "Thornwood",
        "prefix": "2",
        "rooms": [10, 10, 15, 15, 15, 15, 20, 20, 20, 25],
        "layout": lambda rng, n: thorn_layout(rng),
        "angel": lambda rng: thorn_layout(rng, light=True),
        "heart": ("Brood Clearing", "ThornBoss", thorn.BOSS_ARENA),
        "boss": ("Brood Heart", "broodmother"),
        "mixes": [
            ("brambleBoar", "brambleBoar, burrThistle"),
            ("brambleBoar, burrThistle", "brambleBoar, burrThistle, brambleSow"),
            ("brambleBoar, brambleLurker", "brambleBoar, burrThistle, brambleSow"),
            ("brambleBoar, burrThistle, brambleLurker", "brambleBoar, brambleSow, burrThistle"),
            ("brambleSow, brambleLurker, brambleBoar", "burrThistle, brambleLurker, brambleBoar, brambleSow"),
        ],
        # 1-10 is 1.46 / 1.02; the area was tuned to 1.65 / 1.05
        "health": (1.48, 1.65),
        "damage": (1.03, 1.05),
        "counts": ((2, 5), (5, 8)),
    },
    {
        "key": "drowned",
        "area": "DrownedVillage",
        "title": "Drowned Village",
        "prefix": "3",
        "rooms": [10, 10, 10, 15, 15, 15, 15, 15, 20, 20, 20, 20, 20, 20, 25],
        "layout": lambda rng, n: DROWNED_LAYOUTS[n % len(DROWNED_LAYOUTS)],
        "angel": lambda rng: ("DrownedOpen", []),
        "heart": ("Toll Clearing", "DrownedBoss", D.RUINS + D.CRATES),
        "boss": ("Toll Gate", "oldTollcrab"),
        "mixes": [
            ("brambleBoar, hollowFisherman", "burrThistle, hollowFisherman, brambleBoar"),
            ("hollowFisherman, brambleBoar, burrThistle", "brambleBoar, hollowFisherman, brambleSow"),
            ("hollowFisherman, brambleLurker, burrThistle", "brambleSow, hollowFisherman, brambleLurker"),
            ("hollowFisherman, brambleBoar, brambleLurker, burrThistle", "hollowFisherman, brambleSow, burrThistle, brambleBoar"),
        ],
        "health": (1.67, 1.85),
        "damage": (1.06, 1.1),
        "counts": ((3, 5), (5, 8)),
    },
    {
        "key": "bogheart",
        "area": "BogheartCaverns",
        "title": "Bogheart Caverns",
        "prefix": "4",
        "rooms": [10, 10, 10, 15, 15, 15, 15, 15, 20, 20, 20, 20, 20, 20, 25],
        "layout": lambda rng, n: BOGHEART_LAYOUTS[n % len(BOGHEART_LAYOUTS)],
        "angel": lambda rng: ("BogheartOpen", D.MUSHROOMS),
        "heart": ("Bogheart Clearing", "BogheartBoss", D.STREAM + D.MUSHROOMS),
        "boss": ("Bogheart Heart", "grandmotherGulp"),
        "mixes": [
            ("sporePuff", "sporePuff, glowcap"),
            ("sporePuff, glowcap", "glowcap, sporePuff, sporePuff"),
            ("shellback, sporePuff", "sporePuff, glowcap, shellback"),
            ("glowcap, shellback, sporePuff", "shellback, glowcap, sporePuff, sporePuff"),
            ("glowcap, glowcap, sporePuff, shellback", "shellback, shellback, glowcap, sporePuff"),
        ],
        "health": (1.87, 2.1),
        "damage": (1.11, 1.15),
        "counts": ((3, 5), (5, 8)),
    },
]


def lerp(a, b, t):
    return a + (b - a) * t


def row(name, arena, pieces, count, who, encounter=None):
    assert a34.walkable(pieces) if arena.startswith(("Drowned", "Bogheart")) else thorn.walkable(pieces), name
    return (
        "\t{\n"
        f'\t\tname = "{name}",\n'
        f'\t\tarena = "{arena}",\n'
        + a34.obstacles_lua(pieces)
        + f"\t\tenemyCount = {count},\n"
        f"\t\troster = {{ {who} }},\n"
        + (f'\t\tencounter = "{encounter}",\n' if encounter else "")
        + "\t},\n"
    )


def area_rooms(rng, spec):
    """The area's rooms, level by level, and each level's (name, offset, count)."""
    out, levels = [], []
    count_levels = len(spec["rooms"])
    for li, rooms in enumerate(spec["rooms"]):
        level = f"{spec['prefix']}-{li + 1}"
        t = li / (count_levels - 1)
        first = lerp(*spec["counts"][0], t)
        last = lerp(*spec["counts"][1], t)
        #: One mix a level, the area's mixes in order across its levels: a
        #: count that never falls then brings health that never falls.
        flat = [m for pair in spec["mixes"] for m in pair]
        who = flat[min(len(flat) - 1, li * len(flat) // count_levels)]
        final = li == count_levels - 1
        rows, count = [], 0
        for n in range(1, rooms + 1):
            if n < rooms and n % BLOCK == ANGEL_AT:
                arena, pieces = spec["angel"](rng)
                rows.append(row(f"{spec['title']} Angel {level}", arena, pieces, 0, "", encounter="Angel"))
            elif n < rooms:
                count = max(count, round(lerp(first, last, (n - 1) / max(1, rooms - 2))))
                arena, pieces = spec["layout"](rng, n)
                rows.append(row(f"{spec['title']} {level}", arena, pieces, count, who))
            elif final:
                name, boss = spec["boss"]
                _, arena, pieces = spec["heart"]
                rows.append(row(name, arena, pieces, 1, boss))
            else:
                name, arena, pieces = spec["heart"]
                rows.append(row(f"{name} {level}", arena, pieces, count + 1, who))
        out.append(rows)
        health = round(lerp(*spec["health"], t), 2)
        damage = round(lerp(*spec["damage"], t), 2)
        levels.append((level, sum(len(x) for x in out[:-1]), rooms, health, damage))
    return ["".join(r) for r in out], levels


def num(v):
    return f"{v:g}"


def main():
    rng = random.Random(SEED)
    rooms_block = [
        ROOMS_BEGIN + " (2026-11-13): Thornwood 2-1..2-10's, the Drowned\n"
        "     Village 3-1..3-15's and Bogheart Caverns 4-1..4-15's rooms, generated\n"
        "     by `tools/area_levels.py` (owner: \"10 for area 2, 15 for 3, 15 for 4\",\n"
        "     \"bosses should be in the last room of the last level\"). Each area's\n"
        "     levels in order; every level ends in its boss's arena, and only its\n"
        "     last level's last room holds the boss, alone. Edit the script, not\n"
        "     these rows. ]]\n"
    ]
    stages = [
        STAGES_BEGIN + " (2026-11-13): Thornwood 2-1..2-10, the Drowned\n"
        "\t\t     Village 3-1..3-15 and Bogheart Caverns 4-1..4-15, from\n"
        "\t\t     `tools/area_levels.py`. Each behind its area's portal\n"
        "\t\t     (`Config/Lobby`), opened by beating the one before; the boss only\n"
        "\t\t     in the last room of the last. Edit the script, not these. ]]\n"
    ]
    written = 0
    for spec in AREAS:
        rows, levels = area_rooms(rng, spec)
        var = f"{spec['key']}LevelRooms"
        rooms_block.append(f"local {var}: {{ RoomConfig }} = {{\n" + "".join(rows) + "}\n")
        base = f"{spec['key'].upper()}_LEVEL_BASE"
        for level, offset, count, health, damage in levels:
            stages.append(
                "\t\t{\n"
                f'\t\t\tname = "{spec["title"]} {level}",\n'
                f'\t\t\tlevel = "{level}",\n'
                '\t\t\tmode = "Rooms",\n'
                f"\t\t\trooms = roomsAfter({base} + {offset}, {count}),\n"
                f"\t\t\tenemyDamage = {num(damage)},\n"
                f"\t\t\tenemyHealth = {num(health)},\n"
                f'\t\t\tarea = "{spec["area"]}",\n'
                "\t\t},\n"
            )
            written += count
    rooms_text = "".join(rooms_block) + ROOMS_END
    stages_text = "".join(stages) + STAGES_END

    text = BALANCE.read_text(encoding="utf-8")
    if ROOMS_BEGIN in text:
        i = text.index(ROOMS_BEGIN)
        text = text[:i] + rooms_text + text[text.index(ROOMS_END, i) + len(ROOMS_END):]
    else:
        k = text.index(ROOMS_ANCHOR)
        text = text[:k] + rooms_text + "\n" + text[k:]
    if STAGES_BEGIN in text:
        i = text.index(STAGES_BEGIN)
        text = text[:i] + stages_text + text[text.index(STAGES_END, i) + len(STAGES_END):]
    else:
        k = text.index(STAGES_ANCHOR)
        text = text[:k] + stages_text + text[k:]
    BALANCE.write_text(text, encoding="utf-8", newline="\n")
    print(f"wrote {written} rooms in {sum(len(a['rooms']) for a in AREAS)} levels")


if __name__ == "__main__":
    main()
