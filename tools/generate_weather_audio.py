"""Generates the weather sounds in assets/audio/weather (Iteration 17).

Original sounds, synthesised here from noise and simple envelopes: no
recordings, no third-party material, no network. They may be redistributed
with the game (see assets/audio/weather/README.md). Deterministic: the same
files every run (fixed random seeds).

Usage: python3 tools/generate_weather_audio.py [name.wav ...]
With file names, only those files are written.
"""
import math
import os
import random
import struct
import sys
import wave

RATE = 22050
OUT = os.path.join(os.path.dirname(__file__), "..", "assets", "audio", "weather")
ONLY = set(sys.argv[1:])


def write(name, samples):
    if ONLY and name not in ONLY:
        return
    path = os.path.join(OUT, name)
    with wave.open(path, "wb") as w:
        w.setnchannels(1)
        w.setsampwidth(2)
        w.setframerate(RATE)
        w.writeframes(b"".join(struct.pack("<h", int(max(-1, min(1, s)) * 32000)) for s in samples))
    print("wrote", path)


def normalise(out, amp):
    peak = max(abs(s) for s in out) or 1.0
    return [s / peak * amp for s in out]


def loop_seam(out, fade_s):
    """Crossfades the tail into the head so the sound loops without a click."""
    n = len(out)
    fade = int(fade_s * RATE)
    for i in range(fade):
        a = i / fade
        out[i] = out[i] * a + out[n - fade + i] * (1 - a)
    return out[: n - fade]


def smooth_noise(n, smooth, seed):
    random.seed(seed)
    out, v = [], 0.0
    for _ in range(n):
        v += (random.uniform(-1, 1) - v) * smooth
        out.append(v)
    return out


def breeze(dur, amp):
    """A light wind over the deck: two soft airy layers and slow, irregular
    gusts; no whistle, so it stays pleasant for hours."""
    n = int(dur * RATE)
    low = smooth_noise(n, 0.05, 101)
    air = smooth_noise(n, 0.22, 103)
    out = []
    for i in range(n):
        t = i / RATE
        gust = 0.55 + 0.25 * math.sin(2 * math.pi * 0.11 * t + 0.6) + 0.2 * math.sin(2 * math.pi * 0.29 * t + 2.1) ** 2
        out.append((low[i] * 1.4 + air[i] * 0.5) * gust)
    return loop_seam(normalise(out, amp), 1.0)


def water(dur, amp):
    """Water along the hull: a low wash with a slow rhythm of small waves
    slapping, and a little fizz as each one breaks."""
    n = int(dur * RATE)
    wash = smooth_noise(n, 0.015, 107)
    fizz = smooth_noise(n, 0.6, 109)
    random.seed(113)
    slaps = []
    t = 0.3
    while t < dur:
        slaps.append((t, random.uniform(0.6, 1.0)))
        t += random.uniform(1.1, 2.3)
    out = []
    for i in range(n):
        t = i / RATE
        s = wash[i] * 3.0 * (0.7 + 0.3 * math.sin(2 * math.pi * 0.17 * t))
        for start, strength in slaps:
            u = t - start
            if 0.0 <= u < 0.9:
                env = math.sin(math.pi * min(u / 0.12, 1.0)) * math.exp(-u * 4.0) * strength
                s += env * (wash[i] * 4.0 + fizz[i] * 0.35)
        out.append(s)
    return loop_seam(normalise(out, amp), 1.0)


def rain(dur, amp):
    """Rain: a soft hiss with many small drops, a few heavier ones."""
    n = int(dur * RATE)
    hiss = smooth_noise(n, 0.75, 127)
    out = [h * 0.25 for h in hiss]
    random.seed(131)
    drops = int(dur * 260)
    for _ in range(drops):
        start = random.randrange(0, n)
        freq = random.uniform(1800, 5200)
        strength = random.uniform(0.15, 0.6) if random.random() > 0.06 else random.uniform(0.8, 1.2)
        length = int(0.012 * RATE)
        for k in range(length):
            i = start + k
            if i >= n:
                break
            u = k / RATE
            out[i] += strength * math.exp(-u * 380.0) * math.sin(2 * math.pi * freq * u)
    return loop_seam(normalise(out, amp), 0.6)


def thunder_near(dur, amp):
    """A thunderclap close by: a sharp crack, then a heavy roll that fades."""
    n = int(dur * RATE)
    random.seed(137)
    rumble = smooth_noise(n, 0.01, 139)
    bright = smooth_noise(n, 0.5, 149)
    out = []
    for i in range(n):
        t = i / RATE
        crack = bright[i] * math.exp(-t * 14.0) * (1.6 if t < 0.08 else 1.0)
        roll = (0.6 + 0.4 * math.sin(2 * math.pi * 2.3 * t) ** 2) * math.exp(-t * 0.8) * min(1.0, t / 0.05)
        out.append(rumble[i] * roll * 14.0 + crack)
    out = normalise(out, amp)
    fade = int(0.5 * RATE)
    for k in range(fade):
        out[n - 1 - k] *= k / fade
    return out


def thunder_far(dur, amp):
    """Distant thunder: no crack, a deep rumble that swells and rolls away."""
    n = int(dur * RATE)
    rumble = smooth_noise(n, 0.006, 151)
    out = []
    for i in range(n):
        t = i / RATE
        swell = math.sin(math.pi * min(t / dur, 1.0)) ** 1.5 * (0.7 + 0.3 * math.sin(2 * math.pi * 0.9 * t) ** 2)
        out.append(rumble[i] * swell)
    out = normalise(out, amp)
    fade = int(0.6 * RATE)
    for k in range(fade):
        out[n - 1 - k] *= k / fade
    return out


os.makedirs(OUT, exist_ok=True)
write("wind_breeze.wav", breeze(10.0, 0.35))
write("water_hull.wav", water(10.0, 0.35))
write("rain.wav", rain(6.0, 0.3))
write("thunder_near.wav", thunder_near(4.5, 0.5))
write("thunder_far.wav", thunder_far(6.0, 0.4))
