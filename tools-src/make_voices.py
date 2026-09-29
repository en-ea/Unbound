"""Synthesises the little "talking" blips for villagers (our own, CC0): a few short voiced grunts per
character, played one every couple of letters while their words appear (see ui/dialogue_panel.gd).
Run: python3 tools-src/make_voices.py
"""
import os
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


def save(name, x, peak=0.7):
    x = x / (np.max(np.abs(x)) + 1e-9) * peak
    wavfile.write(os.path.join(OUT, name + ".wav"), RATE, (x * 32767).astype(np.int16))


# name: (base pitch Hz, blip length, rasp, vowel formants)
VOICES = {
    "wren": (118, 0.075, 0.35, [[(520, 120, 1.0), (1400, 200, 0.4)], [(400, 100, 1.0), (900, 160, 0.5)],
                                [(700, 140, 1.0), (1200, 180, 0.4)], [(330, 90, 1.0), (1900, 220, 0.3)]]),
    "brakk": (58, 0.11, 0.25, [[(300, 70, 1.0), (700, 120, 0.5)], [(250, 60, 1.0), (520, 100, 0.6)],
                               [(360, 80, 1.0), (800, 140, 0.4)], [(220, 60, 1.0), (600, 90, 0.7)]]),
}
for name, (pitch, length, rasp, sets) in VOICES.items():
    for i, vowels in enumerate(sets):
        save(f"voice_{name}_{i}", blip(pitch * rng.uniform(0.92, 1.1), length * rng.uniform(0.9, 1.1), vowels, rasp))
print("voices written")
