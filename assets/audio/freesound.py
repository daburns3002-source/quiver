"""Takes cut from CC0 recordings on Freesound, rendered like synth.py's.

    python -I freesound.py <out_dir> <round> <cache_dir>

Round 10 (owner, 2026-10-23): "find properly licensed sword sounds ... that
sound as close to the clip as possible". The clip's own sounds come from a
game, so it is only the measuring stick: every CC0 sword sound Freesound
found was cut into single swings and scored against each of the clip's three
blows (DTW over log-mel frames), and the closest are here. Every source was
checked as CC0 (Creative Commons Zero, public domain) on its own page, so no
credit is owed and they can ship in a commercial game. Sources are not kept
in the repo; they download into <cache_dir> by sound id.

A take is a list of layers, each (sound id, start, end, offset, gain): the
slam is a whoosh with an impact laid 0.5 s in, the clip's own timing, since
no single recording had both. Every take plays 10% quicker (resampled, so a
touch higher too), as the owner asked of the clip.
"""
import json
import os
import subprocess
import sys
import urllib.request

import numpy as np
from scipy.io import wavfile
from scipy.signal import resample_poly

SR = 44100
QUICK = (10, 11)  # resample ratio: 10% quicker
FF = os.environ.get("FFMPEG", "ffmpeg")

# sound id: (author, title), for credit we choose to give. All CC0, checked
# 2026-10-23 on each sound's page.
SOURCES = {
    "522701": ("julianmateo_", "Weapon, Sword, Metal sword, Swing, fast, impact"),
    "614170": ("videofueralle", "Swishes_4_strong_fast.wav"),
    "481954": ("craigsmith", "R26-31-Large Sword Whooshes.wav"),
    "782966": ("GrayEpic", "Sword Swing Connect"),
    "651500": ("darcyadam", "DCA Heavy Ground Attack.aif"),
    "667419": ("hz37", "Swish wipe HZA 16-05-2022.wav"),
    "380488": ("deleted_user_6479820", "Sword Swipes"),
    "672569": ("Teaganbear", "Swoosh Slam.wav"),
    "682143": ("HenKonen", "Metal swoosh 1.wav"),
    "547042": ("CogFireStudios", "Hit Impact Sword 3"),
}

# The slam's whoosh sits under its impact, as in the clip.
WHOOSH, IMPACT = 0.5, 1.0

ROUNDS = {
    "10": {
        "sword_swing": [
            ("a", [("522701", 0.30, 1.01, 0, 1)], "Closest to the clip's first swing: a fast metal sword swing (julianmateo_)."),
            ("b", [("614170", 0.44, 0.93, 0, 1)], "A strong, fast swish (videofueralle)."),
            ("c", [("481954", 5.89, 6.33, 0, 1)], "A large sword whoosh, deeper (craigsmith)."),
            ("d", [("782966", 0.00, 0.59, 0, 1)], "A sword swing with a bit of edge on it (GrayEpic)."),
        ],
        "sword_swing_2": [
            ("a", [("614170", 0.44, 0.93, 0, 1)], "Closest to the clip's second swing: the strong, fast swish (videofueralle)."),
            ("b", [("651500", 0.05, 0.53, 0, 1)], "The swing of a heavy attack, without its landing (darcyadam)."),
            ("c", [("667419", 0.00, 0.44, 0, 1)], "A short bright swish (hz37)."),
            ("d", [("380488", 2.43, 2.84, 0, 1)], "A sword swipe, lighter (Sword Swipes)."),
        ],
        "sword_slam": [
            ("a", [("667419", 0.00, 0.44, 0, WHOOSH), ("672569", 0.08, 0.95, 0.5, IMPACT)], "Closest to the clip's slam: the bright swish into a swoosh slam (hz37 + Teaganbear)."),
            ("b", [("667419", 0.00, 0.44, 0, WHOOSH), ("682143", 0.00, 0.82, 0.5, IMPACT)], "The bright swish into a ringing metal swoosh (hz37 + HenKonen)."),
            ("c", [("782966", 1.51, 1.99, 0, WHOOSH), ("672569", 0.08, 0.95, 0.5, IMPACT)], "An edgier swing into the swoosh slam (GrayEpic + Teaganbear)."),
            ("d", [("380488", 2.43, 2.84, 0, WHOOSH), ("672569", 0.08, 0.95, 0.5, IMPACT)], "A lighter swipe into the swoosh slam (Sword Swipes + Teaganbear)."),
            ("e", [("667419", 0.00, 0.44, 0, WHOOSH), ("547042", 0.00, 0.75, 0.5, IMPACT)], "The bright swish into a metal sword impact, more clang (hz37 + CogFireStudios)."),
        ],
    },
}


def preview_url(sid):
    page = urllib.request.urlopen(urllib.request.Request(f"https://freesound.org/s/{sid}/", headers={"User-Agent": "Mozilla/5.0"}), timeout=30).read().decode("utf-8", "replace")
    start = page.index("https://cdn.freesound.org/previews/")
    return page[start:page.index('"', start)].replace("-lq.", "-hq.")


def source(cache, sid):
    path = os.path.join(cache, sid + ".mp3")
    if not os.path.exists(path):
        os.makedirs(cache, exist_ok=True)
        url = preview_url(sid)
        open(path, "wb").write(urllib.request.urlopen(urllib.request.Request(url, headers={"User-Agent": "Mozilla/5.0"}), timeout=30).read())
    raw = subprocess.run([FF, "-loglevel", "error", "-i", path, "-ac", "1", "-ar", str(SR), "-f", "s16le", "-"], capture_output=True, check=True).stdout
    return np.frombuffer(raw, np.int16).astype(float) / 32768


def render(cache, layers):
    parts = []
    for sid, start, end, offset, gain in layers:
        x = source(cache, sid)[int(start * SR):int(end * SR)].copy()
        fade = int(SR * 0.004)
        x[:fade] *= np.linspace(0, 1, fade)
        tail = int(SR * 0.04)
        x[-tail:] *= np.linspace(1, 0, tail)
        parts.append((int(offset * SR), x / (np.abs(x).max() + 1e-9) * gain))
    out = np.zeros(max(o + len(x) for o, x in parts))
    for o, x in parts:
        out[o:o + len(x)] += x
    return resample_poly(out, *QUICK)


if __name__ == "__main__":
    out, rnd, cache = sys.argv[1], sys.argv[2], sys.argv[3]
    sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
    from synth import LEVEL, finish  # noqa: E402

    os.makedirs(out, exist_ok=True)
    manifest_path = os.path.join(out, "manifest.json")
    manifest = json.load(open(manifest_path)) if os.path.exists(manifest_path) else {}
    for name, takes in ROUNDS[rnd].items():
        manifest[name] = []
        for letter, layers, note in takes:
            x = finish(render(cache, layers), target_rms=LEVEL[name])
            base = os.path.join(out, f"{name}_{letter}")
            wavfile.write(base + ".wav", SR, (np.clip(x, -1, 1) * 32767).astype(np.int16))
            subprocess.run([FF, "-y", "-loglevel", "error", "-i", base + ".wav", "-b:a", "160k", base + ".mp3"], check=True)
            manifest[name].append({"variant": letter, "file": os.path.basename(base) + ".wav", "note": note, "ms": round(len(x) / SR * 1000)})
            print(name, letter, round(len(x) / SR * 1000), "ms")
    json.dump(manifest, open(manifest_path, "w"), indent=1)
