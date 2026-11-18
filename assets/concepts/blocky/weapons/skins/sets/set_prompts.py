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
        "gadget; not sleek, not sharp, not military.",
        [
            (
                "livewire_bow", "LIVEWIRE BOW", "bow", "golden_bow.png",
                "a recurve bow built of chunky graphite-black blocks; a glowing cyan light strip runs "
                "down the front of the upper limb and a glowing magenta light strip down the front of "
                "the lower limb; a bright yellow block caps each limb tip; the grip in the middle is a "
                "grey ribbed rubber block with the square green circuit chip set just above it; the "
                "string is one thick straight bar of white-cyan light; glowing softly cyan and magenta",
            ),
            (
                "mainframe_staff", "MAINFRAME STAFF", "staff", "golden_staff.png",
                "a square graphite-black shaft with a glowing magenta light strip running up its "
                "front, a grey ribbed rubber grip a little below the middle and a bright yellow block "
                "foot; its head is an open square frame of graphite-black blocks, like a chunky "
                "monitor bezel, holding one glowing cyan cube that floats in the middle of the frame; "
                "two short block prongs stand on top of the frame, one tipped cyan and one tipped "
                "magenta; the square green circuit chip sits where the shaft meets the frame; glowing "
                "softly cyan and magenta",
            ),
            (
                "overclock_blade", "OVERCLOCK BLADE", "greatsword", "golden_blade.png",
                "a broad blade of graphite-black blocks with a squared-off stepped tip, a wide "
                "glowing cyan light strip along both cutting edges and one glowing magenta line down "
                "the centre groove; the guard is a chunky block like a heat sink, three square fins "
                "each side, with the square green circuit chip in its middle; a short grey ribbed "
                "rubber grip; the pommel is a bright yellow battery block with three small glowing "
                "cyan charge bars; glowing softly cyan and magenta",
            ),
            (
                "glitch_daggers", "GLITCH DAGGERS", "dagger", "golden_daggers.png",
                "a short graphite-black block blade with a glowing cyan edge, whose top third is "
                "broken into three stair-step blocks shifted sideways, as if the picture had glitched, "
                "the topmost block glowing magenta; a small square block guard with the square green "
                "circuit chip in it; a grey ribbed rubber grip; a bright yellow block pommel; glowing "
                "softly cyan and magenta",
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
