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


def ambience():
    secs = 14
    n = secs * RATE
    t = np.arange(n) / RATE
    wind = low(np.cumsum(rng.normal(size=n)) * 0.02, 500)
    wind = wind - low(wind, 40)
    gust = 0.6 + 0.4 * np.sin(2 * np.pi * t / secs) * np.sin(2 * np.pi * 3 * t / secs)
    leaves = band(rng.normal(size=n), 2000, 6000) * 0.04 * (0.5 + 0.5 * np.sin(2 * np.pi * 2 * t / secs) ** 2)
    save("amb_day", loopable(wind * gust + leaves, 1.0), 0.5)

    secs = 12
    n = secs * RATE
    t = np.arange(n) / RATE
    night = low(rng.normal(size=n), 300) * 0.05
    for c in range(3):
        freq = 4300 + c * 350
        rate = 2.6 + c * 0.7
        pulse = (np.sin(2 * np.pi * rate * t + c) > 0.55).astype(float)
        trill = (np.sin(2 * np.pi * 38 * t) > 0).astype(float)
        crick = np.sin(2 * np.pi * freq * t) * low(pulse * trill, 400) * (0.3 + 0.2 * np.sin(2 * np.pi * t / secs * (c + 1)))
        night += crick * (0.25 - c * 0.05)
    save("amb_night", loopable(night, 1.0), 0.45)


def birds():
    for i in range(4):
        dur = 0.25 + 0.15 * i
        n = int(dur * RATE)
        t = np.arange(n) / RATE
        notes = 2 + i
        seg = np.floor(t / dur * notes)
        base = 2200 + 500 * np.sin(seg * 1.7 + i)
        sweep = base + 900 * np.sin(np.pi * (t * notes / dur % 1)) * (1 if i % 2 else -1)
        phase = 2 * np.pi * np.cumsum(sweep) / RATE
        note_env = np.sin(np.pi * (t * notes / dur % 1)) ** 2
        save(f"bird_{i}", np.sin(phase + 0.8 * np.sin(phase * 0.5)) * note_env * env(n, 0.02, 0.5), 0.35)


def hum():
    secs = 10
    n = secs * RATE
    t = np.arange(n) / RATE
    x = sum(np.sin(2 * np.pi * f * t) * a for f, a in [(110, 1), (110.4, 0.8), (165, 0.5), (220.3, 0.3), (330, 0.12)])
    x *= 0.7 + 0.3 * np.sin(2 * np.pi * t / secs * 2)
    x += band(rng.normal(size=n), 800, 2400) * 0.03
    save("hum", loopable(x, 1.0), 0.4)


if __name__ == "__main__":
    os.makedirs(OUT, exist_ok=True)
    steps()
    ambience()
    birds()
    hum()
    print("sounds written to", os.path.abspath(OUT))
