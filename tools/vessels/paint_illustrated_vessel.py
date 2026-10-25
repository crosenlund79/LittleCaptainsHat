"""Paints a vessel's illustrated art profile from its own art scenes (0.100b).

Usage: python3 tools/vessels/paint_illustrated_vessel.py <vessel_id> [deck] [cabin]

For halcyon_40 (Clam 40), petrel_36 (Frogleap 36) and arctic_wanderer_26 (Arctic
Wanderer 26). The Wing 33 (starling_33) keeps its own painter,
paint_illustrated_starling.py, which shares the same toolkit.

Every shape of src/vessels/<id>/deck_visual.tscn and cabin_visual.tscn is
repainted in the illustrated style, chosen by the shape's palette colour
(those scenes use one small palette): cream hulls with ink outlines; marine
teak decks (margin boards, curved and fore-and-aft strips, caulking) with the
coachroof, cockpits, nets and hatches cut out; teak-and-holly cockpit soles;
trampolines as rope nets; planked furniture; plump cushions; made-up berths;
glass, metal and tiles. Then a few cozy details per boat (EXTRAS). Because
the shapes come from the scenes that also hold the layout, the art lines up
with the unchanged collision and stations.

Writes full-canvas PNGs (2 px per unit) to assets/vessels/<id>/illustrated/.
Shadow, rigging, mast and sails stay procedural. Requires Pillow, numpy and
shapely.
"""
import math
import os
import re
import sys

sys.path.insert(0, os.path.dirname(__file__))
from illustrate import *  # noqa: E402,F403
from illustrate import ROOT, Layer, teak_deck, teak_sole  # noqa: E402
from shapely.geometry import Polygon  # noqa: E402

DECK_SLOTS = {"HullBase": "hull_base", "DeckBase": "deck_base", "Coachroof": "coachroof", "DeckDetails": "deck_details"}
CABIN_SLOTS = {"CabinBase": "cabin_base", "FurnitureVisual": "furniture", "CabinDetails": "cabin_details"}

# Palette of the generated scenes (rounded RGB) -> material.
MATERIALS = {
    (239, 229, 204): "cream",
    (212, 204, 180): "deck",
    (180, 171, 147): "sole",
    (138, 106, 74): "teak",
    (94, 71, 51): "darkwood",
    (110, 84, 64): "wood",
    (122, 92, 64): "steps",
    (63, 120, 128): "teal",
    (168, 180, 160): "berth",
    (166, 196, 201): "glass",
    (94, 100, 104): "metal",
    (61, 63, 65): "metal_dark",
    (185, 193, 197): "metal",
    (201, 210, 214): "metal_light",
    (22, 50, 64): "interior",
    (154, 122, 87): "cabin_sole",
    (122, 138, 143): "tile",
    (143, 163, 168): "tile_light",
    (42, 47, 51): "stove",
    (46, 74, 82): "net",
    (201, 209, 190): "fold",
    (75, 83, 87): "metal_dark",
    (75, 85, 87): "metal_dark",
    (16, 45, 59): "ink",
    (74, 54, 38): "darkwood",
    (46, 90, 96): "teal_dark",
}


def rgb(c):
    return tuple(int(round(float(x) * 255)) for x in c[:3])


def parse_nodes(path):
    """Node path -> {"type", "polygon", "points", "position", "size", "color", "width"} in scene order."""
    nodes, order, cur = {}, [], None
    for line in open(path):
        m = re.match(r'\[node name="([^"]+)"(?: type="([^"]+)")?(?:.*parent="([^"]*)")?', line)
        if m:
            parent = m.group(3) or ""
            cur = (parent + "/" if parent not in ("", ".") else "") + m.group(1)
            nodes[cur] = {"type": m.group(2) or "", "parent": parent}
            order.append(cur)
            continue
        if cur is None:
            continue
        m = re.match(r"(polygon|points) = PackedVector2Array\(([^)]*)\)", line)
        if m:
            v = [float(x) for x in m.group(2).split(",") if x.strip()]
            nodes[cur][m.group(1)] = list(zip(v[::2], v[1::2]))
        m = re.match(r"(position|size) = Vector2\(([-\d.e]+), ([-\d.e]+)\)", line)
        if m:
            nodes[cur][m.group(1)] = (float(m.group(2)), float(m.group(3)))
        m = re.match(r"(fill_color|color|default_color) = Color\(([^)]*)\)", line)
        if m:
            nodes[cur]["color"] = [float(x) for x in m.group(2).split(",")]
        m = re.match(r"width = ([\d.]+)", line)
        if m:
            nodes[cur]["width"] = float(m.group(1))
        m = re.match(r"script = ExtResource", line)
        if m:
            nodes[cur]["script"] = True
    return nodes, order


def offset_of(nodes, name):
    x = y = 0.0
    while name:
        n = nodes.get(name)
        if n is None:
            break
        px, py = n.get("position", (0.0, 0.0))
        x, y = x + px, y + py
        name = n["parent"] if n["parent"] not in (".", "") else ""
        if name in ("", "."):
            break
    return x, y


def outline(nodes, name):
    n = nodes[name]
    ox, oy = offset_of(nodes, name)
    if "polygon" in n:
        return [(x + ox, y + oy) for x, y in n["polygon"]]
    if "size" in n:
        w, h = n["size"]
        return [(ox - w / 2, oy - h / 2), (ox + w / 2, oy - h / 2), (ox + w / 2, oy + h / 2), (ox - w / 2, oy + h / 2)]
    return None


def line_points(nodes, name):
    n = nodes[name]
    ox, oy = offset_of(nodes, n["parent"]) if n["parent"] not in ("", ".") else (0.0, 0.0)
    px, py = n.get("position", (0.0, 0.0))
    return [(x + ox + px, y + oy + py) for x, y in n.get("points", [])]


def material(n):
    c = n.get("color")
    if not c:
        return "wood"
    key = rgb(c)
    if key in MATERIALS:
        return MATERIALS[key]
    best = min(MATERIALS, key=lambda k: sum((a - b) ** 2 for a, b in zip(k, key)))
    return MATERIALS[best]


def slot_children(order, slot):
    return [p for p in order if p.startswith(slot + "/")]


# ------------------------------------------------------------------ painting

def paint_shape(L, nodes, name, holes_for_deck, king=None):
    n = nodes[name]
    if n["type"] == "Label" or "/Labels" in name:
        return
    mat = material(n)
    alpha = n.get("color", [0, 0, 0, 1])[3] if n.get("color") and len(n["color"]) > 3 else 1.0
    if n["type"] == "Line2D":
        pts = line_points(nodes, name)
        if len(pts) < 2:
            return
        width = n.get("width", 2.0)
        if mat in ("teak", "darkwood"):
            L.ink(pts, width * 0.6, TEAK if mat == "teak" else TEAK_DARK, closed=False, amp=0.3, alpha=255)
            L.ink(pts, 0.6, INK, closed=False, amp=0.3, alpha=150)
        elif mat in ("metal_light", "metal"):
            L.ink(pts, max(width * 0.45, 0.8), (205, 210, 214), closed=False, amp=0.25, alpha=int(255 * min(alpha + 0.2, 1)))
        elif mat == "glass" or mat == "teal":
            L.ink(pts, width * 0.55, SEAGLASS, closed=False, amp=0.3, alpha=230)
            L.ink(pts, 0.6, (230, 240, 240), closed=False, amp=0.3, alpha=120)
        elif mat == "ink":
            L.ink(pts, width * 0.5, INK, closed=False, amp=0.4, alpha=int(255 * alpha))
        else:
            L.ink(pts, max(width * 0.5, 0.7), INK, closed=False, amp=0.3, alpha=int(180 * alpha))
        return
    pts = outline(nodes, name)
    if not pts or len(pts) < 3:
        return
    if mat == "cream":
        L.piece(pts, HULL if "Hull" in name or "Aka" in name or "Ama" in name or "Bridgedeck" in name else WHITE, 1.6,
                shade=False, shadow=False)
    elif mat == "deck":
        holes = [h for h in holes_for_deck if Polygon(h).intersects(Polygon(pts))]
        teak_deck(L, pts, holes=holes, king_plank=king(pts) if king else None)
    elif mat == "sole":
        if "Locker" in name or "Hatch" in name:
            L.piece(pts, TEAK_LIGHT, 1.3)
            teak_deck(L, pts, strip=4.0, margin=3.5, sprung=0)
        else:
            L.shadow(pts, (3, 4), 3, 70)
            teak_sole(L, pts)
    elif mat == "teak":
        L.shadow(pts, (3, 4), 3, 70)
        teak_deck(L, pts, strip=4.0, margin=3.5, sprung=0)
    elif mat in ("wood", "darkwood", "steps"):
        color = {"wood": TEAK, "darkwood": TEAK_DARK, "steps": TEAK_LIGHT}[mat]
        L.shadow(pts, (4, 5), 3, 80)
        xs = [p[0] for p in pts]
        ys = [p[1] for p in pts]
        L.planks(pts, 8.0 if mat != "steps" else 9.0, color, horizontal=(max(xs) - min(xs)) >= (max(ys) - min(ys)))
        L.ink(pts, 1.5)
    elif mat in ("teal", "teal_dark"):
        if alpha < 0.95:  # glass in a teal tint (sliding doors, windows)
            L.fill(pts, SEAGLASS, 0.08, alpha=int(255 * alpha))
            L.ink(pts, 1.1)
            return
        cushions(L, pts)
    elif mat == "berth":
        pillows = [outline(nodes, c) for c in nodes if c.startswith(name + "/") and "Pillow" in c]
        px = [x for o in pillows if o for x, _ in o]
        berth(L, pts, sum(px) / len(px) if px else None)
    elif mat == "fold":
        L.fill(pts, (226, 230, 214), 0.04)
        L.ink(pts, 0.9, alpha=150)
    elif mat == "glass":
        L.fill(pts, SEAGLASS if "Window" in name or "Portlight" in name else (170, 200, 204), 0.08, alpha=int(255 * max(alpha, 0.6)))
        xs = [p[0] for p in pts]
        ys = [p[1] for p in pts]
        L.line((min(xs) + 3, min(ys) + 3), (min(xs) + (max(xs) - min(xs)) * 0.55, min(ys) + 3), 0.8, WHITE, 130)
        L.ink(pts, 1.1)
    elif mat in ("metal", "metal_dark", "metal_light"):
        color = {"metal": (150, 156, 160), "metal_dark": (80, 84, 88), "metal_light": (200, 206, 210)}[mat]
        L.piece(pts, color, 1.1, shade=False)
    elif mat == "interior":
        L.fill(pts, (62, 52, 44), 0.08, alpha=int(255 * alpha))
        L.ink(pts, 2.0, alpha=int(235 * alpha))
    elif mat == "cabin_sole":
        L.shadow(pts, (0, 0), 6, 120)
        L.planks(pts, 15.0, HONEY, seam=(110, 84, 58), horizontal=True)
        L.ink(pts, 1.6)
    elif mat in ("tile", "tile_light"):
        L.fill(pts, (196, 206, 204) if mat == "tile" else (214, 224, 222), 0.03)
        L.hatch(pts, spacing=10.0, width=0.4, alpha=110, angle=0.0, color=(150, 160, 160))
        L.hatch(pts, spacing=10.0, width=0.4, alpha=110, angle=90.0, color=(150, 160, 160))
        L.ink(pts, 1.3)
    elif mat == "stove":
        L.piece(pts, (40, 42, 44), 0.9, shade=False, shadow=False)
    elif mat == "net":
        paint_net(L, pts)
    elif mat == "ink":
        L.fill(pts, INK, 0.0, alpha=int(255 * alpha))


def paint_net(L, pts):
    """A trampoline or safety net: rope mesh over the water, a rope border."""
    L.fill(pts, (40, 70, 78), 0.05, alpha=150)
    L.hatch(pts, spacing=14.0, width=0.6, alpha=140, angle=0.0, color=ROPE)
    L.hatch(pts, spacing=14.0, width=0.6, alpha=140, angle=90.0, color=ROPE)
    L.ink(pts, 2.2, ROPE, alpha=230)
    L.ink(pts, 0.8, INK, alpha=160)


def cushions(L, pts):
    """A settee: a teak base with plump cushions along its length."""
    xs = [p[0] for p in pts]
    ys = [p[1] for p in pts]
    x0, x1, y0, y1 = min(xs), max(xs), min(ys), max(ys)
    L.shadow(pts, (4, 6), 4, 90)
    L.fill(pts, TEAK_DARK, 0.06)
    L.ink(pts, 1.4)
    along_x = (x1 - x0) >= (y1 - y0)
    length = (x1 - x0) if along_x else (y1 - y0)
    count = max(1, int(round(length / 72.0)))
    gap = 3.0
    for i in range(count):
        if along_x:
            a = x0 + gap + i * (length - gap) / count
            L.piece(L.rounded(a, y0 + 3, (length - gap) / count - gap, (y1 - y0) - 6, 8),
                    CUSHION if i % 2 == 0 else (88, 140, 146), 1.2)
        else:
            a = y0 + gap + i * (length - gap) / count
            L.piece(L.rounded(x0 + 3, a, (x1 - x0) - 6, (length - gap) / count - gap, 8),
                    CUSHION if i % 2 == 0 else (88, 140, 146), 1.2)


def berth(L, pts, pillow_x=None):
    """A made-up berth: mattress and a blue check blanket over the part away
    from the pillows."""
    L.shadow(pts, (4, 6), 5, 90)
    L.fill(pts, (226, 218, 196), 0.05)
    L.ink(pts, 1.5)
    xs = [p[0] for p in pts]
    ys = [p[1] for p in pts]
    x0, x1 = min(xs), max(xs)
    if pillow_x is not None and pillow_x < (x0 + x1) / 2:
        a, b = x0 + (x1 - x0) * 0.38, x1 + 1  # pillows aft: the blanket forward
    else:
        a, b = x0 - 1, x0 + (x1 - x0) * 0.62
    clip = Polygon(pts).intersection(Polygon([(a, min(ys) - 1), (b, min(ys) - 1), (b, max(ys) + 1), (a, max(ys) + 1)]))
    blanket_end = b
    if not clip.is_empty and clip.geom_type == "Polygon":
        bl = list(clip.exterior.coords)[:-1]
        L.fill(bl, BLANKET, 0.08)
        for k in range(1, 5):
            y = min(ys) + (max(ys) - min(ys)) * k / 5
            L.line((max(a, x0) + 3, y), (min(b, x1) - 3, y), 0.6, (220, 226, 230), 110, 0.2)
        L.ink(bl, 1.2)


def illustrate(vessel, area):
    path = os.path.join(ROOT, "src/vessels/%s/%s_visual.tscn" % (vessel, area))
    nodes, order = parse_nodes(path)
    canvas_line = re.search(r"canvas = Rect2\(([^)]*)\)", open(path).read())
    canvas = tuple(int(float(x)) for x in canvas_line.group(1).split(","))
    slots = DECK_SLOTS if area == "deck" else CABIN_SLOTS
    out = os.path.join(ROOT, "assets", "vessels", vessel, "illustrated", area)
    holes = []
    for name in order:
        n = nodes[name]
        if name.startswith("Coachroof/") and name.count("/") == 1 and material(n) in ("cream",) and n["type"] != "Line2D":
            o = outline(nodes, name)
            if o and len(o) >= 3:
                holes.append(o)
        if name.startswith("DeckBase/") and material(n) in ("sole", "net") and n["type"] != "Line2D":
            o = outline(nodes, name)
            if o and len(o) >= 3:
                holes.append(o)
    roof_front = max((x for h in holes for x, _ in h), default=None)
    # Nets drawn only as lines in the scene (the trimaran's): one net per
    # group of NetLine<g><n> lines, over their outline.
    net_groups = {}
    for name in order:
        m = re.match(r"DeckBase/NetLine(\d)\d+$", name)
        if m:
            net_groups.setdefault(m.group(1), []).extend(line_points(nodes, name))
    king = KING.get(vessel)
    for i, (slot, file_name) in enumerate(slots.items()):
        L = Layer(100 + i, canvas)
        for name in slot_children(order, slot):
            if nodes[name]["type"] == "Label" or "/Labels" in name:
                continue
            if any(seg.startswith("Net") and seg[3:].isdigit() or seg.startswith("NetLine") or seg.startswith("NetCross")
                   for seg in name.split("/")[1:]):
                continue  # the procedural net lines: the net is painted by its polygon
            paint_shape(L, nodes, name, holes, king=(lambda pts, k=king: k(pts, roof_front)) if king else None)
        if slot == "DeckBase":
            for pts in net_groups.values():
                hull = Polygon(pts).convex_hull if len(pts) >= 3 else None
                if hull is not None and hull.geom_type == "Polygon":
                    paint_net(L, list(hull.exterior.coords)[:-1])
        extra = EXTRAS.get((vessel, slot))
        if extra:
            extra(L)
        L.save(os.path.join(out, file_name + ".png"))


# ------------------------------------------------------------------ boat by boat

def _king_monohull(pts, roof_front):
    """A king plank on a single hull's foredeck, from the coachroof to near the bow."""
    xs = [p[0] for p in pts]
    if roof_front is None or max(xs) - roof_front < 80:
        return None
    return (roof_front + 6, max(xs) - 30)


KING = {"petrel_36": _king_monohull, "arctic_wanderer_26": _king_monohull}


def _halcyon_deck(L):
    # Lines coiled by the winches, cushions in the cockpit, a fender basket.
    L.coil((-252, -112), 10)
    L.coil((-252, 112), 10, color=(196, 116, 92))
    L.piece(L.rounded(-380, -100, 22, 60, 6), CUSHION, 1.1)
    L.piece(L.rounded(-380, 30, 22, 60, 6), (192, 112, 84), 1.1)
    L.circle((-330, 104), 6, (196, 120, 70), 0.9, n=14)        # a bucket
    for x in (-300, -40, 220):                                   # fenders, harbour side
        L.line((x, 276), (x, 286), 0.7, ROPE, 220)
        L.piece(L.rounded(x - 7, 284, 14, 26, 6), (238, 236, 228), 1.2)


def _halcyon_roof(L):
    L.piece(L.rounded(-60, -150, 40, 26, 5), (110, 140, 96), 1.0)  # herb box
    for (x, y) in ((-50, -141), (-38, -134), (-28, -143)):
        L.circle((x, y), 4, (96, 140, 80), 0.6, n=10, shadow=False)
    L.coil((60, 120), 12)


def _halcyon_details(L):
    # Books, a mug, a plant and a rug: the saloon is the heart of the boat.
    for i, color in enumerate(((160, 72, 60), (70, 104, 130), (200, 160, 80), (90, 120, 90))):
        L.piece(L.rect(-232 + i * 9, -298, 8, 14), color, 0.8, shadow=False)
    L.circle((-30, 60), 9, (210, 120, 90), 1.2)
    L.circle((-70, 80), 5, WHITE, 1.0, n=14)
    L.circle((-10, 84), 5, (130, 170, 176), 1.0, n=14)
    L.circle((40, -40), 9, (150, 110, 80), 1.1, n=16)
    for a in range(0, 360, 60):
        r = math.radians(a)
        L.circle((40 + 7 * math.cos(r), -40 + 7 * math.sin(r)), 4, (96, 140, 80), 0.6, n=10, shadow=False)
    rug = [(30 + 38 * math.cos(a), 20 + 22 * math.sin(a)) for a in [i * math.pi / 20 for i in range(40)]]
    L.fill(rug, (176, 112, 92), 0.08, alpha=200)
    L.ink(rug, 0.9)
    L.circle((-330, -280), 6, OCHRE, 1.0, n=14)                    # reading lamp


def _petrel_deck(L):
    L.coil((-182, -48), 9)
    L.coil((-182, 48), 9, color=(196, 116, 92))
    L.piece(L.rounded(-360, -84, 50, 18, 6), CUSHION, 1.1)
    for x in (-250, 60):                                          # fenders on the starboard float
        L.line((x, 268), (x, 278), 0.7, ROPE, 220)
        L.piece(L.rounded(x - 7, 276, 14, 24, 6), (238, 236, 228), 1.2)


def _petrel_details(L):
    L.circle((-10, -4), 8, (210, 120, 90), 1.2)                    # teapot on the table
    L.circle((24, 6), 4.5, WHITE, 1.0, n=14)
    for i, color in enumerate(((160, 72, 60), (70, 104, 130), (200, 160, 80))):
        L.piece(L.rect(140 + i * 9, 84, 8, 13), color, 0.8, shadow=False)
    L.circle((120, -60), 8, (150, 110, 80), 1.1, n=16)
    for a in range(0, 360, 60):
        r = math.radians(a)
        L.circle((120 + 6 * math.cos(r), -60 + 6 * math.sin(r)), 3.5, (96, 140, 80), 0.6, n=10, shadow=False)
    L.circle((250, -38), 5, OCHRE, 1.0, n=14)


def _wanderer_deck(L):
    L.coil((-215, -52), 8)
    L.coil((-215, 52), 8, color=(196, 116, 92))
    L.piece(L.rounded(-330, -64, 40, 16, 5), CUSHION, 1.0)
    L.circle((-318, 38), 5, (196, 120, 70), 0.9, n=14)             # a bucket
    for x in (-220, 40):
        L.line((x, 126), (x, 136), 0.7, ROPE, 220)
        L.piece(L.rounded(x - 6, 134, 12, 22, 5), (238, 236, 228), 1.1)


def _wanderer_roof(L):
    L.coil((40, -44), 9)


def _wanderer_details(L):
    L.circle((-40, -4), 7, (210, 120, 90), 1.1)                    # kettle on the little table
    L.circle((-14, 8), 4, WHITE, 1.0, n=12)
    for i, color in enumerate(((160, 72, 60), (70, 104, 130), (200, 160, 80))):
        L.piece(L.rect(96 + i * 8, 58, 7, 12), color, 0.8, shadow=False)  # books on the shelf
    L.circle((150, 30), 5, OCHRE, 1.0, n=12)                        # reading lamp by the berth
    L.piece(L.rounded(-170, -64, 9, 18, 3), (196, 160, 110), 0.8, shadow=False)  # tea towel


EXTRAS = {
    ("halcyon_40", "DeckBase"): _halcyon_deck,
    ("halcyon_40", "Coachroof"): _halcyon_roof,
    ("halcyon_40", "CabinDetails"): _halcyon_details,
    ("petrel_36", "DeckBase"): _petrel_deck,
    ("petrel_36", "CabinDetails"): _petrel_details,
    ("arctic_wanderer_26", "DeckBase"): _wanderer_deck,
    ("arctic_wanderer_26", "Coachroof"): _wanderer_roof,
    ("arctic_wanderer_26", "CabinDetails"): _wanderer_details,
}


if __name__ == "__main__":
    vessel = sys.argv[1]
    areas = sys.argv[2:] or ["deck", "cabin"]
    for area in areas:
        illustrate(vessel, area)
