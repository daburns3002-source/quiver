"""King Bloblin's yawn in the story cutscene (owner, 2026-10-25: "there needs to
be a yawn sound for f03b, f04a and f04b"), cut from a CC0 Freesound recording
and slowed to 0.8x (deeper and longer, for a giant slime).

    python -I assets/audio/story_yawn.py <cache_dir>

Source, checked CC0 (Creative Commons Zero) on its page 2026-10-25, so no
credit is owed: 125419, "Man Yawning.wav" by jyoung20. It downloads into
<cache_dir>; the take lands in assets/audio/final/story_king_yawn.mp3.
"""
import os
import subprocess
import sys
import urllib.request

import numpy as np
from scipy.io import wavfile
from scipy.signal import butter, resample_poly, sosfilt

HERE = os.path.dirname(os.path.abspath(__file__))
SID = "125419"
START, END = 0.3, 3.1  # the yawn, in seconds of the source
SLOW = (5, 4)  # resample ratio: plays at 0.8x
FF = os.environ.get("FFMPEG", "ffmpeg")


def main() -> None:
    cache = sys.argv[1]
    os.makedirs(cache, exist_ok=True)
    mp3 = os.path.join(cache, f"{SID}.mp3")
    if not os.path.exists(mp3):
        page = urllib.request.urlopen(
            urllib.request.Request(f"https://freesound.org/s/{SID}/", headers={"User-Agent": "Mozilla/5.0"}),
            timeout=30,
        ).read().decode("utf-8", "replace")
        start = page.index("https://cdn.freesound.org/previews/")
        url = page[start : page.index('"', start)]
        data = urllib.request.urlopen(urllib.request.Request(url, headers={"User-Agent": "Mozilla/5.0"}), timeout=30).read()
        open(mp3, "wb").write(data)
    wav = os.path.join(cache, f"{SID}.wav")
    subprocess.run([FF, "-loglevel", "error", "-y", "-i", mp3, "-ac", "1", "-ar", "44100", wav], check=True)
    sr, x = wavfile.read(wav)
    x = x.astype(np.float64) / 32768
    x = x[int(START * sr) : int(END * sr)]
    x = resample_poly(x, *SLOW)  # same rate, more samples: slower and lower
    x = sosfilt(butter(2, 7000, "low", fs=sr, output="sos"), x)
    fade = int(0.08 * sr)
    x[:fade] *= np.linspace(0, 1, fade)
    x[-fade:] *= np.linspace(1, 0, fade)
    x *= 0.9 / np.max(np.abs(x))
    out = os.path.join(cache, "story_king_yawn.wav")
    wavfile.write(out, sr, (x * 32767).astype(np.int16))
    final = os.path.join(HERE, "final", "story_king_yawn.mp3")
    subprocess.run([FF, "-loglevel", "error", "-y", "-i", out, "-b:a", "192k", final], check=True)
    print(f"{len(x) / sr:.2f}s -> {final}")


if __name__ == "__main__":
    main()
