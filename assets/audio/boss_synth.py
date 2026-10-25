"""Round 18: the two bosses' attacks and Thornwood's enemies (owner,
2026-10-25: "i need sound auditions, 2 big ones for each attack in the 2
boss fights currently being brood mother and king bloblin. the rest of the
enemies in area 2 also need sounds. keep it in the sound style i have now").

    python -I boss_synth.py <out_dir>

Two takes for each sound, built with synth.py's tools in the game's style
(bright, punchy, cartoony): the bosses' are big, with low end and a room
behind them; the Thornwood enemies' are shorter, in each creature's voice.
Written as WAV and MP3 at the same peak, with a manifest for build_page.py.
"""
import json
import os
import subprocess
import sys

import numpy as np
from scipy.io import wavfile

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import pet_synth as p  # noqa: E402
import synth as s  # noqa: E402

SR = s.SR
FF = os.environ.get("FFMPEG", "ffmpeg")

voice, burst, thump, swish, then, crackle, snap = p.voice, p.burst, p.thump, p.swish, p.then, p.crackle, p.snap


# ---------- big building blocks ----------

def big(x, size=0.25, mix=0.25, cutoff=None):
    """A boss sound: a bigger room, and a gentle top roll-off."""
    if cutoff:
        x = s.lowpass(x, cutoff)
    return s.room(x, size=size, mix=mix)


def boom(seconds=0.7, f0=120, f1=42, decay=5):
    """A deep body drop: a falling sine under a dull thud."""
    return s.mix((voice(seconds, f0, f1, decay=decay), 1.0), (burst(0.12, hi=900, decay=7), 0.6))


def splat(seconds=0.45, hi=1600, f0=420, f1=110):
    """A slime landing: a wet noise slap and a falling jelly blop."""
    wet = burst(seconds, hi=hi, decay=7) * (1 + 0.5 * np.sin(2 * np.pi * 28 * s.t_of(seconds)))
    return s.mix((wet, 0.8), (voice(seconds, f0, f1, wave="tri", decay=6), 0.6))


def wobble(seconds, f0, f1, rate=9.0, depth=0.25, wave="tri", attack=0.02, decay=3.0):
    """A jelly wobble: a gliding voice with a slow pitch wobble."""
    return voice(seconds, f0, f1, wave=wave, vibrato=depth, rate=rate, attack=attack, decay=decay)


def rumble(seconds=0.8, hi=220, attack=0.05, decay=3.0):
    return burst(seconds, hi=hi, decay=decay, attack=attack)


def silk(seconds=0.3, f0=1800, f1=6500, attack=0.005, decay=3.5):
    """Silk shooting out: a thin, rising, airy zip."""
    x = s.sweep_filter(s.noise(seconds), f0, f1, q=4.0) * s.env_ad(int(SR * seconds), attack, decay)
    return s.mix((x, 1.0), (voice(seconds, f0 * 0.6, f1 * 0.4, wave="tri", decay=decay) * 0.25, 1.0))


def skitter(count=10, spacing=0.035, f=2600, jitter=0.012, seed=3):
    """Many little legs: dry clicks, unevenly spaced."""
    r = np.random.default_rng(seed)
    parts = []
    for i in range(count):
        t = i * spacing + r.uniform(0, jitter)
        click = s.bandpass(s.noise(0.02), f * 0.7, f * 1.3) * s.env_ad(int(SR * 0.02), 0.001, 12)
        parts.append((s.at(click, t), r.uniform(0.6, 1.0)))
    return s.mix(*parts)


def snort(seconds=0.25, lo=250, hi=1300, rate=22):
    """A pig's snort: a gritty, fluttering noise burst."""
    x = s.bandpass(s.noise(seconds), lo, hi) * s.env_ad(int(SR * seconds), 0.01, 4)
    return x * (0.6 + 0.4 * np.sign(np.sin(2 * np.pi * rate * s.t_of(seconds))))


def squeal(seconds=0.25, f0=900, f1=1500, rate=14):
    return voice(seconds, f0, f1, wave="square", vibrato=0.06, rate=rate, attack=0.02, decay=4) * 0.5


def hooves(count=6, spacing=0.08, f=180):
    return s.mix(*[(s.at(thump(0.07, f * (1 + 0.08 * (i % 2))), i * spacing), 0.8) for i in range(count)])


def creak(seconds=0.5, f=90):
    """Wood or bramble straining: a slow, grainy pluck bending down."""
    return s.mix((s.pluck(f, seconds, brightness=0.2, bend=0.3), 0.8), (crackle(seconds, 0.97), 0.3))


# sound key: (title, what it is for, rhythm or None, [(make, note), (make, note)])
SOUNDS = {
    # ---------------- King Bloblin, the Slime King ----------------
    "boss_king_bounce_windup": [
        (lambda: big(s.mix((wobble(0.7, 140, 90, rate=7, depth=0.18), 0.8), (rumble(0.7, attack=0.25, decay=1.5), 0.5))), "he squashes down: a deep jelly wobble that tightens"),
        (lambda: big(s.mix((wobble(0.6, 110, 200, rate=11, depth=0.12, attack=0.2), 0.7), (s.at(burst(0.15, hi=2000, decay=6), 0.45), 0.3))), "a rising, straining squelch, ready to spring"),
    ],
    "boss_king_bounce_launch": [
        (lambda: big(s.mix((voice(0.35, 120, 520, wave="tri", decay=3), 0.8), (swish(0.4, 300, 2200), 0.6), (burst(0.06, hi=1500, decay=10), 0.5))), "a big boing up and a rush of air"),
        (lambda: big(s.mix((s.at(swish(0.5, 200, 1800), 0.02), 0.7), (wobble(0.4, 180, 700, rate=14, depth=0.1), 0.6))), "a wet sproing, then the whoosh of the leap"),
    ],
    "boss_king_bounce_slam": [
        (lambda: big(s.mix((boom(0.9, 130, 38, decay=4), 1.0), (s.at(splat(0.6, 1400, 320, 90), 0.01), 0.8), (s.at(rumble(0.9, decay=2.5), 0.03), 0.5)), size=0.35, mix=0.3), "a ground-shaking slime slam with a rumble"),
        (lambda: big(s.mix((boom(0.8, 160, 45), 1.0), (s.at(burst(0.5, lo=300, hi=3000, decay=5), 0.0), 0.5), (s.at(s.arp([196, 147], 0.08, 0.6, s.WARM, decay=5), 0.05), 0.35)), size=0.35, mix=0.3), "a heavy splash-down with a shockwave thud"),
    ],
    "boss_king_lash": [
        (lambda: big(s.mix((swish(0.35, 400, 3200), 0.8), (s.at(splat(0.3, 2000, 600, 180), 0.25), 0.7))), "the arm whips out and slaps the ground"),
        (lambda: big(s.mix((voice(0.3, 250, 900, wave="tri", decay=4), 0.5), (swish(0.3, 600, 4000), 0.7), (s.at(thump(0.18, 120), 0.27), 0.8))), "a stretchy whip and a hard smack"),
    ],
    "boss_king_grab": [
        (lambda: big(s.mix((wobble(0.6, 500, 160, rate=12, depth=0.15), 0.7), (burst(0.6, hi=1200, decay=3, attack=0.03), 0.4))), "a sticky stretch as he drags you in"),
        (lambda: big(s.mix((voice(0.55, 700, 180, wave="tri", decay=3), 0.6), (s.at(splat(0.3, 1500, 300, 150), 0.0), 0.5))), "a gloopy grab and a long slurp back"),
    ],
    "boss_king_chest_bump": [
        (lambda: big(s.mix((boom(0.5, 200, 70, decay=6), 1.0), (s.at(voice(0.3, 300, 600, wave="tri", decay=6), 0.04), 0.5))), "a big belly bounce, BOING"),
        (lambda: big(s.mix((thump(0.3, 90, decay=6), 1.0), (s.at(wobble(0.45, 260, 140, rate=10, depth=0.2), 0.03), 0.6))), "a heavy bump that jiggles"),
    ],
    "boss_king_goo": [
        (lambda: big(s.mix(*[(s.at(splat(0.25, 1800, 500 + 80 * i, 160), i * 0.07), 0.6) for i in range(4)])), "goo spatters down in a few blobs"),
        (lambda: big(s.mix((burst(0.4, hi=1400, decay=5), 0.7), (s.at(voice(0.3, 380, 120, wave="tri", decay=5), 0.05), 0.6))), "a thick goo splash that settles"),
    ],
    # ---------------- The Broodmother ----------------
    "boss_brood_web_windup": [
        (lambda: big(s.mix((creak(0.9, 70), 0.7), (silk(0.8, 900, 3000, attack=0.2, decay=2), 0.5), (s.at(skitter(8, 0.05), 0.2), 0.4))), "she rears up and the web unfolds, creaking"),
        (lambda: big(s.mix((voice(0.9, 90, 140, wave="tri", attack=0.3, decay=2), 0.6), (s.at(silk(0.6, 1500, 5000), 0.3), 0.5), (rumble(0.9, attack=0.3, decay=2), 0.4))), "a low hiss rising as the web spreads"),
    ],
    "boss_brood_web_spin": [
        (lambda: big(s.mix(*[(s.at(swish(0.3, 500, 1800), i * 0.25), 0.5) for i in range(8)], (rumble(2.0, attack=0.1, decay=0.8), 0.3))), "the web whirls: steady sweeping whooshes"),
        (lambda: big(s.mix((s.sweep_filter(s.noise(2.0), 400, 1600, q=2.0) * (0.6 + 0.4 * np.sin(2 * np.pi * 4 * s.t_of(2.0))) * s.env_ad(int(SR * 2.0), 0.1, 0.8), 0.7), (skitter(30, 0.06, 2200), 0.3))), "a pulsing, whirring spin with skittering legs"),
    ],
    "boss_brood_web_break": [
        (lambda: big(s.mix(*[(s.at(snap(), i * 0.05), 0.6) for i in range(5)], (s.at(thump(0.3, 80, decay=6), 0.25), 0.7))), "strands snap one after another, then she slumps"),
        (lambda: big(s.mix((burst(0.15, lo=2000, decay=7), 0.6), (s.at(voice(0.5, 400, 90, wave="tri", decay=4), 0.05), 0.6), (s.at(boom(0.4, 110, 50), 0.3), 0.5))), "a sharp tear, a falling groan, a thud"),
    ],
    "boss_brood_web_shot": [
        (lambda: big(s.mix((silk(0.35, 1500, 7000), 0.8), (s.at(splat(0.25, 2500, 700, 300), 0.3), 0.5))), "a silk zip down the lane and a sticky splat"),
        (lambda: big(s.mix((voice(0.12, 600, 250, wave="tri", decay=8), 0.5), (s.at(silk(0.3, 2000, 6000), 0.05), 0.8), (s.at(snap(), 0.33), 0.5))), "a spit, a zing of web, a snap as it lands"),
    ],
    "boss_brood_web_pull": [
        (lambda: big(s.mix((silk(0.5, 5000, 1200, attack=0.01, decay=2.5), 0.7), (creak(0.5, 120), 0.5))), "the strand goes taut and reels you in"),
        (lambda: big(s.mix((voice(0.5, 900, 300, wave="tri", vibrato=0.05, rate=30, decay=3), 0.5), (s.sweep_filter(s.noise(0.5), 4000, 900, q=3) * s.env_ad(int(SR * 0.5), 0.01, 3), 0.6))), "a twanging, stretching pull"),
    ],
    "boss_brood_summon": [
        (lambda: big(s.mix((voice(0.6, 150, 90, wave="tri", vibrato=0.1, rate=8, attack=0.05, decay=3), 0.6), (s.at(skitter(18, 0.03, 2800), 0.35), 0.6), (s.at(s.mix(*[(s.at(thump(0.08, 260), i * 0.09), 0.6) for i in range(3)]), 0.5), 0.6))), "a low call, then a clutch of spiderlings drops and scatters"),
        (lambda: big(s.mix((s.arp([294, 233, 196], 0.12, 0.5, s.WARM, decay=6), 0.4), (s.at(s.mix(*[(s.at(splat(0.15, 2200, 600, 300), i * 0.1), 0.5) for i in range(3)]), 0.3), 0.6), (s.at(skitter(14, 0.035), 0.55), 0.5))), "an eerie three-note call, three eggs pop, legs skitter off"),
    ],
    # ---------------- Thornwood's enemies ----------------
    "enemy_boar_charge": [
        (lambda: p.soft(s.mix((snort(0.25), 0.7), (s.at(hooves(6, 0.07), 0.2), 0.7)), 4000), "a snort and a burst of hooves"),
        (lambda: p.soft(s.mix((squeal(0.2, 700, 1100), 0.5), (s.at(swish(0.35, 300, 1500), 0.1), 0.6), (s.at(hooves(5, 0.06, 200), 0.12), 0.6)), 4000), "a squeal and a thundering rush"),
    ],
    "enemy_boar_gore": [
        (lambda: p.soft(s.mix((snort(0.12), 0.5), (s.at(thump(0.15, 150), 0.06), 0.9), (s.at(crackle(0.15, 0.95), 0.06), 0.4)), 4000), "a grunt and a thorny tusk hit"),
        (lambda: p.soft(s.mix((swish(0.12, 600, 2500), 0.5), (s.at(thump(0.14, 170), 0.09), 0.9)), 4000), "a quick swipe and thump"),
    ],
    "enemy_thistle_spit": [
        (lambda: p.soft(s.mix(*[(s.at(s.mix((voice(0.06, 700, 300, wave="tri", decay=8), 0.6), (burst(0.03, lo=2500, decay=9), 0.5)), i * 0.06), 0.8) for i in range(3)]), 5000), "three burrs spat out: ptoo ptoo ptoo"),
        (lambda: p.soft(s.mix((voice(0.1, 300, 900, wave="tri", decay=6), 0.5), (s.at(s.mix(*[(s.at(swish(0.08, 1500, 4000), i * 0.04), 0.5) for i in range(3)]), 0.07), 0.8)), 5000), "a puff and a spray of burrs"),
    ],
    "enemy_sow_attack": [
        (lambda: p.soft(s.mix((snort(0.3, 150, 900, 18), 0.7), (s.at(thump(0.2, 100, decay=8), 0.15), 1.0)), 3000), "a deep grunt and a heavy bash"),
        (lambda: p.soft(s.mix((voice(0.3, 160, 110, wave="square", vibrato=0.1, rate=20, decay=4) * 0.4, 0.8), (s.at(thump(0.22, 90, decay=7), 0.18), 1.0)), 3000), "a rumbling oink-snort, then a slam"),
    ],
    "enemy_sow_drop": [
        (lambda: p.soft(s.mix((burst(0.2, hi=1800, decay=6), 0.6), (s.at(s.mix(*[(s.at(squeal(0.12, 1100 + 150 * i, 1500 + 150 * i), i * 0.09), 0.5) for i in range(3)]), 0.1), 0.8)), 5000), "the brambles burst and three boarlets squeal out"),
        (lambda: p.soft(s.mix(*[(s.at(s.mix((voice(0.08, 400, 900, wave="tri", decay=7), 0.6), (thump(0.06, 260), 0.5)), i * 0.1), 0.8) for i in range(3)]), 5000), "pop pop pop, three boarlets tumble out"),
    ],
    "enemy_boarlet_bite": [
        (lambda: p.soft(s.mix((squeal(0.1, 1300, 1700), 0.5), (s.at(snap(), 0.06), 0.8)), 5000), "a tiny squeal and a nip"),
        (lambda: p.soft(s.mix((snort(0.08, 500, 2000, 30), 0.5), (s.at(snap(), 0.04), 0.8)), 5000), "a little snort and a snap"),
    ],
    "enemy_lurker_dive": [
        (lambda: p.soft(s.mix((burst(0.4, hi=900, decay=4, attack=0.01), 0.8), (voice(0.35, 300, 80, wave="tri", decay=4), 0.5)), 3000), "it sinks into the soil with a gritty whump"),
        (lambda: p.soft(s.mix((crackle(0.4, 0.93), 0.5), (rumble(0.45, 400, 0.02, 3), 0.8)), 3000), "a rustling burrow down"),
    ],
    "enemy_lurker_emerge": [
        (lambda: p.soft(s.mix((rumble(0.3, 500, 0.05, 4), 0.6), (s.at(s.mix((burst(0.2, hi=2500, decay=6), 0.7), (voice(0.25, 120, 400, wave="tri", decay=5), 0.5)), 0.2), 0.9)), 4000), "a rumble, then it bursts up out of the dirt"),
        (lambda: p.soft(s.mix((creak(0.35, 110), 0.5), (s.at(thump(0.15, 140), 0.25), 0.8), (s.at(crackle(0.2, 0.94), 0.25), 0.5)), 4000), "roots creak and crack as it surfaces"),
    ],
    "enemy_lurker_spray": [
        (lambda: p.soft(s.mix(*[(s.at(swish(0.1, 1200, 4500), i * 0.025), 0.4) for i in range(5)]), 6000), "a fan of thorns flung out"),
        (lambda: p.soft(s.mix((burst(0.1, lo=1500, decay=7), 0.5), (s.at(s.mix(*[(s.at(swish(0.08, 2000, 5000), i * 0.03), 0.4) for i in range(5)]), 0.03), 0.8)), 6000), "a hiss and a spray of thorns"),
    ],
    "enemy_thornling_bite": [
        (lambda: p.soft(s.mix((skitter(5, 0.025, 3000), 0.5), (s.at(snap(), 0.12), 0.8)), 6000), "a scuttle and a tiny fang snap"),
        (lambda: p.soft(s.mix((voice(0.06, 1800, 2400, wave="tri", decay=8), 0.4), (s.at(snap(), 0.03), 0.8)), 6000), "a squeak and a bite"),
    ],
    "enemy_thornling_hatch": [
        (lambda: p.soft(s.mix((s.at(snap(), 0.0), 0.5), (s.at(voice(0.1, 500, 1000, wave="tri", decay=7), 0.04), 0.5), (s.at(skitter(6, 0.03, 2800), 0.12), 0.5)), 5000), "an egg cracks and it skitters off"),
        (lambda: p.soft(s.mix((thump(0.1, 220), 0.6), (s.at(skitter(8, 0.025, 3200), 0.06), 0.6)), 5000), "a soft drop and scurrying legs"),
    ],
}


def main():
    out = sys.argv[1]
    os.makedirs(out, exist_ok=True)
    manifest = {}
    for name, takes in SOUNDS.items():
        manifest[name] = []
        for letter, (fn, note) in zip("ab", takes):
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
