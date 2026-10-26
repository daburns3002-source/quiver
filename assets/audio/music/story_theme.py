"""The story cutscene's music (owner, 2026-10-25: "it needs some music", then
"this music should be more calm"), scored to the cutscene's own frames: the
cue times are read from `Config/Story`, so the music lands on its beats.
Original, made from scratch with the Mossy Glade theme's voices
(`glade_theme.py`), in the title theme's key (B flat); the heroes' part quotes
the title theme "Soar" (`title_theme.py`). Gentle throughout and mastered
quieter than the other themes (TARGET_LUFS).

    python -I story_theme.py <out_dir>

Writes <out_dir>/story.wav, .ogg and .mp3 (what ships: one upload holding the
music and King Bloblin's yawn, `assets/audio/final/story_king_yawn.mp3`, laid
in on its frame) and story_manifest.json.

  calm     Sky to Chest: harp, soft strings, a flute, bells for the fireflies;
           thinning to the strings alone under the yawn (Lounge, Yawn).
  sneaky   Bushes to Unroll: soft plucked bass tiptoeing in G minor, a harp run
           as the soldier dashes in and a drop as he skids, strings rising as the
           poster unrolls.
  unease   Eyes to Breath: quiet held strings in G minor over a slow low pluck,
           climbing gently as he rises.
  roar     Roar, Shockwave: one deep, soft swell of strings and a low drum.
  heroes   Pan to Away: "Soar" on the flute over strings and harp, settling on
           B flat as the screen goes black.
"""
import json
import os
import re
import subprocess
import sys

import numpy as np
from scipy import signal
from scipy.io import wavfile

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import glade_theme as g  # noqa: E402

SR = g.SR
HERE = os.path.dirname(os.path.abspath(__file__))
REPO = os.path.abspath(os.path.join(HERE, "..", "..", ".."))
YAWN = os.path.join(REPO, "assets", "audio", "final", "story_king_yawn.mp3")
YAWN_GAIN = 0.5
# calmer than the other themes (owner, 2026-10-25: "this music should be more calm")
TARGET_LUFS = -19.0


def cue_times():
    """When each shot starts, when the frames end, and when the black has held
    (seconds), from `Config/Story`."""
    src = open(os.path.join(REPO, "src", "shared", "Config", "Story.luau"), encoding="utf-8").read()
    lead = float(re.search(r"\blead = ([\d.]+)", src).group(1))
    hold = float(re.search(r"\bblackHold = ([\d.]+)", src).group(1))
    block = src[src.index("shots = {"):]
    starts, at = {}, lead
    for chunk in block.split('name = "')[1:]:
        starts[chunk[: chunk.index('"')]] = at
        at += sum(float(h) for h in re.findall(r"hold = ([\d.]+)", chunk))
    return starts, at, at + hold


class Mix:
    def __init__(self, seconds):
        self.n = int(SR * seconds)
        self.buses = {}

    def add(self, bus, t, x, pan=0.0):
        if bus not in self.buses:
            self.buses[bus] = np.zeros((self.n, 2))
        i = int(SR * t)
        if i >= self.n:
            return
        x = x[: self.n - i]
        left, right = np.cos((pan + 1) * np.pi / 4), np.sin((pan + 1) * np.pi / 4)
        self.buses[bus][i : i + len(x), 0] += x * left
        self.buses[bus][i : i + len(x), 1] += x * right


def m(name):
    return g.midi(name)


def f(name):
    return g.hz(g.midi(name))


def chord_notes(names, low=3):
    return [f(n) for n in names]


def arrange(starts, ends, total):
    mix = Mix(total + 2.5)
    s = starts

    # ---- calm: Sky to Chest (harp and pad in B flat), strings alone under the yawn
    calm_end = s["Lounge"]
    beat = 0.75
    progression = [("Bb2", ["Bb3", "D4", "F4"]), ("Eb3", ["Eb4", "G4", "Bb4"]), ("G2", ["G3", "Bb3", "D4"]), ("F2", ["F3", "A3", "C4"])]
    t, k = 0.3, 0
    while t < calm_end:
        bass, triad = progression[k % 4]
        length = min(4 * beat, calm_end - t + 0.6)
        for note in triad:
            mix.add("pad", t, g.strings(f(note), length, 0.18), pan=0.0)
        mix.add("bass", t, g.pizz(f(bass), 1.4, 0.5))
        arp = [triad[0], triad[1], triad[2], triad[1]] * 2
        for j, note in enumerate(arp):
            tt = t + j * beat / 2
            if tt < calm_end:
                mix.add("harp", tt, g.harp(m(note) + 12, 0.35), pan=-0.3)
        t += 4 * beat
        k += 1
    for tt, note in ((s["Glade"], "F5"), (s["Glade"] + 0.75, "D6"), (s["Glade"] + 2.25, "C6"), (s["Chest"], "Bb5"), (s["Chest"] + 0.75, "D6"), (s["Chest"] + 1.5, "F6")):
        mix.add("lead", tt, g.flute(f(note), 0.7 if note != "F6" else 1.2, 0.45), pan=0.15)
    for tt in np.arange(1.0, calm_end, 1.6):
        mix.add("bells", tt + g.rng.uniform(0, 0.4), g.bell(f(g.rng.choice(["F6", "Bb6", "D7"])), 0.12), pan=g.rng.uniform(-0.6, 0.6))
    # the chest glints
    for j, note in enumerate(["Bb6", "D7", "F7", "Bb7"]):
        mix.add("bells", s["Chest"] + 0.1 + j * 0.12, g.bell(f(note), 0.25), pan=0.3)
    # under the yawn: a soft held chord only
    sneaky = s["Bushes"]
    for note in ("Bb2", "F3", "D4"):
        mix.add("pad", calm_end, g.strings(f(note), sneaky - calm_end, 0.12))

    # ---- sneaky: Bushes to Unroll (G minor tiptoe)
    tense = s["Eyes"]
    step = 0.32
    walk = ["G2", "r", "D3", "r", "Bb2", "r", "D3", "A2", "G2", "r", "D3", "r", "Eb3", "r", "D3", "r"]
    t, j = sneaky, 0
    while t < tense - 0.05:
        note = walk[j % len(walk)]
        if note != "r":
            mix.add("bass", t, g.pizz(f(note), 0.3, 0.35))
        t += step
        j += 1
    # the soldier dashes in: a soft run up on the harp; a little drop as he skids
    for i, note in enumerate(["G4", "A4", "Bb4", "C5", "D5", "Eb5", "F#5", "G5"]):
        mix.add("harp", s["Run"] + i * 0.12, g.harp(m(note), 0.3), pan=-0.2)
    for i, note in enumerate(["G5", "D5", "Bb4"]):
        mix.add("harp", s["Skid"] + i * 0.08, g.harp(m(note), 0.25), pan=0.2)
    # soft strings rise as the poster unrolls
    for i, note in enumerate(["G3", "A3", "Bb3", "C4"]):
        t0 = s["Take"] + i * (tense - s["Take"]) / 4
        dur = (tense - s["Take"]) / 4 + 0.4
        mix.add("pad", t0, g.strings(f(note), dur, 0.12 + 0.02 * i), pan=0.2)

    # ---- unease: Eyes to Breath, quiet held strings in G minor, a slow low pulse
    breath = s["Breath"]
    roar = s["Roar"]
    for note in ("G2", "D3", "Bb3"):
        x = g.strings(f(note), roar - tense, 0.16)
        x *= np.linspace(0.6, 1.0, len(x))
        mix.add("pad", tense, x)
    mix.add("bells", s["Eyes"] + 0.8, g.bell(f("D6"), 0.15), pan=0.0)
    t = tense
    while t < breath - 0.1:
        mix.add("bass", t, g.pizz(f("G2"), 0.8, 0.35))
        t += 1.2
    # he rises: the strings climb gently
    for i, note in enumerate(["G3", "A3", "Bb3", "C4", "D4"]):
        dur = (breath - s["Rise"]) / 5
        mix.add("pad", s["Rise"] + i * dur, g.strings(f(note), dur + 0.3, 0.12), pan=-0.2)

    # ---- roar: one deep, soft swell (no boom), held through the shockwave
    heroes = s["Pan"]
    for note in ("G1", "G2", "D3", "G3", "Bb3"):
        mix.add("pad", roar, g.strings(f(note), heroes - roar, 0.3))
    mix.add("taiko", roar, g.taiko(0.35))
    mix.add("bass", roar, g.pizz(f("G1"), 1.6, 0.5))
    mix.add("taiko", s["Shockwave"], g.taiko(0.2))

    # ---- heroes: "Soar" (title_theme.py) on the flute over strings and harp
    bar = (ends - heroes) / 3
    beat = bar / 4
    chords = [("Bb2", ["Bb3", "D4", "F4"]), ("G2", ["G3", "Bb3", "D4"]), ("Eb2", ["Eb3", "G3", "Bb3"])]
    soar = [
        [("F5", 1), ("D6", 2), ("C6", 0.5), ("Bb5", 0.5)],
        [("Bb5", 1), ("G5", 2), ("D5", 1)],
        [("Eb5", 1), ("C6", 2), ("Bb5", 0.5), ("A5", 0.5)],
    ]
    for b in range(3):
        t0 = heroes + b * bar
        bass, triad = chords[b]
        for note in triad:
            mix.add("pad", t0, g.strings(f(note), bar, 0.16))
        mix.add("bass", t0, g.pizz(f(bass), bar, 0.45))
        for j in range(8):
            mix.add("harp", t0 + j * beat / 2, g.harp(m(triad[j % 3]) + 12, 0.25), pan=-0.3)
        at = t0
        for note, beats in soar[b]:
            dur = beats * beat
            mix.add("lead", at, g.flute(f(note), dur * 0.95, 0.4), pan=0.1)
            at += dur
    # settle on B flat as the screen goes black
    for note in ("Bb2", "F3", "Bb3", "D4"):
        mix.add("pad", ends, g.strings(f(note), 1.6, 0.16))
    mix.add("harp", ends, g.harp(m("Bb4"), 0.3))
    mix.add("bells", ends, g.bell(f("Bb6"), 0.15))
    return mix


BUSES = {
    # bus: (target RMS dBFS, reverb send)
    "pad": (-26, 0.35),
    "harp": (-30, 0.30),
    "bells": (-34, 0.40),
    "lead": (-24, 0.22),
    "bass": (-26, 0.10),
    "taiko": (-26, 0.18),
}


def yawn(total, at):
    """The yawn, decoded and laid in at `at` seconds."""
    tmp = os.path.join(HERE, "_yawn.wav")
    subprocess.run(["ffmpeg", "-y", "-loglevel", "error", "-i", YAWN, "-ac", "1", "-ar", str(SR), tmp], check=True)
    _, x = wavfile.read(tmp)
    os.remove(tmp)
    return x.astype(np.float64) / 32768


def main():
    out_dir = sys.argv[1]
    os.makedirs(out_dir, exist_ok=True)
    starts, ends, total = cue_times()
    mix = arrange(starts, ends, total)
    n = mix.n
    ir = g.reverb_ir()
    dry = np.zeros((n, 2))
    send = np.zeros((n, 2))
    for bus, x in mix.buses.items():
        target, rev = BUSES[bus]
        # level each bus by its loudest stretch, so quiet sections stay quiet
        x *= 10 ** ((target - g.rms_db(x)) / 20)
        dry += x
        send += rev * x
    wet = np.stack([signal.fftconvolve(send[:, c], ir[:, c])[:n] for c in range(2)], axis=1)
    music = g.tone(dry + 0.55 * wet)
    path = os.path.join(out_dir, "story.wav")
    gain_db = 0.0
    for _ in range(4):
        y = g.limiter(music * 10 ** (gain_db / 20))
        g.write_wav(path, y)
        i, tp = g.lufs(path)
        if abs(i - TARGET_LUFS) < 0.3:
            break
        gain_db += TARGET_LUFS - i
    # the yawn on its frame, over the finished music
    voice = yawn(total, starts["Lounge"]) * YAWN_GAIN
    a = int(SR * starts["Lounge"])
    b = min(n, a + len(voice))
    y[a:b] += voice[: b - a, None]
    y = g.limiter(y)
    g.encode(path, y)
    info = {"seconds": round(n / SR, 2), "lufs": i, "true_peak_db": tp, "yawn_at": starts["Lounge"],
            "cues": {k: round(v, 2) for k, v in starts.items()}, "frames_end": round(ends, 2)}
    json.dump(info, open(os.path.join(out_dir, "story_manifest.json"), "w"), indent=1)
    print(json.dumps(info))


if __name__ == "__main__":
    main()
