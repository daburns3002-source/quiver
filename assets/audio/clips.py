"""Takes cut from royalty-free recordings, rendered like synth.py's.

    python -I clips.py <out_dir> <round> <source.wav>

Each take is a span of the source in seconds, with short fades and the
same loudness levelling as the synthesised sounds, so the audition and the
game treat them alike. Sources are not kept in the repo; each round names
where its source comes from, and its licence.
"""
import json
import os
import subprocess
import sys

import numpy as np
from scipy.io import wavfile
from scipy.signal import resample_poly

SR = 44100

# round: (source, licence, sound, [(variant, start, end, tempo, note)])
ROUNDS = {
    # Owner, 2026-10-23: "the staff cast take the 10-12 second clip from
    # this video". "10 Harry Potter Spells (Sound Effects)", The Audio
    # Horizon SFX, https://www.youtube.com/watch?v=bqixAkezavI: "This audio
    # content was designed by our team and is Royalty Free, you can use it
    # without restrictions." 0:10-0:12 is inside their "Accio".
    "7": ("https://www.youtube.com/watch?v=bqixAkezavI", "Royalty free, no restrictions (The Audio Horizon SFX)", "staff_cast", [
        ("a", 10.0, 12.0, 1.0, "Exactly 10 to 12 seconds of the clip."),
        ("b", 10.0, 12.8, 1.0, "From 10 seconds to the natural end of the spell's ring."),
        ("c", 11.5, 12.8, 1.0, "Just the spell's hit and its ring, for a cast every 1.4 s."),
        ("d", 10.0, 12.8, 2.0, "All of it, played twice as fast at the same pitch."),
        # The owner's choice (2026-10-23): "do D but not the wind up just
        # the end". From the hit's rise at 11.59 s, at D's double speed.
        ("e", 11.59, 12.8, 2.0, "D without the wind-up: the hit and its ring at double speed."),
    ]),
}

FF = os.environ.get("FFMPEG", "ffmpeg")


def take(src, start, end, tempo):
    sr, x = wavfile.read(src)
    x = x.astype(float) / 32768
    if x.ndim > 1:
        x = x.mean(axis=1)
    x = x[int(start * sr):int(end * sr)]
    if sr != SR:
        x = resample_poly(x, SR, sr)
    if tempo != 1.0:
        tmp_in, tmp_out = "_clip_in.wav", "_clip_out.wav"
        wavfile.write(tmp_in, SR, (np.clip(x, -1, 1) * 32767).astype(np.int16))
        subprocess.run([FF, "-y", "-loglevel", "error", "-i", tmp_in, "-filter:a", f"atempo={tempo}", tmp_out], check=True)
        _, x = wavfile.read(tmp_out)
        x = x.astype(float) / 32768
        os.remove(tmp_in)
        os.remove(tmp_out)
    fade = int(SR * 0.008)
    x[:fade] *= np.linspace(0, 1, fade)
    tail = int(SR * 0.05)
    x[-tail:] *= np.linspace(1, 0, tail)
    return x


if __name__ == "__main__":
    out, rnd, src = sys.argv[1], sys.argv[2], sys.argv[3]
    sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
    from synth import LEVEL, finish  # noqa: E402

    os.makedirs(out, exist_ok=True)
    manifest_path = os.path.join(out, "manifest.json")
    manifest = json.load(open(manifest_path)) if os.path.exists(manifest_path) else {}
    _, _, name, takes = ROUNDS[rnd]
    manifest[name] = []
    for letter, start, end, tempo, note in takes:
        x = finish(take(src, start, end, tempo), target_rms=LEVEL[name])
        path = os.path.join(out, f"{name}_{letter}.wav")
        wavfile.write(path, SR, (np.clip(x, -1, 1) * 32767).astype(np.int16))
        manifest[name].append({"variant": letter, "file": os.path.basename(path), "note": note, "ms": round(len(x) / SR * 1000)})
        print(name, letter, round(len(x) / SR * 1000), "ms")
    json.dump(manifest, open(manifest_path, "w"), indent=1)
