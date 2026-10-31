"""Write the area 1 weapon skins into Config/Weapons and the sandbox menu.

    python -I skins_to_luau.py

Reads blocky/forest/skin_imports.json (each import's parts, dumped from
Studio after the owner imported `Downloads\\area1_weapons_import`: mesh id,
size and centre in the model's bounding box) and replaces the block between
the SKINS markers in src/shared/Config/Weapons.luau and in
src/shared/Config/Sandbox.luau. Regenerate after a re-import; never
hand-edit the block.

Each skin is held like its class's base weapon: turned 180 degrees about Y
to the base weapons' frame (the skins' strings sit on +Z, the Twig Bow's on
-Z), sized to the base weapon's length, gripped where the base weapon is (a
bow at its middle, a staff 43% up, a blade at its hilt, 25% up), and played
with the base weapon's animations (`kit`) until it has its own kit.
"""
import json
import pathlib
import re

HERE = pathlib.Path(__file__).parent
ROOT = HERE.parents[2]
IMPORTS = HERE / "blocky" / "forest" / "skin_imports.json"
DROWNED_IMPORTS = HERE / "blocky" / "drowned" / "skin_imports.json"
WEAPONS = ROOT / "src" / "shared" / "Config" / "Weapons.luau"
SANDBOX = ROOT / "src" / "shared" / "Config" / "Sandbox.luau"
BEGIN = "-- SKINS BEGIN (assets/models/weapons/skins_to_luau.py; regenerate, never hand-edit)\n"
END = "-- SKINS END\n"

# class: base weapon, its scale, its length in model units, where the grip is
# up that length (0 bottom, 1 top), and the hand
BASES = {
    "Ranger": {"base": "TwigBow", "scale": 3.6, "length": 1.18, "grip": 0.5},
    "Arcanist": {"base": "BranchStaff", "scale": 3.3, "length": 1.36, "grip": 0.43},
    "Warden": {"base": "TimberBlade", "scale": 3.8, "length": 1.26, "grip": 0.254},
}
# key, label, class, import, projectile import (or None), glow colour (or None)
SKINS = [
    ("AcornBow", "ACORN BOW", "Ranger", "bow_1uncommon_acorn_bow", "bow_1uncommon_acorn_arrow", None),
    ("FireflyBow", "FIREFLY BOW", "Ranger", "bow_2rare_firefly_bow", "bow_2rare_firefly_dart", (249, 227, 109)),
    ("MossSlimeBow", "MOSS SLIME BOW", "Ranger", "bow_3epic_moss_slime_bow", "bow_3epic_moss_slime_arrow", (215, 230, 83)),
    ("EmberFangBow", "EMBER FANG BOW", "Ranger", "bow_4legendary_ember_fang_bow", "bow_4legendary_ember_fang_arrow", (254, 212, 61)),
    ("GladeSpiritBow", "GLADE SPIRIT BOW", "Ranger", "bow_5mythic_glade_spirit_bow", "bow_5mythic_glade_spirit_arrow", None),
    ("ToadstoolStaff", "TOADSTOOL STAFF", "Arcanist", "staff_1uncommon_toadstool_staff", "staff_1uncommon_toadstool_bolt", None),
    ("LanternStaff", "LANTERN STAFF", "Arcanist", "staff_2rare_lantern_staff", "staff_2rare_lantern_staff_bolt", None),
    ("HootmossStaff", "HOOTMOSS STAFF", "Arcanist", "staff_3epic_hootmoss_staff", "staff_3epic_hootmoss_staff_bolt", (230, 173, 207)),
    ("SlimeCrownStaff", "SLIME CROWN STAFF", "Arcanist", "staff_4legendary_slime_crown_staff", "staff_4legendary_slime_crown_staff_bolt", (230, 254, 205)),
    ("WorldrootStaff", "WORLDROOT STAFF", "Arcanist", "staff_5mythic_worldroot_staff", "staff_5mythic_worldroot_staff_bolt", (33, 244, 254)),
    ("MossstoneBlade", "MOSSSTONE BLADE", "Warden", "blade_1uncommon_mossstone_blade", None, None),
    ("ThornBlade", "THORN BLADE", "Warden", "blade_2rare_thorn_blade", None, (191, 21, 46)),
    ("BroodsplitBlade", "BROODSPLIT BLADE", "Warden", "blade_3epic_broodsplit_blade", None, (123, 239, 73)),
    ("EmberfangBlade", "EMBERFANG BLADE", "Warden", "blade_4legendary_emberfang_blade", None, (253, 127, 53)),
    ("GladeheartBlade", "GLADEHEART BLADE", "Warden", "blade_5mythic_gladeheart_blade", None, (222, 190, 243)),
]
# Area 3, the Drowned Village. Tripo imports, so the name carries no tier and
# each states it (docs/WEAPONS-DROWNED.md, read off Codex's sheets). Four of
# the fourteen designed are not in Studio yet: Buoy, Eventide, Maelstrom and
# Stormglass. No projectiles imported, so none has a bolt.
# key, label, class, import, projectile, glow colour, tier
DROWNED = [
    ("ReedStaff", "REED STAFF", "Arcanist", "reed staff arena 3", None, None, 1),
    ("TidewoodBlade", "TIDEWOOD BLADE", "Warden", "tidewood blade arena 3", None, None, 1),
    ("SlatefinBow", "SLATEFIN BOW", "Ranger", "slatefin bow arena 3", None, None, 2),
    ("TidehookBlade", "TIDEHOOK BLADE", "Warden", "tidehook blade arena 3", None, None, 2),
    ("EelcrestBow", "EELCREST BOW", "Ranger", "eelcrest bow arena 3", None, None, 3),
    ("WellpearlStaff", "WELLPEARL STAFF", "Arcanist", "wellpearl staff arena 3", None, None, 3),
    ("CausewayBlade", "CAUSEWAY BLADE", "Warden", "causeway blade arena 3", None, None, 3),
    ("TollstringBow", "TOLLSTRING BOW", "Ranger", "tollstring bow arena 3", None, None, 4),
    ("TollkeeperStaff", "TOLLKEEPER STAFF", "Arcanist", "tollkeeper staff arena 3", None, None, 4),
    # `sunken bell sword arena 3` is the Tollguard Blade under its working
    # name (owner, 2026-10-30).
    ("TollguardBlade", "TOLLGUARD BLADE", "Warden", "sunken bell sword arena 3", None, None, 4),
    ("BuoyStaff", "BUOY STAFF", "Arcanist", "buoy staff arena 3", None, None, 2),
    ("EventideBow", "EVENTIDE BOW", "Ranger", "eventide bow arena 3", None, None, 5),
    ("MaelstromStaff", "MAELSTROM STAFF", "Arcanist", "maelstrom staff arena 3", None, None, 5),
    ("StormglassBlade", "STORMGLASS BLADE", "Warden", "stormglass blade arena 3", None, None, 5),
]
# Radians of extra turn about Y for models that do not follow the base
# weapon's convention. A bow's limbs should curve in YZ as the Twig Bow's do;
# these three are modelled curving in XY, so they face sideways without it.
# Verified against each import's bounding box: X wider than Z means XY.
YAW = {
    "EelcrestBow": "math.pi / 2",
    "TollstringBow": "math.pi / 2",
    "EventideBow": "math.pi / 2",
}
GLOWS = ("Gems", "Glow")
# Epics and up always glow (owner, 2026-10-24); one with no colour of its own
# glows white, and a Mythic cycles its glow through the rainbow (Fx/WeaponGlow).
WHITE = (255, 255, 255)


def rarity(name: str) -> int:
    """1 (uncommon) to 5 (mythic), from the import's name: `bow_5mythic_...`."""
    return int(name.split("_")[1][0])


def num(v: float) -> str:
    s = f"{v:.4f}".rstrip("0").rstrip(".")
    return "0" if s in ("-0", "") else s


def vec(v) -> str:
    return f"Vector3.new({num(v[0])}, {num(v[1])}, {num(v[2])})"


def rgb(c) -> str:
    return f"Color3.fromRGB({c[0]}, {c[1]}, {c[2]})"


def entry(imports, key, cls, name, projectile, glow, tier=None) -> str:
    base = BASES[cls]
    model = imports[name]
    tier = tier if tier is not None else rarity(name)
    if tier >= 3 and not glow:
        glow = WHITE
    length = model["size"][1]
    # the grip, up the length from the bottom, in the model's centred frame
    grip_y = -length / 2 + length * base["grip"]
    scale = base["scale"] * base["length"] / length
    out = [f"\t{key} = {{"]
    out.append(f"\t\t-- `{name}`, held as the {base['base']} is, playing its kit until it has its own")
    out.append(f'\t\tkit = "{base["base"]}",')
    out.append(f"\t\tskinOf = \"{base['base']}\",")
    out.append(f"\t\tscale = {num(scale)},")
    out.append("\t\tparts = {")
    for part in model["parts"]:
        at = part["at"]
        # turned 180 degrees about Y to the base weapons' frame
        offset = (-at[0], at[1] - grip_y, -at[2])
        out.append("\t\t\t{")
        out.append(f'\t\t\t\tname = "{part["name"]}",')
        out.append(f'\t\t\t\tmeshId = "{part["meshId"]}",')
        out.append(f"\t\t\t\tsize = {vec(part['size'])},")
        out.append(f"\t\t\t\toffset = {vec(offset)},")
        out.append("\t\t\t\tturned = true,")
        if YAW.get(key):
            out.append(f"\t\t\t\tyaw = {YAW[key]},")
        # A Tripo model carries its colours in a texture, not its vertices.
        if part.get("textureId"):
            out.append(f'\t\t\t\ttextureId = "{part["textureId"]}",')
        if part["name"] in GLOWS and glow:
            out.append("\t\t\t\tglow = true,")
            out.append(f"\t\t\t\tcolour = {rgb(glow)},")
        out.append("\t\t\t},")
    out.append("\t\t} :: { WeaponPart },")
    if tier == 5:
        out.append("\t\trainbow = true,")
    # Legendary and Mythic shots glow too (owner, 2026-10-25), in the
    # weapon's glow colour; a Mythic's turns round the rainbow.
    if tier >= 4 and projectile:
        out.append(f"\t\tshotGlow = {rgb(glow)},")
    # and a Legendary or Mythic blade's swing glows the same way
    if tier >= 4 and cls == "Warden":
        out.append(f"\t\ttrailGlow = {rgb(glow)},")
    if projectile:
        shot = imports[projectile]
        main = next((p for p in shot["parts"] if p["name"] in ("Bolt", "Glow", "Arrow")), shot["parts"][0])
        out.append("\t\tbolt = {")
        out.append(f'\t\t\tmeshId = "{main["meshId"]}",')
        out.append(f"\t\t\tsize = {vec(main['size'])},")
        out.append("\t\t},")
    out.append("\t},")
    return "\n".join(out)


def splice(path: pathlib.Path, block: str, anchor: str):
    text = path.read_text(encoding="utf-8")
    if BEGIN in text:
        a = text.index(BEGIN)
        b = text.index(END, a) + len(END)
        head = text[:a]
        indent = head[head.rfind(chr(10)) + 1 :]
        text = text[:a] + BEGIN + block + indent + END + text[b:]
    else:
        i = text.index(anchor)
        text = text[:i] + BEGIN + block + END + text[i:]
    path.write_text(text, encoding="utf-8", newline="\n")


def main():
    imports = json.loads(IMPORTS.read_text(encoding="utf-8"))
    drowned = json.loads(DROWNED_IMPORTS.read_text(encoding="utf-8"))
    rows = [(imports, k, c, n, p, g, None) for k, _, c, n, p, g in SKINS]
    rows += [(drowned, k, c, n, p, g, t) for k, _, c, n, p, g, t in DROWNED]
    skins = chr(10).join(entry(*r) for r in rows) + chr(10)
    splice(WEAPONS, skins, "\t--[[ SKINS GO HERE ]]\n")
    menu = "".join(f'\t\t{{ weapon = "{k}", class = "{c}", label = "{l}" }},\n' for k, l, c, *_ in SKINS + DROWNED)
    splice(SANDBOX, menu, "\t\t--[[ SKINS GO HERE ]]\n")
    print(f"wrote {len(rows)} skins")


if __name__ == "__main__":
    main()
