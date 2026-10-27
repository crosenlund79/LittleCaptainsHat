"""Paints the harbour illustrations of I021 (A Wider, Warmer World), in the same hand-drawn
ink style as Copenhagen's Nyhavn strip (tools/harbours/paint_copenhagen_landmark.py):
flat colours, a wobbly dark outline, buildings seen across the quay from the boat with
their roofs (or the land behind) receding away from the water.

Every image is a strip of 1150 x 110 scene units at 2 px per unit (2300 x 220 px,
transparent), drawn beyond the guest pontoon by HarbourDressing. The top band (about
y 6..46) is what faces the water; below it, the roofs, hills or cliffs behind.

Two kinds:
  * archetypes (assets/harbours/looks/<id>.png): one per kind of harbour, chosen per
    harbour in data/harbours/harbour_looks.json. Kinds follow what a harbour looks like
    (its buildings, materials, land and climate), never the continent alone.
  * landmarks (assets/harbours/<port>/<name>.png): one place's own view, for the
    special harbours (data/harbours/<port>.tres).

Original drawings; no source artwork is traced or copied. Deterministic (fixed seeds).

Usage: python3 tools/harbours/paint_harbour_looks.py [name ...]   (default: all)
"""
import math
import os
import random
import sys

from PIL import Image, ImageDraw

ROOT = os.path.join(os.path.dirname(__file__), "..", "..")
SS, FINAL = 4, 2
W, H = 1150, 110
INK = (52, 44, 38, 255)
FACADE_H = 46


class Canvas:
    def __init__(self, seed):
        self.img = Image.new("RGBA", (W * SS, H * SS), (0, 0, 0, 0))
        self.d = ImageDraw.Draw(self.img, "RGBA")
        self.rng = random.Random(seed)

    @staticmethod
    def P(x, y):
        return (x * SS, y * SS)

    def wob(self, pts, amp=0.7, closed=True):
        out = []
        pairs = list(zip(pts, pts[1:] + pts[:1])) if closed else list(zip(pts, pts[1:]))
        for (x0, y0), (x1, y1) in pairs:
            n = max(1, int(math.hypot(x1 - x0, y1 - y0) / 6))
            for i in range(n):
                t = i / n
                out.append((x0 + (x1 - x0) * t + self.rng.uniform(-amp, amp), y0 + (y1 - y0) * t + self.rng.uniform(-amp, amp)))
        if not closed:
            out.append(pts[-1])
        return out

    def shape(self, pts, fill, ink=1.4):
        self.d.polygon([self.P(*p) for p in pts], fill=fill + (255,) if len(fill) == 3 else fill)
        if ink > 0:
            path = self.wob(pts)
            self.d.line([self.P(*p) for p in path + path[:1]], fill=INK, width=int(ink * SS), joint="curve")

    def line(self, pts, colour=INK, width=1.0, wobble=True):
        path = self.wob(pts, 0.5, closed=False) if wobble else pts
        self.d.line([self.P(*p) for p in path], fill=colour, width=max(1, int(width * SS)), joint="curve")

    def rect(self, x, y, w, h, fill, ink=1.0):
        self.shape([(x, y), (x + w, y), (x + w, y + h), (x, y + h)], fill, ink)

    def ellipse(self, cx, cy, rx, ry, fill, ink=1.0):
        n = 18
        pts = [(cx + rx * math.cos(2 * math.pi * i / n), cy + ry * math.sin(2 * math.pi * i / n)) for i in range(n)]
        self.shape(pts, fill, ink)

    def window(self, x, y, w=8, h=8, glass=(238, 232, 214), mullion=True, ink=0.8):
        self.rect(x, y, w, h, glass, ink)
        if mullion:
            self.line([(x + w / 2, y), (x + w / 2, y + h)], width=0.5, wobble=False)

    def arch_window(self, x, y, w, h, fill, ink=0.8):
        pts = [(x, y + h), (x, y + w / 2)]
        for i in range(7):
            a = math.pi + math.pi * i / 6
            pts.append((x + w / 2 + w / 2 * math.cos(a), y + w / 2 + w / 2 * math.sin(a)))
        pts += [(x + w, y + h)]
        self.shape(pts, fill, ink)

    def palm_top(self, cx, cy, r, leaf=(92, 128, 70), dark=(64, 96, 52)):
        """A palm seen from above: a star of fronds."""
        n = self.rng.randint(7, 9)
        off = self.rng.uniform(0, math.pi)
        for i in range(n):
            a = off + 2 * math.pi * i / n
            tip = (cx + r * math.cos(a), cy + r * 0.8 * math.sin(a))
            side = 0.28
            left = (cx + r * 0.45 * math.cos(a - side), cy + r * 0.36 * math.sin(a - side))
            right = (cx + r * 0.45 * math.cos(a + side), cy + r * 0.36 * math.sin(a + side))
            self.shape([(cx, cy), left, tip, right], leaf if i % 2 else dark, 0.9)
        self.ellipse(cx, cy, 2.2, 2.0, (110, 84, 56), 0.7)

    def tree_top(self, cx, cy, r, colour=(104, 136, 86)):
        pts = []
        n = 12
        for i in range(n):
            a = 2 * math.pi * i / n
            rr = r * self.rng.uniform(0.82, 1.08)
            pts.append((cx + rr * math.cos(a), cy + rr * 0.85 * math.sin(a)))
        self.shape(pts, colour, 1.0)
        self.ellipse(cx - r * 0.25, cy - r * 0.2, r * 0.35, r * 0.28, tuple(min(255, c + 22) for c in colour), 0)

    def save(self, rel):
        out = os.path.join(ROOT, rel)
        os.makedirs(os.path.dirname(out), exist_ok=True)
        self.img.resize((W * FINAL, H * FINAL), Image.LANCZOS).save(out, optimize=True)
        print("wrote", rel)


def shade(c, k):
    return tuple(max(0, min(255, int(v * k))) for v in c)


# --- Shared pieces ---------------------------------------------------------------------

def gabled_house(c, x, w, facade, roof, top=10, windows=2, door=True, board=False):
    """A pitched-roof house end-on to the quay: a pointed gable facing the water."""
    c.shape([(x, FACADE_H - 2), (x + w, FACADE_H - 2), (x + w - 3, H - 8), (x + 3, H - 8)], roof)
    for k in range(1, 4):
        yy = FACADE_H + k * (H - FACADE_H - 10) / 4
        c.line([(x + 4, yy), (x + w - 4, yy)], (60, 40, 30, 90), 0.6, False)
    c.line([(x + w / 2, FACADE_H), (x + w / 2, H - 9)], (50, 34, 26, 150), 0.9, False)
    pts = [(x, FACADE_H), (x, top + 12), (x + w / 2, top), (x + w, top + 12), (x + w, FACADE_H)]
    c.shape(pts, facade)
    if board:  # vertical boarding of a timber house
        for bx in range(int(x + 5), int(x + w - 2), 5):
            c.line([(bx, top + 12 + abs(bx - x - w / 2) * -0.24 + 2), (bx, FACADE_H - 1)], shade(facade, 0.78) + (200,), 0.5, False)
    cols = windows
    for col in range(cols):
        wx = x + (col + 0.5) * w / cols - 4
        c.window(wx, top + 15, 8, 8)
    c.window(x + w / 2 - 3, top + 4, 6, 5, mullion=False)
    if door:
        dx = x + w * c.rng.uniform(0.3, 0.6)
        c.rect(dx, FACADE_H - 10, 7, 10, shade(facade, 0.45), 0.8)


def flat_house(c, x, w, h_top, wall, roof_band, windows=2, shutters=None, door_colour=(70, 54, 44), arch=False):
    """A flat- or low-roofed rendered house: wall facing the water, roof terrace behind."""
    c.shape([(x, FACADE_H - 2), (x + w, FACADE_H - 2), (x + w - 2, H - 10), (x + 2, H - 10)], roof_band)
    c.shape([(x, FACADE_H), (x, h_top), (x + w, h_top), (x + w, FACADE_H)], wall)
    c.line([(x + 1, h_top + 2), (x + w - 1, h_top + 2)], shade(wall, 0.8) + (200,), 0.6, False)
    for col in range(windows):
        wx = x + (col + 0.5) * w / windows - 3.5
        if arch:
            c.arch_window(wx, h_top + 8, 7, 11, (64, 70, 80))
        else:
            c.window(wx, h_top + 8, 7, 8, (64, 70, 80) if shutters is None else (236, 230, 214))
            if shutters:
                c.rect(wx - 3, h_top + 8, 3, 8, shutters, 0.6)
                c.rect(wx + 7, h_top + 8, 3, 8, shutters, 0.6)
    dx = x + w * c.rng.uniform(0.25, 0.6)
    if arch:
        c.arch_window(dx, FACADE_H - 13, 8, 13, door_colour)
    else:
        c.rect(dx, FACADE_H - 11, 7, 11, door_colour, 0.8)


# --- Archetypes ------------------------------------------------------------------------

def nordic_timber():
    """Painted timber houses and boat sheds (falu red, ochre, white), steep roofs: the
    fishing harbours of Scandinavia and the Faroes, and timber towns elsewhere that look
    the same (Atlantic Canada, New Zealand)."""
    c = Canvas(2101)
    walls = [(156, 52, 42), (214, 168, 72), (236, 230, 214), (156, 52, 42), (110, 132, 120), (196, 112, 60), (236, 230, 214)]
    roofs = [(70, 66, 64), (96, 60, 48), (64, 70, 74), (120, 70, 52)]
    x = 8.0
    i = 0
    while x < W - 70:
        w = c.rng.uniform(52, 78)
        if i % 4 == 3:  # a low boat shed with a big door
            c.shape([(x, FACADE_H - 2), (x + w, FACADE_H - 2), (x + w - 3, H - 14), (x + 3, H - 14)], c.rng.choice(roofs))
            c.shape([(x, FACADE_H), (x, 22), (x + w / 2, 14), (x + w, 22), (x + w, FACADE_H)], (156, 52, 42))
            for bx in range(int(x + 5), int(x + w - 2), 5):
                c.line([(bx, 24), (bx, FACADE_H - 1)], (120, 38, 30, 200), 0.5, False)
            c.rect(x + w * 0.3, 26, w * 0.4, FACADE_H - 26, (90, 40, 34), 0.9)
            c.line([(x + w * 0.5, 26), (x + w * 0.5, FACADE_H)], width=0.6, wobble=False)
        else:
            gabled_house(c, x, w, walls[i % len(walls)], c.rng.choice(roofs), top=c.rng.uniform(6, 12), board=True)
        x += w + c.rng.uniform(4, 16)
        if c.rng.random() < 0.35 and x < W - 90:  # a birch or rowan behind
            c.tree_top(x - 2, H - 22, c.rng.uniform(9, 13), (104, 136, 86))
        i += 1
    c.save("assets/harbours/looks/nordic_timber.png")


def gabled_waterfront():
    """Brick and rendered townhouses with stepped and pointed gables: Danish and German
    harbour towns, the Hanseatic Baltic, the Low Countries, and Dutch-built waterfronts."""
    c = Canvas(2102)
    facades = [(170, 82, 62), (226, 196, 120), (236, 222, 190), (120, 64, 50), (200, 140, 90), (226, 210, 170), (150, 100, 80)]
    roofs = [(150, 72, 52), (120, 64, 50), (90, 92, 96)]
    x = 6.0
    i = 0
    while x < W - 70:
        w = c.rng.uniform(50, 72)
        facade = facades[i % len(facades)]
        c.shape([(x, FACADE_H - 2), (x + w, FACADE_H - 2), (x + w - 4, H - 6), (x + 4, H - 6)], c.rng.choice(roofs))
        for k in range(1, 5):
            yy = FACADE_H + k * (H - FACADE_H - 8) / 5
            c.line([(x + 3, yy), (x + w - 3, yy)], (80, 40, 30, 110), 0.7, False)
        c.line([(x + w / 2, FACADE_H), (x + w / 2, H - 8)], (60, 34, 26, 160), 1.0, False)
        step = i % 3
        if step == 0:
            pts = [(x, FACADE_H), (x, 16), (x + w * 0.2, 16), (x + w * 0.2, 11), (x + w * 0.4, 11), (x + w * 0.4, 6),
                   (x + w * 0.6, 6), (x + w * 0.6, 11), (x + w * 0.8, 11), (x + w * 0.8, 16), (x + w, 16), (x + w, FACADE_H)]
        elif step == 1:
            pts = [(x, FACADE_H), (x, 16), (x + w / 2, 5), (x + w, 16), (x + w, FACADE_H)]
        else:  # a neck gable with a little curved top
            pts = [(x, FACADE_H), (x, 18), (x + w * 0.3, 18), (x + w * 0.3, 9), (x + w * 0.5, 5), (x + w * 0.7, 9),
                   (x + w * 0.7, 18), (x + w, 18), (x + w, FACADE_H)]
        c.shape(pts, facade)
        if facade in ((170, 82, 62), (120, 64, 50), (150, 100, 80)):  # brick courses
            for yy in range(20, FACADE_H - 2, 4):
                c.line([(x + 2, yy), (x + w - 2, yy)], shade(facade, 0.82) + (150,), 0.4, False)
        cols = max(2, int(w / 20))
        for row, wy in enumerate((20, 31)):
            for col in range(cols):
                c.window(x + (col + 0.5) * w / cols - 4, wy, 8, 8)
        dx = x + w * c.rng.uniform(0.3, 0.6)
        c.rect(dx, FACADE_H - 9, 8, 9, (70, 54, 44), 0.8)
        x += w + c.rng.uniform(0, 2)
        i += 1
    c.save("assets/harbours/looks/gabled_waterfront.png")


def atlantic_stone():
    """Grey and sandstone houses with slate roofs and chimneys behind a solid harbour
    wall: the Scottish and Irish coasts, Cornwall and Brittany, Galicia, and old stone
    ports like Hobart's."""
    c = Canvas(2103)
    stones = [(176, 170, 160), (196, 180, 150), (150, 146, 140), (210, 196, 170), (232, 226, 210), (186, 160, 128)]
    slate = [(84, 90, 98), (70, 76, 84), (96, 100, 106)]
    x = 6.0
    i = 0
    while x < W - 80:
        w = c.rng.uniform(64, 96)
        wall = stones[i % len(stones)]
        two = c.rng.random() < 0.6
        top = 10 if two else 22
        c.shape([(x, FACADE_H - 2), (x + w, FACADE_H - 2), (x + w - 2, H - 12), (x + 2, H - 12)], c.rng.choice(slate))
        for k in range(1, 4):
            c.line([(x + 3, FACADE_H + k * 14), (x + w - 3, FACADE_H + k * 14)], (40, 44, 50, 120), 0.6, False)
        c.line([(x + 2, (FACADE_H + H - 12) / 2), (x + w - 2, (FACADE_H + H - 12) / 2)], (40, 44, 50, 200), 1.0, False)
        c.shape([(x, FACADE_H), (x, top), (x + w, top), (x + w, FACADE_H)], wall)
        for _ in range(int(w * (FACADE_H - top) / 70)):  # stonework
            sx = c.rng.uniform(x + 2, x + w - 8)
            sy = c.rng.uniform(top + 2, FACADE_H - 4)
            c.line([(sx, sy), (sx + c.rng.uniform(3, 7), sy)], shade(wall, 0.72) + (150,), 0.5, False)
        for side in (x + 4, x + w - 12):  # gable chimneys
            c.rect(side, top - 7, 8, 7, shade(wall, 0.85), 0.9)
            c.rect(side + 1.5, top - 9, 2, 2, (150, 90, 70), 0.5)
            c.rect(side + 4.5, top - 9, 2, 2, (150, 90, 70), 0.5)
        rows = (top + 6, top + 19) if two else (top + 7,)
        cols = max(2, int(w / 22))
        for wy in rows:
            for col in range(cols):
                c.window(x + (col + 0.5) * w / cols - 4, wy, 8, 9, (226, 224, 214))
        door = c.rng.choice([(46, 72, 96), (140, 50, 44), (60, 96, 74), (230, 200, 90)])
        c.rect(x + w * c.rng.uniform(0.3, 0.55), FACADE_H - 11, 8, 11, door, 0.8)
        x += w + c.rng.uniform(0, 3)
        i += 1
    for bx in range(10, W - 10, 70):  # the harbour wall's capstones in front
        c.rect(bx, FACADE_H - 1, 64, 4, (160, 156, 148), 0.7)
    c.save("assets/harbours/looks/atlantic_stone.png")


def mediterranean():
    """Warm rendered and stone houses with terracotta roofs and shutters, a campanile, a
    pine or two: Italian, French, Spanish, Croatian and Greek mainland harbours, Cyprus
    and the Turkish coast."""
    c = Canvas(2104)
    walls = [(232, 206, 160), (226, 170, 120), (238, 226, 200), (214, 150, 104), (240, 220, 170), (204, 120, 90), (236, 214, 186)]
    shutters = [(70, 110, 90), (90, 120, 150), (120, 80, 60), (70, 110, 90)]
    tile = (184, 98, 66)
    x = 6.0
    i = 0
    while x < W - 70:
        w = c.rng.uniform(46, 70)
        if i == 7:  # a church tower among the houses
            c.shape([(x, FACADE_H - 2), (x + 26, FACADE_H - 2), (x + 26, FACADE_H + 24), (x, FACADE_H + 24)], (184, 98, 66))
            c.line([(x, FACADE_H - 2), (x + 26, FACADE_H + 24)], width=0.8)
            c.line([(x + 26, FACADE_H - 2), (x, FACADE_H + 24)], width=0.8)
            c.shape([(x, FACADE_H), (x, 1), (x + 26, 1), (x + 26, FACADE_H)], (226, 206, 170))
            c.line([(x + 1, 21), (x + 25, 21)], shade((226, 206, 170), 0.8) + (255,), 0.8, False)
            c.arch_window(x + 5, 4, 7, 13, (70, 60, 52))
            c.arch_window(x + 14, 4, 7, 13, (70, 60, 52))
            c.ellipse(x + 13, 30, 5, 5, (238, 232, 214), 0.8)
            c.line([(x + 13, 30), (x + 13, 26.5)], width=0.6, wobble=False)
            c.line([(x + 13, 30), (x + 15.5, 31)], width=0.6, wobble=False)
            x += 34
        top = c.rng.uniform(8, 16)
        c.shape([(x, FACADE_H - 2), (x + w, FACADE_H - 2), (x + w - 2, H - 10), (x + 2, H - 10)], tile)
        for k in range(1, 6):
            yy = FACADE_H + k * (H - FACADE_H - 12) / 6
            c.line([(x + 3, yy), (x + w - 3, yy)], (130, 60, 40, 120), 0.6, False)
        c.line([(x + w / 2, FACADE_H), (x + w / 2, H - 11)], (120, 56, 36, 170), 0.9, False)
        c.shape([(x, FACADE_H), (x, top), (x + w, top), (x + w, FACADE_H)], walls[i % len(walls)])
        c.line([(x, top + 1.5), (x + w, top + 1.5)], tile + (255,), 1.6, False)
        sh = shutters[i % len(shutters)]
        cols = max(2, int(w / 18))
        for wy in (top + 7, top + 19):
            if wy > FACADE_H - 12:
                continue
            for col in range(cols):
                wx = x + (col + 0.5) * w / cols - 3
                c.rect(wx - 2.5, wy, 2.5, 8, sh, 0.5)
                c.rect(wx + 6, wy, 2.5, 8, sh, 0.5)
                c.rect(wx, wy, 6, 8, (60, 58, 60), 0.6)
        c.rect(x + w * c.rng.uniform(0.25, 0.55), FACADE_H - 11, 7, 11, (110, 76, 56), 0.8)
        x += w + c.rng.uniform(0, 3)
        if c.rng.random() < 0.25 and x < W - 80:  # an umbrella pine behind
            c.tree_top(x, H - 18, 12, (88, 116, 72))
        i += 1
    c.save("assets/harbours/looks/mediterranean.png")


def aegean_island():
    """Whitewashed cube houses with blue doors and shutters, flat roofs, a chapel dome and
    a bougainvillea: the Cyclades and the smaller Greek islands."""
    c = Canvas(2105)
    blue = (54, 104, 160)
    for hx in range(-20, W + 40, 90):  # dry, terraced hills behind
        c.ellipse(hx + c.rng.uniform(-10, 10), H - 14, c.rng.uniform(56, 74), 26, (204, 186, 146), 1.0)
        for k in range(3):
            c.line([(hx - 40, H - 30 + k * 9), (hx + 40, H - 30 + k * 9)], (170, 150, 112, 140), 0.6)
    x = 8.0
    i = 0
    while x < W - 60:
        w = c.rng.uniform(34, 56)
        top = c.rng.choice((12, 18, 24))
        if i % 6 == 4:  # a chapel with its blue dome
            c.shape([(x, FACADE_H - 2), (x + 36, FACADE_H - 2), (x + 34, H - 30), (x + 2, H - 30)], (244, 242, 236))
            c.ellipse(x + 18, H - 46, 12, 10, blue, 1.1)
            c.line([(x + 18, H - 58), (x + 18, H - 63)], width=0.9)
            c.line([(x + 15.5, H - 61), (x + 20.5, H - 61)], width=0.9)
            c.shape([(x, FACADE_H), (x, 14), (x + 36, 14), (x + 36, FACADE_H)], (246, 244, 238))
            c.arch_window(x + 6, 20, 7, 10, blue)
            c.arch_window(x + 23, 20, 7, 10, blue)
            c.arch_window(x + 14, FACADE_H - 15, 8, 15, (110, 76, 56))
            x += 44
            i += 1
            continue
        depth = c.rng.uniform(22, 40)
        c.shape([(x, FACADE_H - 2), (x + w, FACADE_H - 2), (x + w - 1, FACADE_H + depth), (x + 1, FACADE_H + depth)], (236, 234, 228))
        c.shape([(x + 3, FACADE_H + 2), (x + w - 3, FACADE_H + 2), (x + w - 4, FACADE_H + depth - 4), (x + 4, FACADE_H + depth - 4)], (222, 220, 212), 0.6)
        if c.rng.random() < 0.4:  # a little stair or water tank on the roof
            c.rect(x + w * 0.6, FACADE_H + 6, 7, 6, (200, 198, 190), 0.6)
        c.shape([(x, FACADE_H), (x, top), (x + w, top), (x + w, FACADE_H)], (246, 244, 238))
        c.line([(x + 1, top + 1.2), (x + w - 1, top + 1.2)], (210, 208, 200, 220), 0.8, False)
        accent = blue if i % 3 else (64, 132, 120)
        for col in range(max(1, int(w / 20))):
            wx = x + (col + 0.5) * w / max(1, int(w / 20)) - 3.5
            c.rect(wx, top + 6, 7, 8, accent, 0.7)
        c.rect(x + w * c.rng.uniform(0.25, 0.6), FACADE_H - 12, 7, 12, accent, 0.8)
        if c.rng.random() < 0.3:  # bougainvillea over a door
            c.ellipse(x + w * 0.2, top + 2, 6, 4, (196, 60, 120), 0.7)
        x += w + c.rng.uniform(1, 6)
        i += 1
    c.save("assets/harbours/looks/aegean_island.png")


def stone_town():
    """Lime-washed and sand masonry with arched doors, roof terraces, a crenellated sea
    wall and a minaret: the Moroccan coast, and the coral-stone towns of the Swahili
    coast such as Zanzibar."""
    c = Canvas(2106)
    walls = [(232, 218, 190), (214, 186, 140), (240, 234, 222), (222, 196, 156)]
    blue = (40, 92, 150)
    x = 6.0
    i = 0
    while x < W - 60:
        w = c.rng.uniform(44, 70)
        if i == 9:  # a square minaret
            c.shape([(x, FACADE_H), (x, 0), (x + 18, 0), (x + 18, FACADE_H)], (226, 204, 160))
            for k in range(3):
                c.rect(x + 2 + k * 5.5, 0, 3.5, 3, (64, 128, 104), 0.5)
            c.arch_window(x + 5, 10, 8, 12, (70, 60, 52))
            c.rect(x + 3, 28, 12, 3, (64, 128, 104), 0.6)
            x += 24
        flat_house(c, x, w, c.rng.uniform(8, 20), walls[i % len(walls)], (226, 214, 190), windows=max(1, int(w / 26)),
                   door_colour=blue if i % 2 else (110, 70, 44), arch=True)
        c.shape([(x + 3, FACADE_H + 2), (x + w - 3, FACADE_H + 2), (x + w - 5, H - 14), (x + 5, H - 14)], (238, 230, 212), 0.7)
        if c.rng.random() < 0.5:  # a stair hut on the roof terrace
            hx = x + c.rng.uniform(6, w - 18)
            c.rect(hx, FACADE_H + 10, 12, 10, walls[(i + 1) % len(walls)], 0.8)
            c.arch_window(hx + 3, FACADE_H + 12, 6, 8, (70, 60, 52))
        if c.rng.random() < 0.35:  # a line of washing
            wy = c.rng.uniform(FACADE_H + 24, H - 22)
            c.line([(x + 6, wy), (x + w - 6, wy)], (120, 110, 100, 255), 0.5, False)
            for k in range(3):
                c.rect(x + 10 + k * 9, wy, 5, 6, c.rng.choice([(200, 70, 60), (240, 236, 226), (60, 110, 170)]), 0.4)
        x += w + c.rng.uniform(0, 2)
        i += 1
    for mx in range(4, W - 10, 9):  # the sea wall's crenellations at the water
        c.rect(mx, FACADE_H - 4, 5, 4, (200, 176, 132), 0.6)
    c.save("assets/harbours/looks/stone_town.png")


def tropical_town():
    """Low rendered and timber houses in bright colours, corrugated roofs, verandas,
    palms and mango trees, painted wooden boats: Caribbean, West African, Indian Ocean
    and Central American harbour towns."""
    c = Canvas(2107)
    walls = [(232, 200, 90), (110, 180, 170), (226, 126, 100), (236, 230, 214), (150, 190, 110), (230, 160, 180), (120, 150, 200)]
    tin = [(150, 150, 146), (176, 90, 60), (110, 130, 120), (160, 164, 160)]
    x = 10.0
    i = 0
    while x < W - 70:
        w = c.rng.uniform(46, 70)
        top = c.rng.uniform(12, 20)
        roof = c.rng.choice(tin)
        c.shape([(x - 3, FACADE_H - 2), (x + w + 3, FACADE_H - 2), (x + w, H - 18), (x, H - 18)], roof)
        for k in range(int(w / 5)):  # corrugations
            c.line([(x + 2 + k * 5, FACADE_H), (x + 2 + k * 5, H - 19)], shade(roof, 0.82) + (170,), 0.5, False)
        c.shape([(x, FACADE_H), (x, top), (x + w, top), (x + w, FACADE_H)], walls[i % len(walls)])
        c.shape([(x - 3, top + 14), (x + w + 3, top + 14), (x + w + 3, top + 18), (x - 3, top + 18)], shade(roof, 1.08), 0.8)  # veranda roof
        for px in (x + 2, x + w - 4):
            c.rect(px, top + 18, 2, FACADE_H - top - 18, (236, 230, 214), 0.5)
        for col in range(max(1, int(w / 22))):
            wx = x + (col + 0.5) * w / max(1, int(w / 22)) - 4
            c.rect(wx, top + 4, 8, 8, (60, 70, 70), 0.7)
            c.rect(wx - 2, top + 4, 2, 8, (236, 230, 214), 0.5)
            c.rect(wx + 8, top + 4, 2, 8, (236, 230, 214), 0.5)
        c.rect(x + w * 0.45, FACADE_H - 11, 7, 11, (90, 70, 54), 0.8)
        x += w + c.rng.uniform(8, 18)
        if c.rng.random() < 0.6:
            c.palm_top(x - 6, H - 30 - c.rng.uniform(0, 16), c.rng.uniform(19, 25))
        elif c.rng.random() < 0.5:
            c.tree_top(x - 6, H - 28, 17, (78, 120, 66))
        i += 1
    c.save("assets/harbours/looks/tropical_town.png")


def tropical_island():
    """Small timber and thatched buildings among palms on a beach, a lagoon-side wharf:
    the islands of Polynesia, Fiji, Tonga and the Cook Islands, and quiet tropical
    island anchorages."""
    c = Canvas(2108)
    thatch = (196, 164, 104)
    x = 10.0
    i = 0
    c.shape([(0, FACADE_H - 4), (W, FACADE_H - 4), (W, H - 2), (0, H - 2)], (226, 210, 166), 0)  # sand and land
    for gx in range(0, W, 26):
        c.ellipse(gx + c.rng.uniform(0, 10), H - c.rng.uniform(6, 30), c.rng.uniform(16, 26), c.rng.uniform(7, 10), (118, 150, 84), 0)
    while x < W - 60:
        if i % 3 == 1:
            w = c.rng.uniform(36, 48)
            c.shape([(x - 5, FACADE_H - 4), (x + w + 5, FACADE_H - 4), (x + w + 5, FACADE_H + 30), (x - 5, FACADE_H + 30)], thatch)
            c.line([(x - 5, FACADE_H - 4), (x + 8, FACADE_H + 13)], (150, 120, 70, 255), 0.9)
            c.line([(x + w + 5, FACADE_H - 4), (x + w - 8, FACADE_H + 13)], (150, 120, 70, 255), 0.9)
            c.line([(x - 5, FACADE_H + 30), (x + 8, FACADE_H + 13)], (150, 120, 70, 255), 0.9)
            c.line([(x + w + 5, FACADE_H + 30), (x + w - 8, FACADE_H + 13)], (150, 120, 70, 255), 0.9)
            c.line([(x + 8, FACADE_H + 13), (x + w - 8, FACADE_H + 13)], (130, 100, 60, 255), 1.1)
            for k in range(14):
                tx = x - 3 + k * (w + 6) / 14
                c.line([(tx, FACADE_H - 2), (tx + 2, FACADE_H + 4)], (160, 128, 80, 160), 0.5, False)
            c.shape([(x, FACADE_H), (x, 22), (x + w / 2, 12), (x + w, 22), (x + w, FACADE_H)], (176, 130, 84))
            for bx in range(int(x + 3), int(x + w - 1), 4):
                c.line([(bx, 22), (bx, FACADE_H - 1)], (140, 100, 62, 200), 0.5, False)
            c.rect(x + w / 2 - 4, FACADE_H - 12, 8, 12, (90, 64, 44), 0.8)
        else:
            w = c.rng.uniform(40, 56)
            col = c.rng.choice([(236, 230, 214), (190, 220, 210), (240, 210, 170), (214, 230, 190)])
            c.shape([(x - 2, FACADE_H - 3), (x + w + 2, FACADE_H - 3), (x + w, H - 30), (x, H - 30)], (160, 70, 56))
            c.shape([(x, FACADE_H), (x, 18), (x + w, 18), (x + w, FACADE_H)], col)
            c.rect(x + 5, 24, 8, 8, (60, 70, 70), 0.7)
            c.rect(x + w - 13, 24, 8, 8, (60, 70, 70), 0.7)
            c.rect(x + w / 2 - 3.5, FACADE_H - 11, 7, 11, (110, 76, 56), 0.8)
        x += w + c.rng.uniform(14, 30)
        for _ in range(c.rng.randint(1, 2)):
            c.palm_top(x - c.rng.uniform(4, 12), H - c.rng.uniform(10, 40), c.rng.uniform(14, 19))
        i += 1
    c.save("assets/harbours/looks/tropical_island.png")


def volcanic_island():
    """Dark lava rock and cliffs, a few white houses with red roofs and a white church:
    the Azores, Madeira's and the Canaries' rugged harbours, the Galápagos, the
    Marquesas and lonely ocean islands."""
    c = Canvas(2109)
    rock = (72, 66, 64)
    green = (96, 124, 78)
    # cliffs and green slopes behind
    pts = [(0, H)]
    xx = 0
    while xx < W:
        pts.append((xx, c.rng.uniform(2, 30)))
        xx += c.rng.uniform(40, 90)
    pts += [(W, c.rng.uniform(4, 24)), (W, H)]
    c.shape(pts, green, 1.4)
    for k in range(40):
        gx = c.rng.uniform(0, W)
        c.line([(gx, c.rng.uniform(34, 70)), (gx + c.rng.uniform(-20, 20), H - 2)], (70, 96, 60, 150), 0.6, False)
    for k in range(14):  # dark rock ledges showing through the green slopes
        rx = c.rng.uniform(10, W - 50)
        ry = c.rng.uniform(FACADE_H + 6, H - 16)
        rw = c.rng.uniform(22, 50)
        c.shape([(rx, ry), (rx + rw * 0.3, ry - 5), (rx + rw, ry - 2), (rx + rw * 0.8, ry + 5), (rx + rw * 0.2, ry + 4)], rock, 1.0)
    x = 60.0
    i = 0
    while x < W - 80:
        if c.rng.random() < 0.45:
            x += c.rng.uniform(40, 90)
            continue
        w = c.rng.uniform(30, 46)
        if i == 2:  # a white church with black basalt trim
            c.shape([(x, FACADE_H - 2), (x + 40, FACADE_H - 2), (x + 38, H - 34), (x + 2, H - 34)], (176, 84, 62))
            c.shape([(x, FACADE_H), (x, 12), (x + 40, 12), (x + 40, FACADE_H)], (246, 244, 238))
            c.shape([(x + 14, 12), (x + 14, 0), (x + 26, 0), (x + 26, 12)], (246, 244, 238))
            for edge in (x, x + 38):
                c.rect(edge, 12, 2, FACADE_H - 12, (50, 48, 48), 0.5)
            c.arch_window(x + 16, 2, 8, 9, (50, 48, 48))
            c.arch_window(x + 16, FACADE_H - 14, 8, 14, (110, 76, 56))
            x += 50
            i += 1
            continue
        c.shape([(x, FACADE_H - 2), (x + w, FACADE_H - 2), (x + w - 2, H - 40), (x + 2, H - 40)], (176, 84, 62))
        for k in range(1, 3):
            c.line([(x + 3, FACADE_H + k * 7), (x + w - 3, FACADE_H + k * 7)], (130, 60, 44, 140), 0.6, False)
        c.shape([(x, FACADE_H), (x, 18), (x + w, 18), (x + w, FACADE_H)], (244, 242, 236))
        c.rect(x, 18, w, 2.5, (50, 48, 48), 0.4)
        c.rect(x + 5, 24, 7, 8, (60, 90, 110), 0.7)
        c.rect(x + w - 12, 24, 7, 8, (60, 90, 110), 0.7)
        c.rect(x + w / 2 - 3.5, FACADE_H - 11, 7, 11, (60, 90, 110), 0.8)
        x += w + c.rng.uniform(6, 30)
        i += 1
    for bx in range(0, W, 46):  # black basalt quay blocks
        c.rect(bx, FACADE_H - 1, 42, 5, (60, 58, 58), 0.6)
    c.save("assets/harbours/looks/volcanic_island.png")


# --- Landmarks of the special harbours --------------------------------------------------

def valletta_bastions():
    """Valletta: the honey limestone bastion wall straight out of Grand Harbour, with
    its angled bastions and a stone sentry box (gardjola), and behind it the city seen
    from the water: flat-roofed limestone blocks, bright closed timber balconies
    (gallariji) along their fronts, the great dome of the Carmelite church and the
    spire of St Paul's."""
    c = Canvas(1566)  # the year Valletta was founded
    stone = (222, 190, 130)
    # the city behind the wall: flat-roofed blocks (seen from above), balconies at their front edge
    balconies = [(40, 120, 70), (40, 80, 150), (180, 50, 40), (230, 190, 70), (40, 120, 70), (120, 60, 110)]
    x = 2.0
    i = 0
    while x < W - 20:
        w = c.rng.uniform(44, 70)
        roof = shade(stone, c.rng.uniform(0.9, 1.05))
        c.shape([(x, 40), (x + w, 40), (x + w, H - 4), (x, H - 4)], roof, 1.1)
        c.shape([(x + 3, 44), (x + w - 3, 44), (x + w - 3, H - 8), (x + 3, H - 8)], shade(roof, 0.94), 0.5)
        for k in range(max(1, int(w / 28))):  # balconies over the street edge
            bx = x + 6 + k * 26
            c.rect(bx, 40, 15, 7, balconies[(i + k) % len(balconies)], 0.8)
            c.line([(bx + 5, 40), (bx + 5, 47)], width=0.4, wobble=False)
            c.line([(bx + 10, 40), (bx + 10, 47)], width=0.4, wobble=False)
        if c.rng.random() < 0.4:  # a roof stair hut
            c.rect(x + w * 0.5, 66, 12, 9, shade(stone, 1.08), 0.7)
        x += w + 1.5
        i += 1
    for cx, r in ((430, 26), (980, 14)):  # the Carmelite dome and a smaller one
        c.ellipse(cx, H - 36, r, r * 0.95, (176, 160, 140), 1.4)
        for k in range(8):
            a = 2 * math.pi * k / 8
            c.line([(cx + r * 0.35 * math.cos(a), H - 36 + r * 0.35 * math.sin(a)), (cx + r * math.cos(a), H - 36 + r * 0.95 * math.sin(a))], (120, 106, 92, 200), 0.6, False)
        c.ellipse(cx, H - 36, r * 0.32, r * 0.3, (214, 196, 160), 0.9)
    c.shape([(760, H - 24), (772, H - 24), (772, H - 60), (766, H - 74), (760, H - 60)], (214, 186, 132), 1.2)  # the spire
    # the bastion wall facing the harbour, drawn last so it stands in front
    c.shape([(0, 38), (0, 8), (W, 8), (W, 38)], stone, 1.6)
    for yy in range(12, 37, 5):  # coursed ashlar
        c.line([(2, yy), (W - 2, yy)], shade(stone, 0.84) + (170,), 0.5, False)
    for k, yy in enumerate(range(12, 37, 5)):
        for xx in range(8 + (k % 2) * 10, W - 4, 20):
            c.line([(xx, yy), (xx, yy + 5)], shade(stone, 0.84) + (140,), 0.4, False)
    for bx in (140, 470, 820):  # angled bastions jutting towards the water
        c.shape([(bx - 50, 38), (bx - 30, 2), (bx + 30, 2), (bx + 50, 38)], shade(stone, 1.05), 1.4)
        for yy in range(6, 37, 5):
            c.line([(bx - 46 + (38 - yy) * 0.1, yy), (bx + 46 - (38 - yy) * 0.1, yy)], shade(stone, 0.86) + (150,), 0.5, False)
        c.rect(bx + 22, 0, 11, 9, shade(stone, 1.1), 0.9)  # gardjola
        c.shape([(bx + 22, 0), (bx + 27.5, -4), (bx + 33, 0)], shade(stone, 1.1), 0.8)
        c.ellipse(bx + 27.5, 4.5, 2.2, 1.6, (60, 50, 44), 0.4)
    c.save("assets/harbours/valletta/grand_harbour.png")


def symi_harbour():
    """Symi: tiers of neoclassical houses in ochre, rose and cream with pediments and
    tiled roofs, rising from the harbour of Gialos, a clock tower at the water."""
    c = Canvas(1881)  # the clock tower's year
    walls = [(236, 200, 140), (230, 170, 150), (240, 226, 196), (214, 150, 110), (226, 210, 160), (196, 170, 200), (240, 214, 170)]
    tile = (178, 90, 62)
    for tier, (y0, scale) in enumerate(((52, 0.6), (30, 0.8), (0, 1.0))):
        x = 8.0 + tier * 13
        i = tier * 3
        while x < W - 40:
            w = c.rng.uniform(34, 48) * scale + 6
            top = y0 + 10 * scale
            base = y0 + 40 * scale
            c.shape([(x, base - 1), (x + w, base - 1), (x + w - 2, min(H - 2, base + 7 * scale)), (x + 2, min(H - 2, base + 7 * scale))], tile)
            c.shape([(x, base), (x, top), (x + w / 2, top - 7 * scale), (x + w, top), (x + w, base)], walls[i % len(walls)])
            c.line([(x + 2, top), (x + w - 2, top)], (236, 232, 222, 255), 1.0, False)
            c.ellipse(x + w / 2, top - 2.5 * scale, 2.2 * scale, 1.6 * scale, (236, 232, 222), 0.4)
            n = max(2, int(w / 14))
            for col in range(n):
                wx = x + (col + 0.5) * w / n - 2.8 * scale
                c.rect(wx, top + 6 * scale, 5.6 * scale, 10 * scale, (70, 110, 120), 0.5)
            x += w + c.rng.uniform(1, 5)
            i += 1
    c.rect(560, 0, 18, FACADE_H, (236, 222, 190), 1.2)  # the clock tower
    c.ellipse(569, 10, 5, 5, (246, 244, 238), 0.8)
    c.line([(569, 10), (569, 7)], width=0.6, wobble=False)
    c.line([(569, 10), (571.5, 10)], width=0.6, wobble=False)
    c.shape([(558, 0), (569, -6), (580, 0)], tile, 1.0)
    c.save("assets/harbours/symi/gialos.png")


def essaouira_skala():
    """Essaouira: the Skala, the old sea bastion with its row of cannon embrasures,
    white houses with blue shutters behind, and the harbour's blue fishing boats."""
    c = Canvas(1765)
    stone = (196, 170, 128)
    c.shape([(0, FACADE_H + 4), (0, 18), (W, 18), (W, FACADE_H + 4)], stone, 1.6)
    for yy in range(22, FACADE_H, 6):
        c.line([(2, yy), (W - 2, yy)], shade(stone, 0.82) + (150,), 0.5, False)
    for mx in range(4, W - 10, 14):  # merlons and embrasures
        c.rect(mx, 10, 9, 8, shade(stone, 1.06), 0.8)
    for gx in range(30, W - 30, 70):  # cannon in the embrasures
        c.rect(gx, 20, 14, 5, (70, 70, 72), 0.8)
        c.ellipse(gx + 14, 22.5, 2.5, 2.5, (50, 50, 52), 0.6)
    c.shape([(870, FACADE_H + 4), (870, 4), (940, 4), (940, FACADE_H + 4)], shade(stone, 1.04), 1.4)  # the north bastion tower
    for mx in range(872, 936, 9):
        c.rect(mx, 0, 6, 5, shade(stone, 1.1), 0.6)
    for yy in range(10, FACADE_H, 6):
        c.line([(872, yy), (938, yy)], shade(stone, 0.82) + (150,), 0.5, False)
    c.arch_window(898, 22, 14, FACADE_H - 18, (90, 70, 50))
    x = 8.0
    while x < W - 40:  # the medina behind: white roof terraces with parapets, stair huts, a blue door or two
        w = c.rng.uniform(30, 50)
        y0 = c.rng.uniform(50, 56)
        c.shape([(x, y0), (x + w, y0), (x + w, H - 4), (x, H - 4)], (240, 236, 226), 1.0)
        c.shape([(x + 3, y0 + 3), (x + w - 3, y0 + 3), (x + w - 3, H - 7), (x + 3, H - 7)], (228, 222, 208), 0.5)
        if c.rng.random() < 0.5:
            hx = x + c.rng.uniform(5, w - 16)
            c.rect(hx, y0 + 12, 11, 9, (240, 236, 226), 0.7)
            c.rect(hx + 3, y0 + 15, 4, 6, (40, 92, 150), 0.5)
        x += w + c.rng.uniform(1, 3)
    c.save("assets/harbours/essaouira/skala.png")


def lunenburg_waterfront():
    """Lunenburg: the red wooden waterfront buildings of the old fishing town, wharves
    in front, and the brightly painted houses climbing the hill behind."""
    c = Canvas(1753)  # the town's founding
    red = (170, 46, 40)
    x = 10.0
    i = 0
    while x < W - 80:  # big red waterfront buildings with white trim
        w = c.rng.uniform(80, 120)
        c.shape([(x, FACADE_H - 2), (x + w, FACADE_H - 2), (x + w - 3, 70), (x + 3, 70)], (70, 66, 64))
        c.shape([(x, FACADE_H), (x, 18), (x + w / 2, 4), (x + w, 18), (x + w, FACADE_H)], red)
        for bx in range(int(x + 5), int(x + w - 2), 5):
            c.line([(bx, 18), (bx, FACADE_H - 1)], (130, 34, 30, 200), 0.5, False)
        c.line([(x, 18), (x + w / 2, 4), (x + w, 18)], (240, 236, 226, 255), 1.4, False)
        for col in range(int(w / 24)):
            c.window(x + (col + 0.5) * w / int(w / 24) - 4, 22, 8, 9)
        c.rect(x + w / 2 - 9, 32, 18, FACADE_H - 32, (240, 236, 226), 0.9)
        x += w + c.rng.uniform(16, 30)
        i += 1
    houses = [(230, 190, 70), (60, 110, 170), (120, 170, 120), (230, 230, 220), (200, 90, 140), (90, 160, 170)]
    x = 6.0
    i = 0
    while x < W - 30:  # the painted houses up the hill
        w = c.rng.uniform(26, 36)
        y = 74 + c.rng.uniform(-4, 4)
        c.shape([(x, y + 26), (x, y + 6), (x + w / 2, y), (x + w, y + 6), (x + w, y + 26)], houses[i % len(houses)], 1.0)
        c.rect(x + 4, y + 10, 5, 5, (236, 232, 214), 0.5)
        c.rect(x + w - 9, y + 10, 5, 5, (236, 232, 214), 0.5)
        x += w + c.rng.uniform(2, 8)
        i += 1
    c.save("assets/harbours/lunenburg/waterfront.png")


def st_helena_jamestown():
    """Jamestown, St Helena: one street of Georgian houses squeezed into a narrow valley
    between steep, dark volcanic cliffs, the long stair of Jacob's Ladder up the side."""
    c = Canvas(1659)
    cliff = (86, 76, 70)
    # the two cliffs, with the valley between
    c.shape([(0, 0), (430, 0), (470, FACADE_H + 4), (470, H), (0, H)], cliff, 1.6)
    c.shape([(W, 0), (700, 0), (660, FACADE_H + 4), (660, H), (W, H)], cliff, 1.6)
    for k in range(60):
        side = c.rng.random() < 0.5
        x0 = c.rng.uniform(20, 420) if side else c.rng.uniform(710, W - 20)
        y0 = c.rng.uniform(4, H - 10)
        c.line([(x0, y0), (x0 + c.rng.uniform(-14, 14), y0 + c.rng.uniform(6, 16))], (60, 54, 50, 170), 0.7, False)
    for k in range(26):  # scrub and green ledges clinging to the cliffs
        side = c.rng.random() < 0.5
        gx = c.rng.uniform(30, 400) if side else c.rng.uniform(730, W - 30)
        c.ellipse(gx, c.rng.uniform(8, H - 10), c.rng.uniform(8, 18), c.rng.uniform(3, 5), (104, 120, 82), 0.7)
    c.line([(470, FACADE_H - 4), (360, 0)], (230, 226, 210, 255), 1.4, False)  # Jacob's Ladder
    for k in range(18):
        t = k / 18
        px, py = 470 - 110 * t, FACADE_H - 4 - (FACADE_H - 4) * t
        c.line([(px - 2, py), (px + 2, py)], (230, 226, 210, 255), 0.6, False)
    walls = [(236, 230, 214), (226, 196, 140), (200, 214, 200), (236, 210, 190), (220, 220, 210)]
    x = 474.0
    i = 0
    while x < 650:
        w = c.rng.uniform(26, 36)
        c.shape([(x, FACADE_H - 2), (x + w, FACADE_H - 2), (x + w - 2, H - 12), (x + 2, H - 12)], (90, 96, 104))
        c.shape([(x, FACADE_H), (x, 12), (x + w, 12), (x + w, FACADE_H)], walls[i % len(walls)])
        for wy in (17, 29):
            c.window(x + 4, wy, 6, 7)
            c.window(x + w - 10, wy, 6, 7)
        c.rect(x + w / 2 - 3, FACADE_H - 10, 6, 10, (70, 90, 70), 0.7)
        x += w + 1
        i += 1
    c.rect(476, 0, 14, 12, (236, 230, 214), 0.9)  # the church tower
    c.shape([(476, 0), (483, -5), (490, 0)], (90, 96, 104), 0.8)
    c.rect(0, FACADE_H, W, 4, (70, 66, 64), 0.6)  # the sea wall
    c.save("assets/harbours/st_helena/jamestown.png")


ALL = {f.__name__: f for f in (nordic_timber, gabled_waterfront, atlantic_stone, mediterranean, aegean_island, stone_town,
                               tropical_town, tropical_island, volcanic_island, valletta_bastions, symi_harbour,
                               essaouira_skala, lunenburg_waterfront, st_helena_jamestown)}

if __name__ == "__main__":
    for name in sys.argv[1:] or ALL:
        ALL[name]()
