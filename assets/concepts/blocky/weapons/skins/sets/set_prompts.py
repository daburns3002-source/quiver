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
                "a huge wide cleaver-like blade of graphite-black blocks with a slanted stepped tip; "
                "its back edge is a row of five big square cooling fins like a heat sink, and its "
                "cutting edge is one thick glowing cyan light bar from guard to tip; set into the "
                "middle of the blade is a big round cooling fan, a glowing magenta ring with four "
                "chunky graphite fan blades and a yellow hub; the guard is two fat bright yellow "
                "block capacitors, one each side, joined by a graphite bar holding the square green "
                "circuit chip; a short grey ribbed rubber grip; the pommel is a graphite battery block "
                "with three glowing cyan charge bars; glowing strongly cyan and magenta",
            ),
            (
                "glitch_daggers", "GLITCH DAGGERS", "dagger", "golden_daggers.png",
                "its blade is cut into five thick horizontal slices of graphite-black block, each "
                "slice shifted a little left or right of the one below it, alternating, as if the "
                "picture had glitched, the slices getting narrower toward a single square block tip; "
                "the left edge of every slice glows cyan and the right edge glows magenta; all the "
                "slices touch, nothing floats; the guard is a wide bright yellow block shaped like a "
                "chunky game cartridge with the square green circuit chip in its middle; a grey "
                "ribbed rubber grip; the pommel is a glowing magenta cube; glowing strongly cyan and "
                "magenta",
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
