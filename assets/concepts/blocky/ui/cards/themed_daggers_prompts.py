"""Writes the Codex prompts for the seven themed-set daggers' own effects
(owner, 2026-11-18, docs/CLASS-CARDS.md "The themed daggers' seven"), one
`<icon>.prompt.txt` each, in the words Thornwood's cards were asked for,
and the script that draws them.

    python -I assets/concepts/blocky/ui/cards/themed_daggers_prompts.py
    bash assets/concepts/blocky/ui/cards/themed_daggers_2026_11_18.sh
    python -I assets/ui/glow_toy_cards/compose_icon.py <icon> legendary
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
    "magenta, pink or purple-pink in the icon itself. "
)

# icon: what to draw (every one a Legendary's tile)
CARDS = {
    "wishingstar": (
        "WISHING STAR, a falling star bursts on what the daggers strike. A big chunky GOLD voxel "
        "FIVE-POINTED STAR falling diagonally down to the right, a trail of small pale-yellow and "
        "white sparkle cubes behind it, and a small burst of white cube sparks under its lowest point."
    ),
    "spurrowel": (
        "SPUR ROWEL, a spinning spur wheel bounces from enemy to enemy. A big chunky voxel cowboy "
        "SPUR ROWEL: a round brass-gold hub with eight sharp TURQUOISE spikes all round it like a star "
        "wheel, tilted a little, with three curved white motion arcs of cubes round it showing it "
        "spinning, and two small tan dust puffs below it."
    ),
    "splashwave": (
        "SPLASH WAVE, a strike splashes water out round the enemy. A big chunky voxel WATER SPLASH: a "
        "crown of bright light-blue water made of cubes bursting up and outward, with five big round "
        "water DROPLETS flying out from it and a white foam ring of cubes at its base."
    ),
    "combocounter": (
        "COMBO COUNTER, every strike that lands adds power until you are hit. A chunky GOLD voxel "
        "arcade COIN TOKEN with a star stamped on its face, and beside it three RED pixel-block bars "
        "rising left to right like a power meter, the tallest with a small white up arrow of cubes "
        "over it."
    ),
    "cometcrash": (
        "COMET CRASH, a comet falls on the enemy the daggers marked. A big chunky voxel COMET: a "
        "glowing VIOLET-and-white rock of cubes falling down to the left, with a long tail of deep "
        "purple and pale lilac cubes streaming up behind it, and a small cracked dark crater ring of "
        "cubes under it."
    ),
    "bellchime": (
        "BELL CHIME, the bell's ring holds enemies still. A big chunky GOLD voxel temple BELL with a "
        "red cord knot on top and a round clapper showing below, swinging a little, with two curved "
        "white sound-ring arcs of cubes on each side of it."
    ),
    "lavaburst": (
        "LAVA BURST, the double stab sends lava bursting along the ground. Three chunky voxel LAVA "
        "ERUPTIONS in a row going away into the distance, each a fountain of glowing ORANGE and yellow "
        "cubes bursting out of a cracked dark rock, the nearest the biggest, with small ember cubes "
        "flying up."
    ),
}


def main() -> None:
    for name, what in CARDS.items():
        (HERE / f"{name}.prompt.txt").write_text(HEAD + what + "\n", encoding="utf-8", newline="\n")
    script = """#!/usr/bin/env bash
# The themed daggers' seven cards (2026-11-18, docs/CLASS-CARDS.md): one
# Codex draw each on flat magenta, in the set's style, the prompt beside it
# (themed_daggers_prompts.py writes the prompts). Codex's sandbox may not
# write here: its image is then in ~/.codex/generated_images/, named in the log.
# Then: python -I assets/ui/glow_toy_cards/compose_icon.py <icon> legendary
cd "$(dirname "$0")" || exit 1
REFS="-i ../../../../ui/glow_toy_cards/icons_transparent/frostorb.png -i ../../../../ui/glow_toy_cards/icons_transparent/phantomblades.png"
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
	| xargs -P 4 -I{} bash -c 'one {}'
""".replace("NAMES", " ".join(CARDS))
    (HERE / "themed_daggers_2026_11_18.sh").write_text(script, encoding="utf-8", newline="\n")
    print(len(CARDS), "prompts")


if __name__ == "__main__":
    main()
