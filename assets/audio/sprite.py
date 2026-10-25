"""Joins several sounds into one file (an audio sprite), so many sounds cost
one Roblox upload (owner, 2026-10-25: "roblox limits the amount of audio
uploads"). The game plays each back by its region (`Config/Sounds` `region`,
`Fx/SoundFx`).

    python -I sprite.py <out.mp3> <in1.mp3> <in2.mp3> ...

Each sound is followed by GAP seconds of silence, so a region that ends a
touch late never catches the next one. Prints each input's name with its
start and length in seconds, to paste into `Config/Sounds`, and writes the
same as JSON beside the output.
"""
import json
import os
import subprocess
import sys
import tempfile

import numpy as np
from scipy.io import wavfile

SR = 44100
GAP = 0.5
# Added to each region's length: MP3 encoders pad the start a few ms, so a
# region cut exactly would lose the end of its tail.
TAIL = 0.06
FF = os.environ.get("FFMPEG", "ffmpeg")


def load(path):
    with tempfile.TemporaryDirectory() as tmp:
        wav = os.path.join(tmp, "x.wav")
        subprocess.run([FF, "-y", "-loglevel", "error", "-i", path, "-ac", "1", "-ar", str(SR), wav], check=True)
        _, x = wavfile.read(wav)
    return x.astype(np.float32) / 32768


def main():
    out, inputs = sys.argv[1], sys.argv[2:]
    gap = np.zeros(int(GAP * SR), np.float32)
    parts, regions, t = [], {}, 0.0
    for path in inputs:
        x = load(path)
        name = os.path.splitext(os.path.basename(path))[0]
        regions[name] = [round(t, 3), round(len(x) / SR + TAIL, 3)]
        parts += [x, gap]
        t += (len(x) + len(gap)) / SR
    y = np.concatenate(parts)
    with tempfile.TemporaryDirectory() as tmp:
        wav = os.path.join(tmp, "sprite.wav")
        wavfile.write(wav, SR, (np.clip(y, -1, 1) * 32767).astype(np.int16))
        subprocess.run([FF, "-y", "-loglevel", "error", "-i", wav, "-b:a", "160k", out], check=True)
    json.dump(regions, open(os.path.splitext(out)[0] + ".json", "w"), indent=1)
    for name, (start, length) in regions.items():
        print(f"{name} {start} {length}")
    print(f"total {round(len(y) / SR, 2)} s")


if __name__ == "__main__":
    main()
