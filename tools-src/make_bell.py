"""Synthesises the village bell (our own, CC0): one stroke of a bronze bell, rung three times by the village
when a hearing, a public act or a rite is about to begin (studio/village/live.gd).
Run: py -3.11 tools-src/make_bell.py      -> game/assets/sounds/village_bell.wav

A bell's sound is a set of inharmonic partials (the hum, the prime, the tierce, the quint, the nominal, ...) that
die away at different speeds, over a short bright strike. The ratios are a church bell's.
"""
import os
import numpy as np
from scipy.io import wavfile

RATE = 22050
OUT = os.path.join(os.path.dirname(__file__), "..", "game", "assets", "sounds", "village_bell.wav")
rng = np.random.default_rng(5)

SECONDS = 2.6
BASE = 262.0          # the strike note (middle C)
# (ratio to the strike note, loudness, seconds to fall by 60 dB)
PARTIALS = [(0.5, 0.9, 2.6), (1.0, 1.0, 2.2), (1.19, 0.55, 1.7), (1.5, 0.45, 1.5), (2.0, 0.6, 1.2), (2.51, 0.3, 0.9),
            (3.0, 0.22, 0.7), (4.16, 0.16, 0.5), (5.43, 0.1, 0.35)]

t = np.arange(int(SECONDS * RATE)) / RATE
bell = np.zeros_like(t)
for ratio, level, decay in PARTIALS:
    detune = 1.0 + rng.uniform(-0.002, 0.002)                       # a real bell's partials beat a little
    beat = 1.0 + 0.15 * np.sin(2 * np.pi * rng.uniform(0.6, 2.4) * t)
    bell += level * np.sin(2 * np.pi * BASE * ratio * detune * t + rng.uniform(0, 6.28)) * np.exp(-t * 6.9 / decay) * beat
# the strike: a short bright tick
tick = rng.normal(0, 1, len(t)) * np.exp(-t / 0.004)
bell += 0.25 * tick
bell *= np.minimum(t / 0.002, 1.0)
bell = bell / np.max(np.abs(bell)) * 0.8
wavfile.write(OUT, RATE, (bell * 32767).astype(np.int16))
print("bell written")
