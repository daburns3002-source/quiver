"""Takes for the class upgrades' sounds (round 28), made with synth.py's tools.

    python -I class_card_synth.py <out_dir>

The seven class upgrades of 2026-10-27 have been silent since they were built
(docs/TRACKER.md: "sounds picked: seven hooks, one sprite, one audio upload"),
and the nine class cards of 2026-11-13 brought seven more hooks. Three designed
takes for each of the fourteen, levelled to the same peak as every other
round's, with a manifest build_page.py reads (page "28"). The picks go into one
sprite (sprite.py) and one upload.
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


def env(seconds, attack, decay):
    return s.env_ad(int(SR * seconds), attack, decay)


def thump(seconds, f0, f1, decay=7):
    return s.chirp(seconds, f0, f1) * env(seconds, 0.003, decay)


def crackle(seconds, density=0.04, lo=1500, hi=7000):
    n = int(SR * seconds)
    x = np.zeros(n)
    hits = s.rng.random(n) < density / 40
    x[hits] = s.rng.uniform(-1, 1, hits.sum())
    return s.bandpass(x, lo, hi) * 6


# ---------- the Ranger ----------

def phoenix_cry():
    """A bird's cry rising out of a burst of fire."""
    cry = s.chirp(0.5, 900, 2400, wave="tri") * env(0.5, 0.02, 4)
    vib = 1 + 0.25 * np.sin(np.linspace(0, 2 * np.pi * 14, len(cry)))
    fire = s.whoosh(0.7, 300, 1800, q=1.0, attack=0.01, decay=3)
    return s.room(s.mix((cry * vib, 0.6), (fire, 0.7), (crackle(0.7), 0.25)), 0.16, 0.2)


def phoenix_whoosh():
    """A roaring fire whoosh that flies past."""
    roar = s.lowpass(s.noise(0.8), 1400) * np.sin(np.linspace(0, np.pi, int(SR * 0.8))) ** 0.8
    rise = s.whoosh(0.8, 400, 3000, q=1.6, attack=0.05, decay=2.5)
    return s.room(s.mix((roar, 0.8), (rise, 0.6), (crackle(0.8, 0.06), 0.3)), 0.14, 0.18)


def phoenix_bright():
    """Fire whoosh with a bright three-note call on top."""
    call = s.arp([1175, 1568, 2093], 0.07, 0.4, s.GLASS, 7)
    return s.mix((phoenix_whoosh(), 0.7), (call, 0.35))


def rain_volley():
    """One arrow up, then a patter of arrows landing."""
    up = s.whoosh(0.3, 800, 4000, q=2.0, attack=0.01, decay=4)
    parts = [(up, 0.7)]
    for i in range(10):
        tick = s.mix((s.tone(1800 + 300 * (i % 3), 0.06, 30, ((1, 1.0), (2.3, 0.4))), 1.0), (s.highpass(s.noise(0.04), 3000), 0.4))
        parts.append((s.at(tick, 0.55 + i * 0.04), 0.35))
    return s.room(s.mix(*parts), 0.1, 0.15)


def rain_thuds():
    """Arrows thudding into the ground in a quick roll."""
    parts = [(s.whoosh(0.25, 1200, 3500, q=1.8, attack=0.01, decay=4), 0.5)]
    for i in range(12):
        hit = s.mix((thump(0.08, 400, 120, 20), 1.0), (s.bandpass(s.noise(0.05), 600, 2500), 0.5))
        parts.append((s.at(hit, 0.5 + i * 0.035), 0.4))
    return s.room(s.mix(*parts), 0.12, 0.2)


def rain_hiss():
    """A rising whistle, then the hiss of a falling rain of arrows."""
    whistle = s.chirp(0.45, 1200, 3200) * env(0.45, 0.05, 3) * 0.6
    hiss = s.sweep_filter(s.noise(0.6), 5000, 1500, q=1.2) * env(0.6, 0.05, 2.5)
    return s.room(s.mix((whistle, 0.6), (s.at(hiss, 0.4), 0.7)), 0.1, 0.15)


def sniper_crack():
    """A taut string let go, a sharp crack and a fast whistle."""
    twang = s.pluck(196, 0.4, 0.9, bend=0.1)
    crack = s.highpass(s.noise(0.04), 2500) * env(0.04, 0.001, 10)
    zip_ = s.chirp(0.18, 3000, 900) * env(0.18, 0.005, 6)
    return s.room(s.mix((twang, 0.7), (crack, 0.8), (zip_, 0.35)), 0.08, 0.12)


def sniper_ping():
    """A bright ping and a fast streak."""
    ping = s.tone(2637, 0.4, 9, s.GLASS)
    streak = s.whoosh(0.2, 6000, 1500, q=2.4, attack=0.002, decay=5)
    return s.room(s.mix((ping, 0.5), (streak, 0.8), (s.pluck(220, 0.3, 0.8), 0.4)), 0.08, 0.12)


def sniper_heavy():
    """A deep, heavy release with a long whistle."""
    thunk = thump(0.2, 180, 70, 9)
    twang = s.pluck(147, 0.35, 0.7, bend=0.15)
    whistle = s.chirp(0.3, 2400, 1200) * env(0.3, 0.01, 4)
    return s.room(s.mix((thunk, 0.7), (twang, 0.6), (whistle, 0.35)), 0.1, 0.14)


def split_snap():
    """A crisp snap that splits into three quick zips."""
    snap = s.highpass(s.noise(0.03), 2000) * env(0.03, 0.001, 8)
    parts = [(snap, 0.8)]
    for i, f in enumerate((2200, 2600, 3000)):
        parts.append((s.at(s.chirp(0.1, f, f * 0.6) * env(0.1, 0.002, 6), 0.02 + i * 0.02), 0.35))
    return s.room(s.mix(*parts), 0.06, 0.1)


def split_crystal():
    """A small crystal crack and three pings."""
    crack = s.bandpass(s.noise(0.05), 1500, 6000) * env(0.05, 0.001, 9)
    return s.mix((crack, 0.7), (s.arp([1760, 2217, 2637], 0.025, 0.25, s.GLASS, 12), 0.45))


def split_pop():
    """A soft pop with a quick triple flick."""
    pop = thump(0.08, 700, 250, 14)
    flicks = s.mix(*[(s.at(s.whoosh(0.07, 1500, 4000, q=2.5, attack=0.002, decay=6), i * 0.03), 0.5) for i in range(3)])
    return s.mix((pop, 0.7), (flicks, 0.6))


def gust_soft():
    """A short puff of wind."""
    return s.sweep_filter(s.noise(0.3), 600, 2400, q=1.0) * env(0.3, 0.02, 4)


def gust_swirl():
    """Wind swirling round once."""
    x = s.sweep_filter(s.noise(0.35), 900, 3200, q=1.6)
    return x * np.sin(np.linspace(0, np.pi, len(x))) ** 1.2


def gust_pop():
    """A puff with a little pop as the shot breaks."""
    return s.mix((gust_soft(), 0.8), (thump(0.06, 900, 400, 14), 0.4))


# ---------- the Arcanist ----------

def hole_open():
    """A low hum opening, with a downward suck."""
    hum = s.tone(55, 1.2, 1.5, ((1, 1.0), (2, 0.5), (3, 0.2)), attack=0.15)
    wob = 1 + 0.4 * np.sin(np.linspace(0, 2 * np.pi * 7, len(hum)))
    suck = s.whoosh(1.0, 2500, 200, q=1.4, attack=0.1, decay=2)
    return s.room(s.mix((hum * wob, 0.8), (suck, 0.5)), 0.2, 0.25)


def hole_warp():
    """A warping, falling whirl."""
    whirl = s.chirp(1.1, 900, 80, wave="tri") * env(1.1, 0.08, 1.8)
    trem = 1 + 0.5 * np.sin(np.linspace(0, 2 * np.pi * 11, len(whirl)))
    return s.room(s.mix((whirl * trem, 0.6), (s.lowpass(s.noise(1.1), 400) * env(1.1, 0.1, 2), 0.5)), 0.2, 0.25)


def hole_drone():
    """A dark drone with sparkles drawn into it."""
    drone = s.tone(73, 1.2, 1.2, ((1, 1.0), (1.5, 0.4), (2, 0.3)), attack=0.2)
    glints = s.sparkle(0.8, [2637, 2217, 1760, 1319, 1047], 0.12, 6)
    return s.room(s.mix((drone, 0.8), (glints, 0.3)), 0.22, 0.25)


def implode_boom():
    """Everything snaps in, then a deep boom."""
    snap = s.whoosh(0.18, 300, 3000, q=1.5, attack=0.15, decay=0.5)
    boom = s.mix((thump(0.6, 120, 35, 5), 1.0), (s.lowpass(s.noise(0.5), 600) * env(0.5, 0.002, 6), 0.6))
    return s.room(s.mix((snap, 0.5), (s.at(boom, 0.16), 0.9)), 0.18, 0.22)


def implode_glass():
    """A sharp inward rush and a bright shatter."""
    rush = s.whoosh(0.15, 4000, 400, q=1.6, attack=0.12, decay=0.5)
    shatter = s.mix((s.highpass(s.noise(0.35), 2500) * env(0.35, 0.002, 5), 1.0), (s.arp([1568, 2093, 2637, 3136], 0.02, 0.4, s.GLASS, 9), 0.4))
    return s.room(s.mix((rush, 0.6), (s.at(thump(0.4, 150, 45, 6), 0.13), 0.8), (s.at(shatter, 0.14), 0.5)), 0.15, 0.2)


def implode_thud():
    """A short, heavy thud with a ring."""
    ring = s.tone(196, 0.6, 5, METAL) * 0.4
    return s.room(s.mix((thump(0.45, 140, 40, 6), 1.0), (ring, 0.4)), 0.15, 0.2)


def turret_chime():
    """A crystal rising with a chime."""
    rise = s.arp([784, 988, 1175, 1568], 0.05, 0.6, s.GLASS, 6)
    return s.room(s.mix((rise, 0.6), (s.whoosh(0.4, 800, 3500, q=2.0, attack=0.05, decay=3), 0.3)), 0.15, 0.25)


def turret_hum():
    """A humming crystal powering up."""
    hum = s.chirp(0.6, 220, 660) * env(0.6, 0.15, 2.5)
    return s.room(s.mix((hum, 0.5), (s.sparkle(0.5, [1319, 1760, 2349], 0.08, 8), 0.4)), 0.15, 0.25)


def turret_form():
    """Crystal blocks clicking together."""
    clicks = s.mix(*[(s.at(s.tone(1400 + 200 * i, 0.08, 25, s.GLASS), i * 0.06), 0.5) for i in range(5)])
    return s.room(s.mix((clicks, 0.7), (s.at(s.tone(1760, 0.5, 6, s.BELL), 0.3), 0.4)), 0.12, 0.2)


def surge_rise():
    """A rising shimmer of mana."""
    return s.room(s.mix((s.chirp(0.5, 400, 1600) * env(0.5, 0.05, 3), 0.4), (s.sparkle(0.5, [1047, 1319, 1568, 2093], 0.05, 8), 0.5)), 0.15, 0.25)


def surge_whomp():
    """A soft magic whomp charging up."""
    whomp = s.sweep_filter(s.noise(0.4), 200, 1800, q=2.0) * env(0.4, 0.08, 3)
    return s.room(s.mix((whomp, 0.8), (s.tone(523, 0.4, 5, s.WARM), 0.3)), 0.15, 0.2)


def surge_bell():
    """A clear bell with a soft glow under it."""
    return s.room(s.mix((s.tone(1047, 0.7, 4, s.BELL), 0.6), (s.tone(523, 0.7, 3, s.WARM), 0.3)), 0.18, 0.25)


def shield_shatter():
    """A glassy shield breaking."""
    hit = thump(0.1, 600, 200, 12)
    glass = s.highpass(s.noise(0.4), 3000) * env(0.4, 0.002, 6)
    chimes = s.arp([2093, 1760, 1397, 1175], 0.03, 0.4, s.GLASS, 8)
    return s.room(s.mix((hit, 0.6), (glass, 0.5), (chimes, 0.4)), 0.12, 0.2)


def shield_bong():
    """A deep magical bong as the shield takes the hit."""
    bong = s.tone(330, 0.8, 3.5, METAL)
    wob = 1 + 0.3 * np.sin(np.linspace(0, 2 * np.pi * 9, len(bong)))
    return s.room(s.mix((bong * wob, 0.7), (thump(0.1, 500, 200, 12), 0.5)), 0.18, 0.25)


def shield_zap():
    """A bright zap and a falling shimmer."""
    zap = s.chirp(0.12, 2500, 600, wave="square") * env(0.12, 0.002, 6) * 0.4
    fall = s.sparkle(0.5, [2637, 2093, 1568, 1175], 0.05, 9)
    return s.room(s.mix((zap, 0.6), (fall, 0.5)), 0.12, 0.2)


# ---------- the Warden ----------

def titan_quake():
    """A huge low slam with rumble."""
    slam = s.mix((thump(0.5, 110, 30, 4), 1.0), (s.lowpass(s.noise(0.6), 500) * env(0.6, 0.002, 4), 0.7))
    rocks = s.mix(*[(s.at(thump(0.07, 500, 200, 18), 0.08 + i * 0.05), 0.3) for i in range(5)])
    return s.room(s.mix((slam, 1.0), (rocks, 0.5)), 0.2, 0.25)


def titan_crack():
    """A sharp crack splitting the ground, then a boom."""
    crack = s.bandpass(s.noise(0.08), 1500, 6000) * env(0.08, 0.001, 9)
    boom = thump(0.5, 100, 35, 5)
    return s.room(s.mix((crack, 0.8), (s.at(boom, 0.02), 0.9)), 0.2, 0.25)


def titan_metal():
    """The giant blade ringing as it lands."""
    ring = s.tone(110, 0.9, 3, METAL)
    return s.room(s.mix((thump(0.4, 120, 40, 5), 0.9), (ring, 0.4)), 0.2, 0.25)


def counter_slash():
    """A fierce metallic slash."""
    slash = s.whoosh(0.2, 1500, 5000, q=2.0, attack=0.005, decay=4)
    ring = s.tone(880, 0.5, 6, METAL)
    return s.room(s.mix((slash, 0.8), (ring, 0.4), (thump(0.1, 300, 100, 12), 0.6)), 0.1, 0.15)


def counter_clang():
    """A clang and a burst."""
    clang = s.mix((s.tone(660, 0.6, 5, METAL), 1.0), (s.tone(990, 0.4, 7, METAL), 0.5))
    burst = s.bandpass(s.noise(0.15), 800, 4000) * env(0.15, 0.002, 6)
    return s.room(s.mix((clang, 0.6), (burst, 0.7)), 0.12, 0.18)


def counter_roar():
    """A low growl rising into the strike."""
    growl = s.lowpass(s.chirp(0.35, 80, 160, wave="square"), 900) * env(0.35, 0.05, 2) * 0.5
    return s.room(s.mix((growl, 0.6), (s.at(counter_slash(), 0.25), 0.9)), 0.12, 0.18)


def shield_whirr():
    """A shield thrown, spinning away."""
    x = s.sweep_filter(s.noise(0.5), 700, 2400, q=2.5)
    whirr = 1 + 0.7 * np.sin(np.linspace(0, 2 * np.pi * 18, len(x)))
    return s.room(x * whirr * env(0.5, 0.02, 3), 0.1, 0.15)


def shield_throw_clang():
    """A grunt-like thump and a metal ring as it leaves."""
    return s.room(s.mix((thump(0.12, 250, 100, 10), 0.6), (s.tone(523, 0.5, 6, METAL), 0.4), (s.at(shield_whirr(), 0.05), 0.7)), 0.1, 0.15)


def shield_frisbee():
    """A light, fast frisbee whoosh."""
    return s.mix(*[(s.at(s.whoosh(0.12, 900, 2800, q=2.0, attack=0.01, decay=5), i * 0.09), 0.7 - i * 0.12) for i in range(4)])


def storm_spin():
    """A sword whirling away and back."""
    x = s.sweep_filter(s.noise(0.9), 600, 3000, q=2.2)
    whirl = 1 + 0.8 * np.sin(np.linspace(0, 2 * np.pi * 14, len(x)))
    shape = np.sin(np.linspace(0, np.pi, len(x)))
    return s.room(x * whirl * shape, 0.1, 0.15)


def storm_ring():
    """A spinning blade that sings."""
    ring = s.tone(740, 0.9, 2.5, METAL)
    wob = 1 + 0.5 * np.sin(np.linspace(0, 2 * np.pi * 12, len(ring)))
    return s.mix((storm_spin(), 0.7), (ring * wob, 0.3))


def storm_whip():
    """Quick whips round and round."""
    return s.mix(*[(s.at(s.whoosh(0.1, 1200, 4000, q=2.4, attack=0.005, decay=5), i * 0.11), 0.6) for i in range(8)])


DESIGNED = {
    "fx_phoenix": [(phoenix_cry, "A cry rising out of fire"), (phoenix_whoosh, "A fire roar flying past"), (phoenix_bright, "Fire roar with a bright call")],
    "fx_arrow_rain": [(rain_volley, "One up, then a patter"), (rain_thuds, "A roll of thuds"), (rain_hiss, "Whistle, then a falling hiss")],
    "fx_sniper": [(sniper_crack, "Taut release and a crack"), (sniper_ping, "A ping and a fast streak"), (sniper_heavy, "Deep release, long whistle")],
    "fx_split_shot": [(split_snap, "A snap into three zips"), (split_crystal, "Crystal crack and three pings"), (split_pop, "A pop and three flicks")],
    "fx_wind_gust": [(gust_soft, "A short puff"), (gust_swirl, "A swirl of wind"), (gust_pop, "A puff and a pop")],
    "fx_black_hole": [(hole_open, "A low hum opening"), (hole_warp, "A warping whirl"), (hole_drone, "A drone drawing sparkles in")],
    "fx_black_hole_implode": [(implode_boom, "Snap in, deep boom"), (implode_glass, "Rush in, bright shatter"), (implode_thud, "Short heavy thud")],
    "fx_turret": [(turret_chime, "A rising chime"), (turret_hum, "A crystal powering up"), (turret_form, "Blocks clicking together")],
    "fx_mana_surge": [(surge_rise, "A rising shimmer"), (surge_whomp, "A soft whomp"), (surge_bell, "A clear bell")],
    "fx_arcane_shield": [(shield_shatter, "Glass shield breaking"), (shield_bong, "A deep magic bong"), (shield_zap, "A zap and a shimmer")],
    "fx_titan_slam": [(titan_quake, "Huge slam and rubble"), (titan_crack, "Ground cracking, a boom"), (titan_metal, "The giant blade rings")],
    "fx_counter_strike": [(counter_slash, "A fierce slash"), (counter_clang, "A clang and a burst"), (counter_roar, "A growl into the strike")],
    "fx_shield_throw": [(shield_whirr, "A spinning whirr"), (shield_throw_clang, "A ring as it leaves"), (shield_frisbee, "A light, fast whoosh")],
    "fx_blade_storm": [(storm_spin, "Whirling out and back"), (storm_ring, "A spinning blade that sings"), (storm_whip, "Quick whips round")],
}


def main():
    out = sys.argv[1]
    os.makedirs(out, exist_ok=True)
    manifest = {}
    for name, takes in DESIGNED.items():
        manifest[name] = []
        for letter, (fn, note) in zip("abc", takes):
            base = os.path.join(out, f"{name}_{letter}")
            x = s.finish(fn())
            x = x * (0.89 / max(np.abs(x).max(), 1e-9))
            wavfile.write(base + ".wav", SR, (np.clip(x, -1, 1) * 32767).astype(np.int16))
            subprocess.run([FF, "-y", "-loglevel", "error", "-i", base + ".wav", "-b:a", "160k", base + ".mp3"], check=True)
            manifest[name].append({"variant": letter, "file": os.path.basename(base) + ".wav", "note": note, "ms": round(len(x) / SR * 1000)})
        print(name, len(manifest[name]))
    json.dump(manifest, open(os.path.join(out, "manifest.json"), "w"), indent=1)


if __name__ == "__main__":
    main()
