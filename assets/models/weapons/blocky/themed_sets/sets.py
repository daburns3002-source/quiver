"""The seven themed sets after Neon Circuit, as data (docs/WEAPONS-THEMED.md).

    python -I assets/models/weapons/blocky/themed_sets/sets.py

One table of every set's weapons (key, label, class, card, effect line, glow
colour, shot or swing look), read in Studio's Edit datamodel after the
owner's import (2026-11-18) and measured from the GLBs (measure_grips.py).
Writes `skin_imports.json` beside this file for `skins_to_luau.py`, and
prints nothing else: the Luau rows (Config/WeaponStats, WeaponFx, Dex,
Shop) are written by `write_rows()` into marked blocks, so a change here is
one run, never a hand edit in four files.
"""
import json
import pathlib
import re

HERE = pathlib.Path(__file__).parent
ROOT = HERE.parents[4]

# set key, NAME, Dex page (groundTop, groundBottom, trim, plate, accent), glow colours
SETS = [
    ("Starwish", "STARWISH", ((70, 52, 96), (30, 20, 48), (255, 214, 92), (214, 74, 150), (255, 236, 160)),
     ((255, 214, 92), (255, 140, 200))),
    ("Tumbleweed", "TUMBLEWEED", ((112, 74, 44), (52, 32, 18), (240, 190, 80), (26, 128, 120), (120, 236, 220)),
     ((64, 224, 208), (240, 190, 80))),
    ("SplashDay", "SPLASH DAY", ((30, 96, 140), (10, 40, 70), (255, 214, 64), (222, 84, 76), (150, 236, 255)),
     ((80, 220, 255), (255, 120, 110))),
    ("CoinOp", "COIN-OP", ((30, 30, 52), (10, 10, 22), (255, 220, 60), (36, 78, 210), (255, 96, 96)),
     ((255, 70, 70), (70, 130, 255))),
    ("Voidglass", "VOIDGLASS", ((40, 22, 72), (12, 6, 28), (200, 170, 255), (104, 48, 190), (255, 160, 236)),
     ((180, 110, 255), (255, 140, 230))),
    ("LanternBloom", "LANTERN BLOOM", ((70, 40, 52), (30, 14, 22), (255, 200, 110), (176, 36, 48), (255, 182, 206)),
     ((255, 190, 90), (255, 150, 190))),
    ("Cinderforge", "CINDERFORGE", ((44, 36, 34), (14, 10, 10), (255, 140, 40), (150, 52, 20), (255, 210, 90)),
     ((255, 120, 30), (255, 200, 60))),
]

# set, key, LABEL, class, card, effect line, glow (0 primary, 1 second), import folder,
# Studio mesh id, colour map id, size, look (a shot's or a swing's)
WEAPONS = [
    # Starwish
    ("Starwish", "WishbrightBow", "WISHBRIGHT BOW", "Ranger", "BlastArrows",
     "Wishbright: arrows burst like shooting stars where they land.", 0,
     135592328813188, 91614727945119, (0.5098, 0.9798, 0.2758),
     {"shape": "Ball", "spin": (0, 0, 12), "sparkle": 1, "trail": 1.6}),
    ("Starwish", "DreamdropStaff", "DREAMDROP STAFF", "Arcanist", "ElementalOrbs",
     "Dreamdrop: each wish flies out as fire, ice or lightning in turn.", 1,
     126746338301669, 113073061248661, (0.3956, 0.9805, 0.1936),
     {"shape": "Ball", "bob": (0.3, 9), "sparkle": 0, "trail": 1.4}),
    ("Starwish", "WishcutterBlade", "WISHCUTTER BLADE", "Warden", "Whirlwind",
     "Wishcutter: every few swings you spin in a ring of stars.", 0,
     77646162067586, 83650970339437, (0.4563, 0.9816, 0.1478),
     {"form": "Star", "tail": 0.341, "taper": 0.4}),
    ("Starwish", "TwinkleDaggers", "TWINKLE DAGGERS", "Assassin", "SoulChain",
     "Twinkle: hits link nearby enemies like a string of stars, sharing the hurt.", 1,
     133381353315585, 116194704763654, (0.4630, 0.9814, 0.2238),
     {"form": "Star", "tail": 0.121, "taper": 0.1}),
    # Tumbleweed
    ("Tumbleweed", "SaddlehornBow", "SADDLEHORN BOW", "Ranger", "Ricochet",
     "Saddlehorn: a trick shot bounces on to the next enemy.", 0,
     93712261068900, 101987197506919, (0.5317, 0.9789, 0.1665),
     {"shape": "Block", "spin": (0, 0, 10), "sparkle": 1, "trail": 1.4}),
    ("Tumbleweed", "WagonwheelStaff", "WAGONWHEEL STAFF", "Arcanist", "ChainLightning",
     "Wagonwheel: a hit lassoes on to the next enemy.", 0,
     120857626319400, 137006257922329, (0.3876, 0.9793, 0.1374),
     {"shape": "Ball", "spin": (0, 0, 14), "sparkle": 1, "trail": 1.2}),
    ("Tumbleweed", "TrailbossBlade", "TRAILBOSS BLADE", "Warden", "BattleCry",
     "Trailboss: each kill quickens your swings, stacking.", 1,
     80154596704715, 137119121556911, (0.3825, 0.9797, 0.1315),
     {"form": "Chip", "tail": 0.342, "taper": 0.4}),
    ("Tumbleweed", "SpurDaggers", "SPUR DAGGERS", "Assassin", "Quickstep",
     "Spur: a kill spurs you on, and your dash comes back sooner.", 1,
     140311721087454, 129615841966613, (0.3321, 0.9806, 0.2418),
     {"form": "Star", "tail": 0.122, "taper": 0.1}),
    # Splash Day
    ("SplashDay", "NoodleBow", "NOODLE BOW", "Ranger", "PiercingShot",
     "Noodle: the water jet runs on through everything in line.", 0,
     87062589115071, 115404089914100, (0.4973, 0.9803, 0.2190),
     {"shape": "Ball", "wobble": (0.3, 14), "sparkle": 0, "trail": 2}),
    ("SplashDay", "SplashringStaff", "SPLASHRING STAFF", "Arcanist", "SpellPierce",
     "Splashring: the splash runs on through every enemy in line.", 0,
     104899557257644, 126649089229975, (0.3876, 0.9792, 0.1751),
     {"shape": "Ball", "wobble": (0.35, 10), "sparkle": 1, "trail": 1.6}),
    ("SplashDay", "BreakerBlade", "BREAKER BLADE", "Warden", "Shockwave",
     "Breaker: your slam sends a wave rolling forward along the ground.", 0,
     74329406799333, 85506869167256, (0.4168, 0.9817, 0.2386),
     {"form": "Ball", "tail": 0.343, "taper": 0.45}),
    ("SplashDay", "SquirtDaggers", "SQUIRT DAGGERS", "Assassin", "Sunder",
     "Squirt: a soaked enemy takes more damage from everything for 3s.", 0,
     127929929640360, 70441792722031, (0.3907, 0.9818, 0.1768),
     {"form": "Ball", "tail": 0.123, "taper": 0.1}),
    # Coin-Op
    ("CoinOp", "HighscoreBow", "HIGHSCORE BOW", "Ranger", "FrontArrow",
     "Highscore: power-up! Extra arrows fly beside the first.", 0,
     70497883513598, 90791410773927, (0.4011, 0.9783, 0.2702),
     {"shape": "Block", "sparkle": 1, "trail": 1.6}),
    ("CoinOp", "JoystickStaff", "JOYSTICK STAFF", "Arcanist", "TwinCast",
     "Joystick: two-player mode, an extra orb flies beside each one.", 1,
     114774082160561, 103519652395887, (0.2625, 0.9790, 0.2285),
     {"shape": "Block", "bob": (0.3, 9), "sparkle": 0, "trail": 1.2}),
    ("CoinOp", "PixelBlade", "PIXEL BLADE", "Warden", "CounterStrike",
     "Pixel: getting hit powers up your next swing to triple damage.", 1,
     81036173680464, 138716240575470, (0.3695, 0.9819, 0.1222),
     {"form": "Chip", "tail": 0.344, "taper": 0.4}),
    ("CoinOp", "TokenDaggers", "TOKEN DAGGERS", "Assassin", "Precision",
     "Token: a lucky coin, for more critical hits.", 0,
     109593487073132, 105499947744136, (0.3631, 0.9796, 0.2385),
     {"form": "Chip", "tail": 0.124, "taper": 0.1}),
    # Voidglass
    ("Voidglass", "OrbitBow", "ORBIT BOW", "Ranger", "RainOfArrows",
     "Orbit: every sixth shot calls a shower of falling stars onto the target.", 0,
     94734081999341, 102202300078466, (0.4340, 0.9781, 0.2836),
     {"shape": "Ball", "helix": (0.5, 14), "sparkle": 1, "trail": 1.8}),
    ("Voidglass", "StarwellStaff", "STARWELL STAFF", "Arcanist", "TrackingEye",
     "Starwell: orbs fall into orbit round the nearest enemy.", 1,
     121785432247384, 83876518973798, (0.4724, 0.9789, 0.3388),
     {"shape": "Ball", "spin": (0, 0, 8), "helix": (0.55, 15), "sparkle": 0, "trail": 2}),
    ("Voidglass", "NebulaBlade", "NEBULA BLADE", "Warden", "Parry",
     "Nebula: your swings knock enemy shots out of the air.", 0,
     102228735402808, 93712729804632, (0.3761, 0.9779, 0.3302),
     {"form": "Star", "tail": 0.345, "taper": 0.4}),
    ("Voidglass", "CometDaggers", "COMET DAGGERS", "Assassin", "RuinCracks",
     "Comet: your combo's last blow cracks what it hits, and it takes more damage for 4s.", 1,
     131831047658815, 90966274072915, (0.3542, 0.9779, 0.3375),
     {"form": "Shard", "tail": 0.125, "taper": 0.1}),
    # Lantern Bloom
    ("LanternBloom", "BlossomBow", "BLOSSOM BOW", "Ranger", "Multishot",
     "Blossom: each shot is followed by a flurry of petal arrows.", 1,
     98079111026738, 105431348845860, (0.4471, 0.9795, 0.2216),
     {"shape": "Wedge", "wobble": (0.3, 12), "sparkle": 0, "trail": 1.6}),
    ("LanternBloom", "PaperglowStaff", "PAPERGLOW STAFF", "Arcanist", "ArcaneTurret",
     "Paperglow: every ten seconds a paper lantern floats up beside you and casts orbs.", 0,
     123203878806120, 83121551068534, (0.4690, 0.9810, 0.2741),
     {"shape": "Ball", "spin": (0, 6, 0), "bob": (0.3, 8), "sparkle": 1, "trail": 1.2}),
    ("LanternBloom", "PetalfallBlade", "PETALFALL BLADE", "Warden", "Sunder",
     "Petalfall: petals settle on what you strike, and it takes more damage from everything for 3s.", 1,
     78703893865338, 139263431899652, (0.3361, 0.9821, 0.1321),
     {"form": "Leaf", "tail": 0.346, "taper": 0.4}),
    ("LanternBloom", "BellchimeDaggers", "BELLCHIME DAGGERS", "Assassin", "BoarRush",
     "Bellchime: your combo's last blow rings out and shoves everything it hits far back.", 0,
     92988602774925, 89087637842542, (0.4413, 0.9802, 0.1777),
     {"form": "Leaf", "tail": 0.126, "taper": 0.1}),
    # Cinderforge
    ("Cinderforge", "CinderstringBow", "CINDERSTRING BOW", "Ranger", "SniperShot",
     "Cinderstring: stand still and the string heats a red-hot arrow that pierces all and crits.", 0,
     93048340998656, 90939717773223, (0.4797, 0.9798, 0.2292),
     {"shape": "Wedge", "spin": (0, 0, 8), "sparkle": 1, "trail": 1.8}),
    ("Cinderforge", "ForgeheartStaff", "FORGEHEART STAFF", "Arcanist", "ManaSurge",
     "Forgeheart: a kill stokes the forge, and the next cast is bigger and harder.", 0,
     109248491458154, 101093659277750, (0.3451, 0.9780, 0.2911),
     {"shape": "Block", "wobble": (0.25, 12), "sparkle": 1, "trail": 1.4}),
    ("Cinderforge", "MoltenBlade", "MOLTEN BLADE", "Warden", "HeavyBlade",
     "Molten: your third blow lands like a hammer on an anvil.", 0,
     96189184685974, 90975304299716, (0.4137, 0.9806, 0.2146),
     {"form": "Chip", "tail": 0.347, "taper": 0.45}),
    ("Cinderforge", "EmbershardDaggers", "EMBERSHARD DAGGERS", "Assassin", "DeadlyStrike",
     "Embershard: a critical hit lands red-hot and deals more damage.", 1,
     134222445690465, 133070494226928, (0.4547, 0.9785, 0.2438),
     {"form": "Shard", "tail": 0.127, "taper": 0.1}),
]

PRICE = (5000, 300)
BEGIN = "-- THEMED SETS{} BEGIN (assets/models/weapons/blocky/themed_sets/sets.py; regenerate, never hand-edit)\n"
END = "-- THEMED SETS{} END\n"


def colours(set_key):
    return next(s[3] for s in SETS if s[0] == set_key)


def rgb(c):
    return f"rgb({c[0]}, {c[1]}, {c[2]})"


def c3(c):
    return f"Color3.fromRGB({c[0]}, {c[1]}, {c[2]})"


def lighter(c, by=0.45):
    return tuple(int(v + (255 - v) * by) for v in c)


def splice(path, block, anchor, indent, tag=""):
    text = path.read_text(encoding="utf-8")
    begin, end = indent + BEGIN.format(tag), indent + END.format(tag)
    if begin in text:
        a = text.index(begin)
        b = text.index(end, a) + len(end)
        text = text[:a] + begin + block + end + text[b:]
    else:
        i = text.index(anchor)
        text = text[:i] + begin + block + end + text[i:]
    path.write_text(text, encoding="utf-8", newline="\n")


def imports():
    out = {}
    for _, key, _, _, _, _, _, mesh, colour, size, _ in WEAPONS:
        part = {"at": [0, 0, 0], "meshId": f"rbxassetid://{mesh}", "name": "Blade", "size": list(size),
                "textureId": f"rbxassetid://{colour}"}
        out[key] = {"parts": [part], "size": list(size)}
    (HERE / "skin_imports.json").write_text(json.dumps(out, indent=1) + "\n", encoding="utf-8")


def write_rows():
    config = ROOT / "src" / "shared" / "Config"
    # Config/WeaponStats
    stats = ""
    for set_key, key, _, _, card, effect, *_ in WEAPONS:
        stats += (f"\t\t{key} = {{\n\t\t\trarity = \"Legendary\",\n\t\t\tarea = 1,\n\t\t\tset = \"{set_key}\",\n"
                  f"\t\t\tinnate = {{ {card} = 1 }},\n\t\t\teffect = \"{effect}\",\n\t\t}},\n")
    splice(config / "WeaponStats.luau", stats, "\t} :: { [string]: Stats },\n}", "\t\t")
    # Config/WeaponFx: shots for bows and staffs, swings for blades and daggers
    shots, cleaves = "", ""
    for set_key, key, _, cls, _, _, glow, _, _, _, look in WEAPONS:
        main, other = colours(set_key)[glow], colours(set_key)[1 - glow]
        if cls in ("Ranger", "Arcanist"):
            lines = [f"\t{key} = shot({{", f"\t\tcolour = {rgb(main)},", f"\t\tshape = \"{look['shape']}\","]
            if "spin" in look:
                lines.append(f"\t\tspin = Vector3.new({look['spin'][0]}, {look['spin'][1]}, {look['spin'][2]}),")
            for motion in ("helix", "wobble", "bob"):
                if motion in look:
                    lines.append(f"\t\t{motion} = {{ amount = {look[motion][0]}, rate = {look[motion][1]} }},")
            sparkle = other if look["sparkle"] else lighter(main)
            lines.append(f"\t\tsparkle = sparkle({rgb(sparkle)}, 0.3, 1),")
            lines.append(f"\t\ttrail = {look['trail']},")
            lines.append("\t}),")
            shots += "\n".join(lines) + "\n"
        else:
            dagger = cls == "Assassin"
            cleaves += (f"\t{key} = {{\n\t\tcolour = {{ {rgb(main)}, {rgb(other)} }},\n\t\ttail = {look['tail']},\n"
                        f"\t\ttaper = {look['taper']},\n\t\tmotes = {{\n\t\t\tform = \"{look['form']}\",\n"
                        f"\t\t\tcolour = {rgb(lighter(main, 0.3))},\n\t\t\trate = {32 if dagger else 34},\n"
                        f"\t\t\tsize = {0.38 if dagger else 0.45},\n\t\t\trise = {2 if dagger else 1.6},\n"
                        f"\t\t\tlife = {0.45 if dagger else 0.5},\n\t\t}},\n\t}},\n")
    fx = config / "WeaponFx.luau"
    # the shots' table ends just before `local cleaves`; the swings' just before the return
    splice(fx, shots, "}\n\nlocal cleaves", "\t", " SHOTS")
    splice(fx, cleaves, "}\n\nreturn table.freeze({", "\t", " SWINGS")
    # Config/Dex: a page look a set
    dex = ""
    for set_key, name, (top, bottom, trim, plate, accent), _ in SETS:
        dex += (f"\t\t{set_key} = {{\n\t\t\tname = \"{name}\",\n\t\t\tgroundTop = {c3(top)},\n"
                f"\t\t\tgroundBottom = {c3(bottom)},\n\t\t\ttrim = {c3(trim)},\n\t\t\tplate = {c3(plate)},\n"
                f"\t\t\taccent = {c3(accent)},\n\t\t\tscene = {{ x = 0, y = 0, w = 0, h = 0 }},\n\t\t}},\n")
    splice(config / "Dex.luau", dex, "\t} :: { [string]: AreaTheme },\n\t--[[ An area with no look", "\t\t")
    # Config/Shop: the sets, stocked
    shop = "".join(
        f"\t\t{{ key = \"{k}\", name = \"{n}\", coins = {PRICE[0]}, gems = {PRICE[1]}, stocked = true }},\n"
        for k, n, *_ in SETS)
    splice(config / "Shop.luau", shop, "\t} :: { Set },", "\t\t")


def main():
    imports()
    write_rows()
    print(len(WEAPONS), "weapons in", len(SETS), "sets")


if __name__ == "__main__":
    main()
