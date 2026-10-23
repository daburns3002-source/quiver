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

# page: (rounds, picks collection, sounds already chosen, shown for context)
PAGES = {
    "1-2": (ROUND_1_2, "picks", []),
    "3": (ROUND_3, "picks3", ["Player hurt A", "XP crystal D", "Heart D", "Level up A"]),
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
