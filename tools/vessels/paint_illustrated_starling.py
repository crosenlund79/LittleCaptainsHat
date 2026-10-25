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
import math
import os
import re

import numpy as np
from PIL import Image, ImageDraw, ImageFilter

ROOT = os.path.join(os.path.dirname(__file__), "..", "..")
OUT = os.path.join(ROOT, "assets", "vessels", "starling_33", "illustrated")
SS = 4            # supersampling: px per unit while painting
FINAL = 2         # px per unit in the PNGs
CANVAS = (-560, -200, 1120, 400)

INK = (52, 44, 38)
CREAM = (239, 229, 204)
HULL = (233, 222, 196)
SAND = (212, 204, 180)
TEAK = (138, 106, 74)
TEAK_LIGHT = (166, 130, 92)
TEAK_DARK = (104, 78, 54)
HONEY = (154, 122, 87)
SEAGLASS = (63, 120, 128)
NAVY = (34, 52, 74)
RED = (176, 84, 62)
OCHRE = (204, 160, 82)
SAGE = (134, 158, 128)
ROPE = (214, 196, 156)
BLANKET = (126, 150, 166)
CUSHION = (72, 128, 136)
WHITE = (246, 241, 230)


def parse(path):
    """Polygons, points, positions and sizes of the nodes in a .tscn."""
    nodes, cur = {}, None
    for line in open(path):
        m = re.match(r'\[node name="([^"]+)"(?:.*parent="([^"]*)")?', line)
        if m:
            parent = m.group(2) or ""
            cur = (parent + "/" if parent not in ("", ".") else "") + m.group(1)
            nodes[cur] = {}
            continue
        if cur is None:
            continue
        m = re.match(r"(polygon|points) = PackedVector2Array\(([^)]*)\)", line)
        if m:
            v = [float(x) for x in m.group(2).split(",") if x.strip()]
            nodes[cur][m.group(1)] = list(zip(v[::2], v[1::2]))
        m = re.match(r"(position|size) = Vector2\(([-\d.]+), ([-\d.]+)\)", line)
        if m:
            nodes[cur][m.group(1)] = (float(m.group(2)), float(m.group(3)))
    return nodes


def shape(nodes, name):
    """A node's polygon in boat coordinates (rect from size, offset by position)."""
    n = nodes[name]
    pos = n.get("position", (0.0, 0.0))
    if "polygon" in n:
        return [(x + pos[0], y + pos[1]) for x, y in n["polygon"]]
    w, h = n["size"]
    x, y = pos
    return [(x - w / 2, y - h / 2), (x + w / 2, y - h / 2), (x + w / 2, y + h / 2), (x - w / 2, y + h / 2)]


class Layer:
    def __init__(self, seed):
        self.img = Image.new("RGBA", (CANVAS[2] * SS, CANVAS[3] * SS), (0, 0, 0, 0))
        self.rng = np.random.default_rng(seed)

    def px(self, p):
        return ((p[0] - CANVAS[0]) * SS, (p[1] - CANVAS[1]) * SS)

    # --- hand-drawn geometry -------------------------------------------------
    def wobble(self, pts, amp=1.0, closed=True, step=5.0):
        """Densifies a path and displaces it smoothly: a steady but human line."""
        pts = list(pts) + ([pts[0]] if closed else [])
        out = []
        phase = self.rng.uniform(0, 100, 3)
        travelled = 0.0
        for (x0, y0), (x1, y1) in zip(pts, pts[1:]):
            seg = math.hypot(x1 - x0, y1 - y0)
            n = max(1, int(seg / step))
            nx, ny = (-(y1 - y0) / seg, (x1 - x0) / seg) if seg > 0 else (0, 0)
            for i in range(n):
                t = i / n
                d = travelled + seg * t
                off = amp * (0.6 * math.sin(d / 23.0 + phase[0]) + 0.3 * math.sin(d / 9.0 + phase[1])
                             + 0.1 * math.sin(d / 3.7 + phase[2]))
                out.append((x0 + (x1 - x0) * t + nx * off, y0 + (y1 - y0) * t + ny * off))
            travelled += seg
        if not closed:
            out.append(pts[-1])
        return out

    def mask(self, pts):
        m = Image.new("L", self.img.size, 0)
        ImageDraw.Draw(m).polygon([self.px(p) for p in pts], fill=255)
        return m

    def fill(self, pts, color, variation=0.07, grain=60.0, alpha=255, mask=None):
        """A colour wash with soft blotchy variation, clipped to the shape."""
        m = mask if mask is not None else self.mask(pts)
        w, h = self.img.size
        small = self.rng.uniform(-1, 1, (max(2, int(h / (grain * SS)) + 2), max(2, int(w / (grain * SS)) + 2)))
        noise = np.asarray(Image.fromarray(((small + 1) * 127.5).astype(np.uint8)).resize((w, h), Image.BICUBIC),
                           dtype=np.float32) / 127.5 - 1.0
        fine = self.rng.uniform(-1, 1, (h // 8 + 1, w // 8 + 1))
        fine = np.asarray(Image.fromarray(((fine + 1) * 127.5).astype(np.uint8)).resize((w, h), Image.BILINEAR),
                          dtype=np.float32) / 127.5 - 1.0
        k = 1.0 + variation * noise + variation * 0.35 * fine
        rgb = np.clip(np.stack([np.full((h, w), c, np.float32) * k for c in color], -1), 0, 255).astype(np.uint8)
        a = (np.asarray(m, dtype=np.float32) * (alpha / 255.0)).astype(np.uint8)
        layer = Image.fromarray(np.dstack([rgb, a]), "RGBA")
        self.img.alpha_composite(layer)

    def ink(self, pts, width=1.5, color=INK, closed=True, amp=0.9, alpha=235):
        path = self.wobble(pts, amp, closed)
        d = ImageDraw.Draw(self.img, "RGBA")
        d.line([self.px(p) for p in path], fill=color + (alpha,), width=max(1, int(width * SS)), joint="curve")
        # A second, lighter pass slightly off: the doubled line of a quick pen.
        path2 = self.wobble(pts, amp * 0.8, closed)
        d.line([self.px((x + 0.4, y + 0.3)) for x, y in path2], fill=color + (alpha // 3,), width=max(1, int(width * 0.6 * SS)),
               joint="curve")

    def line(self, a, b, width=1.0, color=INK, alpha=200, amp=0.5):
        self.ink([a, b], width, color, closed=False, amp=amp, alpha=alpha)

    def hatch(self, pts, spacing=5.0, width=0.6, alpha=60, angle=45.0, color=INK):
        """Light diagonal hatching inside a shape (shade)."""
        layer = Image.new("RGBA", self.img.size, (0, 0, 0, 0))
        d = ImageDraw.Draw(layer)
        xs = [p[0] for p in pts]
        ys = [p[1] for p in pts]
        x0, x1, y0, y1 = min(xs), max(xs), min(ys), max(ys)
        span = (x1 - x0) + (y1 - y0)
        c = math.cos(math.radians(angle))
        s = math.sin(math.radians(angle))
        k = -span
        while k < span:
            a = (x0 + k, y0)
            b = (x0 + k + c * span * 2, y0 + s * span * 2)
            jitter = self.rng.uniform(-0.6, 0.6)
            d.line([self.px((a[0] + jitter, a[1])), self.px((b[0] + jitter, b[1]))], fill=color + (alpha,), width=max(1, int(width * SS)))
            k += spacing
        clipped = Image.new("RGBA", self.img.size, (0, 0, 0, 0))
        clipped.paste(layer, (0, 0), self.mask(pts))
        self.img.alpha_composite(clipped)

    def planks(self, pts, width, color, seam=TEAK_DARK, horizontal=True, variation=0.09, grain=True):
        """Planking: boards of slightly different tone, seams and wavy grain."""
        m = self.mask(pts)
        xs = [p[0] for p in pts]
        ys = [p[1] for p in pts]
        lo, hi = (min(ys), max(ys)) if horizontal else (min(xs), max(xs))
        a0, a1 = (min(xs), max(xs)) if horizontal else (min(ys), max(ys))
        v = lo
        while v < hi:
            tone = 1.0 + self.rng.uniform(-variation, variation)
            c = tuple(int(min(255, ch * tone)) for ch in color)
            band = ([(a0, v), (a1, v), (a1, v + width), (a0, v + width)] if horizontal
                    else [(v, a0), (v + width, a0), (v + width, a1), (v, a1)])
            bm = Image.fromarray(np.minimum(np.asarray(self.mask(band)), np.asarray(m)))
            self.fill(band, c, variation=0.05, grain=30.0, mask=bm)
            if grain:
                for _ in range(2):
                    off = self.rng.uniform(0.2, 0.8) * width
                    ph = self.rng.uniform(0, 10)
                    path = []
                    t = a0
                    while t <= a1:
                        w_ = math.sin(t / 17.0 + ph) * width * 0.12
                        path.append((t, v + off + w_) if horizontal else (v + off + w_, t))
                        t += 4
                    layer = Image.new("RGBA", self.img.size, (0, 0, 0, 0))
                    ImageDraw.Draw(layer).line([self.px(p) for p in path], fill=seam + (55,), width=max(1, int(0.45 * SS)))
                    clipped = Image.new("RGBA", self.img.size, (0, 0, 0, 0))
                    clipped.paste(layer, (0, 0), bm)
                    self.img.alpha_composite(clipped)
            seam_line = [(a0, v), (a1, v)] if horizontal else [(v, a0), (v, a1)]
            layer = Image.new("RGBA", self.img.size, (0, 0, 0, 0))
            ImageDraw.Draw(layer).line([self.px(p) for p in seam_line], fill=seam + (150,), width=max(1, int(0.7 * SS)))
            clipped = Image.new("RGBA", self.img.size, (0, 0, 0, 0))
            clipped.paste(layer, (0, 0), m)
            self.img.alpha_composite(clipped)
            v += width

    def shadow(self, pts, offset=(6, 8), blur=5.0, alpha=70):
        """A soft drop shadow down and to the right (light from the upper left)."""
        m = Image.new("L", self.img.size, 0)
        ImageDraw.Draw(m).polygon([self.px((x + offset[0], y + offset[1])) for x, y in pts], fill=alpha)
        m = m.filter(ImageFilter.GaussianBlur(blur * SS))
        layer = Image.new("RGBA", self.img.size, (20, 14, 10, 0))
        layer.putalpha(m)
        self.img.alpha_composite(layer)

    def piece(self, pts, color, ink=1.4, shade=True, variation=0.07, shadow=True, hatch=False):
        """A drawn object: shadow, wash, optional hatching, ink outline."""
        if shadow:
            self.shadow(pts, (4, 5), 3.0, 60)
        self.fill(pts, color, variation)
        if hatch:
            self.hatch(pts, alpha=40)
        if shade:
            xs = [p[0] for p in pts]
            ys = [p[1] for p in pts]
            cx, cy = (min(xs) + max(xs)) / 2, (min(ys) + max(ys)) / 2
            inner = [(cx + (x - cx) * 0.92 + 1.5, cy + (y - cy) * 0.9 + 1.5) for x, y in pts]
            self.fill(inner, tuple(int(c * 0.93) for c in color), 0.03, alpha=70)
        self.ink(pts, ink)

    def circle(self, c, r, color, ink=1.2, n=28, shadow=True):
        pts = [(c[0] + r * math.cos(2 * math.pi * i / n), c[1] + r * math.sin(2 * math.pi * i / n)) for i in range(n)]
        self.piece(pts, color, ink, shade=False, shadow=shadow)
        return pts

    def coil(self, c, r, turns=3.2, color=ROPE):
        """A coiled rope seen from above."""
        pts = []
        steps = int(turns * 30)
        for i in range(steps):
            t = i / 30 * 2 * math.pi
            rr = r * (0.35 + 0.65 * i / steps)
            pts.append((c[0] + rr * math.cos(t), c[1] + rr * math.sin(t)))
        self.shadow([(c[0] + r * math.cos(a), c[1] + r * math.sin(a)) for a in np.linspace(0, 2 * math.pi, 20)], (2, 3), 2, 50)
        d = ImageDraw.Draw(self.img, "RGBA")
        d.line([self.px(p) for p in pts], fill=INK + (220,), width=int(2.6 * SS), joint="curve")
        d.line([self.px(p) for p in pts], fill=color + (255,), width=int(1.7 * SS), joint="curve")

    def rect(self, x, y, w, h):
        return [(x, y), (x + w, y), (x + w, y + h), (x, y + h)]

    def rounded(self, x, y, w, h, r):
        pts = []
        for cx, cy, a0 in ((x + w - r, y + r, -90), (x + w - r, y + h - r, 0), (x + r, y + h - r, 90), (x + r, y + r, 180)):
            for i in range(7):
                a = math.radians(a0 + i * 15)
                pts.append((cx + r * math.cos(a), cy + r * math.sin(a)))
        return pts

    def save(self, path):
        os.makedirs(os.path.dirname(path), exist_ok=True)
        out = self.img.resize((CANVAS[2] * FINAL, CANVAS[3] * FINAL), Image.LANCZOS)
        out.save(path, optimize=True)
        print("wrote", os.path.relpath(path, ROOT), out.size)


def inset(pts, d):
    """Pushes a convex-ish outline inwards by about d units (towards its centre line)."""
    xs = [p[0] for p in pts]
    cx = (min(xs) + max(xs)) / 2
    out = []
    for x, y in pts:
        sy = -1 if y < 0 else 1
        nx = x - d * 0.4 * (1 if x > cx else -1)
        out.append((nx, y - sy * d if abs(y) > d else y * 0.5))
    return out


# =============================================================== deck
def paint_deck():
    v = parse(os.path.join(ROOT, "src/vessels/starling_33/deck_visual.tscn"))
    hull = shape(v, "HullBase/Hull")
    deck = shape(v, "DeckBase/DeckSurface")
    toe = v["HullBase/ToeRail"]["points"]

    # Hull: the cream topsides seen from above (a rim around the deck) and a
    # teak toe rail along the sheer.
    L = Layer(1)
    L.fill(hull, HULL, 0.05)
    L.hatch([(x, y) for x, y in hull if y > 0] + [(-500, 0)], spacing=4.0, alpha=30)   # shade on the starboard side
    L.ink(toe, 3.0, TEAK, closed=False, amp=0.4, alpha=255)
    L.ink(toe, 0.7, TEAK_DARK, closed=False, amp=0.4, alpha=160)
    L.ink(hull, 2.2)
    L.save(os.path.join(OUT, "deck", "hull_base.png"))

    # Deck: sand non-skid, teak side decks, cockpit and benches, the hatch.
    D = Layer(2)
    D.fill(deck, SAND, 0.06, grain=45)
    D.hatch(deck, spacing=3.2, width=0.35, alpha=18, angle=60)  # non-skid texture
    side = [(x, y) for x, y in deck]
    D.ink(side, 1.6)
    # Teak planked side decks along both sides (inside the deck edge).
    for sy in (-1, 1):
        strip = []
        for x, y in deck:
            if y * sy > 0 and -470 < x < 440:
                strip.append((x, y))
        strip.sort()
        inner = [(x, y - sy * 26) for x, y in reversed(strip)]
        D.planks(strip + inner, 6.5, TEAK_LIGHT, horizontal=True)
        D.ink(strip + inner, 1.0, alpha=150)
    cockpit = shape(v, "DeckBase/CockpitWell")
    D.shadow(cockpit, (3, 4), 3, 80)
    D.fill(cockpit, (120, 98, 72), 0.06)
    grating = shape(v, "DeckBase/CockpitGrating")
    D.planks(grating, 9.0, TEAK, horizontal=False)
    for x in range(-460, -300, 18):
        D.line((x, -66), (x, 66), 0.6, TEAK_DARK, 120)
    D.ink(cockpit, 1.8)
    for name in ("DeckBase/BenchPort", "DeckBase/BenchStarboard"):
        bench = shape(v, name)
        D.planks(bench, 6.5, TEAK_LIGHT, horizontal=False)
        D.ink(bench, 1.3)
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
    C = Layer(3)
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
    T = Layer(4)
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

    B = Layer(11)
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

    F = Layer(12)
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
    X = Layer(13)
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
    paint_deck()
    paint_cabin()
