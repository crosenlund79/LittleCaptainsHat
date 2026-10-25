"""Shared toolkit for the illustrated vessel art (Visual Identity V01, 0.100b).

The painter scripts (tools/vessels/paint_illustrated_*.py) build full-canvas
PNG layers with it: shapes read from the boats' own scenes, slightly uneven
ink lines, colour washes with soft variation, hatching, soft shadows, and the
marine teak decking (long narrow strips with dark caulking seams, margin
boards along the edges, a king plank on the foredeck, strips that follow the
deck's curve near the edge and run fore and aft inside).

Requirements: Python 3 with Pillow, numpy and shapely.
"""
import math
import os
import re

import numpy as np
from PIL import Image, ImageDraw, ImageFilter

ROOT = os.path.join(os.path.dirname(__file__), "..", "..")
SS = 4            # supersampling: px per unit while painting
FINAL = 2         # px per unit in the PNGs

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
    """One full-canvas art layer. `canvas` is the VesselVisual canvas
    (x, y, width, height) in scene units."""

    def __init__(self, seed, canvas):
        self.canvas = canvas
        self.img = Image.new("RGBA", (canvas[2] * SS, canvas[3] * SS), (0, 0, 0, 0))
        self.rng = np.random.default_rng(seed)

    def px(self, p):
        return ((p[0] - self.canvas[0]) * SS, (p[1] - self.canvas[1]) * SS)

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
        out = self.img.resize((self.canvas[2] * FINAL, self.canvas[3] * FINAL), Image.LANCZOS)
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




# =============================================================== marine teak
from shapely.geometry import LineString, MultiLineString, Polygon, box  # noqa: E402

TEAK_DECK = (158, 116, 72)
CAULK = (44, 34, 28)
HOLLY = (226, 212, 180)


def _lines_of(geom):
    """Every line (list of points) in a shapely geometry's boundary or lines."""
    if geom.is_empty:
        return []
    if geom.geom_type in ("Polygon", "MultiPolygon", "GeometryCollection"):
        parts = getattr(geom, "geoms", [geom])
        out = []
        for g in parts:
            if g.geom_type == "Polygon":
                out.append(list(g.exterior.coords))
                out.extend(list(r.coords) for r in g.interiors)
            else:
                out.extend(_lines_of(g))
        return out
    if geom.geom_type == "LineString":
        return [list(geom.coords)]
    if geom.geom_type == "MultiLineString":
        return [list(g.coords) for g in geom.geoms]
    return []


def _polys_of(geom):
    if geom.is_empty:
        return []
    if geom.geom_type == "Polygon":
        return [geom]
    return [g for g in getattr(geom, "geoms", []) if g.geom_type == "Polygon"]


def _draw_poly(draw, layer, poly, fill):
    draw.polygon([layer.px(p) for p in poly.exterior.coords], fill=fill)
    for ring in poly.interiors:
        draw.polygon([layer.px(p) for p in ring.coords], fill=(0, 0, 0, 0))


def _geom_mask(layer, geom):
    m = Image.new("L", layer.img.size, 0)
    d = ImageDraw.Draw(m)
    for poly in _polys_of(geom):
        d.polygon([layer.px(p) for p in poly.exterior.coords], fill=255)
        for ring in poly.interiors:
            d.polygon([layer.px(p) for p in ring.coords], fill=0)
    return m


def teak_deck(layer, area, holes=(), strip=4.2, margin=8.0, sprung=3, king_plank=None, color=TEAK_DECK, outline=True):
    """Marine teak on `area` (a polygon) minus `holes` (coachroof, cockpit,
    hatches): a margin board along every edge, `sprung` strips that follow the
    edge's curve, then straight fore-and-aft strips (seams of constant y)
    nibbed into them, and an optional king plank along the centre line between
    x = king_plank[0] and king_plank[1]. Dark caulking in every seam."""
    whole = Polygon(area).buffer(0)
    for h in holes:
        whole = whole.difference(Polygon(h).buffer(0))
    if whole.is_empty:
        return
    rng = layer.rng
    tiles = Image.new("RGBA", layer.img.size, (0, 0, 0, 0))
    d = ImageDraw.Draw(tiles)

    def tone(base, spread=0.07):
        k = 1.0 + rng.uniform(-spread, spread)
        return tuple(int(min(255, c * k)) for c in base) + (255,)

    # Margin boards: slightly lighter, wider, along every edge.
    inner = whole.buffer(-margin, join_style=2)
    for poly in _polys_of(whole.difference(inner)):
        _draw_poly(d, layer, poly, tone(tuple(min(255, int(c * 1.08)) for c in color), 0.03))
    # Sprung strips following the edge.
    rings = []
    current = inner
    for i in range(sprung):
        nxt = current.buffer(-strip, join_style=1)
        for poly in _polys_of(current.difference(nxt)):
            _draw_poly(d, layer, poly, tone(color))
        rings.append(current)
        current = nxt
    interior = current
    king = None
    if king_plank and not interior.is_empty:
        king = box(king_plank[0], -strip * 1.5, king_plank[1], strip * 1.5).intersection(inner)
    field = interior.difference(king) if king is not None else interior
    # Straight fore-and-aft strips inside.
    if not field.is_empty:
        minx, miny, maxx, maxy = field.bounds
        y = math.floor(miny / strip) * strip
        while y < maxy:
            band = box(minx - 1, y, maxx + 1, y + strip).intersection(field)
            for poly in _polys_of(band):
                _draw_poly(d, layer, poly, tone(color))
            y += strip
    if king is not None:
        for poly in _polys_of(king):
            _draw_poly(d, layer, poly, tone(tuple(min(255, int(c * 1.16)) for c in color), 0.02))
    layer.img.alpha_composite(tiles)
    # Soft variation along the grain over the whole teak.
    grain = Image.new("RGBA", layer.img.size, (0, 0, 0, 0))
    gd = ImageDraw.Draw(grain)
    minx, miny, maxx, maxy = whole.bounds
    y = miny
    while y < maxy:
        x = minx + rng.uniform(0, 40)
        while x < maxx:
            length = rng.uniform(20, 70)
            yy = y + rng.uniform(0.6, strip - 0.6)
            gd.line([layer.px((x, yy)), layer.px((x + length, yy + rng.uniform(-0.5, 0.5)))],
                    fill=(90, 62, 38, 45), width=max(1, int(0.4 * SS)))
            x += length + rng.uniform(10, 50)
        y += strip
    clipped = Image.new("RGBA", layer.img.size, (0, 0, 0, 0))
    clipped.paste(grain, (0, 0), _geom_mask(layer, whole))
    layer.img.alpha_composite(clipped)
    # Caulking: every seam a thin dark line.
    seams = []
    seams += _lines_of(inner)
    seams += [ln for r in rings[1:] for ln in _lines_of(r)]
    seams += _lines_of(interior)
    if not field.is_empty:
        minx, miny, maxx, maxy = field.bounds
        y = math.floor(miny / strip) * strip
        cuts = []
        while y < maxy:
            cuts.append(LineString([(minx - 2, y), (maxx + 2, y)]))
            y += strip
        seams += _lines_of(MultiLineString(cuts).intersection(field))
    if king is not None:
        seams += _lines_of(king)
    cd = ImageDraw.Draw(layer.img, "RGBA")
    for ln in seams:
        if len(ln) >= 2:
            cd.line([layer.px(p) for p in ln], fill=CAULK + (210,), width=max(1, int(0.7 * SS)), joint="curve")
    if outline:
        for ln in _lines_of(whole):
            layer.ink([tuple(p) for p in ln[:-1]], 1.5)


def teak_sole(layer, area, strip=5.0, holly=True, color=TEAK_DECK):
    """A cockpit sole: narrow fore-and-aft teak strips with pale holly lines
    between them (teak-and-holly), inside a margin."""
    whole = Polygon(area).buffer(0)
    inner = whole.buffer(-6.0, join_style=2)
    tiles = Image.new("RGBA", layer.img.size, (0, 0, 0, 0))
    d = ImageDraw.Draw(tiles)
    for poly in _polys_of(whole.difference(inner)):
        _draw_poly(d, layer, poly, tuple(int(c * 1.05) for c in color) + (255,))
    minx, miny, maxx, maxy = inner.bounds
    y = miny
    while y < maxy:
        k = 1.0 + layer.rng.uniform(-0.06, 0.06)
        for poly in _polys_of(box(minx, y, maxx, y + strip).intersection(inner)):
            _draw_poly(d, layer, poly, tuple(int(min(255, c * k)) for c in color) + (255,))
        y += strip
    layer.img.alpha_composite(tiles)
    cd = ImageDraw.Draw(layer.img, "RGBA")
    y = miny + strip
    while y < maxy - 0.5:
        seg = LineString([(minx, y), (maxx, y)]).intersection(inner)
        for ln in _lines_of(seg):
            cd.line([layer.px(p) for p in ln], fill=(HOLLY if holly else CAULK) + (200,), width=max(1, int(0.8 * SS)))
        y += strip
    for ln in _lines_of(inner):
        cd.line([layer.px(p) for p in ln], fill=CAULK + (200,), width=max(1, int(0.7 * SS)))
    layer.ink(list(whole.exterior.coords)[:-1], 1.6)
