"""King Bloblin's battle theme (area 1's boss): an original, driving fight
tune in D minor, chiptune-meets-orchestral like the Mossy Glade theme, made
from scratch with that theme's voices and mixing (`glade_theme.py`).

    python -I boss_theme.py <out_dir> [take ...]      (takes: a b; both by default)

Writes <out_dir>/boss_<take>.wav, .ogg and .mp3, plus manifest.json. Take b,
the owner's pick, also gets boss_b_<intro> for each battle intro (INTROS):
the intro once, then the loop in a loop region (`Sound.LoopRegion`). Takes
render in order a, b: each draws on one seeded generator, so rendering b
alone would change it.
D minor, 152 BPM, 48 bars (75.8 s), seamless the same way as the glade's.

  a  "Chip Battle": the glade B sound turned up: pulse lead over the flute,
     chip arpeggios, a triangle bass ostinato, battle drums.
  b  "Chip + Brass": the same tune with a brass section doubling the lead,
     a string ostinato and orchestral stabs, the chip still on top.

The middle is a bouncy half-time breakdown (bloopy slime bass and bells)
for the king's wobble, then a snare-roll build back into the tune.
"""
import json
import os
import sys

import numpy as np

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import glade_theme as g  # noqa: E402

SR = g.SR
BPM = 152
BEAT = 60 / BPM
BAR = 4 * BEAT
g.QUALITY["dim"] = [0, 3, 6]

SECTIONS = [
    # name, chords, lead, bells
    ("intro", "Dm | Dm | Bb | A", None, None),
    ("A", "Dm | Dm | Bb | C | Dm | Dm | Gm | A",
     "D5:.5 F5:.5 A5:1 G5:.5 F5:.5 E5:.5 F5:.5 | D5:1.5 A4:.5 D5:1 E5:1 | F5:.5 G5:.5 F5:.5 D5:.5 Bb4:1 D5:1 | "
     "C5:1.5 E5:.5 G5:2 | A5:.5 G5:.5 F5:.5 E5:.5 D5:1 F5:1 | A5:1.5 Bb5:.5 A5:1 F5:1 | "
     "G5:.5 A5:.5 Bb5:1 D6:1 Bb5:1 | A5:2 C#5:1 E5:1", None),
    ("A2", "Dm | Dm | Bb | C | F | C | Gm | A",
     "D6:.5 C6:.5 A5:1 F5:.5 G5:.5 A5:1 | D6:1.5 E6:.5 F6:1 E6:1 | D6:1 Bb5:1 F5:1 D6:1 | C6:1.5 Bb5:.5 G5:1 E5:1 | "
     "F5:.5 A5:.5 C6:1 A5:.5 C6:.5 F6:1 | E6:1.5 D6:.5 C6:1 G5:1 | Bb5:.5 A5:.5 G5:.5 A5:.5 Bb5:1 D6:1 | C#6:2 A5:1 E5:1",
     None),
    ("B", "Bb | C | Dm | Dm | Gm | A | Bb | A7",
     "F5:2 D5:1 F5:1 | G5:2 E5:1 C5:1 | A5:3 F5:1 | D6:4 | Bb5:2 G5:1 Bb5:1 | A5:2 E5:1 C#5:1 | "
     "D5:1 F5:1 Bb5:1 D6:1 | C#6:2 E5:1 G5:1", None),
    ("C", "Dm | Dm | Bb | A | Dm | Dm | Gm | A", None,
     "D6:.5 r:.5 A5:.5 r:.5 F5:.5 r:.5 A5:1 | r:4 | D6:.5 r:.5 Bb5:.5 r:.5 F5:.5 r:.5 D5:1 | E5:.5 r:.5 C#6:.5 r:.5 A5:2 | "
     "D6:.5 r:.5 A5:.5 r:.5 F5:.5 r:.5 A5:1 | r:4 | D6:.5 r:.5 Bb5:.5 r:.5 G5:.5 r:.5 D5:1 | E5:.5 G5:.5 Bb5:.5 C#6:.5 E6:2"),
    ("build", "Bb | C | C#dim | A7", "D5:2 F5:2 | E5:2 G5:2 | E5:2 G5:2 | A5:4", None),
    ("A3", "Dm | Dm | Bb | C | F | C | Gm | A7",
     "D6:.5 C6:.5 A5:1 F5:.5 G5:.5 A5:1 | D6:1.5 E6:.5 F6:1 E6:1 | D6:1 Bb5:1 F5:1 D6:1 | C6:1.5 Bb5:.5 G5:1 E5:1 | "
     "F5:.5 A5:.5 C6:1 A5:.5 C6:.5 F6:1 | E6:1.5 D6:.5 C6:1 G5:1 | Bb5:.5 A5:.5 G5:.5 A5:.5 Bb5:1 D6:1 | C#6:2 A5:1 E5:1",
     None),
]

# 16 steps a bar
DRUMS = {
    "intro": {"taiko": "x.....x.....x...", "hat": "x.x.x.x.x.x.x.x."},
    "A": {"kick": "x.....x.x.......", "snare": "....x.......x...", "hat": "x.x.x.x.x.x.x.x."},
    "A2": {"kick": "x.....x.x.......", "snare": "....x.......x...", "hat": "xxx.xxx.xxx.xxx."},
    "B": {"kick": "x.......x.......", "snare": "....x.......x...", "taiko": "x.....x.....x...", "hat": "x.x.x.x.x.x.x.x."},
    "C": {"kick": "x.........x.....", "snare": "........x.......", "hat": "x.x.x.x.x.x.x.x."},
    "build": {"kick": "x...x...x...x...", "snare": "x.x.x.x.x.x.x.x.", "taiko": "x...............", "hat": "x.x.x.x.x.x.x.x."},
    "A3": {"kick": "x.....x.x.......", "snare": "....x.......x...", "hat": "xxx.xxx.xxx.xxx."},
}
FILLS = {
    "intro": {"snare": "............xxxx"},
    "A": {"snare": "....x.......x.xx"},
    "A2": {"snare": "....x.....x.xxxx"},
    "B": {"taiko": "x.....x...x.x.x."},
    "C": {"snare": "........x...x.xx"},
    "build": {"snare": "xxxxxxxxxxxxxxxx", "taiko": "x...x...x...x..."},
    "A3": {"snare": "....x.......xxxx", "taiko": "............x.x."},
}
CRASH = {"A", "A2", "B", "A3"}  # a crash on the section's first beat


# ---------- voices this track adds ----------

def t_of(s):
    return g.t_of(s)


def saws(f, n, cents=(-8, 0, 8)):
    t = np.arange(n) / SR
    x = np.zeros(n)
    for c in cents:
        fm = f * 2 ** (c / 1200) * (1 + 0.0025 * np.sin(2 * np.pi * (5 + c / 30) * t + g.rng.uniform(0, 6)))
        ph = np.cumsum(fm) / SR % 1
        x += 2 * ph - 1 - g.blep(ph, fm / SR)
    return x / len(cents)


def brass(f, dur, vel):
    """Brass section: detuned saws whose brightness swells in and settles."""
    rel = 0.12
    n_on = int(SR * dur)
    n = n_on + int(SR * rel)
    x = saws(f, n)
    dark = g.lowpass(x, min(f * 2.0, 3000), 2)
    bright = g.lowpass(x, min(f * 7, 7000), 2)
    t = np.arange(n) / SR
    swell = np.clip(t / 0.07, 0, 1) * (0.6 + 0.4 * np.exp(-np.maximum(t - 0.07, 0) / 0.2))
    env = g.release_env(n_on, n - n_on, 0.03)
    return vel * (dark + (bright - dark) * swell) * env


def ostinato(f, dur, vel):
    """Staccato low strings for the driving eighths."""
    n_on = int(SR * min(dur, 0.25))
    n = n_on + int(SR * 0.06)
    x = g.lowpass(saws(f, n, (-5, 5)), min(f * 5, 1600), 2)
    return vel * x * g.release_env(n_on, n - n_on, 0.008) * np.exp(-np.arange(n) / SR / 0.18)


def bloop(f, vel):
    """Slime bass: a round sine that drops into pitch and wobbles."""
    t = t_of(0.32)
    fm = f * (1 + 0.6 * np.exp(-t / 0.025)) * (1 + 0.03 * np.sin(2 * np.pi * 9 * t))
    x = np.sin(2 * np.pi * np.cumsum(fm) / SR) + 0.25 * np.sin(4 * np.pi * np.cumsum(fm) / SR)
    env = np.exp(-t / 0.12)
    env[:60] *= np.linspace(0, 1, 60)
    return vel * x * env


def snare(vel):
    t = t_of(0.2)
    body = np.sin(2 * np.pi * 185 * t) * np.exp(-t / 0.04)
    nz = g.bandpass(g.rng.standard_normal(len(t)), 1200, 9000) * np.exp(-t / 0.07)
    x = 0.6 * body + nz / np.abs(nz).max()
    x[:30] *= np.linspace(0, 1, 30)
    return vel * x


def hat(vel):
    t = t_of(0.05)
    x = g.highpass(g.rng.standard_normal(len(t)), 8000) * np.exp(-t / 0.012)
    return vel * x / np.abs(x).max()


def crash(vel):
    t = t_of(1.6)
    x = g.highpass(g.rng.standard_normal(len(t)), 4500) * np.exp(-t / 0.45)
    x[:40] *= np.linspace(0, 1, 40)
    return vel * x / np.abs(x).max()


def kick(vel):
    t = t_of(0.3)
    f = 50 + 110 * np.exp(-t / 0.03)
    return vel * np.sin(2 * np.pi * np.cumsum(f) / SR) * np.exp(-t / 0.1)


DRUM_VOICES = {"kick": kick, "snare": snare, "hat": hat, "taiko": g.taiko}


# ---------- arranging ----------

def arrange(take):
    bars = []
    for name, chords, lead, bells in SECTIONS:
        cells = chords.split("|")
        for i, cell in enumerate(cells):
            parts = cell.split()
            each = 4 / len(parts)
            bars.append((name, i, len(cells), [(g.parse_chord(c), j * each, each) for j, c in enumerate(parts)]))
    mix = g.Mix(len(bars) * BAR)
    add = mix.add

    for b, (sec, i, n_sec, chords) in enumerate(bars):
        t0 = b * BAR
        last = i == n_sec - 1
        half = sec == "C"
        for (root, ivs, bass), beat0, beats in chords:
            start = t0 + beat0 * BEAT
            bm = 38 + (bass - 38) % 12  # D2..C#3
            # bass: driving eighths (root, root, octave...), bouncy bloops in the breakdown
            if half:
                for k, off in enumerate((0, 1.5, 2, 3)):
                    if off < beats:
                        m = bm + (0, 12, 7, 12)[k]
                        add("bass", start + off * BEAT, bloop(g.hz(m), 1.0 if k == 0 else 0.75), jitter=0)
            else:
                steps = [0, 0, 12, 0, 0, 12, 0, 10 if 10 in ivs else 7]
                for k in range(int(beats * 2)):
                    m = bm + steps[k % 8]
                    v = 1.0 if k % 2 == 0 else 0.75
                    add("bass", start + k * 0.5 * BEAT, g.triangle(g.hz(m), 0.45 * BEAT, v), jitter=0)
                    add("bass", start + k * 0.5 * BEAT, g.pizz(g.hz(m), 0.4 * BEAT, 0.6 * v), jitter=0.002)
                    if take == "b":
                        add("ostinato", start + k * 0.5 * BEAT, ostinato(g.hz(m + 12), 0.45 * BEAT, v), pan=-0.25, jitter=0.003)
            # pad: held strings, strongest in the heroic B and the build
            level = {"intro": 0.5, "A": 0.45, "A2": 0.55, "B": 1.0, "C": 0.6, "build": 1.0, "A3": 0.7}[sec]
            for j, m in enumerate(g.pad_voicing(ivs, root)):
                add("pad", start, g.strings(g.hz(m), beats * BEAT, level), pan=(-0.45, 0.45)[j % 2], jitter=0)
            # chip arpeggio: sixteenths through the chord
            if sec in ("intro", "A", "A2", "B", "A3") or (sec == "build" and take == "a"):
                tones = g.ladder(root, ivs, 62)[:4]
                if sec == "intro":
                    tones = tones + tones[::-1]
                for k in range(int(beats * 4)):
                    v = 0.55 if k % 4 == 0 else 0.4
                    add("chip", start + k * 0.25 * BEAT,
                        g.pulse(g.hz(tones[k % len(tones)]), 0.25 * BEAT, v, duty=0.125, gate=0.6), pan=0.35, jitter=0)
            # stabs: dotted-quarter hits on the chord in the intro and the B section (brass take), every take's intro
            if sec == "intro" or (take == "b" and sec in ("B", "build")):
                for off in (0, 1.5, 3):
                    if off < beats:
                        for m in g.pad_voicing(ivs, root):
                            add("stabs", start + off * BEAT, brass(g.hz(m), 0.35 * BEAT, 0.8), pan=0.1, jitter=0.002)
        # drums
        pat = dict(DRUMS[sec])
        if last:
            pat.update(FILLS.get(sec, {}))
        for part, steps in pat.items():
            for k, c in enumerate(steps):
                if c != "x":
                    continue
                if part == "hat":
                    v = 0.8 if k % 4 == 0 else 0.5
                elif part == "snare" and sec == "build":
                    v = 0.35 + 0.65 * (i * 16 + k) / 64  # the roll swells
                else:
                    v = 1.0 if k % 4 == 0 else 0.8
                bus = {"hat": "perc"}.get(part, part)
                pan = {"hat": 0.35}.get(part, 0.0)
                add(bus, t0 + k * 0.25 * BEAT, DRUM_VOICES[part](v * g.rng.uniform(0.88, 1.0)), pan=pan, jitter=0.002)
        if i == 0 and sec in CRASH:
            add("crash", t0, crash(1.0), pan=-0.3, jitter=0)

    # melodies
    t = 0.0
    for name, chords, lead, bells in SECTIONS:
        n_bars = len(chords.split("|"))
        for part, text in (("lead", lead), ("bells", bells)):
            if not text:
                continue
            for bi, bar in enumerate(g.parse_melody(text)):
                beat = 0.0
                for m, beats in bar:
                    if m is not None:
                        at = t + (bi * 4 + beat) * BEAT
                        dur = beats * BEAT * 0.95
                        v = (1.0 if beat % 2 == 0 else 0.88) * g.rng.uniform(0.92, 1.0)
                        if part == "bells":
                            add("bells", at, g.bell(g.hz(m), 0.8 * v), pan=0.25)
                        else:
                            duty = 0.5 if name in ("B", "build") else 0.25
                            add("chiplead", at, g.pulse(g.hz(m), dur, v, duty=duty), jitter=0)
                            add("lead", at, g.flute(g.hz(m - 12), dur, 0.55 * v), pan=-0.15, jitter=0.005)
                            if take == "b":
                                add("brass", at, brass(g.hz(m - 12), dur, v), pan=0.15, jitter=0.004)
                    beat += beats
        t += n_bars * BAR
    return mix


# ---------- the battle intro ----------
# Played once as the boss appears, like a trainer battle's opening: a rush,
# then a charge up on the dominant (A7) that lands on the loop's first bar.
# 3 bars each; chords as SECTIONS, drums as DRUMS (one pattern per bar).
g.PC.update({"G#": 8, "D#": 3, "A#": 10})
INTROS = {
    "dive": {
        "note": "Dive: a chromatic run tumbling down two octaves, three hits on D minor, then a flourish up to a held high A.",
        "chords": "A7 | Dm Bb | A7",
        "lead": "A6:.25 G#6:.25 G6:.25 F#6:.25 F6:.25 E6:.25 D#6:.25 D6:.25 C#6:.25 C6:.25 B5:.25 Bb5:.25 A5:.25 G#5:.25 G5:.25 F#5:.25 | "
                "D5:.75 D5:.75 F5:.5 r:.5 Bb5:.75 A5:.75 | "
                "A4:.25 C#5:.25 E5:.25 G5:.25 A5:.25 C#6:.25 E6:.25 G6:.25 A6:2",
        "stabs": [(1, 0), (1, 1.5), (1, 3), (2, 0)],
        "drums": [
            {"snare": "xxxxxxxxxxxxxxxx", "taiko": "x..............."},
            {"taiko": "x.....x.....x...", "snare": "....x.......x..."},
            {"snare": "xxxxxxxxxxxxxxxx", "taiko": "x.......x.x.x.x."},
        ],
        "rolls": {0, 2},
    },
    "flash": {
        "note": "Flash: high As flickering an octave apart like the screen flashing, arpeggios sweeping down, then the band charging on A.",
        "chords": "A7 | Bb A | A7",
        "lead": "A6:.25 A5:.25 A6:.25 A5:.25 A6:.25 A5:.25 A6:.25 A5:.25 A6:.25 A5:.25 A6:.25 A5:.25 A6:.25 A5:.25 A6:.25 A5:.25 | "
                "D6:.25 Bb5:.25 F5:.25 D5:.25 Bb4:.25 D5:.25 F5:.25 Bb5:.25 C#6:.25 A5:.25 E5:.25 C#5:.25 A4:.25 C#5:.25 E5:.25 A5:.25 | "
                "A5:.5 r:.25 A5:.25 C#6:.5 r:.25 C#6:.25 E6:.5 G6:.5 A6:1",
        "stabs": [(1, 0), (1, 2), (2, 0), (2, 1), (2, 2), (2, 3)],
        "drums": [
            {"hat": "xxxxxxxxxxxxxxxx", "taiko": "x..............."},
            {"kick": "x.......x.......", "snare": "....x.......xxxx"},
            {"kick": "x.x.x.x.x.x.x.x.", "snare": "x.x.x.x.xxxxxxxx"},
        ],
        "rolls": {2},
    },
}


NOTE_NAMES = ["C", "C#", "D", "Eb", "E", "F", "F#", "G", "Ab", "A", "Bb", "B"]


def shifted(spec, semis, bars, note):
    """The intro with the named bars' chords and lead moved by `semis`."""

    def chord(c):
        root = c[:2] if len(c) > 1 and c[1] in "b#" else c[:1]
        return NOTE_NAMES[(g.PC[root] + semis) % 12] + c[len(root):]

    def tune(bar):
        out = []
        for tok in bar.split():
            name, beats = tok.split(":")
            if name != "r":
                m = g.midi(name) + semis
                name = NOTE_NAMES[m % 12] + str(m // 12 - 1)
            out.append(f"{name}:{beats}")
        return " ".join(out)

    cells = spec["chords"].split("|")
    lead = spec["lead"].split("|")
    for b in bars:
        cells[b] = " ".join(chord(c) for c in cells[b].split())
        lead[b] = tune(lead[b])
    return {**spec, "chords": " | ".join(c.strip() for c in cells), "lead": " | ".join(lead), "note": note}


# The owner liked Dive and asked for its run down and climb up in another key
# (2026-10-24): the runs move, the D minor hits between them and the loop stay.
INTROS["dive_bb"] = shifted(INTROS["dive"], 1, (0, 2), "Dive in B flat: both runs a half step up, a tense, sideways lurch into the fight.")
INTROS["dive_g"] = shifted(INTROS["dive"], -2, (0, 2), "Dive in G: both runs a step down, brighter and bolder against the minor hits.")
INTROS["dive_d"] = shifted(INTROS["dive"], -7, (0, 2), "Dive in D major: both runs on the tune's own home note but major, flipping to minor as the fight starts.")
INTROS["dive"]["note"] = "Dive in A, as before: the runs on the fight's dominant, pulling straight into D minor."
# the ones the music page offers this round
INTRO_ROUND = ["dive", "dive_bb", "dive_g", "dive_d"]


def intro_arrange(take, which):
    spec = INTROS[which]
    cells = [c.split() for c in spec["chords"].split("|")]
    mix = g.Mix(len(cells) * BAR)
    add = mix.add
    for b, parts in enumerate(cells):
        t0 = b * BAR
        each = 4 / len(parts)
        for j, c in enumerate(parts):
            root, ivs, bass = g.parse_chord(c)
            start = t0 + j * each * BEAT
            bm = 38 + (bass - 38) % 12
            for k in range(int(each * 2)):  # the bass pumps eighths, octave on the offbeat
                m = bm + (12 if k % 2 else 0)
                add("bass", start + k * 0.5 * BEAT, g.triangle(g.hz(m), 0.45 * BEAT, 1.0 if k % 2 == 0 else 0.8), jitter=0)
                add("bass", start + k * 0.5 * BEAT, g.pizz(g.hz(m), 0.4 * BEAT, 0.6), jitter=0.002)
                if take == "b":
                    add("ostinato", start + k * 0.5 * BEAT, ostinato(g.hz(m + 12), 0.45 * BEAT, 1.0), pan=-0.25, jitter=0.003)
            for v, m in enumerate(g.pad_voicing(ivs, root)):
                add("pad", start, g.strings(g.hz(m), each * BEAT, 0.9), pan=(-0.45, 0.45)[v % 2], jitter=0)
            for bar, off in spec["stabs"]:
                if bar == b and j * each <= off < (j + 1) * each:
                    for m in g.pad_voicing(ivs, root):
                        add("stabs", t0 + off * BEAT, brass(g.hz(m), 0.35 * BEAT, 0.9), pan=0.1, jitter=0.002)
        for part, steps in spec["drums"][b].items():
            for k, c in enumerate(steps):
                if c != "x":
                    continue
                if part == "snare" and b in spec["rolls"]:
                    v = 0.3 + 0.7 * k / 15  # the roll swells into the next bar
                elif part == "hat":
                    v = 0.8 if k % 2 == 0 else 0.55
                else:
                    v = 1.0 if k % 4 == 0 else 0.8
                add({"hat": "perc"}.get(part, part), t0 + k * 0.25 * BEAT, DRUM_VOICES[part](v * g.rng.uniform(0.9, 1.0)),
                    pan={"hat": 0.35}.get(part, 0.0), jitter=0.002)
    add("crash", 0, crash(1.0), pan=-0.3, jitter=0)
    for bi, bar in enumerate(g.parse_melody(spec["lead"])):
        beat = 0.0
        for m, beats in bar:
            if m is not None:
                at = (bi * 4 + beat) * BEAT
                dur = beats * BEAT * 0.95
                v = (1.0 if beat % 1 == 0 else 0.85) * g.rng.uniform(0.92, 1.0)
                add("chiplead", at, g.pulse(g.hz(m), dur, v, duty=0.25), jitter=0)
                add("lead", at, g.flute(g.hz(m - 12), dur, 0.55 * v), pan=-0.15, jitter=0.004)
                if take == "b":
                    add("brass", at, brass(g.hz(m - 12), dur, v), pan=0.15, jitter=0.003)
            beat += beats
    return mix


# bus: (level dB RMS while playing, reverb send, echo)
BUSES = {
    "chiplead": (-19.5, 0.14, True),
    "lead": (-23, 0.2, False),
    "brass": (-22, 0.22, False),
    "bass": (-21, 0.03, False),
    "ostinato": (-26, 0.08, False),
    "pad": (-27, 0.35, False),
    "chip": (-29, 0.15, False),
    "stabs": (-23, 0.25, False),
    "bells": (-24, 0.4, True),
    "kick": (-23, 0.04, False),
    "snare": (-25, 0.16, False),
    "taiko": (-24, 0.18, False),
    "perc": (-31, 0.08, False),
    "crash": (-31, 0.2, False),
}
TRIMS = {"b": {"chiplead": -1.5, "lead": -2, "chip": -2}}

NOTES = {
    "a": "Chip Battle: the glade's take B sound turned up for the fight: pulse lead over the flute, chip arpeggios, a triangle bass driving eighths, battle drums.",
    "b": "Chip + Brass: the same tune with a brass section under the pulse lead, a string ostinato and orchestral stabs, the chip still on top.",
}

if __name__ == "__main__":
    out_dir = sys.argv[1]
    takes = sys.argv[2:] or ["a", "b"]
    os.makedirs(out_dir, exist_ok=True)
    manifest = []
    for take in takes:
        intros = {k: (lambda t, k=k: intro_arrange(t, k)) for k in INTRO_ROUND} if take == "b" else None
        info = g.master(take, out_dir, arrange_fn=arrange, buses=BUSES, trims=TRIMS, name="boss", beat=BEAT, intros=intros)
        for k, v in (info.get("intros") or {}).items():
            v["note"] = INTROS[k]["note"]
        info["note"] = NOTES[take]
        manifest.append(info)
        print(json.dumps(info))
    json.dump(manifest, open(os.path.join(out_dir, "manifest.json"), "w"), indent=1)
