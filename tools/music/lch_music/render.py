"""Rendering a Piece to audio and MIDI.

- Each part is rendered on its own through TinySoundFont with the
  GeneralUser GS SoundFont, then filtered, panned and level-automated.
- A shared reverb (a synthetic, softly damped stereo room/hall impulse,
  convolved) gives the parts one space.
- Mastering: a gentle high-shelf cut (no harsh highs), loudness normalised to
  a target (ITU-R BS.1770 style, K-weighted and gated), and a soft peak
  limiter keeping true-ish peaks well below full scale.
- Looping: the audio after the loop point (release and reverb tail) is folded
  onto the start, so the file loops seamlessly at exactly the musical length.
"""

from __future__ import annotations

import bisect
import json
import math
import os
import subprocess

import numpy as np
from scipy import signal

from .arrange import Piece

SR = 44100


# --- Time ----------------------------------------------------------------------------------------

class TempoMap:
    def __init__(self, piece: Piece):
        tempos = sorted(piece.tempos, key=lambda t: t.beat)
        self.beats = [t.beat for t in tempos]
        self.bpm = [t.bpm for t in tempos]
        self.secs = [0.0]
        for i in range(1, len(tempos)):
            self.secs.append(self.secs[-1] + (self.beats[i] - self.beats[i - 1]) * 60.0 / self.bpm[i - 1])

    def seconds(self, beat: float) -> float:
        i = max(0, bisect.bisect_right(self.beats, beat) - 1)
        return self.secs[i] + (beat - self.beats[i]) * 60.0 / self.bpm[i]


# --- Synthesis ------------------------------------------------------------------------------------

def render_part(piece: Piece, part_name: str, tmap: TempoMap, total_seconds: float, soundfont: str) -> np.ndarray:
    import tinysoundfont
    part = piece.parts[part_name]
    synth = tinysoundfont.Synth(samplerate=SR, gain=-6.0)
    sfid = synth.sfload(soundfont, max_voices=128)
    synth.program_select(0, sfid, part.bank, part.program, is_drums=part.is_drums)
    synth.control_change(0, 7, 110)
    synth.control_change(0, 11, 127)
    # One sounding instance per key: a key struck again while still sounding
    # is released a moment before the new strike.
    timed = []
    for n in sorted((n for n in piece.notes if n.part == part_name), key=lambda n: n.beat):
        on = max(0.0, tmap.seconds(n.beat) + n.strum)
        off = tmap.seconds(n.beat + n.dur) + max(n.strum, 0.0)
        timed.append([on, max(off, on + 0.03), n.pitch, n.vel])
    by_pitch: dict[int, list] = {}
    for e in sorted(timed, key=lambda e: e[0]):
        prev = by_pitch.get(e[2])
        if prev is not None and prev[1] > e[0] - 0.005:
            prev[1] = max(prev[0] + 0.02, e[0] - 0.005)
        by_pitch[e[2]] = e
    events = []
    for on, off, pitch, vel in timed:
        events.append((on, 1, pitch, vel))
        events.append((off, 0, pitch, 0))
    events.sort(key=lambda e: (e[0], e[1]))
    total = int((total_seconds + 10.0) * SR)
    out = np.zeros((total, 2), dtype=np.float32)
    pos = 0
    for t, kind, pitch, vel in events:
        target = min(total, max(pos, int(t * SR)))
        if target > pos:
            buf = np.frombuffer(synth.generate(target - pos), dtype=np.float32).reshape(-1, 2)
            out[pos:target] = buf
            pos = target
        if kind == 1:
            synth.noteon(0, int(pitch), int(vel))
        else:
            synth.noteoff(0, int(pitch))
    if total > pos:
        out[pos:] = np.frombuffer(synth.generate(total - pos), dtype=np.float32).reshape(-1, 2)
    # Shaping.
    if part.lowpass_hz:
        sos = signal.butter(4, part.lowpass_hz, "low", fs=SR, output="sos")
        out = signal.sosfilt(sos, out, axis=0).astype(np.float32)
    if part.highpass_hz:
        sos = signal.butter(2, part.highpass_hz, "high", fs=SR, output="sos")
        out = signal.sosfilt(sos, out, axis=0).astype(np.float32)
    angle = (part.pan + 1.0) * math.pi / 4.0
    out[:, 0] *= math.cos(angle) * math.sqrt(2.0)
    out[:, 1] *= math.sin(angle) * math.sqrt(2.0)
    gain = np.full(total, 10 ** (part.gain_db / 20.0), dtype=np.float32)
    points = sorted(piece.automation.get(part_name, []))
    if points:
        times = np.array([tmap.seconds(b) * SR for b, _ in points])
        dbs = np.array([g for _, g in points])
        idx = np.arange(total)
        gain *= (10 ** (np.interp(idx, times, dbs) / 20.0)).astype(np.float32)
    out *= gain[:, None]
    return out


# --- Space ----------------------------------------------------------------------------------------

def impulse(seconds: float, damping_hz: float, seed: int, predelay: float = 0.018) -> np.ndarray:
    """A soft stereo reverb impulse: decorrelated noise with an exponential
    decay that darkens over time, plus a few early reflections."""
    rng = np.random.default_rng(seed)
    n = int(seconds * SR)
    t = np.arange(n) / SR
    env = np.exp(-6.9 * t / seconds)  # -60 dB at `seconds`
    ir = np.zeros((n + int(predelay * SR), 2), dtype=np.float64)
    for ch in range(2):
        noise = rng.standard_normal(n) * env
        # Darken progressively: split into blocks with falling cutoff.
        blocks = 12
        shaped = np.zeros(n)
        for b in range(blocks):
            lo, hi = b * n // blocks, (b + 1) * n // blocks
            cutoff = max(900.0, damping_hz * (1.0 - 0.75 * b / blocks))
            sos = signal.butter(1, cutoff, "low", fs=SR, output="sos")
            shaped[lo:hi] = signal.sosfilt(sos, noise[lo:hi])
        ir[int(predelay * SR):, ch] = shaped
        for k, (delay, level) in enumerate([(0.011, 0.5), (0.019, 0.35), (0.027, 0.3), (0.041, 0.22)]):
            d = int((delay + 0.003 * ch * (k % 2)) * SR)
            ir[d, ch] += level
    ir /= np.sqrt(np.sum(ir ** 2) / 2.0)
    return ir.astype(np.float32)


def convolve(dry: np.ndarray, ir: np.ndarray) -> np.ndarray:
    wet = np.zeros_like(dry)
    for ch in range(2):
        wet[:, ch] = signal.oaconvolve(dry[:, ch], ir[:, ch], mode="full")[: len(dry)]
    return wet


# --- Mastering ------------------------------------------------------------------------------------

def k_weight(x: np.ndarray) -> np.ndarray:
    # BS.1770 pre-filter (high shelf) and RLB high-pass, at 44.1 kHz (re-derived for SR).
    f0, g, q = 1681.974450955533, 3.999843853973347, 0.7071752369554196
    k = math.tan(math.pi * f0 / SR)
    vh = 10 ** (g / 20)
    vb = vh ** 0.4996667741545416
    a0 = 1 + k / q + k * k
    b = [(vh + vb * k / q + k * k) / a0, 2 * (k * k - vh) / a0, (vh - vb * k / q + k * k) / a0]
    a = [1, 2 * (k * k - 1) / a0, (1 - k / q + k * k) / a0]
    y = signal.lfilter(b, a, x, axis=0)
    f0, q = 38.13547087602444, 0.5003270373238773
    k = math.tan(math.pi * f0 / SR)
    a0 = 1 + k / q + k * k
    b = [1, -2, 1]
    a = [1, 2 * (k * k - 1) / a0, (1 - k / q + k * k) / a0]
    return signal.lfilter(b, a, y, axis=0)


def loudness(x: np.ndarray) -> float:
    """Integrated loudness (LUFS), gated as in BS.1770."""
    y = k_weight(x.astype(np.float64))
    block, hop = int(0.4 * SR), int(0.1 * SR)
    powers = []
    for start in range(0, len(y) - block, hop):
        seg = y[start:start + block]
        powers.append(np.mean(seg ** 2, axis=0).sum())
    powers = np.array(powers)
    lk = -0.691 + 10 * np.log10(powers + 1e-12)
    gated = powers[lk > -70]
    rel = -0.691 + 10 * np.log10(np.mean(gated) + 1e-12) - 10
    gated = powers[(lk > -70) & (lk > rel)]
    return float(-0.691 + 10 * np.log10(np.mean(gated) + 1e-12))


def short_term(x: np.ndarray, seconds: float = 3.0) -> np.ndarray:
    y = k_weight(x.astype(np.float64))
    block = int(seconds * SR)
    out = []
    for start in range(0, len(y) - block, block):
        seg = y[start:start + block]
        out.append(-0.691 + 10 * np.log10(np.mean(seg ** 2, axis=0).sum() + 1e-12))
    return np.array(out)


def high_shelf(x: np.ndarray, freq: float, gain_db: float) -> np.ndarray:
    a_lin = 10 ** (gain_db / 40)
    w0 = 2 * math.pi * freq / SR
    alpha = math.sin(w0) / 2 * math.sqrt(2)
    cosw = math.cos(w0)
    b0 = a_lin * ((a_lin + 1) + (a_lin - 1) * cosw + 2 * math.sqrt(a_lin) * alpha)
    b1 = -2 * a_lin * ((a_lin - 1) + (a_lin + 1) * cosw)
    b2 = a_lin * ((a_lin + 1) + (a_lin - 1) * cosw - 2 * math.sqrt(a_lin) * alpha)
    a0 = (a_lin + 1) - (a_lin - 1) * cosw + 2 * math.sqrt(a_lin) * alpha
    a1 = 2 * ((a_lin - 1) - (a_lin + 1) * cosw)
    a2 = (a_lin + 1) - (a_lin - 1) * cosw - 2 * math.sqrt(a_lin) * alpha
    return signal.lfilter([b0 / a0, b1 / a0, b2 / a0], [1, a1 / a0, a2 / a0], x, axis=0)


def soft_limit(x: np.ndarray, ceiling_db: float = -3.0) -> tuple[np.ndarray, float]:
    """A smooth peak limiter: the needed gain is held over a 30 ms window and
    averaged over the same window, so it never overshoots and never clicks.
    Returns the audio and the deepest gain reduction in dB."""
    from scipy.ndimage import minimum_filter1d, uniform_filter1d
    ceiling = 10 ** (ceiling_db / 20)
    peak = np.max(np.abs(x), axis=1)
    need = np.minimum(1.0, ceiling / np.maximum(peak, 1e-9))
    w = int(0.03 * SR)
    g = uniform_filter1d(minimum_filter1d(need, size=2 * w + 1), size=2 * w + 1)
    return (x * g[:, None]).astype(np.float32), float(20 * math.log10(max(float(g.min()), 1e-9)))


# --- Whole piece ----------------------------------------------------------------------------------

def render_piece(piece: Piece, soundfont: str, out_dir: str, slug: str, reverb_seconds: float = 2.4,
                 damping_hz: float = 6000.0, target_lufs: float = -20.0, wet: float = 1.0) -> dict:
    tmap = TempoMap(piece)
    loop_seconds = tmap.seconds(piece.total_beats())
    stems = {}
    for name in piece.parts:
        if any(n.part == name for n in piece.notes):
            stems[name] = render_part(piece, name, tmap, loop_seconds, soundfont)
    dry = sum(stems.values())
    send = sum(stems[n] * piece.parts[n].reverb for n in stems)
    ir = impulse(reverb_seconds, damping_hz, seed=hash(slug) & 0xFFFF)
    mix = dry + convolve(send, ir) * 0.55 * wet
    mix = high_shelf(mix, 7500.0, -2.5)
    # Fold the tail after the loop point back onto the start.
    loop_n = int(round(loop_seconds * SR))
    tail = mix[loop_n:]
    audio = mix[:loop_n].copy()
    audio[: len(tail)] += tail[: len(audio)]
    gain = 10 ** ((target_lufs - loudness(audio)) / 20)
    audio *= gain
    audio, reduction = soft_limit(audio, -3.0)
    lufs = loudness(audio)
    peak_db = 20 * math.log10(np.max(np.abs(audio)) + 1e-12)
    os.makedirs(out_dir, exist_ok=True)
    wav = os.path.join(out_dir, slug + ".wav")
    from scipy.io import wavfile
    wavfile.write(wav, SR, audio.astype(np.float32))
    return {"loop_seconds": loop_seconds, "lufs": lufs, "peak_db": peak_db, "limiter_db": reduction,
            "wav": wav, "short_term": short_term(audio).tolist(), "tmap": tmap}


def encode_ogg(wav: str, ogg: str, quality: float = 5.0) -> None:
    subprocess.run(["ffmpeg", "-y", "-loglevel", "error", "-i", wav, "-c:a", "libvorbis", "-q:a", str(quality),
                    "-ar", str(SR), ogg], check=True)


# --- MIDI -----------------------------------------------------------------------------------------

def write_midi(piece: Piece, path: str) -> None:
    import mido
    tpb = 480
    mid = mido.MidiFile(type=1, ticks_per_beat=tpb)
    conductor = mido.MidiTrack()
    conductor.append(mido.MetaMessage("track_name", name=piece.title, time=0))
    last = 0
    last_bpm = None
    for t in sorted(piece.tempos, key=lambda t: t.beat):
        if last_bpm is not None and abs(t.bpm - last_bpm) < 0.05:
            continue
        tick = int(round(t.beat * tpb))
        conductor.append(mido.MetaMessage("set_tempo", tempo=mido.bpm2tempo(t.bpm), time=tick - last))
        last, last_bpm = tick, t.bpm
    for s in piece.sections:
        pass
    mid.tracks.append(conductor)
    channel = 0
    for name, part in piece.parts.items():
        notes = [n for n in piece.notes if n.part == name]
        if not notes:
            continue
        ch = 9 if part.is_drums else channel
        if not part.is_drums:
            channel += 1
            if channel == 9:
                channel = 10
        track = mido.MidiTrack()
        track.append(mido.MetaMessage("track_name", name=name, time=0))
        if not part.is_drums:
            track.append(mido.Message("program_change", channel=ch, program=part.program, time=0))
        msgs = []
        for n in notes:
            msgs.append((int(round(n.beat * tpb)), 1, n.pitch, n.vel))
            msgs.append((int(round((n.beat + n.dur) * tpb)), 0, n.pitch, 0))
        msgs.sort(key=lambda m: (m[0], m[1]))
        cur = 0
        for tick, on, pitch, vel in msgs:
            kind = "note_on" if on else "note_off"
            track.append(mido.Message(kind, channel=ch, note=pitch, velocity=vel, time=max(0, tick - cur)))
            cur = max(cur, tick)
        mid.tracks.append(track)
    mid.save(path)


def section_times(piece: Piece, tmap: TempoMap) -> list[dict]:
    out = []
    for s in piece.sections:
        out.append({"name": s.name, "start": round(tmap.seconds(s.start_beat), 3),
                    "end": round(tmap.seconds(s.start_beat + s.beats), 3), "bars": s.bars, "meter": s.meter,
                    "key": s.key, "bpm": [s.bpm_start, s.bpm_end]})
    return out


def phrase_starts(piece: Piece, tmap: TempoMap, every_bars: int = 4) -> list[float]:
    """Musical re-entry points (every 4 bars) in seconds, for the game's music director."""
    out = []
    for s in piece.sections:
        for bar in range(0, s.bars, every_bars):
            out.append(round(tmap.seconds(s.start_beat + bar * s.meter), 3))
    return out


def save_json(path: str, data: dict) -> None:
    with open(path, "w") as f:
        json.dump(data, f, indent=1)
