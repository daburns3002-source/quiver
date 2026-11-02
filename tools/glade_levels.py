"""Generate Mossy Glade 1-1..1-10's rooms into src/shared/Config/Balance.luau.

    python -I tools/glade_levels.py

The owner's level plan (2026-10-26): "i want there to be 10 levels of mossy
glade, king bloblin will not appear until the end of level 10. level 1-1
should have 10 rooms, 1-2 should have 10 rooms, 1-3 should have 15 rooms,
1-4 should have 15 rooms. 1-5 should be 20 waves in 1 room ... 1-10 should
have 25 ending in king bloblin. each level should be harder than the last."

Made the way `tools/glade_rooms.py` makes the Mossy Glade run, with its
layouts (Archero 2's habits in the glade's kit, `KitLayout`) and
`tools/thornwood_rooms.py`'s checks (light cover, every piece a body's
width from the next, clear of the start and the gate, a walk from the
start to the exit):

**Only 1-5 is waves** (owner, 2026-11-02: "i only want 1-5 to be waves
and the rest should be rooms"), which supersedes the "1-6 should have 20
waves ... 1-10 should have 25" of the plan above. The counts the owner set
are kept and read as rooms: 20, 20, 20, 20 and 25.

- 1-1..1-4: fifty rooms, 10 + 10 + 15 + 15, each level's last a fight in
  the Glade Heart (the boss room, without a boss). Counts rise through a
  level and from level to level; 1-1 brings the Brood Slime in at room 4
  and the Splitter Spitter at room 7, the later levels mix all three.
- 1-5: one clearing, its wave arena (light cover only, since waves arrive
  anywhere). Its waves' rosters are the stage's own (`Balance.Stages`,
  `fights`), so this room's roster is only its first fight's.
- 1-6..1-9: twenty rooms each, the same shape as 1-1..1-4, ending in a
  Glade Heart fight with no boss.
- 1-10: twenty-five, the last of them King Bloblin alone in the Glade
  Heart, as the Broodmother closes Thornwood.

King Bloblin (`slimeKing`) is in no other row. They are written as
`gladeLevelRooms`, after the tutorial's rooms, so their indices in
`Balance.Rooms` start at 86. Seeded, so the same rooms come out every time.
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
glade = _load("glade_rooms")

SEED = 2026_10_26_10
BEGIN = "--[[ BEGIN gladeLevelRooms"
END = "-- END gladeLevelRooms\n"
#: Written just before the rooms list, after the tutorial's.
ANCHOR = "local rooms: { RoomConfig } = {"

#: Every level in order: name, kind, how many rooms, enemies in the first
#: room, in the room before the last, and in the last.
#:
#: "rooms" ends in a Glade Heart fight with no boss; "waves" is the single
#: arena 1-5's waves are fought in, so its count is only its first fight's;
#: "boss" ends in King Bloblin alone.
#:
#: 1-6..1-10's counts are aimed at the health each asked as a wave level, so
#: that turning them into rooms does not quietly undo the flattening of
#: #441: a Waves level only fights about sixteen of its twenty waves (two
#: Valkyries and two Angels are encounters), where every room of a Rooms
#: level is a fight.
LEVELS = [
    ("1-1", "rooms", 10, 3, 5, 5),
    ("1-2", "rooms", 10, 4, 6, 6),
    ("1-3", "rooms", 15, 4, 6, 6),
    ("1-4", "rooms", 15, 5, 7, 7),
    ("1-5", "waves", 1, 5, 5, 5),
    ("1-6", "rooms", 20, 4, 5, 7),
    ("1-7", "rooms", 20, 4, 6, 7),
    ("1-8", "rooms", 20, 5, 6, 7),
    ("1-9", "rooms", 20, 5, 7, 7),
    ("1-10", "boss", 25, 5, 7, 7),
]

MIXES = [
    "meleeCharger, meleeCharger, broodSlime, spreadShooter",
    "meleeCharger, broodSlime, spreadShooter",
    "broodSlime, spreadShooter, meleeCharger",
    "meleeCharger, meleeCharger, broodSlime",
]
#: The Glade Heart's fight closing each Rooms level: Brood Slimes first.
HEART = "broodSlime, broodSlime, meleeCharger, spreadShooter"


def roster(level, n, rooms, first, last):
    """Who fights in room n (1 to rooms - 1) of a Rooms level."""
    count = first + round((last - first) * (n - 1) / max(1, rooms - 2))
    if level == "1-1":
        if n <= 3:
            return count, "meleeCharger"
        if n <= 6:
            return count, "meleeCharger, meleeCharger, broodSlime"
    return count, MIXES[n % len(MIXES)]


def layout(rng, light=False):
    for _ in range(10000):
        kind, pieces = glade.pattern(rng)
        if light and kind in ("scatter", "lane"):
            continue
        if thorn.fits(pieces) and thorn.walkable(pieces):
            return pieces
    raise SystemExit("no layout fits")


def row(name, arena, pieces, count, who, boss=False):
    assert thorn.walkable(pieces), name
    assert boss or "slimeKing" not in who, name
    return (
        "\t{\n"
        f'\t\tname = "{name}",\n'
        f'\t\tarena = "{arena}",\n'
        + thorn.obstacles_lua(pieces)
        + f"\t\tenemyCount = {count},\n"
        f"\t\troster = {{ {who} }},\n"
        "\t},\n"
    )


def main():
    rng = random.Random(SEED)
    out = [
        BEGIN + " (2026-10-26, 1-6..1-10 made rooms 2026-11-02):\n"
        "\tMossy Glade 1-1..1-10's rooms, generated by `tools/glade_levels.py`\n"
        "\t(the owner's level plan: \"10 levels of mossy glade, king bloblin\n"
        "\twill not appear until the end of level 10\", then \"i only want 1-5 to\n"
        "\tbe waves and the rest should be rooms\"). In order: 1-1's ten rooms,\n"
        "\t1-2's ten, 1-3's fifteen, 1-4's fifteen, 1-5's single wave arena,\n"
        "\t1-6..1-9's twenty each and 1-10's twenty-five. Every Rooms level\n"
        "\tends in a Glade Heart fight, and 1-10's last room is King Bloblin\n"
        "\talone. `Balance.Rooms` 86 on, after the tutorial's. Edit the\n"
        "\tscript, not these rows. ]]\n"
        "local gladeLevelRooms: { RoomConfig } = {\n"
    ]
    total = 0
    for level, kind, rooms, first, last, heart in LEVELS:
        if kind == "waves":
            out.append(row(f"Glade Clearing {level}", "GladeLogs", layout(rng, light=True),
                           first, "meleeCharger, meleeCharger, broodSlime"))
            total += 1
            continue
        for n in range(1, rooms + 1):
            if n < rooms:
                count, who = roster(level, n, rooms, first, last)
                out.append(row(f"Mossy Glade {level}", "GladeLogs", layout(rng), count, who))
            elif kind == "boss":
                out.append(row(f"Glade Heart {level}", "GladeBoss", thorn.BOSS_ARENA, 1,
                               "slimeKing", boss=True))
            else:
                out.append(row(f"Glade Heart {level}", "GladeBoss", thorn.BOSS_ARENA,
                               heart, HEART))
            total += 1
    out.append("}\n" + END)

    text = BALANCE.read_text(encoding="utf-8")
    block = "".join(out)
    if BEGIN in text:
        i = text.index(BEGIN)
        j = text.index(END, i) + len(END)
        text = text[:i] + block + text[j:]
    else:
        k = text.index(ANCHOR)
        text = text[:k] + block + "\n" + text[k:]
    BALANCE.write_text(text, encoding="utf-8", newline="\n")
    print(f"wrote {total} rooms")


if __name__ == "__main__":
    main()
