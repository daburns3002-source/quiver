"""One front view of each of Thornwood's fifteen bows, staffs and blades.

    python -I thornwood_single_prompts.py

Thornwood's weapons were designed and drawn in October (their sheets are
`thornwood/<name>_views.png`, docs/WEAPONS-THORNWOOD.md) and never built.
The owner (2026-11-18, "Yes, all fifteen") has them modelled in Tripo, and
Tripo wants ONE picture of the thing from the front. This writes a Codex
prompt per weapon that redraws its sheet's FRONT view alone and large (no
new design), and two scripts that run them, half each, side by side.

A bow's string is asked for as a thick bar: a thin one comes out of Tripo
as a ragged web (the golden bow, 2026-11-14).
"""
import pathlib

HERE = pathlib.Path(__file__).parent

# name, what it is
WEAPONS = [
    ("boar_tusk_bow", "bow"),
    ("plum_burr_bow", "bow"),
    ("lurker_vine_bow", "bow"),
    ("silkweaver_bow", "bow"),
    ("nightbarb_bow", "bow"),
    ("hedge_bulb_staff", "staff"),
    ("burr_totem_staff", "staff"),
    ("lurker_crest_staff", "staff"),
    ("silk_diadem_staff", "staff"),
    ("blackspine_staff", "staff"),
    ("boarback_blade", "greatsword"),
    ("plumguard_blade", "greatsword"),
    ("burrcrest_blade", "greatsword"),
    ("silkbound_blade", "greatsword"),
    ("briarbreaker_blade", "greatsword"),
]

POSE = {
    "bow": "upright, its limbs up and down and its string on the right, drawn as ONE thick straight bar from tip to tip (as thick as the grip, never a thin line), with no arrow on it",
    "staff": "upright, its head at the top and its foot at the bottom",
    "greatsword": "upright with the blade pointing up",
}

PROMPT = """Generate ONE square image at the highest resolution available and save it in the current directory as {name}_single.png

Image 1 is the design sheet of one of our game's weapons, a {kind}: the same {kind} drawn from the front, side, back, top and three-quarter, with labels, a projectile and colour swatches under it.
Redraw its FRONT view only, alone and large: exactly the same {kind}, the same shapes, block sizes, colours, materials, wraps, gems and glow, the same proportions. Add nothing and leave nothing out. Keep its blocky voxel style.
View: ONE single {kind} only, shown flat side-on, {pose}, straight-on camera, no perspective, centred, filling about 85 percent of the image. No hands, no character. This image will be turned into a 3D model.
Plain flat light-grey background, no scenery, no ground, no shadow, no text, no labels, no swatches, no projectile, no other views, no loose particles or sparkles round it. Even soft lighting.
"""


def main():
    halves = (WEAPONS[0::2], WEAPONS[1::2])
    for letter, half in zip("ab", halves):
        lines = ["#!/usr/bin/env bash", "# Thornwood's weapons, front view alone, from Codex (rule 9).", 'cd "$(dirname "$0")/thornwood" || exit 1']
        for name, kind in half:
            (HERE / "thornwood" / f"{name}_single.txt").write_text(
                PROMPT.format(name=name, kind=kind, pose=POSE[kind]), encoding="utf-8", newline="\n"
            )
            lines.append(
                f'timeout 900 codex exec -i {name}_views.png --skip-git-repo-check < {name}_single.txt 2>&1 | tail -20 > {name}_single.log; echo "=== {name} done"'
            )
        (HERE / f"thornwood_single_2026_11_18_{letter}.sh").write_text("\n".join(lines) + "\n", encoding="utf-8", newline="\n")
    print(len(WEAPONS), "prompts")


if __name__ == "__main__":
    main()
