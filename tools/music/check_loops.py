#!/usr/bin/env python3
"""Loop-seam check for the rendered tracks: the sample step across the loop
point compared with ordinary sample-to-sample steps, and the loudness of the
last and first seconds (a seamless loop has no click and no sudden change).

    python3 tools/music/check_loops.py [DIR_WITH_WAVS_OR_OGGS]
"""

import os
import subprocess
import sys

import numpy as np

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, HERE)
from lch_music import render  # noqa: E402

SLUGS = ["home_upon_the_waves", "the_wind_knows_the_way", "lanterns_across_the_water"]


def load(path):
    if path.endswith(".wav"):
        from scipy.io import wavfile
        return wavfile.read(path)[1].astype(np.float64)
    raw = subprocess.run(["ffmpeg", "-loglevel", "error", "-i", path, "-f", "f32le", "-ac", "2", "-ar", "44100", "-"],
                         capture_output=True, check=True).stdout
    return np.frombuffer(raw, dtype=np.float32).reshape(-1, 2).astype(np.float64)


def main():
    folder = sys.argv[1] if len(sys.argv) > 1 else os.path.join(os.path.dirname(os.path.dirname(HERE)), "assets", "audio", "music")
    ok = True
    for slug in SLUGS:
        path = next((os.path.join(folder, slug + ext) for ext in (".wav", ".ogg") if os.path.exists(os.path.join(folder, slug + ext))), None)
        if not path:
            continue
        a = load(path)
        sr = 44100
        steps = np.abs(np.diff(a, axis=0)).max(axis=1)
        typical = np.percentile(steps, 99.9)
        seam = np.abs(a[0] - a[-1]).max()
        joined = np.concatenate([a[-3 * sr:], a[:3 * sr]])
        st = render.short_term(joined.astype(np.float32), 0.5)
        end, start = st[:6].mean(), st[6:].mean()
        verdict = seam <= typical * 1.5 and abs(end - start) < 6.0
        ok = ok and verdict
        print(f"{slug}: {len(a) / sr / 60:.2f} min, seam step {seam:.4f} (99.9th percentile step {typical:.4f}), "
              f"last 3 s {end:.1f} LUFS -> first 3 s {start:.1f} LUFS, peak {20 * np.log10(np.abs(a).max()):.1f} dBFS: "
              f"{'smooth' if verdict else 'CHECK'}")
    sys.exit(0 if ok else 1)


if __name__ == "__main__":
    main()
