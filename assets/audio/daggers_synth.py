"""Takes for the themed daggers' own effects (round 34), made with synth.py's tools.

    python -I daggers_synth.py <out_dir>

The seven daggers' effects (2026-11-18, `Fx/Upgrades/DaggerFx`) shipped with
eight silent hooks (`Config/Sounds`). Three designed takes for each, in the
set's own flavour: a falling star, a cowboy spur, a water toy, an arcade
counter, a comet, a festival bell, a forge. Thornwood's two silent hooks
(Thorn Burst, Boar Rush) get takes too, so all ten can go up as one sprite.
Each is timed to what it plays over: the star bursts 0.35 s in, the comet
crashes 1.5 s in, the lava runs for about 0.4 s, the counter ticks on every
strike. Levelled to the same peak as every other round's, with a manifest
build_page.py reads (page "34").
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
rng = np.random.default_rng(34)
METAL = ((1, 1.0), (2.32, 0.5), (4.25, 0.3), (6.63, 0.15))
TEMPLE = ((1, 1.0), (2.0, 0.55), (2.76, 0.35), (5.4, 0.18), (8.9, 0.06))

# the star's fall and the comet's, as the game times them (`Balance.Player.daggers`)
STAR_LANDS = 0.35
COMET_LANDS = 1.5


def n_of(seconds):
    return int(SR * seconds)


def env(seconds, attack=0.002, decay=6.0):
    return s.env_ad(n_of(seconds), attack, decay)


def square(freq, seconds, decay=10.0):
    """One 8-bit note."""
    return s.chirp(seconds, freq, freq * 1.0001, shape="lin", wave="square") * env(seconds, 0.001, decay)


def drop(freq, seconds=0.05):
    """A water droplet: a short sine blip bending up."""
    return s.chirp(seconds, freq, freq * 1.7) * env(seconds, 0.001, 9)


def thump(f0=150, f1=55, seconds=0.25, decay=6):
    return s.chirp(seconds, f0, f1) * env(seconds, 0.002, decay)


def burst(seconds, lo, hi, attack=0.002, decay=7):
    """Noise in a band, struck and dying."""
    return s.bandpass(s.noise(seconds), lo, hi) * env(seconds, attack, decay)


def crackle(seconds, count, lo=2500, hi=9000):
    """Random tiny clicks: fire, grit."""
    out = np.zeros(n_of(seconds))
    for _ in range(count):
        at = int(rng.uniform(0, seconds - 0.02) * SR)
        click = s.bandpass(s.noise(0.012), lo, hi) * env(0.012, 0.0005, 10) * rng.uniform(0.3, 1.0)
        out[at:at + len(click)] += click
    return out


def tremolo(x, rate, depth=0.8):
    t = np.arange(len(x)) / SR
    return x * (1 - depth / 2 + depth / 2 * np.sin(2 * np.pi * rate * t))


# ---------- Wishing Star: a star falls 0.35 s and bursts ----------
def star_a():
    """Twinkles falling, then a sparkly burst."""
    fall = s.sparkle(0.4, [3136, 2637, 2349, 1976, 1568], spacing=0.065, decay=14)
    pop = s.sparkle(0.6, [1568, 2093, 2637, 3136, 4186], spacing=0.03, decay=9)
    puff = burst(0.25, 3000, 9000, decay=8)
    return s.room(s.mix((fall, 0.6), (s.at(pop, STAR_LANDS), 0.9), (s.at(puff, STAR_LANDS), 0.35)), 0.14, 0.2)


def star_b():
    """A whistling fall, then a bright chime."""
    whistle = s.chirp(STAR_LANDS, 2600, 900) * env(STAR_LANDS, 0.02, 2)
    chime = s.arp([1047, 1319, 1568, 2093], 0.025, 0.8, s.BELL, 6)
    return s.room(s.mix((whistle, 0.35), (s.at(chime, STAR_LANDS), 0.8)), 0.16, 0.22)


def star_c():
    """Two soft pings, then a magic "pom" with sparkle."""
    pings = s.mix((s.tone(2637, 0.2, 14, s.BELL), 0.5), (s.at(s.tone(3136, 0.2, 14, s.BELL), 0.12), 0.5))
    pom = thump(420, 160, 0.22, 7)
    glitter = s.sparkle(0.5, [2093, 2637, 3520, 4186], spacing=0.04, decay=10)
    return s.room(s.mix((pings, 0.6), (s.at(pom, STAR_LANDS), 0.7), (s.at(glitter, STAR_LANDS + 0.02), 0.7)), 0.14, 0.2)


# ---------- Spur Rowel: a spinning spur hops between three enemies ----------
def spur_a():
    """A spinning metal whirr with spur jingles in it."""
    whirr = tremolo(burst(0.7, 1800, 5200, attack=0.03, decay=3), 26, 0.9)
    jingles = s.mix(*[(s.at(s.tone(f, 0.18, 16, METAL), t), 0.35) for f, t in ((3520, 0.05), (4186, 0.2), (3729, 0.36), (4435, 0.5))])
    return s.mix((whirr, 0.55), (jingles, 0.7))


def spur_b():
    """Three bright "ching"s, rising."""
    return s.room(s.mix(*[(s.at(s.mix((s.tone(f, 0.25, 12, METAL), 0.8), (burst(0.03, 5000, 11000, decay=9), 0.4)), t), 0.7)
                          for f, t in ((2637, 0.0), (3136, 0.17), (3520, 0.34))]), 0.1, 0.15)


def spur_c():
    """A flick of the wrist, then a rowel whirring away."""
    flick = s.whoosh(0.09, 2000, 6500, q=2.2, attack=0.003, decay=7)
    spin = tremolo(s.tone(1760, 0.6, 4, METAL, attack=0.02), 22, 0.85)
    return s.mix((flick, 0.7), (s.at(spin, 0.06), 0.45), (s.at(s.tone(3951, 0.15, 18, METAL), 0.08), 0.3))


# ---------- Splash Wave: a splash round the enemy ----------
def splash_a():
    """A splash, and droplets falling after it."""
    body = s.sweep_filter(s.noise(0.4), 4000, 700, q=1.2) * env(0.4, 0.004, 5)
    drops = s.mix(*[(s.at(drop(rng.uniform(900, 2200)), t), 0.35) for t in (0.12, 0.18, 0.26, 0.31, 0.4)])
    return s.mix((body, 0.8), (drops, 0.7))


def splash_b():
    """A deep "sploosh" and bubbles."""
    plunge = s.mix((thump(220, 70, 0.3, 6), 0.7), (s.lowpass(s.noise(0.35), 1800) * env(0.35, 0.003, 5), 0.6))
    bubbles = s.mix(*[(s.at(drop(rng.uniform(400, 900), 0.06), t), 0.4) for t in (0.1, 0.17, 0.22, 0.3)])
    return s.mix((plunge, 0.9), (bubbles, 0.6))


def splash_c():
    """A water blaster's "pshh" and a few plinks."""
    spray = s.highpass(s.noise(0.3), 2500) * env(0.3, 0.01, 4)
    plinks = s.mix(*[(s.at(drop(f, 0.04), t), 0.4) for f, t in ((1800, 0.14), (2400, 0.2), (1500, 0.28))])
    return s.mix((spray, 0.6), (plinks, 0.8))


# ---------- Combo Counter: ticks on every strike (about twice a second) ----------
def count_a():
    """A tiny two-note coin blip."""
    return s.mix((square(988, 0.035, 14), 0.5), (s.at(square(1319, 0.06, 12), 0.03), 0.5))


def count_b():
    """One short square "bip"."""
    return square(1175, 0.05, 12) * 0.6


def count_c():
    """A soft arcade "tik"."""
    return s.chirp(0.04, 1568, 2093, wave="tri") * env(0.04, 0.001, 10) * 0.7


# ---------- Combo Counter, broken: a hit taken empties it ----------
def break_a():
    """Four 8-bit notes falling: the combo is lost."""
    return s.mix(*[(s.at(square(f, 0.07, 8), i * 0.065), 0.55) for i, f in enumerate((784, 659, 523, 392))])


def break_b():
    """A square "bwowww" bending down."""
    return s.chirp(0.38, 900, 140, wave="square") * env(0.38, 0.003, 3) * 0.6


def break_c():
    """The digits shattering: a crack and falling pings."""
    crack = burst(0.08, 2500, 9000, decay=8)
    shards = s.mix(*[(s.at(square(f, 0.05, 12), t), 0.3) for f, t in ((1568, 0.03), (1319, 0.08), (1047, 0.13), (880, 0.18))])
    return s.mix((crack, 0.6), (shards, 0.8))


# ---------- Comet Crash: called on the strike, crashes 1.5 s later ----------
def comet_crash_hit():
    boom = s.mix((thump(140, 40, 0.6, 4), 0.9), (s.lowpass(s.noise(0.5), 2200) * env(0.5, 0.003, 5), 0.7))
    shards = s.sparkle(0.6, [3136, 2637, 2093, 1568], spacing=0.04, decay=9)
    return s.room(s.mix((boom, 0.9), (s.at(shards, 0.03), 0.35)), 0.2, 0.25)


def comet_a():
    """A glint, a whistling fall, a crash with glass in it."""
    glint = s.tone(3520, 0.3, 10, s.GLASS)
    fall = s.chirp(0.6, 3000, 500) * env(0.6, 0.45, 0.8) * 0.5
    rush = s.sweep_filter(s.noise(0.6), 800, 4000, q=1.4) * env(0.6, 0.5, 0.5)
    return s.mix((glint, 0.4), (s.at(fall, COMET_LANDS - 0.6), 0.45), (s.at(rush, COMET_LANDS - 0.6), 0.4),
                 (s.at(comet_crash_hit(), COMET_LANDS), 1.0))


def comet_b():
    """A hum swelling as it nears, then a deep "thoom"."""
    t = np.arange(n_of(COMET_LANDS)) / SR
    hum = np.sin(2 * np.pi * (220 + 260 * (t / COMET_LANDS) ** 2) * t) * (t / COMET_LANDS) ** 2.5
    hum = s.mix((hum, 0.5), (s.lowpass(s.noise(COMET_LANDS), 3000) * (t / COMET_LANDS) ** 3, 0.3))
    thoom = s.mix((thump(110, 35, 0.9, 3), 1.0), (burst(0.4, 200, 1800, decay=5), 0.5))
    return s.room(s.mix((hum, 0.5), (s.at(thoom, COMET_LANDS), 1.0)), 0.25, 0.3)


def comet_c():
    """Only a sparkle on the call; the fall comes late and fast."""
    call = s.sparkle(0.35, [2637, 3520, 4186], spacing=0.05, decay=12)
    fall = s.whoosh(0.35, 6000, 900, q=1.6, attack=0.25, decay=0.5)
    return s.mix((call, 0.5), (s.at(fall, COMET_LANDS - 0.35), 0.55), (s.at(comet_crash_hit(), COMET_LANDS), 1.0))


# ---------- Bell Chime: every 6th strike holds the enemies near ----------
def bell_a():
    """A festival bell, struck once, ringing on."""
    strike = burst(0.02, 2000, 8000, decay=9)
    return s.room(s.mix((s.tone(784, 1.4, 2.6, TEMPLE, attack=0.001), 0.8), (strike, 0.3)), 0.25, 0.3)


def bell_b():
    """A bright hand bell, "ding-ding"."""
    ding = s.tone(1319, 0.7, 4.5, s.BELL, attack=0.001)
    return s.room(s.mix((ding, 0.7), (s.at(ding, 0.14), 0.6)), 0.18, 0.25)


def bell_c():
    """A deep gong with a shimmer over it."""
    gong = tremolo(s.tone(392, 1.6, 2, TEMPLE, attack=0.004), 5, 0.25)
    shimmer = s.sparkle(0.9, [1568, 2093, 2349], spacing=0.08, decay=4)
    return s.room(s.mix((gong, 0.85), (shimmer, 0.25)), 0.3, 0.3)


# ---------- Lava Burst: lava bursting along the ground for about 0.4 s ----------
def blorp(f=180):
    return s.mix((s.chirp(0.12, f, f * 0.5) * env(0.12, 0.003, 6), 0.8), (burst(0.08, 400, 2400, decay=7), 0.35))


def lava_a():
    """A rumble, five blorps along the line, a sizzle."""
    rumble = s.lowpass(s.noise(0.6), 250) * env(0.6, 0.02, 3)
    blorps = s.mix(*[(s.at(blorp(200 - i * 15), i * 0.07), 0.6) for i in range(5)])
    sizzle = s.highpass(s.noise(0.5), 3500) * env(0.5, 0.05, 4)
    return s.mix((rumble, 0.7), (blorps, 0.8), (s.at(sizzle, 0.15), 0.25))


def lava_b():
    """A fiery "whoomph" and crackling."""
    whoomph = s.sweep_filter(s.noise(0.45), 300, 2200, q=1.1) * env(0.45, 0.02, 4)
    return s.mix((whoomph, 0.8), (thump(130, 60, 0.3, 6), 0.5), (crackle(0.7, 18), 0.5))


def lava_c():
    """Three heavy pops, each lower, with a hiss."""
    pops = s.mix(*[(s.at(blorp(f), t), 0.8) for f, t in ((240, 0.0), (190, 0.13), (150, 0.26))])
    hiss = s.highpass(s.noise(0.55), 4000) * env(0.55, 0.03, 4)
    return s.mix((pops, 0.9), (hiss, 0.2))


# ---------- Thornwood's two, silent since 2026-11-18 ----------
def thorn_a():
    """A woody crack, and thorns flying out."""
    crack = s.mix((burst(0.05, 1200, 6000, decay=9), 0.8), (thump(300, 120, 0.1, 8), 0.5))
    tiks = s.mix(*[(s.at(burst(0.02, 4000, 10000, decay=10), t), 0.35) for t in (0.04, 0.07, 0.09, 0.13, 0.16, 0.2)])
    return s.mix((crack, 0.9), (tiks, 0.7))


def thorn_b():
    """A seed pod bursting: "pok" and a rustle."""
    pok = thump(520, 200, 0.07, 9)
    rustle = s.bandpass(s.noise(0.3), 2000, 7000) * env(0.3, 0.01, 5)
    return s.mix((pok, 0.8), (s.at(rustle, 0.02), 0.5))


def thorn_c():
    """A quick spray of needles, "fsst"."""
    return s.mix((s.whoosh(0.18, 3000, 9000, q=2, attack=0.005, decay=6), 0.8), (burst(0.03, 1500, 5000, decay=9), 0.5))


def boar_a():
    """A snort and a heavy shove."""
    snort = s.bandpass(s.noise(0.16), 300, 1400) * env(0.16, 0.01, 5)
    shove = s.mix((thump(120, 45, 0.35, 5), 0.9), (s.lowpass(s.noise(0.3), 900) * env(0.3, 0.004, 5), 0.5))
    return s.mix((snort, 0.6), (s.at(shove, 0.08), 0.9))


def boar_b():
    """Hooves drumming into a cloud of dust."""
    hooves = s.mix(*[(s.at(thump(200, 90, 0.08, 9), t), 0.6) for t in (0.0, 0.07, 0.14)])
    dust = s.sweep_filter(s.noise(0.5), 600, 2500, q=1.0) * env(0.5, 0.05, 4)
    return s.mix((hooves, 0.9), (s.at(dust, 0.12), 0.5))


def boar_c():
    """A low thud and a dust whoosh rolling out."""
    return s.mix((thump(100, 40, 0.4, 5), 1.0), (s.whoosh(0.45, 1500, 400, q=1.1, attack=0.03, decay=4), 0.5))


DESIGNED = {
    "fx_wishing_star": [
        (star_a, "Twinkles falling, then a sparkly burst."),
        (star_b, "A whistling fall, then a bright chime."),
        (star_c, 'Two soft pings, then a magic "pom" with sparkle.'),
    ],
    "fx_spur_rowel": [
        (spur_a, "A spinning metal whirr with spur jingles in it."),
        (spur_b, 'Three bright "ching"s, rising.'),
        (spur_c, "A flick of the wrist, then a rowel whirring away."),
    ],
    "fx_splash_wave": [
        (splash_a, "A splash, and droplets falling after it."),
        (splash_b, 'A deep "sploosh" and bubbles.'),
        (splash_c, "A water blaster's \"pshh\" and a few plinks."),
    ],
    "fx_combo_counter": [
        (count_a, "A tiny two-note coin blip."),
        (count_b, 'One short square "bip".'),
        (count_c, 'A soft arcade "tik".'),
    ],
    "fx_combo_break": [
        (break_a, "Four 8-bit notes falling: the combo is lost."),
        (break_b, 'A square "bwowww" bending down.'),
        (break_c, "The digits shattering: a crack and falling pings."),
    ],
    "fx_comet_crash": [
        (comet_a, "A glint, a whistling fall, a crash with glass in it."),
        (comet_b, 'A hum swelling as it nears, then a deep "thoom".'),
        (comet_c, "Only a sparkle on the call; the fall comes late and fast."),
    ],
    "fx_bell_chime": [
        (bell_a, "A festival bell, struck once, ringing on."),
        (bell_b, 'A bright hand bell, "ding-ding".'),
        (bell_c, "A deep gong with a shimmer over it."),
    ],
    "fx_lava_burst": [
        (lava_a, "A rumble, five blorps along the line, a sizzle."),
        (lava_b, 'A fiery "whoomph" and crackling.'),
        (lava_c, "Three heavy pops, each lower, with a hiss."),
    ],
    "fx_thorn_burst": [
        (thorn_a, "A woody crack, and thorns flying out."),
        (thorn_b, 'A seed pod bursting: "pok" and a rustle.'),
        (thorn_c, 'A quick spray of needles, "fsst".'),
    ],
    "fx_boar_rush": [
        (boar_a, "A snort and a heavy shove."),
        (boar_b, "Hooves drumming into a cloud of dust."),
        (boar_c, "A low thud and a dust whoosh rolling out."),
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
