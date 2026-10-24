"""Takes for the card screen's two big moments, made with synth.py's tools.

    python -I reveal_synth.py <out_dir>

Round 15 (owner, 2026-10-24): "sound auditions for the mythic reveal and
for if there is a legendary in the upgrade banner".

- card_mythic plays when a Mythic's reveal starts (`UI/Cards/MythicReveal`),
  one file timed to its beats: the shake builds over the first second
  (`CardTheme.timing.mythicShake`), the card flips by 1.6 s, the flash is
  at 1.35 and "MYTHIC!" lands at 1.65. Every take hits on FLASH.
- card_legendary plays as a hand with a Legendary in it is dealt, when the
  panel turns gold: a short golden flourish.
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

SHAKE = 1.0  # CardTheme.timing.mythicShake
FLASH = 1.35  # MythicReveal.flashAt
TITLE = 1.65  # CardTheme.timing.mythicTitleAt

# A minor chord for the Mythic's red, a major one for the Legendary's gold.
D_MINOR = (293.7, 349.2, 440.0, 587.3)
C_MAJOR = (523.3, 659.3, 784.0, 1046.5)


def ramp(seconds, power=1.5):
    return np.linspace(0, 1, int(SR * seconds)) ** power


def rattle(seconds, rate0=8, rate1=40, f=900):
    """The card shaking: ticks that come faster and louder."""
    n = int(SR * seconds)
    out = np.zeros(n)
    t, i = 0.0, 0
    while t < seconds:
        rate = rate0 + (rate1 - rate0) * (t / seconds)
        tick = s.bandpass(s.noise(0.015), f, f * 3) * s.env_ad(int(SR * 0.015), 0.0005, 9)
        j = int(t * SR)
        out[j : j + len(tick)] += tick[: n - j] * (0.3 + 0.7 * t / seconds)
        t += 1 / rate
        i += 1
    return out


def boom(seconds=1.4, f0=110, f1=36):
    return s.chirp(seconds, f0, f1) * s.env_ad(int(SR * seconds), 0.002, 3.5)


def chord(notes, seconds, partials=s.WARM, decay=2.0, attack=0.01):
    return s.mix(*[(s.tone(f, seconds, decay, partials, attack), 0.5) for f in notes])


def mythic_thunder():
    """A rumble building under the shake, a thunder crack on the flash, a dark chord."""
    rumble = s.lowpass(s.noise(SHAKE + 0.4), 220) * ramp(SHAKE + 0.4, 2)
    crack = s.bandpass(s.noise(0.25), 1200, 8000) * s.env_ad(int(SR * 0.25), 0.0005, 6)
    tail = chord(D_MINOR, 1.6, decay=1.8)
    return s.room(s.mix((rumble, 0.6), (rattle(SHAKE), 0.4), (s.at(crack, FLASH), 0.9),
                        (s.at(boom(), FLASH), 1.0), (s.at(tail, TITLE), 0.5)), 0.2, 0.25)


def mythic_rise():
    """A riser that climbs through the shake and flip, then bursts in a shimmer."""
    rise = s.chirp(FLASH, 120, 900) * ramp(FLASH, 2.2)
    air = s.sweep_filter(s.noise(FLASH), 300, 5000, q=1.5) * ramp(FLASH, 2)
    burst = s.whoosh(0.8, 4000, 600, q=1.0, attack=0.003, decay=4)
    shimmer = s.sparkle(1.4, [1175, 1397, 1760, 2349, 2794], spacing=0.05, decay=4)
    return s.mix((rise, 0.35), (air, 0.5), (s.at(burst, FLASH), 0.8), (s.at(boom(1.0, 90, 40), FLASH), 0.8),
                 (s.at(shimmer, TITLE), 0.5))


def mythic_choir():
    """A dark swell under the shake opening into a held minor chord on the title."""
    n = SHAKE + 0.6
    swell = s.mix(*[(s.chirp(n, f / 2, f, wave="tri") * ramp(n, 2), 0.25) for f in D_MINOR[:3]])
    hit = s.mix((boom(1.2, 100, 40), 1.0), (s.bandpass(s.noise(0.12), 600, 6000) * s.env_ad(int(SR * 0.12), 0.0005, 7), 0.6))
    pad = chord(D_MINOR + (880.0,), 2.0, partials=s.WARM, decay=1.2, attack=0.08)
    bells = s.arp([587.3, 698.5, 880.0, 1174.7], 0.07, 1.2, s.BELL, 4)
    return s.room(s.mix((swell, 0.7), (rattle(SHAKE, 6, 30, 600), 0.3), (s.at(hit, FLASH), 0.9),
                        (s.at(pad, FLASH), 0.45), (s.at(bells, TITLE), 0.45)), 0.25, 0.3)


def mythic_shatter():
    """Glass straining as it shakes, shattering on the flash, a deep gong after."""
    strain = s.sweep_filter(s.noise(SHAKE + 0.35), 1500, 4000, q=9) * ramp(SHAKE + 0.35, 2)
    shards = np.zeros(int(SR * 1.0))
    rng = np.random.default_rng(15)
    for t in rng.uniform(0, 0.7, 30):
        ping = s.tone(rng.uniform(2500, 6000), 0.2, 16, s.GLASS)
        j = int(t * SR)
        shards[j : j + len(ping)] += ping[: len(shards) - j] * rng.uniform(0.2, 0.7) * (1 - t)
    smash = s.highpass(s.noise(0.3), 2000) * s.env_ad(int(SR * 0.3), 0.0005, 5)
    gong = s.tone(146.8, 2.2, 1.6, ((1, 1.0), (2.1, 0.5), (3.4, 0.3), (4.9, 0.15)))
    return s.room(s.mix((strain, 0.4), (rattle(SHAKE), 0.35), (s.at(smash, FLASH), 0.8), (s.at(shards, FLASH), 0.8),
                        (s.at(gong, FLASH + 0.02), 0.7), (s.at(boom(0.8), FLASH), 0.6)), 0.18, 0.25)


def legendary_fanfare():
    """A bright little fanfare: three notes up and the chord held."""
    notes = s.arp([523.3, 659.3, 784.0], 0.09, 0.6, s.WARM, 6)
    held = chord(C_MAJOR, 1.1, decay=2.5)
    return s.room(s.mix((notes, 0.6), (s.at(held, 0.27), 0.6), (s.at(s.sparkle(0.8, [2093, 2637, 3136]), 0.27), 0.3)), 0.12, 0.2)


def legendary_shine():
    """A golden shimmer sweeping up into a bell."""
    sweep = s.sparkle(0.9, [1046.5, 1318.5, 1568, 2093, 2637, 3136], spacing=0.045, decay=6)
    bell = s.tone(1568, 1.2, 3, s.BELL)
    air = s.whoosh(0.4, 1500, 6000, q=1.2, attack=0.02, decay=5)
    return s.room(s.mix((sweep, 0.6), (air, 0.3), (s.at(bell, 0.25), 0.5)), 0.12, 0.25)


def legendary_chime():
    """Coins of light: a quick bright chime chord with a sparkle tail."""
    hit = s.mix(*[(s.tone(f, 1.0, 4, s.BELL), 0.4) for f in C_MAJOR])
    tail = s.sparkle(0.9, [3136, 2637, 3520, 2093, 4186], spacing=0.07, decay=7)
    return s.room(s.mix((hit, 0.7), (s.at(tail, 0.08), 0.35)), 0.1, 0.2)


def legendary_swell():
    """A warm swell into a major chord: grander, slower to arrive."""
    swell = s.mix(*[(s.chirp(0.4, f * 0.75, f, wave="tri") * ramp(0.4, 1.5), 0.3) for f in C_MAJOR[:3]])
    held = chord(C_MAJOR, 1.3, partials=s.WARM, decay=2.0, attack=0.02)
    bell = s.tone(2093, 1.0, 4, s.BELL)
    return s.room(s.mix((swell, 0.6), (s.at(held, 0.38), 0.6), (s.at(bell, 0.38), 0.3)), 0.15, 0.25)


TAKES = {
    "card_mythic": [
        (mythic_thunder, "A rumble under the shake, a thunder crack on the flash, a dark chord on MYTHIC!"),
        (mythic_rise, "A riser through the shake and flip, a burst on the flash, a shimmer on the title"),
        (mythic_choir, "A dark swell, a hit on the flash, a held minor chord and bells on the title"),
        (mythic_shatter, "Glass straining as it shakes, shattering on the flash, a deep gong after"),
    ],
    "card_legendary": [
        (legendary_fanfare, "A little fanfare: three notes up and a bright chord"),
        (legendary_shine, "A golden shimmer sweeping up into a bell"),
        (legendary_chime, "A quick bright chime chord with a sparkle tail"),
        (legendary_swell, "A warm swell into a major chord, grander"),
    ],
}


def main():
    out = sys.argv[1]
    os.makedirs(out, exist_ok=True)
    manifest = {}
    for name, takes in TAKES.items():
        manifest[name] = []
        for letter, (fn, note) in zip("abcd", takes):
            base = os.path.join(out, f"{name}_{letter}")
            x = s.finish(fn())
            x = x * (0.89 / max(np.abs(x).max(), 1e-9))
            wavfile.write(base + ".wav", SR, (np.clip(x, -1, 1) * 32767).astype(np.int16))
            subprocess.run([FF, "-y", "-loglevel", "error", "-i", base + ".wav", "-b:a", "160k", base + ".mp3"], check=True)
            manifest[name].append({"variant": letter, "file": os.path.basename(base) + ".wav", "note": note, "ms": round(len(x) / SR * 1000)})
        print(name, [t["ms"] for t in manifest[name]])
    json.dump(manifest, open(os.path.join(out, "manifest.json"), "w"), indent=1)


if __name__ == "__main__":
    main()
