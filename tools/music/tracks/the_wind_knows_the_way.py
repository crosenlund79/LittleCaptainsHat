"""The Wind Knows the Way: sailing and open water.

G major, with a journey in tempo: a quiet departure (88), the sails filling
(92-100), the sailing tune (S) for flute and then violin (100-104), a broad
second tune (T), a calm middle (84) for oboe and piano, a long horizon (T at
half speed), the islands (V), a development that lifts the music into A major
for a brighter return (106), a breakdown, and a slowing landing that ends on
the dominant, leading back into the departure.
Very light brushes and a shaker only; no heavy drums.
"""

from lch_music.arrange import Part, Piece
from lch_music.motif import MOTIF
from lch_music.score import augment

PARTS = [
    Part("guitar", 24, pan=-0.35, reverb=0.18, gain_db=0.0),
    Part("strum", 25, pan=0.30, reverb=0.16, gain_db=-7.0, lowpass_hz=7000),
    Part("piano", 0, pan=0.10, reverb=0.24, gain_db=-1.0, lowpass_hz=6500),
    Part("flute", 73, pan=-0.18, reverb=0.28, gain_db=-11.0, lowpass_hz=7500),
    Part("violin", 40, pan=-0.12, reverb=0.30, gain_db=-8.0, legato=1.02, lowpass_hz=4500),
    Part("cello", 42, pan=0.35, reverb=0.28, gain_db=-7.0, legato=1.02, lowpass_hz=5000),
    Part("oboe", 68, pan=0.18, reverb=0.28, gain_db=-8.0, lowpass_hz=6000),
    Part("clarinet", 71, pan=0.22, reverb=0.26, gain_db=-3.0, lowpass_hz=6500),
    Part("strings", 49, pan=0.0, reverb=0.40, gain_db=-7.0, legato=1.02, lowpass_hz=4200),
    Part("bass", 32, pan=0.05, reverb=0.06, gain_db=-5.0, lowpass_hz=1800),
    Part("harp", 46, pan=-0.05, reverb=0.32, gain_db=-7.0),
    Part("brushes", 40, bank=128, pan=0.1, reverb=0.12, gain_db=-12.0, is_drums=True, lowpass_hz=9000),
]

# S: the sailing tune.
S1 = "5,/e 1/e 3/e 5/e 6/q. 5/e | 3/q 2/q 1/h | 1/e 3/e 5/e 1'/e 2'/q. 1'/e | 7/h 5/h | 6/e 7/e 1'/q 6/q 4/q | 5/q. 3/e 1/q 3/q | 2/q 3/e 4/e 5/q 7,/q | 2/h. r/q"
S2 = "5,/e 1/e 3/e 5/e 6/q. 5/e | 3/q 2/q 1/h | 1/e 3/e 5/e 1'/e 2'/q. 1'/e | 7/h 5/h | 6/e 7/e 1'/q 2'/q 3'/q | 2'/q. 1'/e 6/q 1'/q | 2/q 3/e 4/e 5/q 7,/q | 1/w"
S1_CH = "1 4/1 | 6m | 4 2m | 5 | 4 | 1 | 2m7 5 | 5"
S2_CH = "1 4/1 | 6m | 4 2m | 5 | 4 2m | 2m7 | 5sus4 5 | 1"

# T: the broad tune.
T = "3'/h 2'/q 1'/q | 7/h 5/h | 6/q 1'/q 4'/q. 3'/e | 2'/w | 2'/h 1'/q 7/q | 6/h 4/h | 5/q 6/q 7/q 2'/q | 1'/w"
T_CH = "6m 2m7 | 3m | 4 | 5 | 2m7 | 4 | 5 | 1"

# U: the calm middle.
U = "3/q. 2/e 1/q 7,/q | 6,/h 7,/q 1/q | 2/q. 3/e 4/q 2/q | 3/w | 3/q. 4/e 5/q 3/q | 6/h 5/q 4/q | 3/q 2/q 1/q 7,/q | 6,/w"
U_CH = "6m | 4 5 | 2m7 | 3m | 6m 5 | 4 5 | 1:3 3m:1 | 6m"

# V: islands approaching.
V = "1'/e 7/e 1'/q 5/q 3/q | 4/q. 5/e 6/h | 5/e 4/e 5/q 2/q 7,/q | 1/h 3/h | 6/e 5/e 6/q 1'/q 6/q | 5/q. 4/e 3/q 1/q | 2/q 4/q 6/q 7/q | 1'/w"
# W: dolphins alongside (3/4, quick and light).
W1 = "5/q 6/q 5/q | 3'/h 2'/q | 1'/q 7/q 6/q | 5/h. | 4/q 5/q 6/q | 2'/h 1'/q | 7/q 1'/q 2'/q | 5/h."
W2 = "5/q 6/q 5/q | 3'/h 2'/q | 1'/q 2'/q 3'/q | 4'/h. | 3'/q 2'/q 1'/q | 6/h 2'/q | 1'/h 7/q | 1'/h."
W_CH = "1 | 1 | 4 | 1 | 4 | 5 | 5 | 5 | 1 | 1 | 4 | 4 | 1 | 2m | 1/5:2 5:1 | 1"

HORIZON_CH = "6m | 2m7 | 3m | 3m | 4 | 4 | 5 | 5 | 2m7 | 2m7 5 | 4 | 4 | 5 4 | 5 | 1 | 1"
V_CH = "1 | 4 | 5 | 1 | 4 | 1 | 2m7:3 5:1 | 1"


def build() -> Piece:
    p = Piece("The Wind Knows the Way", PARTS, seed=2202)

    # 1. Departure: fingerpicked guitar; the motif on the flute.
    s = p.section("Departure", 8, "G", (86, 88), progression="1 | 4/1 | 1 | 5sus4 5 | 1 | 2m7 | 4 | 5sus4 5")
    s.fingerpick("guitar", vel=50)
    s.melody("flute", "r/w | r/w | r/w | r/w | " + MOTIF + " r/q | r/w | r/w", vel=54)

    # 2. Hoisting sail: a gentle strum, the bass, a shaker; a piano counter-line.
    s = p.section("Hoisting", 8, "G", (92, 96), progression="1 | 6m | 4 | 5 | 1 | 6m | 2m7 | 5sus4 5")
    s.fingerpick("guitar", vel=44, pattern="rise")
    s.strum("strum", vel=40, from_bar=4)
    s.bass("bass", vel=44)
    s.brushes("brushes", vel=22, from_bar=4, snare=False)
    s.counter("piano", 64, 76, vel=44, rhythm=1.0)

    # 3. The sailing tune on the flute.
    s = p.section("Sailing", 16, "G", 100, progression=S1_CH + " | " + S2_CH)
    s.melody("flute", S1 + " | " + S2, vel=62)
    s.fingerpick("guitar", vel=42, pattern="arch")
    s.strum("strum", vel=40)
    s.bass("bass", vel=48)
    s.brushes("brushes", vel=26)
    s.block("piano", vel=32, every=2.0, from_bar=8, bass=False, low=55, high=72)

    # 4. The broad tune: violin, with the cello below.
    s = p.section("Broad", 8, "G", 100, progression=T_CH)
    line = s.melody("violin", T, vel=62)
    s.counter("cello", 48, 62, vel=46, rhythm=2.0, avoid=line)
    s.broken("piano", vel=38)
    s.strum("strum", vel=34)
    s.bass("bass", vel=44)
    s.pad("strings", vel=34)
    s.brushes("brushes", vel=22, snare=False)

    # 5. The sailing tune again, the violin leading, the flute a third above.
    s = p.section("Sailing violin", 16, "G", 104, progression=S1_CH + " | " + S2_CH)
    line = s.melody("violin", S1 + " | " + S2, vel=60, ornament=0.25)
    s.harmony("flute", line, below=False, vel=40)
    s.fingerpick("guitar", vel=40)
    s.strum("strum", vel=38)
    s.bass("bass", vel=48)
    s.pad("strings", vel=30)
    s.brushes("brushes", vel=26)

    # 6. Just the piano and the guitar: the tune once more, close.
    s = p.section("Sailing piano", 8, "G", 100, progression=S2_CH)
    s.melody("piano", S2, vel=58, ornament=0.2)
    s.fingerpick("guitar", vel=42, pattern="roll")
    s.brushes("brushes", vel=18, snare=False)

    # 7. Easing the sheets.
    s = p.section("Easing", 4, "G", (98, 86), progression="4 | 1/3 | 2m7 | 5sus4 5", rit=0.05)
    s.fingerpick("guitar", vel=44)
    s.harp("harp", vel=38, low=50)

    # 8. The calm middle: oboe, guitar, harp.
    s = p.section("Calm", 16, "G", 84, progression=U_CH + " | " + U_CH)
    s.melody("oboe", U, vel=60)
    line = s.melody("piano", U, bar=8, vel=56, ornament=0.25)
    s.fingerpick("guitar", vel=42, pattern="arch", to_bar=8)
    s.harp("harp", vel=34, from_bar=8, low=48)
    s.counter("cello", 45, 59, vel=42, rhythm=4.0, from_bar=4, avoid=line)
    s.bass("bass", vel=40, from_bar=8, walk=False)

    # 8b. The calm tune once more, the clarinet low over harp.
    s = p.section("Calm clarinet", 8, "G", 84, progression=U_CH, rit=0.04)
    s.melody("clarinet", U, vel=54, ornament=0.15)
    s.harp("harp", vel=34, low=48)
    s.pad("strings", vel=28)

    # 9. The long horizon: the broad tune at half speed over flowing guitar.
    s = p.section("Horizon", 16, "G", (84, 90), progression=HORIZON_CH)
    line = s.melody("violin", augment(T), vel=50)
    s.fingerpick("guitar", vel=42, pattern="rise")
    s.pad("strings", vel=32)
    s.bass("bass", vel=40, walk=False)
    s.counter("flute", 72, 84, vel=38, rhythm=2.0, from_bar=8, avoid=line)

    # 10. Islands: a new tune, clarinet and then flute; the rhythm returns.
    s = p.section("Islands", 16, "G", (94, 100), progression=V_CH + " | " + V_CH)
    s.melody("clarinet", V, vel=58)
    s.melody("flute", V, bar=8, vel=58, ornament=0.25)
    s.strum("strum", vel=38)
    s.fingerpick("guitar", vel=38, from_bar=8)
    s.bass("bass", vel=46)
    s.brushes("brushes", vel=24)
    s.block("piano", vel=30, every=2.0, bass=False, low=55, high=72)

    # 10b. Dolphins alongside: a quick, light waltz, flute then violin.
    s = p.section("Dolphins", 32, "G", 112, meter=3, progression=W_CH + " | " + W_CH)
    s.melody("flute", W1 + " | " + W2, vel=58)
    line = s.melody("violin", W1 + " | " + W2, bar=16, vel=56, ornament=0.3)
    s.waltz("guitar", vel=40, to_bar=16)
    s.waltz("piano", vel=36, from_bar=16)
    s.bass("bass", vel=44, walk=False, pattern="1")
    s.counter("cello", 48, 60, vel=40, rhythm=3.0, from_bar=16, avoid=line)
    s.brushes("brushes", vel=20, snare=False)

    # 11. Development: the motif climbs through the keys, into A major.
    s = p.section("Rising", 8, "G", (98, 104), progression="6m | 3m | 4 | 1/3 | 2m7 | 5 | 6sus4 | 6")
    s.melody("flute", "6,/q 3/q 4/e 3/e 1/q | 7,/h. r/q", bar=0, vel=56)
    s.melody("clarinet", "4/q 1'/q 2'/e 1'/e 6/q | 5/h. r/q", bar=2, vel=56)
    s.melody("flute", "2/q 6/q 7/e 6/e 4/q | 5/h 7/q 2'/q", bar=4, vel=58)
    s.melody("violin", "6,/q 3/q 2/e 3/e 6/q | #1/h. 7,/q", bar=6, vel=58)
    s.strum("strum", vel=40)
    s.bass("bass", vel=48)
    s.brushes("brushes", vel=26)
    s.pad("strings", vel=32)

    # 12. The sailing tune in A: piano with the flute an octave above. The fullest part.
    s = p.section("Sailing in A", 16, "A", 106, progression=S1_CH + " | " + S2_CH)
    s.melody("piano", S1 + " | " + S2, vel=62)
    s.melody("flute", S1 + " | " + S2, octave=1, vel=40)
    s.fingerpick("guitar", vel=40)
    s.strum("strum", vel=42)
    s.bass("bass", vel=50)
    s.brushes("brushes", vel=28)
    s.pad("strings", vel=32)

    # 13. The broad tune in A, twice: violin, then cello and piano.
    s = p.section("Broad in A", 16, "A", 106, progression=T_CH + " | " + T_CH)
    line = s.melody("violin", T, vel=60)
    s.counter("cello", 50, 64, vel=44, rhythm=2.0, to_bar=8, avoid=line)
    s.melody("cello", T, bar=8, octave=-1, vel=60, ornament=0.2)
    s.broken("piano", vel=36)
    s.strum("strum", vel=34)
    s.bass("bass", vel=44)
    s.brushes("brushes", vel=22, snare=False)
    s.pad("strings", vel=30, to_bar=8)

    # 14. Islands in A, the clarinet over guitar.
    s = p.section("Islands in A", 8, "A", 104, progression=V_CH)
    s.melody("clarinet", V, vel=58, ornament=0.2)
    s.fingerpick("guitar", vel=42)
    s.bass("bass", vel=44)
    s.brushes("brushes", vel=22)

    # 15. Breakdown: guitar and shaker; the motif called and answered. Ends on D, the way home to G.
    s = p.section("Breakdown", 8, "A", 104, progression="1 | 5 | 1 | 5 | 6m | 4 | 2m7 | 4")
    s.fingerpick("guitar", vel=46, pattern="roll")
    s.brushes("brushes", vel=20, snare=False)
    s.melody("flute", MOTIF + " r/q", bar=0, vel=52)
    s.melody("clarinet", "1/q 5/q 6/e 5/e 3/q | 5/h. r/q", bar=2, vel=50)
    s.melody("flute", "6,/q 3/q 4/e 3/e 1/q | 6,/h. r/q", bar=4, vel=52)
    s.melody("clarinet", "2/q 6/q 7/e 6/e 4/q | 4/h. r/q", bar=6, vel=50)

    # 16. Back in G: the tune's answer on the piano, the flute weaving.
    s = p.section("Homeward", 16, "G", 102, progression=S1_CH + " | " + S2_CH)
    line = s.melody("piano", S1 + " | " + S2, vel=60)
    s.counter("flute", 72, 84, vel=40, rhythm=1.0, avoid=line)
    s.strum("strum", vel=36)
    s.bass("bass", vel=46)
    s.brushes("brushes", vel=22)

    # 17. Landing: slowing to the departure's pace; ends on the dominant.
    s = p.section("Landing", 12, "G", (96, 84),
                  progression="4 | 1/3 | 2m7 | 5 | 1 | 2m7 | 1 | 5sus4 5 | 4 | 1/3 | 2m7 | 5sus4 5", rit=0.1)
    s.fingerpick("guitar", vel=46)
    s.melody("flute", "r/w | r/w | r/w | r/w | " + MOTIF + " r/q | r/w | r/w | r/q 1'/q 6/q 4/q | 3/w | r/w | r/w", vel=50)
    s.pad("strings", vel=30, to_bar=8)
    s.bass("bass", vel=40, to_bar=8, walk=False)
    return p
