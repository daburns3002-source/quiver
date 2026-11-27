"""Takes for the owner's eleven card picks (round 22), made with synth.py.

    python -I card_sounds_synth.py <out_dir>

The owner, 2026-11-03: "i still want the sounds and animations for it
created. give me sound auditions". Three designed takes for each sound that
wants one, levelled to the same peak as every other round's, with a manifest
build_page.py reads (page "22").

Ten of the eleven cards are here. **Twin Elements has no sound**: it fires on
every cast, where the staff's own cast sound already plays, so a sound of its
own would only thicken a noise the player hears every 1.4 seconds. Its fire
and ice read in the orbs themselves. Windrunner and Ghost Quiver fire that
often too, so each is written for the one moment worth hearing: the stacks
reaching full, and the ghost's own release under the player's.
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
SPIRIT = ((1, 1.0), (2.0, 0.5), (3.01, 0.22), (4.8, 0.1))


# --- Windrunner: the stacks reach full, so it is a lift, not a footstep ---
def wind_rise():
    """Three rising airy notes: the third stack landing."""
    notes = s.arp([660, 880, 1170], 0.07, 0.42, partials=s.GLASS, decay=9)
    air = s.whoosh(0.34, 700, 2600, q=1.6, attack=0.03, decay=5) * 0.5
    return s.room(s.mix((notes, 0.85), (air, 0.5)), 0.08, 0.16)


def wind_gust():
    """One clean gust past the ear, bright at its top."""
    body = s.sweep_filter(s.noise(0.36), 500, 3000, q=2.0)
    body = body * np.sin(np.linspace(0, np.pi, len(body))) ** 1.3
    top = s.at(s.tone(1320, 0.22, 11, s.GLASS) * 0.35, 0.12)
    return s.room(s.mix((body, 0.9), (top, 0.5)), 0.07, 0.14)


def wind_chime():
    """A light double chime, like a runner's bell: reads over a fight."""
    a = s.tone(988, 0.3, 10, s.BELL)
    b = s.at(s.tone(1319, 0.34, 9, s.BELL), 0.08)
    air = s.whoosh(0.26, 900, 2200, q=1.8, attack=0.02, decay=6) * 0.3
    return s.room(s.mix((a, 0.7), (b, 0.8), (air, 0.4)), 0.1, 0.2)


# --- Thornfall: arrows plant in the body, then fire outward ---
def thorn_plant():
    """Three wooden thunks into earth, then a flight of shafts out."""
    out = np.zeros(int(SR * 0.7))
    rng = np.random.default_rng(7)
    for i in range(3):
        k = s.pluck(150 + int(rng.integers(0, 60)), 0.16, brightness=0.25)
        thunk = s.lowpass(s.noise(0.09), 900) * s.env_ad(int(SR * 0.09), 0.002, 14)
        piece = s.mix((k, 0.6), (thunk, 0.9))
        d = int(SR * (0.03 + i * 0.045))
        out[d:d + len(piece)] += piece[:len(out) - d]
    fan = s.at(s.whoosh(0.3, 1400, 500, q=1.5, attack=0.01, decay=6), 0.2) * 0.7
    return s.room(s.mix((out, 0.95), (fan, 0.6)), 0.1, 0.18)


def thorn_burst():
    """One sharp woody crack and a spray of shafts leaving at once."""
    crack = s.bandpass(s.noise(0.1), 300, 2600) * s.env_ad(int(SR * 0.1), 0.001, 18)
    body = s.pluck(120, 0.22, brightness=0.35, bend=-0.2)
    spray = s.at(s.sweep_filter(s.noise(0.34), 2200, 700, q=1.4), 0.07) * 0.55
    return s.room(s.mix((crack, 1.0), (body, 0.55), (spray, 0.7)), 0.1, 0.2)


def thorn_growl():
    """Earthier: a low rumble under the shafts, as if the ground gave them up."""
    low = s.lowpass(s.noise(0.44), 260) * s.env_ad(int(SR * 0.44), 0.02, 5)
    shafts = s.sparkle(0.4, [420, 330, 500, 380], spacing=0.05, decay=12) * 0.6
    return s.room(s.mix((low, 0.9), (shafts, 0.7)), 0.12, 0.2)


# --- Headhunter: the guaranteed crit; it must cut through a volley ---
def head_thunk():
    """A dead-centre thunk with a bright ring off the arrowhead."""
    thunk = s.lowpass(s.noise(0.08), 1100) * s.env_ad(int(SR * 0.08), 0.001, 20)
    ring = s.tone(1760, 0.26, 12, METAL) * 0.45
    body = s.pluck(220, 0.18, brightness=0.6)
    return s.room(s.mix((thunk, 1.0), (body, 0.5), (ring, 0.6)), 0.06, 0.14)


def head_snap():
    """A tight metal snap, up a fifth: the sound of a called shot landing."""
    snap = s.bandpass(s.noise(0.06), 1800, 7000) * s.env_ad(int(SR * 0.06), 0.0008, 26)
    up = s.chirp(0.14, 700, 2300, shape="exp", wave="sine") * s.env_ad(int(SR * 0.14), 0.002, 10)
    return s.room(s.mix((snap, 0.95), (up, 0.6)), 0.05, 0.12)


def head_bell():
    """Hit plus a single clear bell, so a crit is unmistakable in a crowd."""
    hit = s.lowpass(s.noise(0.07), 1400) * s.env_ad(int(SR * 0.07), 0.001, 22)
    bell = s.at(s.tone(2093, 0.4, 8, s.BELL), 0.02) * 0.5
    return s.room(s.mix((hit, 1.0), (bell, 0.65)), 0.08, 0.18)


# --- Ghost Quiver: the ghost's own release, under the player's ---
def ghost_breath():
    """A breathy bow release with no wood in it: air, not string."""
    air = s.sweep_filter(s.noise(0.3), 900, 2400, q=2.4) * s.env_ad(int(SR * 0.3), 0.012, 7)
    hollow = s.tone(392, 0.3, 9, SPIRIT) * 0.3
    return s.room(s.mix((air, 0.8), (hollow, 0.5)), 0.16, 0.3)


def ghost_double():
    """The player's shot answered a moment later by a hollower twin."""
    near = s.pluck(300, 0.14, brightness=0.3) * 0.5
    far = s.at(
        s.mix(
            (s.tone(300, 0.26, 8, SPIRIT), 0.8),
            (s.sweep_filter(s.noise(0.24), 1100, 500, q=2.0), 0.4),
        ),
        0.1,
    )
    return s.room(s.mix((near, 0.6), (far, 0.9)), 0.18, 0.34)


def ghost_moan():
    """A faint falling moan behind the arrow: the archer, not the bow."""
    moan = s.chirp(0.4, 520, 300, shape="exp", wave="sine") * s.env_ad(int(SR * 0.4), 0.05, 4)
    air = s.sweep_filter(s.noise(0.34), 1600, 600, q=1.8) * 0.4
    return s.room(s.mix((moan, 0.7), (air, 0.6)), 0.2, 0.36)


# --- Time Dilation: the field opens and everything in it crawls ---
def time_warp():
    """A note bent down and smeared: the sound of slowing itself."""
    down = s.chirp(0.7, 900, 180, shape="exp", wave="sine") * s.env_ad(int(SR * 0.7), 0.02, 2.5)
    shimmer = s.sparkle(0.6, [1480, 1174, 988], spacing=0.1, decay=6) * 0.4
    return s.room(s.mix((down, 0.9), (shimmer, 0.5)), 0.22, 0.4)


def time_tick():
    """A clock's tick stretching out and dying: three beats, each slower."""
    out = np.zeros(int(SR * 0.9))
    for i, (delay, freq) in enumerate([(0.0, 1400), (0.2, 1100), (0.48, 820)]):
        tick = s.bandpass(s.noise(0.05), freq * 0.6, freq * 2.2)
        tick = tick * s.env_ad(int(SR * 0.05), 0.001, 22) * (0.9 - i * 0.2)
        d = int(SR * delay)
        out[d:d + len(tick)] += tick[:len(out) - d]
    hum = s.tone(140, 0.85, 3, ((1, 1.0), (2, 0.3))) * 0.3
    return s.room(s.mix((out, 1.0), (hum, 0.6)), 0.2, 0.34)


def time_hum():
    """A low bowl of sound settling over the ground, with a glass edge."""
    hum = s.tone(165, 0.8, 2.5, ((1, 1.0), (1.5, 0.4), (2.0, 0.2))) * 0.8
    wobble = 1 + 0.2 * np.sin(np.linspace(0, 2 * np.pi * 3.5, len(hum)))
    glass = s.at(s.tone(1319, 0.5, 7, s.GLASS), 0.06) * 0.3
    return s.room(s.mix((hum * wobble, 0.9), (glass, 0.5)), 0.25, 0.42)


# --- Prismatic Burst: the orb shatters into coloured shards ---
def prism_shatter():
    """Glass breaking into a rising scatter of shards."""
    crack = s.bandpass(s.noise(0.07), 2000, 9000) * s.env_ad(int(SR * 0.07), 0.0008, 24)
    shards = s.at(s.sparkle(0.45, [1568, 1976, 2349, 1319, 2637], spacing=0.028, decay=14), 0.03)
    return s.room(s.mix((crack, 0.95), (shards, 0.8)), 0.12, 0.26)


def prism_chord():
    """The shards as a bright chord thrown outward all at once."""
    chord = s.mix(
        (s.tone(1047, 0.42, 9, s.GLASS), 0.8),
        (s.tone(1319, 0.42, 9, s.GLASS), 0.7),
        (s.tone(1568, 0.42, 9, s.GLASS), 0.6),
    )
    pop = s.lowpass(s.noise(0.05), 2200) * s.env_ad(int(SR * 0.05), 0.001, 20)
    return s.room(s.mix((chord, 0.9), (pop, 0.7)), 0.14, 0.3)


def prism_ring():
    """A single struck crystal, then its pieces ringing away."""
    strike = s.tone(2093, 0.3, 10, s.GLASS) * 0.8
    away = s.at(s.sparkle(0.5, [2637, 2093, 1760, 1568], spacing=0.055, decay=11), 0.08) * 0.6
    return s.room(s.mix((strike, 0.9), (away, 0.8)), 0.16, 0.32)


# --- Guard Break: the slam throws them back ---
def guard_crack():
    """Steel plate splitting: a hard crack with a low shove behind it."""
    crack = s.bandpass(s.noise(0.09), 700, 5200) * s.env_ad(int(SR * 0.09), 0.0008, 20)
    shove = s.lowpass(s.noise(0.3), 220) * s.env_ad(int(SR * 0.3), 0.004, 5)
    ring = s.at(s.tone(330, 0.3, 9, METAL), 0.02) * 0.4
    return s.room(s.mix((crack, 1.0), (shove, 0.8), (ring, 0.45)), 0.1, 0.2)


def guard_boom():
    """Heavier and duller: the push matters more than the break."""
    boom = s.lowpass(s.noise(0.4), 170) * s.env_ad(int(SR * 0.4), 0.006, 4)
    thud = s.tone(80, 0.34, 5, ((1, 1.0), (2, 0.4))) * 0.7
    grit = s.at(s.bandpass(s.noise(0.2), 500, 2600), 0.03) * 0.4
    return s.room(s.mix((boom, 0.95), (thud, 0.8), (grit, 0.5)), 0.13, 0.24)


def guard_clang():
    """A shield's clang, bent downward as it is knocked away."""
    clang = s.tone(294, 0.45, 7, METAL) * 0.85
    bend = s.chirp(0.3, 520, 260, shape="exp", wave="saw")
    bend = bend * s.env_ad(int(SR * 0.3), 0.003, 7) * 0.4
    hit = s.lowpass(s.noise(0.07), 1200) * s.env_ad(int(SR * 0.07), 0.001, 18)
    return s.room(s.mix((clang, 0.9), (bend, 0.5), (hit, 0.8)), 0.12, 0.24)


# --- Bull Rush: the charge itself ---
def rush_charge():
    """A rising rush with earth torn up under it."""
    rise = s.sweep_filter(s.noise(0.42), 300, 1800, q=1.4) * s.env_ad(int(SR * 0.42), 0.03, 3.5)
    drag = s.lowpass(s.noise(0.44), 300) * np.linspace(0.3, 1.0, int(SR * 0.44)) * 0.7
    return s.room(s.mix((rise, 0.95), (drag, 0.7)), 0.12, 0.22)


def rush_horn():
    """A short low horn under the charge: the Warden announcing it."""
    horn = s.tone(110, 0.4, 4, ((1, 1.0), (2, 0.5), (3, 0.25), (4, 0.12))) * 0.8
    body = s.whoosh(0.34, 400, 1500, q=1.3, attack=0.02, decay=4) * 0.6
    return s.room(s.mix((horn, 0.9), (body, 0.8)), 0.14, 0.26)


def rush_stamp():
    """Two heavy stamps and the run between them."""
    out = np.zeros(int(SR * 0.5))
    for delay in (0.0, 0.17):
        stamp = s.lowpass(s.noise(0.12), 240) * s.env_ad(int(SR * 0.12), 0.002, 9)
        d = int(SR * delay)
        out[d:d + len(stamp)] += stamp[:len(out) - d]
    run = s.sweep_filter(s.noise(0.46), 500, 1700, q=1.5) * 0.45
    return s.room(s.mix((out, 1.0), (run, 0.7)), 0.11, 0.22)


# --- Blood Pact: it engages as he drops under half health ---
def pact_heart():
    """Two heartbeats, low and close: the pact taking hold."""
    out = np.zeros(int(SR * 0.8))
    for delay, gain in ((0.0, 1.0), (0.26, 0.75)):
        beat = s.tone(55, 0.22, 6, ((1, 1.0), (2, 0.3))) * gain
        thud = s.lowpass(s.noise(0.1), 150) * s.env_ad(int(SR * 0.1), 0.004, 9) * gain
        piece = s.mix((beat, 0.9), (thud, 0.7))
        d = int(SR * delay)
        out[d:d + len(piece)] += piece[:len(out) - d]
    return s.room(out, 0.14, 0.24)


def pact_whisper():
    """A dark rising whisper, as if something agreed to it."""
    breath = s.sweep_filter(s.noise(0.6), 200, 1400, q=2.2) * s.env_ad(int(SR * 0.6), 0.08, 3)
    low = s.chirp(0.5, 120, 190, shape="exp", wave="sine")
    low = low * s.env_ad(int(SR * 0.5), 0.05, 3) * 0.6
    return s.room(s.mix((breath, 0.8), (low, 0.8)), 0.2, 0.36)


def pact_toll():
    """One dark bell struck once: short, and impossible to miss."""
    bell = s.tone(147, 0.7, 4, ((1, 1.0), (2.4, 0.35), (3.8, 0.15))) * 0.9
    edge = s.lowpass(s.noise(0.08), 700) * s.env_ad(int(SR * 0.08), 0.002, 14)
    return s.room(s.mix((bell, 0.95), (edge, 0.6)), 0.18, 0.32)


# --- Vengeful Spirit: a sword rises out of the body ---
def spirit_rise():
    """A blade drawn upward out of the ground, ringing as it comes."""
    draw = s.chirp(0.5, 300, 1100, shape="exp", wave="sine") * s.env_ad(int(SR * 0.5), 0.04, 4)
    ring = s.at(s.tone(880, 0.5, 7, SPIRIT), 0.22) * 0.5
    air = s.sweep_filter(s.noise(0.4), 600, 2200, q=2.0) * 0.35
    return s.room(s.mix((draw, 0.85), (ring, 0.7), (air, 0.5)), 0.2, 0.38)


def spirit_choir():
    """A hollow two-note voice: the spirit, not the steel."""
    a = s.tone(440, 0.6, 5, SPIRIT) * 0.7
    b = s.at(s.tone(659, 0.6, 5, SPIRIT), 0.14) * 0.6
    breath = s.sweep_filter(s.noise(0.5), 500, 1600, q=2.4) * 0.3
    return s.room(s.mix((a, 0.8), (b, 0.8), (breath, 0.5)), 0.26, 0.44)


def spirit_unsheath():
    """Steel on steel, pitched up and left hanging: cold and quick."""
    scrape = s.sweep_filter(s.noise(0.26), 1200, 4200, q=2.6) * s.env_ad(int(SR * 0.26), 0.01, 6)
    ring = s.at(s.tone(1175, 0.45, 8, METAL), 0.1) * 0.45
    return s.room(s.mix((scrape, 0.9), (ring, 0.6)), 0.22, 0.4)


DESIGNED = {
    "fx_windrunner": [
        (wind_rise, "Three rising airy notes: the third stack landing."),
        (wind_gust, "One clean gust past the ear, bright at its top."),
        (wind_chime, "A light double chime, like a runner's bell."),
    ],
    "fx_thornfall": [
        (thorn_plant, "Three wooden thunks into earth, then the shafts fan out."),
        (thorn_burst, "One sharp woody crack and a spray of shafts at once."),
        (thorn_growl, "A low rumble under the shafts: the ground gave them up."),
    ],
    "fx_headhunter": [
        (head_thunk, "A dead-centre thunk with a bright ring off the head."),
        (head_snap, "A tight metal snap, up a fifth: a called shot landing."),
        (head_bell, "Hit plus one clear bell, unmistakable in a crowd."),
    ],
    "fx_ghost_quiver": [
        (ghost_breath, "A breathy release with no wood in it: air, not string."),
        (ghost_double, "Your shot, answered a moment later by a hollow twin."),
        (ghost_moan, "A faint falling moan behind the arrow."),
    ],
    "fx_time_dilation": [
        (time_warp, "A note bent down and smeared: the slowing itself."),
        (time_tick, "A clock ticking three times, each beat slower."),
        (time_hum, "A low bowl of sound settling, with a glass edge."),
    ],
    "fx_prismatic_burst": [
        (prism_shatter, "Glass breaking into a rising scatter of shards."),
        (prism_chord, "The shards as one bright chord thrown outward."),
        (prism_ring, "A struck crystal, then its pieces ringing away."),
    ],
    "fx_guard_break": [
        (guard_crack, "Steel plate splitting, with a low shove behind it."),
        (guard_boom, "Heavier and duller: the push over the break."),
        (guard_clang, "A shield's clang, bent down as it is knocked away."),
    ],
    "fx_bull_rush": [
        (rush_charge, "A rising rush with earth torn up under it."),
        (rush_horn, "A short low horn under the charge."),
        (rush_stamp, "Two heavy stamps and the run between them."),
    ],
    "fx_blood_pact": [
        (pact_heart, "Two low heartbeats, close together."),
        (pact_whisper, "A dark rising whisper, as if something agreed."),
        (pact_toll, "One dark bell, struck once."),
    ],
    "fx_vengeful_spirit": [
        (spirit_rise, "A blade drawn up out of the ground, ringing."),
        (spirit_choir, "A hollow two-note voice: the spirit, not the steel."),
        (spirit_unsheath, "Steel on steel, pitched up and left hanging."),
    ],
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
