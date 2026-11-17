"""Write Codex's prompts for the Assassin's daggers that no area has yet.

    python -I dagger_prompts.py

The Assassin opened on 2026-11-16 with daggers designed for the Mossy Glade
and Bogheart only. This writes one prompt per pair for Thornwood, the
Drowned Village and the Golden Daggers (class level 10), beside the other
classes' art in each area's folder, and `daggers_2026_11_16.sh` runs them.

Each picture is ONE dagger, not the pair: the game holds a copy in each
hand, and Bogheart's five were modelled as a pair in one mesh, which cannot
be held that way. The shop and gear pictures cross two copies of it.
"""
import pathlib

HERE = pathlib.Path(__file__).parent

STYLE = (
    "Image 1 is a style reference for our game's daggers (match its blocky voxel style, chunky "
    "proportions and finish, but NOT its designs or colours). Image 2 is a weapon from the same area "
    "of the game: match its palette and materials, not its shape."
)
VIEW = (
    "View: ONE single dagger only (not a pair), shown flat side-on, upright with the blade pointing up, "
    "straight-on camera, no perspective, centred, filling about 85 percent of the image. A short "
    "one-handed dagger: the blade about twice the length of the handle, a small crossguard, a wrapped "
    "grip and a pommel. Simple chunky blocks, no fine filigree. No hands, no character. This image is "
    "the weapon's in-game picture and will be turned into a 3D model.\n"
    "Plain flat light-grey background, no scenery, no ground, no shadow, no text, no labels, no "
    "particles. Even soft lighting."
)

# area folder, palette reference, then (file, NAME, tier, look)
SETS = [
    (
        "thornwood",
        "silkbound_blade_views.png",
        "Thornwood: a dark bramble wood. Hedge green, bramble plum and maroon, cream thorns, boar brown, "
        "and its spider boss's purple, olive-gold and magenta.",
        [
            ("hedge_prickers", "HEDGE PRICKERS", "Uncommon", "a long cream thorn for a blade, set in a hedge-green wooden handle bound with brown cord, a single small leaf at the guard"),
            ("tusk_knives", "TUSK KNIVES", "Rare", "a curved ivory boar tusk for a blade, a chunky brown leather grip with a dark iron band for a guard and a tuft of bristle at the pommel"),
            ("burrfang_daggers", "BURRFANG DAGGERS", "Epic", "a plum-purple bramble blade with two cream thorn barbs on its back edge, a maroon wrapped grip and a round spiky burr for a pommel, a faint magenta glow in the blade's centre groove"),
            ("silkfang_daggers", "SILKFANG DAGGERS", "Legendary", "a glossy dark spider fang for a blade with an olive-gold edge, bound to a purple handle with white spider silk, a square magenta gem in the guard; glowing softly magenta"),
            ("lurker_claws", "LURKER CLAWS", "Mythic", "a hooked black-green claw blade wrapped in living vine, a glowing magenta eye set in the guard, thorns of light along the back edge; glowing brightly, magenta and green"),
        ],
    ),
    (
        "drowned",
        "tollguard_blade_views.png",
        "the Drowned Village: a flooded village under grey rain. Slate grey, driftwood, rope, teal water, "
        "barnacles, verdigris bronze, and its bell-ringer boss's sunken bronze bell.",
        [
            ("driftwood_dirks", "DRIFTWOOD DIRKS", "Uncommon", "a chipped slate-grey stone blade lashed with tan rope to a pale grey driftwood handle"),
            ("barnacle_knives", "BARNACLE KNIVES", "Rare", "a dark iron blade with a teal edge, three white barnacles on the flat, a rope-wrapped grip and a small iron ring pommel"),
            ("eeltooth_daggers", "EELTOOTH DAGGERS", "Epic", "a curved eel-blue blade with a pale belly edge and a yellow fin for a guard, a dark wrapped grip, a faint electric-yellow glow along the edge"),
            ("tollbell_daggers", "TOLLBELL DAGGERS", "Legendary", "a bronze bell-metal blade green with verdigris at its base, a chunky bronze guard and a small bronze bell for a pommel; glowing softly teal"),
            ("riptide_fangs", "RIPTIDE FANGS", "Mythic", "a blade of glowing sea-glass crystal, teal to white at the tip, rising out of a guard shaped like a curling wave, a pearl in the pommel; glowing brightly, teal and white"),
        ],
    ),
    (
        "golden",
        "golden_blade.png",
        "the golden weapons: a trophy a player earns by mastering a class, regal, clean and bright. "
        "Polished yellow gold with darker amber-gold shading on the block sides; no rust, no moss.",
        [
            ("golden_daggers", "GOLDEN DAGGERS", "Legendary", "a dagger cast in polished gold, a broad gold blade with a brighter white-gold cutting edge and a shallow centre groove, a small winged gold crossguard with one square ruby-red gem in its middle, a brown leather-wrapped hilt and a gold block pommel; glowing softly gold"),
        ],
    ),
]


def main():
    lines = ["#!/usr/bin/env bash", "# The Assassin's missing daggers from Codex (rule 9), one front view each.", 'cd "$(dirname "$0")" || exit 1']
    for area, palette, world, rows in SETS:
        for name, title, tier, look in rows:
            text = (
                f"Generate ONE square image at the highest resolution available and save it in the current directory as {name}.png\n\n"
                f"{STYLE} Draw a new weapon for {world}\n"
                f"{title} ({tier} dagger): {look}.\n"
                f"{VIEW}\n"
            )
            (HERE / area / f"{name}.txt").write_text(text, encoding="utf-8", newline="\n")
            lines.append(
                f'(cd {area} && timeout 900 codex exec -i ../forest/glimmerhorn_daggers_views.png -i {palette} --skip-git-repo-check < {name}.txt 2>&1 | tail -20 > {name}.log; echo "=== {name} done")'
            )
    (HERE / "daggers_2026_11_16.sh").write_text("\n".join(lines) + "\n", encoding="utf-8", newline="\n")
    print(sum(len(r) for *_, r in SETS), "prompts")


if __name__ == "__main__":
    main()
