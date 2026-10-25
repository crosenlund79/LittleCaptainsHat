"""Bootstraps the Arctic Wanderer 26 scenes (the 26 ft starter monohull, 0.100b).

Writes into src/vessels/arctic_wanderer_26/:
  deck_visual.tscn   art only (VesselVisual with the named visual slots)
  deck.tscn          gameplay deck: Visual instance + Layout + SailRig + Player
  cabin_visual.tscn  art only (CabinBase, FurnitureVisual, CabinDetails)
  cabin.tscn         gameplay cabin: Visual instance + Layout + Companion + Player

Like build_multihull_scenes.py this is a one-time starting point, not a build
step, and it refuses to overwrite existing scenes unless --force is given.

    python3 tools/vessels/build_arctic_wanderer_26.py [--force]

Same conventions and scale as the other boats (about 30 units per foot; the
player's body has a radius of 20, so every passage is at least ~50 wide):
+x forward, -y port, +y starboard, origin amidships. The boat is 770 units
long against the Wing 33's 980, with a proportionally narrower beam, a short
cockpit steered by a tiller, a modest coachroof and a one-level cabin:
galley and chart table aft, two settees with a drop-leaf table, a bulkhead
at the mast and a V-berth forward.
"""
import os
import sys

sys.path.insert(0, os.path.dirname(__file__))
from build_multihull_scenes import (  # noqa: E402
    Builder, ROOT, ellipse, hull_outline, offset, surroundings, deck_root, deck_tail, cabin_root, cabin_tail,
    provision_display, visual_root, half_width_at,
    HULL, TEAK, TEAK_DARK, NONSKID, WELL, ROOF, GLASS, METAL, METAL_DARK, STEEL, SOLE, CABIN_HULL, WOOD,
    CUSHION, BLANKET)

ID = "arctic_wanderer_26"
STERN, BOW, HALF, STERN_HALF, BLUFF = -390, 380, 128, 104, 0.45
CANVAS = (-440, -160, 880, 320)
PONTOON_Y = 212
ROOF_X = (-180, 100)
ROOF_HALF = 54
COCKPIT = (-382, -200)      # cockpit well, transom .. companionway
COAMING = 78
COAMING_END = -250         # the coamings stop here: room to step out of the cockpit
MAST = (130, 0)
LIFELINE_FWD = 350


def hull():
    return hull_outline(STERN, BOW, HALF, STERN_HALF, bluff=BLUFF)


def lifeline():
    """Walkable deck: the hull inset 12, cut square at the pulpit."""
    inner = hull_outline(STERN + 12, BOW - 16, HALF - 12, STERN_HALF - 12, bluff=BLUFF)
    port = sorted(p for p in inner if p[1] <= 0 and p[0] < LIFELINE_FWD)
    port.append((LIFELINE_FWD, -half_width_at(inner, LIFELINE_FWD)))
    return port + [(x, -y) for x, y in reversed(port)]


def roof():
    r0, r1 = ROOF_X
    h = ROOF_HALF
    return [(r0, -h), (r1 - 40, -h), (r1, -h + 20), (r1, h - 20), (r1 - 40, h), (r0, h)]


# Deck furniture: name, centre, size.
BENCHES = [("BenchPort", (-312, -62), (120, 22)), ("BenchStarboard", (-312, 62), (120, 22))]
TILLER = ((-336, 0), (72, 8))


def build_deck_visual():
    b = Builder()
    visual_root(b, CANVAS)
    h = hull()
    b.slot("ShadowVisual")
    b.poly("HullShadow", "ShadowVisual", offset(h, 7, 10), "#000000", 0.25)

    b.slot("HullBase")
    b.poly("Hull", "HullBase", h, HULL)
    b.line("ToeRail", "HullBase", h, 5, TEAK, closed=True)

    b.slot("DeckBase")
    b.poly("DeckSurface", "DeckBase", hull_outline(STERN + 8, BOW - 12, HALF - 9, STERN_HALF - 9, bluff=BLUFF), NONSKID)
    c0, c1 = COCKPIT
    b.poly("Cockpit", "DeckBase", [(c0, -COAMING + 4), (c1, -COAMING + 4), (c1, COAMING - 4), (c0, COAMING - 4)], WELL)
    for name, pos, size in BENCHES:
        b.shape(name, "DeckBase", pos, TEAK, size=size)
    b.shape("CompanionHatch", "DeckBase", (c1 + 8, 0), TEAK_DARK, size=(18, 56))
    b.shape("Washboards", "DeckBase", (c1 - 4, 0), TEAK, size=(8, 50))

    b.slot("Coachroof")
    b.shape("Coachroof", "Coachroof", (0, 0), ROOF, polygon=roof())
    for i, x in enumerate((-130, -60, 10)):
        b.poly(f"Portlight{i}", "Coachroof/Coachroof", [(x - 18, -ROOF_HALF + 4), (x + 18, -ROOF_HALF + 4), (x + 18, -ROOF_HALF + 10), (x - 18, -ROOF_HALF + 10)], GLASS, 0.75)
        b.poly(f"PortlightS{i}", "Coachroof/Coachroof", [(x - 18, ROOF_HALF - 10), (x + 18, ROOF_HALF - 10), (x + 18, ROOF_HALF - 4), (x - 18, ROOF_HALF - 4)], GLASS, 0.75)
    b.poly("ForeHatch", "Coachroof/Coachroof", [(40, -20), (76, -20), (76, 20), (40, 20)], "#A6C4C9", 0.6)
    b.poly("SlidingHatch", "Coachroof/Coachroof", [(-176, -24), (-132, -24), (-132, 24), (-176, 24)], TEAK)

    b.slot("DeckDetails")
    b.shape("RudderHead", "DeckDetails", (-372, 0), METAL_DARK, polygon=ellipse(0, 0, 8, 8, 12))
    b.shape("Tiller", "DeckDetails", TILLER[0], TEAK, size=TILLER[1])
    for i, side in enumerate((-1, 1)):
        b.shape(f"Winch{i}", "DeckDetails", (-214, side * 64), METAL_DARK, polygon=ellipse(0, 0, 8, 8, 10))
        b.shape(f"Cleat{i}", "DeckDetails", (-366, side * 88), METAL, size=(18, 7))
        b.shape(f"BowCleat{i}", "DeckDetails", (300, side * 40), METAL, size=(18, 7))
    b.shape("AnchorLocker", "DeckDetails", (300, 0), WELL, size=(44, 34))
    b.shape("BowRoller", "DeckDetails", (370, 0), METAL, size=(22, 9))
    b.line("Lifelines", "DeckDetails", lifeline(), 2, STEEL, 0.65, closed=True, z=6)
    b.line("Pulpit", "DeckDetails", [(326, -34), (362, 0), (326, 34)], 4, STEEL, 0.9, z=6)
    b.line("Pushpit", "DeckDetails", [(-366, -84), (-384, -64), (-384, 64), (-366, 84)], 4, STEEL, 0.9, z=6)
    b.node("Labels", "Node2D", "DeckDetails", ["z_index = 5"])
    big = b.label_settings(15, "#102D3B", 0.6)
    small = b.label_settings(13, "#102D3B", 0.55)
    for name, text, pos, st in [("Cockpit", "COCKPIT", (-290, 30), big), ("Helm", "TILLER", (-336, -24), small),
                                ("Coachroof", "COACHROOF", (-40, 0), small), ("Bow", "BOW", (300, -60), big),
                                ("Mast", "MAST", (140, -28), big)]:
        b.label(name, "DeckDetails/Labels", text, pos, st)

    b.slot("RiggingVisual", z=2)
    mx, my = MAST
    b.line("Shrouds", "RiggingVisual", [(mx - 18, -HALF + 14), (mx, my), (mx - 18, HALF - 14)], 2, STEEL, 0.8)
    b.line("Forestay", "RiggingVisual", [(mx, my), (360, 0)], 2, STEEL, 0.8)
    b.line("Backstay", "RiggingVisual", [(mx, my), (-384, 0)], 1.5, STEEL, 0.55)

    b.slot("MastVisual", z=3)
    b.shape("Mast", "MastVisual", MAST, "#B9C1C5", polygon=[(13, 0), (5, 7), (-11, 5), (-11, -5), (5, -7)])
    return b


def build_deck():
    b = Builder()
    deck_root(b, ID, (-400, -150, 800, 300))
    surroundings(b, PONTOON_Y, "GUEST PONTOON · COPENHAGEN",
                 {"SternLine": ((-360, 96), -400), "BowLine": ((292, 70), 330)}, (-400, 330), 40, -150)
    b.node("Visual", None, ".", [], instance=b.res("PackedScene", f"res://src/vessels/{ID}/deck_visual.tscn"))
    b.node("Layout", "Node2D", ".")
    b.node("Collision", "Node2D", "Layout")
    b.boundary("Lifeline", [lifeline()])
    c0, c1 = COCKPIT
    b.node("Coamings", "StaticBody2D", "Layout/Collision", ["collision_layer = 1", "collision_mask = 0"])
    for name, side in (("Port", -1), ("Starboard", 1)):
        b.node(name, "CollisionPolygon2D", "Layout/Collision/Coamings",
               ["build_mode = 1", f"polygon = PackedVector2Array({STERN}, {side * COAMING}, {COAMING_END}, {side * COAMING})"])
    for name, pos, size in BENCHES:
        b.fixture(name, pos, size=size)
    b.fixture("Coachroof", (0, 0), polygon=roof())
    b.fixture("Mast", MAST, polygon=ellipse(0, 0, 12, 12, 16))
    b.fixture("RudderHead", (-372, 0), polygon=ellipse(0, 0, 8, 8, 12))
    b.fixture("Tiller", TILLER[0], size=TILLER[1])
    b.node("Stations", "Node2D", "Layout")
    b.station("Companionway", (c1 + 4, 0), "companionway", "Go below", ("rect", (36, 96)))
    b.station("Helm", (-346, 0), "helm", "Take the tiller", ("circle", 30))
    b.station("Boatyard", (40, 116), "boatyard", "Visit the boatyard", ("rect", (160, 40)))
    b.station("Grocery", (-150, 116), "grocery", "Visit the grocery store", ("rect", (120, 40)))
    b.markers("SpawnPoints", {"start": (-252, 0), "from_cabin": (c1 - 22, 0), "from_boatyard": (40, 84)})
    b.markers("SailMarkers", {"Mast": MAST, "Tack": (356, 0), "BoomEnd": (-190, 0), "Traveller": (-262, 0),
                              "JibSheetLead": (-160, 92), "SpinnakerSheetLead": (-360, 96)})
    deck_tail(b, ID, (0, 45), 1.5)
    return b


# ---------------------------------------------------------------- cabin

CABIN_OUTLINE_PORT = [(-250, -100), (-200, -107), (-150, -113), (-60, -117), (40, -117), (120, -112), (180, -100),
                      (230, -86), (275, -64), (310, -38), (332, -14), (338, 0)]
BULKHEAD_X = 176


def cabin_outline():
    port = CABIN_OUTLINE_PORT
    return port + [(x, -y) for x, y in reversed(port) if y != 0]


def cabin_hull():
    """The hull around the cabin, ending at the companionway bulkhead."""
    return [(max(x, -262), y) for x, y in hull_outline(STERN - 4, BOW + 4, HALF + 4, STERN_HALF + 4, bluff=BLUFF)]


V_BERTH = [(200, -80), (262, -62), (320, -24), (320, 24), (262, 62), (200, 80)]
# name, centre, size or None, polygon or None, solid, colour
FURNITURE = [
    ("EngineBox", (-237, 0), (26, 70), None, True, "#4B5357"),
    ("CompanionwaySteps", (-208, 0), (32, 76), None, True, "#7A5C40"),
    ("Galley", (-152, -90), (96, 32), None, True, WOOD),
    ("NavTable", (-156, 90), (80, 30), None, True, WOOD),
    ("SetteePort", (40, -92), (168, 30), None, True, CUSHION),
    ("SetteeStarboard", (40, 92), (168, 30), None, True, CUSHION),
    ("SaloonTable", (40, 0), (80, 34), None, True, WOOD),
    ("MastPost", (140, 0), None, ellipse(0, 0, 8, 8, 12), True, METAL),
    ("Shelf", (150, 94), (36, 22), None, True, WOOD),
    ("VBerth", (0, 0), None, V_BERTH, True, BLANKET),
]


def bulkheads():
    return [("BulkheadPort", (BULKHEAD_X, -78), (12, 60)), ("BulkheadStarboard", (BULKHEAD_X, 78), (12, 60))]


def build_cabin_visual():
    b = Builder()
    visual_root(b, CANVAS)
    outline = cabin_outline()
    b.slot("CabinBase")
    b.poly("HullShape", "CabinBase", cabin_hull(), CABIN_HULL)
    b.poly("CabinSole", "CabinBase", outline, SOLE)
    for i, (y, x1) in enumerate(((-80, 216), (-40, 296), (0, 326), (40, 296), (80, 216))):
        b.line(f"Seam{i}", "CabinBase", [(-240, y), (x1, y)], 2, "#5E4733", 0.35)
    b.line("CabinSide", "CabinBase", outline, 12, "#5E4733", closed=True)
    for i, x in enumerate((-130, -60, 10)):
        b.line(f"Portlight{i}", "CabinBase", [(x - 18, -115), (x + 18, -115)], 5, GLASS, 0.85)
        b.line(f"PortlightS{i}", "CabinBase", [(x - 18, 115), (x + 18, 115)], 5, GLASS, 0.85)

    b.slot("FurnitureVisual")
    for name, pos, size in bulkheads():
        b.shape(name, "FurnitureVisual", pos, "#5E4733", size=size)
    for name, pos, size, poly, solid, col in FURNITURE:
        b.shape(name, "FurnitureVisual", pos, col, size=size, polygon=poly)
    for k in range(3):
        b.line(f"Step{k}", "FurnitureVisual/CompanionwaySteps", [(-10 + k * 10, -34), (-10 + k * 10, 34)], 3, "#4A3626", 0.8)
    b.poly("Burner0", "FurnitureVisual/Galley", ellipse(-30, 0, 8, 8, 12), "#2A2F33")
    b.poly("Burner1", "FurnitureVisual/Galley", ellipse(-8, 0, 8, 8, 12), "#2A2F33")
    b.poly("Sink", "FurnitureVisual/Galley", [(16, -9), (40, -9), (40, 9), (16, 9)], "#A6C4C9", 0.8)
    b.poly("ChartPaper", "FurnitureVisual/NavTable", [(-30, -10), (26, -10), (26, 10), (-30, 10)], "#EFE5CC", 0.9)
    b.poly("TableLeaf", "FurnitureVisual/SaloonTable", [(-36, -15), (36, -15), (36, -12), (-36, -12)], "#4A3626", 0.6)
    b.poly("Pillow0", "FurnitureVisual/VBerth", [(286, -36), (312, -18), (312, -3), (286, -3)], "#EFE5CC", 0.85)
    b.poly("Pillow1", "FurnitureVisual/VBerth", [(286, 3), (312, 3), (312, 18), (286, 36)], "#EFE5CC", 0.85)

    b.slot("CabinDetails")
    b.node("Labels", "Node2D", "CabinDetails", ["z_index = 5"])
    big = b.label_settings(15, "#EFE5CC", 0.62)
    small = b.label_settings(13, "#EFE5CC", 0.55)
    for name, text, pos, st in [("Saloon", "SALOON", (40, -40), big), ("Galley", "GALLEY", (-152, -62), small),
                                ("Chart", "CHART TABLE", (-156, 62), small), ("Berth", "V-BERTH", (262, -6), small)]:
        b.label(name, "CabinDetails/Labels", text, pos, st)
    return b


def build_cabin():
    b = Builder()
    cabin_root(b, (-255, -125, 600, 250))
    b.node("Visual", None, ".", [], instance=b.res("PackedScene", f"res://src/vessels/{ID}/cabin_visual.tscn"))
    provision_display(b, (-152, -92))
    b.node("Layout", "Node2D", ".")
    b.node("Collision", "Node2D", "Layout")
    b.boundary("Hull", [cabin_outline()])
    for name, pos, size in bulkheads():
        b.fixture(name, pos, size=size)
    for name, pos, size, poly, solid, col in FURNITURE:
        b.fixture(name, pos, size=size, polygon=poly, solid=solid)
    b.node("Stations", "Node2D", "Layout")
    b.station("Companionway", (-180, 0), "companionway", "Go on deck", ("rect", (30, 76)))
    b.station("Chart", (-156, 66), "nav_table", "Open chart", ("rect", (80, 20)))
    b.station("Provisions", (-152, -64), "provisions", "Check provisions", ("rect", (90, 20)))
    b.station("Work", (40, 26), "work", "Work remotely", ("rect", (80, 20)))
    b.station("Berth", (192, 0), "bed", "Sleep", ("rect", (24, 100)))
    # The captain's hat hangs on a hook on the starboard side, above the end
    # of the settee (well away from the berth, the table and the cat's spots).
    b.station("Hat", (120, 92), "hat", "Put on captain's hat", ("circle", 24))
    b.node("HatSpot", "Marker2D", "Layout", ["position = Vector2(122, 96)"])
    b.markers("SpawnPoints", {"start": (-60, 0), "from_deck": (-166, 0), "v_berth": (180, 0)})
    b.markers("CompanionSpots", {"settee": (70, -92), "nav_station": (-130, 92), "v_berth": (262, 30),
                                 "cabin_floor": (-100, 36), "companionway": (-150, -40), "seating": (-20, 62)})
    cabin_tail(b, (40, 0), 1.7)
    return b


def main(argv):
    force = "--force" in argv
    out = os.path.join(ROOT, "src", "vessels", ID)
    os.makedirs(out, exist_ok=True)
    build_deck_visual().write(os.path.join(out, "deck_visual.tscn"), force)
    build_deck().write(os.path.join(out, "deck.tscn"), force)
    build_cabin_visual().write(os.path.join(out, "cabin_visual.tscn"), force)
    build_cabin().write(os.path.join(out, "cabin.tscn"), force)


if __name__ == "__main__":
    main(sys.argv[1:])
