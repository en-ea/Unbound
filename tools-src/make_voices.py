"""Synthesises the little "talking" blips for villagers (our own, CC0): a few short voiced grunts per
character, played one every couple of letters while their words appear (see ui/dialogue_panel.gd).
Run: python3 tools-src/make_voices.py [names...]   (only the named voices, e.g. `wren`; all when none)
Each voice has its own random seed, so rebuilding one never changes the others.
"""
import os
import sys
import numpy as np
from scipy.io import wavfile
from scipy.signal import butter, sosfilt

RATE = 22050
OUT = os.path.join(os.path.dirname(__file__), "..", "game", "assets", "sounds")
rng = np.random.default_rng(11)


def formant(x, centre, width):
    sos = butter(2, [max(centre - width, 40), centre + width], btype="band", fs=RATE, output="sos")
    return sosfilt(sos, x)


def blip(pitch, length, vowels, rasp, wobble=0.04):
    n = int(length * RATE)
    t = np.arange(n) / RATE
    f = pitch * (1 + wobble * np.sin(2 * np.pi * 7 * t)) * np.linspace(1.08, 0.92, n)
    phase = 2 * np.pi * np.cumsum(f) / RATE
    voice = np.sign(np.sin(phase)) * 0.5 + np.sin(phase) * 0.5          # a buzzy glottal-ish wave
    voice = voice + rasp * rng.normal(0, 1, n)
    out = sum(formant(voice, c, w) * g for c, w, g in vowels)
    env = np.minimum(t / 0.008, 1) * np.exp(-t / (length * 0.45))
    return out * env


def hum(pitch, length, contour, breath=0.06):
    """A different style: a round, sung little "mm-hm" syllable. A soft sine-ish tone with a few
    harmonics, a pitch glide (rise, fall, rise-fall or dip), a breathy consonant tick at the start."""
    n = int(length * RATE)
    t = np.arange(n) / RATE
    u = t / length
    shapes = {"rise": 0.9 + 0.25 * u, "fall": 1.15 - 0.25 * u,
              "arch": 0.95 + 0.3 * np.sin(np.pi * u), "dip": 1.1 - 0.22 * np.sin(np.pi * u)}
    f = pitch * shapes[contour] * (1 + 0.025 * np.sin(2 * np.pi * 9 * t))
    phase = 2 * np.pi * np.cumsum(f) / RATE
    tone = np.sin(phase) + 0.35 * np.sin(2 * phase) + 0.12 * np.sin(3 * phase)
    tone = formant(tone, 300, 180) * 1.0 + formant(tone, 1000, 350) * 0.35 + tone * 0.15
    air = formant(rng.normal(0, 1, n), 3500, 1200) * breath
    tick = np.exp(-t / 0.006) * formant(rng.normal(0, 1, n), 2500, 900) * 0.5      # a soft "p"/"t"
    env = np.minimum(t / 0.014, 1) * np.minimum((length - t) / 0.025, 1) ** 1.5
    return (tone + air) * env + tick


def save(name, x, peak=0.7):
    x = x / (np.max(np.abs(x)) + 1e-9) * peak
    wavfile.write(os.path.join(OUT, name + ".wav"), RATE, (x * 32767).astype(np.int16))


# name: (base pitch Hz, blip length, rasp, vowel formants)
VOICES = {
    "brakk": (58, 0.11, 0.25, [[(300, 70, 1.0), (700, 120, 0.5)], [(250, 60, 1.0), (520, 100, 0.6)],
                               [(360, 80, 1.0), (800, 140, 0.4)], [(220, 60, 1.0), (600, 90, 0.7)]]),
    "morrow": (84, 0.1, 0.9, [[(420, 90, 1.0), (1100, 160, 0.3)], [(320, 80, 1.0), (800, 140, 0.4)],
                              [(500, 100, 1.0), (1500, 200, 0.25)], [(280, 70, 1.0), (700, 120, 0.4)]]),
}
# Hummed voices: name -> (base pitch Hz, syllable length, contours of each clip)
HUMS = {
    "wren": (175, 0.11, ["rise", "arch", "fall", "dip", "arch", "rise", "fall", "arch"]),
}
only = sys.argv[1:]
for name, (pitch, length, rasp, sets) in VOICES.items():
    if only and name not in only:
        continue
    rng = np.random.default_rng(sum(map(ord, name)))
    for i, vowels in enumerate(sets):
        save(f"voice_{name}_{i}", blip(pitch * rng.uniform(0.92, 1.1), length * rng.uniform(0.9, 1.1), vowels, rasp))
for name, (pitch, length, contours) in HUMS.items():
    if only and name not in only:
        continue
    rng = np.random.default_rng(sum(map(ord, name)))
    for i, c in enumerate(contours):
        save(f"voice_{name}_{i}", hum(pitch * rng.uniform(0.9, 1.12), length * rng.uniform(0.85, 1.15), c), 0.6)
print("voices written")
