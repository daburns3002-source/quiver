"""The night title theme: the intro cutscene's music for the title screen
"The World Tree at night" (owner, 2026-11-12: "the title music also needs to
be changed to match the darker tone of the picture", then "i want it to be
the pokemon synths still to match the game but a dark souls/elden ring like
tone to match the atmosphere"). The tone only: slow, minor, solemn and grand.
Every tune here is original; nothing is taken from any game's music.

    python -I title_night.py <out_dir> [take ...]      (takes: a b c d; all by default)

The game's own chip voices carry it (`glade_theme.py`): the pulse lead, the
triangle bass and thin-pulse arpeggios, over a string pad with bells and a
soft taiko. No drum kit, no brass fanfare.

Writes <out_dir>/night_<take>.wav, .ogg and .mp3 (the loop alone) and
night_<take>_build.* (what ships): a 5.0 s build on the black screen, the
theme's first bar landing on exactly 5.0 s (the cutscene's cut,
`Config/Intro.revealAt`), then the theme in a loop region
(`Sound.LoopRegion`) while the title waits. Plus manifest.json. Takes render
in order: each draws on one seeded generator, so rendering one alone would
change it.

48 BPM, so one bar is the build's 5.0 s; twelve bars (60 s) loop, which keeps
`Config/Music.intro`'s loop region where the old theme had it (11.0 to 71.0 s).

The build: a low drone swelling from silence, a glint of bells as the words
pop in (0.6 s), a slow heartbeat, a thin arpeggio climbing on the dominant,
a breath of silence, then the arrival: a deep soft boom, a low bell and the
first chord opening. No riser, no snare roll, no crash.

  a  "Lanterns"   D minor. The pulse lead sings long notes over a slow chip
                  arpeggio; bells answer the held notes. The calmest.
  b  "Old Tree"   G minor. A hymn: the lead doubled an octave down, soft low
                  brass under it from the second phrase, a taiko heartbeat and
                  rolls. The grandest.
  c  "Night Soar" The title tune the game has had (Soar), at half speed over
                  minor chords, lead and bells together like a music box.
  d  "Moonrise"   A minor that lifts to the major in each phrase; the lead
                  high and sparse, the bass walking. The most hopeful.
"""
import json
import os
import sys

import numpy as np

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import boss_theme as bt  # noqa: E402
import glade_theme as g  # noqa: E402
import title_theme as tt  # noqa: E402

SR = g.SR
BPM = 48
BEAT = 60 / BPM
BAR = 4 * BEAT
HIT = 5.0  # the cutscene's cut to the title: the theme's first downbeat
assert abs(BAR - HIT) < 1e-9

# take: chords (a bar each; the last is the dominant, which the build climbs on) and the lead
TUNES = {
    "a": ("Dm | Bb | F | C | Dm | Bb | Gm | A | Bb | F/A | Gm | A",
          "A5:2 D6:1 E6:1 | F6:3 D6:1 | C6:2 A5:1 F5:1 | G5:3 E5:1 | "
          "A5:2 D6:1 E6:1 | F6:2 G6:1 F6:1 | D6:3 Bb5:1 | A5:1 C#6:1 E6:2 | "
          "D6:2 F6:1 Bb6:1 | A6:3 F6:1 | G6:1 F6:1 D6:1 Bb5:1 | A5:3 r:1"),
    "b": ("Gm | Eb | Bb | F | Gm | Eb | Cm | D | Eb | Bb/D | Cm | D",
          "G5:2 Bb5:1 D6:1 | Eb6:3 D6:1 | D6:2 F6:2 | C6:3 A5:1 | "
          "G5:1 Bb5:1 D6:1 G6:1 | G6:2 Bb6:2 | G6:2 Eb6:1 C6:1 | D6:3 r:1 | "
          "Bb6:2 G6:2 | F6:3 D6:1 | Eb6:2 D6:1 C6:1 | D6:2 A5:2"),
    "c": ("Gm | Eb | Cm | F | Bb/D | Eb | Cm | D | Eb | Bb/D | Cm | D",
          "F5:1 D6:2 C6:.5 Bb5:.5 | Bb5:1 G5:2 D5:1 | Eb5:1 C6:2 Bb5:.5 G5:.5 | A5:3 F5:1 | "
          "F5:1 F6:2 Eb6:.5 D6:.5 | Eb6:1.5 D6:.5 C6:1 Bb5:1 | C6:1 Eb6:1 G6:1 F6:.5 Eb6:.5 | D6:3 r:1 | "
          "G5:1 Eb6:2 D6:1 | D6:1 Bb5:2 F5:1 | Eb5:1 C6:2 Bb5:1 | A5:3 r:1"),
    "d": ("Am | F | C | G | Am | F | Dm | E | F | C/E | Dm | E",
          "E5:1 A5:1 C6:2 | A5:3 C6:1 | E6:2 G6:1 E6:1 | D6:3 B5:1 | "
          "C6:1 E6:1 A6:2 | A6:1 G6:1 F6:1 A6:1 | F6:2 D6:1 A5:1 | B5:3 r:1 | "
          "C6:2 F6:1 A6:1 | G6:3 E6:1 | F6:1 E6:1 D6:1 A5:1 | G#5:2 B5:2"),
}


def chords_of(take):
    return [g.parse_chord(c.strip()) for c in TUNES[take][0].split("|")]


def arrange(take):
    chords = chords_of(take)
    mix = g.Mix(len(chords) * BAR)
    add = mix.add
    for b, (root, ivs, bass) in enumerate(chords):
        t0 = b * BAR
        phrase = b // 4  # three phrases of four bars, each a little fuller
        bm = 34 + (bass - 34) % 12  # Bb1..A2
        # bass: the triangle, held; it walks (root, fifth) in take d
        if take == "d":
            for k, step in enumerate((0, 7)):
                add("bass", t0 + 2 * k * BEAT, g.triangle(g.hz(bm + step), 1.95 * BEAT, 1.0), jitter=0)
        else:
            add("bass", t0, g.triangle(g.hz(bm), 3.9 * BEAT, 1.0), jitter=0)
        # pad: held strings, wider each phrase
        level = (0.7, 0.85, 1.0)[phrase]
        for j, m in enumerate(g.pad_voicing(ivs, root)):
            add("pad", t0, g.strings(g.hz(m), 4 * BEAT, level), pan=(-0.45, 0.45)[j % 2], jitter=0)
            add("pad", t0, g.strings(g.hz(m - 12), 4 * BEAT, 0.5 * level), pan=(0.3, -0.3)[j % 2], jitter=0)
        # arpeggio: a thin pulse, slow, up the chord and back
        tones = g.ladder(root, ivs, 62)[:5]
        tones = tones + tones[-2:0:-1]
        if take == "c":
            steps, each = 4, BEAT  # quarters, like a music box's comb
        elif take == "b" and phrase == 0:
            steps, each = 0, BEAT  # the hymn starts bare
        else:
            steps, each = 8, 0.5 * BEAT
        for k in range(steps):
            v = 0.5 if k % 4 == 0 else 0.36
            add("chip", t0 + k * each, g.pulse(g.hz(tones[k % len(tones)]), each, v, duty=0.125, gate=0.55),
                pan=0.35, jitter=0)
        # the heartbeat: a soft taiko
        if take == "b":
            add("taiko", t0, g.taiko(0.9), jitter=0)
            add("taiko", t0 + 2 * BEAT, g.taiko(0.5), jitter=0)
            if b % 4 == 3:  # a roll into the next phrase
                for k, v in enumerate((0.3, 0.4, 0.55, 0.7)):
                    add("taiko", t0 + (3 + k * 0.25) * BEAT, g.taiko(v), jitter=0.002)
        elif take == "a" or (take == "c" and b % 4 == 0):
            add("taiko", t0, g.taiko(0.7), jitter=0)

    # the tune
    for bi, bar in enumerate(g.parse_melody(TUNES[take][1])):
        beat = 0.0
        for m, beats in bar:
            if m is not None:
                at = (bi * 4 + beat) * BEAT
                dur = beats * BEAT * 0.96
                v = (1.0 if beat % 2 == 0 else 0.9) * g.rng.uniform(0.94, 1.0)
                duty = 0.25 if take in ("b", "c") else 0.5
                add("chiplead", at, g.pulse(g.hz(m), dur, v, duty=duty, gate=0.92), jitter=0)
                if take == "b":
                    # the hymn: the lead an octave down too, and low brass from the second phrase
                    add("chiplow", at, g.pulse(g.hz(m - 12), dur, 0.8 * v, duty=0.5, gate=0.92), pan=-0.2, jitter=0)
                    if bi >= 4:
                        add("brass", at, bt.brass(g.hz(m - 24), dur, 0.7 * v), pan=0.15, jitter=0.004)
                if take == "c":
                    add("bells", at, g.bell(g.hz(m + 12), 0.8 * v), pan=0.25)
                elif beats >= 2:
                    # a bell answers a held note, a beat in
                    add("bells", at + BEAT, g.bell(g.hz(m + 12), 0.7 * v), pan=0.25)
            beat += beats
    return mix


GAP = 0.08  # the breath of silence before the arrival


def build_arrange(take):
    chords = chords_of(take)
    first, dominant = chords[0], chords[-1]
    mix = g.Mix(HIT)
    add = mix.add
    cut = HIT - GAP
    tonic = 34 + (first[0] - 34) % 12
    # the drone: the tonic and its fifth, low, swelling from nothing
    for m, pan in ((tonic, 0.0), (tonic + 7, -0.3), (tonic + 12, 0.3)):
        add("drone", 0.15, tt.swell(g.hz(m), cut - 0.15, power=2.0), pan=pan, jitter=0)
    # the strings open on the dominant for the last half
    root, ivs, _ = dominant
    for j, m in enumerate(g.pad_voicing(ivs, root)):
        x = g.strings(g.hz(m), cut - 2.5, 0.7)
        add("pad", 2.5, x * np.linspace(0.3, 1, len(x)), pan=(-0.45, 0.45)[j % 2], jitter=0)
    # the glint as DYL.DEVS PRESENTS pops in: the tonic chord, high
    top = 74 + (first[0] - 74) % 12
    for iv, dt in ((0, 0.0), (first[1][2], 0.09), (first[1][1] + 12, 0.18)):
        add("glint", 0.6 + dt, g.bell(g.hz(top + iv), 0.7), pan=0.25)
    # the heartbeat: three slow beats, each a little surer
    for k, v in ((1, 0.35), (2, 0.5), (3, 0.7)):
        add("taiko", k * BEAT, g.taiko(v), jitter=0)
    # a thin arpeggio climbing on the dominant over the last half
    tones = g.ladder(root, ivs, 57)[:7]
    step = 0.25 * BEAT
    count = int((cut - 2.5 - 0.05) / step)
    for k in range(count):
        u = k / max(count - 1, 1)
        m = tones[min(int(u * len(tones)), len(tones) - 1)]
        add("chip", 2.5 + k * step, g.pulse(g.hz(m), step, 0.25 + 0.45 * u, duty=0.125, gate=0.6), pan=0.35, jitter=0)
    # the arrival, into the theme's first bar: deep and soft, no crash
    add("boom", HIT, tt.boom(0.75), jitter=0)
    add("taiko", HIT, g.taiko(0.8), jitter=0)
    add("glint", HIT, g.bell(g.hz(top - 12), 0.9), pan=-0.2)
    # the breath: nothing but reverb in the last moment before it
    gap = int(round(cut * SR)), int(round(HIT * SR))
    for x in mix.buses.values():
        fade = int(0.01 * SR)
        x[gap[0] - fade:gap[0]] *= np.linspace(1, 0, fade)[:, None]
        x[gap[0]:gap[1]] = 0
    return mix


# bus: (level dB RMS while playing, reverb send, echo)
BUSES = {
    "chiplead": (-20.5, 0.3, True),
    "chiplow": (-25, 0.28, False),
    "brass": (-26, 0.4, False),
    "bass": (-21, 0.05, False),
    "pad": (-23, 0.45, False),
    "chip": (-29, 0.3, True),
    "bells": (-27, 0.5, True),
    "taiko": (-26, 0.35, False),
    # the build's own
    "drone": (-27, 0.35, False),
    "glint": (-30, 0.5, True),
    "boom": (-22, 0.15, False),
}

NAMES = {"a": "Lanterns", "b": "Old Tree", "c": "Night Soar", "d": "Moonrise"}
NOTES = {
    "a": "Lanterns: D minor. The pulse lead sings long notes over a slow chip arpeggio, bells answering each held note, a soft drum once a bar. The calmest of the four.",
    "b": "Old Tree: G minor, a slow hymn. It starts bare (lead and bass), then the chip arpeggio and soft low brass join; a drum heartbeat with a roll into each phrase. The grandest.",
    "c": "Night Soar: the title tune the game has now (Soar), at half speed over minor chords, the lead and bells playing together like a music box. Keeps the game's own theme.",
    "d": "Moonrise: A minor that lifts to the major in every phrase. The lead is high and sparse, the bass walks, no drum at all. The most hopeful.",
}

if __name__ == "__main__":
    out_dir = sys.argv[1]
    takes = sys.argv[2:] or ["a", "b", "c", "d"]
    os.makedirs(out_dir, exist_ok=True)
    manifest = []
    for take in takes:
        info = g.master(take, out_dir, arrange_fn=arrange, buses=BUSES, trims={}, name="night", beat=0.5 * BEAT,
                        intros={"build": build_arrange})
        info["name"] = NAMES[take]
        info["note"] = NOTES[take]
        info["intros"]["build"]["note"] = NOTES[take]
        manifest.append(info)
        print(json.dumps(info))
    json.dump(manifest, open(os.path.join(out_dir, "manifest.json"), "w"), indent=1)
