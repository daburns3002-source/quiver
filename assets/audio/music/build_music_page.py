"""Builds the music audition page from a render's manifest and OGG/MP3 files.

    python -I build_music_page.py <render_dir> <out.html> [track]      (glade by default; or boss)

Each take plays as a seamless Web Audio loop, with a button that starts it a
few seconds before the seam so the join can be heard. Picks save to the
published page's database (collection `music`), like the sound page's.
"""
import base64
import html
import json
import os
import sys

RENDER, OUT = sys.argv[1], sys.argv[2]
TRACK = sys.argv[3] if len(sys.argv) > 3 else "glade"
COLLECTION = "music"
TRACKS = {
    "glade": ("Mossy Glade", "Area 1's music, under every room: a sunny forest clearing. "
              "F major, 104 BPM, 92 seconds, then it loops: a short harp intro, the tune twice, "
              "a minor middle on the ocarina, a quiet harp-and-bells bridge, and the tune once more."),
    "boss": ("King Bloblin", "Area 1's boss fight, while the king is in the room. D minor, 152 BPM, 76 seconds, "
             "then it loops: stabs and a drum fill, the battle tune twice, a heroic major-key middle, a bouncy "
             "half-time breakdown for the slime's wobble, a snare-roll build, and the tune once more."),
}
manifest = json.load(open(os.path.join(RENDER, "manifest.json")))  # as the theme script writes it
here = os.path.dirname(os.path.abspath(__file__))
css = open(os.path.join(here, "..", "page.css"), encoding="utf-8").read()
js = open(os.path.join(here, "music_page.js"), encoding="utf-8").read()

data = {}
rows = []
for v in manifest:
    sid = f"{TRACK}_{v['take']}"
    data[sid] = {ext: base64.b64encode(open(os.path.join(RENDER, f"{sid}.{ext}"), "rb").read()).decode()
                 for ext in ("ogg", "mp3")}
    label = v["take"].upper()
    rows.append(f"""<li class="opt">
  <button class="play" type="button" data-loop="{sid}" aria-label="Play take {label} on loop"><span class="tri"></span></button>
  <div class="meta">
    <div class="top"><b>{label}</b><span class="ms">{v['seconds']} s · {v['lufs']} LUFS</span></div>
    <p>{html.escape(v['note'])}</p>
    <div class="bar" aria-hidden="true"><i data-head="{sid}"></i></div>
  </div>
  <div class="acts"><button class="rep" type="button" data-seam="{sid}">Hear the seam</button><label class="pick"><input type="radio" name="{TRACK}" value="{label}"><span>Pick</span></label></div>
</li>""")

title, blurb = TRACKS[TRACK]
page = f"""<title>{title} Music</title>
<meta name="claude:viewport-fit-sides" content="cover">
<link rel="preconnect" href="https://fonts.googleapis.com"><link rel="preconnect" href="https://fonts.gstatic.com" crossorigin>
<link rel="stylesheet" href="https://fonts.googleapis.com/css2?family=Luckiest+Guy&family=Fredoka:wght@400;500;600&display=swap">
<style>{css}
.bar {{ height: 6px; border-radius: 3px; background: var(--line); overflow: hidden; max-width: 320px; }}
.bar i {{ display: block; height: 100%; width: 0; background: var(--wave); }}
.play.playing .tri {{ border: 0; width: 14px; height: 16px; margin: 0; background: linear-gradient(90deg, var(--accent-ink) 0 35%, transparent 35% 65%, var(--accent-ink) 65%); }}
</style>
<main class="wrap">
  <header class="top-head">
    <h1>{title} Music</h1>
    <p class="intro">Made from scratch for the game, with nothing borrowed. Play a take and it loops forever, as it will in a run; "Hear the seam" starts it four seconds before the loop point so you can listen for the join. Pick the one to upload; notes like "B but slower" are welcome in chat.</p>
    <p class="saved" id="saved" hidden></p>
  </header>
  <section>
    <header><h2>{title}</h2><p>{html.escape(blurb)}</p></header>
    <ol class="opts">{"".join(rows)}</ol>
  </section>
  <footer class="picks">
    <p id="summary">No pick yet.</p>
    <button type="button" id="copy">Copy my pick</button>
  </footer>
</main>
<script>const TRACKS = {json.dumps(data)}; const TRACK = {json.dumps(TRACK)}; const NAMES = {json.dumps({TRACK: title})}; const COLLECTION = {json.dumps(COLLECTION)};</script>
<script>{js}</script>"""
open(OUT, "w", encoding="utf-8").write(page)
print(len(page) // 1024, "KB")
