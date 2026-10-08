"""Synthesises the story set-piece's sounds into game/assets/sounds/ (our own, CC0), for story/awakening.gd:
dread_rise (the sky turns wrong), tendril_burst (shadow tearing out of the ground), hollow_rise (the colossus
lifting out of the land), hollow_voice (its one word: "...You."), light_blast (the stones answer) and
title_hit (the title card's swell). Uses the helpers in make_sounds.py. Run: python tools-src/make_story_sounds.py
"""
import numpy as np
from scipy.signal import butter, sosfilt
import make_sounds as ms
from make_sounds import RATE, band, low, save, reverb

rng = np.random.default_rng(23)


def t_of(seconds):
    n = int(seconds * RATE)
    return n, np.arange(n) / RATE


def place(buf, x, at):
    s = int(at * RATE)
    e = min(len(buf), s + len(x))
    buf[s:e] += x[: e - s]


def sweep(f0, f1, t, dur):
    """A sine gliding from f0 to f1 over dur (exponential), phase-continuous."""
    f = f0 * (f1 / f0) ** np.clip(t / dur, 0, 1)
    return np.sin(2 * np.pi * np.cumsum(f) / RATE)


def saw(f, t, partials=12):
    return sum(np.sin(2 * np.pi * f * k * t) / k for k in range(1, partials + 1))


def boom(t, f0=70, f1=28, decay=2.5):
    return sweep(f0, f1, t, 0.6) * np.exp(-t * decay)


def dread_rise():
    """Five seconds: the hum sours into a falling, beating cluster over a growing sub rumble; a hit at the end."""
    dur = 5.5
    n, t = t_of(dur)
    grow = np.clip(t / 4.6, 0, 1) ** 1.6
    cluster = sum(sweep(f, f * 0.5, t, dur) * w for f, w in [(220, 0.5), (233, 0.45), (311, 0.35), (147, 0.6)])
    rumble = low(rng.normal(size=n), 90, 4) * 6.0
    x = cluster * grow * 0.5 + rumble * grow
    x += band(rng.normal(size=n), 400, 1800) * grow ** 3 * 0.12          # a hiss, like wind through teeth
    x *= np.where(t > 4.6, np.exp(-(t - 4.6) * 6), 1.0)
    m, tt = t_of(0.9)
    place(x, boom(tt, 60, 24, 3.0) * 1.6, 4.6)
    save("dread_rise", reverb(x, 1.2, 0.3), 0.8)


def tendril_burst():
    """Earth tearing open and something wet and dark whipping up out of it."""
    n, t = t_of(1.4)
    crack = low(rng.normal(size=n), 500, 2) * np.exp(-t * 9) * 1.4
    thud = boom(t, 90, 35, 6.0)
    whip = band(rng.normal(size=n), 300, 1400) * np.sin(np.pi * np.clip((t - 0.05) / 0.7, 0, 1)) ** 2 * 0.6
    x = crack + thud + whip
    save("tendril_burst", reverb(x, 0.8, 0.3), 0.75)


def hollow_rise():
    """Six seconds of the land groaning: grinding low noise, a slow sub swell, stone cracking now and then."""
    dur = 6.5
    n, t = t_of(dur)
    swell = np.sin(np.pi * np.clip(t / dur, 0, 1)) ** 0.7
    grind = band(rng.normal(size=n), 40, 220, 2) * (0.7 + 0.3 * np.sin(2 * np.pi * 3.1 * t)) * 3.0
    sub = sweep(32, 44, t, dur) * 0.8
    x = (grind + sub) * swell
    for at in [0.4, 1.3, 2.1, 3.4, 4.0, 5.2]:
        m, tt = t_of(0.5)
        place(x, low(rng.normal(size=m), 1200) * np.exp(-tt * 14) * 0.9, at)
    save("hollow_rise", reverb(x, 1.6, 0.35), 0.85)


def formant(src, f, bw):
    """A resonant band (a vowel formant)."""
    sos = butter(2, [max(f - bw / 2, 20), f + bw / 2], btype="band", fs=RATE, output="sos")
    return sosfilt(sos, src)


def hollow_voice():
    """Its one word, "...You.": a huge, slow, throaty voice. A low glottal buzz through moving formants
    (y -> oo), doubled an octave down, with a breath before it and a long cave of a tail."""
    dur = 2.6
    n, t = t_of(dur)
    pitch = 46.0 * (1.0 - 0.12 * np.clip(t / dur, 0, 1)) * (1 + 0.015 * np.sin(2 * np.pi * 5.5 * t))
    phase = np.cumsum(pitch) / RATE
    pulse = ((phase % 1.0) < 0.12).astype(float) - 0.12          # a raspy glottal pulse train
    pulse += 0.25 * rng.normal(size=n) * low(np.abs(rng.normal(size=n)), 60)   # grit
    k = np.clip((t - 0.35) / 0.5, 0, 1)                            # y -> oo glide
    f1 = 280 + 40 * k
    f2 = 2100 * (1 - k) + 750 * k
    voice = np.zeros(n)
    step = 512
    for s in range(0, n, step):                                    # formants moving in blocks
        e = min(n, s + step)
        mid = (s + e) // 2
        seg = pulse[max(0, s - 256):e]
        out = formant(seg, f1[mid], 120) * 1.0 + formant(seg, f2[mid], 260) * 0.45 + formant(seg, 2600, 400) * 0.15
        voice[s:e] = out[-(e - s):]
    shape = np.clip((t - 0.25) / 0.25, 0, 1) * np.clip((dur - 0.3 - t) / 1.4, 0, 1) ** 1.3
    sub = np.sin(2 * np.pi * np.cumsum(pitch * 0.5) / RATE) * 0.6
    breath = band(rng.normal(size=n), 200, 900) * np.exp(-((t - 0.12) / 0.12) ** 2) * 0.5
    x = voice * shape * 3.0 + sub * shape + breath
    save("hollow_voice", reverb(x, 2.4, 0.45), 0.9)


def bell(f, t, decay=4.0, bright=0.35):
    return (np.sin(2 * np.pi * f * t) + bright * np.sin(2 * np.pi * f * 2.76 * t) * np.exp(-t * decay * 1.5)) * np.exp(-t * decay)


def light_blast():
    """The stones answer: a white whoosh up into a bright struck chord and a deep, clean boom."""
    dur = 3.5
    n, t = t_of(dur)
    rise = band(rng.normal(size=n), 2000, 9000) * np.clip(t / 0.35, 0, 1) ** 3 * np.exp(-np.clip(t - 0.35, 0, None) * 4) * 0.6
    x = rise
    m, tt = t_of(dur - 0.35)
    chord = sum(bell(f, tt, 1.3, 0.5) for f in [523.3, 659.3, 784.0, 1046.5, 1568.0]) * 0.35
    place(x, chord, 0.35)
    place(x, boom(tt, 110, 32, 2.0) * 1.4, 0.35)
    save("light_blast", reverb(x, 1.8, 0.4), 0.85)


def title_hit():
    """The title card: a deep drum hit and a warm brass-like chord swelling up (D major, open), then a shimmer."""
    dur = 7.0
    n, t = t_of(dur)
    x = np.zeros(n)
    m, tt = t_of(2.5)
    place(x, boom(tt, 80, 30, 1.6) * 1.8 + low(rng.normal(size=m), 200) * np.exp(-tt * 8) * 0.8, 0.0)
    swell = np.clip(t / 1.2, 0, 1) ** 1.5 * np.clip((dur - t) / 3.5, 0, 1) ** 1.2
    brass = sum(low(saw(f * (1 + 0.002 * i), t, 10), 900 + 500 * i) * w
                for i, (f, w) in enumerate([(73.4, 0.9), (110.0, 0.7), (146.8, 0.6), (185.0, 0.45), (220.0, 0.4), (293.7, 0.3)]))
    x += brass * swell * 0.35
    shimmer = band(rng.normal(size=n), 5000, 10000) * np.clip((t - 0.8) / 1.5, 0, 1) * np.clip((dur - t) / 3.0, 0, 1) * 0.08
    x += shimmer
    for i, f in enumerate([587.3, 880.0, 1174.7]):
        m, tt = t_of(dur - 1.0 - i * 0.3)
        place(x, bell(f, tt, 0.9, 0.3) * 0.18, 1.0 + i * 0.3)
    save("title_hit", reverb(x, 2.2, 0.35), 0.85)


if __name__ == "__main__":
    dread_rise()
    tendril_burst()
    hollow_rise()
    hollow_voice()
    light_blast()
    title_hit()
    print("story sounds written to", ms.OUT)
