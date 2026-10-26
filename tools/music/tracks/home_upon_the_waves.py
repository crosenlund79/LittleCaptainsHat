"""Home Upon the Waves: cabin, harbours and peaceful exploration.

D major, mostly 72-78 BPM, with a 3/4 waltz in G in the middle. A small,
affectionate theme (A) on piano over fingerpicked guitar; it passes to the
cello, meets a gentler clarinet tune (B), is turned over in a development,
dances as a waltz (C) for flute and violin, and comes home fuller and then
very simply. The coda ends on the dominant, which leads straight back into
the opening when the track loops.
"""

from lch_music.arrange import Part, Piece
from lch_music.motif import MOTIF

PARTS = [
    Part("guitar", 24, pan=-0.35, reverb=0.22, gain_db=0.0),
    Part("piano", 0, pan=0.12, reverb=0.30, gain_db=-1.0, lowpass_hz=6000),
    Part("cello", 42, pan=0.35, reverb=0.34, gain_db=-7.0, legato=1.02, lowpass_hz=5000),
    Part("violin", 40, pan=-0.15, reverb=0.36, gain_db=-7.0, legato=1.02, lowpass_hz=6000),
    Part("strings", 49, pan=0.0, reverb=0.45, gain_db=-6.0, legato=1.02, lowpass_hz=4200),
    Part("clarinet", 71, pan=0.22, reverb=0.30, gain_db=-3.0, legato=1.0, lowpass_hz=6500),
    Part("flute", 73, pan=-0.22, reverb=0.34, gain_db=-12.0, legato=1.0, lowpass_hz=7000),
    Part("bass", 32, pan=0.05, reverb=0.08, gain_db=-5.0, lowpass_hz=1800),
    Part("pizz", 45, pan=0.15, reverb=0.25, gain_db=-5.0),
    Part("harp", 46, pan=-0.05, reverb=0.35, gain_db=-7.0),
]

# Theme A: the welcome (8 + 8 bars), and its harmony.
A1 = "1/q 5/q 6/e 5/e 3/q | 2/h. 3/e 2/e | 1/q 3/q 5/q 1'/q | 7/h 6/q 5/q | 4/q. 3/e 4/q 6/q | 5/q 3/q 2/q 1/q | 2/q. 3/e 4/q 3/q | 2/w"
A2 = "1/q 5/q 6/e 5/e 3/q | 2/q. 1/e 2/q 5/q | 6/q 5/q 3'/q. 2'/e | 1'/h 6/h | 4/q 6/q 1'/q 6/q | 5/q. 3/e 1/q 3/q | 2/q 4/q 2/q 7,/q | 1/w"
A1_CH = "1 | 5/7 | 6m7 | 3m 6m | 4 | 1 2m7 | 2m7 | 5sus4 5"
A2_CH = "1 | 5 | 4 1/3 | 6m | 4 | 1 | 2m7 5 | 1"

# Theme B: the quieter, slightly nostalgic tune (around B minor).
B1 = "3/h 4/e 3/e 2/q | 3/q 6,/q 7,/q 1/q | 2/h. 1/e 7,/e | 6,/w | 4/h 5/e 4/e 3/q | 4/q 7,/q 1/q 2/q | 3/q. 2/e 1/q 7,/q | 1/h 2/h"
B1_CH = "6m | 3m | 5 | 6m | 2m7 | 4 | 6m:3 3m:1 | 4 5"

# Theme C: the waltz (3/4, in G).
C1 = "5/q 1'/q 2'/q | 3'/h 2'/q | 1'/q 6/q 1'/q | 5/h. | 4/q 6/q 1'/q | 3'/h 2'/q | 2'/h. | 5/h."
C2 = "5/q 1'/q 2'/q | 3'/h 4'/q | 5'/q 3'/q 1'/q | 6/h. | 4/q 6/q 2'/q | 1'/h 7/q | 1'/h. | 1'/h."
C1_CH = "1 | 1 | 4 | 1 | 4 | 6m | 5 | 5"
C2_CH = "1 | 1:2 4:1 | 1 | 4 | 2m | 1/5:2 5:1 | 1 | 1"


def build() -> Piece:
    p = Piece("Home Upon the Waves", PARTS, seed=1101)

    # 1. Intro: guitar alone, the motif on the piano at bar 5.
    s = p.section("Intro", 8, "D", (70, 72), progression="1 | 4/1 | 1 | 5sus4 5 | 1 | 2m7 | 4 | 5sus4 5")
    s.fingerpick("guitar", vel=50)
    s.melody("piano", "r/w | r/w | r/w | r/w | " + MOTIF + " r/q | r/w | r/w", vel=56)

    # 2. A on the piano, guitar beneath; the bass joins halfway.
    s = p.section("A", 16, "D", 76, progression=A1_CH + " | " + A2_CH)
    s.fingerpick("guitar", vel=46)
    s.melody("piano", A1 + " | " + A2, vel=62)
    s.bass("bass", vel=46, from_bar=8)

    # 3. A' : the cello sings it; piano rolls underneath; a flute answers high.
    s = p.section("A cello", 16, "D", 76, progression=A1_CH + " | " + A2_CH)
    mel = s.melody("cello", A1 + " | " + A2, octave=-1, vel=64, ornament=0.25)
    s.broken("piano", vel=40)
    s.fingerpick("guitar", vel=36, from_bar=8, pattern="rise")
    s.pad("strings", vel=36, from_bar=8)
    s.counter("flute", 74, 86, vel=40, rhythm=2.0, from_bar=8, avoid=mel)
    s.bass("bass", vel=44)

    # 4. A short breath: guitar alone, the motif turned upwards.
    s = p.section("Breath", 4, "D", (74, 70), progression="4 | 1/3 | 2m7 | 5sus4 5", rit=0.06)
    s.fingerpick("guitar", vel=44, pattern="roll")
    s.melody("piano", "r/h 4/q 6/q | 5/e 3/e 1/q 3/h | r/w | r/w", vel=50)

    # 5. B: the clarinet, softly; then again with the harp and the cello.
    s = p.section("B", 16, "D", 72, progression=B1_CH + " | " + B1_CH)
    s.melody("clarinet", B1, vel=60)
    b2 = s.melody("clarinet", B1, bar=8, vel=58, ornament=0.3)
    s.block("piano", vel=34, every=2.0, to_bar=8)
    s.fingerpick("guitar", vel=40, to_bar=8, pattern="roll")
    s.harp("harp", vel=38, from_bar=8, low=50, rate=0.5)
    s.counter("cello", 45, 60, vel=44, rhythm=2.0, from_bar=8, avoid=b2)
    s.bass("bass", vel=42)

    # 6. Snovs settles: guitar and a flute, very spacious.
    s = p.section("Interlude", 8, "D", 70, progression="1maj7 | 4maj7 | 1maj7 | 4maj7 | 6m7 | 2m7 | 4 | 5sus4 5", rit=0.05)
    s.fingerpick("guitar", vel=46, pattern="arch")
    s.melody("flute", "r/w | 3'/h 1'/q 2'/q | r/w | 6/h 4/q 3/q | r/w | 4/h 3/e 2/e 1/q | r/w | 2/w", vel=50)
    s.melody("harp", "r/w | r/w | r/w | r/w | r/h 1''/q 5'/q | 6'/e 5'/e 3'/q 2'/h | r/w | r/w", vel=44)

    # 7. Development: the motif travels between clarinet and flute, then the piano.
    dev_ch = "6m | 3m | 4 | 1/3 | 2m | 3m | 5 | 5 | 6m | 3m | 4 | 1 | 2m7 | 5 | 4 | 5sus4 5"
    s = p.section("Development", 16, "D", 74, progression=dev_ch)
    s.melody("clarinet", "6,/q 3/q 4/e 3/e 1/q | 7,/h. r/q", bar=0, vel=58)
    s.melody("flute", "4/q 1'/q 2'/e 1'/e 6/q | 5/h. r/q", bar=2, vel=52)
    s.melody("clarinet", "2/q 6/q 7/e 6/e 4/q | 3/h. r/q", bar=4, vel=58)
    s.melody("flute", "5/q 2'/q 3'/e 2'/e 7/q | 5/h 7/q 2'/q", bar=6, vel=54)
    s.melody("piano", "3/q. 4/e 3/q 1/q | 7,/h 5,/h | 6,/q 1/q 4/q 6/q | 5/w | 4/q 6/q 2'/q 1'/q | 7/h 5/h | 6/q 4/q 1/q 3/q | 2/h 5,/h",
             bar=8, vel=60)
    s.pad("strings", vel=34)
    s.fingerpick("guitar", vel=38, from_bar=8)
    s.bass("pizz", vel=44, walk=True)

    # 8. Into the waltz: a harp roll in G.
    s = p.section("To the waltz", 2, "G", (80, 86), meter=3, progression="1 | 5")
    s.harp("harp", vel=40, low=55, rate=0.25)

    # 9. C: the waltz, flute over guitar and pizzicato.
    s = p.section("Waltz", 16, "G", 88, meter=3, progression=C1_CH + " | " + C2_CH)
    s.melody("flute", C1 + " | " + C2, vel=58)
    s.waltz("guitar", vel=42)
    s.bass("pizz", vel=46, walk=False, pattern="1")
    s.harp("harp", vel=30, from_bar=8, low=62, rate=1.0)

    # 10. C': the violin takes the waltz, the clarinet a third below; piano waltzes.
    s = p.section("Waltz violin", 16, "G", 90, meter=3, progression=C1_CH + " | " + C2_CH)
    line = s.melody("violin", C1 + " | " + C2, vel=58, ornament=0.3)
    s.harmony("clarinet", line, vel=44)
    s.waltz("piano", vel=38)
    s.pad("strings", vel=30)
    s.bass("pizz", vel=44, walk=False, pattern="1")

    # 11. C'': the second half once more, just piano and guitar, slowing.
    s = p.section("Waltz quiet", 16, "G", (86, 80), meter=3, progression=C2_CH + " | " + C1_CH, rit=0.08)
    s.melody("piano", C2 + " | " + C1, vel=54)
    s.waltz("guitar", vel=34)

    # 12. Home again: a bridge back to D.
    s = p.section("Bridge", 4, "D", (74, 76), progression="4/5 | 5 | 2m7 | 5sus4 5")
    s.melody("clarinet", "r/h 5/q 1'/q | 2'/h. r/q | 4'/q 2'/q 1'/q 6/q | 5/w", vel=52)
    s.pad("strings", vel=34)
    s.harp("harp", vel=34, low=50)

    # 13. A'': the fullest moment (still gentle): piano, flute above, violin counter.
    s = p.section("A full", 16, "D", 78, progression=A1_CH + " | " + A2_CH)
    mel = s.melody("piano", A1 + " | " + A2, vel=64)
    s.melody("flute", A2, bar=8, octave=1, vel=42)
    s.counter("violin", 69, 81, vel=42, rhythm=2.0, avoid=mel)
    s.fingerpick("guitar", vel=44)
    s.pad("strings", vel=32)
    s.bass("bass", vel=46)

    # 14. B': the cello, low and close.
    s = p.section("B cello", 8, "D", 72, progression=B1_CH)
    s.melody("cello", B1, vel=62)
    s.broken("piano", vel=36, figure="1-5-8-10")
    s.pad("strings", vel=30)

    # 15. A, intimately: piano and guitar only.
    s = p.section("A simple", 8, "D", (74, 72), progression=A2_CH)
    s.melody("piano", A2, vel=56, ornament=0.2)
    s.fingerpick("guitar", vel=40)

    # 16. Coda: fragments of the motif; it ends on the dominant, leading home to the start.
    s = p.section("Coda", 8, "D", (72, 64), progression="4 | 1/3 | 1 | 5 | 4 | 1/3 | 2m7 | 5sus4 5", rit=0.12)
    s.melody("piano", "r/q 1'/q 6/q 4/q | 3/h 5/h | " + MOTIF + " r/q | r/q 1'/q 6/q 4/q | 3/w | r/w | r/w", vel=50)
    s.fingerpick("guitar", vel=42, pattern="roll")
    s.melody("cello", "r/w | r/w | r/w | r/w | 4,/w | 3,/w | 2,/w | 5,/w", octave=-1, vel=40)
    return p
