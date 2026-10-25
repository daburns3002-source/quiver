"""Takes for the Warden's new cards' sounds (round 19), made with synth.py's
tools.

    python -I warden_card_synth.py <out_dir>

The owner, 2026-10-25: Whirlwind and Shockwave each want "a quick animation
and sound", Battle Cry "a sound". Four designed takes for each, levelled to
the same peak as every other round's, with a manifest build_page.py reads
(page "19").
"""
import json
import os
import subprocess
import sys

import numpy as np
from scipy.io import wavfile

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import synth as s  # noqa: E402

SR = s.SR
FF = os.environ.get("FFMPEG", "ffmpeg")
METAL = ((1, 1.0), (2.41, 0.6), (3.93, 0.35), (5.4, 0.2))


def whirl_whoosh():
    """One full turn: a whoosh that rises and falls as the blade comes round."""
    seconds = 0.45
    n = int(SR * seconds)
    sweep = s.sweep_filter(s.noise(seconds), 500, 3200, q=2.2) * np.sin(np.linspace(0, np.pi, n)) ** 1.5
    tail = s.sweep_filter(s.noise(seconds), 2800, 700, q=1.6) * np.linspace(0.6, 0, n)
    return s.room(s.mix((sweep, 0.9), (tail, 0.4)), 0.08, 0.15)


def whirl_double():
    """Two quick passes of the blade, the second higher, as it spins round."""
    a = s.whoosh(0.22, 600, 2600, q=1.8, attack=0.02, decay=5)
    b = s.whoosh(0.24, 900, 3600, q=1.8, attack=0.02, decay=5)
    return s.room(s.mix((a, 0.8), (s.at(b, 0.16), 0.9)), 0.08, 0.15)


def whirl_ring():
    """A spinning whoosh with the blade's metal singing under it."""
    base = whirl_whoosh()
    ring = s.tone(880, 0.6, 6, METAL) * 0.6
    wobble = 1 + 0.35 * np.sin(np.linspace(0, 2 * np.pi * 5, len(ring)))
    return s.mix((base, 0.9), (ring * wobble, 0.3))


def whirl_gust():
    """A short gust round the body: low and full, then a bright edge."""
    low = s.sweep_filter(s.noise(0.5), 250, 1200, q=1.2) * s.env_ad(int(SR * 0.5), 0.05, 4)
    edge = s.at(s.whoosh(0.18, 2000, 5000, q=2, attack=0.005, decay=7), 0.12)
    return s.mix((low, 0.9), (edge, 0.5))


def rocks(seconds, count, start, end, seed, lo=400, hi=2600):
    out = np.zeros(int(SR * seconds))
    rng = np.random.default_rng(seed)
    for t in np.sort(rng.uniform(start, end, count)):
        hit = s.bandpass(s.noise(0.05), lo, hi) * s.env_ad(int(SR * 0.05), 0.001, 8)
        i = int(t * SR)
        out[i : i + len(hit)] += hit[: len(out) - i] * rng.uniform(0.3, 0.9)
    return out


def wave_roll():
    """The ground breaking in a line: thumps one after another, moving away."""
    seconds = 0.9
    out = np.zeros(int(SR * seconds))
    for i in range(6):
        t = i * 0.11
        thump = s.chirp(0.25, 110 - i * 8, 45) * s.env_ad(int(SR * 0.25), 0.002, 6)
        j = int(t * SR)
        out[j : j + len(thump)] += thump[: len(out) - j] * (1 - i * 0.12)
    return s.mix((out, 1.0), (rocks(seconds, 18, 0.0, 0.75, 5), 0.5))


def wave_rumble():
    """A low rumble rolling off, with stones kicked up along it."""
    seconds = 1.0
    rumble = s.lowpass(s.noise(seconds), 220) * s.env_ad(int(SR * seconds), 0.02, 3)
    boom = s.chirp(0.4, 95, 40) * s.env_ad(int(SR * 0.4), 0.002, 5)
    return s.mix((boom, 0.9), (rumble, 0.7), (rocks(seconds, 22, 0.05, 0.85, 9), 0.45))


def wave_crack():
    """The slam's crack running along the ground: a snap that travels."""
    seconds = 0.8
    snaps = np.zeros(int(SR * seconds))
    for i in range(5):
        snap = s.bandpass(s.noise(0.06), 900 - i * 120, 5000 - i * 600) * s.env_ad(int(SR * 0.06), 0.0005, 9)
        j = int(i * 0.1 * SR)
        snaps[j : j + len(snap)] += snap[: len(snaps) - j] * (1 - i * 0.15)
    low = s.chirp(0.5, 90, 40) * s.env_ad(int(SR * 0.5), 0.003, 5)
    return s.room(s.mix((snaps, 0.8), (low, 0.8)), 0.1, 0.18)


def wave_surge():
    """A deep whoomp that surges forward and breaks into gravel."""
    surge = s.sweep_filter(s.noise(0.7), 120, 900, q=1.5) * s.env_ad(int(SR * 0.7), 0.03, 3.5)
    boom = s.chirp(0.5, 80, 38) * s.env_ad(int(SR * 0.5), 0.002, 4)
    return s.mix((surge, 0.7), (boom, 0.9), (rocks(0.9, 16, 0.25, 0.8, 13), 0.5))


def horn(freq, seconds, bright=0.6):
    """A brassy horn note: a sawtooth's odd and even partials, swelled in."""
    t = np.arange(int(SR * seconds)) / SR
    wave = sum((bright ** (k - 1)) / k * np.sin(2 * np.pi * freq * k * t) for k in range(1, 9))
    env = np.minimum(1, t / 0.04) * np.exp(-t * 2.2)
    return s.lowpass(wave * env, 2600)


def cry_horn():
    """A short war-horn blast."""
    return s.room(horn(196, 0.6), 0.12, 0.2)


def cry_horn_rise():
    """Two horn notes, the second a fifth up: a rallying call."""
    return s.room(s.mix((horn(174.6, 0.3), 0.8), (s.at(horn(261.6, 0.45), 0.18), 0.9)), 0.12, 0.2)


def cry_drum():
    """A war drum's thump with a horn over it."""
    drum = s.chirp(0.35, 130, 55) * s.env_ad(int(SR * 0.35), 0.002, 6)
    return s.mix((drum, 1.0), (s.at(horn(220, 0.4, 0.5), 0.03), 0.55))


def cry_clash():
    """Blade on shield and a bright rising shout of brass."""
    clash = s.tone(640, 0.5, 7, METAL)
    rise = horn(196, 0.4) * np.linspace(0.6, 1, int(SR * 0.4))
    return s.mix((clash, 0.6), (s.at(rise, 0.05), 0.7))


DESIGNED = {
    "fx_whirlwind": [
        (whirl_whoosh, "One full turn: a whoosh rising and falling as the blade comes round."),
        (whirl_double, "Two quick passes of the blade, the second higher."),
        (whirl_ring, "The spin's whoosh with the blade's metal singing under it."),
        (whirl_gust, "A short gust round the body, low then a bright edge."),
    ],
    "fx_shockwave": [
        (wave_roll, "Thumps one after another, moving away down the lane."),
        (wave_rumble, "A low rumble rolling off, stones kicked up along it."),
        (wave_crack, "The slam's crack running along the ground."),
        (wave_surge, "A deep whoomp surging forward into gravel."),
    ],
    "fx_battle_cry": [
        (cry_horn, "A short war-horn blast."),
        (cry_horn_rise, "Two horn notes, a fifth apart: a rallying call."),
        (cry_drum, "A war drum's thump with a horn over it."),
        (cry_clash, "Blade on shield, then rising brass."),
    ],
}


def main():
    out = sys.argv[1]
    os.makedirs(out, exist_ok=True)
    manifest = {}
    for name, takes in DESIGNED.items():
        manifest[name] = []
        for letter, (fn, note) in zip("abcd", takes):
            base = os.path.join(out, f"{name}_{letter}")
            x = s.finish(fn())
            x = x * (0.89 / max(np.abs(x).max(), 1e-9))
            wavfile.write(base + ".wav", SR, (np.clip(x, -1, 1) * 32767).astype(np.int16))
            subprocess.run([FF, "-y", "-loglevel", "error", "-i", base + ".wav", "-b:a", "160k", base + ".mp3"], check=True)
            manifest[name].append({"variant": letter, "file": os.path.basename(base) + ".wav", "note": note, "ms": round(len(x) / SR * 1000)})
        print(name, len(manifest[name]))
    json.dump(manifest, open(os.path.join(out, "manifest.json"), "w"), indent=1)


if __name__ == "__main__":
    main()
