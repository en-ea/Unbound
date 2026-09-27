"""Synthesises the placeholder nature sounds into game/assets/sounds/ (our own, CC0).
Run: python tools-src/make_sounds.py
"""
import os
import numpy as np
from scipy.io import wavfile
from scipy.signal import butter, sosfilt

RATE = 22050
OUT = os.path.join(os.path.dirname(__file__), "..", "game", "assets", "sounds")
rng = np.random.default_rng(3)


def band(x, lo, hi, order=2):
    sos = butter(order, [lo, hi], btype="band", fs=RATE, output="sos")
    return sosfilt(sos, x)


def low(x, hi, order=2):
    return sosfilt(butter(order, hi, btype="low", fs=RATE, output="sos"), x)


def env(n, attack, decay_power=2.0):
    t = np.linspace(0, 1, n)
    a = np.clip(t / max(attack, 1e-4), 0, 1)
    return a * (1 - t) ** decay_power


def save(name, x, peak=0.8):
    x = x / (np.max(np.abs(x)) + 1e-9) * peak
    wavfile.write(os.path.join(OUT, name + ".wav"), RATE, (x * 32767).astype(np.int16))


def loopable(x, fade):
    """Crossfades the end into the start so the sound loops without a click."""
    f = int(fade * RATE)
    ramp = np.linspace(0, 1, f)
    head = x[:f] * ramp + x[-f:] * (1 - ramp)
    return np.concatenate([head, x[f:-f]])


def steps():
    # Grass and dirt footsteps are recorded (Kenney Impact Sounds); only water is made here.
    for i in range(3):
        n = int(0.35 * RATE)
        t = np.arange(n) / RATE
        splash = band(rng.normal(size=n), 600, 3500) * env(n, 0.03, 2)
        splash *= 0.7 + 0.3 * np.sin(2 * np.pi * (30 + i * 7) * t)
        splash += np.sin(2 * np.pi * (300 + 200 * np.exp(-t * 20)) * t) * env(n, 0.01, 6) * 0.3
        save(f"step_water_{i}", splash, 0.55)


def reverb(x, seconds=0.7, wet=0.25):
    """A soft outdoor tail: convolve with decaying noise."""
    n = int(seconds * RATE)
    ir = rng.normal(size=n) * np.exp(-np.linspace(0, 6, n))
    ir = low(ir, 3500)
    tail = np.concatenate([np.convolve(x, ir), [0.0]])[: len(x) + n]
    tail /= np.max(np.abs(tail)) + 1e-9
    dry = np.concatenate([x, np.zeros(n)])
    return dry * (1 - wet) + tail * wet * np.max(np.abs(x))


def pink(n):
    """Pink-ish noise (softer than white), for wind and water."""
    white = rng.normal(size=n)
    return low(white, 900) * 0.7 + low(np.cumsum(white) * 0.02, 300)


def ambience():
    # Day: layered wind with slow gusts, and leaves that rustle harder in the gusts.
    secs = 20
    n = secs * RATE
    t = np.arange(n) / RATE
    gust = 0.45 + 0.35 * np.sin(2 * np.pi * t / secs) ** 2 + 0.2 * np.sin(2 * np.pi * 3 * t / secs + 1.3) ** 2
    wind = band(pink(n), 60, 700) * gust
    leaves = band(rng.normal(size=n), 2500, 7500) * (gust - 0.4).clip(0, None) ** 2 * 0.5
    save("amb_day", loopable(wind + leaves, 1.5), 0.45)

    # Night: a few crickets with their own rhythm and pitch, over a low hush.
    secs = 16
    n = secs * RATE
    t = np.arange(n) / RATE
    night = band(pink(n), 60, 400) * 0.25
    for c in range(4):
        freq = 4200 + c * 260 + rng.uniform(-60, 60)
        rate = rng.uniform(1.6, 3.0)                     # chirp groups per second
        phase = rng.uniform(0, 1)
        group = ((t * rate + phase) % 1.0) < 0.28          # a chirp group lasts a moment
        pulses = (np.sin(2 * np.pi * rng.uniform(28, 45) * t) > 0.2)
        amp = low((group & pulses).astype(float), 300) * (0.5 + 0.5 * np.sin(2 * np.pi * t / secs * (c + 1) + c) ** 2)
        night += np.sin(2 * np.pi * freq * t) * amp * (0.22 - c * 0.035)
    save("amb_night", loopable(reverb(night, 0.4, 0.15)[:n], 1.0), 0.4)

    # Pond: gentle lapping water (placed at the pond in the game).
    secs = 12
    n = secs * RATE
    t = np.arange(n) / RATE
    lap = band(pink(n), 200, 1800) * (0.5 + 0.5 * np.sin(2 * np.pi * 0.35 * t) ** 4)
    plips = np.zeros(n)
    for i in range(10):
        start = int(rng.uniform(0, secs - 0.2) * RATE)
        m = int(0.08 * RATE)
        tt = np.arange(m) / RATE
        f = rng.uniform(700, 1400)
        plips[start:start + m] += np.sin(2 * np.pi * (f + 900 * tt / tt[-1]) * tt) * np.exp(-tt * 45) * 0.5
    save("amb_pond", loopable(lap + plips, 1.0), 0.4)


def chirp(f0, f1, dur, shape=1.0, harmonics=0.25):
    n = int(dur * RATE)
    t = np.linspace(0, 1, n)
    f = f0 + (f1 - f0) * t ** shape
    ph = 2 * np.pi * np.cumsum(f) / RATE
    e = np.sin(np.pi * t) ** 1.5
    return (np.sin(ph) + harmonics * np.sin(2 * ph)) * e


def gap(dur):
    return np.zeros(int(dur * RATE))


def birds():
    songs = [
        # a two-note whistle, "fee-bee"
        np.concatenate([chirp(3900, 3800, 0.22), gap(0.05), chirp(3300, 3200, 0.3)]),
        # a quick descending chirp series
        np.concatenate(sum([[chirp(5200 - i * 250, 3600 - i * 200, 0.07, 0.6), gap(0.05)] for i in range(6)], [])),
        # a bubbly warble
        np.concatenate([chirp(2800 + 900 * np.sin(i * 1.7), 3400 + 700 * np.cos(i * 2.3), 0.06, 1.0, 0.4) for i in range(12)]),
        # a rising "tweet?" call, twice
        np.concatenate([chirp(2500, 4800, 0.18, 2.0), gap(0.25), chirp(2500, 5000, 0.18, 2.0)]),
        # a soft trill
        np.concatenate([chirp(4300, 4500, 0.035) for i in range(14)]),
        # a far-off dove, "hoo-hooo"
        np.concatenate([chirp(520, 560, 0.25, 1.0, 0.1), gap(0.12), chirp(560, 500, 0.55, 1.0, 0.1)]),
    ]
    for i, song in enumerate(songs):
        save(f"bird_{i}", reverb(song, 0.9, 0.3), 0.35)
    # A night owl.
    save("owl", reverb(np.concatenate([chirp(380, 400, 0.35, 1.0, 0.05), gap(0.2), chirp(400, 360, 0.7, 1.0, 0.05)]), 1.2, 0.35), 0.35)


def hum():
    secs = 10
    n = secs * RATE
    t = np.arange(n) / RATE
    x = sum(np.sin(2 * np.pi * f * t) * a for f, a in [(110, 1), (110.4, 0.8), (165, 0.5), (220.3, 0.3), (330, 0.12)])
    x *= 0.7 + 0.3 * np.sin(2 * np.pi * t / secs * 2)
    x += band(rng.normal(size=n), 800, 2400) * 0.03
    save("hum", loopable(x, 1.0), 0.4)


def pickups():
    # A soft plucked "blip" for normal pickups, a little sparkly chime for rare finds.
    n = int(0.18 * RATE)
    t = np.arange(n) / RATE
    f = 660 + 500 * (t / t[-1])
    blip = np.sin(2 * np.pi * np.cumsum(f) / RATE) * np.exp(-t * 22)
    blip += np.sin(2 * np.pi * np.cumsum(f * 2) / RATE) * np.exp(-t * 30) * 0.3
    save("pickup", blip, 0.6)
    notes = [880, 1109, 1319, 1760]
    n = int(0.9 * RATE)
    t = np.arange(n) / RATE
    chime = np.zeros(n)
    for i, f in enumerate(notes):
        start = int(i * 0.07 * RATE)
        tt = t[: n - start]
        chime[start:] += (np.sin(2 * np.pi * f * tt) + 0.3 * np.sin(2 * np.pi * f * 2.01 * tt)) * np.exp(-tt * 5)
    save("rare", chime, 0.6)


def tree_fall():
    # A creaking groan as the trunk gives, a leafy rustle, and a heavy thud when it lands.
    n = int(1.1 * RATE)
    t = np.arange(n) / RATE
    f = 140 - 60 * (t / t[-1])
    saw = 2 * ((np.cumsum(f) / RATE) % 1.0) - 1
    creak = band(saw * (0.6 + 0.4 * np.sin(2 * np.pi * 23 * t)), 200, 1600) * env(n, 0.2, 1.5)
    save("tree_creak", creak, 0.45)
    n = int(0.6 * RATE)
    rustle = band(rng.normal(size=n), 1500, 6000) * env(n, 0.05, 1.6)
    save("leaves_rustle", rustle, 0.45)
    n = int(0.7 * RATE)
    t = np.arange(n) / RATE
    thud = np.sin(2 * np.pi * (70 - 30 * t) * t) * np.exp(-t * 7) + low(rng.normal(size=n), 400) * np.exp(-t * 12) * 0.6
    save("tree_thud", thud, 0.7)


def boar():
    # Snort: a noisy, pulsing low grunt.
    n = int(0.55 * RATE)
    t = np.arange(n) / RATE
    grunt = band(rng.normal(size=n), 150, 900) * (0.5 + 0.5 * np.sin(2 * np.pi * 22 * t)) * env(n, 0.05, 1.5)
    grunt += np.sin(2 * np.pi * (95 + 20 * np.sin(2 * np.pi * 6 * t)) * t) * env(n, 0.05, 2) * 0.5
    save("boar_snort", reverb(grunt, 0.3, 0.15), 0.6)
    # Squeal: a harsh pitch glide (when hurt).
    n = int(0.4 * RATE)
    t = np.arange(n) / RATE
    f = 900 + 700 * np.sin(np.pi * t / t[-1])
    ph = 2 * np.pi * np.cumsum(f) / RATE
    squeal = (np.sin(ph) + 0.5 * np.sin(2 * ph) + 0.3 * np.sin(3 * ph)) * env(n, 0.03, 1.2)
    squeal += band(rng.normal(size=n), 1500, 4000) * env(n, 0.02, 2) * 0.3
    save("boar_squeal", squeal, 0.5)


def whoosh():
    n = int(0.28 * RATE)
    t = np.arange(n) / RATE
    x = rng.normal(size=n)
    lo = band(x, 400, 1200) * np.sin(np.pi * t / t[-1]) ** 2
    hi = band(x, 1500, 4000) * np.sin(np.pi * t / t[-1]) ** 4 * 0.5
    save("swing", lo + hi, 0.45)


if __name__ == "__main__":
    os.makedirs(OUT, exist_ok=True)
    steps()
    ambience()
    birds()
    hum()
    pickups()
    tree_fall()
    boar()
    whoosh()
    print("sounds written to", os.path.abspath(OUT))
