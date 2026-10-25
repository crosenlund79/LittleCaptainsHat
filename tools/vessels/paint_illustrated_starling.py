"""Paints the Starling 33's illustrated art-direction prototype (Visual Identity V01).

Usage: python3 tools/vessels/paint_illustrated_starling.py

Writes full-canvas PNG layers (2 px per scene unit, transparent elsewhere) to
assets/vessels/starling_33/illustrated/deck/ and .../cabin/, the slots of
data/vessels/starling_33_visuals_illustrated.tres. Every shape is taken from the
boat's own scenes (deck_visual.tscn, cabin_visual.tscn, cabin.tscn), so the art
lines up with the unchanged collision and stations.

The style follows the written art direction: slightly uneven dark-ink outlines,
warm muted colour washes with soft variation, plank and grain texture, light
hatching for shade (light from the upper left), small lived-in details. It is a
prototype for the owner to judge. These are generated stand-ins: the owner's
own drawings can replace any layer by saving a PNG with the same name.
"""
import os
import sys

sys.path.insert(0, os.path.dirname(__file__))
from illustrate import *  # noqa: E402,F403
from illustrate import ROOT  # noqa: E402

OUT = os.path.join(ROOT, "assets", "vessels", "starling_33", "illustrated")
CANVAS = (-560, -200, 1120, 400)


def roof_front(roof):
    """The forward end of the coachroof (x)."""
    return max(x for x, _ in roof)


# =============================================================== deck
def paint_deck():
    v = parse(os.path.join(ROOT, "src/vessels/starling_33/deck_visual.tscn"))
    hull = shape(v, "HullBase/Hull")
    deck = shape(v, "DeckBase/DeckSurface")
    toe = v["HullBase/ToeRail"]["points"]

    # Hull: the cream topsides seen from above (a rim around the deck) and a
    # teak toe rail along the sheer.
    L = Layer(1, CANVAS)
    L.fill(hull, HULL, 0.05)
    L.hatch([(x, y) for x, y in hull if y > 0] + [(-500, 0)], spacing=4.0, alpha=30)   # shade on the starboard side
    L.ink(toe, 3.0, TEAK, closed=False, amp=0.4, alpha=255)
    L.ink(toe, 0.7, TEAK_DARK, closed=False, amp=0.4, alpha=160)
    L.ink(hull, 2.2)
    L.save(os.path.join(OUT, "deck", "hull_base.png"))

    # Deck: marine teak (0.100b). Margin boards along the sheer, strips
    # sprung along the curve near the edge, fore-and-aft strips inside, a king
    # plank on the foredeck; the coachroof and cockpit are cut out with their
    # own margins. A teak-and-holly cockpit sole and teak benches.
    D = Layer(2, CANVAS)
    roof = shape(v, "Coachroof/Coachroof")
    cockpit = shape(v, "DeckBase/CockpitWell")
    D.shadow(deck, (2, 3), 3, 60)
    teak_deck(D, deck, holes=[roof, cockpit], king_plank=(roof_front(roof), 468))
    D.shadow(cockpit, (3, 4), 3, 80)
    teak_sole(D, cockpit)
    D.ink(cockpit, 1.8)
    for name in ("DeckBase/BenchPort", "DeckBase/BenchStarboard"):
        teak_deck(D, shape(v, name), strip=4.0, margin=3.5, sprung=0)
    # Cushions on the port bench: somewhere to sit at anchor.
    D.piece(D.rounded(-440, -96, 52, 22, 6), CUSHION, 1.2)
    D.line((-414, -94), (-414, -76), 0.6, INK, 90)
    D.piece(D.rounded(-384, -96, 46, 22, 6), (192, 112, 84), 1.2)
    hatch = shape(v, "DeckBase/Hatch")
    D.piece(hatch, TEAK, 1.4)
    for i in range(3):
        D.line((-226 + i * 18, -34), (-226 + i * 18, 34), 0.8, TEAK_DARK, 160)
    D.save(os.path.join(OUT, "deck", "deck_base.png"))

    # Coachroof: cream roof with soft shade, sea-glass portlights, fore hatch.
    C = Layer(3, CANVAS)
    roof = shape(v, "Coachroof/Coachroof")
    C.shadow(roof, (7, 9), 6, 90)
    C.fill(roof, CREAM, 0.05)
    shade_side = [(x, y) for x, y in roof if y > 0] + [(x, 70) for x, y in reversed([(x, y) for x, y in roof if y > 0])]
    C.hatch([(-230, 60), (120, 60), (120, 100), (-230, 100)], spacing=4.5, alpha=35)
    C.ink(roof, 2.0)
    for i in range(4):
        n = v["Coachroof/Coachroof/Portlight%d" % i]
        pl = [(x - 55, y) for x, y in n["polygon"]]
        C.fill(pl, SEAGLASS, 0.1)
        C.line((pl[0][0] + 6, pl[0][1] + 4), (pl[1][0] - 14, pl[1][1] + 4), 0.8, WHITE, 140)
        C.ink(pl, 1.1)
    fore = [(x - 55, y) for x, y in v["Coachroof/Coachroof/ForeHatch"]["polygon"]]
    C.piece(fore, (200, 214, 208), 1.3, shadow=False)
    C.hatch(fore, spacing=3, alpha=40)
    # Grab rails and a few lived-in things on the roof.
    for sy in (-1, 1):
        C.piece(C.rounded(-180, sy * 82 - 3, 150, 6, 3), TEAK, 0.9, shadow=False)
    C.coil((40, -72), 13)
    C.piece(C.rounded(-150, -40, 42, 26, 5), (110, 140, 96), 1.1)   # a small herb box
    for (x, y) in ((-140, -31), (-128, -24), (-118, -33)):
        C.circle((x, y), 4, (96, 140, 80), 0.6, n=10, shadow=False)
    C.save(os.path.join(OUT, "deck", "coachroof.png"))

    # Deck details: wheel, winches, cleats, coils, fenders, lifelines, pulpits.
    T = Layer(4, CANVAS)
    life = v["DeckDetails/Lifelines"]["points"]
    T.ink(life, 0.9, (190, 196, 200), closed=False, amp=0.4, alpha=200)
    pulpit = v["DeckDetails/Pulpit"]["points"]
    T.ink(pulpit, 1.6, (170, 176, 182), closed=False, amp=0.3)
    push = v["DeckDetails/Pushpit"]["points"]
    T.ink(push, 1.6, (170, 176, 182), closed=False, amp=0.3)
    for x, y in [(-470, -128), (-470, 128), (-300, -150), (-300, 150), (-100, -158), (-100, 158), (100, -158), (100, 158),
                 (300, -140), (300, 140)]:
        T.circle((x, y), 3.2, (150, 156, 160), 0.8, n=12, shadow=False)        # stanchion bases
    # The wheel on its pedestal.
    T.circle((-392, 0), 12, (90, 96, 100), 1.2)
    wheel_r = 56
    T.ink([(-406, -wheel_r), (-406, wheel_r)], 4.0, INK, closed=False, amp=0.4)
    T.ink([(-406, -wheel_r), (-406, wheel_r)], 2.4, (130, 106, 80), closed=False, amp=0.3)
    for y in (-wheel_r, wheel_r):
        T.circle((-406, y), 4, (130, 106, 80), 0.9, n=10, shadow=False)
    # Winches by the cockpit, and cleats fore and aft.
    for x, y in [(-300, -112), (-300, 112), (-250, -86), (-250, 86)]:
        T.circle((x, y), 9, (176, 180, 184), 1.2)
        T.circle((x, y), 3.5, (110, 114, 118), 0.8, n=12, shadow=False)
    for x, y, a in [(-470, -116, 0), (-470, 116, 0), (430, -50, 0.5), (430, 50, -0.5), (250, -140, 0), (250, 140, 0)]:
        c, s = math.cos(a), math.sin(a)
        pts = [(-9, -2.5), (9, -2.5), (9, 2.5), (-9, 2.5)]
        T.piece([(x + px_ * c - py * s, y + px_ * s + py * c) for px_, py in pts], (188, 190, 192), 1.0)
    # Coiled sheets in the cockpit corners and a halyard coil at the mast.
    T.coil((-282, -78), 10)
    T.coil((-282, 78), 10, color=(196, 116, 92))
    T.coil((215, 30), 9)
    # Anchor locker lid, bow roller with the anchor, swim ladder.
    T.piece(shape(v, "DeckDetails/AnchorLocker"), TEAK_LIGHT, 1.3)
    T.line((392, -12), (392, 12), 0.7, TEAK_DARK, 150)
    T.line((418, -12), (418, 12), 0.7, TEAK_DARK, 150)
    T.piece(shape(v, "DeckDetails/BowRoller"), (160, 164, 168), 1.0)
    anchor = [(486, -3), (500, -3), (504, -9), (507, 0), (504, 9), (500, 3), (486, 3)]
    T.piece(anchor, (110, 114, 118), 1.0, shadow=False)
    T.piece(shape(v, "DeckDetails/SwimLadder"), (170, 174, 178), 1.0)
    for y in (-18, 0, 18):
        T.line((-512, y), (-500, y), 0.8, INK, 160)
    # Fenders tied to the lifelines on the harbour side (starboard, +y).
    for x in (-300, -40, 220):
        T.line((x, 156), (x, 168), 0.7, ROPE, 220)
        T.piece(T.rounded(x - 7, 166, 14, 26, 6), (238, 236, 228), 1.2)
    # A bucket and a forgotten mug in the cockpit: someone lives here.
    T.circle((-455, -60), 7, (196, 120, 70), 1.0, n=16)
    T.circle((-344, 52), 4, (220, 214, 200), 0.9, n=12)
    T.save(os.path.join(OUT, "deck", "deck_details.png"))


# =============================================================== cabin
def paint_cabin():
    v = parse(os.path.join(ROOT, "src/vessels/starling_33/cabin_visual.tscn"))
    hull = shape(v, "CabinBase/HullShape")
    sole = shape(v, "CabinBase/CabinSole")

    B = Layer(11, CANVAS)
    B.fill(hull, (62, 52, 44), 0.08)                     # the hull's inside, dark wood
    B.ink(hull, 2.2)
    B.shadow(sole, (0, 0), 6, 120)
    B.planks(sole, 15.0, HONEY, seam=(110, 84, 58), horizontal=True)
    B.ink(sole, 1.6)
    # Warm light pooling under the saloon lamp, a darker edge along the sides.
    light = Image.new("L", B.img.size, 0)
    ImageDraw.Draw(light).ellipse([B.px((-140, -90)), B.px((170, 90))], fill=60)
    light = light.filter(ImageFilter.GaussianBlur(40 * SS))
    glow = Image.new("RGBA", B.img.size, (255, 226, 160, 0))
    glow.putalpha(light)
    clipped = Image.new("RGBA", B.img.size, (0, 0, 0, 0))
    clipped.paste(glow, (0, 0), B.mask(sole))
    B.img.alpha_composite(clipped)
    # A round rag rug by the table.
    rug = [(110 + 34 * math.cos(a), 52 + 22 * math.sin(a)) for a in np.linspace(0, 2 * math.pi, 40, endpoint=False)]
    B.fill(rug, (176, 112, 92), 0.08)
    for k in (0.75, 0.5):
        B.ink([(110 + 34 * k * math.cos(a), 52 + 22 * k * math.sin(a)) for a in np.linspace(0, 2 * math.pi, 40, endpoint=False)],
              0.7, (226, 196, 150), alpha=200)
    B.ink(rug, 1.0)
    B.save(os.path.join(OUT, "cabin", "cabin_base.png"))

    F = Layer(12, CANVAS)
    # Engine box and companionway steps.
    F.piece(shape(v, "FurnitureVisual/EngineBox"), TEAK_DARK, 1.5)
    steps = shape(v, "FurnitureVisual/CompanionwaySteps")
    F.planks(steps, 11.0, TEAK_LIGHT, horizontal=False)
    F.ink(steps, 1.5)
    # Galley: teak counter, a two-burner stove, a round sink.
    galley = shape(v, "FurnitureVisual/Galley")
    F.shadow(galley, (4, 6), 4, 90)
    F.planks(galley, 8.0, TEAK, horizontal=True)
    F.ink(galley, 1.6)
    F.piece(F.rect(-318, -138, 58, 30), (70, 74, 78), 1.2, shadow=False)
    for x in (-300, -276):
        F.circle((x, -123), 8, (40, 42, 44), 1.0, shadow=False)
        F.circle((x, -123), 3.5, (120, 80, 60), 0.6, n=10, shadow=False)
    # (The right half of the counter is left plain: the provisions display
    # draws the food crates and water cans there.)
    # Navigation table with the chart, dividers and a lamp.
    nav = shape(v, "FurnitureVisual/NavTable")
    F.shadow(nav, (4, 6), 4, 90)
    F.planks(nav, 9.0, TEAK, horizontal=True)
    F.ink(nav, 1.6)
    chart = [(x - 232, y + 116) for x, y in v["FurnitureVisual/NavTable/ChartPaper"]["polygon"]]
    F.piece(chart, (236, 226, 196), 1.0, shadow=False)
    F.ink([(x - 232, y + 116) for x, y in v["FurnitureVisual/NavTable/ChartCourse"]["points"]], 0.9, SEAGLASS, closed=False)
    F.ink([(-248, 104), (-262, 118), (-250, 132)], 0.7, (130, 120, 110), closed=False)
    F.circle((-186, 98), 6, OCHRE, 1.0, n=14)
    # Settees with plump cushions and the saloon table.
    for name, sy in (("FurnitureVisual/SetteePort", -1), ("FurnitureVisual/SetteeStarboard", 1)):
        base = shape(v, name)
        F.shadow(base, (4, 6), 4, 90)
        F.fill(base, TEAK_DARK, 0.06)
        F.ink(base, 1.5)
        for i in range(3):
            x0 = -112 + i * 80
            cy = 128 * sy
            F.piece(F.rounded(x0, cy - 13, 74, 26, 9), CUSHION if i != 1 else (88, 140, 146), 1.3)
            F.line((x0 + 37, cy - 9), (x0 + 37, cy + 9), 0.6, INK, 70)
    F.piece(F.rounded(-55, -33, 130, 66, 8), TEAK, 1.8)
    F.hatch(F.rounded(-55, -33, 130, 66, 8), spacing=6, alpha=22, angle=0)
    F.planks(F.rounded(-50, -28, 120, 56, 6), 8.0, TEAK_LIGHT, horizontal=True, variation=0.05)
    F.ink(F.rounded(-55, -33, 130, 66, 8), 1.8)
    # Lockers and bulkheads forward, the V-berth with a blanket and pillow.
    for name in ("FurnitureVisual/StoragePort", "FurnitureVisual/StorageStarboard"):
        locker = shape(v, name)
        F.shadow(locker, (4, 6), 4, 90)
        F.planks(locker, 9.0, TEAK, horizontal=False)
        F.ink(locker, 1.5)
    for name in ("FurnitureVisual/BulkheadPort", "FurnitureVisual/BulkheadStarboard"):
        F.piece(shape(v, name), TEAK_DARK, 1.4)
    berth = shape(v, "FurnitureVisual/VBerth")
    F.shadow(berth, (4, 6), 5, 90)
    F.fill(berth, (226, 218, 196), 0.05)
    F.ink(berth, 1.6)
    blanket = [(x + 370, y) for x, y in v["FurnitureVisual/VBerth/Blanket"]["polygon"]]
    F.fill(blanket, BLANKET, 0.08)
    for i in range(-50, 51, 20):                                      # a simple check pattern
        F.line((316, i), (380, i * 0.85), 0.6, (220, 226, 230), 110)
    F.ink(blanket, 1.3)
    pillow = [(x + 370, y) for x, y in v["FurnitureVisual/VBerth/Pillow"]["polygon"]]
    F.piece(pillow, WHITE, 1.2, shadow=False)
    F.save(os.path.join(OUT, "cabin", "furniture.png"))

    # Small details on top: books, a teapot and mugs, a lamp, a plant, a towel.
    X = Layer(13, CANVAS)
    for i, color in enumerate(((160, 72, 60), (70, 104, 130), (200, 160, 80), (90, 120, 90), (130, 90, 120))):
        X.piece(X.rect(172 + i * 9, 100, 8, 14), color, 0.8, shadow=False)       # a row of books on the locker
    X.circle((-20, -6), 9, (210, 120, 90), 1.2)                                   # teapot
    X.ink([(-11, -6), (-4, -9)], 1.2, closed=False)
    X.circle((22, 8), 5, WHITE, 1.0, n=14)                                         # mugs
    X.circle((40, -10), 5, (130, 170, 176), 1.0, n=14)
    X.piece(X.rect(-46, 10, 26, 18), (236, 226, 196), 0.9, shadow=False)          # a postcard home
    X.line((-42, 16), (-25, 16), 0.5, INK, 120)
    X.line((-42, 21), (-30, 21), 0.5, INK, 120)
    X.circle((150, -50), 9, (150, 110, 80), 1.1, n=16)                             # a potted plant
    for a in range(0, 360, 60):
        r = math.radians(a)
        X.circle((150 + 7 * math.cos(r), -50 + 7 * math.sin(r)), 4, (96, 140, 80), 0.6, n=10, shadow=False)
    X.piece(X.rounded(-236, -96, 10, 22, 3), (196, 160, 110), 0.8, shadow=False)  # tea towel on the galley rail
    X.circle((290, -40), 6, OCHRE, 1.0, n=14)                                       # reading lamp by the berth
    X.save(os.path.join(OUT, "cabin", "cabin_details.png"))


if __name__ == "__main__":
    parts = sys.argv[1:] or ["deck", "cabin"]
    if "deck" in parts:
        paint_deck()
    if "cabin" in parts:
        paint_cabin()
