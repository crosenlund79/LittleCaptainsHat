"""Score model for the Little Captain's Hat soundtrack.

Time is measured in quarter-note beats from the start of the piece. A piece
is a list of sections; each section has its own key, metre, tempo (with a
ramp from start to end) and parts. Every note is a plain Note; the renderer
turns beats into seconds through the tempo map.

Melodies are written in scale degrees relative to the section's key, so a
theme can be moved to another key, register or instrument unchanged:

    "1/q 5/q 6/e 5/e 3/q | 2/h. r/q"

- degree 1..7, optional accidental prefix b or #, octave marks ' (up) and , (down)
- duration after the slash: w h q e s (whole .. sixteenth), "." dotted,
  "t" triplet; "r" is a rest; "-" ties onto the previous note
- bar lines "|" are only for reading (they are checked against the metre)
"""

from __future__ import annotations

import dataclasses
import math
import random

MAJOR = [0, 2, 4, 5, 7, 9, 11]
DUR = {"w": 4.0, "h": 2.0, "q": 1.0, "e": 0.5, "s": 0.25}


@dataclasses.dataclass
class Note:
    beat: float  # absolute start, in quarter-note beats
    dur: float  # in beats
    pitch: int  # MIDI note
    vel: int  # 1..127
    part: str  # instrument part name
    strum: float = 0.0  # extra delay in seconds (rolled chords)


@dataclasses.dataclass
class Tempo:
    beat: float
    bpm: float


def degree_to_midi(degree: int, accidental: int, octave: int, tonic: int) -> int:
    """Scale degree (1..7) of the major scale on `tonic` (a MIDI note)."""
    return tonic + MAJOR[(degree - 1) % 7] + 12 * (octave + (degree - 1) // 7) + accidental


def parse_melody(spec: str, tonic: int) -> list[tuple[float, float, int | None]]:
    """Returns [(offset_beats, dur_beats, midi or None)] for a degree melody."""
    out: list[tuple[float, float, int | None]] = []
    t = 0.0
    for token in spec.replace("|", " ").split():
        pitch_part, _, dur_part = token.partition("/")
        dur = DUR[dur_part[0]]
        if "." in dur_part:
            dur *= 1.5
        if "t" in dur_part:
            dur *= 2.0 / 3.0
        if pitch_part == "-":
            o, d, p = out[-1]
            out[-1] = (o, d + dur, p)
        elif pitch_part == "r":
            out.append((t, dur, None))
        else:
            acc = 0
            s = pitch_part
            while s and s[0] in "b#":
                acc += -1 if s[0] == "b" else 1
                s = s[1:]
            octave = s.count("'") - s.count(",")
            degree = int(s.strip("',"))
            out.append((t, dur, degree_to_midi(degree, acc, octave, tonic)))
        t += dur
    return out


def melody_length(spec: str) -> float:
    return sum(d for _, d, _ in parse_melody(spec, 60))


# --- Chords --------------------------------------------------------------------------------------

QUALITIES = {
    "": [0, 4, 7], "m": [0, 3, 7], "7": [0, 4, 7, 10], "maj7": [0, 4, 7, 11], "m7": [0, 3, 7, 10],
    "sus4": [0, 5, 7], "sus2": [0, 2, 7], "add9": [0, 4, 7, 14], "madd9": [0, 3, 7, 14], "6": [0, 4, 7, 9],
    "m6": [0, 3, 7, 9], "dim": [0, 3, 6], "9": [0, 4, 7, 10, 14], "maj9": [0, 4, 7, 11, 14],
}


@dataclasses.dataclass
class Chord:
    root: int  # pitch class 0..11
    tones: list[int]  # pitch classes, root first
    bass: int  # pitch class of the bass
    symbol: str


def parse_chord(symbol: str, tonic_pc: int) -> Chord:
    """'1', '6m', '4maj7', '5sus4', '1/3', 'b7', '2m7/5' relative to the key."""
    body, _, slash = symbol.partition("/")
    acc = 0
    while body and body[0] in "b#":
        acc += -1 if body[0] == "b" else 1
        body = body[1:]
    degree = int(body[0])
    quality = body[1:]
    root = (tonic_pc + MAJOR[degree - 1] + acc) % 12
    tones = [(root + i) % 12 for i in QUALITIES[quality]]
    bass = root
    if slash:
        bacc = 0
        while slash[0] in "b#":
            bacc += -1 if slash[0] == "b" else 1
            slash = slash[1:]
        bass = (tonic_pc + MAJOR[int(slash) - 1] + bacc) % 12
    return Chord(root, tones, bass, symbol)


def parse_progression(spec: str, beats_per_bar: float, tonic_pc: int) -> list[tuple[float, float, Chord]]:
    """'1 | 4 | 6m 5 | 4:3 5:1' -> [(offset, dur, chord)] per bar (equal split,
    or explicit beat counts after a colon)."""
    out = []
    t = 0.0
    for bar in spec.split("|"):
        items = bar.split()
        if not items:
            continue
        explicit = [float(i.partition(":")[2]) if ":" in i else None for i in items]
        free = [e for e in explicit if e is None]
        rest = beats_per_bar - sum(e for e in explicit if e is not None)
        each = rest / len(free) if free else 0.0
        for item, e in zip(items, explicit):
            d = e if e is not None else each
            out.append((t, d, parse_chord(item.partition(":")[0], tonic_pc)))
            t += d
    return out


def nearest_with_pc(target: int, pcs: list[int], low: int = 0, high: int = 127) -> int:
    best = None
    for p in range(low, high + 1):
        if p % 12 in pcs and (best is None or abs(p - target) < abs(best - target)):
            best = p
    return best if best is not None else target


def voice_chord(chord: Chord, low: int, high: int, previous: list[int] | None, count: int = 4) -> list[int]:
    """A close-ish voicing of the chord between low and high, voice-led from
    the previous voicing (each voice moves to the nearest tone it may take)."""
    tones = chord.tones[:count] if len(chord.tones) >= count else chord.tones
    if previous and len(previous) == len(tones):
        result = []
        used = []
        for p in sorted(previous):
            options = [nearest_with_pc(p, [tc], low, high) for tc in tones if tc not in used] or [p]
            choice = min(options, key=lambda q: abs(q - p))
            used.append(choice % 12)
            result.append(choice)
        if len(set(n % 12 for n in result)) >= min(3, len(tones)):
            return sorted(result)
    centre = (low + high) // 2
    start = nearest_with_pc(centre - 6, [chord.tones[0]], low, high)
    voicing = [start]
    for tc in tones[1:]:
        p = voicing[-1] + 1
        while p % 12 != tc:
            p += 1
        voicing.append(p if p <= high else p - 12)
    return sorted(voicing)


# --- Phrase shaping --------------------------------------------------------------------------

def arc_velocity(base: int, position: float, swell: int = 10) -> int:
    """A gentle rise and fall over a phrase (position 0..1)."""
    return int(base + swell * math.sin(math.pi * max(0.0, min(1.0, position))))


class Rng(random.Random):
    """Seeded randomness so every render is identical."""

    def jitter(self, amount: float) -> float:
        return self.gauss(0.0, amount)


def augment(spec: str) -> str:
    """The same melody at half speed (every duration doubled)."""
    out = []
    for token in spec.split():
        if token == "|":
            out.append(token)
            continue
        pitch, _, dur = token.partition("/")
        letter, rest = dur[0], dur[1:]
        if letter == "w":
            out.append(f"{pitch}/w{rest}")
            out.append(f"-/w{rest}")
        else:
            out.append(f"{pitch}/{ {'h': 'w', 'q': 'h', 'e': 'q', 's': 'e'}[letter] }{rest}")
    return " ".join(out)


def double_bars(progression: str) -> str:
    """Each bar of a progression held for two bars (for an augmented melody)."""
    return " | ".join(bar.strip() + " | " + bar.strip() if " " not in bar.strip() and ":" not in bar
                      else " | ".join(_stretch(bar.strip())) for bar in progression.split("|"))


def _stretch(bar: str) -> list[str]:
    items = bar.split()
    if len(items) == 2:
        return items
    return [bar, bar]
