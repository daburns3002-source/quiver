"""The level theme: the music while you play through an area's rooms
(owner, 2026-10-24: "engaging but not overpowering and still matches the
theme of the other songs"). Original, made from scratch with the Mossy Glade
theme's voices and mastering (`glade_theme.py`) and the boss theme's drums.

    python -I level_theme.py <out_dir> [take ...]
        (takes: hilltop bramble lantern by default; a and b voice the first tune)

Writes <out_dir>/level_<take>.wav, .ogg and .mp3, plus manifest.json.
G major, 120 BPM, 48 bars (96 s), seamless like the others, mastered a
decibel under them so it sits beneath the fight.

It keeps out of the sound effects' way: the tune leaves the last beat of
most bars empty, the middle hands it between the lead and a chip echo, and a
four-bar groove break carries no tune at all.

  a  "Chip Trail": the pulse lead over the flute, as in the glade and boss
     picks, with chip arpeggios and harp.
  b  "Flute Trail": the flute leads with the chip as sparkle above it, an
     ocarina in the minor middle; softer.
"""
import json
import os
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import boss_theme as bt  # noqa: E402
import glade_theme as g  # noqa: E402

SR = g.SR
BPM = 120
BEAT = 60 / BPM
BAR = 4 * BEAT
g.TARGET_LUFS = -17.0

SECTIONS = [
    # name, chords, lead, answer (a chip echo after the lead's call)
    ("intro", "G | Em | C | D", None, None),
    ("A", "G | D/F# | Em | C | G | D | C | D",
     "G5:.5 A5:.5 B5:1 D6:1 r:1 | C6:.5 B5:.5 A5:1 F#5:1 r:1 | E5:.5 F#5:.5 G5:1 B5:1.5 A5:.5 | G5:2 E5:1 r:1 | "
     "D5:.5 G5:.5 B5:1 D6:1 B5:1 | C6:1 A5:.5 F#5:.5 D5:1 r:1 | E5:.5 G5:.5 C6:1 B5:.5 A5:.5 G5:1 | A5:3 r:1", None),
    ("A2", "G | D/F# | Em | C | Am | D | G | G",
     "G5:.5 A5:.5 B5:1 D6:1 r:1 | C6:.5 B5:.5 A5:1 D6:1 r:1 | E6:1 D6:.5 B5:.5 G5:1 B5:1 | C6:2 G5:1 r:1 | "
     "A5:.5 B5:.5 C6:1 E6:1 C6:1 | D6:1.5 C6:.5 A5:1 F#5:1 | G5:3 r:1 | r:2 D5:.5 E5:.5 F#5:1", None),
    ("B", "Em | C | G | D | Em | C | Am | D",
     "G5:2 F#5:1 E5:1 | E5:2 G5:1 C6:1 | B5:3 G5:1 | A5:2 F#5:1 D5:1 | "
     "E5:1 G5:1 B5:2 | C6:1 B5:1 G5:1 E5:1 | A5:2 C6:1 E6:1 | D6:3 r:1", None),
    ("break", "C | D | Em | D", None, None),
    ("C", "C | D | Bm | Em | C | D | G | D7",
     "E5:.5 G5:.5 C6:1 r:2 | F#5:.5 A5:.5 D6:1 r:2 | D5:.5 F#5:.5 B5:1 r:2 | E5:.5 G5:.5 B5:1 r:2 | "
     "E5:.5 G5:.5 C6:1 r:2 | F#5:.5 A5:.5 D6:1 r:2 | G5:.5 B5:.5 D6:1 r:2 | A5:.5 C6:.5 F#6:1 r:2",
     "r:2 E6:.25 D6:.25 C6:.5 G5:1 | r:2 F#6:.25 E6:.25 D6:.5 A5:1 | r:2 F#6:.25 D6:.25 B5:.5 F#5:1 | r:2 G6:.25 F#6:.25 E6:.5 B5:1 | "
     "r:2 E6:.25 D6:.25 C6:.5 G5:1 | r:2 F#6:.25 E6:.25 D6:.5 A5:1 | r:2 B6:.25 A6:.25 G6:.5 D6:1 | r:2 C7:.25 A6:.25 F#6:.5 D6:1"),
    ("A3", "G | D/F# | Em | C | Am | D | G | D",
     "G5:.5 A5:.5 B5:1 D6:1 r:1 | C6:.5 B5:.5 A5:1 D6:1 r:1 | E6:1 D6:.5 B5:.5 G5:1 B5:1 | C6:2 G5:1 r:1 | "
     "A5:.5 B5:.5 C6:1 E6:1 C6:1 | D6:1.5 C6:.5 A5:1 F#5:1 | G5:2 B5:1 D6:1 | C6:1 A5:1 F#5:1 D5:1", None),
]

# 16 steps a bar: a steady, light groove
GROOVE = {"kick": "x.......x.....x.", "snare": "....x.......x...", "shaker": "xxxxxxxxxxxxxxxx"}
DRUMS = {
    "intro": {"kick": "x.......x.......", "shaker": "xxxxxxxxxxxxxxxx"},
    "A": GROOVE,
    "A2": {**GROOVE, "tamb": "..x...x...x...x."},
    "B": {"kick": "x.........x.....", "snare": "........x.......", "shaker": "x.x.x.x.x.x.x.x."},
    "break": {**GROOVE, "tamb": "..x...x...x...x."},
    "C": GROOVE,
    "A3": {**GROOVE, "tamb": "..x...x...x...x."},
}
FILLS = {
    "intro": {"snare": "............x.xx"},
    "A": {"snare": "....x.......x.x."},
    "A2": {"snare": "....x.....x.x.xx"},
    "B": {"snare": "........x...x.xx"},
    "break": {"snare": "....x.......xxxx"},
    "C": {"snare": "....x.......x.xx"},
    "A3": {"snare": "....x.......x.x.", "kick": "x.......x......."},
}
CRASH = {"A", "A2", "C", "A3"}
DRUM_VOICES = {"kick": bt.kick, "snare": bt.snare, "shaker": g.shaker, "tamb": g.tamb, "hat": bt.hat}


# The owner wanted a different melody entirely (2026-10-24), with a couple of
# choices: three new tunes, each its own key, tempo and feel, all on take a's
# chip-over-flute voicing. "trail" (above) stays for reference.
TUNES = {
    "trail": (120, SECTIONS),
    # D major with a mixolydian C: a bouncy, syncopated hook
    "hilltop": (124, [
        ("intro", "D | C | G | A", None, None),
        ("A", "D | C | G | D | Bm | G | Em | A",
         "D5:.75 F#5:.75 A5:.5 r:.5 A5:.5 B5:.5 A5:.5 | G5:.75 E5:.75 C5:.5 r:1 E5:.5 G5:.5 | B5:1 A5:.5 G5:.5 D5:1 r:1 | "
         "F#5:.5 E5:.5 D5:.5 E5:.5 F#5:1 r:1 | D5:.75 F#5:.75 B5:.5 r:.5 B5:.5 C#6:.5 B5:.5 | "
         "D6:.75 B5:.75 G5:.5 r:1 B5:.5 D6:.5 | E6:1 D6:.5 B5:.5 G5:1 E5:1 | A5:2 C#6:1 r:1", None),
        ("A2", "D | C | G | D | G | A | D | D",
         "D5:.75 F#5:.75 A5:.5 r:.5 A5:.5 B5:.5 A5:.5 | G5:.75 E5:.75 C5:.5 r:1 E5:.5 G5:.5 | B5:1 A5:.5 G5:.5 D5:1 r:1 | "
         "F#5:.5 E5:.5 D5:.5 E5:.5 F#5:1 r:1 | B5:.75 D6:.75 G6:.5 r:.5 F#6:.5 E6:.5 D6:.5 | "
         "C#6:.75 E6:.75 A6:.5 r:1 G6:.5 E6:.5 | F#6:1 E6:.5 D6:.5 A5:1 F#5:1 | D6:3 r:1", None),
        ("B", "Bm | G | D | A | Bm | G | Em | A",
         "F#5:2 D5:1 F#5:1 | G5:2 B5:1 D6:1 | A5:3 F#5:1 | E5:2 C#5:1 A4:1 | D5:1 F#5:1 B5:2 | B5:1 A5:1 G5:1 D5:1 | "
         "E5:1 G5:1 B5:1 E6:1 | C#6:3 r:1", None),
        ("break", "G | A | Bm | A", None, None),
        ("A3", "D | C | G | D | G | A | D | A",
         "D5:.75 F#5:.75 A5:.5 r:.5 A5:.5 B5:.5 A5:.5 | G5:.75 E5:.75 C5:.5 r:1 E5:.5 G5:.5 | B5:1 A5:.5 G5:.5 D5:1 r:1 | "
         "F#5:.5 E5:.5 D5:.5 E5:.5 F#5:1 r:1 | B5:.75 D6:.75 G6:.5 r:.5 F#6:.5 E6:.5 D6:.5 | "
         "C#6:.75 E6:.75 A6:.5 r:1 G6:.5 E6:.5 | F#6:1 E6:.5 D6:.5 A5:1 F#5:1 | E5:1 A5:1 C#6:1 E6:1", None),
    ]),
    # A minor, driving: a repeated-note motif, lifting to C major in the middle
    "bramble": (132, [
        ("intro", "Am | Am | F | E", None, None),
        ("A", "Am | G | F | E | Am | G | F | E",
         "A5:.5 A5:.5 C6:.5 A5:.5 E6:1 r:1 | D6:.5 D6:.5 B5:.5 G5:.5 D6:1 r:1 | C6:.5 C6:.5 A5:.5 F5:.5 A5:1 r:1 | "
         "G#5:.5 A5:.5 B5:.5 G#5:.5 E5:1 r:1 | A5:.5 A5:.5 C6:.5 A5:.5 E6:.5 F6:.5 E6:1 | "
         "D6:.5 D6:.5 B5:.5 G5:.5 D6:.5 E6:.5 D6:1 | C6:1 A5:.5 C6:.5 F6:1 E6:.5 D6:.5 | B5:2 G#5:1 r:1", None),
        ("A2", "Am | G | F | E | Dm | E | Am | Am",
         "A5:.5 A5:.5 C6:.5 A5:.5 E6:1 r:1 | D6:.5 D6:.5 B5:.5 G5:.5 D6:1 r:1 | C6:.5 C6:.5 A5:.5 F5:.5 A5:1 r:1 | "
         "G#5:.5 A5:.5 B5:.5 G#5:.5 E5:1 r:1 | F6:.5 F6:.5 D6:.5 A5:.5 D6:1 r:1 | E6:.5 E6:.5 B5:.5 G#5:.5 E6:1 D6:1 | "
         "C6:1 B5:.5 A5:.5 E5:1 C6:1 | A5:3 r:1", None),
        ("B", "C | G | Am | Em | F | C | Dm | E",
         "E5:1 G5:1 C6:2 | B5:1 G5:1 D6:2 | C6:1 A5:1 E5:2 | G5:2 B5:1 r:1 | A5:1 C6:1 F6:2 | E6:1 C6:1 G5:2 | "
         "F5:1 A5:1 D6:1 F6:1 | E6:2 G#5:1 B5:1", None),
        ("break", "F | G | Am | E", None, None),
        ("A3", "Am | G | F | E | Dm | E | Am | E",
         "A5:.5 A5:.5 C6:.5 A5:.5 E6:1 r:1 | D6:.5 D6:.5 B5:.5 G5:.5 D6:1 r:1 | C6:.5 C6:.5 A5:.5 F5:.5 A5:1 r:1 | "
         "G#5:.5 A5:.5 B5:.5 G#5:.5 E5:1 r:1 | F6:.5 F6:.5 D6:.5 A5:.5 D6:1 r:1 | E6:.5 E6:.5 B5:.5 G#5:.5 E6:1 D6:1 | "
         "C6:1 B5:.5 A5:.5 E5:1 C6:1 | B5:1 G#5:1 E5:1 r:1", None),
    ]),
    # C major, lilting dotted rhythms: the gentlest of the three
    "lantern": (112, [
        ("intro", "C | Am | F | G", None, None),
        ("A", "C | Am | F | G | C | Em | F | G",
         "E5:.75 G5:.25 C6:1 B5:.75 C6:.25 G5:1 | A5:.75 C6:.25 E6:1 r:1 D6:.5 C6:.5 | A5:.75 C6:.25 F6:1 E6:.75 D6:.25 C6:1 | "
         "B5:2 r:1 G5:1 | E5:.75 G5:.25 C6:1 D6:.75 E6:.25 G6:1 | G6:.75 E6:.25 B5:1 r:1 C6:.5 B5:.5 | "
         "A5:.75 F5:.25 A5:.5 C6:.5 F6:1 E6:.5 D6:.5 | D6:3 r:1", None),
        ("A2", "C | Am | F | G | Am | F | G | C",
         "E5:.75 G5:.25 C6:1 B5:.75 C6:.25 G5:1 | A5:.75 C6:.25 E6:1 r:1 D6:.5 C6:.5 | A5:.75 C6:.25 F6:1 E6:.75 D6:.25 C6:1 | "
         "B5:2 r:1 G5:1 | C6:.75 E6:.25 A6:1 G6:.75 E6:.25 C6:1 | F6:.75 E6:.25 C6:1 r:1 A5:.5 C6:.5 | "
         "B5:.75 D6:.25 G6:1 F6:.75 D6:.25 B5:1 | C6:3 r:1", None),
        ("B", "F | G7 | Em | Am | Dm | G | C | G7",
         "A5:1.5 C6:.5 F6:2 | G6:1.5 F6:.5 D6:2 | E6:1.5 D6:.5 B5:2 | C6:1.5 B5:.5 A5:2 | F5:1 A5:1 D6:1.5 C6:.5 | "
         "B5:1 D6:1 G6:2 | E6:1.5 D6:.5 C6:1 G5:1 | B5:2 D6:1 F6:1", None),
        ("break", "F | G | Am | G", None, None),
        ("A3", "C | Am | F | G | Am | F | Dm | G",
         "E5:.75 G5:.25 C6:1 B5:.75 C6:.25 G5:1 | A5:.75 C6:.25 E6:1 r:1 D6:.5 C6:.5 | A5:.75 C6:.25 F6:1 E6:.75 D6:.25 C6:1 | "
         "B5:2 r:1 G5:1 | C6:.75 E6:.25 A6:1 G6:.75 E6:.25 C6:1 | F6:.75 E6:.25 C6:1 r:1 A5:.5 C6:.5 | "
         "D6:.75 F6:.25 A6:1 F6:.75 D6:.25 A5:1 | B5:1 D6:1 G6:1 F6:1", None),
    ]),
}
# each tune's own groove where the shared one doesn't suit (its A, A2, A3)
TUNE_GROOVES = {
    "bramble": {**GROOVE, "kick": "x.....x.x.......", "hat": "x.x.x.x.x.x.x.x."},
    "lantern": {"kick": "x.......x.......", "snare": "....x.......x...", "shaker": "x..xx..xx..xx..x"},
}


def melody_notes(text, t):
    for bi, bar in enumerate(g.parse_melody(text)):
        beat = 0.0
        for m, beats in bar:
            if m is not None:
                yield t + (bi * 4 + beat) * BEAT, m, beats * BEAT * 0.94, beat
            beat += beats


def arrange(take):
    """take: "a"/"b" (the trail tune's two voicings) or a tune's name (voiced as a)."""
    global BEAT, BAR
    tune, style = ("trail", take) if take in ("a", "b") else (take, "a")
    bpm, sections = TUNES[tune]
    BEAT = 60 / bpm
    BAR = 4 * BEAT
    drums = dict(DRUMS)
    if tune in TUNE_GROOVES:
        tamb = {"tamb": "..x...x...x...x."}
        drums.update(A=TUNE_GROOVES[tune], A2={**TUNE_GROOVES[tune], **tamb}, A3={**TUNE_GROOVES[tune], **tamb})
    bars = []
    for name, chords, lead, answer in sections:
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
        for (root, ivs, bass), beat0, beats in chords:
            start = t0 + beat0 * BEAT
            # harp: up-and-back eighths, as in the glade
            lad = g.ladder(root, ivs, 55)
            for k in range(int(beats * 2)):
                m = lad[[0, 2, 3, 4, 5, 4, 3, 2][k % 8]]
                v = (0.85 if k % 2 == 0 else 0.65) * g.rng.uniform(0.85, 1.0)
                add("harp", start + k * 0.5 * BEAT, g.harp(m, v), pan=-0.3)
            # bass: a skipping figure (root, root on the and of 2, fifth, octave pickup)
            bm = 40 + (bass - 40) % 12  # E2..D#3
            for off, iv, ln in ((0, 0, 1.25), (1.5, 0, 0.5), (2, 7, 1.25), (3.5, 12, 0.5)):
                if off < beats:
                    m = bm + iv - (12 if iv == 7 and bm + 7 > 52 else 0)
                    v = 0.95 if off == 0 else 0.7
                    add("bass", start + off * BEAT, g.pizz(g.hz(m), ln * BEAT, v), jitter=0.002)
                    if style == "a":
                        add("chipbass", start + off * BEAT, g.triangle(g.hz(m), ln * BEAT * 0.8, 1.0), jitter=0)
            # pad
            level = {"intro": 0.5, "A": 0.45, "A2": 0.55, "B": 0.9, "break": 0.6, "C": 0.6, "A3": 0.6}[sec]
            for j, m in enumerate(g.pad_voicing(ivs, root)):
                add("pad", start, g.strings(g.hz(m), beats * BEAT, level), pan=(-0.45, 0.45)[j % 2], jitter=0)
            # chip arpeggio: the groove's sparkle, busiest in the break
            if sec in ("intro", "A2", "break", "A3") or (style == "a" and sec == "A"):
                tones = g.ladder(root, ivs, 67)[:4]
                for k in range(int(beats * 4)):
                    v = (0.55 if k % 4 == 0 else 0.4) * (1.2 if sec == "break" else 1.0)
                    add("chip", start + k * 0.25 * BEAT, g.pulse(g.hz(tones[k % 4]), 0.25 * BEAT, v, duty=0.125, gate=0.6),
                        pan=0.35, jitter=0)
        pat = dict(drums[sec])
        if last:
            pat.update(FILLS.get(sec, {}))
        for part, steps in pat.items():
            for k, c in enumerate(steps):
                if c != "x":
                    continue
                if part in ("shaker", "hat"):
                    v = {0: 1.0, 2: 0.55, 1: 0.35, 3: 0.4}[k % 4]
                else:
                    v = 1.0 if k % 4 == 0 else 0.8
                bus = {"shaker": "perc", "tamb": "perc", "hat": "perc"}.get(part, part)
                vel = v * g.rng.uniform(0.88, 1.0) * {"tamb": 0.35}.get(part, 1.0)
                add(bus, t0 + k * 0.25 * BEAT, DRUM_VOICES[part](vel), pan={"shaker": 0.4, "tamb": 0.5}.get(part, 0.0), jitter=0.003)
        if i == 0 and sec in CRASH:
            add("crash", t0, bt.crash(0.8), pan=-0.3, jitter=0)

    t = 0.0
    for name, chords, lead, answer in sections:
        n_bars = len(chords.split("|"))
        if lead:
            for at, m, dur, beat in melody_notes(lead, t):
                v = (1.0 if beat % 2 == 0 else 0.88) * g.rng.uniform(0.92, 1.0)
                if style == "a":
                    duty = 0.5 if name == "B" else 0.25
                    add("chiplead", at, g.pulse(g.hz(m), dur, v, duty=duty), jitter=0)
                    add("lead", at, g.flute(g.hz(m - 12), dur, 0.55 * v), pan=-0.15, jitter=0.005)
                else:
                    voice = g.ocarina if name == "B" else g.flute
                    add("lead", at, voice(g.hz(m), dur, v), pan=0.05, jitter=0.005)
                    if name in ("A2", "A3"):  # the chip sparkles an octave over the flute's last verses
                        add("chiplead", at, g.pulse(g.hz(m + 12), dur, 0.45, duty=0.25), pan=0.3, jitter=0)
        if answer:
            for at, m, dur, beat in melody_notes(answer, t):
                add("answer", at, g.pulse(g.hz(m), dur, 0.8, duty=0.125, gate=0.8), pan=0.3, jitter=0)
        t += n_bars * BAR
    return mix


# bus: (level dB RMS while playing, reverb send, echo)
BUSES = {
    "chiplead": (-21, 0.16, True),
    "lead": (-21, 0.26, True),
    "answer": (-24, 0.2, True),
    "harp": (-24, 0.34, False),
    "bass": (-22, 0.04, False),
    "chipbass": (-31, 0.0, False),
    "pad": (-28, 0.38, False),
    "chip": (-30, 0.16, False),
    "kick": (-25, 0.05, False),
    "snare": (-28, 0.16, False),
    "perc": (-32, 0.12, False),
    "crash": (-32, 0.2, False),
}
TRIMS = {"a": {"lead": -2.5}, "b": {"chiplead": -4}, "hilltop": {"lead": -2.5}, "bramble": {"lead": -2.5}, "lantern": {"lead": -2.5}}

NOTES = {
    "a": "Chip Trail: the pulse lead over the flute, as in your glade and boss picks, with chip arpeggios, harp and a skipping bass.",
    "b": "Flute Trail: the flute leads with the chip sparkling above it, an ocarina in the minor middle; the softer of the two.",
    "hilltop": "Hilltop: D major at 124 BPM, a bouncy, syncopated hook that rests on its offbeats, a B minor middle. Sunny and on the move.",
    "bramble": "Bramble Run: A minor at 132 BPM, driving eighths on a repeated-note motif, lifting into C major in the middle. The most urgent.",
    "lantern": "Lantern Path: C major at 112 BPM, a lilting skip of dotted notes, a warm F-to-G middle. The gentlest.",
}

if __name__ == "__main__":
    out_dir = sys.argv[1]
    takes = sys.argv[2:] or ["hilltop", "bramble", "lantern"]
    os.makedirs(out_dir, exist_ok=True)
    manifest = []
    for take in takes:
        bpm = TUNES["trail" if take in ("a", "b") else take][0]
        info = g.master(take, out_dir, arrange_fn=arrange, buses=BUSES, trims=TRIMS, name="level", beat=60 / bpm)
        info["note"] = NOTES[take]
        manifest.append(info)
        print(json.dumps(info))
    json.dump(manifest, open(os.path.join(out_dir, "manifest.json"), "w"), indent=1)
