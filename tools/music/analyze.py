#!/usr/bin/env python3
"""Pictures of a track for review: a piano roll by instrument with the
sections marked, a spectrogram of the rendered audio, and the short-term
loudness. These help spot clashes, gaps, monotony or loud spots; they are
not a substitute for listening.

    python3 tools/music/analyze.py SLUG [--wav PATH] [--out DIR]
"""

import argparse
import importlib
import os
import sys

import numpy as np

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, HERE)

from lch_music import render  # noqa: E402

COLOURS = ["#1f77b4", "#d62728", "#2ca02c", "#9467bd", "#8c564b", "#e377c2", "#7f7f7f", "#bcbd22", "#17becf",
           "#ff7f0e", "#393b79", "#637939"]


def main():
    import matplotlib
    matplotlib.use("Agg")
    import matplotlib.pyplot as plt
    from scipy import signal
    from scipy.io import wavfile
    ap = argparse.ArgumentParser()
    ap.add_argument("slug")
    ap.add_argument("--wav", default="")
    ap.add_argument("--out", default=os.path.join(HERE, "analysis"))
    ap.add_argument("--start", type=float, default=0.0, help="seconds")
    ap.add_argument("--end", type=float, default=0.0)
    args = ap.parse_args()
    piece = importlib.import_module("tracks." + args.slug).build()
    tmap = render.TempoMap(piece)
    total = tmap.seconds(piece.total_beats())
    end = args.end or total
    fig, axes = plt.subplots(3 if args.wav else 1, 1, figsize=(22, 13 if args.wav else 6), squeeze=False)
    ax = axes[0][0]
    for i, name in enumerate(piece.parts):
        xs = [(tmap.seconds(n.beat), tmap.seconds(n.beat + n.dur) - tmap.seconds(n.beat), n.pitch, n.vel)
              for n in piece.notes if n.part == name]
        xs = [x for x in xs if args.start <= x[0] <= end]
        if not xs:
            continue
        for t, d, p, v in xs:
            ax.broken_barh([(t, d)], (p - 0.4, 0.8), color=COLOURS[i % len(COLOURS)], alpha=0.3 + 0.6 * v / 110)
        ax.plot([], [], color=COLOURS[i % len(COLOURS)], label=name, linewidth=6)
    for s in piece.sections:
        t = tmap.seconds(s.start_beat)
        if args.start <= t <= end:
            ax.axvline(t, color="k", linewidth=0.6)
            ax.text(t + 0.5, 100, f"{s.name}\n{s.key} {s.meter}/4 {s.bpm_start:g}-{s.bpm_end:g}", fontsize=7, va="top")
    ax.set_xlim(args.start, end)
    ax.set_ylim(28, 102)
    ax.set_title(f"{piece.title}: piano roll ({total / 60:.2f} min)")
    ax.legend(loc="lower right", ncol=6, fontsize=8)
    if args.wav:
        sr, audio = wavfile.read(args.wav)
        mono = audio.mean(axis=1)[int(args.start * sr): int(end * sr)]
        f, t, sxx = signal.spectrogram(mono, fs=sr, nperseg=4096, noverlap=2048)
        ax2 = axes[1][0]
        ax2.pcolormesh(t + args.start, f, 10 * np.log10(sxx + 1e-12), shading="auto", vmin=-130, vmax=-40, cmap="magma")
        ax2.set_ylim(0, 12000)
        ax2.set_title("spectrogram (0-12 kHz)")
        st = render.short_term(audio[int(args.start * sr): int(end * sr)], 1.0)
        ax3 = axes[2][0]
        ax3.plot(np.arange(len(st)) + args.start, st)
        ax3.set_ylim(-45, -10)
        ax3.set_xlim(args.start, end)
        ax3.grid(True)
        ax3.set_title("short-term loudness (LUFS, 1 s)")
    fig.tight_layout()
    os.makedirs(args.out, exist_ok=True)
    suffix = "" if not args.end else f"_{int(args.start)}_{int(end)}"
    path = os.path.join(args.out, f"{args.slug}{suffix}.png")
    fig.savefig(path, dpi=70)
    print(path)


if __name__ == "__main__":
    main()
