"""Round 35: an attack sound for every pet and enemy that had none (the
2026-11-26 content sweep found areas 2-4's pets and a dozen enemies silent).

    python -I attack_synth.py <out_dir>

Three takes each, made with synth.py's and pet_synth.py's tools, kept in
round 17's manner (owner, 2026-10-24: "i want to keep them very simple"):
Thornwood's pets woody and thorny, the Drowned Village's wet, Bogheart's
glowing and boggy; the Legendaries and Mythics carry a small sparkle. The
enemies are plainer and a little heavier, the two new bosses' moves bigger.
Each starts on the moment it plays over (`Config/PetSounds` cues, the
enemies' `AttackAt`/`ShotAt`, the bosses' telegraphs); Grandmother Gulp's
spit lands its glob 0.75 s in, as `spit.flight` does. Written as WAV and
MP3 at round 17's peak, with a manifest build_page.py reads (page "35").
"""
import json
import os
import subprocess
import sys

import numpy as np
from scipy.io import wavfile

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import synth as s  # noqa: E402
from pet_synth import burst, crackle, glimmer, snap, soft, swish, then, thump, voice, zap  # noqa: E402

SR = s.SR
FF = os.environ.get("FFMPEG", "ffmpeg")
BIG_BELL = ((1, 1.0), (2.0, 0.6), (2.76, 0.45), (5.4, 0.2), (8.9, 0.08))
SHELL = ((1, 1.0), (2.4, 0.4), (4.1, 0.15))
# Grandmother Gulp's glob lands this long after it leaves (`spit.flight`)
GLOB_LANDS = 0.75


def n_of(seconds):
    return int(SR * seconds)


def norm(x):
    return x / (np.abs(x).max() + 1e-9)


def squelch(seconds=0.18, f0=900, f1=250, q=2.5, decay=6):
    """Wet noise through a gliding band: a squish, a slap of mud."""
    x = norm(s.sweep_filter(s.noise(seconds), f0, f1, q=q))
    return x * s.env_ad(len(x), 0.005, decay)


def blub(seconds, f0, f1, decay=7):
    """A bubbly glide: a sine with a fast wobble."""
    return voice(seconds, f0, f1, vibrato=0.25, rate=35, decay=decay)


def squeak(f=2400, seconds=0.07):
    return voice(seconds, f, f * 1.3, wave="tri", decay=6)


def chirrup(seconds=0.12, f=4200, rate=45):
    """A cricket's trill: a high tone gated on and off."""
    t = s.t_of(seconds)
    x = np.sin(2 * np.pi * f * t) * (0.5 + 0.5 * np.sign(np.sin(2 * np.pi * rate * t)))
    return s.lowpass(x, 7000) * s.env_ad(len(x), 0.005, 3)


def growl(seconds=0.3, f=90, decay=3):
    t = s.t_of(seconds)
    x = s.chirp(seconds, f * 1.2, f, wave="square") * (1 + 0.5 * np.sin(2 * np.pi * 28 * t))
    return s.lowpass(x, 900) * s.env_ad(len(x), 0.03, decay)


def clack(f=1400, decay=30):
    """A hard little knock: shell, claw, slate."""
    return s.mix((burst(0.025, lo=1800, decay=10), 0.6), (s.tone(f, 0.05, decay, ((1, 1.0), (2.7, 0.3))), 0.5))


def skitter(n=6, every=0.035, f=1500, seed=1):
    r = np.random.default_rng(seed)
    return s.mix(*[(s.at(clack(f * (0.8 + 0.4 * r.random())), i * every * (0.8 + 0.4 * r.random())), 0.7) for i in range(n)])


def splash(seconds=0.3, hi=3500, seed=2):
    r = np.random.default_rng(seed)
    body = burst(seconds, lo=300, hi=hi, decay=5, attack=0.004)
    drops = s.mix(*[(s.at(voice(0.04, f, f * 1.8, decay=10), d), 0.25)
                    for f, d in zip(r.uniform(900, 2200, 6), r.uniform(0.02, seconds * 0.8, 6))])
    return s.mix((body, 0.8), (drops, 1.0))


def rumble(seconds=0.25, cutoff=250, decay=4):
    x = s.lowpass(s.noise(seconds), cutoff)
    return norm(x) * s.env_ad(len(x), 0.03, decay)


def big_bell(f=180, seconds=1.4, decay=3):
    return s.tone(f, seconds, decay, BIG_BELL)


def inhale(seconds=2.0, f0=300, f1=2400):
    """Air drawn in, swelling: a band of noise rising, cut off at the end."""
    x = norm(s.sweep_filter(s.noise(seconds), f0, f1, q=1.8))
    e = np.linspace(0.15, 1, len(x)) ** 1.5
    tail = n_of(0.08)
    e[-tail:] *= np.linspace(1, 0, tail)
    return x * e


def creak(seconds=0.6, f0=300, f1=1200):
    x = norm(s.sweep_filter(s.noise(seconds), f0, f1, q=8))
    return x * s.env_ad(len(x), 0.15, 3)


def darts(n, every, f0=1500, f1=4500, gain=0.5):
    return s.mix(*[(s.at(swish(0.07, f0, f1), i * every), gain) for i in range(n)])


# sound: [(make, note), ...] three takes each
SOUNDS = {
    # ---- Thornwood's pets ----
    # Bark Charge: a short, hard ram
    "pet_bark_hoglet": [
        (lambda: soft(then(burst(0.08, lo=300, hi=1500, decay=6), s.mix((thump(0.14, 110), 1.0), (s.tone(220, 0.1, 14, s.WARM), 0.5)), 0.07, 0.4, 0.9)), "a snort, then a woody ram"),
        (lambda: soft(s.mix((swish(0.1, 400, 1500), 0.5), (s.at(thump(0.16, 95), 0.08), 1.0), (s.at(s.tone(300, 0.08, 18, s.WARM), 0.08), 0.5))), "a rush into a hollow bark thud"),
        (lambda: soft(then(voice(0.07, 500, 350, wave="tri", decay=6), s.mix((thump(0.12, 130), 1.0), (crackle(0.12, 0.92), 0.4)), 0.06, 0.4, 1.0)), "an oink and a splintering bump"),
    ],
    # Burr Toss: three burrs off its back
    "pet_burrball": [
        (lambda: soft(s.mix(*[(s.at(then(swish(0.04, 1500, 4000), crackle(0.05, 0.9), 0.02, 0.4, 0.6), i * 0.07), 1.0) for i in range(3)]), 5000), "three prickly flicks"),
        (lambda: soft(s.mix(*[(s.at(s.mix((s.tone(f, 0.05, 22, s.WARM), 0.7), (crackle(0.04, 0.9), 0.3)), i * 0.06), 1.0) for i, f in enumerate((620, 700, 800))]), 5000), "three bristly pops"),
        (lambda: soft(then(skitter(5, 0.02, 2500, 3), darts(3, 0.06), 0.08, 0.4, 1.0), 5000), "a rattle, then three burrs off its back"),
    ],
    # Spore Puff: a cloud that slows
    "pet_budbulb": [
        (lambda: soft(s.mix((burst(0.25, hi=1800, decay=5, attack=0.02), 0.7), (s.tone(392, 0.3, 6, s.WARM), 0.3))), "a soft spore pfff"),
        (lambda: soft(then(voice(0.06, 500, 900, wave="tri", decay=8), burst(0.3, hi=1500, decay=4, attack=0.03), 0.03, 0.5, 0.8)), "a bud pop into a slow cloud"),
        (lambda: soft(then(voice(0.05, 700, 400, decay=8), burst(0.22, hi=2500, decay=5, attack=0.01), 0.04, 0.5, 0.8)), "a little 'pft' of pollen"),
    ],
    # Berry Cache: a patch that feeds whoever stands in it
    "pet_berry_mouse": [
        (lambda: s.mix((squeak(2600), 0.4), (s.at(soft(thump(0.08, 260)), 0.07), 0.6), (s.at(s.arp([659, 784, 988], 0.06, 0.35, s.BELL, decay=7), 0.12), 0.4)), "a squeak, a berry plop, a healing chime"),
        (lambda: s.mix((soft(then(voice(0.08, 300, 650, wave="tri", decay=7), voice(0.1, 420, 200, decay=8), 0.08)), 0.7), (s.at(glimmer([1047, 1319]), 0.15), 0.4)), "a berry dropped with a juicy blop"),
        (lambda: s.mix((squeak(2300, 0.06), 0.35), (s.at(squeak(2700, 0.06), 0.08), 0.35), (s.at(glimmer([1175, 1397, 1760]), 0.14), 0.5)), "two squeaks into sparkles"),
    ],
    # Thorn Shell: blocks a hit, and thorns burst off the shell
    "pet_thistle_mole": [
        (lambda: soft(s.mix((s.tone(300, 0.2, 9, SHELL), 0.6), (s.at(crackle(0.18, 0.88), 0.03), 0.6), (thump(0.1, 150), 0.6))), "a shell block bursting into thorns"),
        (lambda: then(clack(900), soft(darts(4, 0.03, 2000, 5000, 0.4), 6000), 0.03, 0.7, 1.0), "a hard knock and a spray of spines"),
        (lambda: soft(then(thump(0.08, 180), s.mix((burst(0.15, lo=2500, decay=7), 0.5), (crackle(0.2, 0.9), 0.5)), 0.04)), "a thud and a prickly crackle"),
    ],
    # Chain Snare: a hold that jumps to the enemy beside it
    "pet_briar_beetle": [
        (lambda: soft(s.mix((burst(0.06, hi=2500, decay=8), 0.6), (s.at(s.pluck(140, 0.25, brightness=0.3), 0.02), 0.6), (s.at(s.pluck(185, 0.22, brightness=0.3), 0.16), 0.5)), 2800), "a crack, a creak, a second creak as it jumps"),
        (lambda: s.mix((clack(1100), 0.5), (s.at(swish(0.12, 600, 2000), 0.05), 0.4), (s.at(soft(s.tone(150, 0.2, 9, s.WARM)), 0.15), 0.6)), "a shell click, a whip of vine, a tug"),
        (lambda: soft(s.mix(*[(s.at(then(burst(0.04, hi=2200, decay=8), s.tone(f, 0.12, 12, s.WARM), 0.01, 0.6, 0.6), d), 1.0) for f, d in ((170, 0), (210, 0.15))]), 2500), "two roots snapping tight"),
    ],
    # Blood Berry: a bite that feeds its owner
    "pet_berry_bat": [
        (lambda: s.mix((squeak(3000, 0.06), 0.35), (s.at(snap(), 0.04), 0.6), (s.at(blub(0.18, 500, 900), 0.22), 0.4)), "a squeak, a bite, a sip"),
        (lambda: soft(then(swish(0.06, 900, 2500), s.mix((squelch(0.15, 1500, 500), 0.6), (s.at(voice(0.12, 400, 800, decay=6), 0.12), 0.4)), 0.05)), "a swoop, a juicy nip, a slurp"),
        (lambda: s.mix((snap(), 0.6), (s.at(s.arp([784, 1047], 0.07, 0.3, s.BELL, decay=8), 0.2), 0.4)), "a nip and a little drink-up chime"),
    ],
    # Bramble Swipe: one blow across three
    "pet_bramble_bear": [
        (lambda: soft(s.mix((growl(0.25, 85), 0.6), (s.at(swish(0.14, 500, 2200), 0.1), 0.8), (s.at(crackle(0.14, 0.9), 0.16), 0.4))), "a growl into a thorny swipe"),
        (lambda: soft(s.mix((swish(0.18, 350, 1800), 0.8), (s.at(thump(0.14, 100), 0.1), 0.8), (s.at(burst(0.1, lo=2000, decay=7), 0.12), 0.3))), "a heavy paw swipe that lands"),
        (lambda: soft(then(voice(0.12, 200, 150, wave="tri", decay=4), s.mix(*[(s.at(burst(0.04, lo=1500, decay=8), i * 0.04), 0.5) for i in range(3)]), 0.08, 0.6, 1.0)), "a huff and three thorn scratches"),
    ],
    # Thorn Darts: four that follow
    "pet_briar_lynx": [
        (lambda: soft(darts(4, 0.05), 5000), "four quick thorn darts"),
        (lambda: soft(then(burst(0.1, lo=3000, decay=4), darts(4, 0.05, 1800, 4500), 0.06, 0.3, 1.0), 5500), "a hiss, then four darts"),
        (lambda: soft(s.mix(*[(s.at(then(burst(0.02, lo=3000, decay=8), swish(0.06, 2000, 4000), 0.01, 0.4, 0.5), i * 0.06), 1.0) for i in range(4)]), 6000), "four thorns flicked off its tufts"),
    ],
    # Thorn Bite, the bolt half: thorns that stack
    "pet_bramble_wilf_bolt": [
        (lambda: s.mix((soft(then(swish(0.08, 800, 2500), crackle(0.15, 0.9), 0.05, 0.5, 0.7)), 1.0), (s.at(glimmer([1319, 1568]), 0.05), 0.3)), "a thorny bolt with a glint"),
        (lambda: s.mix((soft(snap()), 0.7), (s.at(soft(burst(0.12, lo=500, hi=2500, decay=7)), 0.03), 0.5), (s.at(glimmer([1175, 1568, 1760]), 0.08), 0.35)), "a snapping bite of thorns"),
        (lambda: s.mix((zap(0.12, 1400, 600), 0.4), (s.at(crackle(0.18, 0.9), 0.04), 0.6), (s.at(glimmer([1568, 1976]), 0.06), 0.3)), "a green zap with crackling thorns"),
    ],
    # Thorn Bite, the howl half: speeds its owner's attacks
    "pet_bramble_wilf_howl": [
        (lambda: s.mix((soft(voice(0.32, 450, 700, attack=0.04, decay=3, vibrato=0.08, rate=6), 3500), 0.6), (s.at(glimmer([1319, 1568]), 0.15), 0.3)), "a short howl"),
        (lambda: s.mix((soft(voice(0.35, 380, 620, wave="tri", attack=0.05, decay=3, vibrato=0.1, rate=7), 3000), 0.6), (s.at(s.arp([784, 988, 1175], 0.05, 0.3, s.BELL, decay=7), 0.2), 0.35)), "a howl rising into bells"),
        (lambda: s.mix((soft(voice(0.28, 520, 820, attack=0.03, decay=3, vibrato=0.06, rate=8), 3500), 0.6), (s.at(crackle(0.2, 0.93), 0.08), 0.35), (s.at(glimmer([1319, 1568, 1976]), 0.12), 0.3)), "a yippy howl with rustling thorns"),
    ],
    # Briar Cage: two spirits, and a cage that holds even a boss
    "pet_thorn_princess": [
        (lambda: s.mix((s.arp([659, 784, 988], 0.06, 0.35, s.BELL, decay=7), 0.5), (s.at(soft(s.pluck(130, 0.35, brightness=0.3)), 0.15), 0.5), (s.at(glimmer([1568, 1976, 2349]), 0.18), 0.35)), "a fairy fanfare and creaking vines closing"),
        (lambda: s.mix((soft(then(voice(0.1, 600, 1200, decay=7), voice(0.1, 700, 1400, decay=7), 0.08)), 0.4), (s.at(soft(s.mix(*[(s.at(burst(0.05, hi=2500, decay=8), i * 0.05), 0.5) for i in range(4)])), 0.15), 0.6), (s.at(glimmer([1319, 1760]), 0.25), 0.35)), "two spirits swoop in, the cage snaps shut"),
        (lambda: s.mix((soft(thump(0.18, 100, decay=7)), 0.6), (s.at(crackle(0.25, 0.9), 0.02), 0.4), (s.at(s.arp([988, 1175, 1397], 0.05, 0.4, s.BELL, decay=7), 0.04), 0.45)), "a royal thorn cage slamming down"),
    ],
    # The Wake: a ring of thorns turning round its owner
    "pet_thornwake": [
        (lambda: s.mix((soft(s.whoosh(0.4, 400, 1800, q=1.6, attack=0.1, decay=3), 4000), 0.6), (s.at(crackle(0.35, 0.92), 0.05), 0.4), (s.at(glimmer([1047, 1319, 1568, 2093], 0.05), 0.1), 0.4)), "a swirl of thorns with rainbow sparkles"),
        (lambda: s.mix(*[(s.at(swish(0.1, 800, 2600), i * 0.07), 0.4) for i in range(5)], (s.at(s.arp([784, 988, 1175, 1568], 0.06, 0.4, s.GLASS, decay=6), 0.05), 0.4)), "a ring of thorns whirling round, chiming"),
        (lambda: s.mix((voice(0.45, 300, 600, attack=0.08, decay=3, vibrato=0.15, rate=9), 0.3), (soft(s.whoosh(0.45, 600, 2400, q=1.4, attack=0.1, decay=3)), 0.5), (s.at(glimmer([1568, 2093, 2637]), 0.2), 0.4)), "a deep thorny hum that blooms"),
    ],
    # ---- the Drowned Village's pets ----
    # Roof Huddle: it tucks in beside you and everything hurts less
    "pet_slate_turtle": [
        (lambda: soft(s.mix((clack(600), 0.6), (s.at(s.tone(220, 0.3, 6, ((1, 1.0), (2.4, 0.3))), 0.03), 0.5), (s.at(burst(0.2, hi=900, decay=5, attack=0.03), 0.05), 0.3)), 3000), "a slate clack and a sheltering hum"),
        (lambda: soft(then(splash(0.15, 2500, 4), s.mix((thump(0.12, 130), 0.8), (s.tone(260, 0.25, 7, s.WARM), 0.4)), 0.06, 0.6, 1.0)), "a small splash and a shell settling"),
        (lambda: s.mix((soft(s.mix(*[(s.at(clack(700 + 100 * i), i * 0.05), 0.6) for i in range(3)])), 0.7), (s.at(voice(0.3, 200, 240, attack=0.05, decay=4), 0.1), 0.4)), "slates tapping shut, a low hum"),
    ],
    # Payback Puff: one blunt spine at triple weight when its owner is hurt
    "pet_buoy_puffer": [
        (lambda: then(voice(0.12, 250, 700, wave="tri", attack=0.03, decay=3), soft(s.mix((thump(0.1, 140), 0.8), (snap(), 0.4))), 0.1, 0.5, 1.0), "a puff-up and a spiny bonk"),
        (lambda: soft(s.mix((burst(0.12, lo=200, hi=1200, decay=4, attack=0.04), 0.6), (s.at(s.tone(180, 0.1, 14, s.WARM), 0.1), 0.6), (s.at(burst(0.03, lo=2000, decay=8), 0.1), 0.5))), "a whoomph of air and a jab"),
        (lambda: soft(then(blub(0.15, 300, 900), voice(0.06, 900, 300, decay=8), 0.12, 0.6, 0.6)), "a bubbly inflate and a pop"),
    ],
    # Ink Blink: ink in one enemy's face
    "pet_inkpot": [
        (lambda: soft(then(squelch(0.1, 2500, 800), squelch(0.15, 1200, 300), 0.06)), "a squirt and an inky splat"),
        (lambda: soft(s.mix((burst(0.08, lo=1500, hi=5000, decay=6), 0.5), (s.at(blub(0.15, 600, 250), 0.05), 0.6))), "a spurt of ink, a gloop"),
        (lambda: soft(then(voice(0.05, 400, 1600, wave="tri", decay=6), splash(0.18, 2000, 7), 0.04, 0.4, 0.8)), "a pfft and a wet splat"),
    ],
    # Wake Chase: foam that bites whatever wears it for moving
    "pet_tide_wilf": [
        (lambda: s.mix((soft(s.whoosh(0.3, 300, 1500, q=1.2, attack=0.04, decay=4)), 0.5), (s.at(splash(0.25, 4000, 9), 0.08), 0.6), (s.at(glimmer([1319, 1568, 1976]), 0.1), 0.3)), "a rushing wave with a glint"),
        (lambda: s.mix((soft(voice(0.25, 480, 700, attack=0.03, decay=3, vibrato=0.08, rate=6)), 0.4), (s.at(splash(0.3, 3500, 11), 0.1), 0.6), (s.at(glimmer([1568, 1976]), 0.15), 0.3)), "a short howl into foam"),
        (lambda: s.mix((burst(0.35, lo=800, hi=6000, decay=4, attack=0.05), 0.4), (s.at(s.mix(*[(s.at(blub(0.05, f, f * 1.5), i * 0.04), 0.3) for i, f in enumerate((700, 900, 800, 1100))]), 0.05), 0.6), (s.at(glimmer([1175, 1568]), 0.15), 0.3)), "fizzing foam and bubbles"),
    ],
    # Deep Accord, and a curtain of stinging tentacles
    "pet_abyss_jelly": [
        (lambda: s.mix((voice(0.5, 150, 220, attack=0.08, decay=3, vibrato=0.2, rate=5), 0.3), (s.at(s.mix(*[(s.at(zap(0.06, 2400, 1200), i * 0.06), 0.3) for i in range(4)]), 0.1), 0.5), (s.at(glimmer([1047, 1319, 1568, 2093], 0.05), 0.1), 0.4)), "a deep pulse, stinging zaps, rainbow sparkles"),
        (lambda: s.mix((soft(blub(0.4, 200, 500, decay=3)), 0.5), (s.at(s.arp([523, 784, 1047, 1568], 0.07, 0.5, s.GLASS, decay=5), 0.05), 0.5), (s.at(crackle(0.3, 0.95), 0.1), 0.3)), "a watery swell with glassy chimes and fizz"),
        (lambda: s.mix((s.tone(110, 0.5, 4, s.WARM), 0.3), (s.at(s.mix(*[(s.at(then(burst(0.02, lo=3000, decay=8), s.tone(1800 + 300 * i, 0.06, 20, s.GLASS), 0.005, 0.5, 0.4), i * 0.07), 1.0) for i in range(4)]), 0.08), 0.5), (s.at(glimmer([1568, 2093, 2637]), 0.2), 0.35)), "a deep thrum and four stings"),
    ],
    # ---- Bogheart Caverns' pets ----
    # Long Chirp: the enemy furthest off
    "pet_cave_cricket": [
        (lambda: s.mix((chirrup(0.1, 4300), 0.6), (s.at(swish(0.1, 1500, 4000), 0.06), 0.5)), "a chirp and a dart"),
        (lambda: s.mix((chirrup(0.06, 4000), 0.5), (s.at(chirrup(0.06, 4600), 0.08), 0.5), (s.at(swish(0.08, 2000, 4500), 0.12), 0.4)), "a chirp-chirp, then a dart"),
        (lambda: s.mix((voice(0.05, 3500, 4500, decay=6), 0.4), (s.at(s.pluck(880, 0.18, brightness=0.8), 0.03), 0.5), (s.at(swish(0.1, 1800, 5000), 0.05), 0.4)), "a leg-flick twang"),
    ],
    # Fourth Lick: short nips, every fourth one triple
    "pet_lichen_gecko": [
        (lambda: soft(then(voice(0.05, 500, 2000, wave="tri", decay=6), snap(), 0.05, 0.5, 0.6), 4500), "a quick lick and a nip"),
        (lambda: soft(then(burst(0.03, lo=2500, decay=8), voice(0.07, 1500, 500, wave="tri", decay=6), 0.02, 0.5, 0.6)), "a flick-snap"),
        (lambda: s.mix((squeak(3200, 0.04), 0.3), (s.at(soft(snap()), 0.04), 0.7)), "a chirp and a tiny bite"),
    ],
    # Mud Plaster: soaks hits for a moment
    "pet_bog_beaver": [
        (lambda: soft(then(squelch(0.1, 900, 300), thump(0.1, 160), 0.08)), "a mud slap and a tail pat"),
        (lambda: soft(s.mix((thump(0.1, 140), 0.7), (s.at(thump(0.1, 140), 0.1), 0.7), (s.at(squelch(0.2, 700, 250), 0.12), 0.5))), "two tail slaps into mud"),
        (lambda: soft(s.mix((squelch(0.18, 1200, 350), 0.6), (s.at(s.tone(330, 0.25, 7, s.WARM), 0.06), 0.4))), "a wet plaster and a warm hum"),
    ],
    # Glow Mote, the first half: the light sticks to an enemy
    "pet_lanternfin_mote": [
        (lambda: s.mix((voice(0.2, 900, 1600, attack=0.03, decay=5), 0.4), (s.at(s.tone(1760, 0.25, 8, s.GLASS), 0.1), 0.5)), "a bright hum that sticks"),
        (lambda: s.arp([1175, 1568], 0.07, 0.3, s.GLASS, decay=8), "two glowing pings"),
        (lambda: s.mix((blub(0.12, 600, 1200), 0.4), (s.at(glimmer([1568, 1976]), 0.08), 0.5)), "a bubble of light"),
    ],
    # Glow Mote, the second half: it bursts 1.5 s later
    "pet_lanternfin_burst": [
        (lambda: s.mix((soft(burst(0.18, hi=2500, decay=6)), 0.6), (s.at(s.arp([1568, 1175, 880], 0.04, 0.3, s.GLASS, decay=8), 0.02), 0.4)), "a soft pop of light"),
        (lambda: s.mix((zap(0.15, 2200, 600), 0.4), (thump(0.12, 140), 0.5), (s.at(glimmer([1319, 1760, 2093]), 0.04), 0.4)), "a bright burst with a thump"),
        (lambda: soft(s.mix((burst(0.25, lo=400, hi=4000, decay=5, attack=0.005), 0.6), (s.at(crackle(0.2, 0.93), 0.03), 0.4))), "a fizzing flare"),
    ],
    # Tremor Snap: harder the more enemies crowd its target
    "pet_olm": [
        (lambda: soft(s.mix((rumble(0.25, 200), 0.8), (s.at(snap(), 0.15), 0.6)), 3000), "a ground rumble and a snap"),
        (lambda: soft(s.mix((thump(0.2, 70, decay=6), 0.8), (s.at(snap(), 0.05), 0.5), (s.at(skitter(4, 0.04, 900, 5), 0.05), 0.3))), "a deep thud, a snap and pebbles"),
        (lambda: soft(then(voice(0.15, 120, 80, decay=4), s.mix((burst(0.04, lo=1500, decay=8), 0.6), (s.tone(600, 0.06, 20, s.WARM), 0.4)), 0.1)), "a low rumble ending in a bite"),
    ],
    # Spore Sneeze: a wedge of spores toward the nearest enemy
    "pet_glowcap_wilf": [
        (lambda: s.mix((voice(0.12, 500, 800, wave="tri", attack=0.05, decay=2), 0.2), (s.at(burst(0.2, lo=600, hi=5000, decay=5, attack=0.005), 0.12), 0.7), (s.at(glimmer([1319, 1568, 1976]), 0.16), 0.3)), "an 'ah...' then a sparkly spore sneeze"),
        (lambda: s.mix((soft(burst(0.3, hi=3000, decay=4, attack=0.01)), 0.6), (s.at(glimmer([1047, 1319, 1568]), 0.05), 0.4)), "a big puff of glowing spores"),
        (lambda: s.mix((voice(0.08, 900, 1300, wave="tri", decay=6), 0.3), (s.at(soft(s.whoosh(0.25, 2000, 600, q=1.2, attack=0.005, decay=4)), 0.06), 0.6), (s.at(glimmer([1568, 1976, 2349]), 0.1), 0.3)), "a yip and a spray of spores"),
    ],
    # Little Belly Flop: lands on the crowd
    "pet_gulpling": [
        (lambda: s.mix((soft(s.mix((squelch(0.2, 800, 200), 0.6), (thump(0.16, 90, decay=8), 0.8))), 1.0), (s.at(glimmer([1175, 1568]), 0.08), 0.3)), "a belly flop splat"),
        (lambda: s.mix((soft(then(swish(0.1, 1500, 500), s.mix((thump(0.16, 85), 0.8), (splash(0.2, 2500, 13), 0.5)), 0.08)), 1.0), (s.at(glimmer([1175, 1568]), 0.12), 0.3)), "a little whoosh and a wet flop"),
        (lambda: s.mix((soft(blub(0.12, 250, 150)), 0.5), (s.at(soft(thump(0.18, 80, decay=7)), 0.06), 0.8), (s.at(s.arp([784, 988, 1175], 0.05, 0.35, s.BELL, decay=7), 0.08), 0.35)), "a gulp, a flop, a jingle"),
    ],
    # Prism Split: a crystal bolt that breaks into three shards
    "pet_prism_leviathan": [
        (lambda: s.mix((zap(0.2, 1200, 2400), 0.3), (s.at(s.arp([2093, 2637, 3136], 0.05, 0.3, s.GLASS, decay=8), 0.2), 0.5), (s.at(glimmer([1047, 1319, 1568, 2093], 0.04), 0.02), 0.35)), "a crystal bolt, then three shard tinks"),
        (lambda: s.mix((soft(s.whoosh(0.25, 800, 3000, q=1.5, attack=0.02, decay=4)), 0.5), (s.at(s.tone(1568, 0.3, 7, s.GLASS), 0.12), 0.4), (s.at(s.arp([2349, 2793, 3322], 0.04, 0.25, s.GLASS, decay=9), 0.2), 0.4)), "a sweeping crystal shot that shatters"),
        (lambda: s.mix((voice(0.3, 300, 450, attack=0.03, decay=3, vibrato=0.1, rate=5), 0.25), (s.at(s.arp([1319, 1760, 2093, 2637], 0.05, 0.4, s.BELL, decay=6), 0.05), 0.5)), "a deep sea hum with rainbow bells"),
    ],
    # ---- enemies: a blow that lands (`AttackAt`) or a volley leaving (`ShotAt`) ----
    # Charger (Moss Slime): a bump, about once a second
    "enemy_charger_bite": [
        (lambda: soft(then(squelch(0.08, 1200, 400), thump(0.08, 160), 0.03, 0.6, 0.7)), "a slimy bump"),
        (lambda: soft(s.mix((voice(0.1, 300, 150, wave="tri", decay=7), 0.6), (burst(0.05, hi=2500, decay=8), 0.4))), "a quick gloopy chomp"),
        (lambda: soft(then(voice(0.04, 600, 900, decay=8), squelch(0.1, 900, 300), 0.03)), "a blip and a squish"),
    ],
    # Bulwark: a heavy, slow blow
    "enemy_bulwark_bash": [
        (lambda: soft(s.mix((thump(0.2, 70, decay=7), 0.9), (squelch(0.18, 600, 150), 0.5)), 2500), "a heavy slimy thud"),
        (lambda: soft(then(voice(0.1, 160, 110, wave="tri", decay=4), thump(0.18, 75, decay=7), 0.07)), "a grunt and a big body slam"),
        (lambda: soft(s.mix((thump(0.22, 60, decay=6), 0.9), (s.tone(140, 0.2, 9, ((1, 1.0), (2.4, 0.3))), 0.4))), "a deep bonk"),
    ],
    # Spitter: two orbs, every 3 s
    "enemy_spitter_spit": [
        (lambda: soft(then(voice(0.06, 300, 900, wave="tri", decay=6), voice(0.06, 330, 950, wave="tri", decay=6), 0.07)), "ptoo-ptoo"),
        (lambda: soft(s.mix((squelch(0.12, 2000, 700), 0.6), (s.at(squelch(0.12, 2100, 750), 0.06), 0.5))), "a double wet spit"),
        (lambda: soft(then(burst(0.05, lo=500, hi=3000, decay=6), blub(0.1, 400, 800), 0.03)), "a hork and a gloop"),
    ],
    # Baby Slime: a tiny nip, often several at once
    "enemy_baby_slime_bite": [
        (lambda: soft(voice(0.06, 700, 400, wave="tri", decay=7)), "a tiny bloop-nip"),
        (lambda: soft(squelch(0.06, 2500, 1200)), "a tiny squish"),
        (lambda: soft(then(voice(0.03, 900, 1200, decay=8), burst(0.03, lo=2000, decay=8), 0.02)), "a peep and a nip"),
    ],
    # Brood Slime: a bigger, gloopier bite
    "enemy_brood_slime_bite": [
        (lambda: soft(s.mix((voice(0.14, 260, 120, wave="tri", decay=6), 0.7), (squelch(0.12, 1000, 300), 0.5))), "a big gloopy chomp"),
        (lambda: soft(then(squelch(0.1, 900, 300), thump(0.12, 110), 0.05)), "a squelch and a thud"),
        (lambda: soft(s.mix((blub(0.16, 200, 120), 0.6), (burst(0.06, hi=2000, decay=8), 0.4))), "a heavy wobble-bite"),
    ],
    # Lurker: surfaces and flings a fan of five clods
    "enemy_burrower_clods": [
        (lambda: soft(s.mix((rumble(0.2, 600, 5), 0.7), (s.at(skitter(5, 0.03, 700, 7), 0.05), 0.5)), 3000), "dirt bursting, clods flung"),
        (lambda: soft(then(thump(0.12, 90), s.mix(*[(s.at(swish(0.06, 600, 1800), i * 0.025), 0.3) for i in range(5)]), 0.04)), "a thump and a fan of clods"),
        (lambda: soft(s.mix((burst(0.25, lo=150, hi=1500, decay=5, attack=0.01), 0.7), (s.at(crackle(0.2, 0.9), 0.03), 0.4))), "a crumbly earth spray"),
    ],
    # Lancer (benched, no room yet): one fast lance
    "enemy_lancer_lance": [
        (lambda: s.mix((swish(0.15, 1200, 5000), 0.6), (s.tone(1800, 0.15, 12, ((1, 1.0), (2.32, 0.4))), 0.3)), "a sharp zing"),
        (lambda: s.mix((voice(0.12, 2000, 600, wave="tri", decay=5), 0.4), (burst(0.1, lo=2500, decay=5), 0.5)), "a piercing fwip"),
        (lambda: s.mix((burst(0.02, lo=2000, decay=8), 0.6), (s.at(s.whoosh(0.2, 600, 4000, q=2, attack=0.01, decay=5), 0.01), 0.7)), "a click and a long whoosh"),
    ],
    # Glowcap: four glowing spores
    "enemy_glowcap_spores": [
        (lambda: soft(s.mix(*[(s.at(voice(0.06, 500 + 80 * i, 900 + 80 * i, wave="tri", decay=7), i * 0.045), 0.5) for i in range(4)])), "four soft spore pops"),
        (lambda: s.mix((soft(burst(0.2, hi=2500, decay=5, attack=0.01)), 0.6), (s.at(s.arp([880, 1047], 0.05, 0.2, s.GLASS, decay=9), 0.03), 0.3)), "a glowing puff"),
        (lambda: soft(then(voice(0.08, 250, 500, attack=0.02, decay=4), s.mix(*[(s.at(burst(0.04, hi=3000, decay=7), i * 0.04), 0.4) for i in range(4)]), 0.06)), "a swell, then four pfts"),
    ],
    # Spore Puff: a bite (its threat is the cloud it leaves)
    "enemy_spore_puff_bite": [
        (lambda: soft(s.mix((voice(0.08, 400, 250, wave="tri", decay=7), 0.6), (burst(0.08, hi=2000, decay=6), 0.4))), "a puffy bump"),
        (lambda: soft(then(burst(0.05, hi=1500, decay=6), snap(), 0.02, 0.5, 0.5)), "a pff and a nip"),
        (lambda: soft(voice(0.1, 600, 300, decay=7, vibrato=0.2, rate=30)), "a wobbly boop"),
    ],
    # Shellback: a heavy shell bash
    "enemy_shellback_bash": [
        (lambda: soft(s.mix((thump(0.18, 80, decay=7), 0.9), (clack(500), 0.5)), 3000), "a stony shell bash"),
        (lambda: soft(then(s.tone(200, 0.08, 14, s.WARM), s.mix((thump(0.16, 70), 0.8), (burst(0.08, lo=800, hi=3000, decay=7), 0.4)), 0.05)), "a knock and a crunch"),
        (lambda: soft(s.mix((s.tone(160, 0.25, 8, SHELL), 0.5), (thump(0.15, 90), 0.8))), "a ringing shell slam"),
    ],
    # Hollow Fisherman: casts its bobber
    "enemy_fisherman_cast": [
        (lambda: s.mix((swish(0.12, 600, 3000), 0.6), (s.at(s.whoosh(0.3, 3000, 2000, q=4, attack=0.01, decay=3), 0.08), 0.2)), "a rod whip and the line zinging out"),
        (lambda: s.mix((swish(0.1, 500, 2500), 0.6), (s.at(skitter(8, 0.02, 2200, 9), 0.06), 0.3)), "a cast and the reel clicking"),
        (lambda: s.mix((soft(burst(0.05, lo=300, hi=2000, decay=6)), 0.5), (s.at(swish(0.14, 800, 3500), 0.03), 0.6), (s.at(s.tone(660, 0.12, 12, ((1, 1.0), (2.76, 0.3))), 0.12), 0.3)), "a creaky flick and a bobber bell"),
    ],
    # ---- the Old Tollcrab (`TollcrabMoves`) ----
    # Toll, the wind-up: the bell raised
    "boss_toll_raise": [
        (lambda: s.mix((creak(0.7, 300, 1200), 0.5), (s.at(big_bell(220, 0.7, 6), 0.3), 0.15)), "a creaking lift with a faint hum"),
        (lambda: s.mix((voice(0.8, 110, 165, wave="tri", attack=0.3, decay=2), 0.5), (s.at(s.tone(440, 0.5, 6, s.BELL), 0.3), 0.2)), "a rising hum as the bell goes up"),
        (lambda: s.mix((skitter(4, 0.08, 900, 11), 0.4), (s.at(s.whoosh(0.5, 200, 900, q=1.5, attack=0.2, decay=3), 0.05), 0.5)), "claws gripping, the bell swung up"),
    ],
    # Toll: the bell planted and rung, a ring rolling out
    "boss_toll_ring": [
        (lambda: s.mix((thump(0.25, 60, decay=6), 0.7), (big_bell(147, 1.8, 2.5), 0.6)), "a planted thud and a deep BONG"),
        (lambda: s.mix((big_bell(175, 1.6, 3), 0.6), (s.at(big_bell(262, 1.2, 3.5), 0.02), 0.15), (s.at(s.whoosh(0.8, 300, 120, q=1.2, attack=0.05, decay=3), 0.05), 0.4)), "a bell clang with a rolling whoosh"),
        (lambda: s.mix((clack(400), 0.5), (big_bell(131, 2.0, 2.2), 0.7), (s.at(rumble(0.6, 250), 0.02), 0.5)), "a heavy toll that rumbles"),
    ],
    # Echo: each rap drops a glowing ring under the player
    "boss_toll_rap": [
        (lambda: s.mix((clack(1200), 0.6), (s.at(s.tone(880, 0.35, 7, s.BELL), 0.01), 0.4)), "a claw rap and a ping"),
        (lambda: s.mix((clack(1100), 0.5), (s.at(clack(1300), 0.08), 0.5), (s.at(s.tone(660, 0.3, 8, s.GLASS), 0.08), 0.35)), "tok-tok on the bell"),
        (lambda: s.mix((s.tone(988, 0.4, 6, s.BELL), 0.5), (s.at(voice(0.3, 600, 1200, decay=4), 0.02), 0.12)), "a bright ping that rises"),
    ],
    # Echo: a ring striking a beat later
    "boss_toll_echo": [
        (lambda: s.mix((thump(0.15, 90), 0.7), (s.tone(523, 0.4, 6, s.BELL), 0.5)), "a ring striking down: thud and bell"),
        (lambda: s.mix((burst(0.15, hi=3000, decay=6), 0.5), (s.tone(392, 0.45, 5, ((1, 1.0), (2.0, 0.5), (2.76, 0.35))), 0.5)), "a burst, clanging"),
        (lambda: s.mix((zap(0.15, 1600, 400), 0.3), (thump(0.15, 100), 0.6), (s.at(s.tone(784, 0.3, 8, s.GLASS), 0.02), 0.3)), "a zapping strike"),
    ],
    # Scuttle: each sideways dash
    "boss_toll_scuttle": [
        (lambda: s.mix((skitter(8, 0.03, 1300, 13), 0.6), (swish(0.2, 300, 1200), 0.5)), "a claw-clattering dash"),
        (lambda: s.mix((skitter(6, 0.04, 900, 15), 0.5), (s.whoosh(0.3, 200, 800, q=1.2, attack=0.02, decay=4), 0.6), (thump(0.12, 90), 0.4)), "a heavy sideways scuttle"),
        (lambda: s.mix((s.mix(*[(s.at(clack(1000 + 200 * (i % 2)), i * 0.05), 0.5) for i in range(7)]), 0.8), (s.tone(220, 0.3, 6, s.BELL), 0.1)), "a tap-tap-tap of claws, the bell humming"),
    ],
    # ---- Grandmother Gulp (`BossMoves` Spit, Slide, Gulp) ----
    # Spit: each of her three globs, landing 0.75 s later
    "boss_gulp_spit": [
        (lambda: s.mix((soft(then(burst(0.12, lo=200, hi=1500, decay=5), voice(0.15, 200, 600, wave="tri", decay=6), 0.05)), 0.7), (s.at(soft(squelch(0.2, 900, 200)), GLOB_LANDS), 0.6)), "a big hork, then the glob splats down"),
        (lambda: s.mix((soft(blub(0.25, 150, 400, decay=4)), 0.6), (s.at(soft(then(thump(0.12, 100), squelch(0.15, 800, 250), 0.01)), GLOB_LANDS), 0.6)), "a gurgly spit and a wet landing"),
        (lambda: soft(s.mix((voice(0.2, 180, 90, wave="tri", decay=4), 0.6), (squelch(0.15, 1500, 400), 0.5))), "a deep 'blorp' as it leaves (no landing)"),
    ],
    # Belly Slide: across the room, leaving a trail
    "boss_gulp_slide": [
        (lambda: s.mix((soft(s.whoosh(1.0, 200, 700, q=1.2, attack=0.05, decay=2)), 0.6), (squelch(1.0, 400, 1200, q=1.5, decay=2), 0.5)), "a long slimy slide"),
        (lambda: s.mix((soft(voice(0.3, 200, 120, wave="tri", decay=3)), 0.4), (s.at(soft(s.whoosh(0.9, 300, 900, q=1.5, attack=0.05, decay=2.5)), 0.15), 0.6), (s.at(s.mix(*[(s.at(blub(0.06, 300, 500), i * 0.12), 0.3) for i in range(7)]), 0.2), 0.5)), "an 'oof' then a squelching belly slide"),
        (lambda: soft(s.mix((rumble(1.2, 500, 2.5), 0.8), (squelch(1.2, 300, 900, q=1.2, decay=2), 0.5))), "a heavy, wet rumble along the floor"),
    ],
    # Big Gulp: a 2.2 s inhale that drags the player to her
    "boss_gulp_inhale": [
        (lambda: s.mix((inhale(2.0, 300, 2400), 0.6), (voice(2.0, 80, 160, attack=1.5, decay=1), 0.2)), "a huge rising inhale"),
        (lambda: s.mix((inhale(2.1, 500, 1500), 0.6), (s.at(blub(0.25, 300, 150), 1.9), 0.6)), "a long suck, ending in a gulp"),
        (lambda: s.mix((inhale(1.8, 200, 3000), 0.6), (s.at(s.mix(*[(s.at(voice(0.1, 900, 1400, decay=6), i * 0.25), 0.15) for i in range(6)]), 0.2), 0.4)), "a whooshing pull with whistling air"),
    ],
}


def main():
    out = sys.argv[1]
    os.makedirs(out, exist_ok=True)
    manifest = {}
    for name, takes in SOUNDS.items():
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
