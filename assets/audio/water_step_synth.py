"""Footsteps in shallow water for the Drowned Village (`Fx/WaterSteps`;
owner, 2026-11-05: "the footsteps in the shallow water need to be
emphasized"): three takes of a foot slapping into ankle-deep water, each a
burst of band-passed noise (the slap and spray) over a few rising bubble
chirps (the plunge), so a run of steps never repeats one sound.

    uv run --with numpy --with scipy python -I water_step_synth.py <out folder>

Writes water_step_1..3.mp3; `sprite.py` joins them into
`final/water_step_sprite.mp3`, one upload for all three.
"""
import os
import pathlib
import subprocess
import sys
import tempfile

import numpy as np
from scipy.io import wavfile
from scipy.signal import butter, sosfilt

SR = 44100
FF = os.environ.get("FFMPEG", "ffmpeg")


def band(x, lo, hi):
    return sosfilt(butter(4, [lo, hi], btype="band", fs=SR, output="sos"), x)


def take(seed: int, length=0.42):
    rng = np.random.default_rng(seed)
    n = int(length * SR)
    t = np.arange(n) / SR
    out = np.zeros(n)
    # the slap: a sharp band of noise, falling fast
    slap = band(rng.standard_normal(n), 500 + 150 * seed, 3800) * np.exp(-t * (38 + 4 * seed))
    out += slap * 0.9
    # the spray: higher, softer, a touch later and longer
    spray = band(rng.standard_normal(n), 2500, 9000) * np.exp(-np.maximum(t - 0.02, 0) * 16)
    spray[: int(0.02 * SR)] = 0
    out += spray * 0.35
    # the plunge: a few bubbles, each a quick rising chirp
    for k in range(3 + seed % 2):
        start = 0.03 + 0.05 * k + rng.uniform(0, 0.03)
        dur = rng.uniform(0.03, 0.06)
        f0 = rng.uniform(350, 650)
        s0 = int(start * SR)
        m = int(dur * SR)
        if s0 + m >= n:
            continue
        tt = np.arange(m) / SR
        freq = f0 * (1 + 2.2 * tt / dur)
        phase = 2 * np.pi * np.cumsum(freq) / SR
        out[s0 : s0 + m] += np.sin(phase) * np.exp(-tt * 70) * 0.35
    # a soft attack so the slap never clicks
    attack = int(0.003 * SR)
    out[:attack] *= np.linspace(0, 1, attack)
    return out / np.max(np.abs(out)) * 0.9


def main():
    folder = pathlib.Path(sys.argv[1])
    folder.mkdir(parents=True, exist_ok=True)
    for i in (1, 2, 3):
        x = take(i)
        with tempfile.TemporaryDirectory() as tmp:
            wav = os.path.join(tmp, "x.wav")
            wavfile.write(wav, SR, (x * 32767).astype(np.int16))
            out = folder / f"water_step_{i}.mp3"
            subprocess.run([FF, "-y", "-loglevel", "error", "-i", wav, "-b:a", "160k", str(out)], check=True)
            print(out)


if __name__ == "__main__":
    main()
