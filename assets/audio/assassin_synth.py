"""Takes for the Assassin's sounds (round 33), made with synth.py's tools.

    python -I assassin_synth.py <out_dir>

The class opened on 2026-11-16 with stand-ins: its three strikes play the
Warden's swings sped up and its cards' five sounds are silent
(`Config/Sounds`). Three designed takes for each, and for the Shadow Dash's
cut, which borrows the stab today. The strikes land about two a second, so
they are short, thin and quieter than a sword: air and a little steel, no
weight until the stab. Levelled to the same peak as every other round's,
with a manifest build_page.py reads (page "33").
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
STEEL = ((1, 1.0), (2.32, 0.5), (4.25, 0.3), (6.63, 0.15))


def n_of(seconds):
    return int(SR * seconds)


def tick(seconds=0.02, lo=5000, hi=11000, decay=9):
    """The edge of a blade: a tiny bright click."""
    return s.bandpass(s.noise(seconds), lo, hi) * s.env_ad(n_of(seconds), 0.0008, decay)


def ring(freq, seconds=0.16, decay=13):
    return s.tone(freq, seconds, decay, STEEL, attack=0.001)


# ---------- the two slashes: one from each hand, about two a second ----------
def slash_a():
    """A thin, bright swish."""
    return s.whoosh(0.11, 2400, 6800, q=2.2, attack=0.004, decay=7)


def slash_b():
    """A swish with the faintest scrape of steel."""
    return s.mix((s.whoosh(0.1, 2800, 7200, q=2.4, attack=0.003, decay=7), 0.9), (s.at(ring(3100, 0.09, 20), 0.02), 0.16))


def slash_c():
    """A softer, lower "fwip"."""
    return s.whoosh(0.13, 1300, 4200, q=1.7, attack=0.008, decay=6)


def slash2_a():
    """The other hand: the swish falling instead of rising."""
    return s.whoosh(0.11, 7000, 2600, q=2.2, attack=0.004, decay=7)


def slash2_b():
    """The steel swish again, a tone higher."""
    return s.mix((s.whoosh(0.1, 3300, 8200, q=2.4, attack=0.003, decay=7), 0.9), (s.at(ring(3650, 0.09, 20), 0.02), 0.16))


def slash2_c():
    """The soft "fwip", coming back up."""
    return s.whoosh(0.13, 4400, 1500, q=1.7, attack=0.008, decay=6)


# ---------- the stab: both daggers driven in, 1.5x ----------
def stab_a():
    """Two thrusts a moment apart, and a small thud."""
    a = s.whoosh(0.07, 2200, 5200, q=2, attack=0.003, decay=8)
    b = s.whoosh(0.08, 2600, 6200, q=2, attack=0.003, decay=8)
    thud = s.chirp(0.09, 190, 80) * s.env_ad(n_of(0.09), 0.002, 7)
    return s.mix((a, 0.7), (s.at(b, 0.045), 0.8), (s.at(thud, 0.06), 0.8))


def stab_b():
    """One punchy "thk"."""
    body = s.chirp(0.1, 240, 90) * s.env_ad(n_of(0.1), 0.001, 8)
    return s.mix((s.whoosh(0.06, 1800, 4200, q=1.8, attack=0.002, decay=9), 0.6), (s.at(body, 0.03), 1.0), (s.at(tick(), 0.03), 0.5))


def stab_c():
    """A thrust that ends on ringing steel."""
    return s.mix(
        (s.whoosh(0.08, 2000, 6000, q=2.2, attack=0.003, decay=8), 0.8),
        (s.at(ring(2050, 0.2, 11), 0.05), 0.35),
        (s.at(s.chirp(0.07, 170, 85) * s.env_ad(n_of(0.07), 0.002, 8), 0.05), 0.6),
    )


# ---------- Shadow Dash: the cut through whatever it passed ----------
def dash_a():
    """A fast dark rush, and one clean slice at its end."""
    rush = s.whoosh(0.2, 300, 2400, q=1.3, attack=0.03, decay=3)
    cut = s.whoosh(0.09, 3000, 9000, q=2.6, attack=0.002, decay=8)
    return s.mix((rush, 0.8), (s.at(cut, 0.13), 0.9))


def dash_b():
    """A hollow "voom" that snaps shut."""
    voom = s.chirp(0.22, 320, 110) * s.env_ad(n_of(0.22), 0.02, 4)
    air = s.whoosh(0.2, 900, 3600, q=1.4, attack=0.02, decay=4)
    return s.mix((voom, 0.7), (air, 0.6), (s.at(tick(0.03, 4000, 10000, 8), 0.19), 0.6))


def dash_c():
    """A whisper of air, then steel singing."""
    air = s.whoosh(0.18, 1200, 5200, q=1.6, attack=0.02, decay=4)
    return s.mix((air, 0.8), (s.at(ring(2600, 0.24, 9), 0.12), 0.3))


# ---------- Backstab: a strike from behind lands harder ----------
def backstab_a():
    """A sharp sting: a crack with a high ping over it."""
    crack = s.bandpass(s.noise(0.05), 1500, 7000) * s.env_ad(n_of(0.05), 0.001, 9)
    return s.mix((crack, 0.8), (s.at(s.tone(1760, 0.16, 12, s.GLASS), 0.01), 0.45))


def backstab_b():
    """A low, mean thump under a blade's edge."""
    thump = s.chirp(0.12, 210, 70) * s.env_ad(n_of(0.12), 0.001, 7)
    return s.mix((thump, 1.0), (tick(0.03, 3500, 9000, 8), 0.6))


def backstab_c():
    """Two notes falling: "gotcha"."""
    return s.mix((s.tone(1320, 0.1, 14, s.GLASS), 0.5), (s.at(s.tone(880, 0.16, 11, s.GLASS), 0.06), 0.6), (tick(), 0.4))


# ---------- Poison Trail: the cloud the dash leaves ----------
def bubbles(seconds, count, seed, lo=300, hi=900):
    out = np.zeros(n_of(seconds))
    rng = np.random.default_rng(seed)
    for t in np.sort(rng.uniform(0.02, seconds - 0.08, count)):
        f = rng.uniform(lo, hi)
        blip = s.chirp(0.05, f, f * 1.6) * s.env_ad(n_of(0.05), 0.004, 8)
        i = int(t * SR)
        out[i : i + len(blip)] += blip[: len(out) - i] * rng.uniform(0.4, 0.9)
    return out


def poison_a():
    """A soft hiss spreading out."""
    hiss = s.bandpass(s.noise(0.55), 3000, 9000) * s.env_ad(n_of(0.55), 0.06, 3.5)
    return s.mix((hiss, 0.8), (s.lowpass(s.noise(0.4), 500) * s.env_ad(n_of(0.4), 0.05, 4), 0.3))


def poison_b():
    """The hiss, with a few bubbles in it."""
    hiss = s.bandpass(s.noise(0.5), 2500, 8000) * s.env_ad(n_of(0.5), 0.05, 3.5)
    return s.mix((hiss, 0.7), (bubbles(0.5, 7, 3), 0.5))


def poison_c():
    """A wet "pfff" that sinks."""
    puff = s.sweep_filter(s.noise(0.45), 4200, 700, q=1.3) * s.env_ad(n_of(0.45), 0.03, 4)
    return s.mix((puff, 0.9), (bubbles(0.45, 4, 8, 200, 500), 0.4))


# ---------- Fan of Knives: three knives thrown at once ----------
def knives(gap, f0, f1, count=3):
    parts = []
    for i in range(count):
        k = s.whoosh(0.09, f0 * (1 + 0.12 * i), f1 * (1 + 0.12 * i), q=2.4, attack=0.003, decay=8)
        parts.append((s.at(k, i * gap), 0.8))
    return s.mix(*parts)


def fan_a():
    """Three quick "fft"s, each a little higher."""
    return knives(0.035, 2600, 7000)


def fan_b():
    """One spread "shing": the three almost together, steel on them."""
    return s.mix((knives(0.012, 2800, 7600), 0.9), (s.at(ring(3300, 0.14, 14), 0.01), 0.2))


def fan_c():
    """A flick of the wrist: a snap, then the knives leaving."""
    return s.mix((tick(0.025, 2500, 8000, 9), 0.6), (s.at(knives(0.025, 2200, 6000), 0.02), 0.9))


# ---------- Death Mark: the toughest enemy is marked ----------
def mark_a():
    """A low bell, tolled once."""
    return s.room(s.tone(196, 0.9, 5, s.BELL), 0.2, 0.25)


def mark_b():
    """A dark two-note sting, falling."""
    return s.room(s.mix((s.tone(392, 0.5, 6, s.BELL), 0.6), (s.at(s.tone(277, 0.8, 5, s.BELL), 0.14), 0.8)), 0.18, 0.2)


def mark_c():
    """A blade drawn, into a low hum."""
    draw = s.whoosh(0.18, 1500, 7000, q=2.6, attack=0.02, decay=4)
    hum = s.tone(147, 0.7, 4, s.WARM, attack=0.05)
    return s.mix((draw, 0.6), (s.at(ring(2400, 0.3, 8), 0.12), 0.2), (s.at(hum, 0.1), 0.7))


# ---------- Thousand Cuts: shadows cut every enemy at once (Mythic) ----------
def flurry(seconds, count, seed, f0=2400, f1=7600):
    out = np.zeros(n_of(seconds + 0.12))
    rng = np.random.default_rng(seed)
    for t in np.linspace(0, seconds, count):
        up = rng.random() < 0.5
        a, b = (f0, f1) if up else (f1, f0)
        k = s.whoosh(0.07, a * rng.uniform(0.85, 1.15), b * rng.uniform(0.85, 1.15), q=2.4, attack=0.003, decay=8)
        i = int(t * SR)
        out[i : i + len(k)] += k * rng.uniform(0.5, 0.9)
    return out


def cuts_a():
    """A flurry of slashes, faster and faster, and one last ring."""
    return s.room(s.mix((flurry(0.55, 9, 5), 0.8), (s.at(ring(1760, 0.5, 6), 0.58), 0.4)), 0.12, 0.15)


def cuts_b():
    """A dark rush, the flurry inside it, then silence cut by a single slice."""
    rush = s.whoosh(0.6, 200, 1800, q=1.2, attack=0.1, decay=2.5)
    last = s.whoosh(0.1, 3000, 10000, q=2.8, attack=0.002, decay=8)
    return s.mix((rush, 0.6), (flurry(0.45, 7, 11), 0.7), (s.at(last, 0.62), 1.0))


def cuts_c():
    """The flurry over a falling chord of steel."""
    chord = s.mix((s.at(ring(2093, 0.4, 7), 0.0), 0.3), (s.at(ring(1568, 0.4, 7), 0.16), 0.3), (s.at(ring(1047, 0.6, 5), 0.34), 0.4))
    return s.room(s.mix((flurry(0.5, 8, 21), 0.8), (chord, 0.6)), 0.12, 0.15)


DESIGNED = {
    "dagger_slash": [
        (slash_a, "A thin, bright swish."),
        (slash_b, "A swish with the faintest scrape of steel."),
        (slash_c, 'A softer, lower "fwip".'),
    ],
    "dagger_slash_2": [
        (slash2_a, "The swish falling instead of rising."),
        (slash2_b, "The steel swish again, a tone higher."),
        (slash2_c, 'The soft "fwip", coming back.'),
    ],
    "dagger_stab": [
        (stab_a, "Two thrusts a moment apart, and a small thud."),
        (stab_b, 'One punchy "thk".'),
        (stab_c, "A thrust that ends on ringing steel."),
    ],
    "fx_shadow_dash": [
        (dash_a, "A fast dark rush, and one clean slice at its end."),
        (dash_b, 'A hollow "voom" that snaps shut.'),
        (dash_c, "A whisper of air, then steel singing."),
    ],
    "fx_backstab": [
        (backstab_a, "A sharp sting: a crack with a high ping over it."),
        (backstab_b, "A low, mean thump under a blade's edge."),
        (backstab_c, 'Two notes falling: "gotcha".'),
    ],
    "fx_poison_trail": [
        (poison_a, "A soft hiss spreading out."),
        (poison_b, "The hiss, with a few bubbles in it."),
        (poison_c, 'A wet "pfff" that sinks.'),
    ],
    "fx_fan_of_knives": [
        (fan_a, 'Three quick "fft"s, each a little higher.'),
        (fan_b, 'One spread "shing": the three almost together.'),
        (fan_c, "A flick of the wrist, then the knives leaving."),
    ],
    "fx_death_mark": [
        (mark_a, "A low bell, tolled once."),
        (mark_b, "A dark two-note sting, falling."),
        (mark_c, "A blade drawn, into a low hum."),
    ],
    "fx_thousand_cuts": [
        (cuts_a, "A flurry of slashes and one last ring."),
        (cuts_b, "A dark rush, the flurry inside it, then a single slice."),
        (cuts_c, "The flurry over a falling chord of steel."),
    ],
}


def main():
    out = sys.argv[1]
    os.makedirs(out, exist_ok=True)
    manifest = {}
    for name, takes in DESIGNED.items():
        manifest[name] = []
        for letter, (fn, note) in zip("abc", takes):
            base = os.path.join(out, f"{name}_{letter}")
            x = s.finish(fn())
            x = x * (0.89 / max(np.abs(x).max(), 1e-9))
            wavfile.write(base + ".wav", SR, (np.clip(x, -1, 1) * 32767).astype(np.int16))
            subprocess.run([FF, "-y", "-loglevel", "error", "-i", base + ".wav", "-b:a", "160k", base + ".mp3"], check=True)
            manifest[name].append({"variant": letter, "file": os.path.basename(base) + ".wav", "note": note, "ms": round(len(x) / SR * 1000)})
        print(name, [m["ms"] for m in manifest[name]])
    json.dump(manifest, open(os.path.join(out, "manifest.json"), "w"), indent=1)


if __name__ == "__main__":
    main()
