"""Arranging: sections, tempo maps and the accompaniment figures.

A Piece collects sections one after another. Inside a section, methods
write melodies (from degree strings) and accompaniments (from the section's
chord progression) into the piece's note list. Everything is deterministic
(seeded), so a render can be reproduced exactly.
"""

from __future__ import annotations

import dataclasses
import math

from .score import (Chord, Note, Rng, Tempo, arc_velocity, nearest_with_pc, parse_melody,
                    parse_progression, voice_chord)

NOTE_NAMES = {"C": 0, "C#": 1, "Db": 1, "D": 2, "Eb": 3, "E": 4, "F": 5, "F#": 6, "Gb": 6, "G": 7,
              "Ab": 8, "A": 9, "Bb": 10, "B": 11}


@dataclasses.dataclass
class Part:
    """An instrument: General MIDI program in the SoundFont (bank 128 = drums)."""
    name: str
    program: int
    bank: int = 0
    pan: float = 0.0  # -1 left .. 1 right
    gain_db: float = 0.0
    reverb: float = 0.25  # send amount
    lowpass_hz: float = 0.0  # 0 = none (a "felt" piano uses ~2500)
    highpass_hz: float = 0.0
    legato: float = 1.0  # note length factor
    is_drums: bool = False


@dataclasses.dataclass
class SectionInfo:
    name: str
    start_beat: float
    beats: float
    bars: int
    meter: int
    key: str
    bpm_start: float
    bpm_end: float


class Piece:
    def __init__(self, title: str, parts: list[Part], seed: int):
        self.title = title
        self.parts = {p.name: p for p in parts}
        self.notes: list[Note] = []
        self.tempos: list[Tempo] = []
        self.sections: list[SectionInfo] = []
        self.automation: dict[str, list[tuple[float, float]]] = {}  # part -> [(beat, gain_db)]
        self.lines: list = []  # written melodies, for the harmony audit
        self.cursor = 0.0
        self.rng = Rng(seed)

    def section(self, name: str, bars: int, key: str, bpm: float | tuple[float, float], meter: int = 4,
                progression: str = "", rit: float = 0.0, phrase_breath: float = 0.03, octave: int = 4) -> "Section":
        start, end = (bpm, bpm) if isinstance(bpm, (int, float)) else bpm
        sec = Section(self, name, self.cursor, bars, meter, key, start, end, progression, rit, phrase_breath, octave)
        self.sections.append(SectionInfo(name, self.cursor, bars * meter, bars, meter, key, start, end))
        self.cursor += bars * meter
        return sec

    def total_beats(self) -> float:
        return self.cursor

    def set_gain(self, part: str, beat: float, gain_db: float) -> None:
        """Automation point: the part's level ramps linearly between points."""
        self.automation.setdefault(part, []).append((beat, gain_db))


class Section:
    def __init__(self, piece: Piece, name: str, start: float, bars: int, meter: int, key: str,
                 bpm_start: float, bpm_end: float, progression: str, rit: float, phrase_breath: float, octave: int):
        self.piece = piece
        self.name = name
        self.start = start
        self.bars = bars
        self.meter = meter
        self.key = key
        self.tonic_pc = NOTE_NAMES[key]
        self.tonic = 12 * (octave + 1) + self.tonic_pc  # melody register: degree 1 near middle C
        if self.tonic > 67:
            self.tonic -= 12
        self.rng = piece.rng
        self.chords = parse_progression(progression, meter, self.tonic_pc) if progression else []
        total = sum(d for _, d, _ in self.chords)
        if self.chords and abs(total - bars * meter) > 1e-6:
            raise ValueError(f"{piece.title}/{name}: progression is {total} beats, expected {bars * meter}")
        # Tempo map: a ramp across the section, a small breath at each phrase
        # end (every 4 bars) and an optional ritardando over the last bar.
        step = 0.5
        b = 0.0
        length = bars * meter
        while b < length - 1e-9:
            frac = b / length
            bpm = bpm_start + (bpm_end - bpm_start) * frac
            bar_index = int(b // meter)
            in_bar = b - bar_index * meter
            if (bar_index + 1) % 4 == 0 and in_bar >= meter - 1.0:
                bpm *= 1.0 - phrase_breath
            if rit > 0.0 and bar_index >= bars - 2:
                into = (b - (bars - 2) * meter) / (2 * meter)
                bpm *= 1.0 - rit * into
            piece.tempos.append(Tempo(start + b, bpm))
            b += step

    # --- Helpers -------------------------------------------------------------------------

    def bar_beat(self, bar: int) -> float:
        return self.start + bar * self.meter

    def chord_at(self, offset: float) -> Chord:
        for o, d, c in self.chords:
            if o <= offset + 1e-6 < o + d:
                return c
        return self.chords[-1][2]

    def chord_spans(self, from_bar: int = 0, to_bar: int | None = None):
        to_bar = self.bars if to_bar is None else to_bar
        lo, hi = from_bar * self.meter, to_bar * self.meter
        for o, d, c in self.chords:
            if lo - 1e-6 <= o < hi - 1e-6:
                yield o, min(d, hi - o), c

    def add(self, part: str, offset: float, dur: float, pitch: int, vel: int, strum: float = 0.0) -> None:
        if part not in self.piece.parts:
            raise KeyError(part)
        vel = max(8, min(118, int(vel)))
        jitter = self.rng.jitter(0.008)
        self.piece.notes.append(Note(self.start + offset, dur, pitch, vel, part, strum + jitter))

    def _strong(self, offset: float) -> bool:
        in_bar = offset % self.meter
        return abs(in_bar) < 1e-6 or (self.meter == 4 and abs(in_bar - 2.0) < 1e-6)

    # --- Melody ----------------------------------------------------------------------------

    def melody(self, part: str, spec: str, bar: int = 0, octave: int = 0, vel: int = 62, swell: int = 10,
               ornament: float = 0.0, legato: float | None = None, transpose: int = 0,
               fit: bool = False) -> list[tuple[float, float, int]]:
        """Writes a degree melody starting at `bar`. Returns [(offset, dur, pitch)]."""
        notes = parse_melody(spec, self.tonic + 12 * octave + transpose)
        length = sum(d for _, d, _ in notes)
        base = bar * self.meter
        if base + length > self.bars * self.meter + 1e-6:
            raise ValueError(f"{self.piece.title}/{self.name}: melody of {length} beats from bar {bar} overruns the section")
        self.piece.lines.append((self.name, part, [(self.start + base + o, d, p) for o, d, p in notes if p is not None],
                                 self))
        written = []
        events = [(base + o, d, p) for o, d, p in notes]
        if ornament > 0.0:
            events = self._ornament(events, ornament)
        if fit:
            events = [(o, d, self._fit(o, d, p)) if p is not None else (o, d, p) for o, d, p in events]
        art = legato if legato is not None else self.piece.parts[part].legato
        for o, d, p in events:
            if p is None:
                continue
            pos = (o - base) / max(length, 1e-6)
            v = arc_velocity(vel, pos, swell) + (4 if self._strong(o) else 0) + self.rng.randint(-3, 3)
            self.add(part, o, d * art, p, v)
            written.append((o, d, p))
        return written

    def _fit(self, offset: float, dur: float, pitch: int) -> int:
        """On strong beats, long non-chord tones move to the nearest chord tone."""
        if not self._strong(offset) or dur < 1.0 or not self.chords:
            return pitch
        chord = self.chord_at(offset)
        if pitch % 12 in chord.tones:
            return pitch
        return nearest_with_pc(pitch, chord.tones, pitch - 2, pitch + 2)

    def _ornament(self, events, amount: float):
        """Fills some leaps of a third with a passing note, and turns some
        long notes into a note with a neighbour: small, singer-like details."""
        out = []
        for i, (o, d, p) in enumerate(events):
            nxt = events[i + 1] if i + 1 < len(events) else None
            if p is not None and nxt and nxt[2] is not None and d >= 1.0 and self.rng.random() < amount:
                step = nxt[2] - p
                if abs(step) in (3, 4):
                    passing = p + (2 if step > 0 else -2)
                    passing = nearest_with_pc(passing, [(self.tonic_pc + s) % 12 for s in (0, 2, 4, 5, 7, 9, 11)],
                                              passing - 1, passing + 1)
                    out.append((o, d - 0.5, p))
                    out.append((o + d - 0.5, 0.5, passing))
                    continue
                if d >= 2.0:
                    upper = nearest_with_pc(p + 2, [(self.tonic_pc + s) % 12 for s in (0, 2, 4, 5, 7, 9, 11)], p + 1, p + 2)
                    out.append((o, d - 1.0, p))
                    out.append((o + d - 1.0, 0.5, upper))
                    out.append((o + d - 0.5, 0.5, p))
                    continue
            out.append((o, d, p))
        return out

    def harmony(self, part: str, line: list[tuple[float, float, int]], below: bool = True, vel: int = 48,
                legato: float = 1.0) -> None:
        """A second voice a diatonic third (or sixth) away, kept on chord tones."""
        scale = [(self.tonic_pc + s) % 12 for s in (0, 2, 4, 5, 7, 9, 11)]
        for o, d, p in line:
            chord = self.chord_at(o)
            target = p - 4 if below else p + 4
            options = [q for q in range(target - 2, target + 3) if q % 12 in scale]
            chord_options = [q for q in options if q % 12 in chord.tones]
            pick = min(chord_options or options, key=lambda q: abs(q - target))
            self.add(part, o, d * legato, pick, vel + self.rng.randint(-3, 3))

    def counter(self, part: str, low: int, high: int, vel: int = 46, rhythm: float = 2.0, from_bar: int = 0,
                to_bar: int | None = None, avoid: list[tuple[float, float, int]] | None = None, legato: float = 1.0,
                swell: int = 8) -> None:
        """A slow counter-line: chord tones, mostly by step, moving against the melody."""
        to_bar = self.bars if to_bar is None else to_bar
        prev = (low + high) // 2
        t = from_bar * self.meter
        end = to_bar * self.meter
        melody_at = {}
        for o, d, p in (avoid or []):
            k = o
            while k < o + d - 1e-6:
                melody_at[round(k, 3)] = p
                k += 0.5
        count = 0
        total = (end - t) / rhythm
        while t < end - 1e-6:
            chord = self.chord_at(t)
            candidates = [q for q in range(low, high + 1) if q % 12 in chord.tones]
            mel = melody_at.get(round(t, 3))

            def cost(q):
                c = abs(q - prev) + (0 if abs(q - prev) <= 2 else 2)
                if mel is not None and abs(q - mel) < 3:
                    c += 6
                if q == prev:
                    c += 1.5
                return c
            q = min(candidates, key=cost) if candidates else prev
            d = min(rhythm, end - t)
            self.add(part, t, d * legato, q, arc_velocity(vel, count / max(total, 1), swell))
            prev = q
            t += d
            count += 1

    # --- Accompaniments --------------------------------------------------------------------

    def fingerpick(self, part: str, vel: int = 50, from_bar: int = 0, to_bar: int | None = None,
                   bass_octave: int = 3, pattern: str = "arch", ring: float = 1.6) -> None:
        """Fingerpicked guitar: bass on the beat, the chord broken in eighths above."""
        for o, d, chord in self.chord_spans(from_bar, to_bar):
            bass = nearest_with_pc(12 * (bass_octave + 1) + 2, [chord.bass], 40, 55)
            upper = voice_chord(chord, bass + 7, bass + 24, None, 3)
            seq = {"arch": [0, 1, 2, 1], "rise": [0, 1, 2, 3], "roll": [1, 0, 2, 1]}[pattern]
            steps = int(round(d / 0.5))
            for i in range(steps):
                t = o + i * 0.5
                if i == 0 or (self.meter == 4 and i == 4 and d >= 4):
                    self.add(part, t, min(d - i * 0.5, 2.0) * ring, bass, vel + 6)
                    if i == 0:
                        continue
                k = seq[i % len(seq)]
                pool = upper + [upper[0] + 12]
                p = pool[k % len(pool)]
                accent = 4 if i % 2 == 0 else 0
                self.add(part, t, 1.0 * ring, p, vel - 6 + accent + self.rng.randint(-4, 3))

    def strum(self, part: str, vel: int = 46, from_bar: int = 0, to_bar: int | None = None,
              pattern: str = "D.DU.UDU") -> None:
        """Gently strummed guitar: rolled chords, softer up-strokes."""
        for o, d, chord in self.chord_spans(from_bar, to_bar):
            bass = nearest_with_pc(45, [chord.bass], 40, 52)
            shape = [bass] + voice_chord(chord, bass + 5, bass + 21, None, 4)
            steps = int(round(d / 0.5))
            for i in range(steps):
                symbol = pattern[(int(round((o % self.meter) / 0.5)) + i) % len(pattern)]
                if symbol == ".":
                    continue
                t = o + i * 0.5
                down = symbol == "D"
                strings = shape if down else list(reversed(shape[1:]))
                v = vel + (6 if (t % self.meter) < 1e-6 else 0) - (0 if down else 10)
                for k, p in enumerate(strings):
                    self.add(part, t, 0.9, p, v - k, strum=k * (0.014 if down else 0.010))

    def broken(self, part: str, vel: int = 44, from_bar: int = 0, to_bar: int | None = None,
               low: int = 38, sustain: float = 1.5, figure: str = "1-5-10-5") -> None:
        """Piano left hand: an open, rolling broken chord (root, fifth, tenth)."""
        for o, d, chord in self.chord_spans(from_bar, to_bar):
            root = nearest_with_pc(low + 5, [chord.bass], low, low + 12)
            fifth = nearest_with_pc(root + 7, [chord.tones[2 % len(chord.tones)]], root + 5, root + 9)
            third_up = nearest_with_pc(root + 15, [chord.tones[1]], root + 12, root + 17)
            octave = root + 12
            tones = {"1-5-10-5": [root, fifth, third_up, fifth], "1-5-8-10": [root, fifth, octave, third_up],
                     "1-10": [root, third_up]}[figure]
            steps = int(round(d / 0.5))
            for i in range(steps):
                p = tones[i % len(tones)]
                self.add(part, o + i * 0.5, sustain, p, vel - (0 if i % 2 == 0 else 6) + self.rng.randint(-3, 3))

    def block(self, part: str, vel: int = 40, from_bar: int = 0, to_bar: int | None = None, low: int = 52,
              high: int = 72, every: float | None = None, bass: bool = True, roll: float = 0.02) -> None:
        """Soft sustained piano chords (rolled a little), with an optional bass note."""
        prev = None
        for o, d, chord in self.chord_spans(from_bar, to_bar):
            step = every or d
            t = o
            while t < o + d - 1e-6:
                voicing = voice_chord(chord, low, high, prev, 3)
                prev = voicing
                hold = min(step, o + d - t)
                if bass:
                    self.add(part, t, hold, nearest_with_pc(low - 14, [chord.bass], low - 22, low - 10), vel + 2)
                for k, p in enumerate(voicing):
                    self.add(part, t, hold, p, vel - 2 + self.rng.randint(-3, 2), strum=k * roll)
                t += step

    def pad(self, part: str, vel: int = 40, from_bar: int = 0, to_bar: int | None = None, low: int = 50,
            high: int = 74, voices: int = 4, legato: float = 1.02) -> None:
        """Sustained, voice-led string chords."""
        prev = None
        for o, d, chord in self.chord_spans(from_bar, to_bar):
            voicing = voice_chord(chord, low, high, prev, voices)
            prev = voicing
            for p in voicing:
                self.add(part, o, d * legato, p, vel + self.rng.randint(-2, 2))

    def waltz(self, part: str, vel: int = 42, from_bar: int = 0, to_bar: int | None = None, low: int = 40) -> None:
        """Bass on one, a light chord on two and three."""
        prev = None
        for o, d, chord in self.chord_spans(from_bar, to_bar):
            t = o
            while t < o + d - 1e-6:
                beat = round(t % self.meter, 3)
                if beat == 0:
                    self.add(part, t, 1.0, nearest_with_pc(low + 5, [chord.bass], low, low + 11), vel + 4)
                else:
                    voicing = voice_chord(chord, 55, 72, prev, 3)
                    prev = voicing
                    for k, p in enumerate(voicing):
                        self.add(part, t, 0.8, p, vel - 6, strum=k * 0.012)
                t += 1.0

    def bass(self, part: str, vel: int = 52, from_bar: int = 0, to_bar: int | None = None, low: int = 31,
             walk: bool = True, pattern: str = "1-5") -> None:
        """Root on the downbeat, the fifth mid-bar, and a gentle approach note
        into the next chord now and then."""
        spans = list(self.chord_spans(from_bar, to_bar))
        for i, (o, d, chord) in enumerate(spans):
            root = nearest_with_pc(low + 7, [chord.bass], low, low + 12)
            self.add(part, o, min(d, 2.0) * 0.95, root, vel + 4)
            if d >= 3.0 and pattern == "1-5":
                fifth = nearest_with_pc(root + 7, [chord.tones[2 % len(chord.tones)]], root + 3, root + 9)
                self.add(part, o + (2.0 if self.meter == 4 else 2.0), min(d - 2.0, 2.0) * 0.9, fifth, vel - 4)
            if walk and i + 1 < len(spans) and d >= 2.0 and self.rng.random() < 0.45:
                nxt = nearest_with_pc(root, [spans[i + 1][2].bass], low, low + 12)
                if abs(nxt - root) >= 3:
                    approach = nxt + (-1 if nxt > root else 1) * (2 if self.rng.random() < 0.6 else 1)
                    self.add(part, o + d - 0.5, 0.45, approach, vel - 8)

    def harp(self, part: str, vel: int = 40, from_bar: int = 0, to_bar: int | None = None, low: int = 50,
             span: int = 24, rate: float = 0.5, descend_every: int = 2) -> None:
        """Rolling harp arpeggios across two octaves."""
        bar_count = 0
        for o, d, chord in self.chord_spans(from_bar, to_bar):
            tones = sorted({p for p in range(low, low + span + 1) if p % 12 in chord.tones})
            seq = tones if (bar_count % descend_every) == 0 else list(reversed(tones))
            steps = int(round(d / rate))
            for i in range(steps):
                self.add(part, o + i * rate, 1.5, seq[i % len(seq)], vel + self.rng.randint(-5, 3))
            bar_count += 1

    def brushes(self, part: str, vel: int = 30, from_bar: int = 0, to_bar: int | None = None, shaker: bool = True,
                snare: bool = True, kick: bool = False) -> None:
        """Very soft brush kit: a shaker in eighths, a brush tap on the back beats."""
        for bar in range(from_bar, self.bars if to_bar is None else to_bar):
            o = bar * self.meter
            for i in range(int(self.meter * 2)):
                t = o + i * 0.5
                if shaker:
                    self.add(part, t, 0.25, 70, vel - (0 if i % 2 == 0 else 8) + self.rng.randint(-4, 4))
            if snare:
                for b in ((1, 3) if self.meter == 4 else (2,)):
                    self.add(part, o + b, 0.25, 38, vel + 2 + self.rng.randint(-3, 3))
            if kick:
                self.add(part, o, 0.25, 36, vel + 6)

    def sparkle(self, part: str, spec: str, bar: int = 0, octave: int = 1, vel: int = 46) -> None:
        """A music-box/celesta phrase, high and soft."""
        self.melody(part, spec, bar=bar, octave=octave, vel=vel, swell=4)
