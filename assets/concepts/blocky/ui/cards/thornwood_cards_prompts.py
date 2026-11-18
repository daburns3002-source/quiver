"""Writes the Codex prompts for Thornwood's six cards (2026-11-18,
docs/CLASS-CARDS.md), one `<icon>.prompt.txt` each, in the words the
Assassin's cards of 2026-11-15 were asked for, and the script that draws
them.

    python -I assets/concepts/blocky/ui/cards/thornwood_cards_prompts.py
    bash assets/concepts/blocky/ui/cards/thornwood_cards_2026_11_18.sh
    python -I assets/ui/glow_toy_cards/compose_icon.py <icon> <rarity>
"""

import pathlib

HERE = pathlib.Path(__file__).resolve().parent

HEAD = (
    "Use case: a 2D game upgrade-card icon for a children's blocky voxel game. Generate ONE square "
    "1024x1024 image: a single icon centred on a FLAT, PURE MAGENTA background (#FF00FF) everywhere, "
    "no tile, no frame, no border, no text or letters, no shadow on the background. Copy EXACTLY the "
    "style of the attached reference icons: chunky pixel-voxel 3D built from small cubes, soft "
    "top-left light, a thick dark navy outline round every piece. Make it BIG, BOLD and SIMPLE, "
    "filling about 85% of the image, few details, clearly readable when shrunk to 48 px. Use NO "
    "magenta or hot pink in the icon itself. "
)

# icon: (rarity tile, what to draw)
CARDS = {
    "websnare": (
        "uncommon",
        "WEB SNARE, arrows tangle what they hit in web. A chunky voxel round GREEN SLIME with a "
        "worried face, wrapped in three thick WHITE strands of spider silk made of cubes, and a "
        "small white voxel spider web behind it.",
    ),
    "thornburst": (
        "epic",
        "THORN BURST, a shot bursts into thorns where it lands. A round dark-plum voxel BURR in the "
        "middle with eight big CREAM THORN spikes flying outward from it in a star, each a chunky "
        "cone of cubes, and small green leaf cubes between them.",
    ),
    "roothold": (
        "rare",
        "ROOT HOLD, an orb roots an enemy in place. A chunky voxel round GREEN SLIME with a "
        "surprised face, held by thick BROWN ROOTS made of cubes that curl up out of the ground "
        "and wrap round its base, with two small green leaves on the roots.",
    ),
    "burrblight": (
        "epic",
        "BURR BLIGHT, orbs stack a poison. A spiky round dark-olive voxel BURR dripping three big "
        "bright GREEN poison drops made of cubes, each drop bigger than the last, with two small "
        "green bubbles beside it.",
    ),
    "boarrush": (
        "uncommon",
        "BOAR RUSH, the slam shoves enemies far back. A chunky voxel brown BOAR HEAD seen from the "
        "side, charging to the right with two big cream tusks, and three thick white speed lines of "
        "cubes behind it.",
    ),
    "ruincracks": (
        "epic",
        "RUIN CRACKS, the slam cracks what it hits. A chunky grey voxel STONE SHIELD split by a big "
        "jagged glowing ORANGE crack from top to bottom, with small stone chips of cubes flying off "
        "both sides.",
    ),
}


def main() -> None:
    for name, (_, what) in CARDS.items():
        (HERE / f"{name}.prompt.txt").write_text(HEAD + what + "\n", encoding="utf-8", newline="\n")
    script = """#!/usr/bin/env bash
# Thornwood's six cards (2026-11-18, docs/CLASS-CARDS.md): one Codex draw
# each on flat magenta, in the set's style, the prompt beside it
# (thornwood_cards_prompts.py writes the prompts).
# Then: python -I assets/ui/glow_toy_cards/compose_icon.py <icon> <rarity>
cd "$(dirname "$0")" || exit 1
REFS="-i ../../../../ui/glow_toy_cards/icons_transparent/frostorb.png -i ../../../../ui/glow_toy_cards/icons_transparent/poisontrail.png"
one() {
	name="$1"
	[ -f "${name}_raw.png" ] && return 0
	{ cat "${name}.prompt.txt"; printf '\\n\\nSave the image in the current directory as %s_raw.png\\n' "$name"; } \\
		| timeout 900 codex exec $REFS --skip-git-repo-check > "${name}.log" 2>&1
	ls -la "${name}_raw.png"
}
export -f one
export REFS
printf '%s\\n' NAMES \\
	| xargs -P 3 -I{} bash -c 'one {}'
""".replace("NAMES", " ".join(CARDS))
    (HERE / "thornwood_cards_2026_11_18.sh").write_text(script, encoding="utf-8", newline="\n")
    print(len(CARDS), "prompts")


if __name__ == "__main__":
    main()
