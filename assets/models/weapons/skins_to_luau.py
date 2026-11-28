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
import math
import pathlib
import re

HERE = pathlib.Path(__file__).parent
ROOT = HERE.parents[2]
IMPORTS = HERE / "blocky" / "forest" / "skin_imports.json"
DROWNED_IMPORTS = HERE / "blocky" / "drowned" / "skin_imports.json"
BOGHEART_IMPORTS = HERE / "blocky" / "bogheart" / "skin_imports.json"
GOLDEN_IMPORTS = HERE / "blocky" / "golden" / "skin_imports.json"
DAGGER_IMPORTS = HERE / "blocky" / "daggers" / "skin_imports.json"
DAGGER_GRIPS = HERE / "blocky" / "daggers" / "grips.json"
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
    # the Splinter Daggers: a dagger 0.5444 long at scale 3.5, about 1.9 studs
    "Assassin": {"base": "SplinterDaggers", "scale": 3.5, "length": 0.5444, "grip": 0.2},
}
# classes whose weapon swings: a Legendary's or Mythic's glow goes on the
# swing's trail, not on a shot
MELEE = ("Warden", "Assassin")
# key, label, class, import, projectile import (or None), glow colour (or None)
SKINS = [
    ("AcornBow", "ACORN BOW", "Ranger", "bow_1uncommon_acorn_bow", "bow_1uncommon_acorn_arrow", None),
    ("FireflyBow", "FIREFLY BOW", "Ranger", "bow_2rare_firefly_bow", "bow_2rare_firefly_dart", (249, 227, 109)),
    ("MossSlimeBow", "MOSS SLIME BOW", "Ranger", "bow_3epic_moss_slime_bow", "bow_3epic_moss_slime_arrow", (215, 230, 83)),
    ("EmberFangBow", "EMBER FANG BOW", "Ranger", "bow_4legendary_ember_fang_bow", "bow_4legendary_ember_fang_arrow", (254, 212, 61)),
    ("GladeSpiritBow", "GLADE SPIRIT BOW", "Ranger", "bow_5mythic_glade_spirit_bow", "bow_5mythic_glade_spirit_arrow", (150, 255, 170)),
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
    ("TollstringBow", "TOLLSTRING BOW", "Ranger", "tollstring bow arena 3", None, (70, 220, 200), 4),
    ("TollkeeperStaff", "TOLLKEEPER STAFF", "Arcanist", "tollkeeper staff arena 3", None, (70, 220, 200), 4),
    # `sunken bell sword arena 3` is the Tollguard Blade under its working
    # name (owner, 2026-10-30).
    ("TollguardBlade", "TOLLGUARD BLADE", "Warden", "sunken bell sword arena 3", None, (70, 220, 200), 4),
    ("BuoyStaff", "BUOY STAFF", "Arcanist", "buoy staff arena 3", None, None, 2),
    ("EventideBow", "EVENTIDE BOW", "Ranger", "eventide bow arena 3", None, (90, 240, 225), 5),
    ("MaelstromStaff", "MAELSTROM STAFF", "Arcanist", "maelstrom staff arena 3", None, (90, 240, 225), 5),
    ("StormglassBlade", "STORMGLASS BLADE", "Warden", "stormglass blade arena 3", None, (90, 240, 225), 5),
]
# Area 4, Bogheart Caverns (docs/WEAPONS-BOGHEART.md): the low-poly Tripo
# set imported 2026-11-06 (Workspace/TripoImports/Weapons, each one MeshPart
# whose SurfaceAppearance colour map is its textureId). The five daggers wait
# for the Assassin class. A Legendary's or Mythic's glow is an `aura` (one
# textured mesh has no gem to draw Neon), and a Mythic need not be rainbow
# (owner, 2026-11-06), so none of these is.
# key, label, class, import, projectile, glow colour, tier
BOGHEART = [
    ("PeatwoodBow", "PEATWOOD BOW", "Ranger", "PeatwoodBow", None, None, 1),
    ("SporestringBow", "SPORESTRING BOW", "Ranger", "SporestringBow", None, None, 2),
    ("GlowcapLongbow", "GLOWCAP LONGBOW", "Ranger", "GlowcapLongbow", None, None, 3),
    ("GulpstringBow", "GULPSTRING BOW", "Ranger", "GulpstringBow", None, (233, 185, 46), 4),
    ("LumenveilBow", "LUMENVEIL BOW", "Ranger", "LumenveilBow", None, (63, 230, 242), 5),
    ("LichenStaff", "LICHEN STAFF", "Arcanist", "LichenStaff", None, None, 1),
    ("PuffballStaff", "PUFFBALL STAFF", "Arcanist", "PuffballStaff", None, None, 2),
    ("VentstoneStaff", "VENTSTONE STAFF", "Arcanist", "VentstoneStaff", None, None, 3),
    ("GrandmothersStaff", "GRANDMOTHER'S STAFF", "Arcanist", "GrandmothersStaff", None, (77, 232, 200), 4),
    ("MyceliadStaff", "MYCELIAD STAFF", "Arcanist", "MyceliadStaff", None, (63, 230, 242), 5),
    ("BogironBlade", "BOGIRON BLADE", "Warden", "BogironBlade", None, None, 1),
    ("ShellbackCleaver", "SHELLBACK CLEAVER", "Warden", "ShellbackCleaver", None, None, 2),
    ("CaplightBlade", "CAPLIGHT BLADE", "Warden", "CaplightBlade", None, None, 3),
    ("GulpfangBlade", "GULPFANG BLADE", "Warden", "GulpfangBlade", None, (154, 205, 60), 4),
    ("DeepglowBlade", "DEEPGLOW BLADE", "Warden", "DeepglowBlade", None, (63, 230, 242), 5),
]
# The golden weapons (owner, 2026-11-14; Config/ClassLevels): a class's level
# 10, Legendary strength. Tripo models from the Codex front views in
# assets/concepts/blocky/weapons/skins/golden, one textured mesh each, so
# the gold glow is an `aura`. Imported by the owner 2026-11-14 as
# `gold_golden_bow_8k_clean`, `gold_golden_staff` and `gold_golden_blade`
# (Workspace), dumped to blocky/golden/skin_imports.json under their keys.
# key, label, class, import, projectile, glow colour, tier
GOLDEN = [
    ("GoldenBow", "GOLDEN BOW", "Ranger", "GoldenBow", None, (255, 205, 56), 4),
    ("GoldenStaff", "GOLDEN STAFF", "Arcanist", "GoldenStaff", None, (255, 214, 84), 4),
    ("GoldenBlade", "GOLDEN BLADE", "Warden", "GoldenBlade", None, (255, 198, 44), 4),
]
# The Assassin's daggers (owner, 2026-11-16 and 17): 21 skins of the Splinter
# Daggers, every one a Tripo model of ONE dagger (4,000 triangles, 8K
# texture), held in each hand (`Config/Weapons` copies the base's
# `offhand`). Imported by the owner 2026-11-17 from
# `Downloads\\assassin_daggers_import`, read in Studio into
# blocky/daggers/skin_imports.json (write_skin_imports.py) under their keys;
# grips measured from the GLBs into blocky/daggers/grips.json
# (measure_grips.py). One textured mesh each, so a Legendary's or Mythic's
# glow is an `aura`, and none is rainbow. Areas: Mossy Glade (1), Thornwood
# (2), the Drowned Village (3), Bogheart Caverns (4), and the Golden Daggers
# of class level 10.
# key, label, class, import, projectile, glow colour, tier
DAGGERS = [
    ("BrambleShivs", "BRAMBLE SHIVS", "Assassin", "BrambleShivs", None, None, 1),
    ("FireflyFangs", "FIREFLY FANGS", "Assassin", "FireflyFangs", None, None, 2),
    ("GladeFoxClaws", "GLADE FOX CLAWS", "Assassin", "GladeFoxClaws", None, None, 3),
    ("EmberWilfFangs", "EMBER WILF FANGS", "Assassin", "EmberWilfFangs", None, (255, 140, 40), 4),
    ("GlimmerhornDaggers", "GLIMMERHORN DAGGERS", "Assassin", "GlimmerhornDaggers", None, (235, 170, 255), 5),
    ("HedgePrickers", "HEDGE PRICKERS", "Assassin", "HedgePrickers", None, None, 1),
    ("TuskKnives", "TUSK KNIVES", "Assassin", "TuskKnives", None, None, 2),
    ("BurrfangDaggers", "BURRFANG DAGGERS", "Assassin", "BurrfangDaggers", None, None, 3),
    ("SilkfangDaggers", "SILKFANG DAGGERS", "Assassin", "SilkfangDaggers", None, (230, 60, 200), 4),
    ("LurkerClaws", "LURKER CLAWS", "Assassin", "LurkerClaws", None, (255, 70, 210), 5),
    ("DriftwoodDirks", "DRIFTWOOD DIRKS", "Assassin", "DriftwoodDirks", None, None, 1),
    ("BarnacleKnives", "BARNACLE KNIVES", "Assassin", "BarnacleKnives", None, None, 2),
    ("EeltoothDaggers", "EELTOOTH DAGGERS", "Assassin", "EeltoothDaggers", None, None, 3),
    ("TollbellDaggers", "TOLLBELL DAGGERS", "Assassin", "TollbellDaggers", None, (70, 220, 200), 4),
    ("RiptideFangs", "RIPTIDE FANGS", "Assassin", "RiptideFangs", None, (90, 240, 225), 5),
    ("MossShivs", "MOSS SHIVS", "Assassin", "MossShivs", None, None, 1),
    ("SporeFangs", "SPORE FANGS", "Assassin", "SporeFangs", None, None, 2),
    ("GlowcapKris", "GLOWCAP KRIS", "Assassin", "GlowcapKris", None, None, 3),
    ("ToadtongueDaggers", "TOADTONGUE DAGGERS", "Assassin", "ToadtongueDaggers", None, (245, 120, 160), 4),
    ("PrismStingers", "PRISM STINGERS", "Assassin", "PrismStingers", None, (63, 230, 242), 5),
    ("GoldenDaggers", "GOLDEN DAGGERS", "Assassin", "GoldenDaggers", None, (255, 205, 56), 4),
]
# Area 2, Thornwood (docs/WEAPONS-THORNWOOD.md): the five bows, staffs and
# blades, Tripo models (4,000 triangles, 8K texture, PR #625) of the Codex
# front views, one textured mesh each. Uploaded 2026-11-27 through Open
# Cloud from `Downloads\\thornwood_weapons_import` and read in Studio into
# blocky/thornwood/skin_imports.json (write_skin_imports.py); grips and the
# bows' risers measured from the GLBs (themed_sets/measure_grips.py) and
# turned into the meshes' axes (GLB x and z negated). A
# Legendary's or Mythic's glow is an `aura`: silk magenta for the three
# Legendaries, and each Mythic its own (none rainbow).
THORNWOOD_IMPORTS = HERE / "blocky" / "thornwood" / "skin_imports.json"
# key, label, class, import, projectile, glow colour, tier
THORNWOOD = [
    ("BoarTuskBow", "BOAR TUSK BOW", "Ranger", "BoarTuskBow", None, None, 1),
    ("PlumBurrBow", "PLUM BURR BOW", "Ranger", "PlumBurrBow", None, None, 2),
    ("LurkerVineBow", "LURKER VINE BOW", "Ranger", "LurkerVineBow", None, None, 3),
    ("SilkweaverBow", "SILKWEAVER BOW", "Ranger", "SilkweaverBow", None, (236, 82, 214), 4),
    ("NightbarbBow", "NIGHTBARB BOW", "Ranger", "NightbarbBow", None, (255, 86, 70), 5),
    ("HedgeBulbStaff", "HEDGE BULB STAFF", "Arcanist", "HedgeBulbStaff", None, None, 1),
    ("BurrTotemStaff", "BURR TOTEM STAFF", "Arcanist", "BurrTotemStaff", None, None, 2),
    ("LurkerCrestStaff", "LURKER CREST STAFF", "Arcanist", "LurkerCrestStaff", None, None, 3),
    ("SilkDiademStaff", "SILK DIADEM STAFF", "Arcanist", "SilkDiademStaff", None, (236, 70, 198), 4),
    ("BlackspineStaff", "BLACKSPINE STAFF", "Arcanist", "BlackspineStaff", None, (152, 92, 255), 5),
    ("BoarbackBlade", "BOARBACK BLADE", "Warden", "BoarbackBlade", None, None, 1),
    ("PlumguardBlade", "PLUMGUARD BLADE", "Warden", "PlumguardBlade", None, None, 2),
    ("BurrcrestBlade", "BURRCREST BLADE", "Warden", "BurrcrestBlade", None, None, 3),
    ("SilkboundBlade", "SILKBOUND BLADE", "Warden", "SilkboundBlade", None, (236, 90, 230), 4),
    ("BriarbreakerBlade", "BRIARBREAKER BLADE", "Warden", "BriarbreakerBlade", None, (255, 170, 40), 5),
]
# Themed sets (docs/WEAPONS-THEMED.md): a weapon for every class, of no area.
# Neon Circuit (owner, 2026-11-18): Tripo models of the Codex front views in
# assets/concepts/blocky/weapons/skins/sets/neon_circuit, imported by the
# owner from `Downloads\\neon_circuit_import` and read in Studio into
# blocky/neon_circuit/skin_imports.json. One textured mesh each, so the
# Legendary glow is an `aura`, cyan or magenta as the weapon's strips are.
NEON_CIRCUIT_IMPORTS = HERE / "blocky" / "neon_circuit" / "skin_imports.json"
# key, label, class, import, projectile, glow colour, tier
NEON_CIRCUIT = [
    ("LivewireBow", "LIVEWIRE BOW", "Ranger", "LivewireBow", None, (70, 232, 255), 4),
    ("MainframeStaff", "MAINFRAME STAFF", "Arcanist", "MainframeStaff", None, (255, 62, 196), 4),
    ("OverclockBlade", "OVERCLOCK BLADE", "Warden", "OverclockBlade", None, (70, 232, 255), 4),
    ("GlitchDaggers", "GLITCH DAGGERS", "Assassin", "GlitchDaggers", None, (255, 62, 196), 4),
]
# The seven sets after it (owner, 2026-11-18: "make the designs for all first"):
# Starwish, Tumbleweed, Splash Day, Coin-Op, Voidglass, Lantern Bloom and
# Cinderforge, 28 Legendaries listed in blocky/themed_sets/sets.py with their
# Studio ids (its skin_imports.json), cards and glow colours.
THEMED_IMPORTS = HERE / "blocky" / "themed_sets" / "skin_imports.json"
# Area 5, the Windswept Cliffs (docs/WINDSWEPT-CLIFFS.md, 2026-11-26): Tripo
# models of the Codex front views in
# assets/concepts/blocky/weapons/skins/windswept, imported from
# `Downloads\windswept_import` and read in Studio into
# blocky/windswept/skin_imports.json under their keys. One textured mesh each,
# so a Legendary's or Mythic's glow is an `aura`; none is rainbow. Grips and
# the bows' turns measured by blocky/windswept/measure_grips.py.
WINDSWEPT_IMPORTS = HERE / "blocky" / "windswept" / "skin_imports.json"
# key, label, class, import, projectile, glow colour, tier
WINDSWEPT = [
    ("SlatewoodBow", "SLATEWOOD BOW", "Ranger", "SlatewoodBow", None, None, 1),
    ("HarpyBow", "HARPY BOW", "Ranger", "HarpyBow", None, None, 2),
    ("GalestringLongbow", "GALESTRING LONGBOW", "Ranger", "GalestringLongbow", None, None, 3),
    ("RocsWingBow", "ROC'S WING BOW", "Ranger", "RocsWingBow", None, (255, 205, 56), 4),
    ("SkyrenderBow", "SKYRENDER BOW", "Ranger", "SkyrenderBow", None, (255, 236, 96), 5),
    ("CloudspunStaff", "CLOUDSPUN STAFF", "Arcanist", "CloudspunStaff", None, None, 1),
    ("GustcallerStaff", "GUSTCALLER STAFF", "Arcanist", "GustcallerStaff", None, None, 2),
    ("PrayerflagStaff", "PRAYERFLAG STAFF", "Arcanist", "PrayerflagStaff", None, None, 3),
    ("TempestStaff", "TEMPEST STAFF", "Arcanist", "TempestStaff", None, (255, 205, 56), 4),
    ("EyeOfTheStorm", "EYE OF THE STORM", "Arcanist", "EyeOfTheStorm", None, (150, 230, 255), 5),
    ("LedgestoneBlade", "LEDGESTONE BLADE", "Warden", "LedgestoneBlade", None, None, 1),
    ("RamhornCleaver", "RAMHORN CLEAVER", "Warden", "RamhornCleaver", None, None, 2),
    ("WindcutterBlade", "WINDCUTTER BLADE", "Warden", "WindcutterBlade", None, None, 3),
    ("StormtalonBlade", "STORMTALON BLADE", "Warden", "StormtalonBlade", None, (255, 205, 56), 4),
    ("ThunderheadBlade", "THUNDERHEAD BLADE", "Warden", "ThunderheadBlade", None, (255, 236, 96), 5),
    ("FlintTalon", "FLINT TALON", "Assassin", "FlintTalon", None, None, 1),
    ("HarpyClaw", "HARPY CLAW", "Assassin", "HarpyClaw", None, None, 2),
    ("StormQuill", "STORM QUILL", "Assassin", "StormQuill", None, None, 3),
    ("ThunderbeakDagger", "THUNDERBEAK DAGGER", "Assassin", "ThunderbeakDagger", None, (255, 205, 56), 4),
    ("ZephyrFang", "ZEPHYR FANG", "Assassin", "ZephyrFang", None, (150, 240, 255), 5),
]


def themed_rows():
    """(key, label, class, import, projectile, glow colour, tier) for every set weapon in sets.py."""
    import importlib.util

    spec = importlib.util.spec_from_file_location("sets", HERE / "blocky" / "themed_sets" / "sets.py")
    sets = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(sets)
    return [(key, label, cls, key, None, sets.colours(s)[glow], 4) for s, key, label, cls, _, _, glow, *_ in sets.WEAPONS]
# Radians of extra turn about Y for models that do not follow the base
# weapon's convention. A bow's limbs should curve in YZ as the Twig Bow's do;
# these three are modelled curving in XY, so they face sideways without it.
# Verified against each import's bounding box: X wider than Z means XY.
# Radians of extra turn about Y, on top of `turned`, for models that do not
# face the base weapon's way. A bow is held with its riser in the hand and its
# string behind it (+Z out of the riser, as the Twig Bow's arrow flies). Which
# turn does that depends on which side of each mesh its riser is, measured
# from the meshes (2026-11-13, owner: "make sure the player is holding the
# weapons correctly"): riser on +X a quarter turn, on -X a quarter the other
# way, on +Z half a turn, on -Z none. Five were held back to front before.
YAW = {
    "AcornBow": "math.pi / 2",
    "GladeSpiritBow": "math.pi / 2",
    "FireflyBow": "-math.pi / 2",
    "EmberFangBow": "-math.pi / 2",
    "MossSlimeBow": "math.pi",
    "SlatefinBow": "math.pi",
    "EelcrestBow": "math.pi / 2",
    "TollstringBow": "math.pi / 2",
    "EventideBow": "math.pi / 2",
    "PeatwoodBow": "math.pi / 2",
    "SporestringBow": "math.pi / 2",
    "GlowcapLongbow": "math.pi / 2",
    "GulpstringBow": "math.pi / 2",
    "LumenveilBow": "math.pi / 2",
    "GoldenBow": "math.pi / 2",
    "LivewireBow": "-math.pi / 2",
    # Thornwood's bows, every riser on +X of its uploaded mesh (on -X of its
    # GLB, whose x and z the upload negates; read in Studio 2026-11-27)
    "BoarTuskBow": "math.pi / 2",
    "PlumBurrBow": "math.pi / 2",
    "LurkerVineBow": "math.pi / 2",
    "SilkweaverBow": "math.pi / 2",
    "NightbarbBow": "math.pi / 2",
    # the seven themed sets' bows, every riser on -X (themed_sets/measure_grips.py)
    "WishbrightBow": "-math.pi / 2",
    "SaddlehornBow": "-math.pi / 2",
    "NoodleBow": "-math.pi / 2",
    "HighscoreBow": "-math.pi / 2",
    "OrbitBow": "-math.pi / 2",
    "BlossomBow": "-math.pi / 2",
    "CinderstringBow": "-math.pi / 2",
    # the Windswept Cliffs' five, every riser on -X (windswept/measure_grips.py)
    "SlatewoodBow": "-math.pi / 2",
    "HarpyBow": "-math.pi / 2",
    "GalestringLongbow": "-math.pi / 2",
    "RocsWingBow": "-math.pi / 2",
    "SkyrenderBow": "-math.pi / 2",
}
YAW_RADIANS = {"math.pi / 2": math.pi / 2, "-math.pi / 2": -math.pi / 2, "math.pi": math.pi}
# Where the hand closes on each one-mesh model, measured from its mesh's cross
# sections (2026-11-13): (x, how far up its length, z), x and z as fractions
# of its length from its centre in Studio's mesh axes. A bow's riser at its
# middle; a blade's handle between pommel and guard, which sits anywhere from
# 16% to 26% up (one grip for all put some hands on the guard); a staff's shaft
# 43% up. A model not listed is gripped at its class's `grip`, centred.
GRIPS = {
    # the Windswept Cliffs' twenty (windswept/measure_grips.py); the
    # Stormtalon Blade's and Thunderbeak Dagger's handles set from their
    # pictures, the measure taking each pommel's waist for the guard
    "SlatewoodBow": (-0.0582, 0.5, 0.0004),
    "HarpyBow": (-0.0849, 0.5, 0.0074),
    "GalestringLongbow": (-0.1392, 0.5, 0.0),
    "RocsWingBow": (-0.0411, 0.5, 0.0004),
    "SkyrenderBow": (-0.0905, 0.5, 0.0006),
    "CloudspunStaff": (0.003, 0.43, 0.0063),
    "GustcallerStaff": (-0.0126, 0.43, -0.0081),
    "PrayerflagStaff": (0.0001, 0.43, -0.0003),
    "TempestStaff": (-0.0004, 0.43, 0.0004),
    "EyeOfTheStorm": (-0.0003, 0.43, -0.0001),
    "LedgestoneBlade": (0.0007, 0.14, -0.0005),
    "RamhornCleaver": (0.0009, 0.21, -0.0004),
    "WindcutterBlade": (0.0003, 0.2, -0.0005),
    "StormtalonBlade": (-0.0002, 0.2, 0.0008),
    "ThunderheadBlade": (-0.0006, 0.19, 0.0004),
    "FlintTalon": (0.0, 0.2, 0.0),
    "HarpyClaw": (-0.002, 0.23, -0.0004),
    "StormQuill": (-0.0011, 0.22, -0.0009),
    "ThunderbeakDagger": (-0.0176, 0.24, 0.0006),
    "ZephyrFang": (-0.0012, 0.22, 0.0),
    "AcornBow": (0.0377, 0.5, 0.0),
    "FireflyBow": (-0.066, 0.5, -0.0003),
    "MossSlimeBow": (-0.0258, 0.5, 0.1123),
    "EmberFangBow": (-0.0718, 0.5, 0.0313),
    "GladeSpiritBow": (0.109, 0.5, -0.0007),
    "ToadstoolStaff": (0.006, 0.43, -0.001),
    "LanternStaff": (-0.003, 0.43, 0.001),
    "HootmossStaff": (-0.001, 0.43, -0.002),
    "SlimeCrownStaff": (-0.0, 0.43, 0.001),
    "WorldrootStaff": (-0.005, 0.43, 0.002),
    "MossstoneBlade": (-0.0001, 0.2313, 0.0),
    "ThornBlade": (-0.0008, 0.25, -0.0002),
    "BroodsplitBlade": (0.0001, 0.2562, -0.0003),
    "EmberfangBlade": (0.0003, 0.1812, 0.0002),
    "GladeheartBlade": (-0.0005, 0.2375, -0.0006),
    "ReedStaff": (0.001, 0.43, 0.004),
    "TidewoodBlade": (0.0, 0.1875, 0.0),
    "SlatefinBow": (0.002, 0.5, 0.0917),
    "TidehookBlade": (0.0, 0.175, 0.0),
    "EelcrestBow": (0.0355, 0.5, 0.0014),
    "WellpearlStaff": (-0.001, 0.43, 0.001),
    "CausewayBlade": (0.0006, 0.1625, 0.0),
    "TollstringBow": (0.1075, 0.5, 0.0126),
    "TollkeeperStaff": (-0.0, 0.43, -0.0),
    "TollguardBlade": (0.0003, 0.2125, 0.0),
    "BogironBlade": (-0.0008, 0.1938, -0.0008),
    "CaplightBlade": (-0.0001, 0.1938, -0.0001),
    "DeepglowBlade": (0.0001, 0.2375, 0.0009),
    "GlowcapLongbow": (0.075, 0.5, -0.001),
    "GrandmothersStaff": (-0.023, 0.43, -0.036),
    "GulpfangBlade": (-0.002, 0.2188, 0.0007),
    "GulpstringBow": (0.079, 0.5, -0.0077),
    "LichenStaff": (-0.011, 0.43, -0.011),
    "LumenveilBow": (0.017, 0.5, -0.0007),
    "MyceliadStaff": (-0.01, 0.43, -0.001),
    "PeatwoodBow": (0.0582, 0.5, 0.0),
    "PuffballStaff": (-0.008, 0.43, 0.001),
    "ShellbackCleaver": (0.0301, 0.2188, -0.0004),
    "SporestringBow": (0.0892, 0.5, -0.001),
    "VentstoneStaff": (0.0, 0.43, -0.004),
    # measured in Studio from the imported meshes (no local GLB matched them)
    "EventideBow": (0.057, 0.5, -0.006),
    "BuoyStaff": (-0.001, 0.43, 0.0),
    "MaelstromStaff": (0.012, 0.43, -0.005),
    "StormglassBlade": (0.0, 0.181, 0.0),
    # the golden weapons, measured from their GLBs (2026-11-14): the bow's
    # riser is on +X; the blade's handle runs from 10% to 25% up, under a
    # guard that starts at 26%
    "GoldenBow": (0.0806, 0.5, -0.0004),
    "GoldenStaff": (0.0, 0.43, 0.0),
    "GoldenBlade": (0.0, 0.175, 0.0),
    # Thornwood, measured from its GLBs (themed_sets/measure_grips.py,
    # 2026-11-26) and turned into its uploaded meshes' axes (x and z negated,
    # checked in Studio 2026-11-27). The Briarbreaker Blade's narrow handle
    # runs 12% to 28% up under its guard (a wrap band at 20% split the rule's
    # run), so it is held at the middle of the whole run.
    "BoarTuskBow": (0.0674, 0.5, 0.0),
    "PlumBurrBow": (0.1069, 0.5, -0.0002),
    "LurkerVineBow": (0.1004, 0.5, -0.0008),
    "SilkweaverBow": (0.0714, 0.5, 0.0001),
    "NightbarbBow": (0.049, 0.5, -0.0001),
    "HedgeBulbStaff": (0.0001, 0.43, 0.0001),
    "BurrTotemStaff": (0.0002, 0.43, -0.0003),
    "LurkerCrestStaff": (0.0001, 0.43, -0.0003),
    "SilkDiademStaff": (-0.0004, 0.43, -0.0005),
    "BlackspineStaff": (-0.0021, 0.43, -0.003),
    "BoarbackBlade": (0.0002, 0.18, -0.0007),
    "PlumguardBlade": (-0.0004, 0.19, 0.0001),
    "BurrcrestBlade": (0.0002, 0.22, -0.0001),
    "SilkboundBlade": (-0.0001, 0.18, 0.0001),
    "BriarbreakerBlade": (0.0003, 0.2, -0.0017),
    # Neon Circuit, measured from its GLBs (neon_circuit/measure_grips.py,
    # 2026-11-18): the bow's riser is on -X; the blade's handle runs 12% to
    # 30% up, the dagger's 12% to 28% (its pommel cube below)
    "LivewireBow": (-0.0994, 0.5, -0.0014),
    "MainframeStaff": (-0.0007, 0.43, -0.0018),
    "OverclockBlade": (0.0004, 0.21, 0.0004),
    "GlitchDaggers": (0.0011, 0.2, 0.0),
    # the seven themed sets, measured from their GLBs (themed_sets/measure_grips.py,
    # 2026-11-18). Two staffs are held lower than 43%, on their own grips under
    # what hangs off the shaft there: the Splashring Staff's water tank and the
    # Paperglow Staff's lantern (x from the bare shaft below). The Spur
    # Daggers' handle runs 9% to 34% up, between the star pommel and the
    # bandana under the spur (the rule took the pommel in).
    "WishbrightBow": (-0.1421, 0.5, -0.0002),
    "DreamdropStaff": (-0.0012, 0.43, -0.0016),
    "WishcutterBlade": (-0.0009, 0.2, 0.0005),
    "TwinkleDaggers": (-0.0001, 0.21, 0.0001),
    "SaddlehornBow": (-0.1135, 0.5, 0.0055),
    "WagonwheelStaff": (-0.0001, 0.43, -0.0007),
    "TrailbossBlade": (-0.0013, 0.15, 0.0),
    "SpurDaggers": (-0.002, 0.2, 0.0009),
    "NoodleBow": (-0.1126, 0.5, 0.0129),
    "SplashringStaff": (0.0012, 0.3, -0.0005),
    "BreakerBlade": (0.0007, 0.21, 0.0051),
    "SquirtDaggers": (0.0, 0.22, -0.0004),
    "HighscoreBow": (-0.1, 0.5, 0.0009),
    "JoystickStaff": (-0.0004, 0.43, -0.0004),
    "PixelBlade": (-0.0005, 0.25, 0.0006),
    "TokenDaggers": (-0.0006, 0.27, 0.0004),
    "OrbitBow": (-0.0961, 0.5, 0.0004),
    "StarwellStaff": (0.0007, 0.43, -0.0012),
    "NebulaBlade": (0.0001, 0.22, -0.0004),
    "CometDaggers": (0.0001, 0.22, -0.0048),
    "BlossomBow": (-0.1165, 0.5, 0.0009),
    "PaperglowStaff": (-0.1169, 0.23, 0.0006),
    "PetalfallBlade": (0.0, 0.23, 0.0006),
    "BellchimeDaggers": (0.0006, 0.25, 0.0),
    "CinderstringBow": (-0.114, 0.5, 0.0),
    "ForgeheartStaff": (0.0008, 0.43, 0.0019),
    "MoltenBlade": (0.0007, 0.24, -0.0002),
    "EmbershardDaggers": (0.0001, 0.22, 0.0026),
}
# Every Mossy Glade skin is a Tripo model (seven remade 2026-11-10, all
# eighteen at 4,000 triangles and an 8K texture 2026-11-13, owner): one
# textured mesh each, so a Legendary's or Mythic's glow is an `aura`, as
# Bogheart's are, not a Neon gem group.
TRIPO_FOREST = {k for k, *_ in SKINS}
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


def entry(imports, key, cls, name, projectile, glow, tier=None, aura=False) -> str:
    base = BASES[cls]
    model = imports[name]
    tier = tier if tier is not None else rarity(name)
    if tier >= 3 and not glow:
        glow = WHITE
    length = model["size"][1]
    # the grip in the model's centred frame: measured, or up the length from
    # the bottom at the class's fraction
    gx, frac, gz = GRIPS.get(key, (0, base["grip"], 0))
    grip = (gx * length, -length / 2 + length * frac, gz * length)
    # the part's full turn about Y: half round (`turned`) and any `yaw`
    theta = math.pi + YAW_RADIANS.get(YAW.get(key, ""), 0)
    c, s = math.cos(theta), math.sin(theta)
    scale = base["scale"] * base["length"] / length
    out = [f"\t{key} = {{"]
    out.append(f"\t\t-- `{name}`, held as the {base['base']} is, playing its kit until it has its own")
    out.append(f'\t\tkit = "{base["base"]}",')
    out.append(f"\t\tskinOf = \"{base['base']}\",")
    out.append(f"\t\tscale = {num(scale)},")
    out.append("\t\tparts = {")
    for part in model["parts"]:
        at = part["at"]
        # the part's centre from the grip, turned as the part is
        d = (at[0] - grip[0], at[1] - grip[1], at[2] - grip[2])
        offset = (d[0] * c + d[2] * s, d[1], -d[0] * s + d[2] * c)
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
    if tier == 5 and not aura:
        out.append("\t\trainbow = true,")
    if aura and tier >= 4:
        out.append(f"\t\taura = {rgb(glow)},")
    # Legendary and Mythic shots glow too (owner, 2026-10-25), in the
    # weapon's glow colour; a Mythic's turns round the rainbow. A skin with
    # no projectile of its own still fires its base's bolt (Config/Weapons
    # resolves `skin.bolt or base.bolt`), so a staff glows whether or not it
    # brought a bolt of its own. A bow with no arrow of its own fires the
    # plain arrow, and that glows too (owner, 2026-11-08). A Warden's blade
    # has no shot: it takes `trailGlow` below instead.
    if tier >= 4 and cls not in MELEE:
        out.append(f"\t\tshotGlow = {rgb(glow)},")
    # and a Legendary or Mythic blade's swing glows the same way
    if tier >= 4 and cls in MELEE:
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
    rows = [(imports, k, c, n, p, g, None, k in TRIPO_FOREST) for k, _, c, n, p, g in SKINS]
    # Textured Tripo meshes, so a Legendary's or Mythic's glow is an `aura`,
    # teal as the area's daggers' (2026-11-26: the sweep found these six
    # with no glow in hand, against the every-Legendary-glows rule).
    rows += [(drowned, k, c, n, p, g, t, True) for k, _, c, n, p, g, t in DROWNED]
    bogheart = json.loads(BOGHEART_IMPORTS.read_text(encoding="utf-8"))
    rows += [(bogheart, k, c, n, p, g, t, True) for k, _, c, n, p, g, t in BOGHEART]
    listed = SKINS + DROWNED + BOGHEART
    if GOLDEN_IMPORTS.exists():
        golden = json.loads(GOLDEN_IMPORTS.read_text(encoding="utf-8"))
        rows += [(golden, k, c, n, p, g, t, True) for k, _, c, n, p, g, t in GOLDEN]
        listed = listed + GOLDEN
    if DAGGER_IMPORTS.exists():
        daggers = json.loads(DAGGER_IMPORTS.read_text(encoding="utf-8"))
        GRIPS.update({k: tuple(v) for k, v in json.loads(DAGGER_GRIPS.read_text(encoding="utf-8")).items()})
        rows += [(daggers, k, c, n, p, g, t, True) for k, _, c, n, p, g, t in DAGGERS]
        listed = listed + DAGGERS
    if THORNWOOD_IMPORTS.exists():
        thornwood = json.loads(THORNWOOD_IMPORTS.read_text(encoding="utf-8"))
        rows += [(thornwood, k, c, n, p, g, t, True) for k, _, c, n, p, g, t in THORNWOOD]
        listed = listed + THORNWOOD
    if NEON_CIRCUIT_IMPORTS.exists():
        neon = json.loads(NEON_CIRCUIT_IMPORTS.read_text(encoding="utf-8"))
        rows += [(neon, k, c, n, p, g, t, True) for k, _, c, n, p, g, t in NEON_CIRCUIT]
        listed = listed + NEON_CIRCUIT
    if THEMED_IMPORTS.exists():
        themed = json.loads(THEMED_IMPORTS.read_text(encoding="utf-8"))
        extra = themed_rows()
        rows += [(themed, k, c, n, p, g, t, True) for k, _, c, n, p, g, t in extra]
        listed = listed + extra
    if WINDSWEPT_IMPORTS.exists():
        windswept = json.loads(WINDSWEPT_IMPORTS.read_text(encoding="utf-8"))
        rows += [(windswept, k, c, n, p, g, t, True) for k, _, c, n, p, g, t in WINDSWEPT]
        listed = listed + WINDSWEPT
    skins = chr(10).join(entry(*r) for r in rows) + chr(10)
    splice(WEAPONS, skins, "\t--[[ SKINS GO HERE ]]\n")
    menu = "".join(f'\t\t{{ weapon = "{k}", class = "{c}", label = "{l}" }},\n' for k, l, c, *_ in listed)
    splice(SANDBOX, menu, "\t\t--[[ SKINS GO HERE ]]\n")
    print(f"wrote {len(rows)} skins")


if __name__ == "__main__":
    main()
