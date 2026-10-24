"""Designed takes for round 13 of the effect sounds, made with synth.py's
tools, beside the CC0 recordings that were worth keeping.

    python -I effect_synth.py <cc0_round_dir> <out_dir>

Round 13 (owner, 2026-10-24): the five effects whose round-12 takes were
all turned down. Freesound's CC0 pool for them is thin (its second search
found a sci-fi bullet for a fire and coins for a chain), so the recordings
in KEEP stay and each effect is filled to four takes with sounds built for
it: crackling fire, a bowstring winding tight, chain links clinking, a
heavy blade's slam, an earth-breaking boom.
"""
import json
import os
import shutil
import subprocess
import sys

import numpy as np
from scipy.io import wavfile

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import synth as s  # noqa: E402

SR = s.SR
FF = os.environ.get("FFMPEG", "ffmpeg")

# effect: the Freesound sources from round 13's CC0 search worth keeping
KEEP = {
    "fx_blaze": ["739487"],
    "fx_overdraw": ["490556"],
    "fx_soul_chain": ["411880", "812047"],
    "fx_heavy_blade": ["733887", "614062"],
    "fx_earthbreaker": ["530209"],
}


def crackle(seconds, rate=60, gain=0.5):
    """Fire's pops: short bright clicks at random times."""
    n = int(SR * seconds)
    out = np.zeros(n)
    rng = np.random.default_rng(7)
    for t in rng.uniform(0, seconds * 0.85, int(rate * seconds)):
        i = int(t * SR)
        click = s.highpass(s.noise(0.012), 1800) * s.env_ad(int(SR * 0.012), 0.0005, 9)
        out[i : i + len(click)] += click[: n - i] * rng.uniform(0.3, 1.0)
    return out * gain


def blaze_whoomp():
    body = s.whoosh(0.9, 250, 1800, q=0.9, attack=0.03, decay=3.5)
    low = s.lowpass(s.noise(0.9), 300) * s.env_ad(int(SR * 0.9), 0.02, 4)
    return s.mix((body, 0.8), (low, 0.6), (crackle(0.9, 50), 0.6))


def blaze_flare():
    roar = s.sweep_filter(s.noise(1.1), 600, 2600, q=1.1) * s.env_ad(int(SR * 1.1), 0.01, 3)
    return s.mix((roar, 0.7), (crackle(1.1, 80), 0.8))


def blaze_lick():
    lick = s.whoosh(0.6, 900, 3500, q=1.6, attack=0.005, decay=6)
    return s.room(s.mix((lick, 0.8), (crackle(0.6, 70), 0.6)), 0.08, 0.15)


def overdraw_creak():
    """A bowstring winding tight: a creaking rise, then the release."""
    seconds = 1.3
    creak = s.sweep_filter(s.noise(seconds), 300, 1100, q=8) * np.linspace(0.2, 1, int(SR * seconds))
    hum = s.chirp(seconds, 180, 420, wave="tri") * np.linspace(0.1, 0.6, int(SR * seconds))
    snap = s.at(s.pluck(220, 0.3, brightness=0.8), seconds - 0.05)
    return s.mix((creak, 0.6), (hum, 0.4), (snap, 0.9))


def overdraw_charge():
    """Gathering power: a rising shimmer that tops out in a bright ping."""
    seconds = 1.2
    rise = s.chirp(seconds, 300, 1400) * np.linspace(0, 1, int(SR * seconds)) ** 1.5
    air = s.sweep_filter(s.noise(seconds), 400, 4000, q=2) * np.linspace(0, 0.7, int(SR * seconds))
    ping = s.at(s.tone(1760, 0.4, 7, s.GLASS), seconds - 0.02)
    return s.mix((rise, 0.4), (air, 0.4), (ping, 0.6))


def overdraw_tension():
    """Wood and string under load, three creaks rising."""
    parts = []
    for i, f in enumerate((260, 360, 500)):
        creak = s.sweep_filter(s.noise(0.3), f, f * 1.6, q=10) * s.env_ad(int(SR * 0.3), 0.08, 3)
        parts.append((s.at(creak, i * 0.32), 0.5 + 0.2 * i))
    parts.append((s.at(s.whoosh(0.3, 1200, 5000, q=1.5, attack=0.003, decay=7), 1.0), 0.7))
    return s.mix(*parts)


METAL = ((1, 1.0), (2.41, 0.6), (3.93, 0.35), (5.4, 0.2))


def chain_clinks():
    """Three links snapping taut: bright inharmonic clinks."""
    parts = []
    for i, f in enumerate((2300, 2650, 2100)):
        parts.append((s.at(s.tone(f, 0.25, 14, METAL), i * 0.07), 0.7))
        parts.append((s.at(s.highpass(s.noise(0.02), 3000) * s.env_ad(int(SR * 0.02), 0.0005, 10), i * 0.07), 0.4))
    return s.room(s.mix(*parts), 0.06, 0.15)


def chain_whip():
    """A chain lashing out: a quick whoosh into a rattle of links."""
    whip = s.whoosh(0.25, 800, 4000, q=1.4, attack=0.01, decay=5)
    rattle = s.mix(*[(s.at(s.tone(f, 0.12, 18, METAL), 0.18 + i * 0.035), 0.4) for i, f in enumerate((2400, 2000, 2700, 2200, 2500))])
    return s.mix((whip, 0.7), (rattle, 0.8))


def blade_slam():
    """A heavy blade driven into the ground: a low thud and a clang."""
    thud = s.chirp(0.5, 120, 45) * s.env_ad(int(SR * 0.5), 0.002, 6)
    clang = s.tone(520, 0.9, 5, METAL)
    crack = s.bandpass(s.noise(0.08), 800, 5000) * s.env_ad(int(SR * 0.08), 0.0005, 8)
    return s.room(s.mix((thud, 1.0), (clang, 0.45), (crack, 0.6)), 0.12, 0.2)


def blade_gold():
    """The slam with a bright golden ring over it."""
    base = blade_slam()
    ring = s.arp([1046, 1318, 1568], 0.03, 0.8, s.BELL, 5)
    return s.mix((base, 0.9), (s.at(ring, 0.03), 0.35))


def earth_boom():
    """The ground breaking: a deep boom, a rumble, and stone falling."""
    seconds = 1.8
    boom = s.chirp(1.0, 90, 32) * s.env_ad(int(SR * 1.0), 0.003, 3.5)
    rumble = s.lowpass(s.noise(seconds), 180) * s.env_ad(int(SR * seconds), 0.01, 2.5)
    rocks = np.zeros(int(SR * seconds))
    rng = np.random.default_rng(3)
    for t in rng.uniform(0.15, 1.3, 26):
        hit = s.bandpass(s.noise(0.05), 400, 2500) * s.env_ad(int(SR * 0.05), 0.001, 8)
        i = int(t * SR)
        rocks[i : i + len(hit)] += hit[: len(rocks) - i] * rng.uniform(0.2, 0.8)
    return s.mix((boom, 1.0), (rumble, 0.6), (rocks, 0.5))


def earth_crack():
    """A sharp crack splitting the ground, then the boom under it."""
    crack = s.bandpass(s.noise(0.15), 1500, 7000) * s.env_ad(int(SR * 0.15), 0.0005, 7)
    return s.mix((crack, 0.8), (s.at(earth_boom(), 0.04), 0.9))


def earth_thump():
    """A heavier, shorter slam: the boom and a burst of gravel."""
    boom = s.chirp(0.7, 110, 38) * s.env_ad(int(SR * 0.7), 0.002, 4.5)
    gravel = s.bandpass(s.noise(0.6), 300, 3000) * s.env_ad(int(SR * 0.6), 0.005, 5)
    return s.room(s.mix((boom, 1.0), (gravel, 0.6)), 0.15, 0.2)


DESIGNED = {
    "fx_blaze": [(blaze_whoomp, "Designed: a fire whoomp with crackle"), (blaze_flare, "Designed: a flaring roar of fire, crackling"), (blaze_lick, "Designed: a quick bright lick of flame")],
    "fx_overdraw": [(overdraw_creak, "Designed: the bowstring creaking tight, then released"), (overdraw_charge, "Designed: power gathering to a bright ping"), (overdraw_tension, "Designed: three rising creaks and the arrow away")],
    "fx_soul_chain": [(chain_clinks, "Designed: three bright links snapping taut"), (chain_whip, "Designed: a chain lashing out into a rattle")],
    "fx_heavy_blade": [(blade_slam, "Designed: a low thud and a ringing clang"), (blade_gold, "Designed: the slam with a golden ring over it")],
    "fx_earthbreaker": [(earth_boom, "Designed: a deep boom, rumble and falling stone"), (earth_crack, "Designed: a sharp crack, then the boom"), (earth_thump, "Designed: a short heavy slam and gravel")],
}


def main():
    src, out = sys.argv[1], sys.argv[2]
    os.makedirs(out, exist_ok=True)
    cc0 = json.load(open(os.path.join(src, "manifest.json"), encoding="utf-8"))
    manifest = {}
    for name in DESIGNED:
        takes = []
        for take in cc0.get(name, []):
            if take.get("source") in KEEP[name]:
                takes.append(("cc0", take))
        for fn, note in DESIGNED[name]:
            takes.append(("synth", (fn, note)))
        manifest[name] = []
        for letter, (kind, take) in zip("abcdef", takes):
            base = os.path.join(out, f"{name}_{letter}")
            if kind == "cc0":
                old = os.path.join(src, f"{name}_{take['variant']}")
                shutil.copy(old + ".wav", base + ".wav")
                shutil.copy(old + ".mp3", base + ".mp3")
                entry = dict(take, variant=letter, file=os.path.basename(base) + ".wav")
            else:
                fn, note = take
                x = s.finish(fn())
                # every take at the same peak as the recordings, -1 dBFS
                x = x * (0.89 / max(np.abs(x).max(), 1e-9))
                wavfile.write(base + ".wav", SR, (np.clip(x, -1, 1) * 32767).astype(np.int16))
                subprocess.run([FF, "-y", "-loglevel", "error", "-i", base + ".wav", "-b:a", "160k", base + ".mp3"], check=True)
                entry = {"variant": letter, "file": os.path.basename(base) + ".wav", "note": note, "ms": round(len(x) / SR * 1000)}
            manifest[name].append(entry)
        print(name, len(manifest[name]))
    json.dump(manifest, open(os.path.join(out, "manifest.json"), "w"), indent=1)


if __name__ == "__main__":
    main()
