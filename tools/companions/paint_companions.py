"""Paints the ship's cat and dog (Iteration 13) in the game's illustrated style.

The boats, the sailor and the harbour are drawn from above in warm ink lines
over soft colour washes (tools/vessels/illustrate.py). The companions follow
the same look: seen from above and a little in front, so their faces read at
the small size they have in the cabin. Every pose is painted on the same
256 x 256 canvas with the animal in the same place, so poses line up when the
game cross-fades between them (see CompanionVisualSet).

Poses (the names CompanionVisualSet uses):
  resting     idle: lying with the head up on the paws, eyes half open
  sleeping    asleep: curled up (cat) / on its side (dog), eyes closed
  alert       looking up, and the pose shown when petted (with hearts)
  stretching  a long stretch, front paws forward

Writes assets/companions/<kind>/<pose>.png. The owner's original cat drawings
in Visuals/Cat are never read or changed.

Usage: python3 tools/companions/paint_companions.py
Requirements: Python 3 with Pillow and numpy.
"""
import math
import os

import numpy as np
from PIL import Image, ImageChops, ImageDraw, ImageFilter

ROOT = os.path.join(os.path.dirname(__file__), "..", "..")
OUT = os.path.join(ROOT, "assets", "companions")
N = 256          # final canvas, px
SS = 4           # supersampling while painting
INK = (52, 44, 38)
SHADOW = (20, 30, 34)

CAT = {
    "fur": (128, 134, 136), "fur_dark": (78, 82, 86), "stripe": (70, 72, 76), "white": (241, 236, 224),
    "ear": (226, 168, 156), "nose": (214, 140, 132), "eye": (60, 72, 46), "iris": (164, 176, 92),
}
DOG = {
    "fur": (176, 118, 72), "fur_dark": (122, 80, 50), "white": (240, 228, 206), "ear": (118, 76, 48),
    "nose": (48, 36, 32), "eye": (44, 32, 26), "tongue": (214, 120, 118), "collar": (176, 84, 62),
}


# --- Drawing helpers (design units are final pixels) ------------------------------

def blank():
    return Image.new("L", (N * SS, N * SS), 0)


def _p(points):
    return [(x * SS, y * SS) for x, y in points]


def ellipse_points(c, r, angle=0.0, steps=64):
    a = math.radians(angle)
    pts = []
    for i in range(steps):
        t = 2 * math.pi * i / steps
        x, y = r[0] * math.cos(t), r[1] * math.sin(t)
        pts.append((c[0] + x * math.cos(a) - y * math.sin(a), c[1] + x * math.sin(a) + y * math.cos(a)))
    return pts


def ell(c, r, angle=0.0):
    m = blank()
    ImageDraw.Draw(m).polygon(_p(ellipse_points(c, r, angle)), fill=255)
    return m


def poly(points):
    m = blank()
    ImageDraw.Draw(m).polygon(_p(points), fill=255)
    return m


def bezier(points, steps=40):
    """A smooth curve through control points (quadratic B-spline style)."""
    if len(points) == 2:
        (x0, y0), (x1, y1) = points
        return [(x0 + (x1 - x0) * k / steps, y0 + (y1 - y0) * k / steps) for k in range(steps + 1)]
    if len(points) < 2:
        return points
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
    """A soft tapering tube along a smooth curve (tails, legs)."""
    w1 = w0 if w1 is None else w1
    curve = bezier(points)
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


class Painter:
    def __init__(self):
        self.img = Image.new("RGBA", (N * SS, N * SS), (0, 0, 0, 0))
        self.silhouette = blank()
        rng = np.random.default_rng(7)
        noise = rng.normal(0.0, 1.0, (N // 4, N // 4)).astype(np.float32)
        self.grain = np.array(Image.fromarray(((noise * 18) + 128).clip(0, 255).astype(np.uint8)).resize((N * SS, N * SS), Image.BICUBIC),
                              dtype=np.float32) / 128.0 - 1.0

    def fill(self, mask, colour, light=(0.35, 0.3), shade=0.22, outline=True, ink_w=2.2, alpha=1.0):
        """A colour wash in `mask`: lit from the upper left, with a little grain,
        and an ink line just inside its edge."""
        box = mask.getbbox()
        if not box:
            return
        h, w = N * SS, N * SS
        yy, xx = np.mgrid[0:h, 0:w].astype(np.float32)
        cx = box[0] + (box[2] - box[0]) * light[0]
        cy = box[1] + (box[3] - box[1]) * light[1]
        size = max(box[2] - box[0], box[3] - box[1])
        d = np.sqrt((xx - cx) ** 2 + (yy - cy) ** 2) / max(size, 1)
        f = (1.0 + 0.12 - d * shade * 1.6).clip(1.0 - shade, 1.12)
        f = f + self.grain * 0.05
        rgb = (np.array(colour, dtype=np.float32)[None, None, :] * f[:, :, None]).clip(0, 255).astype(np.uint8)
        layer = Image.fromarray(np.dstack([rgb, (np.array(mask, dtype=np.float32) * alpha).astype(np.uint8)]), "RGBA")
        self.img.alpha_composite(layer)
        self.silhouette = union(self.silhouette, mask)
        if outline:
            self.outline(mask, ink_w)

    def outline(self, mask, width=2.2, colour=INK, alpha=235):
        k = max(3, int(width * SS) | 1)
        inner = mask.filter(ImageFilter.MinFilter(k))
        ring = minus(mask, inner).filter(ImageFilter.GaussianBlur(SS * 0.35))
        self.ink(ring, colour, alpha)

    def ink(self, mask, colour=INK, alpha=235):
        a = (np.array(mask, dtype=np.float32) * alpha / 255.0).astype(np.uint8)
        layer = Image.new("RGBA", self.img.size, colour + (0,))
        layer.putalpha(Image.fromarray(a))
        self.img.alpha_composite(layer)

    def line(self, points, width, colour=INK, alpha=235, smooth=True):
        self.ink(tube(points if smooth else points, width), colour, alpha)

    def dot(self, c, r, colour, alpha=255):
        self.ink(ell(c, (r, r)), colour, alpha)

    def finish(self, path):
        # A soft shadow under the animal, like the boats' fixtures.
        shadow = self.silhouette.filter(ImageFilter.GaussianBlur(SS * 4))
        shadow = ImageChops.offset(shadow, 3 * SS, 5 * SS)
        sh = Image.new("RGBA", self.img.size, SHADOW + (0,))
        sh.putalpha(shadow.point(lambda v: int(v * 0.32)))
        out = Image.alpha_composite(sh, self.img)
        out = out.resize((N, N), Image.LANCZOS)
        os.makedirs(os.path.dirname(path), exist_ok=True)
        out.save(path)
        print("wrote", os.path.relpath(path, ROOT))


# --- Faces ----------------------------------------------------------------------------

def cat_face(p, c, scale=1.0, eyes="open", tilt=0.0):
    """Eyes, nose, mouth and whiskers on a cat's head centred at `c`."""
    s = scale
    for side in (-1, 1):
        e = (c[0] + side * 11 * s, c[1] - 2 * s + tilt * side)
        if eyes == "open":
            p.dot(e, 4.6 * s, CAT["iris"])
            p.ink(ell(e, (2.0 * s, 3.8 * s)), (30, 30, 26), 255)
            p.dot((e[0] - 1.2 * s, e[1] - 1.6 * s), 1.1 * s, (255, 255, 250))
            p.outline(ell(e, (4.6 * s, 4.6 * s)), 1.2)
        elif eyes == "half":
            p.ink(minus(ell(e, (4.8 * s, 3.4 * s)), ell((e[0], e[1] - 3.2 * s), (6 * s, 3.6 * s))), (40, 40, 34), 255)
            p.line([(e[0] - 5 * s, e[1] - 0.6 * s), (e[0], e[1] - 1.6 * s), (e[0] + 5 * s, e[1] - 0.6 * s)], 1.6 * s)
        else:  # closed: content little arcs
            p.line([(e[0] - 5 * s, e[1]), (e[0], e[1] + 2.6 * s), (e[0] + 5 * s, e[1])], 1.8 * s)
    nose = (c[0], c[1] + 7 * s)
    p.ink(poly([(nose[0] - 3.4 * s, nose[1] - 2 * s), (nose[0] + 3.4 * s, nose[1] - 2 * s), (nose[0], nose[1] + 2 * s)]), CAT["nose"], 255)
    p.line([(nose[0], nose[1] + 1.5 * s), (nose[0] - 3.5 * s, nose[1] + 5 * s), (nose[0] - 6 * s, nose[1] + 4 * s)], 1.2 * s)
    p.line([(nose[0], nose[1] + 1.5 * s), (nose[0] + 3.5 * s, nose[1] + 5 * s), (nose[0] + 6 * s, nose[1] + 4 * s)], 1.2 * s)
    for side in (-1, 1):
        for k, dy in enumerate((-1.5, 2.0)):
            p.line([(nose[0] + side * 9 * s, nose[1] + dy * s), (nose[0] + side * 19 * s, nose[1] + (dy - 2 + k * 3) * s),
                    (nose[0] + side * 28 * s, nose[1] + (dy - 3 + k * 5) * s)], 0.9 * s, (236, 232, 222), 200)


def cat_head(p, c, scale=1.0, eyes="open", ears_angle=0.0):
    s = scale
    ears = []
    for side in (-1, 1):
        a = math.radians(ears_angle * side)
        base = (c[0] + side * 15 * s, c[1] - 12 * s)
        tip = (c[0] + side * 22 * s + math.sin(a) * 6 * s, c[1] - 33 * s)
        ear = poly([(base[0] - 10 * s, base[1] + 4 * s), tip, (base[0] + 9 * s, base[1] - 2 * s)])
        ears.append((ear, base, tip, side))
        p.fill(ear, CAT["fur"])
        inner = poly([(base[0] - 5 * s, base[1] + 1 * s), (tip[0] - side * 1.5 * s, tip[1] + 7 * s), (base[0] + 5 * s, base[1] - 2 * s)])
        p.fill(inner, CAT["ear"], outline=False)
    head = ell(c, (27 * s, 23 * s))
    p.fill(head, CAT["fur"])
    for k in (-1, 0, 1):  # forehead "M" stripes
        p.line([(c[0] + k * 6 * s, c[1] - 21 * s), (c[0] + k * 5 * s, c[1] - 12 * s)], 2.4 * s, CAT["stripe"], 210)
    for side in (-1, 1):
        p.line([(c[0] + side * 26 * s, c[1] - 2 * s), (c[0] + side * 18 * s, c[1] + 1 * s)], 2.0 * s, CAT["stripe"], 200)
    muzzle = union(ell((c[0] - 6 * s, c[1] + 9 * s), (9 * s, 7 * s)), ell((c[0] + 6 * s, c[1] + 9 * s), (9 * s, 7 * s)),
                   ell((c[0], c[1] + 3 * s), (5 * s, 9 * s)))
    p.fill(clip(muzzle, head), CAT["white"], outline=False)
    cat_face(p, c, s, eyes)


def dog_head(p, c, scale=1.0, eyes="open", tongue=False, ears_up=0.0):
    s = scale
    for side in (-1, 1):  # floppy ears behind the head
        ear = tube([(c[0] + side * 18 * s, c[1] - 14 * s), (c[0] + side * (30 + ears_up * 4) * s, c[1] - (2 + ears_up * 6) * s),
                    (c[0] + side * 27 * s, c[1] + 16 * s)], 15 * s, 13 * s)
        p.fill(ear, DOG["ear"])
    head = union(ell(c, (25 * s, 22 * s)), ell((c[0], c[1] + 12 * s), (15 * s, 14 * s)))
    p.fill(head, DOG["fur"])
    blaze = union(ell((c[0], c[1] + 13 * s), (13 * s, 11 * s)), poly([(c[0] - 4 * s, c[1] - 20 * s), (c[0] + 4 * s, c[1] - 20 * s),
                                                                        (c[0] + 7 * s, c[1] + 6 * s), (c[0] - 7 * s, c[1] + 6 * s)]))
    p.fill(clip(blaze, head), DOG["white"], outline=False)
    for side in (-1, 1):
        e = (c[0] + side * 11 * s, c[1] - 3 * s)
        if eyes == "open":
            p.dot(e, 4.2 * s, DOG["eye"])
            p.dot((e[0] - 1.2 * s, e[1] - 1.5 * s), 1.2 * s, (255, 250, 240))
        else:
            p.line([(e[0] - 4.5 * s, e[1]), (e[0], e[1] + 2.4 * s), (e[0] + 4.5 * s, e[1])], 1.8 * s)
        p.line([(e[0] - 4 * s, e[1] - 7 * s), (e[0] + 3 * s, e[1] - 8 * s)], 1.6 * s, DOG["fur_dark"], 200)
    nose = (c[0], c[1] + 15 * s)
    p.ink(ell(nose, (5.5 * s, 4 * s)), DOG["nose"], 255)
    p.dot((nose[0] - 1.6 * s, nose[1] - 1.4 * s), 1.2 * s, (120, 110, 104))
    p.line([(nose[0], nose[1] + 3 * s), (nose[0], nose[1] + 7 * s)], 1.3 * s)
    p.line([(nose[0] - 7 * s, nose[1] + 6 * s), (nose[0], nose[1] + 7.5 * s), (nose[0] + 7 * s, nose[1] + 6 * s)], 1.3 * s)
    if tongue:
        t = ell((nose[0], nose[1] + 12 * s), (4.5 * s, 6 * s))
        p.fill(t, DOG["tongue"], ink_w=1.4)
        p.line([(nose[0], nose[1] + 8 * s), (nose[0], nose[1] + 14 * s)], 1.0 * s, (150, 70, 70), 200)


def stripes(p, body, arcs):
    for pts, w in arcs:
        p.ink(clip(tube(pts, w, w * 0.6), body), CAT["stripe"], 215)


# --- The cat --------------------------------------------------------------------------

def cat_resting(path):
    p = Painter()
    tail = tube([(70, 150), (60, 190), (110, 206), (170, 200)], 17, 11)
    p.fill(tail, CAT["fur"])
    stripes(p, tail, [([(78, 172), (64, 182)], 6), ([(96, 200), (92, 210)], 6), ([(130, 203), (128, 212)], 6), ([(156, 199), (155, 208)], 5)])
    body = union(ell((118, 148), (58, 44), -8), ell((90, 160), (36, 34)))
    p.fill(body, CAT["fur"])
    stripes(p, body, [([(80, 112), (74, 140), (78, 168)], 7), ([(100, 106), (96, 136), (100, 168)], 7), ([(122, 106), (122, 134), (126, 160)], 7),
                      ([(142, 112), (146, 136)], 6), ([(66, 140), (62, 160)], 6)])
    for x in (150, 186):
        paw = ell((x, 182), (15, 10))
        p.fill(paw, CAT["white"])
    chest = ell((166, 166), (24, 18))
    p.fill(clip(chest, body) if False else chest, CAT["white"], outline=False)
    cat_head(p, (168, 140), 1.05, "half")
    p.finish(path)


def cat_sleeping(path):
    p = Painter()
    body = ell((128, 146), (66, 54))
    p.fill(body, CAT["fur"])
    stripes(p, body, [([(84, 104), (70, 140), (80, 180)], 8), ([(108, 96), (98, 136), (104, 186)], 8), ([(134, 94), (130, 120)], 7),
                      ([(158, 100), (168, 122)], 7), ([(178, 118), (190, 140)], 6)])
    head = (110, 168)
    tail = tube([(186, 148), (196, 184), (160, 204), (104, 202), (70, 190)], 18, 11)
    cat_head(p, head, 0.95, "closed", ears_angle=12)
    p.fill(tail, CAT["fur"])
    stripes(p, tail, [([(190, 168), (178, 174)], 6), ([(166, 196), (162, 206)], 6), ([(134, 202), (132, 212)], 6), ([(100, 200), (98, 209)], 5)])
    paw = ell((146, 184), (13, 9), -10)
    p.fill(paw, CAT["white"])
    p.finish(path)


def cat_alert(path):
    p = Painter()
    tail = tube([(160, 196), (196, 196), (204, 166)], 14, 9)
    p.fill(tail, CAT["fur"])
    stripes(p, tail, [([(178, 190), (178, 202)], 5), ([(196, 182), (206, 184)], 5)])
    body = union(ell((128, 168), (44, 38)), ell((128, 138), (32, 30)))
    p.fill(body, CAT["fur"])
    stripes(p, body, [([(92, 160), (98, 186)], 7), ([(164, 160), (158, 186)], 7), ([(102, 140), (108, 162)], 6), ([(154, 140), (148, 162)], 6)])
    chest = ell((128, 150), (20, 26))
    p.fill(chest, CAT["white"], outline=False)
    for x in (112, 144):
        paw = ell((x, 196), (11, 9))
        p.fill(paw, CAT["white"])
    cat_head(p, (128, 110), 1.15, "open")
    p.finish(path)


def cat_stretching(path):
    p = Painter()
    tail = tube([(60, 148), (40, 124), (44, 90), (58, 76)], 15, 10)
    p.fill(tail, CAT["fur"])
    stripes(p, tail, [([(46, 130), (36, 126)], 5), ([(40, 104), (50, 104)], 5)])
    for y in (130, 166):
        leg = tube([(96, y), (82, y + 6)], 16, 13)
        p.fill(leg, CAT["fur"])
    body = union(ell((120, 148), (56, 30), -4), ell((84, 146), (28, 30)))
    p.fill(body, CAT["fur"])
    stripes(p, body, [([(84, 120), (80, 172)], 7), ([(106, 120), (104, 172)], 7), ([(128, 120), (128, 170)], 7), ([(150, 124), (152, 168)], 6)])
    for y in (156, 178):
        leg = tube([(160, y), (214, y + 4)], 13, 11)
        p.fill(leg, CAT["fur"])
        p.fill(ell((216, y + 4), (10, 8)), CAT["white"])
    cat_head(p, (178, 150), 1.0, "closed", ears_angle=-14)
    p.finish(path)


# --- The dog --------------------------------------------------------------------------

def dog_resting(path):
    p = Painter()
    tail = tube([(70, 168), (52, 186), (60, 206)], 13, 8)
    p.fill(tail, DOG["fur"])
    body = union(ell((116, 158), (56, 38), -4), ell((84, 168), (32, 30)))
    p.fill(body, DOG["fur"])
    p.fill(clip(ell((120, 190), (40, 18)), body), DOG["white"], outline=False)
    for x in (66, 92):
        p.fill(ell((x, 196), (14, 9)), DOG["fur"])
    for x in (150, 186):
        leg = tube([(x - 14, 186), (x + 8, 196)], 16, 14)
        p.fill(leg, DOG["fur"])
        p.fill(ell((x + 10, 197), (12, 9)), DOG["white"])
    p.fill(tube([(146, 136), (142, 158), (146, 176)], 9, 9), DOG["collar"], ink_w=1.4)
    dog_head(p, (170, 152), 1.05, "open")
    p.finish(path)


def dog_sleeping(path):
    p = Painter()
    tail = tube([(58, 150), (44, 176), (52, 196)], 13, 8)
    p.fill(tail, DOG["fur"])
    for y in (184, 196):
        leg = tube([(80, y - 12), (68, y + 8)], 15, 12)
        p.fill(leg, DOG["fur"])
    body = union(ell((118, 156), (62, 40), 2), ell((80, 160), (30, 34)))
    p.fill(body, DOG["fur"])
    p.fill(clip(ell((116, 182), (46, 16)), body), DOG["white"], outline=False)
    for y in (186, 198):
        leg = tube([(158, y - 10), (196, y)], 14, 12)
        p.fill(leg, DOG["fur"])
        p.fill(ell((198, y), (10, 8)), DOG["white"])
    p.fill(tube([(152, 138), (148, 160), (152, 178)], 9, 9), DOG["collar"], ink_w=1.4)
    dog_head(p, (174, 156), 0.95, "closed")
    p.finish(path)


def dog_alert(path):
    p = Painter()
    tail = tube([(160, 200), (194, 196), (206, 170)], 13, 8)
    p.fill(tail, DOG["fur"])
    body = union(ell((128, 172), (46, 36)), ell((128, 142), (32, 28)))
    p.fill(body, DOG["fur"])
    p.fill(ell((128, 156), (20, 26)), DOG["white"], outline=False)
    for x in (110, 146):
        leg = tube([(x, 170), (x, 198)], 15, 13)
        p.fill(leg, DOG["fur"])
        p.fill(ell((x, 201), (11, 8)), DOG["white"])
    p.fill(tube([(108, 128), (148, 128)], 10, 10), DOG["collar"], ink_w=1.4)
    p.dot((128, 136), 4.5, (226, 196, 96))
    dog_head(p, (128, 100), 1.15, "open", tongue=True, ears_up=1.0)
    p.finish(path)


def dog_stretching(path):
    p = Painter()
    tail = tube([(58, 132), (40, 112), (42, 84)], 13, 8)
    p.fill(tail, DOG["fur"])
    for y in (132, 168):
        leg = tube([(92, y), (74, y + 6)], 17, 14)
        p.fill(leg, DOG["fur"])
    body = union(ell((118, 148), (58, 30), -3), ell((80, 148), (28, 32)))
    p.fill(body, DOG["fur"])
    for y in (158, 180):
        leg = tube([(160, y), (214, y + 4)], 14, 12)
        p.fill(leg, DOG["fur"])
        p.fill(ell((216, y + 4), (11, 8)), DOG["white"])
    p.fill(tube([(148, 132), (156, 164)], 9, 9), DOG["collar"], ink_w=1.4)
    dog_head(p, (180, 150), 1.0, "closed", tongue=True)
    p.finish(path)


if __name__ == "__main__":
    for kind, poses in (("cat", (cat_resting, cat_sleeping, cat_alert, cat_stretching)),
                        ("dog", (dog_resting, dog_sleeping, dog_alert, dog_stretching))):
        for paint in poses:
            name = paint.__name__.split("_", 1)[1]
            paint(os.path.join(OUT, kind, name + ".png"))
