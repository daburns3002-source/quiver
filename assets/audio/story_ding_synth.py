"""King Bloblin's ding in the story cutscene (owner, 2026-11-12: "make sure
the cutscene for bloblin plays the ding effect when his eyes get small and
his eyebrow raises"): the Eyes shot's second picture, f12b, which is drawn
with the ding's own marks beside the brow (`Config/Story.sounds`).

    python -I assets/audio/story_ding_synth.py <out_dir>

Four takes of `story_king_ding`, built from scratch (struck partials and a
click, no recording), as <out_dir>/story_king_ding_<a-d>.wav and .mp3 with a
manifest.json for `build_page.py` (page "28").
"""
import json
import os
import subprocess
import sys

import numpy as np
from scipy.io import wavfile

SR = 44100
FF = os.environ.get("FFMPEG", "ffmpeg")
rng = np.random.default_rng(20261112)


def struck(freq, seconds, partials, decay, attack=0.002):
    """A struck tone: each partial (ratio, level, how much faster it dies)
    rings down on its own, so the sound starts bright and ends pure."""
    t = np.arange(int(SR * seconds)) / SR
    out = np.zeros_like(t)
    for ratio, level, faster in partials:
        out += level * np.sin(2 * np.pi * freq * ratio * t) * np.exp(-decay * faster * t)
    rise = max(1, int(SR * attack))
    out[:rise] *= np.linspace(0, 1, rise)
    return out


def click(seconds=0.012, level=0.25):
    """The tap of the striker: a few milliseconds of bright noise."""
    n = int(SR * seconds)
    x = rng.standard_normal(n) * np.exp(-np.linspace(0, 9, n))
    return np.diff(x, prepend=0) * level


def mix(*layers):
    """Layers of (samples, start seconds, level), summed."""
    end = max(int(SR * start) + len(x) for x, start, _ in layers)
    out = np.zeros(end)
    for x, start, level in layers:
        i = int(SR * start)
        out[i : i + len(x)] += x * level
    return out


BELL = [(1, 1.0, 1), (2.0, 0.5, 1.6), (2.76, 0.35, 2.2), (5.4, 0.2, 3.5), (8.93, 0.1, 5)]
GLASS = [(1, 1.0, 1), (2.32, 0.3, 2), (4.25, 0.15, 3.5)]
TRIANGLE = [(1, 1.0, 1), (2.7, 0.6, 1.2), (5.2, 0.45, 1.5), (8.1, 0.3, 2), (11.4, 0.2, 2.6)]
ROUND = [(1, 1.0, 1), (2.0, 0.25, 2.5), (3.0, 0.08, 4)]

TAKES = [
    (
        lambda: mix((struck(2093, 0.9, BELL, 6), 0, 1.0), (click(), 0, 1.0)),
        "a desk bell: one bright ding that rings for most of a second",
    ),
    (
        lambda: mix(
            (struck(1319, 0.25, GLASS, 14), 0, 0.8),
            (struck(1976, 0.75, GLASS, 7), 0.09, 1.0),
            (click(0.008, 0.15), 0, 1.0),
            (click(0.008, 0.15), 0.09, 1.0),
        ),
        "di-ding: two quick glassy notes stepping up, the second one ringing",
    ),
    (
        lambda: mix((struck(3136, 1.0, TRIANGLE, 4.5), 0, 0.9), (click(0.006, 0.3), 0, 1.0)),
        "a triangle: a thin high ting with a long shimmer",
    ),
    (
        lambda: mix((struck(1568, 0.6, ROUND, 8, attack=0.004), 0, 1.0), (click(0.006, 0.08), 0, 1.0)),
        "a rounder, lower bing, shorter and less piercing",
    ),
]


def main():
    out = sys.argv[1]
    os.makedirs(out, exist_ok=True)
    name = "story_king_ding"
    manifest = {name: []}
    for letter, (make, note) in zip("abcd", TAKES):
        x = make()
        fade = int(SR * 0.03)
        x[-fade:] *= np.linspace(1, 0, fade)
        x = x * (0.89 / max(np.abs(x).max(), 1e-9))
        base = os.path.join(out, f"{name}_{letter}")
        wavfile.write(base + ".wav", SR, (np.clip(x, -1, 1) * 32767).astype(np.int16))
        subprocess.run([FF, "-y", "-loglevel", "error", "-i", base + ".wav", "-b:a", "160k", base + ".mp3"], check=True)
        manifest[name].append({"variant": letter, "file": os.path.basename(base) + ".wav", "note": note, "ms": round(len(x) / SR * 1000)})
    print(name, [m["ms"] for m in manifest[name]])
    json.dump(manifest, open(os.path.join(out, "manifest.json"), "w"), indent=1)


if __name__ == "__main__":
    main()
