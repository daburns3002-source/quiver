"""The Mossy Glade theme (area 1's music): an original pastoral forest tune,
bright and chiptune-meets-orchestral, made from scratch here (no samples,
no borrowed melody), so all of it is ours to ship.

    python -I glade_theme.py <out_dir> [take ...]      (takes: a b; both by default)

Writes <out_dir>/glade_<take>.wav (44.1 kHz, 16-bit stereo), .ogg (what goes
to Roblox) and .mp3, plus manifest.json. F major, 104 BPM, 40 bars (92.3 s).

The loop is seamless by construction: everything that rings past the last bar
(releases, reverb, echoes) is folded back onto the start, and every filter and
the limiter run on the loop as a circle, so the last sample leads straight
into the first. The check at the end measures the seam against the rest.

Takes share the tune and differ in voicing:
  a  "Woodland": flute lead, ocarina in the minor middle, harp, strings,
     with the chip arpeggios as sparkle.
  b  "Route": a pulse-wave lead doubled by the flute an octave down, chip
     arpeggios throughout and a triangle bass under the pizzicato.
"""
import json
import os
import subprocess
import sys

import numpy as np
from scipy import signal
from scipy.io import wavfile
from scipy.ndimage import maximum_filter1d, minimum_filter1d

SR = 44100
BPM = 104
BEAT = 60 / BPM
BAR = 4 * BEAT
TARGET_LUFS = -16.0
CEILING = 0.84  # about -1.5 dBFS, headroom for the lossy encode

# ---------- the tune ----------
# One bar per "|". Chords may split a bar in two ("Csus4 C"); "F/A" puts A in
# the bass. Melodies are note:beats, r for a rest; each bar sums to 4.
SECTIONS = [
    # name, chords, lead melody, bells melody, drums
    ("intro", "F | Bbmaj7 | F | Csus4 C", None,
     "C6:1 F6:1 A6:2 | r:4 | C6:1 G6:1 A6:2 | r:4", "intro"),
    ("A", "F | Am | Bb | F | Dm | Gm7 | Bbmaj7 | Csus4 C",
     "C5:1 F5:1 A5:1.5 G5:.5 | A5:1.5 G5:.5 E5:1 C5:1 | D5:1 F5:1 Bb5:1.5 A5:.5 | A5:2 r:.5 F5:.5 G5:.5 A5:.5 | "
     "D6:1.5 C6:.5 A5:1 F5:1 | G5:1 Bb5:1 A5:1 G5:1 | F5:1.5 D5:.5 F5:1 A5:1 | G5:3 r:1",
     None, "A"),
    ("A2", "F | Am | Bb | Gm | Dm | Bb | C | F",
     "C5:1 F5:1 A5:1.5 G5:.5 | A5:1.5 C6:.5 E6:1 C6:1 | D6:1.5 C6:.5 Bb5:1 A5:.5 G5:.5 | Bb5:1 A5:.5 G5:.5 D5:2 | "
     "F5:1 A5:1 D6:1 C6:1 | Bb5:1.5 A5:.5 G5:1 F5:1 | E5:1 G5:1 C6:1 Bb5:1 | A5:3 r:1",
     None, "A2"),
    ("B", "Dm | C | Bb | A | Dm | Bb | Gm7 | C7",
     "A4:1 D5:1 E5:1 F5:1 | G5:2 E5:1 C5:1 | D5:1.5 F5:.5 Bb5:2 | A5:1.5 G5:.5 E5:1 C#5:1 | "
     "D5:1 F5:1 A5:1 D6:1 | D6:1.5 C6:.5 Bb5:1 A5:1 | Bb5:1 A5:.5 G5:.5 F5:1 D5:1 | E5:2 G5:1 Bb5:1",
     None, "B"),
    ("bridge", "Bb | F/A | Gm | Csus4 C", None,
     "F6:1 D6:1 Bb5:2 | C6:1 A5:1 F5:2 | D6:1 Bb5:1 G5:1 A5:1 | G5:2 r:2", "bridge"),
    ("A3", "F | Am | Bb | Gm | Dm | Bb | C | C7",
     "C5:1 F5:1 A5:1.5 G5:.5 | A5:1.5 C6:.5 E6:1 C6:1 | D6:1.5 C6:.5 Bb5:1 A5:.5 G5:.5 | Bb5:1 A5:.5 G5:.5 D5:2 | "
     "F5:1 A5:1 D6:1 C6:1 | Bb5:1.5 A5:.5 G5:1 F5:1 | E5:1 G5:1 C6:1 Bb5:1 | G5:2 E5:1 C5:1",
     None, "A3"),
]

# 16 steps a bar
DRUMS = {
    "intro": {"shaker": "....x.x.....x.x."},
    "A": {"kick": "x.......x.......", "wood": "....x.......x...", "shaker": "xxxxxxxxxxxxxxxx"},
    "A2": {"kick": "x.......x.......", "wood": "....x.......x...", "shaker": "xxxxxxxxxxxxxxxx",
           "tamb": "..x...x...x...x."},
    "B": {"taiko": "x.....x...x.....", "shaker": "x.x.x.x.x.x.x.x.", "wood": "............x..."},
    "bridge": {"shaker": "..x...x...x...x."},
    "A3": {"kick": "x.......x.......", "wood": "....x.......x...", "shaker": "xxxxxxxxxxxxxxxx",
           "tamb": "..x...x...x...x."},
}
# last-bar fills, replacing that bar's pattern for the named parts
FILLS = {
    "A": {"wood": "....x.......x.xx"},
    "A2": {"wood": "....x.......xx.x"},
    "B": {"taiko": "x.....x...x.x.xx", "wood": "................"},
    "A3": {"kick": "x...............", "taiko": "........x.x.xxxx", "wood": "....x..........."},
}

PC = {"C": 0, "C#": 1, "Db": 1, "D": 2, "Eb": 3, "E": 4, "F": 5, "F#": 6, "G": 7, "Ab": 8,
      "A": 9, "Bb": 10, "B": 11}
QUALITY = {"": [0, 4, 7], "m": [0, 3, 7], "7": [0, 4, 7, 10], "m7": [0, 3, 7, 10],
           "maj7": [0, 4, 7, 11], "sus4": [0, 5, 7]}

rng = np.random.default_rng(20261024)


def midi(name):
    return 12 * (int(name[-1]) + 1) + PC[name[:-1]]


def hz(m):
    return 440.0 * 2 ** ((m - 69) / 12)


def parse_chord(text):
    text, _, bass = text.partition("/")
    root = text[:2] if len(text) > 1 and text[1] in "b#" else text[:1]
    return PC[root], QUALITY[text[len(root):]], PC[bass] if bass else PC[root]


def parse_melody(text):
    bars = []
    for bar in text.split("|"):
        notes = []
        for tok in bar.split():
            name, beats = tok.split(":")
            notes.append((None if name == "r" else midi(name), float(beats)))
        assert abs(sum(b for _, b in notes) - 4) < 1e-6, bar
        bars.append(notes)
    return bars


def t_of(seconds):
    return np.arange(int(SR * seconds)) / SR


def lowpass(x, hz_, order=2):
    return signal.sosfilt(signal.butter(order, hz_, "low", fs=SR, output="sos"), x)


def bandpass(x, lo, hi, order=2):
    return signal.sosfilt(signal.butter(order, [lo, min(hi, SR / 2 - 100)], "band", fs=SR, output="sos"), x)


def highpass(x, hz_, order=2):
    return signal.sosfilt(signal.butter(order, hz_, "high", fs=SR, output="sos"), x)


def release_env(n_on, n_rel, attack):
    e = np.ones(n_on + n_rel)
    a = max(1, min(int(SR * attack), n_on))
    e[:a] = np.linspace(0, 1, a) ** 0.8
    e[n_on:] = np.linspace(1, 0, n_rel) ** 2
    return e


# ---------- voices ----------

def wind(f, dur, vel, harm, breath, vib, chiff):
    """Flute or ocarina: a few sine harmonics, breath noise, delayed vibrato."""
    rel = 0.14
    t = t_of(dur + rel)
    vib_in = np.clip((t - 0.2) / 0.35, 0, 1)
    fm = f * (1 + vib * vib_in * np.sin(2 * np.pi * 5.1 * t + rng.uniform(0, 6)))
    ph = 2 * np.pi * np.cumsum(fm) / SR
    x = sum(a * np.sin((k + 1) * ph) for k, a in enumerate(harm))
    air = bandpass(rng.standard_normal(len(t)), f * 0.8, f * 4)
    x = x + breath * air / (np.abs(air).max() + 1e-9) * (0.6 + 0.4 * np.sin(2 * np.pi * 3.3 * t))
    burst = bandpass(rng.standard_normal(len(t)), 1500, 7000) * np.exp(-t / 0.018)
    x = x + chiff * burst / (np.abs(burst).max() + 1e-9)
    env = release_env(int(SR * dur), len(t) - int(SR * dur), 0.05)
    env *= 1 - 0.12 * np.clip(t / max(dur, 0.1), 0, 1)  # a breath fades a little
    return vel * x * env


def flute(f, dur, vel):
    return wind(f, dur, vel, (1, 0.32, 0.12, 0.05, 0.02), 0.07, 0.004, 0.10)


def ocarina(f, dur, vel):
    return wind(f, dur, vel, (1, 0.07, 0.03), 0.10, 0.0055, 0.06)


def blep(p, dt):
    """PolyBLEP: rounds a waveform's jump so it doesn't alias into grit."""
    out = np.zeros_like(p)
    lo = p < dt
    hi = p > 1 - dt
    x = p[lo] / dt[lo]
    out[lo] = 2 * x - x * x - 1
    x = (p[hi] - 1) / dt[hi]
    out[hi] = x * x + 2 * x + 1
    return out


def pulse(f, dur, vel, duty=0.25, gate=0.85):
    """Chip voice: a pulse wave, gated short, a touch of late vibrato."""
    on = max(dur * gate, 0.05)
    t = t_of(on + 0.01)
    vib_in = np.clip((t - 0.25) / 0.2, 0, 1)
    fm = f * (1 + 0.006 * vib_in * np.sin(2 * np.pi * 6 * t))
    ph = np.cumsum(fm) / SR % 1
    dt = fm / SR
    x = np.where(ph < duty, 1.0, -1.0) + blep(ph, dt) - blep((ph + 1 - duty) % 1, dt) - (2 * duty - 1)
    env = np.ones(len(t))
    env *= 0.7 + 0.3 * np.exp(-t / 0.06)
    env[-int(SR * 0.01):] *= np.linspace(1, 0, int(SR * 0.01))
    env[:40] *= np.linspace(0, 1, 40)
    return vel * lowpass(x * env, 7500, 1)


def triangle(f, dur, vel):
    on = max(dur * 0.9, 0.05)
    t = t_of(on + 0.01)
    ph = f * t % 1
    x = 4 * np.abs(ph - 0.5) - 1
    env = np.ones(len(t))
    env[-int(SR * 0.01):] = np.linspace(1, 0, int(SR * 0.01))
    env[:40] *= np.linspace(0, 1, 40)
    return vel * x * env


_harp_cache = {}


def harp(m, vel, length=2.6):
    """Plucked string: inharmonic partials, the high ones dying first."""
    if m not in _harp_cache:
        f = hz(m)
        t = t_of(length)
        x = np.zeros(len(t))
        for k in range(1, 14):
            fk = f * k * (1 + 0.0003 * k * k)
            if fk > 15000:
                break
            a = abs(np.sin(np.pi * k * 0.13)) / k ** 1.1
            d = (1.4 + 0.75 * k) * (f / 330) ** 0.35
            x += a * np.exp(-d * t) * np.sin(2 * np.pi * fk * t + rng.uniform(0, 6))
        x[:90] *= np.linspace(0, 1, 90)
        _harp_cache[m] = x / np.abs(x).max()
    return vel * _harp_cache[m]


def pizz(f, dur, vel):
    """Round plucked bass."""
    t = t_of(min(dur, 1.6) + 0.12)
    ph = 2 * np.pi * f * t
    x = np.sin(ph) + 0.35 * np.exp(-5 * t) * np.sin(2 * ph) + 0.15 * np.exp(-9 * t) * np.sin(3 * ph)
    env = np.exp(-1.6 * t)
    env[:120] *= np.linspace(0, 1, 120)
    n_on = int(SR * min(dur, 1.6))
    env[n_on:] *= np.linspace(1, 0, len(t) - n_on) ** 2
    return vel * x * env


def strings(f, dur, vel):
    """Soft string pad voice: three detuned saws, low-passed, slow swell."""
    rel = 0.8
    t = t_of(dur + rel)
    x = np.zeros(len(t))
    for cents in (-7, 0, 7):
        fm = f * 2 ** (cents / 1200) * (1 + 0.002 * np.sin(2 * np.pi * (4.6 + cents / 20) * t + rng.uniform(0, 6)))
        ph = np.cumsum(fm) / SR % 1
        x += 2 * ph - 1 - blep(ph, fm / SR)
    x = lowpass(x, min(2400, f * 7), 2)
    return vel * x * release_env(int(SR * dur), int(SR * rel), 0.45)


def bell(f, vel):
    """Glockenspiel: bright inharmonic partials over a quick strike."""
    t = t_of(2.2)
    x = np.zeros(len(t))
    for ratio, amp, decay in ((1, 1, 2.0), (2.756, 0.45, 3.6), (5.404, 0.22, 6), (8.933, 0.1, 9)):
        if f * ratio < 18000:
            x += amp * np.exp(-decay * t) * np.sin(2 * np.pi * f * ratio * t)
    x[:30] *= np.linspace(0, 1, 30)
    return vel * x


def kick(vel):
    t = t_of(0.35)
    f = 48 + 90 * np.exp(-t / 0.035)
    x = np.sin(2 * np.pi * np.cumsum(f) / SR) * np.exp(-t / 0.12)
    return vel * x


def taiko(vel):
    t = t_of(0.6)
    f = 70 + 40 * np.exp(-t / 0.05)
    body = np.sin(2 * np.pi * np.cumsum(f) / SR) * np.exp(-t / 0.22)
    skin = lowpass(rng.standard_normal(len(t)), 900) * np.exp(-t / 0.04)
    return vel * (body + 0.6 * skin / np.abs(skin).max())


def shaker(vel):
    t = t_of(0.08)
    x = highpass(rng.standard_normal(len(t)), 6500) * np.exp(-t / 0.018)
    x[:60] *= np.linspace(0, 1, 60)
    return vel * x / np.abs(x).max()


def wood(vel):
    t = t_of(0.12)
    x = np.sin(2 * np.pi * 1150 * t) * np.exp(-t / 0.025) + 0.4 * bandpass(rng.standard_normal(len(t)), 1800, 4000) * np.exp(-t / 0.008)
    return vel * x


def tamb(vel):
    t = t_of(0.18)
    x = bandpass(rng.standard_normal(len(t)), 7000, 12000) * np.exp(-t / 0.05)
    x *= 1 + 0.5 * np.sin(2 * np.pi * 38 * t)  # the jingles' flutter
    return vel * x / np.abs(x).max()


DRUM_VOICES = {"kick": kick, "taiko": taiko, "shaker": shaker, "wood": wood, "tamb": tamb}


# ---------- arranging ----------

class Mix:
    def __init__(self, seconds):
        self.n = int(round(seconds * SR))
        self.tail = int(SR * 6)
        self.buses = {}

    def add(self, bus, at, x, pan=0.0, jitter=0.004):
        i = int(round((at + rng.normal(0, jitter)) * SR)) if jitter else int(round(at * SR))
        i = max(0, i)
        b = self.buses.setdefault(bus, np.zeros((self.n + self.tail, 2)))
        x = x[: len(b) - i]
        a = (pan + 1) * np.pi / 4
        b[i:i + len(x), 0] += np.cos(a) * x
        b[i:i + len(x), 1] += np.sin(a) * x


def fold(x, n):
    """Wrap everything past n samples back onto the start: the loop as a circle."""
    m = -(-len(x) // n)
    pad = np.zeros((m * n - len(x),) + x.shape[1:])
    return np.concatenate([x, pad]).reshape((m, n) + x.shape[1:]).sum(0)


def circular(fn, x, pad_s=3.0):
    """Run a stateful process (filter, limiter) on a loop with no seam."""
    p = int(SR * pad_s)
    y = fn(np.concatenate([x[-p:], x, x[:p]]))
    return y[p:p + len(x)]


def ladder(root, ivs, low):
    r = root
    while r < low:
        r += 12
    while r >= low + 12:
        r -= 12
    return sorted(r + iv + 12 * o for o in range(3) for iv in ivs)


def pad_voicing(ivs, root):
    # each chord tone in G3..F#4: smooth voice leading for free
    return [55 + (root + iv - 55) % 12 for iv in ivs]


def arrange(take):
    bars = []  # (section, bar index in section, [(chord, start beat, beats)])
    for name, chords, lead, bells, drums in SECTIONS:
        for i, cell in enumerate(chords.split("|")):
            parts = cell.split()
            each = 4 / len(parts)
            bars.append((name, i, [(parse_chord(c), j * each, each) for j, c in enumerate(parts)]))
    total = len(bars) * BAR
    mix = Mix(total)

    for b, (sec, i, chords) in enumerate(bars):
        t0 = b * BAR
        n_in_sec = sum(1 for s in bars if s[0] == sec)
        last = i == n_in_sec - 1
        for (root, ivs, bass), beat0, beats in chords:
            start = t0 + beat0 * BEAT
            # harp: up-and-back eighths over two octaves (sixteenths in the bridge)
            lad = ladder(root, ivs, 53 if sec != "bridge" else 60)
            pattern = [0, 2, 3, 4, 5, 4, 3, 2] if sec != "bridge" else [0, 1, 2, 3, 4, 5, 6, 7, 8, 7, 6, 5, 4, 3, 2, 1]
            step = 0.5 if sec != "bridge" else 0.25
            for k in range(int(beats / step)):
                m = lad[pattern[k % len(pattern)]]
                v = (0.9 if k % 2 == 0 else 0.7) * rng.uniform(0.85, 1.0)
                mix.add("harp", start + k * step * BEAT, harp(m, v), pan=-0.3)
            # pad
            pad_level = {"intro": 0.5, "A": 0.55, "A2": 0.7, "B": 1.0, "bridge": 0.8, "A3": 0.9}[sec]
            for j, m in enumerate(pad_voicing(ivs, root)):
                mix.add("pad", start, strings(hz(m), beats * BEAT, pad_level), pan=(-0.45, 0.45)[j % 2], jitter=0)
            # bass: root, then fifth on beat 3 (whole notes when it should breathe)
            bm = 36 + (bass - 36) % 12
            if bm < 41:
                bm += 12
            if sec in ("intro", "bridge") or beats < 4:
                hits = [(0, beats)]
            else:
                hits = [(0, 2), (2, 1.5), (3.5, 0.5)]
            for k, (off, ln) in enumerate(hits):
                m = bm + (7 if k == 1 else 0) - (12 if k == 1 and bm + 7 > 50 else 0)
                if k == 2:
                    m = bm + 12
                mix.add("bass", start + off * BEAT, pizz(hz(m), ln * BEAT, 0.9 if k == 0 else 0.7), jitter=0.002)
                if take == "b" and sec not in ("intro", "bridge"):
                    mix.add("chipbass", start + off * BEAT, triangle(hz(m), ln * BEAT * 0.8, 1.0), jitter=0)
            # chip arpeggio: sixteenths through the chord, an octave above the melody's home
            chip_on = sec in ("A2", "bridge", "A3") or (take == "b" and sec in ("A", "B"))
            if chip_on:
                tones = [m for m in ladder(root, ivs, 65)[:4]]
                for k in range(int(beats * 4)):
                    v = 0.55 if k % 4 == 0 else 0.4
                    mix.add("chip", start + k * 0.25 * BEAT, pulse(hz(tones[k % 4]), 0.25 * BEAT, v, duty=0.125, gate=0.6),
                            pan=0.35, jitter=0)
        # drums
        pat = dict(DRUMS[sec])
        if last:
            pat.update(FILLS.get(sec, {}))
        for part, steps in pat.items():
            for k, c in enumerate(steps):
                if c != "x":
                    continue
                accent = {0: 1.0, 2: 0.55, 1: 0.35, 3: 0.4}[k % 4]
                if part != "shaker":
                    accent = 1.0 if k % 4 == 0 else 0.8
                pan = {"shaker": 0.4, "wood": -0.2, "tamb": 0.5}.get(part, 0.0)
                mix.add(part if part in ("kick", "taiko") else "perc", t0 + k * 0.25 * BEAT,
                        DRUM_VOICES[part](accent * rng.uniform(0.85, 1.0) * {"wood": 0.5, "tamb": 0.35}.get(part, 1.0)),
                        pan=pan, jitter=0.003)

    # melodies
    t = 0.0
    for name, chords, lead, bells, drums in SECTIONS:
        n_bars = len(chords.split("|"))
        if lead:
            for bi, bar in enumerate(parse_melody(lead)):
                beat = 0.0
                for m, beats in bar:
                    if m is not None:
                        at = t + (bi * 4 + beat) * BEAT
                        dur = beats * BEAT * 0.97
                        v = (1.0 if beat == 0 else 0.88) * rng.uniform(0.92, 1.0)
                        if take == "a":
                            voice = ocarina if name == "B" else flute
                            mix.add("lead", at, voice(hz(m), dur, v), pan=0.05, jitter=0.006)
                            if name == "A3":  # the chip joins the last verse, an octave up
                                mix.add("chiplead", at, pulse(hz(m + 12), dur, 0.5, duty=0.25), pan=0.3, jitter=0)
                        else:
                            duty = 0.5 if name == "B" else 0.25
                            mix.add("chiplead", at, pulse(hz(m), dur, v, duty=duty), pan=0.0, jitter=0)
                            mix.add("lead", at, flute(hz(m - 12), dur, 0.55 * v), pan=-0.15, jitter=0.006)
                    beat += beats
        if bells:
            for bi, bar in enumerate(parse_melody(bells)):
                beat = 0.0
                for m, beats in bar:
                    if m is not None:
                        mix.add("bells", t + (bi * 4 + beat) * BEAT, bell(hz(m), 0.8 * rng.uniform(0.9, 1.0)), pan=0.25)
                    beat += beats
        t += n_bars * BAR
    return mix


# bus: (level dB RMS while playing, reverb send, echo)
BUSES = {
    "lead": (-19, 0.28, True),
    "chiplead": (-23, 0.16, True),
    "harp": (-23, 0.34, False),
    "pad": (-27, 0.40, False),
    "bass": (-22, 0.05, False),
    "chipbass": (-31, 0.0, False),
    "chip": (-31, 0.18, False),
    "bells": (-27, 0.45, True),
    "kick": (-26, 0.06, False),
    "taiko": (-25, 0.20, False),
    "perc": (-33, 0.14, False),
}
BUS_TRIM = {"b": {"chiplead": 4, "lead": -3, "chip": 2}}


def reverb_ir(rt=2.0, length=3.0):
    t = t_of(length)
    env = 10 ** (-3 * t / rt)
    ir = np.zeros((len(t), 2))
    mix = np.clip(t / 1.2, 0, 1)
    for c in range(2):
        nz = rng.standard_normal(len(t))
        dark = lowpass(nz, 2500, 1) * 2.2
        ir[:, c] = ((1 - mix) * nz + mix * dark) * env
    ir = np.concatenate([np.zeros((int(SR * 0.018), 2)), ir])
    return ir / np.sqrt((ir ** 2).sum() / 2)


def rms_db(x):
    active = np.abs(x).max(axis=1) > 1e-3
    if not active.any():
        return -120.0
    return 10 * np.log10((x[active] ** 2).mean() + 1e-20)


def limiter(x, ceiling=CEILING):
    peak = np.abs(x).max(axis=1)
    w = int(0.004 * SR)
    g = np.minimum(1.0, ceiling / np.maximum(maximum_filter1d(peak, 2 * w + 1), 1e-9))
    g = minimum_filter1d(g, 2 * w + 1)
    win = np.hanning(2 * w + 1)
    g = np.convolve(g, win / win.sum(), mode="same")
    return x * g[:, None]


def lufs(path):
    out = subprocess.run(["ffmpeg", "-hide_banner", "-nostats", "-i", path, "-af", "ebur128=peak=true", "-f", "null", "-"],
                         capture_output=True, text=True).stderr
    summary = out[out.rfind("Summary:"):]
    i = float(summary.split("I:")[1].split("LUFS")[0])
    tp = float(summary.split("Peak:")[1].split("dBFS")[0])
    return i, tp


def write_wav(path, x):
    wavfile.write(path, SR, (np.clip(x, -1, 1) * 32767).astype(np.int16))


def master(take, out_dir, arrange_fn=None, buses=None, trims=None, name="glade", beat=BEAT):
    """Mix, master and encode one take; other tracks pass their own arrangement."""
    mix = (arrange_fn or arrange)(take)
    buses = buses or BUSES
    trims = BUS_TRIM if trims is None else trims
    n = mix.n
    ir = reverb_ir()
    dry = np.zeros((n, 2))
    send = np.zeros((n, 2))
    levels = {}
    for bus, x in mix.buses.items():
        target, rev, echo = buses[bus]
        target += trims.get(take, {}).get(bus, 0)
        x = fold(x, n)
        x *= 10 ** ((target - rms_db(x)) / 20)
        if echo:  # dotted-eighth ping-pong, quiet
            d = int(round(0.75 * beat * SR))
            e = np.zeros_like(x)
            for k, (gain, ch) in enumerate(((0.22, 1), (0.12, 0), (0.06, 1)), start=1):
                e[:, ch] += np.roll(x.sum(1) * 0.5, d * k) * gain
            x = x + e
        levels[bus] = round(rms_db(x), 1)
        dry += x
        send += rev * x
    wet = np.stack([signal.fftconvolve(send[:, c], ir[:, c]) for c in range(2)], axis=1)
    mixed = dry + 0.55 * fold(wet, n)

    def tone(y):
        y = highpass(y.T, 30, 2).T
        # a little air on top
        sos = signal.butter(1, 6000, "high", fs=SR, output="sos")
        return y + 0.12 * signal.sosfilt(sos, y.T).T

    mixed = circular(tone, mixed)
    gain_db = 0.0
    path = os.path.join(out_dir, f"{name}_{take}.wav")
    for _ in range(4):
        y = circular(limiter, mixed * 10 ** (gain_db / 20))
        write_wav(path, y)
        i, tp = lufs(path)
        if abs(i - TARGET_LUFS) < 0.2:
            break
        gain_db += TARGET_LUFS - i
    ogg = path[:-4] + ".ogg"
    mp3 = path[:-4] + ".mp3"
    subprocess.run(["ffmpeg", "-y", "-loglevel", "error", "-i", path, "-c:a", "libvorbis", "-q:a", "5", ogg], check=True)
    subprocess.run(["ffmpeg", "-y", "-loglevel", "error", "-i", path, "-c:a", "libmp3lame", "-b:a", "192k", mp3], check=True)
    return {"take": take, "seconds": round(n / SR, 2), "samples": n, "lufs": i, "true_peak_db": tp,
            "bus_rms_db": levels, "seam": seam_check(y)}


def seam_check(y):
    """Sample-to-sample jump at the seam, against the loudest 1% of jumps inside."""
    d = np.abs(np.diff(y, axis=0)).max(axis=1)
    seam = float(np.abs(y[0] - y[-1]).max())
    return {"jump": round(seam, 5), "p99_inside": round(float(np.percentile(d, 99)), 5),
            "max_inside": round(float(d.max()), 5)}


if __name__ == "__main__":
    out_dir = sys.argv[1]
    takes = sys.argv[2:] or ["a", "b"]
    os.makedirs(out_dir, exist_ok=True)
    notes = {
        "a": "Woodland: flute lead, ocarina in the minor middle, harp, strings and pizzicato, chip arpeggios as sparkle.",
        "b": "Route: the same tune on a pulse-wave lead with the flute an octave under, chip arpeggios throughout, a triangle bass.",
    }
    manifest = []
    for take in takes:
        info = master(take, out_dir)
        info["note"] = notes[take]
        manifest.append(info)
        print(json.dumps(info))
    json.dump(manifest, open(os.path.join(out_dir, "manifest.json"), "w"), indent=1)
