"""Paints the fish, sharks and junk of Iteration 18 in the game's illustrated style.

The look follows the ship's cat and dog (tools/companions/paint_companions.py):
warm ink lines just inside each shape, soft colour washes lit from above, a
little paper grain and a soft shadow. Fish are seen from the side, head to the
left, so they read at the small sizes the game shows them at.

Every species is drawn from its own description below (body outline, fins,
tail, colours, markings, eye), so each is recognizable by its real features:
the mackerel's wavy back stripes, the cod's barbel and speckles, the garfish's
beak, the perch's bars, the bream's golden brow, the tunas' finlets, the
sharks' gill slits and long tail lobe, and so on.

For the small animations the game plays (a blink, a tail flick), each fish is
written as layers on one canvas (W x H), so they stack exactly:
    body.png   the fish without its tail, eye open
    tail.png   the tail alone (drawn behind the body; it turns about the
               pivot written to data/fishing/fish_art.json)
    lid.png    the closed eye: shown for a moment to blink
    thumb.png  the whole fish, small and static (lists, trophies)
Junk has only art.png and thumb.png (it does not blink).

Writes assets/fishing/<id>/... and data/fishing/fish_art.json. Original work
for this project (no source images); same licence as the game's own art.

Usage: python3 tools/fishing/paint_fish.py [species_id ...]
Requirements: Python 3 with Pillow and numpy.
"""
import json
import math
import os
import sys

import numpy as np
from PIL import Image, ImageChops, ImageDraw, ImageFilter

ROOT = os.path.join(os.path.dirname(__file__), "..", "..")
OUT = os.path.join(ROOT, "assets", "fishing")
META = os.path.join(ROOT, "data", "fishing", "fish_art.json")
W, H = 512, 256      # final canvas, px
SS = 3               # supersampling while painting
THUMB = (128, 64)
INK = (52, 44, 38)
SHADOW = (20, 30, 34)
CY = 122             # the fish's middle line


# --- Masks ---------------------------------------------------------------------------

def blank():
    return Image.new("L", (W * SS, H * SS), 0)


def _p(points):
    return [(x * SS, y * SS) for x, y in points]


def poly(points):
    m = blank()
    if len(points) >= 3:
        ImageDraw.Draw(m).polygon(_p(points), fill=255)
    return m


def ell(c, r, angle=0.0, steps=72):
    a = math.radians(angle)
    pts = []
    for i in range(steps):
        t = 2 * math.pi * i / steps
        x, y = r[0] * math.cos(t), r[1] * math.sin(t)
        pts.append((c[0] + x * math.cos(a) - y * math.sin(a), c[1] + x * math.sin(a) + y * math.cos(a)))
    return poly(pts)


def smooth(points, steps=24):
    """A smooth curve through control points (quadratic B-spline style)."""
    if len(points) < 3:
        return list(points)
    out = []
    for i in range(len(points) - 2):
        p0 = ((points[i][0] + points[i + 1][0]) / 2, (points[i][1] + points[i + 1][1]) / 2) if i else points[0]
        p1 = points[i + 1]
        p2 = ((points[i + 1][0] + points[i + 2][0]) / 2, (points[i + 1][1] + points[i + 2][1]) / 2) if i < len(points) - 3 else points[-1]
        for k in range(steps):
            t = k / steps
            out.append(((1 - t) ** 2 * p0[0] + 2 * (1 - t) * t * p1[0] + t * t * p2[0],
                        (1 - t) ** 2 * p0[1] + 2 * (1 - t) * t * p1[1] + t * t * p2[1]))
    out.append(points[-1])
    return out


def tube(points, w0, w1=None):
    w1 = w0 if w1 is None else w1
    curve = smooth(points) if len(points) > 2 else points
    if len(curve) == 2:
        (x0, y0), (x1, y1) = curve
        n = max(int(math.hypot(x1 - x0, y1 - y0) / 1.5), 2)
        curve = [(x0 + (x1 - x0) * k / n, y0 + (y1 - y0) * k / n) for k in range(n + 1)]
    m = blank()
    d = ImageDraw.Draw(m)
    for i, (x, y) in enumerate(curve):
        w = (w0 + (w1 - w0) * i / max(len(curve) - 1, 1)) / 2
        d.ellipse([(x - w) * SS, (y - w) * SS, (x + w) * SS, (y + w) * SS], fill=255)
    return m


def union(*masks):
    out = blank()
    for m in masks:
        out = ImageChops.lighter(out, m)
    return out


def minus(a, b):
    return ImageChops.subtract(a, b)


def clip(a, b):
    return ImageChops.multiply(a, b)


def mix(a, b, t):
    return tuple(int(a[i] + (b[i] - a[i]) * t) for i in range(3))


# --- The painter -------------------------------------------------------------------------

class Painter:
    def __init__(self, seed=7):
        self.img = Image.new("RGBA", (W * SS, H * SS), (0, 0, 0, 0))
        self.silhouette = blank()
        rng = np.random.default_rng(seed)
        noise = rng.normal(0.0, 1.0, (H // 4, W // 4)).astype(np.float32)
        self.grain = np.array(Image.fromarray(((noise * 18) + 128).clip(0, 255).astype(np.uint8)).resize((W * SS, H * SS), Image.BICUBIC),
                              dtype=np.float32) / 128.0 - 1.0
        self.yy = np.mgrid[0:H * SS, 0:W * SS][0].astype(np.float32)

    def wash(self, mask, top, bottom=None, y0=None, y1=None, outline=True, ink_w=2.0, alpha=1.0, sheen=0.10):
        """A colour wash in `mask`, from `top` to `bottom` down the shape (lit
        from above), with grain and an ink line just inside the edge."""
        box = mask.getbbox()
        if not box:
            return
        bottom = top if bottom is None else bottom
        y0 = box[1] if y0 is None else y0 * SS
        y1 = box[3] if y1 is None else y1 * SS
        t = ((self.yy - y0) / max(y1 - y0, 1)).clip(0, 1)
        a = np.array(top, dtype=np.float32)
        b = np.array(bottom, dtype=np.float32)
        rgb = a[None, None, :] + (b - a)[None, None, :] * t[:, :, None]
        light = 1.0 + sheen * (1.0 - t) - 0.06 * t + self.grain * 0.045
        rgb = (rgb * light[:, :, None]).clip(0, 255).astype(np.uint8)
        layer = Image.fromarray(np.dstack([rgb, (np.array(mask, dtype=np.float32) * alpha).astype(np.uint8)]), "RGBA")
        self.img.alpha_composite(layer)
        self.silhouette = union(self.silhouette, mask)
        if outline:
            self.outline(mask, ink_w)

    def outline(self, mask, width=2.0, colour=INK, alpha=235):
        k = max(3, int(width * SS) | 1)
        inner = mask.filter(ImageFilter.MinFilter(k))
        ring = minus(mask, inner).filter(ImageFilter.GaussianBlur(SS * 0.35))
        self.ink(ring, colour, alpha)

    def ink(self, mask, colour=INK, alpha=235):
        a = (np.array(mask, dtype=np.float32) * alpha / 255.0).astype(np.uint8)
        layer = Image.new("RGBA", self.img.size, tuple(colour) + (0,))
        layer.putalpha(Image.fromarray(a))
        self.img.alpha_composite(layer)

    def line(self, points, width, colour=INK, alpha=235):
        self.ink(tube(points, width), colour, alpha)

    def dot(self, c, r, colour, alpha=255):
        self.ink(ell(c, (r, r)), colour, alpha)

    def colour_at(self, x, y, r=3):
        """The painted colour around a point (for the eyelid)."""
        box = (int((x - r) * SS), int((y - r) * SS), int((x + r) * SS), int((y + r) * SS))
        arr = np.array(self.img.crop(box), dtype=np.float32)
        w = arr[:, :, 3:4] / 255.0
        return tuple(int(v) for v in (arr[:, :, :3] * w).sum((0, 1)) / max(w.sum(), 1e-6))

    def image(self, shadow=True):
        out = self.img
        if shadow:
            sh_mask = self.silhouette.filter(ImageFilter.GaussianBlur(SS * 4))
            sh_mask = ImageChops.offset(sh_mask, 3 * SS, 6 * SS)
            sh = Image.new("RGBA", self.img.size, SHADOW + (0,))
            sh.putalpha(sh_mask.point(lambda v: int(v * 0.28)))
            out = Image.alpha_composite(sh, self.img)
        return out.resize((W, H), Image.LANCZOS)


# --- The fish's shape --------------------------------------------------------------------

class Shape:
    """A fish body between the snout (x0) and the tail's root (x1): smooth top
    and bottom outlines from control points (t along the body, y from CY)."""

    def __init__(self, spec):
        self.x0, self.x1 = spec["x0"], spec["x1"]
        self.top = smooth([(self.x(t), CY + y) for t, y in spec["top"]], 30)
        self.bot = smooth([(self.x(t), CY + y) for t, y in spec["bot"]], 30)

    def x(self, t):
        return self.x0 + (self.x1 - self.x0) * t

    @staticmethod
    def _at(curve, x):
        for (ax, ay), (bx, by) in zip(curve, curve[1:]):
            if ax <= x <= bx or bx <= x <= ax:
                return ay + (by - ay) * ((x - ax) / (bx - ax) if bx != ax else 0)
        return curve[-1][1] if x > curve[-1][0] else curve[0][1]

    def top_at(self, t):
        return self._at(self.top, self.x(t))

    def bot_at(self, t):
        return self._at(self.bot, self.x(t))

    def mid_at(self, t):
        return (self.top_at(t) + self.bot_at(t)) / 2

    def mask(self):
        return poly(self.top + list(reversed(self.bot)))

    def root(self):
        """The tail's root (pivot) and half its height."""
        return (self.x1, (self.top[-1][1] + self.bot[-1][1]) / 2), abs(self.bot[-1][1] - self.top[-1][1]) / 2


def fin_on(shape, edge, t0, t1, height, kind="soft", sweep=0.35, rays=0):
    """A fin along the top or bottom edge between t0 and t1 (height in px,
    outward; sweep leans it toward the tail). Kinds: soft (rounded), spiny
    (a row of points), tri (triangular), long (a low ribbon)."""
    sign = -1 if edge == "top" else 1
    at = shape.top_at if edge == "top" else shape.bot_at
    base = [(shape.x(t0 + (t1 - t0) * k / 12), at(t0 + (t1 - t0) * k / 12)) for k in range(13)]
    length = shape.x(t1) - shape.x(t0)
    out = []
    if kind == "spiny":
        n = max(rays, 5)
        for k in range(n + 1):
            f = k / n
            x = shape.x(t0 + (t1 - t0) * f)
            hgt = height * (0.55 + 0.45 * math.sin(math.pi * min(f * 1.4, 1.0) / 1.0 * 0.9 + 0.2))
            out.append((x + length * sweep * 0.25, at(t0 + (t1 - t0) * f) + sign * hgt))
            if k < n:
                xm = shape.x(t0 + (t1 - t0) * (f + 0.5 / n))
                out.append((xm + length * sweep * 0.2, at(t0 + (t1 - t0) * (f + 0.5 / n)) + sign * hgt * 0.62))
    elif kind == "tri":
        out = [(shape.x(t0) + length * (0.35 + sweep), at(t0) + sign * height), (shape.x(t1) + length * sweep * 0.5, at(t1) + sign * height * 0.18)]
    elif kind == "long":
        for k in range(13):
            f = k / 12
            out.append((shape.x(t0 + (t1 - t0) * f) + length * 0.03, at(t0 + (t1 - t0) * f) + sign * height * (0.8 + 0.2 * math.sin(f * math.pi))))
    else:  # soft, rounded
        for k in range(13):
            f = k / 12
            hgt = height * math.sin(math.pi * (0.15 + 0.85 * f)) ** 0.7
            out.append((shape.x(t0 + (t1 - t0) * f) + length * sweep * f, at(t0 + (t1 - t0) * f) + sign * hgt))
    return poly(base + list(reversed(out)))


def pectoral(shape, t, length, droop=25, width=0.42):
    """A side fin behind the gill, lying along the body."""
    x = shape.x(t)
    y = shape.mid_at(t) + (shape.bot_at(t) - shape.mid_at(t)) * 0.35
    a = math.radians(droop)
    tip = (x + length * math.cos(a), y + length * math.sin(a))
    w = length * width
    return poly(smooth([(x, y - w * 0.35), ((x + tip[0]) / 2, (y + tip[1]) / 2 - w * 0.45), tip,
                        ((x + tip[0]) / 2 - w * 0.1, (y + tip[1]) / 2 + w * 0.35), (x, y + w * 0.3)], 12))


def tail_mask(root, half, kind, length, spread):
    """The tail fin from its root. Kinds: fork, deepfork, square, round,
    notch (slightly forked), shark (long upper lobe), plaice (fan)."""
    x, y = root
    h = half
    base = [(x - 10, y - h * 1.05), (x - 10, y + h * 1.05)]
    if kind == "fork":
        pts = [(x - 10, y - h), (x + length * 0.55, y - spread * 0.75), (x + length, y - spread), (x + length * 0.82, y - spread * 0.55),
               (x + length * 0.38, y), (x + length * 0.82, y + spread * 0.55), (x + length, y + spread), (x + length * 0.55, y + spread * 0.75),
               (x - 10, y + h)]
    elif kind == "deepfork":
        pts = [(x - 10, y - h), (x + length * 0.45, y - spread * 0.7), (x + length, y - spread * 1.05), (x + length * 0.7, y - spread * 0.45),
               (x + length * 0.2, y), (x + length * 0.7, y + spread * 0.45), (x + length, y + spread * 1.05), (x + length * 0.45, y + spread * 0.7),
               (x - 10, y + h)]
    elif kind == "square":
        pts = [(x - 10, y - h), (x + length * 0.6, y - spread * 0.85), (x + length, y - spread), (x + length * 0.97, y),
               (x + length, y + spread), (x + length * 0.6, y + spread * 0.85), (x - 10, y + h)]
    elif kind == "notch":
        pts = [(x - 10, y - h), (x + length * 0.6, y - spread * 0.8), (x + length, y - spread), (x + length * 0.85, y),
               (x + length, y + spread), (x + length * 0.6, y + spread * 0.8), (x - 10, y + h)]
    elif kind == "round" or kind == "plaice":
        pts = smooth([(x - 10, y - h), (x + length * 0.5, y - spread), (x + length, y - spread * 0.55), (x + length * 1.05, y),
                      (x + length, y + spread * 0.55), (x + length * 0.5, y + spread), (x - 10, y + h)], 14)
    else:  # shark: long upper lobe, short lower one
        pts = [(x - 12, y - h), (x + length * 0.55, y - spread * 1.1), (x + length, y - spread * 1.55), (x + length * 0.82, y - spread * 0.9),
               (x + length * 0.45, y - spread * 0.05), (x + length * 0.42, y + spread * 0.55), (x + length * 0.2, y + spread * 0.25), (x - 12, y + h)]
    return poly(pts)


# --- Species -------------------------------------------------------------------------------

# Colours: back (top of the wash), belly (bottom), fins, tail, ink accents.
SPECIES = {
    "herring": dict(
        x0=70, x1=390, top=[(0, 2), (0.06, -18), (0.25, -36), (0.5, -38), (0.8, -24), (1, -11)],
        bot=[(0, 2), (0.08, 18), (0.3, 34), (0.6, 32), (0.85, 18), (1, 11)],
        back=(64, 104, 136), belly=(222, 230, 232), fin=(160, 178, 186), tail_col=(120, 148, 168),
        tail=("deepfork", 92, 52), dorsal=[("top", 0.42, 0.6, 30, "soft")], anal=[("bot", 0.72, 0.86, 14, "soft")],
        pelvic=("bot", 0.46, 0.54, 12), pectoral=(0.2, 38), eye=(0.11, -4, 13), scales=0.5,
        marks=["sheen_band"], mouth="up"),
    "mackerel": dict(
        x0=60, x1=388, top=[(0, 3), (0.06, -16), (0.25, -32), (0.5, -36), (0.8, -22), (1, -8)],
        bot=[(0, 3), (0.08, 16), (0.3, 30), (0.6, 30), (0.85, 16), (1, 8)],
        back=(40, 116, 108), belly=(232, 236, 230), fin=(150, 166, 150), tail_col=(66, 110, 100),
        tail=("deepfork", 88, 50), dorsal=[("top", 0.32, 0.46, 30, "spiny"), ("top", 0.58, 0.7, 20, "soft")],
        anal=[("bot", 0.6, 0.72, 16, "soft")], finlets=(0.73, 0.98, 5), pectoral=(0.2, 34), eye=(0.1, -3, 12),
        scales=0.0, marks=["mackerel_waves"], mouth="flat"),
    "flatfish": dict(
        x0=74, x1=372, top=[(0, 10), (0.05, -16), (0.2, -50), (0.5, -62), (0.8, -44), (1, -12)],
        bot=[(0, 12), (0.06, 26), (0.22, 54), (0.5, 64), (0.8, 46), (1, 12)],
        back=(150, 122, 86), belly=(128, 102, 70), fin=(162, 134, 96), tail_col=(150, 120, 84),
        tail=("plaice", 64, 44), dorsal=[("top", 0.1, 0.94, 18, "long")], anal=[("bot", 0.18, 0.94, 18, "long")],
        pectoral=(0.24, 0), eye=(0.13, -26, 10), second_eye=(0.2, -36, 9), scales=0.0, marks=["plaice_spots"],
        mouth="flat", fin_rays=True),
    "cod": dict(
        x0=66, x1=384, top=[(0, 6), (0.06, -22), (0.22, -44), (0.45, -46), (0.75, -30), (1, -14)],
        bot=[(0, 8), (0.08, 26), (0.3, 46), (0.6, 40), (0.85, 22), (1, 14)],
        back=(118, 112, 70), belly=(224, 214, 184), fin=(140, 128, 88), tail_col=(118, 108, 70),
        tail=("square", 78, 46), dorsal=[("top", 0.26, 0.42, 30, "soft"), ("top", 0.47, 0.64, 28, "soft"), ("top", 0.68, 0.86, 24, "soft")],
        anal=[("bot", 0.48, 0.64, 22, "soft"), ("bot", 0.68, 0.86, 20, "soft")], pectoral=(0.22, 40), eye=(0.12, -10, 12),
        scales=0.0, marks=["speckles", "lateral_pale"], mouth="down", barbel=True),
    "perch": dict(
        x0=72, x1=380, top=[(0, 6), (0.06, -22), (0.22, -52), (0.45, -58), (0.75, -34), (1, -14)],
        bot=[(0, 8), (0.08, 24), (0.3, 44), (0.6, 40), (0.85, 22), (1, 14)],
        back=(90, 116, 54), belly=(226, 214, 150), fin=(208, 108, 64), tail_col=(198, 112, 66),
        tail=("notch", 80, 46), dorsal=[("top", 0.24, 0.5, 40, "spiny", 9), ("top", 0.56, 0.74, 28, "soft")],
        anal=[("bot", 0.62, 0.76, 22, "soft")], pelvic=("bot", 0.3, 0.38, 22), pectoral=(0.22, 34),
        eye=(0.12, -10, 13), scales=0.5, marks=["perch_bars"], mouth="flat", fin_tint=(212, 92, 58), dorsal_spot=True),
    "garfish": dict(
        x0=30, x1=420, top=[(0, 4), (0.03, 1), (0.16, -6), (0.24, -15), (0.5, -18), (0.85, -14), (1, -7)],
        bot=[(0, 6), (0.03, 7), (0.16, 8), (0.24, 14), (0.5, 17), (0.85, 13), (1, 7)],
        back=(46, 112, 92), belly=(224, 232, 222), fin=(120, 150, 128), tail_col=(66, 120, 98),
        tail=("fork", 54, 32), dorsal=[("top", 0.8, 0.94, 18, "soft")], anal=[("bot", 0.78, 0.92, 16, "soft")],
        pectoral=(0.27, 22), eye=(0.205, -2, 9), scales=0.0, marks=["gar_band"], mouth="beak"),
    "gilthead_bream": dict(
        x0=74, x1=376, top=[(0, 8), (0.05, -16), (0.18, -50), (0.42, -64), (0.75, -38), (1, -12)],
        bot=[(0, 10), (0.08, 28), (0.3, 50), (0.6, 46), (0.85, 24), (1, 12)],
        back=(110, 124, 136), belly=(232, 232, 226), fin=(152, 158, 164), tail_col=(122, 132, 142),
        tail=("fork", 82, 52), dorsal=[("top", 0.24, 0.84, 30, "spiny", 11)], anal=[("bot", 0.62, 0.84, 22, "soft")],
        pectoral=(0.24, 40), eye=(0.13, -12, 12), scales=0.55, marks=["gold_brow", "gill_spot", "faint_lines"], mouth="flat"),
    "sea_trout": dict(
        x0=66, x1=386, top=[(0, 4), (0.06, -20), (0.25, -40), (0.5, -42), (0.8, -26), (1, -13)],
        bot=[(0, 6), (0.08, 20), (0.3, 38), (0.6, 36), (0.85, 20), (1, 13)],
        back=(84, 104, 116), belly=(236, 232, 222), fin=(150, 158, 160), tail_col=(110, 122, 130),
        tail=("square", 80, 48), dorsal=[("top", 0.38, 0.54, 32, "soft")], adipose=(0.8, 0.86),
        anal=[("bot", 0.66, 0.78, 20, "soft")], pelvic=("bot", 0.46, 0.54, 14), pectoral=(0.2, 34), eye=(0.11, -6, 12),
        scales=0.0, marks=["trout_spots"], mouth="flat"),
    "sea_bass": dict(
        x0=66, x1=386, top=[(0, 6), (0.06, -20), (0.25, -42), (0.5, -44), (0.8, -26), (1, -12)],
        bot=[(0, 8), (0.08, 22), (0.3, 40), (0.6, 38), (0.85, 20), (1, 12)],
        back=(96, 112, 120), belly=(236, 236, 230), fin=(140, 150, 156), tail_col=(112, 124, 132),
        tail=("notch", 80, 48), dorsal=[("top", 0.3, 0.48, 36, "spiny", 8), ("top", 0.54, 0.7, 26, "soft")],
        anal=[("bot", 0.62, 0.74, 20, "soft")], pelvic=("bot", 0.3, 0.38, 16), pectoral=(0.22, 36), eye=(0.11, -8, 12),
        scales=0.55, marks=["gill_spot", "lateral_dark"], mouth="flat"),
    "bonito": dict(
        x0=62, x1=388, top=[(0, 4), (0.06, -20), (0.25, -42), (0.5, -44), (0.8, -24), (1, -7)],
        bot=[(0, 4), (0.08, 20), (0.3, 38), (0.6, 38), (0.85, 18), (1, 7)],
        back=(46, 70, 112), belly=(230, 232, 236), fin=(90, 104, 130), tail_col=(52, 74, 112),
        tail=("deepfork", 96, 62), dorsal=[("top", 0.26, 0.5, 32, "spiny", 9), ("top", 0.58, 0.66, 20, "tri")],
        anal=[("bot", 0.6, 0.68, 18, "tri")], finlets=(0.7, 0.98, 6), pectoral=(0.22, 30), eye=(0.1, -6, 12),
        scales=0.0, marks=["bonito_stripes"], mouth="flat", keel=True),
    "mahi_mahi": dict(
        x0=70, x1=384, top=[(0, 0), (0.02, -40), (0.08, -54), (0.3, -50), (0.6, -38), (0.85, -22), (1, -10)],
        bot=[(0, 4), (0.08, 26), (0.3, 36), (0.6, 30), (0.85, 18), (1, 10)],
        back=(36, 132, 112), belly=(232, 206, 72), fin=(36, 120, 150), tail_col=(198, 176, 64),
        tail=("deepfork", 96, 60), dorsal=[("top", 0.06, 0.96, 17, "long")], anal=[("bot", 0.5, 0.95, 13, "long")],
        pectoral=(0.2, 30), eye=(0.12, -10, 11), scales=0.0, marks=["mahi_dots"], mouth="flat", fin_tint=(40, 118, 158), fin_rays=True),
    "skipjack": dict(
        x0=62, x1=388, top=[(0, 4), (0.06, -22), (0.25, -46), (0.5, -48), (0.8, -26), (1, -7)],
        bot=[(0, 4), (0.08, 22), (0.3, 42), (0.6, 42), (0.85, 20), (1, 7)],
        back=(40, 54, 96), belly=(232, 234, 238), fin=(70, 84, 118), tail_col=(48, 62, 104),
        tail=("deepfork", 98, 64), dorsal=[("top", 0.26, 0.46, 34, "spiny", 9), ("top", 0.56, 0.64, 22, "tri")],
        anal=[("bot", 0.6, 0.68, 20, "tri")], finlets=(0.7, 0.98, 6), pectoral=(0.22, 30), eye=(0.1, -6, 12),
        scales=0.0, marks=["skipjack_stripes"], mouth="flat", keel=True),
    "snapper": dict(
        x0=56, x1=382, top=[(0, 6), (0.04, -6), (0.12, -30), (0.24, -56), (0.42, -64), (0.72, -36), (1, -12)],
        bot=[(0, 10), (0.1, 18), (0.34, 38), (0.62, 36), (0.86, 20), (1, 12)],
        back=(196, 72, 72), belly=(244, 196, 180), fin=(222, 110, 98), tail_col=(206, 84, 80),
        tail=("notch", 82, 50), dorsal=[("top", 0.22, 0.5, 36, "spiny", 10), ("top", 0.54, 0.76, 28, "soft")],
        anal=[("bot", 0.62, 0.78, 24, "soft")], pelvic=("bot", 0.3, 0.38, 18), pectoral=(0.22, 38), eye=(0.12, -12, 13),
        scales=0.55, marks=[], mouth="flat", eye_red=True),
    "yellowfin": dict(
        x0=60, x1=388, top=[(0, 4), (0.06, -22), (0.25, -48), (0.5, -50), (0.8, -26), (1, -7)],
        bot=[(0, 4), (0.08, 22), (0.3, 44), (0.6, 44), (0.85, 20), (1, 7)],
        back=(34, 48, 92), belly=(226, 230, 236), fin=(228, 196, 54), tail_col=(52, 64, 104),
        tail=("deepfork", 104, 70), dorsal=[("top", 0.26, 0.44, 34, "spiny", 9), ("top", 0.52, 0.62, 70, "tri", 0, 0.9)],
        anal=[("bot", 0.54, 0.64, 66, "tri", 0, 0.9)], finlets=(0.68, 0.98, 7), pectoral=(0.2, 58), eye=(0.1, -6, 12),
        scales=0.0, marks=["yellow_band", "belly_dashes"], mouth="flat", keel=True, finlet_col=(240, 206, 60)),
    "blue_shark": dict(
        x0=24, x1=392, top=[(0, 10), (0.05, -4), (0.16, -24), (0.36, -34), (0.65, -24), (0.9, -12), (1, -8)],
        bot=[(0, 12), (0.06, 18), (0.2, 26), (0.45, 30), (0.75, 18), (0.9, 10), (1, 8)],
        back=(52, 82, 152), belly=(236, 238, 240), fin=(64, 94, 160), tail_col=(56, 86, 154),
        tail=("shark", 110, 46), dorsal=[("top", 0.38, 0.52, 42, "tri", 0, 0.2), ("top", 0.82, 0.86, 10, "tri")],
        anal=[("bot", 0.82, 0.86, 10, "tri")], pectoral=(0.22, 86, 32, 0.3), eye=(0.1, -2, 8), scales=0.0,
        marks=["gills", "countershade"], mouth="shark", shark=True),
    "blacktip_reef_shark": dict(
        x0=40, x1=390, top=[(0, 10), (0.05, -6), (0.16, -28), (0.38, -38), (0.65, -26), (0.9, -12), (1, -8)],
        bot=[(0, 12), (0.06, 20), (0.2, 30), (0.45, 32), (0.75, 20), (0.9, 10), (1, 8)],
        back=(126, 118, 104), belly=(238, 236, 230), fin=(130, 122, 108), tail_col=(126, 118, 104),
        tail=("shark", 100, 46), dorsal=[("top", 0.36, 0.52, 46, "tri", 0, 0.15), ("top", 0.8, 0.85, 12, "tri")],
        anal=[("bot", 0.8, 0.85, 12, "tri")], pectoral=(0.22, 62, 32, 0.34), eye=(0.1, -2, 8), scales=0.0,
        marks=["gills", "countershade"], mouth="shark", shark=True, black_tips=True),
    # --- I021: A Wider, Warmer World ---
    "pollack": dict(  # slimmer than the cod, with a jutting lower jaw and no barbel
        x0=58, x1=390, top=[(0, 2), (0.06, -16), (0.22, -34), (0.45, -36), (0.75, -24), (1, -11)],
        bot=[(0, 8), (0.08, 20), (0.3, 34), (0.6, 30), (0.85, 17), (1, 11)],
        back=(110, 104, 62), belly=(226, 218, 186), fin=(132, 120, 80), tail_col=(112, 104, 64),
        tail=("notch", 80, 48), dorsal=[("top", 0.26, 0.42, 30, "soft"), ("top", 0.47, 0.64, 26, "soft"), ("top", 0.68, 0.86, 22, "soft")],
        anal=[("bot", 0.46, 0.64, 22, "soft"), ("bot", 0.68, 0.86, 18, "soft")], pectoral=(0.22, 36), eye=(0.12, -8, 13),
        scales=0.0, marks=["arched_line"], mouth="up"),
    "halibut": dict(  # longer and slimmer than the flounder, with a big mouth and a concave tail
        x0=44, x1=388, top=[(0, 2), (0.04, -14), (0.16, -36), (0.42, -44), (0.75, -34), (0.92, -18), (1, -10)],
        bot=[(0, 8), (0.05, 18), (0.18, 36), (0.45, 44), (0.75, 34), (0.92, 18), (1, 10)],
        back=(92, 86, 66), belly=(80, 74, 56), fin=(104, 96, 74), tail_col=(90, 84, 64),
        tail=("notch", 76, 62), dorsal=[("top", 0.16, 0.9, 14, "long")], anal=[("bot", 0.24, 0.9, 14, "long")],
        pectoral=(0.24, 0), eye=(0.1, -14, 10), second_eye=(0.16, -22, 9), scales=0.0, marks=["mottle"],
        mouth="flat", fin_rays=True),
    "red_mullet": dict(
        x0=60, x1=388, top=[(0, 10), (0.04, -8), (0.14, -32), (0.3, -42), (0.6, -36), (0.85, -22), (1, -12)],
        bot=[(0, 12), (0.08, 20), (0.3, 30), (0.6, 28), (0.85, 18), (1, 12)],
        back=(214, 98, 92), belly=(244, 214, 200), fin=(230, 150, 120), tail_col=(214, 104, 94),
        tail=("deepfork", 80, 48), dorsal=[("top", 0.28, 0.42, 34, "spiny", 7), ("top", 0.56, 0.7, 24, "soft")],
        anal=[("bot", 0.6, 0.72, 18, "soft")], pelvic=("bot", 0.3, 0.38, 14), pectoral=(0.22, 30), eye=(0.12, -10, 12),
        scales=0.55, marks=["yellow_stripes"], mouth="down", barbel=True),
    "dentex": dict(
        x0=60, x1=384, top=[(0, 8), (0.04, -10), (0.12, -40), (0.3, -58), (0.55, -54), (0.8, -32), (1, -12)],
        bot=[(0, 12), (0.1, 26), (0.34, 46), (0.62, 40), (0.86, 22), (1, 12)],
        back=(176, 140, 150), belly=(236, 222, 222), fin=(190, 150, 160), tail_col=(176, 136, 148),
        tail=("fork", 84, 54), dorsal=[("top", 0.22, 0.82, 32, "spiny", 12)], anal=[("bot", 0.62, 0.8, 22, "soft")],
        pelvic=("bot", 0.3, 0.38, 18), pectoral=(0.22, 38), eye=(0.11, -10, 12), scales=0.5, marks=["blue_spots"], mouth="flat"),
    "bluefish": dict(
        x0=62, x1=388, top=[(0, 4), (0.06, -20), (0.25, -40), (0.5, -42), (0.8, -24), (1, -9)],
        bot=[(0, 8), (0.08, 22), (0.3, 38), (0.6, 36), (0.85, 18), (1, 9)],
        back=(54, 110, 128), belly=(230, 234, 232), fin=(120, 150, 150), tail_col=(66, 112, 126),
        tail=("fork", 88, 54), dorsal=[("top", 0.3, 0.42, 24, "spiny", 7), ("top", 0.48, 0.8, 26, "soft")],
        anal=[("bot", 0.54, 0.8, 22, "soft")], pectoral=(0.22, 34), eye=(0.11, -6, 12), scales=0.0,
        marks=["pectoral_spot"], mouth="up"),
    "striped_bass": dict(  # longer and more streamlined than the European sea bass
        x0=44, x1=392, top=[(0, 4), (0.06, -16), (0.25, -34), (0.5, -36), (0.8, -22), (1, -10)],
        bot=[(0, 8), (0.08, 18), (0.3, 32), (0.6, 30), (0.85, 16), (1, 10)],
        back=(92, 104, 108), belly=(238, 238, 232), fin=(140, 146, 148), tail_col=(106, 116, 120),
        tail=("fork", 82, 52), dorsal=[("top", 0.3, 0.46, 34, "spiny", 8), ("top", 0.52, 0.68, 26, "soft")],
        anal=[("bot", 0.6, 0.72, 20, "soft")], pelvic=("bot", 0.3, 0.38, 16), pectoral=(0.22, 34), eye=(0.11, -8, 12),
        scales=0.5, marks=["long_stripes"], mouth="up"),
    "giant_trevally": dict(
        x0=60, x1=384, top=[(0, 10), (0.03, -4), (0.1, -34), (0.26, -62), (0.5, -60), (0.78, -30), (1, -8)],
        bot=[(0, 12), (0.1, 30), (0.34, 50), (0.62, 42), (0.86, 18), (1, 8)],
        back=(92, 98, 108), belly=(214, 218, 220), fin=(96, 100, 110), tail_col=(84, 90, 100),
        tail=("deepfork", 100, 70), dorsal=[("top", 0.26, 0.36, 20, "spiny", 6), ("top", 0.4, 0.62, 44, "tri", 0, 0.6)],
        anal=[("bot", 0.42, 0.62, 40, "tri", 0, 0.6)], pectoral=(0.2, 60), eye=(0.1, -14, 13), scales=0.0,
        marks=["dark_flecks", "scute_line"], mouth="flat", keel=True),
    "wahoo": dict(
        x0=26, x1=404, top=[(0, 6), (0.04, -6), (0.14, -18), (0.4, -26), (0.75, -20), (0.92, -10), (1, -6)],
        bot=[(0, 8), (0.05, 10), (0.16, 18), (0.45, 24), (0.75, 18), (0.92, 10), (1, 6)],
        back=(40, 72, 116), belly=(222, 230, 236), fin=(56, 84, 126), tail_col=(44, 74, 116),
        tail=("deepfork", 70, 54), dorsal=[("top", 0.2, 0.55, 14, "long"), ("top", 0.66, 0.72, 14, "tri")],
        anal=[("bot", 0.64, 0.72, 14, "tri")], finlets=(0.74, 0.98, 8), pectoral=(0.16, 22), eye=(0.07, -2, 9), scales=0.0,
        marks=["tiger_bars"], mouth="beak", keel=True),
    "spanish_mackerel": dict(
        x0=40, x1=400, top=[(0, 4), (0.05, -10), (0.18, -24), (0.4, -32), (0.75, -24), (0.92, -12), (1, -6)],
        bot=[(0, 6), (0.06, 12), (0.2, 24), (0.45, 30), (0.75, 20), (0.92, 10), (1, 6)],
        back=(64, 98, 132), belly=(226, 232, 236), fin=(90, 114, 140), tail_col=(66, 98, 130),
        tail=("deepfork", 82, 60), dorsal=[("top", 0.22, 0.48, 18, "spiny", 12), ("top", 0.56, 0.64, 20, "tri")],
        anal=[("bot", 0.58, 0.66, 18, "tri")], finlets=(0.68, 0.98, 8), pectoral=(0.18, 26), eye=(0.08, -4, 10), scales=0.0,
        marks=["wavy_bars"], mouth="flat", keel=True),
    "grouper": dict(
        x0=58, x1=380, top=[(0, 4), (0.04, -14), (0.15, -40), (0.38, -54), (0.65, -46), (0.88, -26), (1, -16)],
        bot=[(0, 16), (0.1, 32), (0.36, 50), (0.64, 46), (0.88, 26), (1, 16)],
        back=(104, 74, 54), belly=(206, 170, 120), fin=(116, 82, 60), tail_col=(104, 74, 54),
        tail=("round", 66, 48), dorsal=[("top", 0.22, 0.56, 30, "spiny", 11), ("top", 0.6, 0.84, 30, "soft")],
        anal=[("bot", 0.62, 0.82, 26, "soft")], pelvic=("bot", 0.3, 0.38, 20), pectoral=(0.24, 42), eye=(0.12, -10, 12),
        scales=0.0, marks=["pale_blotches"], mouth="up", fin_tint=(150, 110, 70)),
}

JUNK = ["old_boot", "tangled_rope", "rusty_tin"]


# --- Painting a fish ----------------------------------------------------------------------

def paint_fins(p, shape, spec, which):
    fin = spec["fin"]
    tint = spec.get("fin_tint", fin)
    edge = mix(fin, INK, 0.3)
    masks = []
    for entry in spec.get(which, []):
        edge_name, t0, t1, height, kind = entry[:5]
        rays = entry[5] if len(entry) > 5 else 0
        sweep = entry[6] if len(entry) > 6 else 0.35
        m = fin_on(shape, edge_name, t0, t1, height, kind, sweep, rays)
        m = minus(m, shape.mask())
        colour = spec.get("finlet_col", tint) if kind == "tri" and spec.get("finlet_col") and height > 40 else tint
        p.wash(m, mix(colour, (255, 255, 255), 0.1), colour, alpha=0.95, ink_w=1.6)
        if spec.get("black_tips"):
            box = m.getbbox()
            if box:
                tip_y = (box[1] if edge_name == "top" else box[3]) / SS
                band = poly([(0, tip_y - 14), (W, tip_y - 14), (W, tip_y + 14), (0, tip_y + 14)]) if edge_name == "top" else \
                    poly([(0, tip_y - 14), (W, tip_y - 14), (W, tip_y + 14), (0, tip_y + 14)])
                p.ink(clip(m, band), (34, 30, 28), 230)
        if spec.get("fin_rays") or kind in ("spiny", "soft"):
            box = m.getbbox()
            if box:
                for k in range(8):
                    x = (box[0] + (box[2] - box[0]) * (k + 0.5) / 8) / SS
                    y_in = shape.top_at((x - shape.x0) / (shape.x1 - shape.x0)) if edge_name == "top" else shape.bot_at((x - shape.x0) / (shape.x1 - shape.x0))
                    y_out = box[1] / SS if edge_name == "top" else box[3] / SS
                    p.ink(clip(tube([(x, y_in), (x + 4, y_out)], 1.0), m), edge, 110)
        masks.append(m)
    return masks


def paint_body(p, shape, spec):
    body = shape.mask()
    top_y = min(y for _, y in shape.top)
    bot_y = max(y for _, y in shape.bot)
    p.wash(body, spec["back"], spec["belly"], top_y, bot_y, sheen=0.12, ink_w=2.2)
    if spec.get("marks") and "countershade" in spec["marks"]:
        # A crisp line between the dark back and the white belly.
        line = [(shape.x(t / 20), shape.mid_at(t / 20) + 4 + 6 * math.sin(t / 20 * math.pi)) for t in range(21)]
        belly = poly(line + [(W, H), (0, H)])
        p.wash(clip(body, belly), spec["belly"], spec["belly"], outline=False, sheen=0.02)
    if spec.get("scales", 0) > 0:
        pattern = blank()
        d = ImageDraw.Draw(pattern)
        step = 9
        for row in range(0, H // step + 2):
            for col in range(0, W // step + 2):
                cx = (col * step + (step / 2 if row % 2 else 0)) * SS
                cy = row * step * SS
                d.arc([cx - step * SS * 0.6, cy - step * SS * 0.6, cx + step * SS * 0.6, cy + step * SS * 0.6], 20, 160, fill=255, width=SS)
        p.ink(clip(pattern, body.filter(ImageFilter.MinFilter(7 * SS | 1))), mix(spec["back"], INK, 0.4), int(60 * spec["scales"]))
    return body


def paint_marks(p, shape, spec, body):
    marks = spec.get("marks", [])
    inner = body.filter(ImageFilter.MinFilter(3 * SS | 1))
    rng = np.random.default_rng(len(spec["back"]) * 31 + int(spec["x1"]))
    L = shape.x1 - shape.x0
    if "mackerel_waves" in marks:
        for k in range(15):
            t = 0.2 + k * 0.052
            x = shape.x(t)
            y_top = shape.top_at(t)
            y_mid = shape.mid_at(t) - 2
            p.ink(clip(tube([(x - 4, y_top + 1), (x + 5, y_top + (y_mid - y_top) * 0.4), (x - 3, y_top + (y_mid - y_top) * 0.75),
                             (x + 4, y_mid)], 3.4, 2.2), inner), (24, 40, 38), 225)
    if "sheen_band" in marks:
        band = poly([(shape.x(0.15), shape.mid_at(0.15) - 2), (shape.x(0.95), shape.mid_at(0.95) - 2),
                     (shape.x(0.95), shape.mid_at(0.95) + 4), (shape.x(0.15), shape.mid_at(0.15) + 6)])
        p.ink(clip(band.filter(ImageFilter.GaussianBlur(SS * 2)), inner), (200, 214, 226), 120)
    if "plaice_spots" in marks:
        for k in range(14):
            t = rng.uniform(0.16, 0.92)
            y = rng.uniform(shape.top_at(t) + 12, shape.bot_at(t) - 12)
            p.ink(clip(ell((shape.x(t), y), (5.5, 5.5)), inner), (226, 112, 52), 235)
            p.outline(clip(ell((shape.x(t), y), (5.5, 5.5)), inner), 1.0, mix((226, 112, 52), INK, 0.4), 140)
    if "speckles" in marks:
        for k in range(110):
            t = rng.uniform(0.12, 0.98)
            y = rng.uniform(shape.top_at(t) + 3, shape.mid_at(t) + 10)
            p.ink(clip(ell((shape.x(t), y), (1.6, 1.4)), inner), (78, 66, 40), 170)
    if "lateral_pale" in marks or "lateral_dark" in marks:
        colour = (238, 230, 206) if "lateral_pale" in marks else mix(spec["back"], INK, 0.5)
        pts = [(shape.x(t / 24), shape.top_at(t / 24) + (shape.mid_at(t / 24) - shape.top_at(t / 24)) * (0.55 if t < 8 else 0.75))
               for t in range(3, 25)]
        p.ink(clip(tube(pts, 2.4), inner), colour, 200)
    if "perch_bars" in marks:
        for k in range(6):
            t = 0.26 + k * 0.11
            band = poly([(shape.x(t) - 6, shape.top_at(t) - 2), (shape.x(t) + 8, shape.top_at(t) - 2),
                         (shape.x(t) + 4, shape.bot_at(t) - 16), (shape.x(t) - 3, shape.bot_at(t) - 18)])
            p.ink(clip(band.filter(ImageFilter.GaussianBlur(SS * 1.2)), inner), (40, 58, 30), 170)
    if "gar_band" in marks:
        pts = [(shape.x(t / 20), shape.mid_at(t / 20) + 1) for t in range(4, 21)]
        p.ink(clip(tube(pts, 3.0), inner), (196, 216, 214), 150)
    if "gold_brow" in marks:
        e = spec["eye"]
        x = shape.x(e[0]) + 2
        p.ink(clip(tube([(x - 22, shape.top_at(e[0]) + 16), (x - 4, shape.top_at(e[0]) + 7), (x + 22, shape.top_at(e[0]) + 13)], 7, 6), inner),
              (232, 186, 64), 245)
    if "gill_spot" in marks:
        t = spec["eye"][0] + 0.1
        p.ink(clip(ell((shape.x(t), shape.mid_at(t) - 10), (6, 5)), inner), (40, 40, 44), 200)
    if "faint_lines" in marks:
        for k in range(5):
            frac = 0.25 + k * 0.13
            pts = [(shape.x(t / 20), shape.top_at(t / 20) + (shape.bot_at(t / 20) - shape.top_at(t / 20)) * frac) for t in range(5, 20)]
            p.ink(clip(tube(pts, 1.6), inner), mix(spec["back"], INK, 0.3), 80)
    if "trout_spots" in marks:
        for k in range(46):
            t = rng.uniform(0.14, 0.95)
            y = rng.uniform(shape.top_at(t) + 4, shape.mid_at(t) + 6)
            x = shape.x(t)
            m = union(tube([(x - 2.2, y - 2.2), (x + 2.2, y + 2.2)], 1.6), tube([(x - 2.2, y + 2.2), (x + 2.2, y - 2.2)], 1.6))
            p.ink(clip(m, inner), (38, 36, 40), 170)
    if "bonito_stripes" in marks:
        for k in range(7):
            t0 = 0.2 + k * 0.1
            pts = [(shape.x(t0), shape.top_at(t0) + 3), (shape.x(t0 + 0.12), shape.mid_at(t0 + 0.12) - 4)]
            p.ink(clip(tube(pts, 3.0), inner), (28, 40, 70), 220)
    if "skipjack_stripes" in marks:
        for k in range(4):
            frac = 0.58 + k * 0.1
            pts = [(shape.x(t / 20), shape.top_at(t / 20) + (shape.bot_at(t / 20) - shape.top_at(t / 20)) * frac) for t in range(5, 19)]
            p.ink(clip(tube(pts, 3.2), inner), (52, 62, 92), 190)
    if "mahi_dots" in marks:
        for k in range(36):
            t = rng.uniform(0.15, 0.95)
            y = rng.uniform(shape.top_at(t) + 6, shape.bot_at(t) - 8)
            p.ink(clip(ell((shape.x(t), y), (2.2, 2.2)), inner), (30, 96, 120), 190)
    if "yellow_band" in marks:
        pts = [(shape.x(t / 20), shape.mid_at(t / 20) - 4) for t in range(3, 19)]
        p.ink(clip(tube(pts, 6.0, 3.0).filter(ImageFilter.GaussianBlur(SS * 0.8)), inner), (236, 200, 60), 210)
    if "belly_dashes" in marks:
        for k in range(14):
            t = 0.3 + k * 0.045
            y = shape.mid_at(t) + 12
            p.ink(clip(tube([(shape.x(t), y), (shape.x(t), y + 14)], 2.2), inner), (196, 204, 220), 170)
    # --- I021 marks ---
    if "arched_line" in marks:  # the pollack's dark lateral line, arched over the pectoral fin
        pts = [(shape.x(t / 24), shape.top_at(t / 24) + (shape.mid_at(t / 24) - shape.top_at(t / 24)) * (0.35 + 0.4 * min(1.0, t / 12)))
               for t in range(3, 25)]
        p.ink(clip(tube(pts, 2.2), inner), mix(spec["back"], INK, 0.55), 210)
    if "mottle" in marks:
        for k in range(26):
            t = rng.uniform(0.14, 0.94)
            y = rng.uniform(shape.top_at(t) + 10, shape.bot_at(t) - 10)
            p.ink(clip(ell((shape.x(t), y), (rng.uniform(5, 9), rng.uniform(4, 7))).filter(ImageFilter.GaussianBlur(SS * 1.2)), inner),
                  mix(spec["back"], INK, 0.35), 120)
    if "yellow_stripes" in marks:
        for k in range(3):
            frac = 0.42 + k * 0.14
            pts = [(shape.x(t / 20), shape.top_at(t / 20) + (shape.bot_at(t / 20) - shape.top_at(t / 20)) * frac) for t in range(3, 19)]
            p.ink(clip(tube(pts, 2.6), inner), (238, 204, 84), 200)
    if "blue_spots" in marks:
        for k in range(30):
            t = rng.uniform(0.14, 0.86)
            y = rng.uniform(shape.top_at(t) + 6, shape.mid_at(t))
            p.ink(clip(ell((shape.x(t), y), (2.2, 2.0)), inner), (70, 120, 190), 200)
    if "pectoral_spot" in marks:
        t = spec["pectoral"][0]
        p.ink(clip(ell((shape.x(t) + 2, shape.mid_at(t) + 3), (5, 4)), inner), (30, 40, 46), 200)
    if "long_stripes" in marks:
        for k in range(6):
            frac = 0.18 + k * 0.1
            pts = [(shape.x(t / 20), shape.top_at(t / 20) + (shape.bot_at(t / 20) - shape.top_at(t / 20)) * frac) for t in range(4, 20)]
            p.ink(clip(tube(pts, 1.8), inner), (44, 50, 56), 190)
    if "dark_flecks" in marks:
        for k in range(40):
            t = rng.uniform(0.15, 0.85)
            y = rng.uniform(shape.top_at(t) + 6, shape.bot_at(t) - 8)
            p.ink(clip(ell((shape.x(t), y), (1.4, 1.2)), inner), (36, 38, 44), 170)
    if "scute_line" in marks:
        pts = [(shape.x(t / 20), shape.mid_at(t / 20) + 2) for t in range(13, 20)]
        p.ink(clip(tube(pts, 3.2), inner), mix(spec["back"], INK, 0.4), 190)
    if "tiger_bars" in marks:
        for k in range(18):
            t = 0.16 + k * 0.045
            pts = [(shape.x(t), shape.top_at(t) + 2), (shape.x(t) + 3, shape.mid_at(t) + 4)]
            p.ink(clip(tube(pts, 2.0), inner), (60, 96, 160), 210)
    if "wavy_bars" in marks:
        for k in range(16):
            t = 0.2 + k * 0.045
            x = shape.x(t)
            y_top = shape.top_at(t)
            y_mid = shape.mid_at(t) + 2
            p.ink(clip(tube([(x, y_top + 2), (x + 3, y_top + (y_mid - y_top) * 0.4), (x - 2, y_top + (y_mid - y_top) * 0.75),
                             (x + 2, y_mid)], 1.8), inner), (40, 60, 92), 200)
    if "pale_blotches" in marks:
        for k in range(18):
            t = rng.uniform(0.16, 0.9)
            y = rng.uniform(shape.top_at(t) + 8, shape.bot_at(t) - 10)
            p.ink(clip(ell((shape.x(t), y), (rng.uniform(4, 7), rng.uniform(3, 5))).filter(ImageFilter.GaussianBlur(SS * 0.6)), inner),
                  (214, 196, 160), 170)
    if "gills" in marks:
        for k in range(5):
            t = spec["eye"][0] + 0.1 + k * 0.02
            x = shape.x(t)
            p.ink(clip(tube([(x - 1, shape.mid_at(t) - 10), (x + 2, shape.mid_at(t)), (x, shape.mid_at(t) + 9)], 1.6), inner), INK, 170)


def paint_head(p, shape, spec):
    """Mouth, gill cover, barbel."""
    mouth = spec.get("mouth", "flat")
    nose = (shape.x0, (shape.top[0][1] + shape.bot[0][1]) / 2)
    L = shape.x1 - shape.x0
    if mouth == "beak":
        p.line([(nose[0] + 2, nose[1]), (shape.x(0.16), nose[1] + 1)], 1.2, INK, 190)
    elif mouth == "shark":
        p.line([(shape.x(0.05), shape.bot_at(0.05) - 2), (shape.x(0.1), shape.bot_at(0.1) - 4), (shape.x(0.13), shape.bot_at(0.13) - 2)], 1.6, INK, 200)
    else:
        dy = {"up": -3, "down": 4, "flat": 0}[mouth]
        p.line([(nose[0] + 2, nose[1] + dy), (nose[0] + L * 0.06, nose[1] + dy + 3)], 1.8, INK, 210)
    if not spec.get("shark"):
        t = spec["eye"][0] + 0.09
        gx = shape.x(t)
        p.line([(gx - 6, shape.top_at(t) + 8), (gx + 2, shape.mid_at(t)), (gx - 4, shape.bot_at(t) - 6)], 1.8, mix(spec["back"], INK, 0.55), 170)
    if spec.get("barbel"):
        p.line([(shape.x(0.06), shape.bot_at(0.06) - 1), (shape.x(0.06) + 1, shape.bot_at(0.06) + 10), (shape.x(0.06) - 3, shape.bot_at(0.06) + 15)],
               1.8, mix(spec["back"], INK, 0.3), 220)


def eye_point(shape, spec):
    t, dy, r = spec["eye"]
    return (shape.x(t), shape.top_at(t) + (shape.mid_at(t) - shape.top_at(t)) * 0.55 + dy), r


def paint_eye(p, c, r, spec):
    iris = (196, 70, 60) if spec.get("eye_red") else (208, 186, 120)
    p.dot(c, r, (244, 238, 220))
    p.dot(c, r * 0.78, iris)
    p.dot(c, r * 0.52, (22, 22, 24))
    p.dot((c[0] - r * 0.28, c[1] - r * 0.3), r * 0.2, (255, 255, 250))
    p.outline(ell(c, (r, r)), 1.3)


def paint_lid(p, c, r, colour):
    p.wash(ell(c, (r * 1.08, r * 1.08)), mix(colour, (255, 255, 255), 0.08), colour, outline=False, sheen=0.05)
    p.line([(c[0] - r * 0.85, c[1] - r * 0.05), (c[0], c[1] + r * 0.35), (c[0] + r * 0.85, c[1] - r * 0.05)], max(r * 0.2, 1.6))


def paint_species(sid):
    spec = SPECIES[sid]
    shape = Shape(spec)
    root, half = shape.root()
    kind, length, spread = spec["tail"]

    # The tail, alone.
    tail_p = Painter()
    tail = tail_mask(root, half, kind, length, spread)
    tail_p.wash(tail, mix(spec["tail_col"], (255, 255, 255), 0.12), spec["tail_col"], ink_w=1.8)
    if spec.get("black_tips"):
        tip = poly([(root[0] + length * 0.65, 0), (W, 0), (W, root[1] - spread * 0.85), (root[0] + length * 0.7, root[1] - spread * 0.85)])
        tail_p.ink(clip(tail, tip), (34, 30, 28), 230)
    box = tail.getbbox()
    for k in range(7):
        y = root[1] + (k - 3) * spread / 3.4
        tail_p.ink(clip(tube([(root[0] + 4, root[1] + (k - 3) * half / 4), (root[0] + length * 0.85, y)], 1.1), tail),
                   mix(spec["tail_col"], INK, 0.35), 90)

    # The body with its fins and face.
    p = Painter()
    fin_masks = []
    fin_masks += paint_fins(p, shape, spec, "dorsal")
    fin_masks += paint_fins(p, shape, spec, "anal")
    if spec.get("pelvic"):
        edge, t0, t1, height = spec["pelvic"]
        m = minus(fin_on(shape, edge, t0, t1, height, "soft", 0.6), shape.mask())
        p.wash(m, spec.get("fin_tint", spec["fin"]), outline=True, ink_w=1.4, alpha=0.95)
    if spec.get("adipose"):
        t0, t1 = spec["adipose"]
        m = minus(fin_on(shape, "top", t0, t1, 9, "soft", 0.3), shape.mask())
        p.wash(m, spec["back"], outline=True, ink_w=1.4)
    body = paint_body(p, shape, spec)
    paint_marks(p, shape, spec, body)
    if spec.get("finlets"):
        t0, t1, n = spec["finlets"]
        for k in range(n):
            t = t0 + (t1 - t0) * k / max(n - 1, 1)
            for edge in ("top", "bot"):
                y = shape.top_at(t) if edge == "top" else shape.bot_at(t)
                sign = -1 if edge == "top" else 1
                m = poly([(shape.x(t) - 3, y), (shape.x(t) + 6, y + sign * 7), (shape.x(t) + 4, y - sign * 1)])
                p.wash(m, spec.get("finlet_col", spec["fin"]), ink_w=1.0)
    if spec.get("keel"):
        p.line([(shape.x(0.86), shape.mid_at(0.86)), (shape.x(1.0), shape.mid_at(1.0))], 3.0, mix(spec["back"], INK, 0.4), 200)
    paint_head(p, shape, spec)
    pec = spec["pectoral"]
    pm = blank() if pec[1] <= 0 else pectoral(shape, pec[0], pec[1], pec[2] if len(pec) > 2 else 25, pec[3] if len(pec) > 3 else 0.42)
    p.wash(pm, mix(spec.get("fin_tint", spec["fin"]), (255, 255, 255), 0.12), spec.get("fin_tint", spec["fin"]), alpha=0.92, ink_w=1.4)
    if spec.get("black_tips"):
        tip = ell((shape.x(pec[0]) + pec[1] * 0.9, shape.mid_at(pec[0]) + pec[1] * 0.55), (16, 12))
        p.ink(clip(pm, tip), (34, 30, 28), 230)
    eye_c, eye_r = eye_point(shape, spec)
    lid_colour = p.colour_at(eye_c[0], eye_c[1], eye_r * 0.8)
    paint_eye(p, eye_c, eye_r, spec)
    eyes = [(eye_c, eye_r)]
    if spec.get("second_eye"):
        t, dy, r = spec["second_eye"]
        c2 = (shape.x(t), shape.top_at(t) + 12 + dy * 0.2)
        paint_eye(p, c2, r, spec)
        eyes.append((c2, r))

    lid_p = Painter()
    for c, r in eyes:
        paint_lid(lid_p, c, r, lid_colour)
    return {"tail": tail_p.image(), "body": p.image(), "lid": lid_p.image(shadow=False),
            "meta": {"tail_pivot": [round(root[0], 1), round(root[1], 1)], "eye": [round(eye_c[0], 1), round(eye_c[1], 1), eye_r],
                     "canvas": [W, H], "kind": "shark" if spec.get("shark") else "fish"}}


# --- Junk --------------------------------------------------------------------------------

def paint_junk(jid):
    p = Painter(seed=11)
    if jid == "old_boot":
        shaft = poly(smooth([(196, 40), (262, 34), (270, 120), (274, 150), (360, 168), (378, 192), (372, 206), (184, 206), (178, 160), (190, 120)], 10))
        p.wash(shaft, (120, 84, 56), (86, 58, 40), ink_w=2.4)
        sole = poly([(180, 198), (376, 198), (378, 214), (182, 216)])
        p.wash(sole, (64, 52, 44), ink_w=2.0)
        for k in range(5):
            y = 70 + k * 18
            p.line([(206, y), (254, y - 4)], 2.2, (222, 210, 182), 230)
        p.line([(200, 52), (258, 48)], 3.0, mix((120, 84, 56), INK, 0.4), 200)
        weed = union(tube([(236, 46), (228, 30), (240, 18), (234, 10)], 6, 3), tube([(300, 170), (322, 150), (318, 128)], 6, 3))
        p.wash(weed, (96, 140, 70), (60, 104, 52), ink_w=1.4)
        p.dot((330, 186), 2.5, (60, 50, 40), 200)
    elif jid == "tangled_rope":
        rng = np.random.default_rng(5)
        loops = []
        for k in range(7):
            cx, cy = 256 + rng.uniform(-60, 60), 128 + rng.uniform(-36, 36)
            rx, ry = rng.uniform(34, 70), rng.uniform(20, 44)
            pts = [(cx + rx * math.cos(a), cy + ry * math.sin(a)) for a in np.linspace(0, 2 * math.pi * 1.1, 40)]
            loops.append(pts)
        for pts in loops:
            m = tube(pts, 9)
            p.wash(m, (218, 196, 150), (176, 150, 104), ink_w=1.6)
            for q in range(0, len(pts) - 1, 3):
                x, y = pts[q]
                p.ink(clip(tube([(x - 3, y - 3), (x + 3, y + 3)], 1.2), m), (130, 104, 70), 160)
        end = tube([(214, 160), (170, 190), (130, 214), (100, 210)], 9)
        p.wash(end, (218, 196, 150), (176, 150, 104), ink_w=1.6)
    else:  # rusty tin
        body = poly([(196, 70), (326, 70), (326, 200), (196, 200)])
        p.wash(body, (176, 172, 160), (130, 124, 114), ink_w=2.2)
        label = poly([(196, 104), (326, 104), (326, 166), (196, 166)])
        p.wash(label, (180, 92, 70), (150, 70, 54), outline=False)
        p.line([(214, 136), (306, 136)], 4, (236, 220, 180), 200)
        top = ell((261, 70), (65, 12))
        p.wash(top, (196, 192, 182), (150, 146, 136), ink_w=1.8)
        rng = np.random.default_rng(3)
        for k in range(26):
            c = (rng.uniform(200, 322), rng.uniform(74, 198))
            p.ink(clip(ell(c, (rng.uniform(2, 6), rng.uniform(2, 5))), body), (150, 84, 40), 170)
        lid = poly([(262, 64), (330, 40), (336, 48), (270, 70)])
        p.wash(lid, (190, 186, 176), ink_w=1.6)
    return p.image()


# --- Output -------------------------------------------------------------------------------

def save(img, path):
    os.makedirs(os.path.dirname(path), exist_ok=True)
    img.save(path)


def thumb_of(layers):
    comp = Image.new("RGBA", (W, H), (0, 0, 0, 0))
    for layer in layers:
        comp.alpha_composite(layer)
    box = comp.getbbox() or (0, 0, W, H)
    pad = 6
    box = (max(box[0] - pad, 0), max(box[1] - pad, 0), min(box[2] + pad, W), min(box[3] + pad, H))
    crop = comp.crop(box)
    crop.thumbnail(THUMB, Image.LANCZOS)
    out = Image.new("RGBA", THUMB, (0, 0, 0, 0))
    out.alpha_composite(crop, ((THUMB[0] - crop.width) // 2, (THUMB[1] - crop.height) // 2))
    return out


def main(ids):
    meta = {}
    if os.path.exists(META):
        with open(META) as f:
            meta = json.load(f).get("art", {})
    for sid in ids:
        if sid in SPECIES:
            layers = paint_species(sid)
            for name in ("tail", "body", "lid"):
                save(layers[name], os.path.join(OUT, sid, name + ".png"))
            save(thumb_of([layers["tail"], layers["body"]]), os.path.join(OUT, sid, "thumb.png"))
            meta[sid] = layers["meta"]
        elif sid in JUNK:
            art = paint_junk(sid)
            save(art, os.path.join(OUT, sid, "art.png"))
            save(thumb_of([art]), os.path.join(OUT, sid, "thumb.png"))
            meta[sid] = {"canvas": [W, H], "kind": "junk"}
        else:
            print("unknown:", sid)
            continue
        print("painted", sid)
    with open(META, "w") as f:
        json.dump({"note": "Written by tools/fishing/paint_fish.py: the layer canvas, the tail's pivot and the eye (canvas px).",
                   "art": meta}, f, indent=1, sort_keys=True)


if __name__ == "__main__":
    main(sys.argv[1:] or list(SPECIES) + JUNK)
