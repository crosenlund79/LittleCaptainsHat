"""Generates the TEMPORARY placeholder/test sounds in assets/audio/placeholder.

These are synthetic test signals used to verify audio bus routing and volume
settings. They are not game audio and are meant to be replaced.

Usage: python3 tools/generate_placeholder_audio.py
"""
import math
import os
import random
import struct
import wave

RATE = 22050
OUT = os.path.join(os.path.dirname(__file__), "..", "assets", "audio", "placeholder")


def write(name, samples):
    path = os.path.join(OUT, name)
    with wave.open(path, "wb") as w:
        w.setnchannels(1)
        w.setsampwidth(2)
        w.setframerate(RATE)
        w.writeframes(b"".join(struct.pack("<h", int(max(-1, min(1, s)) * 32000)) for s in samples))
    print("wrote", path)


def envelope(i, n, attack=0.01, release=0.05):
    t, dur = i / RATE, n / RATE
    return min(1.0, t / attack) * min(1.0, (dur - t) / release)


def tone(freq, dur, amp=0.4, attack=0.01, release=0.05):
    n = int(dur * RATE)
    return [amp * envelope(i, n, attack, release) * math.sin(2 * math.pi * freq * i / RATE) for i in range(n)]


def noise_loop(dur, amp, smooth, swell_hz):
    """Brown-ish noise with a slow swell. Starts and ends near silence-free
    continuity by crossfading the tail into the head so it loops cleanly."""
    random.seed(7)
    n = int(dur * RATE)
    out, v = [], 0.0
    for i in range(n):
        v += (random.uniform(-1, 1) - v) * smooth
        swell = 0.65 + 0.35 * math.sin(2 * math.pi * swell_hz * i / RATE)
        out.append(v * swell)
    peak = max(abs(s) for s in out) or 1.0
    out = [s / peak * amp for s in out]
    fade = int(0.5 * RATE)
    for i in range(fade):
        a = i / fade
        out[i] = out[i] * a + out[n - fade + i] * (1 - a)
    return out[: n - fade]


os.makedirs(OUT, exist_ok=True)
# Music bus test: a short, calm arpeggio (D major-ish).
arp = []
for f in (293.66, 369.99, 440.0, 587.33):
    arp += tone(f, 0.35, 0.35, 0.02, 0.2)
write("test_music_arpeggio.wav", arp)
# Ambience bus: soft wash loops for deck and cabin.
write("placeholder_ambience_deck.wav", noise_loop(6.0, 0.35, 0.08, 0.18))
write("placeholder_ambience_cabin.wav", noise_loop(6.0, 0.22, 0.02, 0.1))
# SFX bus test: a short two-tone blip.
write("test_sfx_blip.wav", tone(660, 0.07, 0.4) + tone(880, 0.09, 0.4))
# UI bus: a very short soft click.
write("ui_click.wav", tone(1200, 0.03, 0.25, 0.002, 0.02))
