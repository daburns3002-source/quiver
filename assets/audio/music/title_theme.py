"""The title theme: the intro cutscene's music (owner, 2026-10-25: quiet and
building while "DYL.DEVS PRESENTS" shows on black, then "a grandiose song"
from the moment the "Archer Legends" picture cuts in). Original, made from
scratch with the Mossy Glade theme's voices and mastering (`glade_theme.py`)
and the boss theme's brass and drums (`boss_theme.py`).

    python -I title_theme.py <out_dir> [take ...]      (takes: a-g; d e f g by default)

Writes <out_dir>/title_<take>.wav, .ogg and .mp3 (the loop alone) and
title_<take>_build.* (what ships): the 5.0 s build, the theme's first bar
landing on exactly 5.0 s (the cutscene's cut, `intro-cutscene-contract.md`),
then the theme in a loop region (`Sound.LoopRegion`) while the title screen
waits. Plus manifest.json. Takes render in order a, b, c: each draws on one
seeded generator, so rendering one alone would change it.
B flat major, 96 BPM (two bars are the build's 5.0 s), 24 bars (60 s).

The build: a low drone swelling up from silence, a glint of bells as the
words pop in (0.6 s), a heartbeat of taiko quickening, a chip arpeggio
climbing on the dominant, a noise riser and a snare roll peaking over the
last second (3.8-5.0 s), a breath of silence, then the hit: a boom, a crash
and the whole band on B flat.

  a  "Chip + Brass": the boss pick's sound made grand: pulse lead over the
     flute, a brass section doubling it, string ostinato, orchestral stabs.
  b  "Chip Anthem": the glade and level picks' sound: pulse lead and flute,
     chip arpeggios, the brass only in the stabs.
  c  "Orchestral": a brass lead with bells over its long notes, harp
     arpeggios and strings, the chip only as sparkle.

Round 2 (round 21 on the audition page, its A-D): the owner disliked all
three melodies, so d-g are four new tunes (`TAKES`), each voiced as take a.
  d  "Rise"   e  "Saga" (G minor)   f  "March"   g  "Soar"
"""
import json
import os
import sys

import numpy as np

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import boss_theme as bt  # noqa: E402
import glade_theme as g  # noqa: E402

SR = g.SR
BPM = 96
BEAT = 60 / BPM
BAR = 4 * BEAT
HIT = 5.0  # the cutscene's cut to the picture: the theme's first downbeat
assert abs(2 * BAR - HIT) < 1e-9

SECTIONS = [
    # name, chords, lead
    ("A", "Bb | F/A | Gm | Eb | Cm | F | Gm Eb | F",
     "F5:.75 F5:.25 Bb5:1 D6:1.5 C6:.5 | C6:1 A5:1 F5:2 | G5:.75 A5:.25 Bb5:1 D6:1 G6:1 | F6:1.5 Eb6:.5 D6:1 Bb5:1 | "
     "C6:.75 D6:.25 Eb6:1 G6:1.5 F6:.5 | F6:1 C6:1 A5:2 | Bb5:1 D6:1 Eb6:1 G6:1 | F6:3 r:1"),
    ("B", "Gm | Eb | Bb | F | Gm | Eb | Cm | F7",
     "D6:2 Bb5:1 G5:1 | Eb6:1.5 D6:.5 C6:1 Bb5:1 | D6:2 F6:2 | C6:3 A5:1 | "
     "Bb5:1 D6:1 G6:2 | G6:1 F6:1 Eb6:1 G6:1 | F6:1.5 Eb6:.5 D6:1 C6:1 | C6:2 A5:.5 C6:.5 Eb6:.5 F6:.5"),
    ("A2", "Bb | F/A | Gm | Eb | Cm | Eb F | Bb | F",
     "F6:.75 F6:.25 D6:1 Bb5:1.5 C6:.5 | C6:1 A5:1 F5:1 C6:1 | D6:.75 Eb6:.25 F6:1 G6:1.5 F6:.5 | Eb6:1 D6:1 C6:1 Bb5:1 | "
     "C6:1.5 D6:.5 Eb6:1 C6:1 | D6:1 Eb6:1 F6:1 A5:1 | Bb5:4 | F6:2 Eb6:.5 D6:.5 C6:.5 A5:.5"),
]

# Round 2 (owner, 2026-10-25: "i dont like the melody on any of these redo
# them"): four new tunes, each its own take, all voiced as take a.
RISE = [
    ("A", "Bb | Bb | Eb | Bb | Gm | Eb | C | F",
     "F5:1 Bb5:1.5 C6:.5 D6:1 | F6:3 D6:.5 Bb5:.5 | Eb6:1.5 D6:.5 C6:1 Bb5:1 | D6:2 F5:1 Bb5:1 | "
     "G5:1 Bb5:1.5 C6:.5 D6:1 | G6:3 Eb6:.5 D6:.5 | E6:1.5 D6:.5 C6:1 E6:1 | F6:3 r:1"),
    ("B", "Eb | F | Dm | Gm | Cm | F | Bb/D Eb | F",
     "G5:1 Bb5:1 Eb6:2 | F6:1.5 Eb6:.5 D6:1 C6:1 | D6:1 F6:1 A6:2 | G6:2 F6:1 D6:1 | "
     "Eb6:1.5 D6:.5 C6:1 G5:1 | A5:1 C6:1 F6:2 | F6:1 D6:1 Eb6:1 G6:1 | F6:2 C6:1 A5:1"),
    ("A2", "Bb | Bb | Eb | Bb | Gm | Eb | F | F",
     "F5:1 Bb5:1.5 C6:.5 D6:1 | F6:3 G6:.5 F6:.5 | Eb6:1.5 F6:.5 G6:1 Bb6:1 | Bb6:2 F6:1 D6:1 | "
     "G6:1 F6:1 D6:1 Bb5:1 | Eb6:1.5 F6:.5 G6:2 | F6:2 D6:1 C6:1 | C6:2 D6:.5 C6:.5 A5:.5 F5:.5"),
]
SAGA = [
    ("A", "Gm | Eb | Bb | F | Gm | Eb | Cm | D",
     "D5:1 G5:1 A5:1 Bb5:1 | G5:3 Bb5:.5 C6:.5 | D6:2 C6:1 Bb5:1 | C6:3 r:1 | "
     "D6:1 G6:1 F6:1 D6:1 | Eb6:2 D6:1 C6:1 | C6:1 Eb6:1 D6:1 C6:1 | D6:3 r:1"),
    ("B", "Eb | Bb | F | Gm | Eb | Bb | Cm | D",
     "Bb5:1 Eb6:1 G6:2 | F6:1.5 D6:.5 Bb5:2 | C6:1 F6:1 A6:2 | G6:2 D6:2 | "
     "Eb6:1 G6:1 Bb6:2 | Bb6:1.5 A6:.5 F6:2 | G6:1 Eb6:1 C6:1 Eb6:1 | D6:2 F#6:1 A6:1"),
    ("A2", "Gm | Eb | Bb | F | Gm | Eb | Cm D | D",
     "D5:1 G5:1 A5:1 Bb5:1 | G5:3 Bb5:.5 C6:.5 | D6:2 C6:1 Bb5:1 | C6:3 r:1 | "
     "D6:1 G6:1 F6:1 D6:1 | Eb6:2 D6:1 C6:1 | C6:1 Eb6:1 D6:1 F#6:1 | G6:2 F#6:1 D6:1"),
]
MARCH = [
    ("A", "Bb | F | Bb | F | Eb | Bb | C | F",
     "Bb5:.75 Bb5:.25 Bb5:.75 Bb5:.25 D6:1 F6:1 | F6:1.5 Eb6:.5 C6:2 | D6:.75 D6:.25 D6:.75 D6:.25 F6:1 Bb6:1 | A6:3 r:1 | "
     "G6:.75 F6:.25 Eb6:1 Bb5:1 Eb6:1 | D6:.75 C6:.25 Bb5:1 F5:1 Bb5:1 | C6:.75 D6:.25 E6:1 G6:1 E6:1 | F6:2 C6:1 A5:1"),
    ("B", "Gm | D | Eb | Bb | Cm | Gm | Eb | F",
     "G5:1.5 A5:.5 Bb5:1 D6:1 | A5:1.5 D6:.5 F#6:2 | G6:1.5 F6:.5 Eb6:1 Bb5:1 | D6:3 r:1 | "
     "Eb6:1.5 D6:.5 C6:1 G5:1 | Bb5:1.5 A5:.5 G5:1 D6:1 | Eb6:1 G6:1 Bb6:1 G6:1 | F6:.75 F6:.25 F6:.75 F6:.25 F6:.5 G6:.5 A6:1"),
    ("A2", "Bb | F | Bb | F | Eb | Bb | C | F",
     "Bb5:.75 Bb5:.25 Bb5:.75 Bb5:.25 D6:1 F6:1 | F6:1.5 Eb6:.5 C6:2 | D6:.75 D6:.25 D6:.75 D6:.25 F6:1 Bb6:1 | A6:3 r:1 | "
     "G6:.75 F6:.25 Eb6:1 Bb5:1 Eb6:1 | D6:.75 C6:.25 Bb5:1 D6:1 F6:1 | C6:.75 D6:.25 E6:1 G6:1 E6:1 | F6:.75 F6:.25 F6:.75 F6:.25 C6:1 A5:1"),
]
SOAR = [
    ("A", "Bb | Gm | Eb | F | Bb/D | Eb | Cm | F",
     "F5:1 D6:2 C6:.5 Bb5:.5 | Bb5:1 G5:2 D5:1 | Eb5:1 C6:2 Bb5:.5 G5:.5 | A5:3 F5:1 | "
     "F5:1 F6:2 Eb6:.5 D6:.5 | Eb6:1.5 D6:.5 C6:1 Bb5:1 | C6:1 Eb6:1 G6:1 F6:.5 Eb6:.5 | C6:3 r:1"),
    ("B", "Gm | Eb | Bb | F | Gm | Eb | Cm | F7",
     "D6:1.5 Eb6:.5 D6:1 Bb5:1 | G5:1 Bb5:1 Eb6:2 | F6:1.5 G6:.5 F6:1 D6:1 | C6:3 r:1 | "
     "D6:1.5 Eb6:.5 F6:1 G6:1 | Bb6:2 G6:1 Eb6:1 | F6:1.5 Eb6:.5 D6:1 C6:1 | Eb6:2 C6:1 A5:1"),
    ("A2", "Bb | Gm | Eb | F | Bb/D | Eb | Cm F | F",
     "F5:1 D6:2 C6:.5 Bb5:.5 | Bb5:1 G6:2 F6:1 | Eb6:1 C6:2 Bb5:.5 G5:.5 | A5:2 C6:1 F6:1 | "
     "F6:1 Bb6:2 A6:.5 G6:.5 | G6:1.5 F6:.5 Eb6:1 G6:1 | F6:1 Eb6:1 D6:1 C6:1 | C6:2 A5:1 F5:1"),
]
# take: (voicing, tune)
TAKES = {"a": ("a", SECTIONS), "b": ("b", SECTIONS), "c": ("c", SECTIONS),
         "d": ("a", RISE), "e": ("a", SAGA), "f": ("a", MARCH), "g": ("a", SOAR)}

# 16 steps a bar: broad half-time drums, the B section driving
DRUMS = {
    "A": {"kick": "x.......x.......", "snare": "........x.......", "taiko": "x.....x...x.....", "hat": "x.x.x.x.x.x.x.x."},
    "B": {"kick": "x.......x.x.....", "snare": "....x.......x...", "taiko": "x...x...x...x...", "hat": "x.x.x.x.x.x.x.x."},
    "A2": {"kick": "x.....x.x.......", "snare": "....x.......x...", "taiko": "x.....x...x.....", "hat": "xxx.xxx.xxx.xxx."},
}
FILLS = {
    "A": {"snare": "........x...xxxx", "taiko": "............x.x."},
    "B": {"snare": "....x...xxxxxxxx", "taiko": "x...x...x.x.x.x."},
    "A2": {"snare": "....x.......xxxx", "taiko": "........x.x.x.x."},
}
DRUM_VOICES = {"kick": bt.kick, "snare": bt.snare, "hat": bt.hat, "taiko": g.taiko}


def bars_of(sections):
    bars = []
    for name, chords, _ in sections:
        cells = chords.split("|")
        for i, cell in enumerate(cells):
            parts = cell.split()
            each = 4 / len(parts)
            bars.append((name, i, len(cells), [(g.parse_chord(c), j * each, each) for j, c in enumerate(parts)]))
    return bars


def arrange(take):
    take, tune = TAKES[take]  # from here, `take` is the voicing
    bars = bars_of(tune)
    mix = g.Mix(len(bars) * BAR)
    add = mix.add
    for b, (sec, i, n_sec, chords) in enumerate(bars):
        t0 = b * BAR
        for (root, ivs, bass), beat0, beats in chords:
            start = t0 + beat0 * BEAT
            bm = 34 + (bass - 34) % 12  # Bb1..A2
            # bass: broad half notes in A, driving eighths in B and A2
            if sec == "A":
                for k in range(int(beats / 2) or 1):
                    add("bass", start + 2 * k * BEAT, g.triangle(g.hz(bm), 1.9 * BEAT, 1.0), jitter=0)
                    add("bass", start + 2 * k * BEAT, g.pizz(g.hz(bm), 1.6 * BEAT, 0.6), jitter=0.002)
            else:
                steps = [0, 0, 12, 0, 0, 12, 7, 12]
                for k in range(int(beats * 2)):
                    m = bm + steps[k % 8]
                    v = 1.0 if k % 2 == 0 else 0.75
                    add("bass", start + k * 0.5 * BEAT, g.triangle(g.hz(m), 0.45 * BEAT, v), jitter=0)
                    add("bass", start + k * 0.5 * BEAT, g.pizz(g.hz(m), 0.4 * BEAT, 0.6 * v), jitter=0.002)
            if take in ("a", "c") or sec == "B":
                for k in range(int(beats * 2)):
                    m = bm + 12 + (0, 7)[k % 2]
                    add("ostinato", start + k * 0.5 * BEAT, bt.ostinato(g.hz(m), 0.45 * BEAT, 1.0 if k % 2 == 0 else 0.8),
                        pan=-0.25, jitter=0.003)
            # pad: held strings, widest in the reprise
            level = {"A": 0.7, "B": 0.85, "A2": 1.0}[sec]
            for j, m in enumerate(g.pad_voicing(ivs, root)):
                add("pad", start, g.strings(g.hz(m), beats * BEAT, level), pan=(-0.45, 0.45)[j % 2], jitter=0)
                add("pad", start, g.strings(g.hz(m - 12), beats * BEAT, 0.5 * level), pan=(0.3, -0.3)[j % 2], jitter=0)
            # arpeggio: chip sixteenths (harp eighths in the orchestral take)
            tones = g.ladder(root, ivs, 62)[:5]
            tones = tones + tones[-2:0:-1]
            if take == "c":
                for k in range(int(beats * 2)):
                    add("harp", start + k * 0.5 * BEAT, g.harp(tones[k % len(tones)] - 12, 0.8 if k % 2 == 0 else 0.6), pan=0.3)
                if sec == "A2":
                    for k in range(int(beats * 4)):
                        add("chip", start + k * 0.25 * BEAT, g.pulse(g.hz(tones[k % len(tones)] + 12), 0.25 * BEAT, 0.4,
                                                                      duty=0.125, gate=0.5), pan=0.4, jitter=0)
            else:
                for k in range(int(beats * 4)):
                    v = 0.55 if k % 4 == 0 else 0.4
                    add("chip", start + k * 0.25 * BEAT,
                        g.pulse(g.hz(tones[k % len(tones)]), 0.25 * BEAT, v, duty=0.125, gate=0.6), pan=0.35, jitter=0)
            # stabs: the band on the chord, dotted, on every take
            for off in (0, 1.5, 3) if sec != "A" else (0,):
                if off < beats:
                    for m in g.pad_voicing(ivs, root):
                        add("stabs", start + off * BEAT, bt.brass(g.hz(m), 0.4 * BEAT, 0.8), pan=0.1, jitter=0.002)
        # drums
        pat = dict(DRUMS[sec])
        if i == n_sec - 1:
            pat.update(FILLS[sec])
        for part, steps in pat.items():
            for k, c in enumerate(steps):
                if c != "x":
                    continue
                if part == "hat":
                    v = 0.8 if k % 4 == 0 else 0.5
                elif part == "snare" and i == n_sec - 1 and k >= 8:
                    v = 0.45 + 0.55 * (k - 8) / 7
                else:
                    v = 1.0 if k % 4 == 0 else 0.8
                add({"hat": "perc"}.get(part, part), t0 + k * 0.25 * BEAT, DRUM_VOICES[part](v * g.rng.uniform(0.88, 1.0)),
                    pan={"hat": 0.35}.get(part, 0.0), jitter=0.002)
        if i == 0:
            add("crash", t0, bt.crash(1.0), pan=-0.3, jitter=0)

    # the tune
    t = 0.0
    for name, chords, lead in tune:
        for bi, bar in enumerate(g.parse_melody(lead)):
            beat = 0.0
            for m, beats in bar:
                if m is not None:
                    at = t + (bi * 4 + beat) * BEAT
                    dur = beats * BEAT * 0.95
                    v = (1.0 if beat % 2 == 0 else 0.88) * g.rng.uniform(0.92, 1.0)
                    if take == "c":
                        add("brass", at, bt.brass(g.hz(m - 12), dur, v), pan=0.1, jitter=0.004)
                        add("lead", at, g.flute(g.hz(m), dur, 0.4 * v), pan=-0.15, jitter=0.005)
                        if beats >= 1.5:
                            add("bells", at, g.bell(g.hz(m + 12), 0.8 * v), pan=0.25)
                    else:
                        duty = 0.5 if name == "B" else 0.25
                        add("chiplead", at, g.pulse(g.hz(m), dur, v, duty=duty), jitter=0)
                        add("lead", at, g.flute(g.hz(m - 12), dur, 0.55 * v), pan=-0.15, jitter=0.005)
                        if take == "a":
                            add("brass", at, bt.brass(g.hz(m - 12), dur, v), pan=0.15, jitter=0.004)
                beat += beats
        t += len(chords.split("|")) * BAR
    return mix


# ---------- the build: 0 to 5.0 s, then the hit ----------

def swell(f, dur, power=2.5):
    """A drone of detuned saws opening up from silence: louder and brighter
    towards the end, like a held breath."""
    n = int(SR * dur)
    t = np.arange(n) / SR
    x = bt.saws(f, n, (-10, 0, 10))
    u = t / dur
    dark = g.lowpass(x, f * 1.5, 2)
    bright = g.lowpass(x, min(f * 10, 6000), 2)
    y = dark + (bright - dark) * u ** 2
    return y * u ** power


def riser(dur):
    """Noise through a band climbing three octaves, swelling to the end."""
    n = int(SR * dur)
    u = np.arange(n) / n
    nz = g.rng.standard_normal(n)
    out = np.zeros(n)
    # a few overlapping bands stepped upwards, crossfaded: a sweep without per-sample filters
    k = 12
    for j in range(k):
        lo = 300 * 2 ** (3 * j / k)
        band = g.bandpass(nz, lo, lo * 1.8)
        centre = (j + 0.5) / k
        out += band * np.clip(1 - np.abs(u - centre) * k / 1.5, 0, 1)
    return out / np.abs(out).max() * u ** 3


def boom(vel):
    """The hit's low end: a sine dropping from 110 to 35 Hz."""
    t = g.t_of(1.8)
    f = 35 + 75 * np.exp(-t / 0.08)
    x = np.sin(2 * np.pi * np.cumsum(f) / SR) * np.exp(-t / 0.55)
    x[:40] *= np.linspace(0, 1, 40)
    return vel * x


GAP = 0.08  # the breath of silence before the hit


def build_arrange(take):
    first = TAKES[take][1][0][1].split("|")[0].split()[0]  # the tune's first chord, which the hit lands on
    take = TAKES[take][0]
    mix = g.Mix(HIT)
    add = mix.add
    cut = HIT - GAP
    # the drone: B flat and F, low, swelling from nothing (E flat, then the dominant)
    for m, pan in ((34, 0.0), (41, -0.3), (46, 0.3)):
        x = swell(g.hz(m), cut - 0.15)
        add("drone", 0.15, x, pan=pan, jitter=0)
    # the strings come in on E flat, move to F sus, then F
    for (chord, at, dur, vel) in (("Eb", 0.6, 1.9, 0.35), ("Fsus4", 2.5, 1.25, 0.6), ("F", 3.75, cut - 3.75, 0.9)):
        root, ivs, _ = g.parse_chord(chord)
        for j, m in enumerate(g.pad_voicing(ivs, root)):
            x = g.strings(g.hz(m), dur, vel)
            add("pad", at, x * np.linspace(0.4, 1, len(x)), pan=(-0.45, 0.45)[j % 2], jitter=0)
    # the glint as DYL.DEVS PRESENTS pops in
    for m, dt in ((82, 0.0), (77, 0.07), (86, 0.14)):  # Bb5 F5 D6
        add("glint", 0.6 + dt, g.bell(g.hz(m), 0.7), pan=0.25)
        add("glint", 0.6 + dt, g.harp(m - 12, 0.7), pan=-0.2)
    # heartbeat: taiko on halves from the words, then quarters, then eighths
    beats = [2.0, 4.0, 5.0, 6.0, 6.5, 7.0, 7.5]
    for b in beats:
        at = b * BEAT
        if at < cut:
            add("taiko", at, g.taiko(0.35 + 0.65 * (at / cut) ** 1.5), jitter=0)
    # chip arpeggio climbing on the dominant, from the second half note
    tones = g.ladder(5, [0, 4, 7, 10], 53)[:9]  # F7 from F3, two-and-a-bit octaves
    k = 0
    t = 2 * BEAT
    while t < cut - 0.05:
        u = (t - 2 * BEAT) / (cut - 2 * BEAT)
        m = tones[min(int(u * len(tones) * 1.0), len(tones) - 1)] + (0, 7, 12)[k % 3]
        if take == "c":
            add("harp", t, g.harp(m, 0.3 + 0.6 * u), pan=0.3)
        else:
            add("chip", t, g.pulse(g.hz(m), 0.25 * BEAT, 0.25 + 0.5 * u, duty=0.125, gate=0.6), pan=0.35, jitter=0)
        k += 1
        t += 0.25 * BEAT
    # riser and the snare roll over the peak (3.8 s on)
    add("riser", 2.2, riser(cut - 2.2), jitter=0)
    t = 6 * BEAT  # 3.75 s
    while t < cut - 0.02:
        u = (t - 6 * BEAT) / (cut - 6 * BEAT)
        add("snare", t, bt.snare(0.3 + 0.7 * u), jitter=0)
        t += (0.25 if u < 0.5 else 0.125) * BEAT
    # the hit, into the theme's first bar
    add("boom", HIT, boom(1.0), jitter=0)
    add("crash", HIT, bt.crash(1.0), pan=0.3, jitter=0)
    add("taiko", HIT, g.taiko(1.0), jitter=0)
    root, ivs, _ = g.parse_chord(first)
    for m in sorted({46 + (root + iv - 46) % 12 + o for iv in ivs for o in (0, 12)}):  # wide, from B flat 2 up
        add("stabs", HIT, bt.brass(g.hz(m), 1.2 * BEAT, 0.9), pan=0.1, jitter=0)
    # the breath: nothing but reverb in the last moment before the hit
    gap = int(round(cut * SR)), int(round(HIT * SR))
    for bus, x in mix.buses.items():
        fade = int(0.01 * SR)
        x[gap[0] - fade:gap[0]] *= np.linspace(1, 0, fade)[:, None]
        x[gap[0]:gap[1]] = 0
    return mix


# bus: (level dB RMS while playing, reverb send, echo)
BUSES = {
    "chiplead": (-19.5, 0.14, True),
    "lead": (-23, 0.22, False),
    "brass": (-21, 0.24, False),
    "bass": (-21, 0.03, False),
    "ostinato": (-26, 0.08, False),
    "pad": (-25, 0.38, False),
    "chip": (-29, 0.15, False),
    "harp": (-24, 0.32, False),
    "stabs": (-23, 0.28, False),
    "bells": (-25, 0.42, True),
    "kick": (-23, 0.04, False),
    "snare": (-25, 0.18, False),
    "taiko": (-23, 0.22, False),
    "perc": (-31, 0.08, False),
    "crash": (-30, 0.22, False),
    # the build's own
    "drone": (-27, 0.3, False),
    "riser": (-31, 0.3, False),
    "glint": (-31, 0.45, True),
    "boom": (-20, 0.1, False),
}
TRIMS = {"a": {"chiplead": -1.5, "lead": -2, "chip": -2}, "c": {"lead": -4, "brass": 1}}

NOTES = {
    "d": "Rise: B flat major, a leaping heroic call (up a fourth, climbing to a held high F), a big lift through C major at the end of each phrase.",
    "e": "Saga: G minor, an old-legend tune that walks up step by step, turns to the major (E flat, B flat) in the middle and climbs to a high A.",
    "f": "March: B flat major, a triumphant fanfare of repeated notes (ta-ta ta-ta, up the chord), a minor middle that marches back.",
    "g": "Soar: B flat major, a lyrical tune of wide leaps (up a sixth), long held notes over the band, the most singable.",
    "a": "Chip + Brass: the boss pick's sound made grand: pulse lead over the flute with a brass section doubling it, a string ostinato, orchestral stabs.",
    "b": "Chip Anthem: closest to the glade and level music: pulse lead and flute, chip arpeggios, the brass only in the stabs.",
    "c": "Orchestral: a brass lead with bells on its long notes, harp arpeggios and strings, the chip only as sparkle in the reprise.",
}

if __name__ == "__main__":
    out_dir = sys.argv[1]
    takes = sys.argv[2:] or ["d", "e", "f", "g"]
    os.makedirs(out_dir, exist_ok=True)
    manifest = []
    for take in takes:
        info = g.master(take, out_dir, arrange_fn=arrange, buses=BUSES, trims=TRIMS, name="title", beat=BEAT,
                        intros={"build": build_arrange})
        info["note"] = NOTES[take]
        manifest.append(info)
        print(json.dumps(info))
    json.dump(manifest, open(os.path.join(out_dir, "manifest.json"), "w"), indent=1)
