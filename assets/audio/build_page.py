"""Builds the sound audition page from a render's manifest and MP3s.

    python -I build_page.py <render_dir> <out.html> [page]

`page` is one of PAGES (default "1-2"). Picks are saved to the published
page's database, in the page's own collection (`picks` for rounds 1 and 2,
`picks3` for round 3), so Claude reads them back directly and a round's
picks never preselect another round's takes; the copy button is the
fallback.
"""
import base64
import html
import json
import os
import sys

import numpy as np
from scipy.io import wavfile

RENDER = sys.argv[1]
OUT = sys.argv[2]
PAGE = sys.argv[3] if len(sys.argv) > 3 else "1-2"
manifest = json.load(open(os.path.join(RENDER, "manifest.json")))

# sound: (title, what it is for, (gap seconds, repeats) to hear it in game rhythm)
ROUND_1_2 = [
    ("Round 1 · the three you hear most", {
        "arrow_fire": ("Arrow fire", "Every arrow the archer looses, about once a second, more with Multishot. Short and light, so it never wears on you.", (0.7, 5)),
        "enemy_hit": ("Enemy hit", "An arrow landing on an enemy. Mostly slimes, so a soft, jelly-ish impact suits them.", (0.32, 5)),
        "enemy_death": ("Enemy death", "The reward: the body bursts into a puff. Once per kill, so it can be fuller.", None),
    }),
    ("Round 2 · everything else in a fight", {
        "staff_cast": ("Staff cast", "The Arcanist's bolt leaving the staff, about every 1.4 seconds.", (1.4, 4)),
        "player_hurt": ("Player hurt", "You take a hit. It has to cut through everything else and read as bad news.", None),
        "dash": ("Dash", "The dodge roll, at most every 4 seconds.", None),
        "xp_pickup": ("XP crystal", "Each crystal you collect. Many come at once when a room clears, so it has to be tiny.", (0.06, 8)),
        "heart_pickup": ("Heart", "Picking up a heart, which heals a fifth of your health.", None),
        "level_up": ("Level up", "You levelled up and the card draft is about to open.", None),
        "card_pick": ("Card pick", "Choosing a skill card from the draft.", None),
        "gate_open": ("Exit gate opens", "The room is clear and the glowing gate opens.", None),
    }),
]

ROUND_3 = [
    ("Round 3 · new takes on everything not yet chosen", {
        "arrow_fire": ROUND_1_2[0][1]["arrow_fire"],
        "enemy_hit": ROUND_1_2[0][1]["enemy_hit"],
        "enemy_death": ROUND_1_2[0][1]["enemy_death"],
        "staff_cast": ROUND_1_2[1][1]["staff_cast"],
        "dash": ROUND_1_2[1][1]["dash"],
        "card_pick": ROUND_1_2[1][1]["card_pick"],
        "gate_open": ROUND_1_2[1][1]["gate_open"],
    }),
]

ROUND_4 = [
    ("Round 4 · the staff without its shimmer, a better poof, and new tries", {
        "staff_cast": ROUND_1_2[1][1]["staff_cast"],
        "enemy_death": ROUND_1_2[0][1]["enemy_death"],
        "arrow_fire": ROUND_1_2[0][1]["arrow_fire"],
        "gate_open": ROUND_1_2[1][1]["gate_open"],
    }),
]

ROUND_5 = [
    ("Round 5 · a new staff cast, the big poof, and the gate with its doors", {
        "staff_cast": ROUND_1_2[1][1]["staff_cast"],
        "enemy_death": ROUND_1_2[0][1]["enemy_death"],
        "gate_open": ("Exit gate opens", "The room is clear and the gate's two wooden doors swing open into the light.", None),
    }),
]

ROUND_6 = [
    ("Round 6 · your gate B in four versions, a new staff cast, a softer poof", {
        "gate_open": ROUND_5[0][1]["gate_open"],
        "staff_cast": ROUND_1_2[1][1]["staff_cast"],
        "enemy_death": ROUND_1_2[0][1]["enemy_death"],
    }),
]

ROUND_7 = [
    ("Round 7 · the staff cast from your clip, and just the pops", {
        "staff_cast": ("Staff cast", "The Arcanist's bolt, about every 1.4 seconds, cut from the clip you chose (The Audio Horizon SFX, royalty free). The longer takes overlap at that pace; the rhythm button lets you hear it.", (1.4, 4)),
        "enemy_death": ROUND_1_2[0][1]["enemy_death"],
    }),
]

ROUND_8 = [
    ("Round 8 · the Warden's greatsword", {
        "sword_swing": ("Sword swing", "The Warden's sweep and backswing: the first two blows of its combo, about once a second.", (1.0, 4)),
        "sword_slam": ("Sword slam", "The combo's third blow: the greatsword brought down overhead.", None),
    }),
]

ROUND_9 = [
    ("Round 9 · the Warden's three blows, made to your clip's shape", {
        "sword_swing": ("Blow 1 · the sweep", "Made from scratch to the clip's first swing: its swell, its fade and its falling pitch, 10% quicker. The clip's own sounds come from a game, so they can't be used.", None),
        "sword_swing_2": ("Blow 2 · the backswing", "The clip's second swing: a rise to a bright peak and back, 10% quicker.", None),
        "sword_slam": ("Blow 3 · the slam", "The clip's third: a bright whoosh straight into a heavy impact that rings out, 10% quicker.", None),
    }),
]

ROUND_10 = [
    ("Round 10 · licensed sword sounds, picked to match your clip", {
        "sword_swing": ("Blow 1 · the sweep", "Real recordings, all CC0 (public domain, free for commercial games), chosen by measuring each against your clip's first swing; A measured closest. 10% quicker, as before.", (1.0, 3)),
        "sword_swing_2": ("Blow 2 · the backswing", "The same search against the clip's second swing; A measured closest.", (1.0, 3)),
        "sword_slam": ("Blow 3 · the slam", "No single recording had the clip's whoosh-into-impact, so each is a CC0 whoosh with a CC0 impact laid in at the clip's timing; A measured closest.", None),
    }),
]

ROUND_11 = [
    ("Round 11 · new slams, to go with your blows", {
        "sword_slam": ("Blow 3 · the slam", "Every whoosh comes from the same recordings as your blow 1 and 2 picks, so the combo sounds like one sword; each lands on a different kind of impact. All CC0, 10% quicker; A measured closest to your clip.", None),
    }),
]

ROUND_12 = [
    ("Round 12 · the upgrade effects (all CC0 recordings from Freesound, licence checked on each page)", {
        "fx_blaze": ("Blaze", "An enemy catches fire from your arrow.", None),
        "fx_heal": ("Heal", "The Heal card: the potion pours over you.", None),
        "fx_overdraw": ("Overdraw", "The bow charges while you stand still, then lets loose.", None),
        "fx_blast_arrows": ("Blast Arrows", "The starburst where an arrow explodes. Can come often, so short is good.", (0.45, 4)),
        "fx_soul_chain": ("Soul Chain", "A chain snaps between linked enemies.", None),
        "fx_heavy_blade": ("Heavy Blade", "The Warden's slam, the third blow, bursts in gold.", None),
        "fx_bloodletting": ("Bloodletting", "Life drawn from a struck enemy into the Warden. Every blow, so it must stay quiet.", (0.5, 3)),
        "fx_earthbreaker": ("Earthbreaker", "The Mythic's leaping slam: sod and stone thrown up.", None),
        "fx_chain_lightning": ("Chain Lightning", "The zig-zag bolt jumping to the next enemy.", (0.3, 3)),
        "fx_meteor": ("Meteor", "The Mythic meteor whooshing down before it lands.", None),
    }),
]

ROUND_13 = [
    ("Round 13 · new takes for the five you turned down: the best CC0 recordings, and sounds designed for each", {
        "fx_blaze": ROUND_12[0][1]["fx_blaze"],
        "fx_overdraw": ROUND_12[0][1]["fx_overdraw"],
        "fx_soul_chain": ROUND_12[0][1]["fx_soul_chain"],
        "fx_heavy_blade": ROUND_12[0][1]["fx_heavy_blade"],
        "fx_earthbreaker": ROUND_12[0][1]["fx_earthbreaker"],
    }),
]

ROUND_14 = [
    ("Round 14 · every Blaze take again, from rounds 12 and 13", {
        "fx_blaze": ROUND_12[0][1]["fx_blaze"],
    }),
]

# page: (rounds, picks collection, sounds already chosen, shown for context)
PAGES = {
    "14": (ROUND_14, "picks14", ["Heal", "Blast Arrows", "Bloodletting", "Chain Lightning", "Meteor", "Overdraw", "Heavy Blade", "Earthbreaker", "Soul Chain (an octave lower)"]),
    "13": (ROUND_13, "picks13", ["Heal (quieter, lower)", "Blast Arrows B", "Bloodletting D", "Chain Lightning C", "Meteor A"]),
    "12": (ROUND_12, "picks12", []),
    "1-2": (ROUND_1_2, "picks", []),
    "3": (ROUND_3, "picks3", ["Player hurt A", "XP crystal D", "Heart D", "Level up A"]),
    "11": (ROUND_11, "picks11", ["Player hurt", "XP crystal", "Heart", "Level up", "Enemy hit", "Dash", "Card pick", "Arrow fire", "Staff cast", "Enemy death", "Gate", "Blow 1 (10 C)", "Blow 2 (10 D)"]),
    "10": (ROUND_10, "picks10", ["Player hurt", "XP crystal", "Heart", "Level up", "Enemy hit", "Dash", "Card pick", "Arrow fire", "Staff cast", "Enemy death", "Gate"]),
    "9": (ROUND_9, "picks9", ["Player hurt", "XP crystal", "Heart", "Level up", "Enemy hit", "Dash", "Card pick", "Arrow fire", "Staff cast", "Enemy death", "Gate"]),
    "8": (ROUND_8, "picks8", ["Player hurt", "XP crystal", "Heart", "Level up", "Enemy hit", "Dash", "Card pick", "Arrow fire", "Staff cast", "Enemy death", "Gate (round 6 B)"]),
    "7": (ROUND_7, "picks7", ["Player hurt", "XP crystal", "Heart", "Level up", "Enemy hit", "Dash", "Card pick", "Arrow fire"]),
    "6": (ROUND_6, "picks6", ["Player hurt", "XP crystal", "Heart", "Level up", "Enemy hit", "Dash", "Card pick", "Arrow fire"]),
    "5": (ROUND_5, "picks5", ["Player hurt", "XP crystal", "Heart", "Level up", "Enemy hit", "Dash", "Card pick", "Arrow fire"]),
    "4": (ROUND_4, "picks4", ["Player hurt", "XP crystal", "Heart", "Level up", "Enemy hit", "Dash", "Card pick"]),
}
ROUNDS, COLLECTION, CHOSEN = PAGES[PAGE]


def wave_path(wav, width=240, height=44):
    sr, x = wavfile.read(wav)
    x = x.astype(float) / 32767
    step = max(1, len(x) // width)
    peaks = [np.abs(x[i * step:(i + 1) * step]).max() if i * step < len(x) else 0 for i in range(width)]
    top = " ".join(f"{i},{height / 2 - p * height / 2:.1f}" for i, p in enumerate(peaks))
    bot = " ".join(f"{i},{height / 2 + p * height / 2:.1f}" for i, p in reversed(list(enumerate(peaks))))
    return f'<svg class="wave" viewBox="0 0 {width} {height}" preserveAspectRatio="none" aria-hidden="true"><polygon points="{top} {bot}"/></svg>'


blocks = []
data = {}
names = {}
for round_title, sounds in ROUNDS:
    sections = []
    for key, (title, blurb, rhythm) in sounds.items():
        names[key] = title
        rows = []
        for v in manifest[key]:
            sid = f"{key}_{v['variant']}"
            data[sid] = base64.b64encode(open(os.path.join(RENDER, sid + ".mp3"), "rb").read()).decode()
            rep = (
                f'<button class="rep" type="button" data-play="{sid}" data-repeat="{rhythm[1]}" data-gap="{rhythm[0]}">×{rhythm[1]} in game rhythm</button>'
                if rhythm else ""
            )
            rows.append(f"""<li class="opt">
  <button class="play" type="button" data-play="{sid}" aria-label="Play {title} {v['variant'].upper()}"><span class="tri"></span></button>
  <div class="meta">
    <div class="top"><b>{v['variant'].upper()}</b><span class="ms">{v['ms']} ms</span></div>
    <p>{html.escape(v['note'])}</p>
    {wave_path(os.path.join(RENDER, sid + '.wav'))}
  </div>
  <div class="acts">{rep}<label class="pick"><input type="radio" name="{key}" value="{v['variant'].upper()}" id="pick-{sid}"><span>Pick</span></label></div>
</li>""")
        sections.append(f"""<section>
  <header><h2>{title}</h2><p>{html.escape(blurb)}</p></header>
  <ol class="opts">{"".join(rows)}</ol>
</section>""")
    blocks.append(f'<p class="round">{html.escape(round_title)}</p>' + "".join(sections))

here = os.path.dirname(os.path.abspath(__file__))
css = open(os.path.join(here, "page.css"), encoding="utf-8").read()
js = open(os.path.join(here, "page.js"), encoding="utf-8").read()
page = f"""<title>Arrow Legends Sound Audition</title>
<meta name="claude:viewport-fit-sides" content="cover">
<link rel="preconnect" href="https://fonts.googleapis.com"><link rel="preconnect" href="https://fonts.gstatic.com" crossorigin>
<link rel="stylesheet" href="https://fonts.googleapis.com/css2?family=Luckiest+Guy&family=Fredoka:wght@400;500;600&display=swap">
<style>{css}</style>
<main class="wrap">
  <header class="top-head">
    <h1>Sound Audition</h1>
    <p class="intro">Tap a take to hear it and pick a favourite in each group. Your picks save as you go, and I read them from here, so there is nothing to send. Notes like "C but punchier" are still welcome in chat.</p>
    {f'<p class="chosen-list">Already chosen and going in: {html.escape(", ".join(CHOSEN))}.</p>' if CHOSEN else ""}
    <p class="saved" id="saved" hidden></p>
  </header>
  {"".join(blocks)}
  <footer class="picks">
    <p id="summary">No picks yet.</p>
    <button type="button" id="copy">Copy my picks</button>
  </footer>
</main>
<script>const SOUNDS = {json.dumps(data)}; const NAMES = {json.dumps(names)}; const COLLECTION = {json.dumps(COLLECTION)};</script>
<script>{js}</script>"""
open(OUT, "w", encoding="utf-8").write(page)
print(len(page) // 1024, "KB")
