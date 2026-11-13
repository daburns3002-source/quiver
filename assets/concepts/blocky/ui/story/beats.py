"""Draws the area story beats' stills with ChatGPT Codex (owner's rule): four
stills for each boss's first defeat, the story the owner approved on
2026-11-13 ("the bog is rising": `Config/StoryBeats`). Each lands in
beats_raw/<name>.png (1536 x 1024; the beat shows its middle 16:9 band, cut by
assets/ui/story/cut_beats.py).

    python -I assets/concepts/blocky/ui/story/beats.py            # all sixteen
    python -I assets/concepts/blocky/ui/story/beats.py b1a b2c    # just these
"""

import re
import shutil
import subprocess
import sys
from concurrent.futures import ThreadPoolExecutor
from pathlib import Path

HERE = Path(__file__).resolve().parent
ASSETS = HERE.parents[3]
RAW = HERE / "beats_raw"
GENERATED = Path.home() / ".codex" / "generated_images"
WORKERS = 4

FRAMES = ASSETS / "ui" / "story" / "frames"
ICONS = ASSETS / "ui" / "boss_banner" / "icons"
ARENAS = ASSETS / "concepts" / "blocky" / "arenas"
ITEMS = ASSETS / "ui" / "shop" / "icons"

CHEST = FRAMES / "f02d.jpg"  # the opening's style: King Bloblin's chest
HEROES = FRAMES / "f22b.jpg"  # the three heroes, front
BEHIND = FRAMES / "f23a.jpg"  # the three heroes from behind
KING = ICONS / "boss01_king_bloblin.png"
BROOD = ICONS / "boss02_broodmother.png"
CRAB = ICONS / "boss03_old_tollcrab.png"
GULP = ICONS / "boss04_grandmother_gulp.png"
ROC = ICONS / "boss05_tempest_roc.png"
GLADE = ARENAS / "area01_mossy_glade.jpg"
THORN = ARENAS / "area02_thornwood.jpg"
VILLAGE = ARENAS / "area03_drowned_village_v2.png"
CAVES = ARENAS / "area04_bogheart_caverns_v2.png"
CLIFFS = ARENAS / "area05_windswept_cliffs.jpg"

STYLE = """Style: exactly the 2D blocky pixel-art look of the FIRST attached image (a frame of the game's opening cutscene): chunky pixels, flat 2-3 tone shading, thick near-black ink outlines, bright saturated colours, cube-shaped leaves, blocks and stones. No smooth gradients, no blur, no 3D rendering, no photo look.

The three HEROES, when they are in the frame, exactly as in the opening cutscene: the ARCANIST, a girl with long brown hair, deep-blue robe with gold trim, blue hood, wooden staff topped with a green crystal; the RANGER, green hood and tunic, wooden bow, quiver of arrows; the WARDEN, red cap, long red cape, brown leather armour, big wooden greatsword.

A WANTED POSTER, when it is in the frame, has NO WORDS AND NO LETTERS AT ALL: cream parchment with torn edges, nailed up by its corners, a big 2D pixel icon of the named boss's face in the middle, a little drawing of a treasure chest under it as the reward."""

FRAMING = """Output ONE image, 1536 x 1024, a single full-screen frame of a 2D cutscene (not a storyboard page): no panel border, no number, no text, no letters, no words anywhere in the picture. It will be cropped to 16:9, so keep everything important inside the middle band; the top 80 px and bottom 80 px must be only extendable background (sky, canopy, ground, water, cave rock). Leave the bottom fifth of the picture calm (ground or water, no faces), because a line of words is laid over it."""


def still(refs: list[Path], who: str, scene: str) -> dict:
    return {
        "refs": refs,
        "prompt": f"""Use your image generation tool to draw one finished, detailed cutscene frame for a cute blocky archery adventure game.

Attached, in order: {who}

The frame: {scene}

{FRAMING}

{STYLE}""",
    }


STILLS = {
    # 1 Mossy Glade: King Bloblin beaten
    "b1a": still(
        [CHEST, KING, GLADE],
        "a frame of the opening cutscene (the style, the glade and the slime-covered treasure chest), King Bloblin's face icon, the Mossy Glade.",
        "KING BLOBLIN, beaten: the huge lime-green cube slime has slumped and melted into a big wobbly puddle-blob in the middle of the sunny Mossy Glade, dizzy swirl eyes, his gold block crown with the green gem tipped off and lying on the grass beside him. His HUGE brown wooden treasure chest with gold bands, dripping with green slime, stands shut behind him. Little cube slimes peek out from behind stumps. Light rays, fireflies.",
    ),
    "b1b": still(
        [CHEST, ITEMS / "RoyalJelly.png", GLADE],
        "a frame of the opening cutscene (the style and the treasure chest), the ROYAL JELLY icon, the Mossy Glade.",
        "Close on KING BLOBLIN's HUGE brown wooden treasure chest with gold bands as its lid bursts open: instead of gold, a big gushing wave of murky BOG WATER pours out of it, dark green-brown and muddy with bubbles, duckweed and little reeds in it, a few gold coins swept away in the flood. Floating on top of the wave, glowing gold, is a jar of ROYAL JELLY drawn like the attached icon. Splashes and droplets everywhere, the sunny glade behind.",
    ),
    "b1c": still(
        [CHEST, GLADE, THORN],
        "a frame of the opening cutscene (the style), the Mossy Glade, the Thornwood.",
        "A wide shot from low over the grass: a shining wet SLIME TRAIL of green goo and puddles of bog water runs from the open treasure chest (small in the left foreground) across the sunny Mossy Glade and away into the edge of the THORNWOOD on the right: a dark wood of purple-black thorn brambles and twisted trees with magenta glowing buds, gloomy under its canopy, as in the attached Thornwood picture. The trail leads straight into the dark gap between the brambles.",
    ),
    "b1d": still(
        [BEHIND, BROOD, THORN],
        "a frame of the opening cutscene (the style and the three heroes seen from behind), THE BROODMOTHER's face icon, the Thornwood.",
        "The three HEROES seen from behind, standing in the lower left and middle, looking up at a WANTED POSTER nailed to a huge twisted thorn tree at the dark purple edge of the THORNWOOD. The poster shows THE BROODMOTHER's face exactly like her attached icon (a spider queen, bramble legs, glowing magenta eyes). The Warden grips his greatsword, the Ranger has an arrow ready, the Arcanist's crystal glows. Purple gloom and thorns ahead, a little sunny glade light behind them.",
    ),
    # 2 Thornwood: the Broodmother beaten
    "b2a": still(
        [CHEST, BROOD, THORN],
        "a frame of the opening cutscene (the style), THE BROODMOTHER's face icon, the Thornwood.",
        "THE BROODMOTHER, beaten: the big spider queen with bramble legs and a glowing magenta abdomen lies curled up on her back in a heap in the middle of the dark purple THORNWOOD, legs folded, dizzy swirl eyes, a few little thorn spiders scurrying away. Behind her a great web stretches between two thorn trees, filling the background. Purple gloom, glowing magenta buds.",
    ),
    "b2b": still(
        [CHEST, THORN, VILLAGE],
        "a frame of the opening cutscene (the style), the Thornwood, the Drowned Village.",
        "The Broodmother's GREAT WEB tearing and falling away between two thorn trees, strands snapping and drifting down like ribbons, and the brambles behind it parting: through the gap, a warm golden-teal dusk light shines in from beyond the wood. Leaves and web threads float in the air.",
    ),
    "b2c": still(
        [CHEST, VILLAGE, THORN],
        "a frame of the opening cutscene (the style), the Drowned Village, the Thornwood.",
        "A wide view from the edge of the Thornwood (a few purple thorns framing the top corners): an old cobbled road winds DOWNHILL to a VILLAGE HALF UNDER WATER, as in the attached Drowned Village picture: wooden houses sunk to their windows in still teal water, crooked roofs and chimneys poking out, a stone church tower standing in the middle of the flood with an EMPTY bell arch, lanterns glowing on posts, mist on the water, a calm teal-and-orange dusk sky.",
    ),
    "b2d": still(
        [BEHIND, CRAB, VILLAGE],
        "a frame of the opening cutscene (the style and the three heroes seen from behind), OLD TOLLCRAB's face icon, the Drowned Village.",
        "The three HEROES seen from behind, standing at the end of the cobbled road where it runs into the flood water, looking at a WANTED POSTER nailed to a crooked wooden signpost sticking out of the water. The poster shows OLD TOLLCRAB exactly like his attached icon (a giant hermit crab living in a green-bronze church bell). Beyond, the drowned village: roofs in teal water, the church tower, lanterns, dusk.",
    ),
    # 3 Drowned Village: Old Tollcrab beaten
    "b3a": still(
        [CHEST, CRAB, VILLAGE],
        "a frame of the opening cutscene (the style), OLD TOLLCRAB's face icon, the Drowned Village.",
        "OLD TOLLCRAB, beaten: the giant hermit crab has toppled onto his back in the shallow teal water of the drowned village square, claws limp, dizzy swirl eyes; his green-bronze church-bell shell rings one last time: big clean golden sound rings ripple out from the bell across the water. Half-sunk houses around, lanterns, dusk.",
    ),
    "b3b": still(
        [CHEST, VILLAGE, CAVES],
        "a frame of the opening cutscene (the style), the Drowned Village, Bogheart Caverns.",
        "The flood DRAINING AWAY: the teal water of the drowned village swirls in a big whirlpool and pours down into a hole that has opened under the stone church tower, revealing wet cobbles, muddy doorsteps and puddles; boats and barrels left tilted in the mud. From the hole under the church a deep teal-cyan glow shines up, the light of a cave below.",
    ),
    "b3c": still(
        [CHEST, CAVES, GULP],
        "a frame of the opening cutscene (the style), Bogheart Caverns, GRANDMOTHER GULP's face icon.",
        "Looking down into the dark mouth of BOGHEART CAVERNS under the church: a deep cave of dark blue-purple rock lit by glowing teal and cyan fungus and mushrooms, as in the attached cavern picture, the last of the flood water pouring down into the dark. Deep in the blackness, two HUGE glowing yellow toad eyes have just opened, and the water is being sucked toward them: GULP. Spooky but cute.",
    ),
    "b3d": still(
        [BEHIND, GULP, CAVES],
        "a frame of the opening cutscene (the style and the three heroes seen from behind), GRANDMOTHER GULP's face icon, Bogheart Caverns.",
        "The three HEROES seen from behind, standing at the top of slippery stone steps leading down into the glowing cave under the church, looking at a WANTED POSTER stuck to the wet cave wall. The poster shows GRANDMOTHER GULP exactly like her attached icon (an enormous warty toad with glowing fungus on her back). The cave below glows teal and cyan with mushrooms.",
    ),
    # 4 Bogheart Caverns: Grandmother Gulp beaten
    "b4a": still(
        [CHEST, GULP, ITEMS / "BogPearl.png"],
        "a frame of the opening cutscene (the style), GRANDMOTHER GULP's face icon, the BOGHEART PEARL icon.",
        "GRANDMOTHER GULP, beaten, in her glowing fungus cavern: the enormous warty toad, cheeks bulging, SPITS OUT a big round glowing pearl, the BOGHEART PEARL (drawn like the attached icon, without its pouch: a big luminous pearl with a lime and purple shine), which flies out in a burst of bog water and sparkles. Her eyes are dizzy swirls. Teal and cyan mushrooms glow around.",
    ),
    "b4b": still(
        [CHEST, VILLAGE],
        "a frame of the opening cutscene (the style), the Drowned Village (as it was under water).",
        "THE VILLAGE DRIED OUT in warm morning sunshine: the same village as the attached picture but the flood is gone: wooden houses standing on dry cobbled streets, steaming puddles drying, laundry hung out, flowers coming back in window boxes, the stone church tower with its bell arch, little fish flopping back into a small pond, a blue morning sky. Peaceful and happy.",
    ),
    "b4c": still(
        [CHEST, GLADE, CLIFFS],
        "a frame of the opening cutscene (the style), the Mossy Glade, the Windswept Cliffs.",
        "THE WIND TURNS: a strong wind blowing across a sunny hillside meadow, grass bending, leaves and petals streaming in long swirls across the sky; far away on the horizon rise tall pale WINDSWEPT CLIFFS under a stormy grey-blue sky with swirling clouds, as in the attached cliffs picture. Caught in the wind, a single small cream parchment poster tumbles through the air toward the viewer.",
    ),
    "b4d": still(
        [BEHIND, ROC, CLIFFS],
        "a frame of the opening cutscene (the style and the three heroes seen from behind), THE TEMPEST ROC's face icon, the Windswept Cliffs.",
        "The three HEROES seen from behind, the Ranger holding up a WANTED POSTER that the wind has just blown into his hands, the other two leaning in to look. The poster shows THE TEMPEST ROC exactly like its attached icon (a huge storm bird). Ahead of them, across the meadow, the tall pale WINDSWEPT CLIFFS under swirling storm clouds, a flash of lightning far off. Capes and hair blowing in the wind.",
    ),
}


def run(name: str, job: dict) -> str:
    out = RAW / f"{name}.png"
    args = ["codex", "exec", "--skip-git-repo-check", "-s", "read-only"]
    for ref in job["refs"]:
        args += ["-i", str(ref)]
    args.append("-")
    done = subprocess.run(
        args, input=job["prompt"], capture_output=True, text=True, encoding="utf-8", shell=True
    )
    log = done.stdout + done.stderr
    (RAW / f"{name}.log").write_text(log, encoding="utf-8")
    match = re.search(r"session id: ([0-9a-f-]+)", log)
    if not match:
        return f"{name}: no session id"
    images = sorted((GENERATED / match.group(1)).glob("*.png"))
    if not images:
        return f"{name}: no image"
    shutil.copy(images[-1], out)
    return f"{name}: ok"


def main() -> None:
    names = sys.argv[1:] or list(STILLS)
    RAW.mkdir(exist_ok=True)
    with ThreadPoolExecutor(WORKERS) as pool:
        for line in pool.map(lambda n: run(n, STILLS[n]), names):
            print(line, flush=True)


if __name__ == "__main__":
    main()
