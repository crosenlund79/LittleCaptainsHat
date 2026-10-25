"""Paints Copenhagen's landmark illustration for the harbour prototype
(Visual Identity V01): a row of Nyhavn-style gabled harbour houses in their
famous ochre, red, blue and cream, seen across the quay from the boat, with
tiled roofs behind. A simplified, hand-drawn stand-in for the owner's own art.

Usage: python3 tools/harbours/paint_copenhagen_landmark.py

Writes assets/harbours/copenhagen/nyhavn.png (2 px per scene unit, 1150 x 110
units, transparent background). data/harbours/copenhagen.tres places it.
"""
import math
import os
import random

from PIL import Image, ImageDraw

ROOT = os.path.join(os.path.dirname(__file__), "..", "..")
OUT = os.path.join(ROOT, "assets", "harbours", "copenhagen", "nyhavn.png")
SS, FINAL = 4, 2
W_UNITS, H_UNITS = 1150, 110
INK = (52, 44, 38, 255)
FACADES = [(214, 168, 72), (190, 82, 62), (90, 130, 160), (236, 222, 190), (214, 120, 70), (120, 150, 110),
           (226, 196, 96), (170, 70, 70), (70, 110, 140), (230, 210, 170), (200, 140, 90)]
ROOFS = [(150, 72, 52), (120, 64, 50), (90, 92, 96), (140, 80, 60)]
FACADE_H = 46

random.seed(1673)  # the year Nyhavn was dug
img = Image.new("RGBA", (W_UNITS * SS, H_UNITS * SS), (0, 0, 0, 0))
d = ImageDraw.Draw(img, "RGBA")


def P(x, y):
    return (x * SS, y * SS)


def wob(pts, amp=0.7):
    out = []
    for (x0, y0), (x1, y1) in zip(pts, pts[1:] + pts[:1]):
        n = max(1, int(math.hypot(x1 - x0, y1 - y0) / 6))
        for i in range(n):
            t = i / n
            out.append((x0 + (x1 - x0) * t + random.uniform(-amp, amp), y0 + (y1 - y0) * t + random.uniform(-amp, amp)))
    return out


def shape(pts, fill, ink=1.4):
    d.polygon([P(*p) for p in pts], fill=fill + (255,) if len(fill) == 3 else fill)
    path = wob(pts)
    d.line([P(*p) for p in path + path[:1]], fill=INK, width=int(ink * SS), joint="curve")


x = 6.0
i = 0
while x < W_UNITS - 60:
    w = random.uniform(58, 86)
    facade = FACADES[i % len(FACADES)]
    roof = random.choice(ROOFS)
    # Roof behind the facade (seen from above): ridge line along the house.
    roof_pts = [(x, FACADE_H - 2), (x + w, FACADE_H - 2), (x + w - 4, H_UNITS - 6), (x + 4, H_UNITS - 6)]
    shape(roof_pts, roof)
    for k in range(1, 5):
        yy = FACADE_H + k * (H_UNITS - FACADE_H - 8) / 5
        d.line([P(x + 3, yy), P(x + w - 3, yy)], fill=(80, 40, 30, 110), width=int(0.7 * SS))
    d.line([P(x + w / 2, FACADE_H), P(x + w / 2, H_UNITS - 8)], fill=(60, 34, 26, 160), width=int(1.0 * SS))
    if random.random() < 0.5:  # a chimney
        cx = x + random.uniform(10, w - 18)
        shape([(cx, FACADE_H + 14), (cx + 9, FACADE_H + 14), (cx + 9, FACADE_H + 26), (cx, FACADE_H + 26)], (110, 70, 56), 1.0)
    # The facade facing the water, with a stepped or pointed gable.
    gable = random.choice(("step", "point", "flat"))
    top = 6 if gable != "flat" else 12
    pts = [(x, FACADE_H), (x, 14)]
    if gable == "point":
        pts += [(x + w / 2, top)]
    elif gable == "step":
        pts += [(x + w * 0.2, 14), (x + w * 0.2, 9), (x + w * 0.4, 9), (x + w * 0.4, top), (x + w * 0.6, top),
                (x + w * 0.6, 9), (x + w * 0.8, 9), (x + w * 0.8, 14)]
    pts += [(x + w, 14), (x + w, FACADE_H)]
    shape(pts, facade)
    # Windows in two rows and a door at the quay.
    cols = max(2, int(w / 20))
    for row, wy in enumerate((18, 30)):
        for c in range(cols):
            wx = x + (c + 0.5) * w / cols - 4
            shape([(wx, wy), (wx + 8, wy), (wx + 8, wy + 8), (wx, wy + 8)], (238, 232, 214), 0.8)
            d.line([P(wx + 4, wy), P(wx + 4, wy + 8)], fill=INK, width=int(0.5 * SS))
    dx = x + w * random.uniform(0.3, 0.6)
    shape([(dx, FACADE_H - 9), (dx + 8, FACADE_H - 9), (dx + 8, FACADE_H), (dx, FACADE_H)], (70, 54, 44), 0.8)
    x += w + random.uniform(0, 2)
    i += 1

os.makedirs(os.path.dirname(OUT), exist_ok=True)
img.resize((W_UNITS * FINAL, H_UNITS * FINAL), Image.LANCZOS).save(OUT, optimize=True)
print("wrote", os.path.relpath(OUT, ROOT))
