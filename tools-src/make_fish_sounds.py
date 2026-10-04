"""Synthesises the fishing sounds into game/assets/sounds/ (our own, CC0): the cast whoosh, the bobber's
plop when it lands or a fish bites, a splash when a fish breaks the water, the reel's ticking and the catch.
Uses the helpers in make_sounds.py. Run: python tools-src/make_fish_sounds.py
"""
import os
import numpy as np
import make_sounds as ms
from make_sounds import RATE, band, low, save, reverb
from make_fight_sounds import t_of, bell, place

rng = np.random.default_rng(23)


def cast():
    n, t = t_of(0.55)
    whoosh = band(rng.normal(size=n), 900, 3500) * np.sin(np.pi * t / t[-1]) ** 3
    save("fish_cast", whoosh, 0.5)


def plop():
    n, t = t_of(0.35)
    f = 520 * np.exp(-t * 9) + 180
    x = np.sin(2 * np.pi * np.cumsum(f) / RATE) * np.exp(-t * 16)
    x += band(rng.normal(size=n), 1200, 5000) * np.exp(-t * 30) * 0.4
    save("fish_plop", reverb(x, 0.3, 0.15), 0.6)


def splash():
    n, t = t_of(0.9)
    x = band(rng.normal(size=n), 400, 6000) * np.exp(-t * 6) * (1 + 0.5 * np.sin(2 * np.pi * 9 * t))
    x += low(rng.normal(size=n), 300) * np.exp(-t * 10)
    for k in range(6):                                  # droplets falling back
        m, tt = t_of(0.12)
        place(x, np.sin(2 * np.pi * rng.uniform(900, 1800) * tt) * np.exp(-tt * 40) * 0.25, 0.25 + k * 0.08)
    save("fish_splash", reverb(x, 0.4, 0.2), 0.65)


def reel():
    n, t = t_of(0.5)
    x = np.zeros(n)
    for k in range(10):                                 # the ratchet ticking
        m, tt = t_of(0.02)
        place(x, band(rng.normal(size=m), 3000, 8000) * np.exp(-tt * 300), k * 0.05)
    save("fish_reel", x, 0.45)


def caught():
    n, t = t_of(1.2)
    x = np.zeros(n)
    for i, f in enumerate([659.3, 784.0, 987.8]):
        m, tt = t_of(1.2 - i * 0.07)
        place(x, bell(f, tt, 4.0, 0.25), i * 0.07)
    save("fish_caught", reverb(x, 0.6, 0.25), 0.6)


if __name__ == "__main__":
    cast()
    plop()
    splash()
    reel()
    caught()
    print("fish sounds written to", os.path.abspath(ms.OUT))
