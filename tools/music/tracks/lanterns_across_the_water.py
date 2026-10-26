"""Lanterns Across the Water: night aboard, sleeping cabin, night sailing.

F major, mostly 3/4 at 54-66 BPM, with space and pauses. A soft "felt"
piano (the grand piano, played gently and darkened) carries the lantern
tune (L); a cello takes it up; a slightly more moving 4/4 night song (N) for
viola and clarinet over guitar; a music-box "stars" passage; the lantern
tune warmed in B flat; the piano alone; and a slow coda that rests on the
dominant, so the loop returns to the opening chords.
"""

from lch_music.arrange import Part, Piece

PARTS = [
    Part("piano", 0, pan=0.08, reverb=0.42, gain_db=0.0, lowpass_hz=2400),
    Part("musicbox", 10, pan=-0.25, reverb=0.55, gain_db=-7.0, lowpass_hz=6000),
    Part("celesta", 8, pan=0.25, reverb=0.55, gain_db=-5.0, lowpass_hz=6000),
    Part("guitar", 24, pan=-0.32, reverb=0.32, gain_db=-1.0),
    Part("cello", 42, pan=0.32, reverb=0.40, gain_db=-7.0, legato=1.02, lowpass_hz=4200),
    Part("viola", 41, pan=-0.12, reverb=0.40, gain_db=-7.0, legato=1.02, lowpass_hz=3800),
    Part("clarinet", 71, pan=0.18, reverb=0.38, gain_db=-4.0, lowpass_hz=5000),
    Part("harp", 46, pan=-0.05, reverb=0.45, gain_db=-8.0),
    Part("strings", 49, pan=0.0, reverb=0.50, gain_db=-8.0, legato=1.02, lowpass_hz=3200),
    Part("pad", 89, pan=0.0, reverb=0.50, gain_db=-20.0, legato=1.02, lowpass_hz=2500),
    Part("bass", 32, pan=0.05, reverb=0.12, gain_db=-7.0, lowpass_hz=1200),
]

MOTIF3 = "1/q 5/q 6/e 5/e | 3/q 2/h"  # the shared motif, in 3/4

# L: the lantern tune (3/4, 16 bars).
L1 = "1/q 5/q 6/q | 5/h 3/q | 2/h. | r/q 2/q 3/q | 4/q. 3/e 2/q | 3/q 5/q 1'/q | 7/h. | 5/h r/q"
L2 = "1/q 5/q 6/q | 5/h 3'/q | 2'/h 1'/q | 7/h. | 6/q 7/q 1'/q | 2'/q. 1'/e 6/q | 5/q 3/q 2/q | 1/h."
L1_CH = "1 | 3m | 2m7 | 5 | 4 | 6m | 3m | 1"
L2_CH = "6m | 1 | 2m7 | 5 | 4 | 2m | 1/5:2 5:1 | 1"

# N: the night song (4/4), with a little more movement.
N1 = "6,/q 1/q 3/q 6/q | 5/h 3/h | 4/q 3/q 2/q 4/q | 3/w | 2/q 3/q 4/q 6/q | 5/h. 4/e 3/e | 2/q 1/q 2/q 3/q | 2/w"
N2 = "6,/q 1/q 3/q 6/q | 5/h 3/h | 4/q 3/q 2/q 4/q | 3/w | 2/q 3/q 4/q 1'/q | 7/h. 6/e 5/e | 2/q 1/q 7,/q 2/q | 1/w"
N1_CH = "6m | 1 | 2m7 | 6m | 2m | 1 | 5 | 5"
N2_CH = "6m | 1 | 2m7 | 6m | 2m | 5 | 5 | 1"

# Stars: high, sparse, for music box and celesta (3/4).
ST1 = "1'/q 5/q 6/q | 5/h. | 3'/q 2'/q 1'/q | 2'/h. | 6/q 5/q 3/q | 2/h 5/q | 1'/h. | r/h."
ST2 = "3'/q 2'/q 1'/q | 7/h 5/q | 6/q 1'/q 3'/q | 2'/h. | 4'/q 3'/q 2'/q | 1'/h 6/q | 7/q 1'/q 2'/q | 1'/h."
ST1_CH = "1 | 3m | 6m | 5 | 4 | 2m7 | 1 | 1"
ST2_CH = "6m | 3m | 4 | 5 | 2m7 | 4 | 5 | 1"


def build() -> Piece:
    p = Piece("Lanterns Across the Water", PARTS, seed=3303)

    # 1. Intro: soft piano chords; the motif on the music box.
    s = p.section("Intro", 8, "F", (54, 56), meter=3, progression="1 | 4/1 | 1 | 4/1 | 1 | 6m | 2m7 | 5sus4")
    s.block("piano", vel=34, low=53, high=69, roll=0.05)
    s.sparkle("musicbox", "r/h. | r/h. | r/h. | r/h. | " + MOTIF3 + " | r/h. | r/h.", octave=1, vel=50)
    s.pad("pad", vel=40, voices=3)

    # 2. The lantern tune on the felt piano, the left hand rocking gently.
    s = p.section("Lantern", 16, "F", 60, meter=3, progression=L1_CH + " | " + L2_CH, phrase_breath=0.05)
    s.melody("piano", L1 + " | " + L2, vel=54, swell=8)
    s.broken("piano", vel=32, low=36, figure="1-5-10-5", sustain=2.0)

    # 3. The cello sings it; the guitar picks softly; strings breathe underneath.
    s = p.section("Lantern cello", 16, "F", 60, meter=3, progression=L1_CH + " | " + L2_CH, phrase_breath=0.05)
    line = s.melody("cello", L1 + " | " + L2, octave=-1, vel=58, ornament=0.2)
    s.fingerpick("guitar", vel=38, pattern="arch", ring=2.0)
    s.pad("strings", vel=30)
    s.sparkle("musicbox", "r/h. | r/h. | r/h. | r/h. | r/h. | r/h. | r/h. | r/h. | r/h. | r/h. | r/h. | r/h. | 6/q 7/q 1'/q | 2'/h. | r/h. | r/h.",
              octave=1, vel=40)

    # 4. A breath: harp, and the music box answering.
    s = p.section("Ripples", 4, "F", 58, meter=3, progression="4 | 1/3 | 2m7 | 5sus4", rit=0.05)
    s.harp("harp", vel=34, low=53, rate=0.5)
    s.sparkle("musicbox", "r/h. | 5/q 3/q 2/q | 1/h. | r/h.", octave=1, vel=42)

    # 5. The night song: viola over fingerpicked guitar; the bass joins.
    s = p.section("Night song", 16, "F", (68, 72), progression=N1_CH + " | " + N2_CH)
    s.melody("viola", N1 + " | " + N2, vel=58)
    s.fingerpick("guitar", vel=42, pattern="rise")
    s.block("piano", vel=28, every=4.0, from_bar=8, low=57, high=72, bass=False, roll=0.04)
    s.bass("bass", vel=40, from_bar=8, walk=False)

    # 6. Again, for the clarinet, with harp and strings.
    s = p.section("Night song clarinet", 16, "F", 72, progression=N1_CH + " | " + N2_CH)
    line = s.melody("clarinet", N1 + " | " + N2, vel=56, ornament=0.25)
    s.broken("piano", vel=30, low=38)
    s.harp("harp", vel=28, from_bar=8, low=57, rate=1.0)
    s.pad("strings", vel=28)
    s.counter("cello", 45, 58, vel=38, rhythm=4.0, avoid=line)
    s.bass("bass", vel=38, walk=False)

    # 7. Back to the slow three.
    s = p.section("Return", 4, "F", (66, 60), meter=3, progression="4 | 1/3 | 2m7 | 5sus4", rit=0.06)
    s.fingerpick("guitar", vel=40, pattern="roll", ring=2.0)
    s.pad("pad", vel=36, voices=3)

    # 8. Stars: music box and celesta take turns, harp below, a warm pad.
    s = p.section("Stars", 16, "F", 66, meter=3, progression=ST1_CH + " | " + ST2_CH)
    s.sparkle("musicbox", ST1, octave=1, vel=52)
    s.sparkle("celesta", ST2, bar=8, octave=1, vel=50)
    s.harp("harp", vel=40, low=48, rate=1.0)
    s.pad("pad", vel=48, voices=3)

    # 9. Stars again, the piano carrying them, the cello beneath.
    s = p.section("Stars piano", 16, "F", (66, 62), meter=3, progression=ST1_CH + " | " + ST2_CH)
    line = s.melody("piano", ST1 + " | " + ST2, vel=44)
    s.counter("cello", 43, 57, vel=36, rhythm=3.0, avoid=line)
    s.fingerpick("guitar", vel=34, ring=2.0)

    # 10. The lantern tune warmed in B flat: piano, cello counter, guitar.
    s = p.section("Lantern in B flat", 16, "Bb", 62, meter=3, progression=L1_CH + " | " + L2_CH, phrase_breath=0.05)
    line = s.melody("piano", L1 + " | " + L2, vel=54, ornament=0.2)
    s.counter("cello", 43, 57, vel=40, rhythm=3.0, avoid=line)
    s.fingerpick("guitar", vel=36, pattern="arch", ring=2.0)
    s.pad("strings", vel=26)

    # 11. The piano alone, slower, breathing between phrases (back in F).
    s = p.section("Piano alone", 8, "F", (60, 56), meter=3, progression=L2_CH, phrase_breath=0.1)
    s.melody("piano", L2, vel=50, swell=6)
    s.broken("piano", vel=28, low=36, figure="1-10", sustain=2.5)

    # 12. The lantern tune, all together but still hushed.
    s = p.section("Lantern together", 16, "F", 60, meter=3, progression=L1_CH + " | " + L2_CH, phrase_breath=0.05)
    line = s.melody("piano", L1 + " | " + L2, vel=54)
    s.sparkle("musicbox", L2, bar=8, octave=1, vel=36)
    s.counter("cello", 43, 57, vel=38, rhythm=3.0, avoid=line)
    s.fingerpick("guitar", vel=34, ring=2.0)
    s.pad("strings", vel=28)

    # 13. Coda: the motif, slower and slower; it rests on the dominant.
    s = p.section("Coda", 8, "F", (56, 48), meter=3, progression="1 | 6m | 3m | 1/3 | 2m7 | 1 | 4 | 5sus4", rit=0.12)
    s.melody("piano", "r/h. | " + MOTIF3 + " | r/h. | r/h. | r/h. | r/h. | r/h.", vel=46)
    s.block("piano", vel=28, low=53, high=67, roll=0.06)
    s.sparkle("musicbox", "r/h. | r/h. | r/h. | r/h. | 1'/q 5/q 6/q | 5/h. | r/h. | r/h.", octave=1, vel=36)
    s.pad("pad", vel=36, voices=3)
    return p
