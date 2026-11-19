"""Write Codex's prompts for a themed weapon set (docs/WEAPONS-THEMED.md).

    python -I set_prompts.py

A themed set belongs to no area: one theme across one weapon for every
class (bow, staff, greatsword, dagger). Every set is an original design
for this game, in its own blocky style. This writes one front-view prompt
per weapon into the set's folder and `<set>_run_a.sh` / `<set>_run_b.sh`,
which run them, half each, side by side.

The picture is the weapon's 2D picture in the game and what Tripo models
from, so it is ONE weapon from the front. A bow's string is asked for as a
thick bar (a thin one comes out of Tripo as a ragged web); a dagger is ONE
dagger, held as a copy in each hand. The prompts say "toy prop" and never
"weapon": Codex's image filter refused three plain bow prompts on
2026-11-18.
"""
import pathlib

HERE = pathlib.Path(__file__).parent
GOLDEN = "../../golden"

STYLE = (
    "Image 1 is a style reference from our children's blocky voxel game (match its blocky voxel "
    "style, chunky proportions, block sizes and clean finish, but NOT its design or its colours). "
    "Draw a new toy prop for the same game, an original design."
)
VIEW = {
    "bow": (
        "ONE single archery bow only, shown flat side-on, upright, its limbs up and down and its "
        "string on the right, drawn as ONE thick straight bar from tip to tip (as thick as the grip, "
        "never a thin line), with no arrow on it"
    ),
    "staff": "ONE single wizard's staff only, shown flat from the front, upright, its head at the top and its foot at the bottom",
    "greatsword": "ONE single broad two-handed toy sword only, shown flat side-on, upright with the blade pointing up",
    "dagger": (
        "ONE single short toy dagger only (not a pair), shown flat side-on, upright with the blade "
        "pointing up, the blade about twice the length of the handle"
    ),
}
END = (
    "straight-on camera, no perspective, centred, filling about 85 percent of the image. Simple "
    "chunky blocks, no fine filigree, no thin wires. No hands, no character. This image is the "
    "prop's in-game picture and will be turned into a 3D model.\n"
    "Plain flat light-grey background, no scenery, no ground, no shadow, no text, no letters, no "
    "logos, no labels, no loose particles or sparkles round it. Even soft lighting."
)

# set folder -> (what the set is, [(file, NAME, kind, golden reference, look)])
SETS = {
    "neon_circuit": (
        "NEON CIRCUIT, a set of chunky toy electronics: matte graphite-black blocks with dark navy "
        "shading on the block sides, glowing light strips in bright cyan and hot magenta, grey "
        "ribbed rubber grips, one bright yellow block as an accent, and one small square green "
        "circuit chip with a few gold pixel traces. Friendly and toy-like, like a kid's light-up "
        "gadget; not sleek, not military. Each prop has a bold, unusual silhouette that reads at a "
        "glance, with big simple shapes rather than a plain stick or blade.",
        [
            (
                "livewire_bow", "LIVEWIRE BOW", "bow", "golden_bow.png",
                "a bow whose two limbs are big zigzag lightning bolts built of thick stepped "
                "graphite-black blocks, each limb bending in three sharp right-angle steps; the upper "
                "bolt carries a wide glowing cyan light strip down its middle and the lower bolt a "
                "wide glowing magenta one; each limb tip ends in a big bright yellow two-pronged plug "
                "head, prongs pointing outward; the grip in the middle is a fat graphite power cell "
                "wrapped in grey ribbed rubber, with a round glowing cyan dial on its front and the "
                "square green circuit chip above it; the string is one thick straight bar of "
                "white-cyan light; glowing strongly cyan and magenta",
            ),
            (
                "mainframe_staff", "MAINFRAME STAFF", "staff", "golden_staff.png",
                "its head is a big boxy retro computer monitor of graphite-black blocks, as wide as "
                "four shaft widths, with a large glowing cyan screen crossed by one chunky magenta "
                "zigzag pulse line, a row of three bright yellow square keys under the screen, and two "
                "thick block antennae on top leaning outward in a V, one tipped with a glowing cyan "
                "cube and one with a glowing magenta cube; the monitor sits on a short neck holding "
                "the square green circuit chip; the shaft is a thick graphite conduit with a glowing "
                "magenta light strip up its front and a grey ribbed rubber grip a little below the "
                "middle; the foot is a big bright yellow plug with two prongs pointing down; glowing "
                "strongly cyan and magenta",
            ),
            (
                "overclock_blade", "OVERCLOCK BLADE", "greatsword", "golden_blade.png",
                "a big heroic two-edged greatsword, symmetrical left to right, NOT a cleaver or a "
                "knife: a long broad blade of graphite-black blocks, a little wider near the top than "
                "at the guard, ending in a pointed tip built of three centred steps; a thick glowing "
                "cyan light bar runs up BOTH cutting edges from guard to tip; down the centre of the "
                "blade runs a glowing magenta light strip, and set into the blade just above the "
                "guard is a round cooling fan, a glowing magenta ring with four chunky graphite fan "
                "blades and a yellow hub; the guard is a wide heat sink, three square graphite fins "
                "stepping upward on each side like wings, each side ending in a fat bright yellow "
                "block capacitor, with the square green circuit chip in the guard's middle; a grey "
                "ribbed rubber grip long enough for two hands; the pommel is a graphite battery block "
                "with three glowing cyan charge bars; the blade is about three times as long as the "
                "grip; glowing strongly cyan and magenta",
            ),
            (
                "glitch_daggers", "GLITCH DAGGERS", "dagger", "golden_daggers.png",
                "a straight, slim dagger blade with a pointed tip that looks torn sideways by a screen "
                "glitch: the blade is one tall narrow graphite-black bar, all the same width, cut "
                "across into five equal slices, and the second and fourth slices are slid half a "
                "block to the RIGHT while the first, third and fifth stay in line, so the two edges "
                "run in a square-wave zigzag up the blade; the fifth slice is topped by a small "
                "pointed block tip. It must NOT be a pyramid, a tower or a stack that narrows in "
                "steps: every slice is the same width. The left face of each slice has a glowing cyan "
                "edge strip and the right face a glowing magenta one, like a picture whose colours "
                "have split apart; all the slices touch, nothing floats; the guard is a wide bright "
                "yellow block shaped like a chunky game cartridge with the square green circuit chip "
                "in its middle; a grey ribbed rubber grip; the pommel is a glowing magenta cube; "
                "glowing strongly cyan and magenta",
            ),
        ],
    ),
    "starwish": (
        "STARWISH, a set of chunky toy wishing-star charms: soft pastel pink and mint-green blocks, "
        "cream-white blocks, shiny gold star charms, flat chunky ribbon wraps (wide flat block "
        "strips, never thin strings), and glowing pale-yellow star gems. Sweet and toy-like, like "
        "a kid's sparkly birthday present; no faces, no characters, no wings, no hearts, no moons. "
        "Each prop has a bold, unusual silhouette that reads at a glance, with big simple shapes "
        "rather than a plain stick or blade.",
        [
            (
                "wishbright_bow", "WISHBRIGHT BOW", "bow", "golden_bow.png",
                "a bow whose two limbs are smooth curved arcs of pastel pink blocks, each wrapped "
                "near its middle by a wide flat mint ribbon band; each limb tip carries a big chunky "
                "gold five-pointed star, as wide as three limb widths; the grip in the middle is "
                "cream white wrapped in a wide flat mint ribbon tied in a chunky block bow knot on "
                "its front, with a round glowing pale-yellow star gem set above the knot; the string "
                "is one thick straight bar of soft pink light; glowing softly pink and gold",
            ),
            (
                "dreamdrop_staff", "DREAMDROP STAFF", "staff", "golden_staff.png",
                "its head is a big chunky five-pointed star of pastel pink blocks with a thick gold "
                "rim, as wide as five shaft widths, with a large glowing pale-yellow star gem in its "
                "centre; two short wide flat mint ribbon tails hang from under the star on either "
                "side, each ending in a small gold star charm; the shaft is cream white with a wide "
                "flat mint ribbon spiralling round it in chunky steps; a pastel pink grip a little "
                "below the middle; the foot is a small gold star pointing down; glowing softly pink "
                "and gold",
            ),
            (
                "wishcutter_blade", "WISHCUTTER BLADE", "greatsword", "golden_blade.png",
                "a big heroic two-edged greatsword, symmetrical left to right, NOT a cleaver: a long "
                "broad blade of pale mint-green blocks with pastel pink edges on both sides, ending in "
                "a pointed tip built of three centred steps; up the centre of the blade run three "
                "gold five-pointed stars in a line, small, medium and large, the largest just above "
                "the guard; the guard is a wide gold bar ending in a chunky gold star on each side, "
                "with a round glowing pale-yellow star gem in its middle; a cream-white grip long "
                "enough for two hands, wrapped in a wide flat pink ribbon; the pommel is a small gold "
                "star; the blade is about three times as long as the grip; glowing softly pink and "
                "gold",
            ),
            (
                "twinkle_daggers", "TWINKLE DAGGERS", "dagger", "golden_daggers.png",
                "a dagger whose blade is one long pointed ray of a star: a tall chunky pastel pink "
                "crystal blade, wide at the guard and narrowing in even block steps to a sharp "
                "point, with a cream-white stripe up its middle; the guard is a big chunky mint "
                "ribbon bow knot of flat block loops, one loop out each side, with a gold star in "
                "its knot; a cream-white grip wrapped in a wide flat pink ribbon; the pommel is a "
                "round glowing pale-yellow star gem; all parts touch, nothing floats; glowing softly "
                "pink and gold",
            ),
        ],
    ),
    # The other six themes (owner, 2026-11-18: "make the designs for all first"). Each takes
    # only a broad genre; nothing here copies any other game's line, item or character.
    "tumbleweed": (
        "TUMBLEWEED, a set of friendly toy cowboy gear: warm tan leather with stitched edges, "
        "polished honey-brown wood, shiny brass rivets and buckles, chunky coiled rope (thick, "
        "never thin string), a small tin star badge, a red bandana cloth knot and one turquoise "
        "stone as an accent. Sunny and playful, like a kid's toy ranch set; no skulls, no faces, "
        "no guns, no fire. Each prop has a bold, unusual silhouette that reads at a glance, with "
        "big simple shapes rather than a plain stick or blade.",
        [
            (
                "saddlehorn_bow", "SADDLEHORN BOW", "bow", "golden_bow.png",
                "a bow whose two limbs are big curving cattle horns of cream and honey-brown blocks, "
                "curving out and back like a pair of horns, each tip capped in brass; the grip in the "
                "middle is wrapped in tan stitched leather with two brass rivets, a small tin star "
                "badge on its front and a thick coil of rope tied round it; the string is one thick "
                "straight bar of braided tan rope",
            ),
            (
                "wagonwheel_staff", "WAGONWHEEL STAFF", "staff", "golden_staff.png",
                "its head is a big wooden wagon wheel stood upright, as wide as five shaft widths, "
                "with a thick honey-brown rim bound in a brass band, eight chunky wooden spokes, and "
                "a round brass hub set with a glowing turquoise stone; the shaft is polished wood "
                "with two thick rope wraps and a tan leather grip with brass rivets a little below "
                "the middle; a red bandana knot is tied just under the wheel; the foot is a brass "
                "horseshoe-shaped cap",
            ),
            (
                "trailboss_blade", "TRAILBOSS BLADE", "greatsword", "golden_blade.png",
                "a big heroic two-edged greatsword, symmetrical left to right, NOT a cleaver: a long "
                "broad blade of pale polished steel blocks ending in a pointed tip built of three "
                "centred steps, with a brass stripe down its middle set with a row of round brass "
                "rivets; the guard is two chunky brass horseshoes, one each side, their open ends "
                "pointing up, with a tin star badge in the middle; a grip long enough for two hands, "
                "wrapped in tan stitched leather with a red bandana knot tied below the guard; the "
                "pommel is a turquoise stone in a brass cap; the blade is about three times as long "
                "as the grip",
            ),
            (
                "spur_daggers", "SPUR DAGGERS", "dagger", "golden_daggers.png",
                "a straight dagger with a pale polished steel blade, wide and chunky, with a thin "
                "turquoise inlay down its middle and a pointed tip; the guard is a big brass spur "
                "rowel, a chunky round wheel of eight blunt block points, set flat behind the blade "
                "so it sticks out on both sides; a grip wrapped in tan stitched leather with a thick "
                "rope wrap; the pommel is a small brass cap with a tin star on it; all parts touch, "
                "nothing floats",
            ),
        ],
    ),
    "splash_day": (
        "SPLASH DAY, a set of chunky summer water toys: bright foam pool noodles with ridged "
        "stripes, glossy inflatable rings in coral and white stripes, sunny yellow and aqua "
        "plastic like a water blaster, and clear light-blue water shaped into solid chunky "
        "blocks. Bright, wet and fun, like a kid's backyard splash party; no animals, no faces, "
        "no characters. Each prop has a bold, unusual silhouette that reads at a glance, with big "
        "simple shapes rather than a plain stick or blade.",
        [
            (
                "noodle_bow", "NOODLE BOW", "bow", "golden_bow.png",
                "a bow whose two limbs are thick bent foam pool noodles, one coral and one aqua, each "
                "with ridged stripes, curving out and back; each limb tip is capped with a small "
                "glossy yellow inflatable ring; the grip in the middle is a chunky yellow water "
                "blaster handle with a round aqua water tank on its front; the string is one thick "
                "straight bar of clear light-blue water",
            ),
            (
                "splashring_staff", "SPLASHRING STAFF", "staff", "golden_staff.png",
                "its head is a big glossy inflatable swim ring with coral and white stripes, stood "
                "upright, as wide as five shaft widths, holding a round ball of clear glowing "
                "light-blue water in its hole; the shaft is a sunny yellow plastic water pipe with "
                "an aqua water tank clipped to it and an aqua foam grip a little below the middle; "
                "the foot is a chunky aqua spray nozzle",
            ),
            (
                "breaker_blade", "BREAKER BLADE", "greatsword", "golden_blade.png",
                "a big heroic two-edged greatsword, symmetrical left to right, NOT a cleaver: its "
                "broad blade is shaped like a glossy surfboard with rounded stepped edges, white "
                "with a coral stripe and an aqua stripe running up its middle, ending in a rounded "
                "point; the guard is a short fat inflatable tube of sunny yellow, sticking out "
                "both sides; a grip long enough for two hands wrapped in aqua ridged foam; the "
                "pommel is a small striped beach ball; the blade is about three times as long as "
                "the grip",
            ),
            (
                "squirt_daggers", "SQUIRT DAGGERS", "dagger", "golden_daggers.png",
                "a dagger whose blade is a jet of clear light-blue water frozen into a chunky solid "
                "pointed blade, with white foam blocks along its edges; the guard is a sunny yellow "
                "water blaster trigger block with a small round aqua tank on top; a coral ridged "
                "foam grip; the pommel is a small striped beach ball; all parts touch, nothing "
                "floats",
            ),
        ],
    ),
    "coin_op": (
        "COIN-OP, a set of chunky toy arcade gear: glossy cherry-red and royal-blue plastic, big "
        "square pixels like an 8-bit game, round arcade buttons, shiny yellow game coins, small "
        "red pixel hearts and white pixel sparkles built into the blocks, and black panels. "
        "Bright and cheerful like a kid's arcade night; no characters, no faces, no text, no "
        "neon tubes. Each prop has a bold, unusual silhouette that reads at a glance, with big "
        "simple shapes rather than a plain stick or blade.",
        [
            (
                "highscore_bow", "HIGHSCORE BOW", "bow", "golden_bow.png",
                "a bow drawn as big square 8-bit pixels: each limb is a staircase of chunky "
                "cherry-red pixel blocks with white pixel highlights, curving out and back; each "
                "tip carries a big shiny yellow game coin; the grip in the middle is a black block "
                "with a glossy red arcade joystick ball sticking out of its front and a small red "
                "pixel heart above it; the string is one thick straight bar of white pixels",
            ),
            (
                "joystick_staff", "JOYSTICK STAFF", "staff", "golden_staff.png",
                "the whole staff is a giant arcade joystick: its head is a big glossy cherry-red "
                "ball, as wide as four shaft widths, on top of the shaft; just below it sits a "
                "royal-blue control-panel block with two round arcade buttons, one yellow and one "
                "red; the shaft is black with a stack of three red pixel hearts on its front and a "
                "blue grip a little below the middle; the foot is a black coin-slot block with a "
                "yellow game coin half pushed into it",
            ),
            (
                "pixel_blade", "PIXEL BLADE", "greatsword", "golden_blade.png",
                "a big heroic two-edged greatsword built entirely of big square 8-bit pixels, "
                "symmetrical left to right, NOT a cleaver: a long broad royal-blue pixel blade with "
                "a stripe of white pixel highlights up its middle, ending in a stepped pixel "
                "point; the guard is a wide bar of yellow pixels with a red pixel heart in its "
                "middle; a black pixel grip long enough for two hands with red pixel bands; the "
                "pommel is a yellow game coin; the blade is about three times as long as the grip",
            ),
            (
                "token_daggers", "TOKEN DAGGERS", "dagger", "golden_daggers.png",
                "a dagger whose blade is a chunky stepped stack of cherry-red 8-bit pixels with "
                "white pixel highlights and a pointed pixel tip; the guard is a royal-blue "
                "plus-shaped direction pad block; a black grip with yellow pixel bands; the "
                "pommel is a shiny yellow game coin stood on its edge; all parts touch, nothing "
                "floats",
            ),
        ],
    ),
    "voidglass": (
        "VOIDGLASS, a set of chunky toy space crystals: deep purple and midnight-blue "
        "see-through glass blocks with tiny white and pink stars and soft swirls floating "
        "inside them, polished silver-violet trim, and small black orbs circled by glowing "
        "violet rings like tiny ringed planets. Calm and magical, like a kid's glow-in-the-dark "
        "space toy; no skulls, no faces, no eyes, no tentacles, no black holes. Each prop has a "
        "bold, unusual silhouette that reads at a glance, with big simple shapes rather than a "
        "plain stick or blade.",
        [
            (
                "orbit_bow", "ORBIT BOW", "bow", "golden_bow.png",
                "a bow whose two limbs are thick curved bars of deep purple see-through glass with "
                "tiny stars inside, curving out and back; each limb tip carries a small black orb "
                "with a glowing violet ring round it; the grip in the middle is polished silver "
                "with a bigger black orb set in its front, circled by a tilted glowing violet "
                "ring; the string is one thick straight bar of pale violet light",
            ),
            (
                "starwell_staff", "STARWELL STAFF", "staff", "golden_staff.png",
                "its head is a big black orb, as wide as four shaft widths, circled by a wide "
                "tilted glowing violet ring like a ringed planet, held in a silver cradle on top "
                "of the shaft; two small purple glass moons sit on short silver rods either side "
                "of it; the shaft is deep purple see-through glass with tiny stars inside, with a "
                "silver grip a little below the middle; the foot is a silver point",
            ),
            (
                "nebula_blade", "NEBULA BLADE", "greatsword", "golden_blade.png",
                "a big heroic two-edged greatsword, symmetrical left to right, NOT a cleaver: a long "
                "broad blade of deep purple and midnight-blue see-through glass with a swirl of "
                "pink and violet mist and tiny white stars inside, edged in polished silver, ending "
                "in a pointed tip built of three centred steps; the guard is a wide silver bar with "
                "a black orb in its middle circled by a glowing violet ring; a grip long enough for "
                "two hands wrapped in dark violet with silver bands; the pommel is a small purple "
                "glass moon; the blade is about three times as long as the grip",
            ),
            (
                "comet_daggers", "COMET DAGGERS", "dagger", "golden_daggers.png",
                "a dagger whose blade is a long pointed teardrop of deep purple see-through glass "
                "like a comet, with a glowing white star at its tip and a trail of tiny stars "
                "inside running down to the guard; the guard is a polished silver ring set flat "
                "round the base of the blade; a dark violet grip with silver bands; the pommel is a "
                "small black orb with a glowing violet ring; all parts touch, nothing floats",
            ),
        ],
    ),
    "lantern_bloom": (
        "LANTERN BLOOM, a set of chunky toy festival props: pale cream wood, round red paper "
        "lanterns with gold caps glowing warm yellow inside, clusters of pink blossom flowers "
        "built of blocks, small fresh green leaves, little round gold bells and thick red cord "
        "wraps with chunky tassels. Warm and gentle, like a kid's spring festival night; no "
        "masks, no animals, no faces, no spirits, no blue flames. Each prop has a bold, unusual "
        "silhouette that reads at a glance, with big simple shapes rather than a plain stick or "
        "blade.",
        [
            (
                "blossom_bow", "BLOSSOM BOW", "bow", "golden_bow.png",
                "a bow whose two limbs are pale cream wooden branches curving out and back, with "
                "chunky clusters of pink blossom flowers and green leaves along them; each limb tip "
                "hangs a small round red paper lantern with gold caps glowing warm yellow; the grip "
                "in the middle is wrapped in thick red cord with a small round gold bell on its "
                "front; the string is one thick straight bar of soft warm yellow light",
            ),
            (
                "paperglow_staff", "PAPERGLOW STAFF", "staff", "golden_staff.png",
                "the top of the pale cream wooden shaft curls over into a chunky hook, and from the "
                "hook hangs a big round red paper lantern, as wide as four shaft widths, with gold "
                "caps top and bottom and a warm yellow glow inside; pink blossom flowers and green "
                "leaves grow along the hook; two small gold bells hang under the lantern; the "
                "shaft has a thick red cord grip a little below the middle; the foot is a gold cap",
            ),
            (
                "petalfall_blade", "PETALFALL BLADE", "greatsword", "golden_blade.png",
                "a big heroic two-edged greatsword, symmetrical left to right, NOT a cleaver: a long "
                "broad blade of pale cream-white steel blocks with a chunky pink blossom branch "
                "running up its middle and soft pink edges, ending in a pointed tip built of three "
                "centred steps; the guard is a round gold disc like a lantern frame, with a pink "
                "blossom in its centre, and a small gold bell hanging at each side; a grip long "
                "enough for two hands wrapped in thick red cord; the pommel is a small gold cap with "
                "a chunky red tassel; the blade is about three times as long as the grip",
            ),
            (
                "bellchime_daggers", "BELLCHIME DAGGERS", "dagger", "golden_daggers.png",
                "a dagger whose blade is a slim chunky pale-pink petal shape with a cream-white "
                "edge and a pointed tip; the guard is two round gold bells, one sticking out each "
                "side; a pale cream wooden grip wrapped in thick red cord; the pommel is a small "
                "round red paper lantern with gold caps glowing warm yellow; all parts touch, "
                "nothing floats",
            ),
        ],
    ),
    "cinderforge": (
        "CINDERFORGE, a set of chunky toy volcano-forge gear: cracked matte black rock blocks "
        "with bright orange-yellow lava glowing through the cracks, dark iron bands with round "
        "rivets, and glowing molten cubes. Bold and warm like a kid's lava adventure toy; no "
        "skulls, no horns, no faces, no demons, no flames floating loose. Each prop has a bold, "
        "unusual silhouette that reads at a glance, with big simple shapes rather than a plain "
        "stick or blade.",
        [
            (
                "cinderstring_bow", "CINDERSTRING BOW", "bow", "golden_bow.png",
                "a bow whose two limbs are thick chunky bars of cracked black rock with glowing "
                "orange lava seams, curving out and back in big blocky steps; each limb tip is a "
                "glowing molten orange cube in an iron cap; the grip in the middle is a dark iron "
                "band with round rivets wrapped round a glowing lava core that shows through a "
                "square window; the string is one thick straight bar of molten orange light",
            ),
            (
                "forgeheart_staff", "FORGEHEART STAFF", "staff", "golden_staff.png",
                "its head is a big square dark iron cage, as wide as four shaft widths, with "
                "chunky bars, holding a glowing molten orange rock heart inside; the shaft is "
                "cracked black rock with glowing lava seams and two dark iron bands with rivets, "
                "and an iron-banded grip a little below the middle; the foot is a small chunky "
                "dark iron anvil shape",
            ),
            (
                "molten_blade", "MOLTEN BLADE", "greatsword", "golden_blade.png",
                "a big heroic two-edged greatsword, symmetrical left to right, NOT a cleaver: a long "
                "broad blade of cracked matte black rock with bright orange-yellow lava glowing "
                "through a web of chunky cracks, both cutting edges glowing orange-hot, ending in a "
                "pointed tip built of three centred steps; the guard is a wide dark iron anvil "
                "shape with round rivets; a grip long enough for two hands wrapped in dark leather "
                "with iron rings; the pommel is a glowing molten orange cube in an iron cap; the "
                "blade is about three times as long as the grip",
            ),
            (
                "embershard_daggers", "EMBERSHARD DAGGERS", "dagger", "golden_daggers.png",
                "a dagger whose blade is a jagged chunky shard of black rock, wide at the guard and "
                "pointed, with one bright orange lava seam glowing up its middle; the guard is a "
                "thick dark iron band with two round rivets sticking out both sides; a dark "
                "leather grip with iron rings; the pommel is a glowing molten orange cube; all "
                "parts touch, nothing floats",
            ),
        ],
    ),
}


def main():
    count = 0
    for folder, (world, rows) in SETS.items():
        (HERE / folder).mkdir(exist_ok=True)
        halves = (rows[0::2], rows[1::2])
        for letter, half in zip("ab", halves):
            lines = [
                "#!/usr/bin/env bash",
                f"# {folder}: one front view each from Codex (rule 9).",
                f'cd "$(dirname "$0")/{folder}" || exit 1',
            ]
            for name, title, kind, ref, look in half:
                text = (
                    f"Generate ONE square image at the highest resolution available and save it in the current directory as {name}.png\n\n"
                    f"{STYLE} It belongs to {world}\n"
                    f"{title} ({kind}): {look}.\n"
                    f"View: {VIEW[kind]}, {END}\n"
                )
                (HERE / folder / f"{name}.txt").write_text(text, encoding="utf-8", newline="\n")
                lines.append(
                    f'timeout 900 codex exec -i {GOLDEN}/{ref} --skip-git-repo-check < {name}.txt 2>&1 | tail -20 > {name}.log; echo "=== {name} done"'
                )
                count += 1
            (HERE / f"{folder}_run_{letter}.sh").write_text("\n".join(lines) + "\n", encoding="utf-8", newline="\n")
    print(count, "prompts")


if __name__ == "__main__":
    main()
