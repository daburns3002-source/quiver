"""Round 17: a simple attack sound for each pet (owner, 2026-10-24: "i need
sounds for each of the pets in the game, i want to keep them very simple",
then "this is their attack sounds i want").

    python -I pet_synth.py <out_dir>

Three takes per pet, each a short, plain hit in the pet's character, made
with synth.py's tools: a bounce-splat, a tongue lash, a bite, a zap. The
Legendary and Mythic pets carry a small sparkle, in step with their auras.
All under half a second, all at the same peak, written as WAV and MP3 with a
manifest for build_page.py.
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


def voice(seconds, f0, f1, wave="sine", vibrato=0.0, rate=18.0, attack=0.01, decay=5.0):
    """A pitched sound gliding f0 to f1, with an optional wobble."""
    # chirp's exponential glide divides by log(f1 / f0): never a flat zero
    x = s.chirp(seconds, f0, f1 if f1 != f0 else f0 * 1.001, wave=wave)
    if vibrato:
        t = s.t_of(seconds)
        x = x * (1 + vibrato * np.sin(2 * np.pi * rate * t))
    return x * s.env_ad(len(x), attack, decay)


def glimmer(notes, spacing=0.03):
    return s.sparkle(0.35, notes, spacing=spacing, decay=12)


def soft(x, cutoff=3500):
    return s.room(s.lowpass(x, cutoff), size=0.08, mix=0.12)


def burst(seconds, lo=None, hi=None, decay=8.0, attack=0.002):
    """A filtered noise burst: a puff, a snap, a whoomp."""
    x = s.noise(seconds)
    if hi:
        x = s.lowpass(x, hi)
    if lo:
        x = s.highpass(x, lo)
    return x * s.env_ad(len(x), attack, decay)


def thump(seconds=0.12, freq=120, decay=12):
    """A soft body hit: a low sine drop with a short click."""
    return s.mix((voice(seconds, freq * 1.6, freq, decay=decay), 1.0), (burst(0.02, hi=3000, decay=10), 0.5))


def swish(seconds=0.12, f0=800, f1=3000):
    """A quick movement of air: a lunge, a swipe, a swoop."""
    return s.whoosh(seconds, f0, f1, q=1.4, attack=0.01, decay=5)


def zap(seconds=0.14, f0=1800, f1=500):
    """A small magic or electric bolt: a falling buzz."""
    return voice(seconds, f0, f1, wave="square", decay=8) * 0.6


def snap():
    """A bite's snap."""
    return s.mix((burst(0.03, lo=2000, decay=8), 0.7), (s.at(s.tone(800, 0.05, 20), 0.01), 0.4))


def crackle(seconds=0.2, density=0.96):
    x = burst(seconds, lo=2500, decay=8, attack=0.005)
    return x * (np.random.default_rng(5).random(len(x)) > density)


def then(a, b, gap, ga=1.0, gb=1.0):
    return s.mix((a, ga), (s.at(b, gap), gb))


# pet: [(make, note), ...] three takes each, one per pet's designed attack
# (docs/PETS-FOREST.md, Attacks; owner: "this is their attack sounds i want")
PETS = {
    # Slime Glob: lobs a slime blob that leaves a puddle
    "pet_mosslet": [
        (lambda: soft(then(voice(0.08, 300, 700, wave="tri", decay=7), thump(0.12, 140), 0.12, 0.4, 0.9)), "a lob, then a splat"),
        (lambda: soft(s.mix((voice(0.16, 480, 160, wave="tri", decay=7), 0.7), (burst(0.12, hi=1500, decay=8), 0.4))), "a wet glob landing"),
        (lambda: soft(then(s.tone(400, 0.06, 18, s.WARM), voice(0.14, 360, 150, decay=8), 0.1, 0.5, 0.8)), "a pop, then a slow puddle blop"),
    ],
    # Acorn Flick: a quick burst of three small acorn pellets
    "pet_babacorn": [
        (lambda: soft(s.mix(*[(s.at(s.tone(900, 0.05, 20, s.WARM), i * 0.06), 0.7) for i in range(3)]), 5000), "three quick ticks"),
        (lambda: soft(s.mix(*[(s.at(then(swish(0.04, 1500, 4000), s.tone(800, 0.04, 22, s.WARM), 0.02, 0.3, 0.7), i * 0.07), 1.0) for i in range(3)]), 5000), "three flicks"),
        (lambda: soft(s.mix(*[(s.at(s.tone(f, 0.05, 20, s.WARM), i * 0.055), 0.7) for i, f in enumerate((760, 860, 980))]), 5000), "three rising pops"),
    ],
    # Tongue Snap: a short, hard tongue lash that tugs small enemies in
    "pet_fern_frog": [
        (lambda: soft(then(voice(0.08, 300, 1600, wave="tri", decay=6), thump(0.06, 200), 0.07, 0.6, 0.7), 4000), "a thwip and a smack"),
        (lambda: soft(then(voice(0.07, 400, 1800, wave="tri", decay=6), voice(0.12, 1600, 300, wave="tri", decay=6), 0.08, 0.6, 0.6), 4000), "a lash out and a tug back"),
        (lambda: soft(then(burst(0.03, lo=2000, decay=8), voice(0.12, 1400, 350, wave="tri", decay=7), 0.02, 0.6, 0.7), 4000), "a snap that reels in"),
    ],
    # Spore Patch: drops a glowing mushroom ring that heals
    "pet_toadstool_tot": [
        (lambda: s.mix((soft(burst(0.18, hi=2200, decay=6, attack=0.005)), 0.6), (s.at(s.arp([784, 988, 1175], 0.06, 0.4, s.BELL, decay=7), 0.08), 0.4)), "a soft puff, then a healing chime"),
        (lambda: s.mix((soft(thump(0.1, 200)), 0.5), (s.at(glimmer([1047, 1319, 1568]), 0.06), 0.5)), "a plop into green sparkles"),
        (lambda: soft(s.mix((burst(0.25, hi=1800, decay=4, attack=0.03), 0.5), (s.tone(523, 0.35, 5, s.WARM), 0.4))), "a gentle spore bloom"),
    ],
    # Shell Guard: its shell flies in front of you and blocks one hit
    "pet_mossback_snail": [
        (lambda: soft(then(swish(0.1, 400, 1400), s.tone(330, 0.25, 8, ((1, 1.0), (2.4, 0.4), (4.1, 0.15))), 0.09, 0.4, 0.8), 3000), "a whoosh, then a stony clang"),
        (lambda: soft(s.mix((thump(0.14, 110), 0.7), (s.tone(290, 0.3, 7, ((1, 1.0), (2.4, 0.4))), 0.5)), 2500), "a heavy block that rings"),
        (lambda: soft(then(s.tone(250, 0.12, 12, s.WARM), s.tone(370, 0.25, 8, ((1, 1.0), (2.4, 0.35))), 0.07, 0.5, 0.7), 2800), "a clunk and a shield ring"),
    ],
    # Lantern Lure: pulls crystals in, marks an enemy
    "pet_firefly_bun": [
        (lambda: s.mix((voice(0.3, 600, 1400, attack=0.05, decay=4), 0.4), (s.at(glimmer([1568, 2093]), 0.2), 0.5)), "a rising hum, then a glint"),
        (lambda: s.arp([1319, 1760, 2093], 0.07, 0.35, s.GLASS, decay=8), "three bright lantern chimes"),
        (lambda: s.mix((zap(0.1, 2000, 1300), 0.4), (s.at(s.tone(1760, 0.3, 7, s.GLASS), 0.06), 0.5)), "a spark that marks"),
    ],
    # Root Snare: roots burst under an enemy and hold it
    "pet_stumpy": [
        (lambda: soft(s.mix((burst(0.12, hi=1500, decay=6, attack=0.005), 0.6), (s.tone(140, 0.25, 8, s.WARM), 0.6)), 2500), "a rumble and a root burst"),
        (lambda: soft(then(burst(0.06, hi=2500, decay=8), s.pluck(110, 0.3, brightness=0.3), 0.03, 0.6, 0.6), 2500), "a crack and a creaking root"),
        (lambda: soft(s.mix(*[(s.at(s.tone(f, 0.12, 12, s.WARM), i * 0.05), 0.6) for i, f in enumerate((180, 150, 120))]), 2500), "three roots knocking up"),
    ],
    # Leaf Dash: blinks between up to three enemies, slashing each
    "pet_glade_fox": [
        (lambda: soft(s.mix(*[(s.at(swish(0.07, 1200, 4000), i * 0.09), 0.7) for i in range(3)]), 6000), "three quick slashes"),
        (lambda: soft(s.mix(*[(s.at(then(swish(0.05, 1000, 3500), burst(0.03, lo=2500, decay=8), 0.04, 0.5, 0.6), i * 0.1), 1.0) for i in range(3)]), 6000), "dash-slash, three times"),
        (lambda: soft(then(voice(0.06, 900, 1300, wave="tri", decay=9), s.mix(*[(s.at(swish(0.06, 1500, 4500), i * 0.08), 0.7) for i in range(3)]), 0.05, 0.4, 1.0), 6000), "a yip and three slashes"),
    ],
    # Feather Volley: homing feathers fired from above
    "pet_hootmoss": [
        (lambda: soft(s.mix(*[(s.at(swish(0.1, 900, 2600), i * 0.06), 0.5) for i in range(3)]), 5000), "a flutter of three feathers"),
        (lambda: soft(then(swish(0.16, 300, 1000), s.mix(*[(s.at(swish(0.07, 1500, 3500), i * 0.05), 0.5) for i in range(3)]), 0.1, 0.5, 0.8), 5000), "a wing beat, then darts"),
        (lambda: soft(then(voice(0.12, 420, 400, attack=0.02, decay=5), s.mix(*[(s.at(swish(0.08, 1200, 3000), i * 0.06), 0.5) for i in range(3)]), 0.1, 0.4, 0.8), 5000), "a hoot, then a volley"),
    ],
    # Royal Court: summons two mini slimes; a crown shockwave at bosses
    "pet_slime_prince": [
        (lambda: s.mix((s.arp([523, 659, 784], 0.07, 0.35, s.BELL, decay=7), 0.5), (s.at(soft(then(voice(0.1, 300, 600, decay=8), voice(0.1, 340, 680, decay=8), 0.09)), 0.15), 0.6)), "a little fanfare, two slimes pop out"),
        (lambda: s.mix((soft(then(voice(0.1, 280, 560, wave="tri", decay=8), voice(0.1, 320, 640, wave="tri", decay=8), 0.1)), 0.6), (s.at(glimmer([1568, 1976, 2349]), 0.12), 0.4)), "two bloops into gold sparkles"),
        (lambda: s.mix((soft(thump(0.2, 90, decay=7)), 0.7), (s.at(s.arp([784, 988, 1175], 0.05, 0.4, s.BELL, decay=7), 0.03), 0.4)), "a crown shockwave with bells"),
    ],
    # Ember Bite: fire bolts that set enemies burning, and a howl
    "pet_ember_wilf": [
        (lambda: s.mix((soft(burst(0.14, hi=2000, decay=6, attack=0.01)), 0.6), (crackle(0.25), 0.5)), "a fire bolt whoomp, crackling"),
        (lambda: s.mix((soft(then(swish(0.08, 800, 2500), burst(0.12, hi=1800, decay=7), 0.06, 0.5, 0.7)), 0.7), (s.at(crackle(0.2, 0.95), 0.08), 0.5)), "a fiery shot that sizzles"),
        (lambda: s.mix((soft(voice(0.3, 500, 800, attack=0.04, decay=3, vibrato=0.08, rate=6), 3500), 0.5), (s.at(crackle(0.2), 0.1), 0.4)), "a short howl with embers"),
    ],
    # Prism Beam: a sweeping rainbow beam that pierces and heals
    "pet_glimmerhorn": [
        (lambda: s.mix((voice(0.4, 700, 1400, attack=0.04, decay=3) * 0.5, 0.6), (glimmer([1047, 1319, 1568, 2093], 0.04), 0.5)), "a rising beam hum with rainbow sparkles"),
        (lambda: s.mix((zap(0.3, 1600, 2400), 0.3), (s.arp([1047, 1319, 1568, 2093], 0.05, 0.4, s.GLASS, decay=6), 0.5)), "a bright beam over a rising chime"),
        (lambda: s.mix((soft(swish(0.3, 600, 3000), 5000), 0.4), (s.at(s.arp([2093, 1568, 1319, 1047], 0.04, 0.4, s.BELL, decay=7), 0.05), 0.5)), "a sweep with falling bells"),
    ],
}


def main():
    out = sys.argv[1]
    os.makedirs(out, exist_ok=True)
    manifest = {}
    for name, takes in PETS.items():
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
