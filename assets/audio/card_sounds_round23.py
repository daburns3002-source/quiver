"""Second takes for the three card sounds the owner sent back (round 23).

    python -I card_sounds_round23.py <out_dir>

The owner, 2026-11-03, having heard round 22: "thornfall, guard break, and
bull rush need new ones. the rest can stay." Seven of the ten are settled
(Blood Pact A, Ghost Quiver A, Headhunter C, Prismatic Burst B, Time
Dilation A, Vengeful Spirit A, Windrunner C) and these three are open —
Thornfall was left unpicked altogether.

**Four takes each, and different in kind rather than nudged.** Round 22's
three were all one idea apiece: Thornfall was wood and earth three ways,
Guard Break was a metal break three ways, Bull Rush was a rising rush three
ways. Shading those again would most likely be sent back again, so each
take below starts somewhere else — what the sound is *of*, not how bright
it is.
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
METAL = ((1, 1.0), (2.41, 0.6), (3.93, 0.35), (5.4, 0.2))
WOOD = ((1, 1.0), (1.9, 0.3), (3.1, 0.12))


# --- Thornfall: round 22 was wood going into earth. These are the arrows ---
def thorn_volley():
    """Four bowstrings loosing at once: the arrows firing, not the planting."""
    out = np.zeros(int(SR * 0.5))
    for i, delay in enumerate((0.0, 0.025, 0.055, 0.08)):
        twang = s.pluck(260 + i * 40, 0.18, brightness=0.55)
        air = s.whoosh(0.2, 1200, 2800, q=1.9, attack=0.004, decay=8) * 0.5
        piece = s.mix((twang, 0.8), (air, 0.6))
        d = int(SR * delay)
        out[d:d + len(piece)] += piece[:len(out) - d] * (1.0 - i * 0.12)
    return s.room(out, 0.09, 0.18)


def thorn_blades():
    """Metal, not wood: three blades snapping out of the ground."""
    out = np.zeros(int(SR * 0.45))
    for i, delay in enumerate((0.0, 0.05, 0.095)):
        shunk = s.bandpass(s.noise(0.07), 900, 5200) * s.env_ad(int(SR * 0.07), 0.001, 20)
        ring = s.tone(1240 + i * 180, 0.22, 11, METAL) * 0.35
        piece = s.mix((shunk, 1.0), (ring, 0.5))
        d = int(SR * delay)
        out[d:d + len(piece)] += piece[:len(out) - d]
    return s.room(out, 0.08, 0.2)


def thorn_gore():
    """It comes out of a body: a wet burst, then shafts whistling off."""
    burst = s.lowpass(s.noise(0.13), 700) * s.env_ad(int(SR * 0.13), 0.004, 10)
    squelch = s.chirp(0.16, 420, 180, shape="exp", wave="sine") * s.env_ad(int(SR * 0.16), 0.01, 8)
    whistle = s.at(s.sparkle(0.38, [1800, 2200, 1500], spacing=0.04, decay=13), 0.09) * 0.5
    return s.room(s.mix((burst, 0.95), (squelch, 0.6), (whistle, 0.6)), 0.1, 0.2)


def thorn_toy():
    """Arcade and bright, like the rest of the game: a pop and a zip-fan."""
    pop = s.lowpass(s.noise(0.05), 1800) * s.env_ad(int(SR * 0.05), 0.001, 18)
    boing = s.chirp(0.18, 300, 900, shape="exp", wave="sine") * s.env_ad(int(SR * 0.18), 0.004, 9)
    fan = s.at(s.sparkle(0.32, [1046, 1318, 1568, 2093], spacing=0.03, decay=15), 0.05) * 0.7
    return s.room(s.mix((pop, 0.9), (boing, 0.5), (fan, 0.8)), 0.08, 0.18)


# --- Guard Break: round 22 was a metal break. These are the push ---
def guard_crunch():
    """Stone and timber giving way, with a whip-crack on top."""
    crunch = s.lowpass(s.noise(0.22), 600) * s.env_ad(int(SR * 0.22), 0.003, 7)
    body = s.tone(120, 0.3, 6, WOOD) * 0.7
    whip = s.bandpass(s.noise(0.05), 2600, 8000) * s.env_ad(int(SR * 0.05), 0.0006, 26)
    return s.room(s.mix((crunch, 0.95), (body, 0.6), (whip, 0.7)), 0.1, 0.2)


def guard_whump():
    """Air shoved out of the way: a bass drop you feel more than hear."""
    drop = s.chirp(0.4, 180, 42, shape="exp", wave="sine") * s.env_ad(int(SR * 0.4), 0.008, 3.5)
    air = s.sweep_filter(s.noise(0.32), 1400, 300, q=1.3) * s.env_ad(int(SR * 0.32), 0.006, 5)
    return s.room(s.mix((drop, 1.0), (air, 0.65)), 0.12, 0.2)


def guard_shatter():
    """The guard as something brittle: it breaks rather than bends."""
    crack = s.bandpass(s.noise(0.06), 1600, 9000) * s.env_ad(int(SR * 0.06), 0.0006, 28)
    shards = s.at(s.sparkle(0.34, [2400, 1900, 3000, 1600], spacing=0.022, decay=18), 0.02) * 0.6
    low = s.lowpass(s.noise(0.18), 260) * s.env_ad(int(SR * 0.18), 0.004, 8) * 0.7
    return s.room(s.mix((crack, 1.0), (shards, 0.7), (low, 0.8)), 0.1, 0.22)


def guard_knock():
    """One flat arcade "CHNK" and debris scattering: short, no ring at all."""
    chnk = s.bandpass(s.noise(0.055), 400, 3600) * s.env_ad(int(SR * 0.055), 0.0008, 24)
    thud = s.tone(96, 0.16, 9, ((1, 1.0), (2, 0.35))) * 0.8
    debris = s.at(s.sparkle(0.3, [700, 520, 880, 620], spacing=0.035, decay=16), 0.05) * 0.45
    return s.room(s.mix((chnk, 1.0), (thud, 0.75), (debris, 0.5)), 0.07, 0.16)


# --- Bull Rush: round 22 was a rising rush. These are the animal and the burst ---
def rush_snort():
    """A bull: a short snort, then he is gone."""
    snort = s.sweep_filter(s.noise(0.16), 220, 900, q=1.8) * s.env_ad(int(SR * 0.16), 0.01, 9)
    growl = s.tone(78, 0.22, 7, ((1, 1.0), (2, 0.45), (3, 0.2))) * 0.8
    off = s.at(s.whoosh(0.3, 600, 2000, q=1.4, attack=0.01, decay=5), 0.14) * 0.7
    return s.room(s.mix((snort, 0.9), (growl, 0.8), (off, 0.7)), 0.1, 0.2)


def rush_burst():
    """All of the speed at the front: a launch, then a wind tail."""
    launch = s.lowpass(s.noise(0.09), 900) * s.env_ad(int(SR * 0.09), 0.001, 16)
    kick = s.chirp(0.12, 90, 220, shape="exp", wave="sine") * s.env_ad(int(SR * 0.12), 0.002, 10)
    tail = s.at(s.sweep_filter(s.noise(0.36), 2200, 500, q=1.5), 0.06) * 0.6
    return s.room(s.mix((launch, 1.0), (kick, 0.7), (tail, 0.7)), 0.1, 0.2)


def rush_snap():
    """Snappy and arcade: one drum hit and a fast whoosh away."""
    hit = s.bandpass(s.noise(0.07), 300, 3000) * s.env_ad(int(SR * 0.07), 0.0008, 22)
    tom = s.tone(140, 0.14, 10, ((1, 1.0), (1.6, 0.3))) * 0.7
    away = s.at(s.whoosh(0.24, 900, 2600, q=1.7, attack=0.006, decay=7), 0.04) * 0.75
    return s.room(s.mix((hit, 0.95), (tom, 0.7), (away, 0.8)), 0.08, 0.16)


def rush_armour():
    """The armour, not the man: plate rattling and scraping as he tears off."""
    rattle = np.zeros(int(SR * 0.4))
    rng = np.random.default_rng(23)
    for _ in range(7):
        tick = s.bandpass(s.noise(0.04), 1200, 6000) * s.env_ad(int(SR * 0.04), 0.0008, 24)
        d = int(SR * float(rng.uniform(0, 0.24)))
        rattle[d:d + len(tick)] += tick[:len(rattle) - d] * float(rng.uniform(0.4, 0.9))
    scrape = s.sweep_filter(s.noise(0.34), 700, 2400, q=2.2) * s.env_ad(int(SR * 0.34), 0.02, 5)
    low = s.lowpass(s.noise(0.3), 280) * 0.5
    return s.room(s.mix((rattle, 0.8), (scrape, 0.8), (low, 0.6)), 0.11, 0.22)


DESIGNED = {
    "fx_thornfall": [
        (thorn_volley, "Four bowstrings loosing at once: the arrows, not the planting."),
        (thorn_blades, "Metal instead of wood: three blades snapping out of the ground."),
        (thorn_gore, "It comes out of a body — a wet burst, then shafts whistling off."),
        (thorn_toy, "Arcade and bright like the rest of the game: a pop and a zip-fan."),
    ],
    "fx_guard_break": [
        (guard_crunch, "Stone and timber giving way, with a whip-crack on top."),
        (guard_whump, "Air shoved out of the way: a bass drop you feel more than hear."),
        (guard_shatter, "The guard as something brittle: it breaks rather than bends."),
        (guard_knock, "One flat arcade CHNK and debris scattering. No ring at all."),
    ],
    "fx_bull_rush": [
        (rush_snort, "A bull: a short snort, then he is gone."),
        (rush_burst, "All the speed at the front — a launch, then a wind tail."),
        (rush_snap, "Snappy and arcade: one drum hit and a fast whoosh away."),
        (rush_armour, "The armour, not the man: plate rattling and scraping."),
    ],
}


def main():
    out = sys.argv[1]
    os.makedirs(out, exist_ok=True)
    manifest = {}
    for name, takes in DESIGNED.items():
        manifest[name] = []
        for letter, (fn, note) in zip("abcd", takes):
            base = os.path.join(out, f"{name}_{letter}")
            x = s.finish(fn())
            x = x * (0.89 / max(np.abs(x).max(), 1e-9))
            wavfile.write(base + ".wav", SR, (np.clip(x, -1, 1) * 32767).astype(np.int16))
            subprocess.run(
                [FF, "-y", "-loglevel", "error", "-i", base + ".wav",
                 "-b:a", "160k", base + ".mp3"],
                check=True,
            )
            manifest[name].append({
                "variant": letter,
                "file": os.path.basename(base) + ".wav",
                "note": note,
                "ms": round(len(x) / SR * 1000),
            })
        print(name, len(manifest[name]))
    json.dump(manifest, open(os.path.join(out, "manifest.json"), "w"), indent=1)


if __name__ == "__main__":
    main()
