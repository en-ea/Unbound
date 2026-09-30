"""Synthesises the fight, feedback and story sounds into game/assets/sounds/ (our own, CC0): level-up
fanfare, kill finisher, critical, parry clang, perfect-dodge shimmer, shield block, bow shot and arrow hit,
sneak stab, the "spotted!" sting, fire (burst, cast, crackle loop), the shrine awakening and chest sparkle.
Uses the helpers in make_sounds.py. Run: python tools-src/make_fight_sounds.py
"""
import os
import numpy as np
import make_sounds as ms
from make_sounds import RATE, band, low, env, save, reverb

rng = np.random.default_rng(11)


def t_of(seconds):
    n = int(seconds * RATE)
    return n, np.arange(n) / RATE


def bell(f, t, decay=4.0, bright=0.35):
    """A struck bell-like tone with slightly inharmonic partials."""
    return (np.sin(2 * np.pi * f * t) + bright * np.sin(2 * np.pi * f * 2.76 * t) * np.exp(-t * decay * 1.5)
            + 0.2 * np.sin(2 * np.pi * f * 5.4 * t) * np.exp(-t * decay * 3)) * np.exp(-t * decay)


def place(buf, x, at):
    s = int(at * RATE)
    e = min(len(buf), s + len(x))
    buf[s:e] += x[: e - s]


def level_up():
    n, t = t_of(1.8)
    x = np.zeros(n)
    for i, f in enumerate([523.3, 659.3, 784.0, 1046.5]):      # C E G C, rising
        m, tt = t_of(1.8 - i * 0.09)
        place(x, bell(f, tt, 2.6), i * 0.09)
    m, tt = t_of(1.3)
    shimmer = band(rng.normal(size=m), 5000, 9000) * np.sin(np.pi * tt / tt[-1]) ** 2 * 0.25
    place(x, shimmer, 0.3)
    save("level_up", reverb(x, 0.9, 0.3), 0.7)


def kill():
    n, t = t_of(0.8)
    boom = np.sin(2 * np.pi * (80 - 40 * t) * t) * np.exp(-t * 6) + low(rng.normal(size=n), 300) * np.exp(-t * 14) * 0.8
    shing = band(rng.normal(size=n), 3000, 8000) * np.exp(-t * 18) * 0.5 + bell(1760, t, 7, 0.2) * 0.25
    save("kill", reverb(boom + shing, 0.5, 0.2), 0.75)


def crit():
    n, t = t_of(0.45)
    x = band(rng.normal(size=n), 2000, 7000) * np.exp(-t * 30) + bell(1318, t, 9, 0.5) * 0.5
    x += low(rng.normal(size=n), 400) * np.exp(-t * 25) * 0.8
    save("crit", x, 0.7)


def parry():
    n, t = t_of(1.0)
    clang = bell(987, t, 5, 0.6) + bell(1480, t, 7, 0.4) * 0.6
    clang += band(rng.normal(size=n), 2500, 8000) * np.exp(-t * 40) * 1.2
    save("parry", reverb(clang, 0.6, 0.25), 0.75)


def perfect_dodge():
    n, t = t_of(1.0)
    swell = np.linspace(0, 1, n) ** 3
    rev = band(rng.normal(size=n), 1500, 6000) * swell * (1 - np.clip((t - 0.85) / 0.15, 0, 1))
    tone = np.sin(2 * np.pi * (300 + 900 * t) * t) * swell * 0.4
    x = np.concatenate([np.zeros(int(0.02 * RATE)), rev + tone])
    save("perfect_dodge", x[::-1] * 0.3 + x, 0.55)


def block():
    n, t = t_of(0.4)
    x = low(rng.normal(size=n), 700) * np.exp(-t * 28) * 1.5 + np.sin(2 * np.pi * 220 * t) * np.exp(-t * 20) * 0.6
    x += band(rng.normal(size=n), 1200, 3000) * np.exp(-t * 45) * 0.4
    save("block", x, 0.7)


def bow():
    n, t = t_of(0.35)
    twang = np.sin(2 * np.pi * (180 + 40 * np.exp(-t * 30)) * t) * np.exp(-t * 14)
    swish = band(rng.normal(size=n), 1500, 5000) * np.exp(-((t - 0.08) / 0.05) ** 2) * 0.6
    save("bow_shot", twang + swish, 0.6)
    n, t = t_of(0.3)
    thunk = low(rng.normal(size=n), 900) * np.exp(-t * 35) * 1.5 + np.sin(2 * np.pi * 140 * t) * np.exp(-t * 25)
    save("arrow_hit", thunk, 0.6)


def stab():
    n, t = t_of(0.6)
    x = band(rng.normal(size=n), 800, 3000) * np.exp(-t * 40) + low(rng.normal(size=n), 250) * np.exp(-t * 9) * 1.4
    x += np.sin(2 * np.pi * (60 - 20 * t) * t) * np.exp(-t * 8) * 0.8
    save("sneak_kill", reverb(x, 0.4, 0.2), 0.75)


def spotted():
    n, t = t_of(0.7)
    f = 440 + 440 * np.clip(t / 0.12, 0, 1)
    ph = 2 * np.pi * np.cumsum(f) / RATE
    x = (np.sin(ph) + 0.4 * np.sin(2 * ph) + 0.2 * np.sin(3.01 * ph)) * env(n, 0.02, 2.5)
    save("spotted", reverb(x, 0.4, 0.2), 0.55)


def fire():
    n, t = t_of(0.9)
    whoomph = low(rng.normal(size=n), 600) * np.sin(np.pi * np.clip(t / 0.5, 0, 1)) ** 1.5 * np.exp(-t * 2.5) * 2
    crack = band(ms.grains(n, 300, 7), 1500, 6000) * np.exp(-t * 3) * 3
    save("fire_burst", reverb(whoomph + crack + np.sin(2 * np.pi * (70 - 30 * t) * t) * np.exp(-t * 5), 0.5, 0.2), 0.8)
    n, t = t_of(0.5)
    rise = band(rng.normal(size=n), 400, 2500) * (t / t[-1]) ** 2 * 1.2 + np.sin(2 * np.pi * (200 + 500 * t) * t) * (t / t[-1]) * 0.3
    save("fire_cast", rise, 0.55)
    n, t = t_of(3.0)
    crackle = band(ms.grains(n, 60, 9), 1200, 7000) * 5 + low(rng.normal(size=n), 300) * 0.35
    save("fire_loop", ms.loopable(crackle, 0.3), 0.45)


def shrine():
    n, t = t_of(4.5)
    swell = np.sin(np.pi * np.clip(t / 4.5, 0, 1)) ** 1.2
    chord = sum(np.sin(2 * np.pi * f * t + 0.3 * np.sin(2 * np.pi * 0.3 * k * t)) for k, f in enumerate([196, 294, 392, 494, 587]))
    x = chord * swell * 0.4 + band(rng.normal(size=n), 3000, 8000) * swell ** 3 * 0.15
    for i, f in enumerate([784, 988, 1175, 1568]):
        m, tt = t_of(4.5 - (1.6 + i * 0.25))
        place(x, bell(f, tt, 1.6) * 0.5, 1.6 + i * 0.25)
    save("shrine_wake", reverb(x, 1.5, 0.35), 0.7)


def chest():
    n, t = t_of(1.2)
    x = np.zeros(n)
    for i, f in enumerate([1318, 1568, 1976, 2637, 3136]):
        m, tt = t_of(1.2 - i * 0.05)
        place(x, bell(f, tt, 5, 0.2) * 0.6, i * 0.05)
    x += low(rng.normal(size=n), 250) * np.exp(-t * 20) * 0.8
    save("chest_burst", reverb(x, 0.7, 0.25), 0.65)


if __name__ == "__main__":
    level_up()
    kill()
    crit()
    parry()
    perfect_dodge()
    block()
    bow()
    stab()
    spotted()
    fire()
    shrine()
    chest()
    print("fight sounds written to", os.path.abspath(ms.OUT))
