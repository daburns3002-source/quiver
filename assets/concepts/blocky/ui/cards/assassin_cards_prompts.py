"""Writes the Codex prompts for the Assassin's ten cards (2026-11-15,
docs/CLASS-CARDS.md), one `<icon>.prompt.txt` each, in the words the
class cards of 2026-11-13 were asked for.

    python -I assets/concepts/blocky/ui/cards/assassin_cards_prompts.py
    bash assets/concepts/blocky/ui/cards/assassin_cards_2026_11_15.sh
    python -I assets/ui/glow_toy_cards/compose_icon.py <icon> <rarity>
"""

import pathlib

HERE = pathlib.Path(__file__).resolve().parent

HEAD = (
    "Use case: a 2D game upgrade-card icon. Generate ONE square 1024x1024 image: a single icon "
    "centred on a FLAT, PURE MAGENTA background (#FF00FF) everywhere, no tile, no frame, no border, "
    "no text or letters, no shadow on the background. Copy EXACTLY the style of the attached "
    "reference icons: chunky pixel-voxel 3D built from small cubes, soft top-left light, a thick "
    "dark navy outline round every piece. Make it BIG, BOLD and SIMPLE, filling about 85% of the "
    "image, few details, clearly readable when shrunk to 48 px. Use NO magenta or hot pink in the "
    "icon itself. Every dagger has a pale steel blade and a handle wrapped in VIOLET cloth. "
)

CARDS = {
    "twinfangs": (
        "COMMON",
        "TWIN FANGS, the double stab hits harder. Two chunky voxel DAGGERS side by side, both "
        "pointing up and to the right, thrusting forward together, two short white speed lines of "
        "cubes behind them and a small yellow burst of sparks at their tips.",
    ),
    "backstab": (
        "UNCOMMON",
        "BACKSTAB, striking an enemy from behind hits harder. A chunky voxel round GREEN SLIME "
        "seen from BEHIND (no face), and one voxel DAGGER coming down into its back from the upper "
        "right, a yellow impact star of cubes where it lands.",
    ),
    "quickstep": (
        "UNCOMMON",
        "QUICKSTEP, a kill brings the dash back sooner. A chunky voxel BOOT with a small violet "
        "wing on its heel, dashing to the right, three violet speed lines of cubes behind it and a "
        "small circular refresh arrow of white cubes above it.",
    ),
    "serratededge": (
        "RARE",
        "SERRATED EDGE, a critical hit leaves the enemy open. One chunky voxel DAGGER, drawn "
        "large on a diagonal, whose blade edge is a row of big sharp SAW TEETH, with a bright RED "
        "jagged burst star of cubes behind the blade.",
    ),
    "bleed": (
        "RARE",
        "BLEED, strikes stack a bleed. One chunky voxel DAGGER pointing down with three big RED "
        "DROPS made of cubes falling in a line from its tip, each drop bigger than the last.",
    ),
    "poisontrail": (
        "RARE",
        "POISON TRAIL, the dash leaves a cloud of poison behind. Three chunky voxel bright GREEN "
        "POISON CLOUD puffs with small bubbles in a row, growing from left to right, and a violet "
        "dash streak of cubes shooting out of the biggest puff to the right.",
    ),
    "fanofknives": (
        "EPIC",
        "FAN OF KNIVES, every fourth strike throws a fan of knives. FIVE chunky voxel throwing "
        "KNIVES spread like an open hand fan from one point at the bottom centre, blades pointing "
        "outward and up, their violet handles meeting at the bottom.",
    ),
    "deathmark": (
        "LEGENDARY",
        "DEATH MARK, one enemy is marked and takes more damage. A chunky voxel VIOLET TARGET "
        "crosshair ring with four ticks, a small friendly round white SKULL of cubes in its "
        "centre, glowing violet.",
    ),
    "phantomblades": (
        "LEGENDARY",
        "PHANTOM BLADES, ghost daggers circle the hero and cut what they touch. THREE glowing "
        "pale CYAN ghost DAGGERS arranged evenly round a ring, each pointing along the circle "
        "clockwise, joined by a faint circular trail of small cyan cubes.",
    ),
    "thousandcuts": (
        "MYTHIC",
        "THOUSAND CUTS, shadows strike every enemy in turn. A dark VIOLET hooded SHADOW figure, "
        "head and shoulders, two glowing white eyes, with many bright white crossing SLASH lines "
        "of cubes radiating all round it like a star burst.",
    ),
}

for name, (rarity, subject) in CARDS.items():
    article = "an" if rarity[0] in "AEIOU" else "a"
    text = f"{HEAD}It is {article} {rarity} card. Subject: {subject}"
    (HERE / f"{name}.prompt.txt").write_text(text, encoding="utf-8")
    print(name, rarity)
