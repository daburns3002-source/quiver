"""Draws the story cutscene's frames with ChatGPT Codex (owner's rule), from
the approved storyboard (storyboard_b1.png beats 1-12, storyboard_b2.png
beats 13-24, owner 2026-10-25) and the Slime Soldier sheet.

Key frames are drawn from their storyboard panel; in-between frames are
edits of their key frame, so the characters and the place stay the same.
Each frame lands in raw/<name>.png (1536 x 1024; the cutscene shows its
middle 16:9 band, cut by cut.py).

    python -I assets/concepts/blocky/ui/story/frames.py keys
    python -I assets/concepts/blocky/ui/story/frames.py tweens
    python -I assets/concepts/blocky/ui/story/frames.py bows       # the Ranger's bow fixed
    python -I assets/concepts/blocky/ui/story/frames.py keys f11 f13a   # just these
"""

import re
import shutil
import subprocess
import sys
from concurrent.futures import ThreadPoolExecutor
from pathlib import Path

HERE = Path(__file__).resolve().parent
ASSETS = HERE.parents[3]
RAW = HERE / "raw"
GENERATED = Path.home() / ".codex" / "generated_images"
WORKERS = 4

SHEET_1 = HERE / "storyboard_b1.png"
SHEET_2 = HERE / "storyboard_b2.png"
SOLDIER = HERE / "slime_soldier.png"
KING = ASSETS / "ui" / "boss_banner" / "icons" / "boss01_king_bloblin_attack.png"
TWIG_BOW = ASSETS / "concepts" / "blocky" / "weapons" / "skins" / "forest" / "twig_bow_views.jpg"
HEROES = ASSETS / "concepts" / "blocky" / "ui" / "intro" / "title.png"

STYLE = """Style: exactly the 2D blocky pixel-art look of the attached storyboard page: chunky pixels, flat 2-3 tone shading, thick near-black ink outlines, bright saturated colours, a sunny Mossy Glade forest of cube-leafed trees, grass blocks, mossy stones, stumps, little orange spotted mushrooms, fireflies, light rays. No smooth gradients, no blur, no 3D rendering.

Characters, exactly as on the storyboard page and the references:
- KING BLOBLIN (his 2D icon sheet attached): a huge cube-shaped lime-green slime, a gold block crown with a green gem, glowing yellow square eyes under dark brows, a cloak of dark-green moss/leaf cubes with little cube slimes riding on it, a brown strap with a gold green-gem clasp, big cube fists. He sits on a big mossy stone throne in the middle of the glade; a HUGE brown wooden treasure chest with gold bands and studs, covered and dripping with thick green slime, stands directly behind him.
- the SLIME SOLDIER (his design sheet attached): a small cube lime-green slime, iron pot helmet with a leaf plume, square amber eyes, a twig spear, a brown strap with a gold buckle, and a round wooden shield painted with a small KING BLOBLIN FACE ICON (green cube face, gold crown, yellow eyes), NOT a crown.
- the three HEROES (as on the storyboard page; seen from behind in the title picture attached): the ARCANIST, a girl with long brown hair, deep-blue robe with gold trim, blue hood, wooden staff topped with a green crystal; the RANGER, green hood and tunic, wooden bow, quiver of arrows; the WARDEN, red cap, long red cape, brown leather armour, big wooden greatsword.
- THE SCROLL is a WANTED poster with NO WORDS AND NO LETTERS AT ALL: cream parchment; at the top a big 2D pixel icon of King Bloblin's face (as on his icon sheet: green cube face, gold crown with green gem, angry yellow eyes); under it a small arrow pointing to a 2D pixel icon of his treasure chest (brown wood, gold bands, dripping green slime) as the reward; along the bottom three square class icons side by side, each with a little scribbled signature mark under it as if signed up: green-framed with a wooden bow (Ranger), blue-framed with a wooden staff topped by a green crystal (Arcanist), red-framed with a wooden greatsword (Warden)."""

FRAMING = """Output ONE image, 1536 x 1024, a single full-screen frame of a 2D cutscene (not a storyboard page): no panel border, no number, no text, no letters anywhere. It will be cropped to 16:9, so keep everything important inside the middle band; the top 80 px and bottom 80 px must be only extendable background (sky, canopy, grass)."""


def key(sheet: Path, panel: int, scene: str) -> dict:
    return {
        "refs": [sheet, KING, SOLDIER, HEROES],
        "prompt": f"""Use your image generation tool to draw panel {panel} of the FIRST attached image (an approved storyboard page; the panels are numbered in their top-left corners) as one finished, detailed, full-size cutscene frame: the same composition, camera, characters and place as that panel, drawn larger and cleaner.

The frame: {scene}

{FRAMING}

{STYLE}""",
    }


def tween(base: str, change: str) -> dict:
    return {
        "base": base,
        "refs": [KING, SOLDIER],
        "prompt": f"""Use your image generation tool to EDIT the FIRST attached image (a frame of a 2D pixel-art cutscene, 1536 x 1024). Output ONE image of exactly the same size: the NEXT frame of the animation, identical to the input in every pixel (camera, background, lighting, colours, style, every character's look) except for this one change:

{change}

Nothing else moves or changes. No text, no letters, no border.

{STYLE}""",
    }


def bow(base: str, how: str) -> dict:
    """The Ranger's bow redrawn as the Twig Bow (owner, 2026-10-25: "make sure
    the bow in each frame does not look ai and actually looks like a bow")."""
    return {
        "base": base,
        "refs": [TWIG_BOW],
        "prompt": f"""Use your image generation tool to EDIT the FIRST attached image (a frame of a 2D pixel-art cutscene, 1536 x 1024). Output ONE image of exactly the same size, identical in every pixel except for ONE change: redraw the RANGER's bow (the hero in the green hood) so it is clearly a real, well-made bow: the TWIG BOW from the SECOND attached image (its design sheet), drawn in the frame's 2D pixel-art style with a dark ink outline: ONE bow only, a single continuous curved wooden limb made of chunky brown segments, a green-wrapped grip with a gold ring above and below it in the middle, a little green leaf cluster with a gold ring at each tip, and ONE thin straight pale string. {how} No second string, no crossing lines, no broken or doubled limbs, no extra bows. Everything else in the frame stays exactly the same. No text.""",
    }


KEYS = {
    "f01": key(SHEET_1, 1, "high above the sunny forest canopy at morning, sun rays, a waterfall, the glade a small clearing far below with the tiny king in it."),
    "f02a": key(SHEET_1, 2, "the view sinks into the clearing: King Bloblin in the middle on his mossy stone throne, small in the frame, the huge slimy chest directly behind him, the whole sunny glade around, stone steps up to the throne."),
    # the chest's own shot (owner, 2026-10-25: "the chest in the cutscene should
    # have its own frame and should look over the top"), drawn from f02a's chest
    "f02c": {
        "refs": [RAW / "f02a.png", KING, SOLDIER],
        "prompt": f"""Use your image generation tool to draw one finished, detailed, full-size cutscene frame: a dramatic close-up of the HUGE treasure chest that stands behind King Bloblin's throne in the FIRST attached image (a frame of the same cutscene). It is the SAME chest (same brown wood planks, same gold bands and studs, same green slime), seen up close from a low angle so it towers over us and fills most of the frame, and made gloriously OVER THE TOP: enormous and bulging, its lid straining half open with a blinding golden light blasting out from inside, mountains of gold coins, sparkling gems (emerald, ruby, sapphire), gold goblets, a jewelled sword hilt and pearl necklaces spilling over its rim and cascading down its front onto the grass; extra gold corner caps and a giant gold lock with a green gem shaped like King Bloblin's face; thick glossy green slime oozing over the lid and dripping down in long strands, slime puddles; sparkles and glints everywhere; two tiny slime soldiers standing guard at its feet, dwarfed by it. The top of King Bloblin's crown peeks in at the bottom edge in front of it.

{FRAMING}

{STYLE}""",
    },
    "f03a": key(SHEET_1, 3, "closer: King Bloblin lounging on his throne, eyes half-closed, content and lazy, little slimes dozing on his cloak, the slimy chest behind him."),
    "f04a": key(SHEET_1, 4, "King Bloblin starting a huge yawn: eyes squeezed shut, square mouth half open, arms stretching."),
    "f05a": key(SHEET_1, 5, "the bushes at the right edge of the glade by a stump, still and quiet, a mossy stone wall and mushrooms; nobody in sight yet."),
    "f06a": key(SHEET_1, 6, "the slime soldier bursts out of the bushes running toward the left, the rolled scroll held high over his head, a puff of dust behind him."),
    "f07a": key(SHEET_1, 7, "the slime soldier skids to a stop at the foot of the throne, slime splashing round his feet, sweat drops; the king above, eyes half-closed."),
    "f08a": key(SHEET_1, 8, "the slime soldier holds the rolled scroll up with both stubby arms toward the king; the king leans down from his throne, peering at it with one brow raised."),
    "f09": key(SHEET_1, 9, "the king's big cube hand plucks the rolled scroll from the slime soldier's arms."),
    "f10a": key(SHEET_1, 10, "the king starts unrolling the scroll in both hands, curious, the paper half open toward him (we see its plain back)."),
    "f11": key(SHEET_1, 11, "close-up of the open WANTED poster scroll filling the frame, held at its edges by the king's big green fingers, the glade blurred behind. Draw the poster exactly as described below, with no words at all."),
    "f12a": key(SHEET_1, 12, "extreme close-up of King Bloblin's eyes peeking over the top edge of the scroll, eyes normal, brows level."),
    "f13a": key(SHEET_2, 13, "close-up: King Bloblin's face going darker green, brows slammed down, eyes glowing hot, steam puffs from his head, holding the open WANTED poster toward us (drawn as described below, no words), his hands trembling."),
    "f14a": key(SHEET_2, 14, "King Bloblin crumples the poster in one fist, paper bits flying; the slime soldier at the right backs away, sweating."),
    "f15a": key(SHEET_2, 15, "low angle: King Bloblin rising up from his throne, huge, his shadow falling over the tiny slime soldier, the slimy chest behind him."),
    "f16a": key(SHEET_2, 16, "King Bloblin takes a giant breath: body swelling, cheeks puffed, eyes squeezed shut, steam puffs, the little slimes on his cloak clinging on."),
    "f17a": key(SHEET_2, 17, "close-up: King Bloblin ROARS, a huge open square mouth, slime spraying, a pale shockwave ring and light rays bursting from him, cubes flying."),
    "f18a": key(SHEET_2, 18, "wide: the roar's shockwave rings sweep across the glade from the king, leaves and white birds blasting off the trees, the chest's slime splashing, the slime soldier tumbling backward at the right."),
    "f19": key(SHEET_2, 19, "a WIDE forest panorama for a camera pan from left to right (King Bloblin is NOT in it: the heroes and the king never share a frame): at the far LEFT edge the forest by the glade where the roar comes from; across the middle the roar's pale shockwave rings rolling through the cube trees, leaves streaming to the right; at the far RIGHT edge a mossy forest path at the edge of the woods where the three heroes stand small, turning toward the roar."),
    "f20a": key(SHEET_2, 20, "at the edge of the forest by a mossy path, the three heroes (seen from the front) as the shockwave reaches them: leaves blowing past, they spin round startled, yellow '!' marks over their heads."),
    "f21a": key(SHEET_2, 21, "close-up of the three heroes' faces reacting: the Arcanist gasping, the Ranger wide-eyed, the Warden gritting his teeth."),
    "f22a": key(SHEET_2, 22, "the three heroes share a determined look and grip their weapons, leaves still drifting."),
    "f23a": key(SHEET_2, 23, "the three heroes run away from us into the forest down a stone path between the cube trees, seen from behind, mid stride."),
    "f24": key(SHEET_2, 24, "the three heroes small in the distance, disappearing into the shadowy trees down the stone path; the edges of the picture darkened toward black."),
}

BOWS = {
    "f20a": bow("f20a", "He holds it low in one hand at his side; the string runs straight from the top tip to the bottom tip."),
    "f20b": bow("f20b", "He holds it low in one hand at his side, ready; the string runs straight from the top tip to the bottom tip."),
    "f22a": bow("f22a", "He holds it upright in his left hand by the grip, an arrow resting against it; the string runs straight from the top tip to the bottom tip."),
    "f22b": bow("f22b", "He holds it upright in his left hand by the grip, drawing an arrow: the arrow rests on the grip pointing forward, its back end nocked on the string at his right hand by his cheek, and the string runs in two straight lines from the top tip to his hand and from his hand to the bottom tip, forming one clean V."),
    "f23a": bow("f23a", "It is slung across his back as he runs, upright; the string runs straight from tip to tip."),
    "f23b": bow("f23b", "It is slung across his back as he runs, upright; the string runs straight from tip to tip."),
    "f23c": bow("f23c", "It is slung across his back as he runs, upright; the string runs straight from tip to tip."),
}

# the poster's words (owner, 2026-10-25: "the scroll should say wanted: 'king
# bloblin icon' reward: 'chest icon'")
WORDS = """Change ONLY the WANTED poster (the cream parchment with the icons): rearrange its top part so it reads, in big chunky dark-brown pixel capital letters with a thin dark outline, the word "WANTED:" on its own line at the very top, then King Bloblin's face icon under it; then a line with the word "REWARD:" followed by the treasure chest icon to the right of it (remove the little arrow). Keep the three signed class icons along the bottom exactly as they are. Spell the two words exactly: WANTED: and REWARD:. No other words anywhere."""

POSTERS = {
    "f11": {"base": "f11", "refs": [KING], "prompt": f"Use your image generation tool to EDIT the FIRST attached image (a frame of a 2D pixel-art cutscene, 1536 x 1024). Output ONE image of exactly the same size, identical in every pixel except: {WORDS}"},
    "f13b": {"base": "f13b", "refs": [KING, RAW / "f13a.png"], "prompt": f"Use your image generation tool to EDIT the FIRST attached image (a frame of a 2D pixel-art cutscene, 1536 x 1024). Output ONE image of exactly the same size, identical in every pixel except: {WORDS} The poster must look exactly like the poster in the THIRD attached image (the frame before it)."},
    "f13a": {"base": "f13a", "refs": [KING], "prompt": f"Use your image generation tool to EDIT the FIRST attached image (a frame of a 2D pixel-art cutscene, 1536 x 1024). Output ONE image of exactly the same size, identical in every pixel except: {WORDS}"},
}

# two hands only (owner, 2026-10-25: "he has 4 hands in that picture holding the scroll")
TWO = "King Bloblin must have EXACTLY TWO hands: ONE big green cube fist on the LEFT edge of the poster and ONE on the RIGHT edge, each gripping the poster's side. REMOVE every extra hand, fist or green block that reads as a hand (there must not be two stacked on a side, nor hands at the poster's top corners); fill where they were with the forest background behind (or his mossy cloak where it is behind them). The poster itself (WANTED:, his icon, REWARD:, the chest icon, the three signed class icons) stays exactly the same."

HANDS = {
    name: {
        "base": name,
        "refs": [KING],
        "prompt": f"Use your image generation tool to EDIT the FIRST attached image (a frame of a 2D pixel-art cutscene, 1536 x 1024). Output ONE image of exactly the same size, identical in every pixel except: {TWO}",
    }
    for name in ("f11", "f13a", "f13b")
}

TWEENS = {
    # the glade's opening frame without the soldier, who arrives later (run before f02b)
    "f02a": tween("f02a", "REMOVE the slime soldier with the scroll and shield at the bottom right completely, and fill where he stood with the same leafy bushes, grass and stone steps around him, so nobody but King Bloblin is in the glade."),
    # the scroll stays rolled until the king opens it (run before f08b)
    "f08a": tween("f08a", "the slime soldier now holds up a ROLLED-UP scroll (a cream parchment roll tied with a small red ribbon, nothing drawn on it visible) with both stubby arms, instead of the open poster; everything else stays exactly the same."),
    # the king and the heroes never share a frame (owner, 2026-10-25)
    "f19": tween("f19", "REMOVE King Bloblin, his throne, the slime soldier and the slimy treasure chest at the LEFT end completely; fill where they were with more of the same cube-leafed forest trees, mossy stones and grass, with the pale shockwave rings and the streaming leaves now coming in from beyond the left edge of the picture. The three heroes at the right stay exactly as they are."),
    "f02b": tween("f02a", "a gentle moment later: the fireflies and a few drifting leaves have moved a little, the slime on the chest has dripped a little lower."),
    "f02d": tween("f02c", "a moment later: the glints and sparkles on the treasure have moved to different coins and gems, a few more coins tumble down the front, the slime strands have dripped lower, the golden light pulses a little brighter."),
    "f03b": tween("f03a", "King Bloblin's eyes are fully closed now and his body has sunk very slightly lower as he breathes out; a dozing little slime on his cloak has tipped its head."),
    "f04b": tween("f04a", "the yawn is only just starting: King Bloblin's eyes squeezed shut, his square mouth only a little open, arms just starting to rise; the orange butterfly is NOT on his crown yet but fluttering in at the top right corner of the frame."),
    "f04c": tween("f04a", "the yawn is over: mouth closed, arms lowered to rest, and his eyes look up at the orange butterfly sitting on the top of his crown, cross-eyed."),
    "f05b": tween("f05a", "the bushes at the right shake and rustle, leaves flying off them, small motion marks."),
    "f05c": tween("f05b", "a twig spear's stone tip and a green leaf plume poke out of the shaking bushes."),
    "f06b": tween("f06a", "the slime soldier has run further left, closer to the middle, the other foot forward, the scroll still held high, a new dust puff behind."),
    "f06c": tween("f06b", "the slime soldier has run further left again, nearly at the throne's steps, the first foot forward again, sweat drops flying."),
    "f07b": tween("f07a", "the slime soldier now stands to attention saluting with his spear hand, chest out, the splash settled into a little puddle."),
    "f08b": tween("f08a", "the king leans closer, his big face lower over the scroll, both brows raised now; the slime soldier trembles."),
    "f10b": tween("f10a", "the scroll is fully unrolled in the king's hands, its plain back facing us; the king's eyes narrow as he reads it."),
    "f12b": tween("f12a", "King Bloblin's eyes widen, the pupils shrinking, one brow twitching up with little yellow strain marks beside it."),
    "f13b": tween("f13a", "a moment later: his face a shade darker still, bigger steam puffs blasting from both sides of his head, his hands shaking harder."),
    "f14b": tween("f14a", "the poster fully crushed into a ball in his fist, more paper bits scattered, the slime soldier further back at the right edge, hands up."),
    "f15b": tween("f15a", "King Bloblin has risen to his full height, towering, the top of his crown now near the top of the frame, his shadow fully over the cowering slime soldier."),
    "f16b": tween("f16a", "King Bloblin's body swollen even bigger with the breath, cheeks bulging to bursting, the little slimes on his cloak flapping."),
    "f17b": tween("f17a", "the roar continues: the shockwave ring further out, different slime droplets and cubes flying, his mouth even wider."),
    "f18b": tween("f18a", "a moment later: the shockwave rings have spread further across the glade, more leaves and birds in the air, the slime soldier tumbled further, upside down."),
    "f20b": tween("f20a", "a moment later: the heroes have fully turned toward the roar, crouched and ready, the '!' marks bigger, more leaves blowing past."),
    "f21b": tween("f21a", "a moment later: the Arcanist's mouth closes into a determined line, the Ranger narrows his eyes, the Warden's grimace hardens."),
    "f22b": tween("f22a", "the Warden now points his big wooden greatsword forward toward the forest, the Arcanist raises her staff, the Ranger draws an arrow."),
    "f23b": tween("f23a", "the next running step: the three heroes a little further down the path and smaller, each with the other foot forward, capes and hair flapping."),
    "f23c": tween("f23b", "the next running step: the three heroes further down the path and smaller again, the first foot forward again."),
}


def run(name: str, job: dict) -> str:
    out = RAW / f"{name}.png"
    refs = list(job["refs"])
    if "base" in job:
        refs.insert(0, RAW / f"{job['base']}.png")
    args = ["codex", "exec", "--skip-git-repo-check", "-s", "read-only"]
    for ref in refs:
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
    which = sys.argv[1]
    jobs = {"keys": KEYS, "tweens": TWEENS, "bows": BOWS, "posters": POSTERS, "hands": HANDS}[which]
    names = sys.argv[2:] or list(jobs)
    RAW.mkdir(exist_ok=True)
    with ThreadPoolExecutor(WORKERS) as pool:
        for line in pool.map(lambda n: run(n, jobs[n]), names):
            print(line, flush=True)


if __name__ == "__main__":
    main()
