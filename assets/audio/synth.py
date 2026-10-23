"""Procedural sound effects for Arrow Legends: bright, punchy, cartoony,
lightly after Archero 2. Every sound is built from scratch here (tones,
noise, filters, envelopes), so all of it is ours to ship.

Usage: synth.py <out_dir> [round ...]   (rounds 1 2 by default; later rounds alone)
Writes <out_dir>/<sound>_<variant>.wav (44.1 kHz, 16-bit mono) and a
manifest.json describing each variant.
"""
import json
import os
import sys

import numpy as np
from scipy import signal
from scipy.io import wavfile

SR = 44100
rng = np.random.default_rng(20261023)


# ---------- building blocks ----------

def t_of(seconds):
    return np.arange(int(SR * seconds)) / SR


def env_ad(n, attack, decay_curve=6.0):
    """Fast attack, exponential decay over the rest of n samples."""
    a = max(1, int(SR * attack))
    e = np.ones(n)
    e[:a] = np.linspace(0, 1, a)
    rest = n - a
    if rest > 0:
        e[a:] = np.exp(-decay_curve * np.linspace(0, 1, rest))
    return e


def noise(seconds):
    return rng.standard_normal(int(SR * seconds))


def bandpass(x, lo, hi, order=2):
    sos = signal.butter(order, [lo, hi], btype="band", fs=SR, output="sos")
    return signal.sosfilt(sos, x)


def lowpass(x, cutoff, order=2):
    sos = signal.butter(order, cutoff, btype="low", fs=SR, output="sos")
    return signal.sosfilt(sos, x)


def highpass(x, cutoff, order=2):
    sos = signal.butter(order, cutoff, btype="high", fs=SR, output="sos")
    return signal.sosfilt(sos, x)


def sweep_filter(x, f0, f1, q=2.0, kind="band"):
    """A filter whose centre glides from f0 to f1 across x (block-wise)."""
    out = np.zeros_like(x)
    block = 256
    zi = None
    n_blocks = int(np.ceil(len(x) / block))
    for b in range(n_blocks):
        frac = b / max(1, n_blocks - 1)
        f = f0 * (f1 / f0) ** frac
        bw = f / q
        lo, hi = max(30, f - bw / 2), min(SR / 2 - 100, f + bw / 2)
        sos = signal.butter(2, [lo, hi], btype="band", fs=SR, output="sos") if kind == "band" else \
            signal.butter(2, min(f, SR / 2 - 100), btype="low", fs=SR, output="sos")
        seg = x[b * block:(b + 1) * block]
        if zi is None:
            zi = signal.sosfilt_zi(sos) * 0
        y, zi = signal.sosfilt(sos, seg, zi=zi)
        out[b * block:b * block + len(seg)] = y
    return out


def chirp(seconds, f0, f1, shape="exp", wave="sine"):
    t = t_of(seconds)
    if shape == "exp":
        k = np.log(f1 / f0) / seconds
        phase = 2 * np.pi * f0 * (np.exp(k * t) - 1) / k
    else:
        phase = 2 * np.pi * (f0 * t + (f1 - f0) * t * t / (2 * seconds))
    if wave == "sine":
        return np.sin(phase)
    if wave == "tri":
        return 2 / np.pi * np.arcsin(np.sin(phase))
    if wave == "square":
        return np.tanh(4 * np.sin(phase))
    return np.sin(phase)


def pluck(freq, seconds, brightness=0.5, bend=0.0):
    """Karplus-Strong plucked string; `bend` drops pitch by that ratio."""
    n = int(SR * seconds)
    out = np.zeros(n)
    period = SR / freq
    buf_len = int(period)
    buf = rng.uniform(-1, 1, buf_len)
    buf = lowpass(buf, 2000 + 8000 * brightness)
    idx = 0
    damp = 0.996
    for i in range(n):
        out[i] = buf[idx]
        nxt = (idx + 1) % buf_len
        buf[idx] = damp * 0.5 * (buf[idx] + buf[nxt])
        idx = nxt
    if bend:
        # Resample to bend pitch downward over time.
        warp = np.cumsum(1 - bend * np.linspace(0, 1, n))
        warp = warp / warp[-1] * (n - 1)
        out = np.interp(warp, np.arange(n), out)
    return out


def room(x, size=0.12, mix=0.18):
    """A small, bright room: convolve with a short decaying noise burst."""
    ir_n = int(SR * size)
    ir = rng.standard_normal(ir_n) * np.exp(-np.linspace(0, 7, ir_n))
    ir = highpass(ir, 400)
    ir /= np.sqrt(np.sum(ir ** 2)) + 1e-9
    wet = signal.fftconvolve(x, ir)
    dry = np.concatenate([x, np.zeros(len(wet) - len(x))])
    return (1 - mix) * dry + mix * wet * 0.6


def mix(*parts):
    n = max(len(p) for p, _ in parts)
    out = np.zeros(n)
    for p, gain in parts:
        out[: len(p)] += p * gain
    return out


def at(x, delay):
    return np.concatenate([np.zeros(int(SR * delay)), x])


def sparkle(seconds, notes, spacing=0.035, decay=10):
    """Tiny bell pings rising through `notes` (Hz)."""
    parts = []
    for i, f in enumerate(notes):
        tt = t_of(seconds)
        bell = (np.sin(2 * np.pi * f * tt) + 0.4 * np.sin(2 * np.pi * f * 2.76 * tt)) * np.exp(-decay * tt)
        parts.append((at(bell, i * spacing), 1.0 / len(notes) ** 0.5))
    return mix(*parts)


def finish(x, peak_db=-1.0, fade_ms=4, target_rms=None):
    x = x - np.mean(x)
    f = int(SR * fade_ms / 1000)
    x[-f:] *= np.linspace(1, 0, f)
    x[:2] *= np.linspace(0, 1, 2)
    # Trim trailing near-silence.
    above = np.where(np.abs(x) > 1e-3 * np.max(np.abs(x)))[0]
    if len(above):
        x = x[: above[-1] + int(SR * 0.01)]
    if target_rms:
        x *= target_rms / (np.sqrt(np.mean(x ** 2)) + 1e-9)
    peak = np.max(np.abs(x)) + 1e-9
    limit = 10 ** (peak_db / 20)
    if peak > limit:
        x *= limit / peak
    return x


# ---------- arrow fire: short, light, heard ~once a second ----------

def arrow_a():  # Classic twang + whoosh
    tw = pluck(196, 0.22, brightness=0.6, bend=0.25) * env_ad(int(SR * 0.22), 0.001, 7)
    wh = sweep_filter(noise(0.16), 1800, 6500, q=1.5) * env_ad(int(SR * 0.16), 0.02, 5)
    return room(mix((tw, 0.9), (at(wh, 0.01), 0.55)), 0.08, 0.12)


def arrow_b():  # Bright snap, short tail
    tw = pluck(330, 0.12, brightness=0.9, bend=0.15) * env_ad(int(SR * 0.12), 0.0005, 9)
    click = highpass(noise(0.012), 3000) * env_ad(int(SR * 0.012), 0.0005, 8)
    wh = sweep_filter(noise(0.1), 3000, 8000, q=2) * env_ad(int(SR * 0.1), 0.01, 6)
    return mix((tw, 0.8), (click, 0.4), (at(wh, 0.008), 0.45))


def arrow_c():  # Cartoony "thwip"
    zip_ = chirp(0.09, 1400, 380) * env_ad(int(SR * 0.09), 0.002, 5)
    air = bandpass(noise(0.09), 2500, 7000) * env_ad(int(SR * 0.09), 0.005, 6)
    return mix((zip_, 0.7), (air, 0.35))


def arrow_d():  # Airy whoosh with a soft click
    click = lowpass(noise(0.008), 4000) * env_ad(int(SR * 0.008), 0.0005, 6)
    wh = sweep_filter(noise(0.2), 1200, 5000, q=1.2) * env_ad(int(SR * 0.2), 0.03, 4)
    return room(mix((click, 0.6), (wh, 0.8)), 0.1, 0.15)


def arrow_e():  # Heavier: low thunk twang + whoosh
    tw = pluck(130, 0.25, brightness=0.4, bend=0.3) * env_ad(int(SR * 0.25), 0.001, 6)
    thunk = chirp(0.06, 160, 70) * env_ad(int(SR * 0.06), 0.001, 6)
    wh = sweep_filter(noise(0.15), 1500, 5000, q=1.5) * env_ad(int(SR * 0.15), 0.015, 5)
    return room(mix((tw, 0.8), (thunk, 0.5), (at(wh, 0.012), 0.5)), 0.08, 0.12)


# ---------- enemy hit: soft jelly impact ----------

def hit_a():  # Wet squish
    body = lowpass(noise(0.12), 900) * env_ad(int(SR * 0.12), 0.001, 7)
    blip = chirp(0.07, 420, 140) * env_ad(int(SR * 0.07), 0.001, 6)
    return mix((body, 0.8), (blip, 0.6))


def hit_b():  # Punchy "thock"
    thump = chirp(0.09, 220, 90) * env_ad(int(SR * 0.09), 0.0005, 7)
    click = highpass(noise(0.01), 2500) * env_ad(int(SR * 0.01), 0.0005, 8)
    return mix((thump, 1.0), (click, 0.5))


def hit_c():  # Cartoony pop-boing
    pop = chirp(0.06, 300, 900) * env_ad(int(SR * 0.06), 0.001, 5)
    wob = np.sin(2 * np.pi * 520 * t_of(0.12) + 3 * np.sin(2 * np.pi * 30 * t_of(0.12))) * env_ad(int(SR * 0.12), 0.002, 6)
    return mix((pop, 0.6), (at(wob, 0.02), 0.45))


def hit_d():  # Crunchy impact
    crunch = bandpass(noise(0.08), 1500, 6000) * env_ad(int(SR * 0.08), 0.0005, 8)
    thump = chirp(0.08, 180, 70) * env_ad(int(SR * 0.08), 0.0005, 7)
    return mix((np.tanh(3 * crunch), 0.5), (thump, 0.8))


def hit_e():  # Soft jelly bloop
    tt = t_of(0.15)
    f = 260 * (1 + 0.25 * np.exp(-25 * tt) * np.sin(2 * np.pi * 18 * tt))
    bloop = np.sin(2 * np.pi * np.cumsum(f) / SR) * env_ad(len(tt), 0.003, 6)
    squish = lowpass(noise(0.05), 1200) * env_ad(int(SR * 0.05), 0.001, 6)
    return mix((bloop, 0.9), (squish, 0.35))


# ---------- enemy death: a rewarding poof ----------

def death_a():  # Soft poof + rising sparkle
    poof = sweep_filter(noise(0.35), 2500, 400, q=1.0) * env_ad(int(SR * 0.35), 0.01, 5)
    sp = sparkle(0.3, [1568, 2093, 2637, 3136])
    return room(mix((poof, 0.9), (at(sp, 0.05), 0.35)), 0.15, 0.2)


def death_b():  # Pop! then a falling tone
    pop = chirp(0.03, 600, 1800) * env_ad(int(SR * 0.03), 0.0005, 5)
    burst = bandpass(noise(0.06), 800, 4000) * env_ad(int(SR * 0.06), 0.0005, 7)
    fall = chirp(0.22, 900, 220, wave="tri") * env_ad(int(SR * 0.22), 0.005, 4)
    return room(mix((pop, 0.6), (burst, 0.5), (at(fall, 0.03), 0.55)), 0.12, 0.15)


def death_c():  # Comic "bwoop" down + poof
    bwoop = chirp(0.28, 700, 120, wave="tri") * env_ad(int(SR * 0.28), 0.005, 3.5)
    poof = lowpass(noise(0.25), 1500) * env_ad(int(SR * 0.25), 0.02, 5)
    return room(mix((bwoop, 0.8), (at(poof, 0.12), 0.5)), 0.12, 0.15)


def death_d():  # Bright shatter-poof with bells
    shards = highpass(noise(0.12), 3500) * env_ad(int(SR * 0.12), 0.0005, 6)
    poof = sweep_filter(noise(0.3), 2000, 500, q=1.0) * env_ad(int(SR * 0.3), 0.01, 5)
    bells = sparkle(0.45, [2093, 2637, 3136, 4186], spacing=0.05, decay=7)
    return room(mix((shards, 0.4), (poof, 0.7), (at(bells, 0.03), 0.45)), 0.2, 0.22)


def death_e():  # Deep slime splat-poof
    splat = lowpass(noise(0.2), 700) * env_ad(int(SR * 0.2), 0.002, 5)
    drop = chirp(0.2, 260, 70) * env_ad(int(SR * 0.2), 0.002, 4)
    sp = sparkle(0.25, [1047, 1319, 1568], spacing=0.04)
    return room(mix((splat, 0.9), (drop, 0.6), (at(sp, 0.08), 0.25)), 0.14, 0.18)


# ---------- round 2 helpers ----------

def tone(freq, seconds, decay=6.0, partials=((1, 1.0),), attack=0.002):
    """A struck tone: sine partials at freq * ratio, decaying together."""
    tt = t_of(seconds)
    x = sum(g * np.sin(2 * np.pi * freq * r * tt) for r, g in partials)
    return x * env_ad(len(tt), attack, decay)


BELL = ((1, 1.0), (2.76, 0.4), (5.4, 0.15))
GLASS = ((1, 1.0), (3.0, 0.25), (6.2, 0.08))
WARM = ((1, 1.0), (2, 0.35), (3, 0.12))


def arp(notes, spacing, seconds, partials=BELL, decay=6.0):
    """Notes struck one after another, each ringing on."""
    return mix(*[(at(tone(f, seconds, decay, partials), i * spacing), 1.0) for i, f in enumerate(notes)])


def whoosh(seconds, f0, f1, q=1.3, attack=0.02, decay=4.0):
    return sweep_filter(noise(seconds), f0, f1, q=q) * env_ad(int(SR * seconds), attack, decay)


# ---------- staff cast: the Arcanist's bolt, every 1.4 s ----------

def cast_a():  # Shimmering rising zap
    zap = chirp(0.18, 500, 1800, wave="tri") * env_ad(int(SR * 0.18), 0.003, 4)
    shim = sparkle(0.25, [2093, 2637, 3136], spacing=0.025, decay=12)
    return room(mix((zap, 0.6), (whoosh(0.2, 1500, 6000), 0.5), (shim, 0.3)), 0.12, 0.18)


def cast_b():  # Soft magic fwoom
    body = sweep_filter(noise(0.3), 300, 2200, q=1.0) * env_ad(int(SR * 0.3), 0.03, 4)
    hum = chirp(0.3, 180, 360) * env_ad(int(SR * 0.3), 0.02, 4)
    return room(mix((body, 0.9), (hum, 0.5)), 0.15, 0.2)


def cast_c():  # Crystal ping, then a whoosh
    ping = tone(1568, 0.35, 7, GLASS)
    return room(mix((ping, 0.6), (at(whoosh(0.18, 2000, 7000, q=1.6), 0.02), 0.6)), 0.14, 0.2)


def cast_d():  # Electric crackle bolt
    n = int(SR * 0.16)
    buzz = np.sign(np.sin(2 * np.pi * 95 * t_of(0.16))) * env_ad(n, 0.002, 5)
    crack = highpass(noise(0.16), 2500) * (rng.random(n) > 0.85) * env_ad(n, 0.001, 4)
    zap = chirp(0.12, 2400, 600) * env_ad(int(SR * 0.12), 0.001, 5)
    return mix((lowpass(buzz, 1800), 0.35), (crack, 0.6), (zap, 0.5))


# ---------- player hurt: has to cut through a fight ----------

def hurt_a():  # Dull thud with a low tone
    thud = chirp(0.14, 160, 55) * env_ad(int(SR * 0.14), 0.001, 6)
    body = lowpass(noise(0.1), 700) * env_ad(int(SR * 0.1), 0.001, 7)
    return mix((thud, 1.0), (body, 0.5))


def hurt_b():  # Sharp crack, falling tone
    crack = highpass(noise(0.03), 2000) * env_ad(int(SR * 0.03), 0.0005, 7)
    fall = chirp(0.22, 700, 180, wave="square") * env_ad(int(SR * 0.22), 0.002, 5)
    return mix((crack, 0.7), (lowpass(fall, 2500), 0.5))


def hurt_c():  # Muffled punch that rings
    punch = chirp(0.08, 200, 80) * env_ad(int(SR * 0.08), 0.0005, 6)
    ring = tone(440, 0.3, 8, ((1, 1.0), (1.5, 0.5)))
    return mix((punch, 1.0), (ring, 0.3))


def hurt_d():  # Cartoony bonk
    bonk = tone(620, 0.18, 9, ((1, 1.0), (2.3, 0.4)))
    knock = lowpass(noise(0.02), 3000) * env_ad(int(SR * 0.02), 0.0005, 6)
    return mix((bonk, 0.8), (knock, 0.6))


# ---------- dash: every 4 s at most ----------

def dash_a():  # Quick whoosh
    return whoosh(0.22, 900, 4500, q=1.2, attack=0.01, decay=5)


def dash_b():  # Whoosh rising in pitch
    return mix((whoosh(0.25, 600, 6000, q=2.0, attack=0.02, decay=4), 0.9),
               (chirp(0.2, 300, 900) * env_ad(int(SR * 0.2), 0.02, 5), 0.25))


def dash_c():  # Airy swish with a sparkle
    return room(mix((whoosh(0.2, 2000, 7000, q=1.5, attack=0.005, decay=5), 0.8),
                    (at(sparkle(0.2, [2637, 3520], spacing=0.04, decay=14), 0.06), 0.25)), 0.1, 0.15)


def dash_d():  # Low, heavy woosh
    return mix((whoosh(0.3, 250, 1600, q=1.0, attack=0.02, decay=4), 1.0),
               (chirp(0.25, 90, 60) * env_ad(int(SR * 0.25), 0.02, 4), 0.4))


# ---------- XP crystal: many at once, so tiny ----------

def xp_a():  # Tiny high ping
    return tone(2637, 0.12, 14, GLASS)


def xp_b():  # Glassy tick
    return mix((tone(3520, 0.06, 20, GLASS), 0.8), (highpass(noise(0.006), 5000), 0.2))


def xp_c():  # Two-note blip up
    return arp([1760, 2349], 0.04, 0.09, GLASS, 14)


def xp_d():  # Soft chime
    return tone(1976, 0.2, 9, BELL)


# ---------- heart: heals 20% ----------

def heart_a():  # Warm two notes up
    return room(arp([659, 988], 0.08, 0.35, WARM, 6), 0.15, 0.2)


def heart_b():  # Bubbly healing shimmer
    bubbles = mix(*[(at(chirp(0.05, f, f * 1.8) * env_ad(int(SR * 0.05), 0.003, 5), i * 0.035), 0.5)
                    for i, f in enumerate([500, 650, 800, 1000, 1250])])
    return room(mix((bubbles, 0.8), (at(sparkle(0.3, [1568, 2093]), 0.12), 0.3)), 0.15, 0.2)


def heart_c():  # Bell chord
    return room(mix((tone(784, 0.5, 5, BELL), 0.6), (tone(988, 0.5, 5, BELL), 0.5),
                    (tone(1175, 0.5, 5, BELL), 0.4)), 0.2, 0.22)


def heart_d():  # Soft ding and sparkle
    return room(mix((tone(1319, 0.4, 6, WARM), 0.7), (at(sparkle(0.3, [2093, 2637, 3136]), 0.05), 0.3)), 0.15, 0.2)


# ---------- level up: the draft is about to open ----------

def level_a():  # Rising arpeggio
    return room(arp([523, 659, 784, 1047], 0.07, 0.5, BELL, 5), 0.2, 0.25)


def level_b():  # Little fanfare
    return room(mix((arp([523, 784], 0.1, 0.25, WARM, 7), 0.7), (at(tone(1047, 0.6, 3.5, WARM), 0.2), 0.7)), 0.2, 0.25)


def level_c():  # Shimmer sweeping up
    sweep = sweep_filter(noise(0.6), 800, 8000, q=4) * env_ad(int(SR * 0.6), 0.2, 3)
    return room(mix((sweep, 0.6), (at(sparkle(0.4, [1568, 2093, 2637, 3136, 4186], spacing=0.05), 0.25), 0.5)), 0.25, 0.3)


def level_d():  # Magic chord swelling in
    chord = sum(tone(f, 0.8, 3, BELL, attack=0.12) for f in [523, 659, 784, 1047]) / 2
    return room(chord, 0.3, 0.3)


# ---------- card pick ----------

def card_a():  # Flick and a ding
    flick = bandpass(noise(0.03), 1500, 6000) * env_ad(int(SR * 0.03), 0.001, 7)
    return mix((flick, 0.6), (at(tone(1568, 0.35, 7, BELL), 0.02), 0.6))


def card_b():  # Whoosh into a thump
    return mix((whoosh(0.15, 1200, 4000, q=1.5, attack=0.02, decay=4), 0.6),
               (at(chirp(0.08, 200, 90) * env_ad(int(SR * 0.08), 0.001, 6), 0.12), 0.8))


def card_c():  # Bright chime
    return room(arp([1319, 1976], 0.05, 0.4, GLASS, 6), 0.15, 0.2)


def card_d():  # Paper snap
    snap = highpass(noise(0.025), 1800) * env_ad(int(SR * 0.025), 0.0005, 9)
    return mix((np.tanh(2 * snap), 0.8), (at(tone(880, 0.12, 12, WARM), 0.005), 0.3))


# ---------- exit gate opens ----------

def gate_a():  # Magic swell
    swell = sweep_filter(noise(0.9), 400, 3000, q=2) * env_ad(int(SR * 0.9), 0.3, 3)
    return room(mix((swell, 0.6), (tone(392, 0.9, 3, BELL, attack=0.25), 0.4),
                    (tone(587, 0.9, 3, BELL, attack=0.3), 0.3)), 0.3, 0.3)


def gate_b():  # Stone rumble then a chime
    rumble = lowpass(noise(0.5), 180) * env_ad(int(SR * 0.5), 0.05, 4)
    return room(mix((rumble, 1.0), (at(arp([784, 1175], 0.08, 0.5, BELL, 5), 0.3), 0.5)), 0.25, 0.25)


def gate_c():  # Whoosh open and a bell
    return room(mix((whoosh(0.5, 300, 4000, q=1.2, attack=0.15, decay=3), 0.7),
                    (at(tone(1047, 0.7, 4, BELL), 0.25), 0.5)), 0.3, 0.3)


def gate_d():  # Airy chord
    chord = sum(tone(f, 1.0, 2.5, WARM, attack=0.2) for f in [392, 494, 587, 784]) / 2
    air = sweep_filter(noise(1.0), 2000, 6000, q=3) * env_ad(int(SR * 1.0), 0.3, 3)
    return room(mix((chord, 0.7), (air, 0.25)), 0.3, 0.3)


ROUND2 = {
    "staff_cast": [
        ("a", cast_a, "Shimmering zap rising, with a whoosh and a sparkle."),
        ("b", cast_b, "Soft magic \"fwoom\": warm and low."),
        ("c", cast_c, "A crystal ping, then a bright whoosh."),
        ("d", cast_d, "Electric crackle: a buzzing, snapping bolt."),
    ],
    "player_hurt": [
        ("a", hurt_a, "Dull thud with a low tone."),
        ("b", hurt_b, "Sharp crack and a falling tone; the most alarming."),
        ("c", hurt_c, "Muffled punch that rings a little."),
        ("d", hurt_d, "Cartoony \"bonk\"."),
    ],
    "dash": [
        ("a", dash_a, "A quick whoosh."),
        ("b", dash_b, "A whoosh that rises in pitch."),
        ("c", dash_c, "Airy swish with a sparkle."),
        ("d", dash_d, "Low, heavy woosh."),
    ],
    "xp_pickup": [
        ("a", xp_a, "Tiny high ping."),
        ("b", xp_b, "Glassy tick; the shortest."),
        ("c", xp_c, "Two-note blip up."),
        ("d", xp_d, "Soft chime."),
    ],
    "heart_pickup": [
        ("a", heart_a, "Two warm notes going up."),
        ("b", heart_b, "Bubbly healing shimmer."),
        ("c", heart_c, "A bell chord."),
        ("d", heart_d, "A soft ding and a sparkle."),
    ],
    "level_up": [
        ("a", level_a, "Rising four-note arpeggio."),
        ("b", level_b, "A little fanfare."),
        ("c", level_c, "A shimmer sweeping up into sparkles."),
        ("d", level_d, "A magic chord swelling in."),
    ],
    "card_pick": [
        ("a", card_a, "A card flick and a ding."),
        ("b", card_b, "A whoosh landing in a thump."),
        ("c", card_c, "A bright two-note chime."),
        ("d", card_d, "A crisp paper snap."),
    ],
    "gate_open": [
        ("a", gate_a, "A magic swell with two bells."),
        ("b", gate_b, "Stone rumble, then a chime."),
        ("c", gate_c, "A whoosh opening into a bell."),
        ("d", gate_d, "An airy chord."),
    ],
}

LEVEL2 = {
    "staff_cast": 0.12, "player_hurt": 0.18, "dash": 0.11, "xp_pickup": 0.07,
    "heart_pickup": 0.12, "level_up": 0.13, "card_pick": 0.12, "gate_open": 0.12,
}


ROUND1 = {
    "arrow_fire": [
        ("a", arrow_a, "Classic bow twang with a whoosh behind it."),
        ("b", arrow_b, "Bright, snappy twang; the shortest and lightest."),
        ("c", arrow_c, "Cartoony \"thwip\": a quick falling zip, no string."),
        ("d", arrow_d, "Mostly air: a soft click and a whoosh."),
        ("e", arrow_e, "Heavier: a low twang with a thunk."),
    ],
    "enemy_hit": [
        ("a", hit_a, "Wet squish, suits the slimes."),
        ("b", hit_b, "Punchy \"thock\": a tight thump and a click."),
        ("c", hit_c, "Cartoony pop with a little wobble."),
        ("d", hit_d, "Crunchy impact with weight."),
        ("e", hit_e, "Soft jelly bloop that wobbles in pitch."),
    ],
    "enemy_death": [
        ("a", death_a, "Soft poof with a rising sparkle."),
        ("b", death_b, "Pop! then a falling tone."),
        ("c", death_c, "Comic \"bwoop\" falling, then a poof."),
        ("d", death_d, "Bright shatter-poof with bells."),
        ("e", death_e, "Deep slime splat with a small sparkle."),
    ],
}

# Each sound family is levelled to the same loudness, so variants compare
# fairly; the families sit at different levels the way they would in game.
LEVEL = {"arrow_fire": 0.10, "enemy_hit": 0.16, "enemy_death": 0.14}

# ---------- round 3: soft, musical and clean, after the owner's round 2
# picks (a warm thud, a soft chime, a ding and sparkle, a rising
# arpeggio). Everything unpicked is redone, and the enemy death again
# around the pick, C. ----------

# arrow fire

def r3_arrow_a():  # Soft "fft": an air puff over a low pluck
    puff = bandpass(noise(0.09), 900, 3500) * env_ad(int(SR * 0.09), 0.004, 6)
    pl = pluck(147, 0.12, brightness=0.3, bend=0.1) * env_ad(int(SR * 0.12), 0.001, 8)
    return mix((puff, 0.6), (lowpass(pl, 1500), 0.7))


def r3_arrow_b():  # Muted bow thump with a soft click
    pl = pluck(110, 0.14, brightness=0.25, bend=0.2) * env_ad(int(SR * 0.14), 0.001, 7)
    click = bandpass(noise(0.008), 1500, 4000) * env_ad(int(SR * 0.008), 0.0005, 6)
    return mix((lowpass(pl, 1200), 0.9), (click, 0.3))


def r3_arrow_c():  # Musical "pew": a soft falling tone with air
    pew = chirp(0.08, 950, 620) * env_ad(int(SR * 0.08), 0.002, 6)
    air = bandpass(noise(0.07), 2500, 6000) * env_ad(int(SR * 0.07), 0.005, 6)
    return mix((pew, 0.6), (air, 0.2))


def r3_arrow_d():  # Whisper whoosh with a quiet string snap
    wh = whoosh(0.12, 1500, 4500, q=1.5, attack=0.006, decay=6)
    snap = bandpass(pluck(262, 0.08, brightness=0.6), 400, 2500) * env_ad(int(SR * 0.08), 0.001, 9)
    return mix((wh, 0.6), (snap, 0.45))


# enemy hit

def r3_hit_a():  # Soft muted thump
    th = chirp(0.07, 190, 110) * env_ad(int(SR * 0.07), 0.001, 6)
    pat = lowpass(noise(0.03), 1200) * env_ad(int(SR * 0.03), 0.001, 7)
    return mix((th, 1.0), (pat, 0.3))


def r3_hit_b():  # Rounded "plop"
    plop = chirp(0.09, 520, 240) * env_ad(int(SR * 0.09), 0.002, 6)
    return mix((plop, 0.9), (lowpass(noise(0.02), 2000) * env_ad(int(SR * 0.02), 0.001, 6), 0.2))


def r3_hit_c():  # Soft woodblock tick
    return tone(780, 0.08, 18, ((1, 1.0), (2.6, 0.3), (4.1, 0.1)), attack=0.0008)


def r3_hit_d():  # Squishy pat
    sq = lowpass(noise(0.07), 450) * env_ad(int(SR * 0.07), 0.002, 6)
    body = tone(150, 0.08, 9)
    return mix((sq, 0.8), (body, 0.6))


# enemy death, around C (a falling "bwoop" and a poof)

def r3_death_a():  # C, shorter and rounder
    bwoop = chirp(0.2, 620, 160) * env_ad(int(SR * 0.2), 0.004, 4)
    poof = lowpass(noise(0.18), 1200) * env_ad(int(SR * 0.18), 0.02, 5)
    return room(mix((bwoop, 0.8), (at(poof, 0.08), 0.45)), 0.1, 0.12)


def r3_death_b():  # Bwoop down, sparkle up
    bwoop = chirp(0.22, 650, 170, wave="tri") * env_ad(int(SR * 0.22), 0.004, 4)
    sp = sparkle(0.3, [1568, 2093, 2637], spacing=0.04, decay=10)
    return room(mix((bwoop, 0.75), (at(sp, 0.14), 0.35)), 0.14, 0.18)


def r3_death_c():  # Soft poof with a gentle bell
    poof = sweep_filter(noise(0.25), 1600, 400, q=1.0) * env_ad(int(SR * 0.25), 0.01, 5)
    bell = tone(880, 0.4, 6, BELL)
    return room(mix((poof, 0.8), (at(bell, 0.03), 0.35)), 0.15, 0.2)


def r3_death_d():  # Pop-pop, then a poof
    pops = mix(*[(at(chirp(0.04, f, f * 2.2) * env_ad(int(SR * 0.04), 0.001, 6), d), 0.6)
                 for f, d in ((420, 0), (560, 0.06))])
    poof = lowpass(noise(0.2), 1400) * env_ad(int(SR * 0.2), 0.02, 5)
    return room(mix((pops, 0.8), (at(poof, 0.1), 0.5)), 0.12, 0.15)


# staff cast

def r3_cast_a():  # Bell ping with a gentle whoosh
    return room(mix((tone(1175, 0.4, 6, BELL), 0.55), (whoosh(0.22, 800, 3500, q=1.2, attack=0.02, decay=5), 0.5)), 0.15, 0.2)


def r3_cast_b():  # Warm "vwoom" with a wobble
    tt = t_of(0.3)
    f = 300 + 300 * tt / 0.3 + 12 * np.sin(2 * np.pi * 9 * tt)
    vw = np.sin(2 * np.pi * np.cumsum(f) / SR) * env_ad(len(tt), 0.02, 4)
    return room(mix((vw, 0.7), (lowpass(noise(0.3), 1500) * env_ad(len(tt), 0.03, 5), 0.25)), 0.15, 0.2)


def r3_cast_c():  # Quick three-note twinkle up
    return room(mix((arp([1319, 1568, 2093], 0.03, 0.25, GLASS, 9), 0.6), (whoosh(0.18, 1500, 5000, q=1.5), 0.35)), 0.12, 0.18)


def r3_cast_d():  # Soft deep orb launch with shimmer
    th = chirp(0.22, 230, 120) * env_ad(int(SR * 0.22), 0.004, 5)
    sh = sparkle(0.25, [2093, 2637], spacing=0.03, decay=12)
    return room(mix((th, 0.9), (at(sh, 0.02), 0.25)), 0.15, 0.2)


# dash

def r3_dash_a():  # Short soft swish
    return whoosh(0.13, 1200, 3500, q=1.4, attack=0.01, decay=6)


def r3_dash_b():  # Swish with a small rising chime
    return mix((whoosh(0.15, 1000, 4000, q=1.4, attack=0.01, decay=5), 0.7),
               (at(arp([1319, 1760], 0.04, 0.2, WARM, 10), 0.03), 0.3))


def r3_dash_c():  # Double "fwip"
    one = whoosh(0.07, 1800, 5000, q=1.6, attack=0.005, decay=6)
    return mix((one, 0.6), (at(one, 0.07), 0.45))


def r3_dash_d():  # Low, short air puff
    return mix((whoosh(0.14, 400, 1500, q=1.0, attack=0.01, decay=6), 0.9),
               (tone(110, 0.1, 8), 0.3))


# card pick

def r3_card_a():  # A single soft bell ding
    return room(tone(1319, 0.45, 6, BELL), 0.15, 0.2)


def r3_card_b():  # Card slide into two warm notes up
    slide = bandpass(noise(0.06), 1500, 4500) * env_ad(int(SR * 0.06), 0.02, 4)
    return room(mix((slide, 0.35), (at(arp([784, 1175], 0.06, 0.35, WARM, 7), 0.04), 0.6)), 0.15, 0.2)


def r3_card_c():  # A short sparkle cascade
    return room(sparkle(0.35, [3136, 2637, 2093, 1568], spacing=0.035, decay=9), 0.15, 0.2)


def r3_card_d():  # Woody tap and a ding
    tap = tone(520, 0.05, 20, ((1, 1.0), (2.6, 0.3)), attack=0.0008)
    return room(mix((tap, 0.6), (at(tone(1568, 0.35, 7, BELL), 0.04), 0.5)), 0.15, 0.2)


# gate open

def r3_gate_a():  # A slower, lower rising arpeggio
    return room(arp([392, 523, 659, 784, 1047], 0.09, 0.6, BELL, 4), 0.25, 0.28)


def r3_gate_b():  # Soft chord bloom with sparkle
    chord = sum(tone(f, 0.8, 3, WARM, attack=0.08) for f in [523, 659, 784]) / 2
    return room(mix((chord, 0.7), (at(sparkle(0.4, [2093, 2637, 3136, 4186], spacing=0.05), 0.15), 0.35)), 0.25, 0.28)


def r3_gate_c():  # Chimes falling into a sparkle
    return room(mix((arp([1568, 1319, 1047, 784], 0.07, 0.5, BELL, 5), 0.6),
                    (at(sparkle(0.3, [2637, 3136]), 0.3), 0.3)), 0.25, 0.28)


def r3_gate_d():  # Warm bell and a short airy swell
    swell = sweep_filter(noise(0.6), 600, 3000, q=2) * env_ad(int(SR * 0.6), 0.15, 4)
    return room(mix((tone(659, 0.7, 4, BELL), 0.6), (swell, 0.35)), 0.25, 0.28)


ROUND3 = {
    "arrow_fire": [
        ("a", r3_arrow_a, "Soft \"fft\": an air puff over a low, muted pluck."),
        ("b", r3_arrow_b, "Muted bow thump with a soft click."),
        ("c", r3_arrow_c, "Musical \"pew\": a soft falling tone."),
        ("d", r3_arrow_d, "A whisper of whoosh with a quiet string snap."),
    ],
    "enemy_hit": [
        ("a", r3_hit_a, "Soft, muted thump."),
        ("b", r3_hit_b, "A rounded \"plop\"."),
        ("c", r3_hit_c, "A soft woodblock tick."),
        ("d", r3_hit_d, "A squishy pat."),
    ],
    "enemy_death": [
        ("a", r3_death_a, "Your pick C, shorter and rounder."),
        ("b", r3_death_b, "C's falling bwoop, then a sparkle rising."),
        ("c", r3_death_c, "A soft poof with a gentle bell."),
        ("d", r3_death_d, "Pop-pop, then a poof."),
    ],
    "staff_cast": [
        ("a", r3_cast_a, "A bell ping with a gentle whoosh."),
        ("b", r3_cast_b, "A warm \"vwoom\" with a little wobble."),
        ("c", r3_cast_c, "A quick three-note twinkle going up."),
        ("d", r3_cast_d, "A soft, deep orb launch with a shimmer."),
    ],
    "dash": [
        ("a", r3_dash_a, "A short, soft swish."),
        ("b", r3_dash_b, "A swish with a small rising chime."),
        ("c", r3_dash_c, "A double \"fwip\"."),
        ("d", r3_dash_d, "A low, short puff of air."),
    ],
    "card_pick": [
        ("a", r3_card_a, "A single soft bell ding."),
        ("b", r3_card_b, "A card slide into two warm notes going up."),
        ("c", r3_card_c, "A short sparkle cascading down."),
        ("d", r3_card_d, "A woody tap and a ding."),
    ],
    "gate_open": [
        ("a", r3_gate_a, "A slower, lower rising arpeggio, like your level-up pick."),
        ("b", r3_gate_b, "A soft chord blooming, with a sparkle."),
        ("c", r3_gate_c, "Chimes falling into a sparkle."),
        ("d", r3_gate_d, "A warm bell and a short airy swell."),
    ],
}


LEVEL.update(LEVEL2)
# ---------- round 4: the staff's deep orb launch without its shimmer, the
# enemy death's pop-pop with a better poof, and new directions for the
# arrow and the gate (owner, 2026-10-23). ----------

# staff cast, around round 3's D (a soft, deep orb launch), no shimmer

def r4_cast_a():  # Round 3's D, shimmer removed
    th = chirp(0.22, 230, 120) * env_ad(int(SR * 0.22), 0.004, 5)
    return room(th, 0.15, 0.2)


def r4_cast_b():  # Deeper and a little longer, with soft air
    th = chirp(0.28, 200, 95) * env_ad(int(SR * 0.28), 0.004, 4.5)
    air = lowpass(noise(0.2), 1800) * env_ad(int(SR * 0.2), 0.01, 6)
    return room(mix((th, 0.9), (air, 0.2)), 0.15, 0.2)


def r4_cast_c():  # A rounder "whomp": the drop with a soft body
    th = chirp(0.24, 240, 115) * env_ad(int(SR * 0.24), 0.006, 5)
    body = sweep_filter(noise(0.22), 900, 250, q=1.0) * env_ad(int(SR * 0.22), 0.01, 5)
    return room(mix((th, 0.85), (body, 0.4)), 0.15, 0.2)


def r4_cast_d():  # Punchier: a quicker drop with a soft click
    th = chirp(0.16, 260, 110) * env_ad(int(SR * 0.16), 0.002, 6)
    click = bandpass(noise(0.006), 1500, 4000) * env_ad(int(SR * 0.006), 0.0005, 6)
    return room(mix((th, 1.0), (click, 0.25)), 0.12, 0.15)


# enemy death: round 3's D (pop-pop, then a poof) with a better poof

def _pops():
    return mix(*[(at(chirp(0.04, f, f * 2.2) * env_ad(int(SR * 0.04), 0.001, 6), d), 0.6)
                 for f, d in ((420, 0), (560, 0.06))])


def r4_death_a():  # A fuller, breathy poof over a low thump
    poof = sweep_filter(noise(0.32), 2600, 300, q=0.9) * env_ad(int(SR * 0.32), 0.03, 4.5)
    thump = chirp(0.12, 140, 70) * env_ad(int(SR * 0.12), 0.003, 5)
    return room(mix((_pops(), 0.75), (at(poof, 0.09), 0.75), (at(thump, 0.09), 0.4)), 0.15, 0.2)


def r4_death_b():  # A puff of smoke: soft, darkening as it fades
    puff = sweep_filter(noise(0.4), 1800, 200, q=0.7, kind="low") * env_ad(int(SR * 0.4), 0.05, 4)
    return room(mix((_pops(), 0.75), (at(puff, 0.08), 0.9)), 0.2, 0.25)


def r4_death_c():  # A bubbly "pff": the poof with a little tone in it
    pff = sweep_filter(noise(0.28), 900, 350, q=4) * env_ad(int(SR * 0.28), 0.02, 5)
    air = lowpass(noise(0.25), 2000) * env_ad(int(SR * 0.25), 0.02, 5)
    return room(mix((_pops(), 0.75), (at(pff, 0.09), 0.6), (at(air, 0.09), 0.35)), 0.15, 0.2)


def r4_death_d():  # An airy poof with a tiny sparkle tail
    poof = sweep_filter(noise(0.3), 3000, 600, q=1.0) * env_ad(int(SR * 0.3), 0.02, 4.5)
    sp = sparkle(0.25, [2637, 3136], spacing=0.04, decay=12)
    return room(mix((_pops(), 0.75), (at(poof, 0.08), 0.7), (at(sp, 0.25), 0.2)), 0.15, 0.2)


# arrow fire, new directions (every earlier take passed over)

def r4_arrow_a():  # A light "swip", the arrow cutting past
    swip = sweep_filter(noise(0.07), 2800, 6500, q=2.5) * env_ad(int(SR * 0.07), 0.004, 5)
    tail = pluck(330, 0.06, brightness=0.5) * env_ad(int(SR * 0.06), 0.001, 10)
    return mix((swip, 0.8), (lowpass(tail, 3000), 0.25))


def r4_arrow_b():  # A soft wooden "tok" with air behind it
    tok = tone(420, 0.06, 22, ((1, 1.0), (2.6, 0.25)), attack=0.0008)
    air = bandpass(noise(0.08), 2000, 5500) * env_ad(int(SR * 0.08), 0.006, 6)
    return mix((tok, 0.7), (at(air, 0.005), 0.35))


def r4_arrow_c():  # A high, musical "tink" of string
    pl = pluck(392, 0.09, brightness=0.8, bend=0.04) * env_ad(int(SR * 0.09), 0.0008, 9)
    return lowpass(pl, 5000)


def r4_arrow_d():  # A breathy "fsh" over a low tick
    fsh = lowpass(whoosh(0.1, 1500, 4000, q=1.2, attack=0.006, decay=6), 5000)
    tick = tone(90, 0.05, 14)
    return mix((fsh, 0.75), (tick, 0.45))


# gate open, new directions (every earlier take passed over)

def r4_gate_a():  # A rising portal whoosh with a soft shimmer pad
    sweep = whoosh(0.9, 300, 5000, q=2.5, attack=0.4, decay=3)
    pad = sum(tone(f, 0.9, 2.5, WARM, attack=0.35) for f in [523, 784]) / 3
    return room(mix((sweep, 0.6), (pad, 0.35)), 0.3, 0.3)


def r4_gate_b():  # A warm swell rising in pitch, with a sparkle
    tt = t_of(0.8)
    f = 220 * (1 + 1.0 * (tt / 0.8) ** 2)
    sw = np.sin(2 * np.pi * np.cumsum(f) / SR) * env_ad(len(tt), 0.3, 3)
    return room(mix((sw, 0.6), (at(sparkle(0.35, [2093, 2637, 3136], spacing=0.05), 0.5), 0.35)), 0.3, 0.3)


def r4_gate_c():  # A soft "ta-da": two warm chords
    one = sum(tone(f, 0.25, 7, WARM) for f in [392, 494, 587]) / 2
    two = sum(tone(f, 0.7, 3.5, WARM) for f in [523, 659, 784]) / 2
    return room(mix((one, 0.6), (at(two, 0.16), 0.7)), 0.25, 0.28)


def r4_gate_d():  # A quick harp run upward
    run = mix(*[(at(pluck(f, 0.6, brightness=0.6) * env_ad(int(SR * 0.6), 0.001, 4), i * 0.035), 0.5)
                for i, f in enumerate([392, 440, 494, 587, 659, 784, 880, 988])])
    return room(lowpass(run, 6000), 0.25, 0.3)


ROUND4 = {
    "staff_cast": [
        ("a", r4_cast_a, "Round 3's D exactly, with the shimmer taken out."),
        ("b", r4_cast_b, "Deeper and a little longer, with soft air."),
        ("c", r4_cast_c, "A rounder \"whomp\": the drop with a soft body to it."),
        ("d", r4_cast_d, "Punchier: a quicker drop with a soft click."),
    ],
    "enemy_death": [
        ("a", r4_death_a, "Pop-pop, then a fuller, breathy poof over a low thump."),
        ("b", r4_death_b, "Pop-pop, then a puff of smoke that darkens as it fades."),
        ("c", r4_death_c, "Pop-pop, then a bubbly \"pff\" with a little tone in it."),
        ("d", r4_death_d, "Pop-pop, then an airy poof with a tiny sparkle tail."),
    ],
    "arrow_fire": [
        ("a", r4_arrow_a, "A light \"swip\", the arrow cutting past."),
        ("b", r4_arrow_b, "A soft wooden \"tok\" with air behind it."),
        ("c", r4_arrow_c, "A high, musical \"tink\" of string."),
        ("d", r4_arrow_d, "A breathy \"fsh\" over a low tick."),
    ],
    "gate_open": [
        ("a", r4_gate_a, "A rising portal whoosh over a soft pad. No bells."),
        ("b", r4_gate_b, "A warm swell rising in pitch, then a sparkle."),
        ("c", r4_gate_c, "A soft \"ta-da\": two warm chords."),
        ("d", r4_gate_d, "A quick harp run upward."),
    ],
}


# ---------- round 5 (owner, 2026-10-23): the staff cast in a completely
# new direction; the enemy death's pop-pop ending in a big cartoon "POOF"
# of a dust cloud (an original, in the spirit of a goal-explosion poof);
# round 4's gate C with the doors in it. ----------

# staff cast: new directions

def r5_cast_a():  # A magic bubble "bloop"
    tt = t_of(0.18)
    f = 300 + 900 * (1 - np.exp(-tt * 40)) - 500 * (tt / 0.18) ** 2
    bloop = np.sin(2 * np.pi * np.cumsum(f) / SR) * env_ad(len(tt), 0.003, 5)
    return room(bloop, 0.12, 0.15)


def r5_cast_b():  # A soft synth stab, filter opening and closing
    tt = t_of(0.28)
    saw = sum(np.sin(2 * np.pi * f * k * tt) / k for f in (220, 330) for k in range(1, 8))
    stab = sweep_filter(saw, 2400, 500, q=1.5, kind="low") * env_ad(len(tt), 0.004, 5)
    return room(stab, 0.15, 0.2)


def r5_cast_c():  # A kalimba pluck, two notes
    def tine(f, s):
        return tone(f, s, 9, ((1, 1.0), (5.4, 0.18), (8.9, 0.05)), attack=0.001)
    return room(mix((tine(784, 0.35), 0.7), (at(tine(1175, 0.3), 0.06), 0.55)), 0.15, 0.2)


def r5_cast_d():  # An airy flute "hoo" swelling quickly
    tt = t_of(0.3)
    f = 660 * (1 + 0.01 * np.sin(2 * np.pi * 6 * tt))
    body = np.sin(2 * np.pi * np.cumsum(f) / SR) + 0.2 * np.sin(2 * np.pi * 2 * np.cumsum(f) / SR)
    breath = bandpass(noise(0.3), 1200, 4000) * 0.35
    e = env_ad(len(tt), 0.06, 4)
    return room((body + breath) * e, 0.18, 0.22)


# enemy death: pop-pop, then a big cartoon dust-cloud POOF

def _r5_pops():
    return mix(*[(at(chirp(0.04, f, f * 2.2) * env_ad(int(SR * 0.04), 0.001, 6), d), 0.6)
                 for f, d in ((420, 0), (560, 0.06))])


def _poof(seconds=0.45, top=2400, bottom=180, thump=110):
    cloud = sweep_filter(noise(seconds), top, bottom, q=0.8, kind="low") * env_ad(int(SR * seconds), 0.008, 4)
    low = chirp(0.18, thump, thump * 0.5) * env_ad(int(SR * 0.18), 0.002, 5)
    return mix((cloud, 1.0), (low, 0.6))


def r5_death_a():  # A big, round POOF
    return room(mix((_r5_pops(), 0.6), (at(_poof(), 0.1), 0.95)), 0.2, 0.22)


def r5_death_b():  # A POOF with a cartoon "pff" whistle down through it
    whistle = chirp(0.25, 1400, 400) * env_ad(int(SR * 0.25), 0.005, 5)
    return room(mix((_r5_pops(), 0.6), (at(_poof(0.4), 0.1), 0.9), (at(whistle, 0.1), 0.2)), 0.2, 0.22)


def r5_death_c():  # A punchier POOF, a little confetti sparkle after
    sp = sparkle(0.35, [2093, 2637, 3136, 3520], spacing=0.035, decay=10)
    return room(mix((_r5_pops(), 0.6), (at(_poof(0.35, 3000, 250, 130), 0.1), 1.0), (at(sp, 0.25), 0.22)), 0.2, 0.22)


def r5_death_d():  # A softer, bigger cloud: POOF that lingers
    return room(mix((_r5_pops(), 0.55), (at(_poof(0.65, 1800, 120, 90), 0.1), 0.95)), 0.28, 0.28)


# gate open: round 4's C (two warm chords) with the doors in it

def _r4c():
    one = sum(tone(f, 0.25, 7, WARM) for f in [392, 494, 587]) / 2
    two = sum(tone(f, 0.7, 3.5, WARM) for f in [523, 659, 784]) / 2
    return mix((one, 0.6), (at(two, 0.16), 0.7))


def _creak(seconds=0.7):
    tt = t_of(seconds)
    rate = 18 + 10 * np.sin(2 * np.pi * 1.3 * tt)
    pulses = (np.sin(2 * np.pi * np.cumsum(rate) / SR) > 0.92).astype(float)
    grit = bandpass(noise(seconds), 500, 1600) * pulses
    return lowpass(grit, 2200) * env_ad(len(tt), 0.1, 2)


def _thud(f=95):
    return mix((chirp(0.12, f, f * 0.6) * env_ad(int(SR * 0.12), 0.002, 6), 1.0),
               (lowpass(noise(0.05), 600) * env_ad(int(SR * 0.05), 0.001, 6), 0.4))


def r5_gate_a():  # A wooden creak as the doors swing, then C
    return room(mix((_creak(), 0.6), (at(_r4c(), 0.65), 0.75)), 0.25, 0.28)


def r5_gate_b():  # A latch click and the doors' soft thud, then C
    latch = tone(1800, 0.04, 30, ((1, 1.0), (2.4, 0.4)), attack=0.0005)
    return room(mix((latch, 0.4), (at(_thud(), 0.7), 0.7), (at(_r4c(), 0.75), 0.7)), 0.25, 0.28)


def r5_gate_c():  # C over the creak, together
    return room(mix((_creak(0.9), 0.45), (at(_r4c(), 0.15), 0.75)), 0.25, 0.28)


def r5_gate_d():  # The doors swing and bounce to a stop (thunk-thunk), then C
    return room(mix((whoosh(0.6, 300, 1200, q=1.0, attack=0.2, decay=3), 0.35),
                    (at(_thud(), 0.6), 0.8), (at(_thud(120), 0.78), 0.45), (at(_r4c(), 0.85), 0.7)), 0.25, 0.28)


ROUND5 = {
    "staff_cast": [
        ("a", r5_cast_a, "A magic bubble \"bloop\"."),
        ("b", r5_cast_b, "A soft synth stab, its tone opening and closing."),
        ("c", r5_cast_c, "A kalimba pluck, two notes."),
        ("d", r5_cast_d, "An airy flute \"hoo\" swelling quickly."),
    ],
    "enemy_death": [
        ("a", r5_death_a, "Pop-pop, then a big round POOF."),
        ("b", r5_death_b, "Pop-pop, then a POOF with a cartoon whistle down through it."),
        ("c", r5_death_c, "Pop-pop, then a punchier POOF and a little confetti sparkle."),
        ("d", r5_death_d, "Pop-pop, then a softer, bigger cloud that lingers."),
    ],
    "gate_open": [
        ("a", r5_gate_a, "The doors creak open, then your C."),
        ("b", r5_gate_b, "A latch click, the doors' soft thud, then your C."),
        ("c", r5_gate_c, "Your C over the creaking doors, together."),
        ("d", r5_gate_d, "The doors swing and bounce to a stop (thunk-thunk), then your C."),
    ],
}


# The audition rounds, kept so any take can be rendered again exactly.
ROUNDS = {"1": ROUND1, "2": ROUND2, "3": ROUND3, "4": ROUND4, "5": ROUND5}

if __name__ == "__main__":
    out = sys.argv[1]
    # Rounds render in order from one seed, so a round renders the same
    # takes only alongside the rounds it was first rendered with (1 and 2
    # together; each later round alone).
    wanted = sys.argv[2:] or ["1", "2"]
    os.makedirs(out, exist_ok=True)
    manifest = {}
    for r in wanted:
        for name, variants in ROUNDS[r].items():
            manifest[name] = []
            for letter, fn, note in variants:
                x = finish(fn(), target_rms=LEVEL[name])
                path = os.path.join(out, f"{name}_{letter}.wav")
                wavfile.write(path, SR, (np.clip(x, -1, 1) * 32767).astype(np.int16))
                manifest[name].append({"variant": letter, "file": os.path.basename(path), "note": note, "ms": round(len(x) / SR * 1000)})
                print(name, letter, round(len(x) / SR * 1000), "ms")
    json.dump(manifest, open(os.path.join(out, "manifest.json"), "w"), indent=1)
