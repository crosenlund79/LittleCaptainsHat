#!/usr/bin/env python3
"""Builds the Little Captain's Hat soundtrack from its composition scripts.

    python3 tools/music/build.py [--soundfont PATH] [--only slug] [--out DIR]

Writes, per track: MIDI (tools/music/midi/), the game's OGG Vorbis file and a
timing sidecar (assets/audio/music/), and an analysis summary
(tools/music/analysis/). See tools/music/README.md.
"""

import argparse
import importlib
import json
import os
import sys

HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.dirname(os.path.dirname(HERE))
sys.path.insert(0, HERE)

from lch_music import render  # noqa: E402

TRACKS = [
    # slug, module, reverb seconds, damping
    ("home_upon_the_waves", "tracks.home_upon_the_waves", 2.3, 6500.0),
    ("the_wind_knows_the_way", "tracks.the_wind_knows_the_way", 1.9, 7500.0),
    ("lanterns_across_the_water", "tracks.lanterns_across_the_water", 3.2, 5200.0),
]


def audit(piece):
    """Strong-beat melody notes against the chord sounding at the time."""
    clashes, total = [], 0
    for sec_name, part, notes, sec in piece.lines:
        if not sec.chords:
            continue
        for beat, dur, pitch in notes:
            off = beat - sec.start
            if dur < 1.0 or not sec._strong(off):
                continue
            total += 1
            chord = sec.chord_at(off)
            if pitch % 12 not in chord.tones and pitch % 12 != chord.bass:
                clashes.append(f"{sec_name}/{part} bar {int(off // sec.meter) + 1}: {pitch} over {chord.symbol}")
    return total, clashes


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--soundfont", default=os.environ.get("LCH_SOUNDFONT", os.path.join(HERE, "soundfont", "GeneralUser-GS.sf2")))
    ap.add_argument("--only", default="")
    ap.add_argument("--out", default=os.path.join(ROOT, "assets", "audio", "music"))
    ap.add_argument("--work", default=os.path.join(HERE, "work"))
    ap.add_argument("--audit-only", action="store_true")
    args = ap.parse_args()
    os.makedirs(args.out, exist_ok=True)
    os.makedirs(os.path.join(HERE, "midi"), exist_ok=True)
    os.makedirs(os.path.join(HERE, "analysis"), exist_ok=True)
    for slug, module, reverb, damping in TRACKS:
        if args.only and args.only not in slug:
            continue
        piece = importlib.import_module(module).build()
        total, clashes = audit(piece)
        print(f"{piece.title}: {len(piece.notes)} notes, {len(piece.sections)} sections; "
              f"harmony audit {total - len(clashes)}/{total} strong-beat melody notes on chord tones")
        for c in clashes:
            print("   ", c)
        if args.audit_only:
            continue
        result = render.render_piece(piece, args.soundfont, args.work, slug, reverb_seconds=reverb, damping_hz=damping)
        tmap = result.pop("tmap")
        ogg = os.path.join(args.out, slug + ".ogg")
        render.encode_ogg(result["wav"], ogg)
        render.write_midi(piece, os.path.join(HERE, "midi", slug + ".mid"))
        sections = render.section_times(piece, tmap)
        meta = {"title": piece.title, "loop_seconds": round(result["loop_seconds"], 3),
                "phrases": render.phrase_starts(piece, tmap), "sections": sections}
        render.save_json(os.path.join(args.out, slug + ".json"), meta)
        summary = {k: (round(v, 2) if isinstance(v, float) else v) for k, v in result.items() if k not in ("short_term", "wav")}
        summary.update({"ogg_bytes": os.path.getsize(ogg), "notes": len(piece.notes), "sections": sections,
                        "short_term_lufs": [round(x, 1) for x in result["short_term"]]})
        render.save_json(os.path.join(HERE, "analysis", slug + ".json"), summary)
        print(f"   {result['loop_seconds'] / 60:.2f} min, {result['lufs']:.1f} LUFS, peak {result['peak_db']:.1f} dBFS, "
              f"limiter {result['limiter_db']:.1f} dB, {os.path.getsize(ogg) / 1e6:.1f} MB")


if __name__ == "__main__":
    main()
