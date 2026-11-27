"""The Windswept Cliffs' twenty weapons (docs/WINDSWEPT-CLIFFS.md), one Codex
front view each: the weapon's picture and Tripo's input. Writes <name>.txt;
run.sh sends them. Bows are asked for as toy props (Codex's filter refused
bows asked for as weapons, 2026-11-18); every bowstring is one thick bar."""
import pathlib

HERE = pathlib.Path(__file__).parent
AREA = ("the Windswept Cliffs: slate cliff tops in a sea of white cloud. Slate grey-blue, "
        "cloud white, sky blue, weathered wood, prayer-flag red, yellow, green and blue, "
        "and the storm boss's navy, cream, gold and lightning yellow.")
KIND = {
    "bow": ("an archery bow", "a toy prop from our children's blocky voxel game, an archery bow",
            "ONE single bow only, shown flat side-on, upright, its limbs up and down and its string on the right, "
            "drawn as ONE thick straight bar from tip to tip (as thick as the grip, never a thin line), with no arrow on it"),
    "staff": ("a magic staff", "a magic staff from our children's blocky voxel game",
              "ONE single staff only, shown flat side-on, upright, its head at the top and its foot at the bottom"),
    "blade": ("a sword", "a sword from our children's blocky voxel game",
              "ONE single sword only, shown flat side-on, upright with the blade pointing up"),
    "dagger": ("a dagger", "a dagger from our children's blocky voxel game",
               "ONE single dagger only (not a pair), shown flat side-on, upright with the blade pointing up. "
               "A short one-handed dagger: the blade about twice the length of the handle, a small crossguard, "
               "a wrapped grip and a pommel"),
}
WEAPONS = [
    ("slatewood_bow", "bow", "SLATEWOOD BOW (Uncommon)", "grey slate-wood limbs with stepped edges, prayer-flag cloth wraps in red, yellow, green and blue round the grip"),
    ("harpy_bow", "bow", "HARPY BOW (Rare)", "limbs of layered purple and magenta feathers, a bone-white owl-skull mask on the grip with two small glowing pale-blue eyes"),
    ("galestring_longbow", "bow", "GALESTRING LONGBOW (Epic)", "tall sky-blue limbs ending in glowing pale-cyan wind-swirl tips, a cloud-white grip"),
    ("rocs_wing_bow", "bow", "ROC'S WING BOW (Legendary)", "limbs shaped like navy-and-gold stepped wings, gold talon tips, a cream feather grip, a soft gold glow"),
    ("skyrender_bow", "bow", "SKYRENDER BOW (Mythic)", "limbs of glowing lightning-yellow feathers with jagged bolt edges, a cloud-white grip with a navy gem, a bright glow"),
    ("cloudspun_staff", "staff", "CLOUDSPUN STAFF (Uncommon)", "a pale birch shaft with a rope wrap, topped by a fluffy puff of cloud-white wool"),
    ("gustcaller_staff", "staff", "GUSTCALLER STAFF (Rare)", "a knotted brown crook with cream and teal ribbons, topped by a glowing pale-blue wind spiral"),
    ("prayerflag_staff", "staff", "PRAYERFLAG STAFF (Epic)", "a slate-grey pole hung with small bright prayer flags in red, yellow, green and blue round a glowing blue gem at the top"),
    ("tempest_staff", "staff", "TEMPEST STAFF (Legendary)", "a navy shaft with gold bands, gold talons at the top gripping a glowing storm-cloud orb with a yellow lightning spark inside, a soft gold glow"),
    ("eye_of_the_storm", "staff", "EYE OF THE STORM (Mythic staff)", "a navy shaft topped by a ring of navy and gold feathers round a glowing pale-cyan cyclone core, small yellow lightning sparks on the ring, a bright glow"),
    ("ledgestone_blade", "blade", "LEDGESTONE BLADE (Uncommon)", "a slate-grey stepped stone blade, a wooden crossguard and a rope-bound grip"),
    ("ramhorn_cleaver", "blade", "RAMHORN CLEAVER (Rare)", "a broad cream blade curling at the top like a goat's horn, a dark-brown ridged horn crossguard and a leather grip"),
    ("windcutter_blade", "blade", "WINDCUTTER BLADE (Epic)", "a pale sky-blue blade with three glowing pale-cyan wind slits down its middle, a slate crossguard, a white grip"),
    ("stormtalon_blade", "blade", "STORMTALON BLADE (Legendary)", "a navy blade with a lightning-yellow edge, a gold talon crossguard gripping the blade, a cream feather pommel, a soft gold glow"),
    ("thunderhead_blade", "blade", "THUNDERHEAD BLADE (Mythic)", "a big greatsword whose blade is a glowing storm cloud of grey-blue and white blocks crackling with yellow lightning, a gold wing crossguard, a bright glow"),
    ("flint_talon", "dagger", "FLINT TALON (Uncommon)", "a chipped grey flint blade with a leather-wrapped grip and a small wooden pommel"),
    ("harpy_claw", "dagger", "HARPY CLAW (Rare)", "a curved purple talon blade fading to magenta at its point, a bone-white grip and a small skull pommel"),
    ("storm_quill", "dagger", "STORM QUILL (Epic)", "a long navy feather-quill blade with a glowing pale-blue edge, a cream quill grip"),
    ("thunderbeak_dagger", "dagger", "THUNDERBEAK DAGGER (Legendary)", "a hooked gold beak blade, a navy feather grip and a cream pommel, a soft gold glow"),
    ("zephyr_fang", "dagger", "ZEPHYR FANG (Mythic)", "a glowing pale-cyan wind-crystal blade with swirl facets, a gold feather crossguard and a white grip, a bright glow"),
]
for name, kind, title, look in WEAPONS:
    what, prop, view = KIND[kind]
    text = (
        f"Generate ONE square image at the highest resolution available and save it in the current directory as {name}.png\n\n"
        f"Image 1 is a style reference for our game's items like this ({what}): match its blocky voxel style, chunky proportions and finish, "
        f"but NOT its design or colours. Image 2 is the area this one belongs to: match its palette and materials, not its shapes.\n"
        f"Draw {prop} for {AREA}\n"
        f"{title}: {look}.\n"
        f"View: {view}, straight-on camera, no perspective, centred, filling about 85 percent of the image. "
        "Simple chunky blocks, no fine filigree. No hands, no character. This image is the item's in-game picture and will be turned into a 3D model.\n"
        "Plain flat light-grey background, no scenery, no ground, no shadow, no text, no labels, no particles. Even soft lighting.\n"
    )
    (HERE / f"{name}.txt").write_text(text, encoding="utf-8")
    print(name, kind)
