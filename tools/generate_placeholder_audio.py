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


def engine_loop(dur, amp, cutoff_hz):
    """Diesel-like hum: 55 Hz with harmonics, a 27.5 Hz firing pulse and an
    8 Hz throb. Every component completes whole cycles in `dur` (2 s), so the
    loop is seamless. `cutoff_hz` applies a one-pole low-pass (run over two
    periods so the filter is settled and the loop still joins up), used for
    the muffled version heard below deck."""
    n = int(dur * RATE)
    base = []
    for i in range(n):
        t = i / RATE
        s = (0.55 * math.sin(2 * math.pi * 55 * t)
             + 0.30 * math.sin(2 * math.pi * 110 * t + 0.4)
             + 0.18 * math.sin(2 * math.pi * 165 * t + 1.1)
             + 0.10 * math.sin(2 * math.pi * 220 * t + 2.0)
             + 0.07 * math.sin(2 * math.pi * 330 * t + 0.7))
        pulse = 0.75 + 0.25 * max(0.0, math.sin(2 * math.pi * 27.5 * t)) ** 4
        throb = 0.85 + 0.15 * math.sin(2 * math.pi * 8 * t)
        base.append(s * pulse * throb)
    if cutoff_hz:
        k = 1 - math.exp(-2 * math.pi * cutoff_hz / RATE)
        y, out = 0.0, []
        for rep in range(2):
            out = []
            for s in base:
                y += (s - y) * k
                out.append(y)
        base = out
    peak = max(abs(s) for s in base) or 1.0
    return [s / peak * amp for s in base]


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
# SFX bus: engine loops (open air on deck, muffled below deck / at the chart).
write("engine_hum.wav", engine_loop(2.0, 0.5, 0))
write("engine_hum_muffled.wav", engine_loop(2.0, 0.5, 140))


def purr(dur, amp):
    """Soft cat purr: low filtered noise pulsing at ~26 Hz, in two breaths."""
    random.seed(11)
    n = int(dur * RATE)
    out, v = [], 0.0
    for i in range(n):
        t = i / RATE
        v += (random.uniform(-1, 1) - v) * 0.04
        pulse = 0.55 + 0.45 * math.sin(2 * math.pi * 26 * t) ** 2
        breath = math.sin(math.pi * ((t % (dur / 2)) / (dur / 2))) ** 0.8
        out.append(v * pulse * breath)
    peak = max(abs(s) for s in out) or 1.0
    return [s / peak * amp * envelope(i, n, 0.05, 0.2) for i, s in enumerate(out)]


def dog_pant(dur, amp):
    """Gentle, happy dog panting: short airy breaths, then a contented sigh."""
    random.seed(23)
    n = int(dur * RATE)
    out, v = [], 0.0
    for i in range(n):
        t = i / RATE
        v += (random.uniform(-1, 1) - v) * 0.25
        if t < dur * 0.65:
            phase = (t * 4.2) % 1.0
            breath = math.sin(math.pi * min(phase / 0.45, 1.0)) if phase < 0.45 else 0.0
            level = 0.8
        else:
            u = (t - dur * 0.65) / (dur * 0.35)
            breath = math.sin(math.pi * u) ** 1.5
            level = 0.55
        out.append(v * breath * level)
    peak = max(abs(s) for s in out) or 1.0
    return [s / peak * amp * envelope(i, n, 0.02, 0.15) for i, s in enumerate(out)]


# SFX bus: ship's companion responses to petting (soft, never harsh test tones).
write("companion_purr.wav", purr(1.6, 0.4))
write("companion_dog_pant.wav", dog_pant(1.6, 0.3))


def storm_wind(dur, amp):
    """Strong wind in the rigging (Iteration 005a): bright gusting noise with a
    faint whistle, crossfaded to loop. Played louder the stronger the wind."""
    random.seed(31)
    n = int(dur * RATE)
    out, v, w = [], 0.0, 0.0
    for i in range(n):
        t = i / RATE
        v += (random.uniform(-1, 1) - v) * 0.35
        w += (random.uniform(-1, 1) - w) * 0.03
        gust = 0.55 + 0.45 * math.sin(2 * math.pi * 0.23 * t + 1.3 * math.sin(2 * math.pi * 0.07 * t)) ** 2
        whistle = 0.08 * math.sin(2 * math.pi * (620 + 80 * math.sin(2 * math.pi * 0.3 * t)) * t)
        out.append((v * 0.7 + w * 0.6 + whistle) * gust)
    peak = max(abs(s) for s in out) or 1.0
    out = [s / peak * amp for s in out]
    fade = int(0.6 * RATE)
    for i in range(fade):
        a = i / fade
        out[i] = out[i] * a + out[n - fade + i] * (1 - a)
    return out[: n - fade]


def thunder(dur, amp):
    """Distant thunder (Iteration 005a): a soft crack, then a low rolling rumble."""
    random.seed(37)
    n = int(dur * RATE)
    out, v = [], 0.0
    for i in range(n):
        t = i / RATE
        v += (random.uniform(-1, 1) - v) * 0.012
        crack = random.uniform(-1, 1) * math.exp(-t * 18.0) * 0.3
        roll = (0.6 + 0.4 * math.sin(2 * math.pi * 1.7 * t) ** 2) * math.exp(-t * 0.9)
        out.append(v * roll * 9.0 + crack)
    peak = max(abs(s) for s in out) or 1.0
    return [s / peak * amp * envelope(i, n, 0.005, 0.4) for i, s in enumerate(out)]


# Ambience bus: hazardous weather (strong wind loop, occasional thunder).
write("storm_wind.wav", storm_wind(6.0, 0.4))
write("thunder.wav", thunder(3.5, 0.45))
