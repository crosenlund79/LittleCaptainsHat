"""Draws the demo sprite for the Starling 33's Coachroof slot.

A stand-in for real hand-drawn art: wobbly ink outline, a slightly uneven
wash of colour and a little hatching, on a transparent full-canvas PNG
(2240 x 800 = the deck canvas Rect2(-560, -200, 1120, 400) at 2x). It shows
that a sprite dropped into a slot replaces the procedural art without
touching collision or interactions.

    python3 tools/vessels/make_demo_coachroof.py
writes assets/vessels/starling_33/demo/deck/coachroof.png
"""
import os
import random

from PIL import Image, ImageDraw, ImageFilter

ROOT = os.path.normpath(os.path.join(os.path.dirname(__file__), "..", ".."))
OUT = os.path.join(ROOT, "assets", "vessels", "starling_33", "demo", "deck", "coachroof.png")
CANVAS = (-560, -200, 1120, 400)
SCALE = 2
INK = (52, 44, 38, 255)


def px(x, y):
    return ((x - CANVAS[0]) * SCALE, (y - CANVAS[1]) * SCALE)


def wobble(points, amount, rnd, steps=10):
    """Resamples a closed outline with a little hand-drawn wobble."""
    out = []
    for i, (x0, y0) in enumerate(points):
        x1, y1 = points[(i + 1) % len(points)]
        for k in range(steps):
            t = k / steps
            out.append((x0 + (x1 - x0) * t + rnd.uniform(-amount, amount), y0 + (y1 - y0) * t + rnd.uniform(-amount, amount)))
    return out


def main():
    rnd = random.Random(33)
    w, h = CANVAS[2] * SCALE, CANVAS[3] * SCALE
    img = Image.new("RGBA", (w, h), (0, 0, 0, 0))
    roof = [(-230, -100), (90, -100), (120, -70), (120, 70), (90, 100), (-230, 100)]
    outline = [px(x, y) for x, y in roof]

    # Wash: base colour plus soft uneven blotches, clipped to the roof.
    mask = Image.new("L", (w, h), 0)
    ImageDraw.Draw(mask).polygon(wobble(outline, 1.5, rnd), fill=255)
    wash = Image.new("RGBA", (w, h), (232, 222, 196, 255))
    blotches = Image.new("RGBA", (w, h), (0, 0, 0, 0))
    bd = ImageDraw.Draw(blotches)
    for _ in range(60):
        cx, cy = rnd.uniform(outline[0][0], outline[2][0]), rnd.uniform(outline[0][1], outline[4][1])
        r = rnd.uniform(20, 70)
        tone = rnd.choice([(214, 200, 168, 60), (245, 238, 220, 70), (205, 188, 160, 45)])
        bd.ellipse((cx - r, cy - r * 0.7, cx + r, cy + r * 0.7), fill=tone)
    wash = Image.alpha_composite(wash, blotches.filter(ImageFilter.GaussianBlur(12)))
    img.paste(wash, (0, 0), mask)

    d = ImageDraw.Draw(img)
    # Hatching along the aft and starboard edges (shade).
    for i in range(26):
        x = outline[0][0] + 14 + i * 22
        d.line([(x, outline[4][1] - 6), (x + 18, outline[4][1] - 26)], fill=(120, 100, 80, 110), width=2)
    # Portlights (same places as the procedural ones) and the fore hatch.
    for x0, x1 in ((-112, -68), (18, 62)):
        for y0, y1 in ((-68, -52), (52, 68)):
            box = [px(x0, y0), px(x1, y1)]
            d.rounded_rectangle(box, radius=10, fill=(63, 120, 128, 230), outline=INK, width=3)
            d.line([(box[0][0] + 8, box[0][1] + 6), (box[0][0] + 30, box[0][1] + 6)], fill=(220, 240, 240, 160), width=3)
    hatch = wobble([px(-65, -28), px(-15, -28), px(-15, 27), px(-65, 27)], 1.2, rnd, 6)
    d.polygon(hatch, fill=(166, 196, 201, 200))
    d.line(hatch + [hatch[0]], fill=INK, width=3)
    d.line([px(-60, 0), px(-20, 0)], fill=INK, width=2)
    # Two passes of wobbly ink for the outline, like a quick pen sketch.
    for amount, width in ((2.2, 5), (1.2, 2)):
        line = wobble(outline, amount, rnd)
        d.line(line + [line[0]], fill=INK, width=width, joint="curve")
    os.makedirs(os.path.dirname(OUT), exist_ok=True)
    img.save(OUT)
    print("wrote", OUT)


if __name__ == "__main__":
    main()
