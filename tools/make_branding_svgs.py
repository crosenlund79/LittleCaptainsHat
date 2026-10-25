"""Generates the Little Captain's Hat branding SVGs (Visual Identity V01).

Usage: python3 tools/make_branding_svgs.py assets/fonts/PatrickHand-Regular.ttf assets/branding

The wordmark is set in Patrick Hand (SIL OFL) and converted to outline paths,
so the SVGs render identically everywhere, including Godot's SVG importer,
which does not render <text>. The symbol is a captain's hat above a wave,
drawn with slightly uneven dark-ink outlines in the game's hand-drawn style.

The game was developed as "Next Harbor" until Iteration 006. The old
next_harbor_* files in assets/branding/ are kept unchanged for history; this
script no longer writes them.
"""
import sys
from fontTools.ttLib import TTFont
from fontTools.pens.svgPathPen import SVGPathPen
from fontTools.pens.transformPen import TransformPen

FONT = sys.argv[1]
OUT = sys.argv[2]

NAVY, TEAL, SEAFOAM, CREAM, BRASS = "#102D3B", "#3F7880", "#A6C4C9", "#EFE5CC", "#C79F6D"
INK, CROWN, CROWN_SHADE, BAND, PEAK = "#1d1a17", "#f3ede0", "#d9d0bd", "#22344a", "#141b22"
NAME = "Little Captain’s Hat"


def wordmark(text, size, tracking_em, x0, baseline):
    font = TTFont(FONT)
    gs = font.getGlyphSet()
    cmap = font.getBestCmap()
    upm = font["head"].unitsPerEm
    scale = size / upm
    hmtx = font["hmtx"]
    paths, x = [], 0.0
    for i, ch in enumerate(text):
        gname = cmap[ord(ch)]
        adv = hmtx[gname][0]
        if ch != " ":
            pen = SVGPathPen(gs)
            tp = TransformPen(pen, (scale, 0, 0, -scale, x0 + x, baseline))
            gs[gname].draw(tp)
            paths.append(pen.getCommands())
        x += adv * scale
        if i < len(text) - 1:
            x += tracking_em * size
    return " ".join(paths), x


def symbol(wave, ox=0, oy=0, s=1.0, ink=INK):
    """A captain's hat, three-quarter side view, in a 256x256 box: white crown,
    navy band with a brass badge, glossy black peak, above a wave."""
    stroke = f'stroke="{ink}" stroke-width="5" stroke-linejoin="round" stroke-linecap="round"'
    g = f'<g transform="translate({ox} {oy}) scale({s})">'
    # Crown top (the white cover), a little lopsided like a hand drawing.
    g += f'<path d="M38 117 Q 44 69 127 61 Q 215 57 223 107 Q 201 127 129 128 Q 64 131 38 117 Z" fill="{CROWN}" {stroke}/>'
    # Crown side, shaded, down to the band.
    g += f'<path d="M55 118 L 65 151 Q 129 161 196 150 L 209 113 Q 131 133 55 118 Z" fill="{CROWN_SHADE}" {stroke}/>'
    # Band.
    g += f'<path d="M65 151 Q 129 162 196 150 L 194 172 Q 128 183 67 173 Z" fill="{BAND}" {stroke}/>'
    # Gold cord across the band.
    g += f'<path d="M70 160 Q 130 170 191 159" fill="none" stroke="{BRASS}" stroke-width="4" stroke-linecap="round"/>'
    # Peak.
    g += f'<path d="M67 173 Q 129 186 194 172 Q 197 197 151 205 Q 99 208 62 191 Q 55 180 67 173 Z" fill="{PEAK}" {stroke}/>'
    g += f'<path d="M92 190 Q 125 198 160 192" fill="none" stroke="#4a5866" stroke-width="4" stroke-linecap="round"/>'
    # Brass badge with a tiny anchor.
    g += f'<circle cx="130" cy="139" r="13" fill="{BRASS}" stroke="{ink}" stroke-width="4"/>'
    g += (f'<path d="M130 131 L130 147 M124 136 L136 136 M123 143 Q 130 150 137 143" fill="none" '
          f'stroke="{ink}" stroke-width="2.5" stroke-linecap="round"/>')
    # The wave below.
    g += (f'<path d="M24 230 Q 46 216 68 230 T 112 230 T 156 230 T 200 230 T 236 228" fill="none" '
          f'stroke="{wave}" stroke-width="9" stroke-linecap="round" stroke-linejoin="round"/>')
    return g + "</g>"


def svg(w, h, body, title):
    return (f'<svg xmlns="http://www.w3.org/2000/svg" width="{w}" height="{h}" '
            f'viewBox="0 0 {w} {h}"><title>{title}</title>{body}</svg>\n')


def write(name, content):
    with open(f"{OUT}/{name}", "w") as f:
        f.write(content)


# Compact symbol, transparent background (for dark surfaces).
write("little_captains_hat_symbol.svg", svg(256, 256, symbol(SEAFOAM), f"{NAME} symbol"))
# App icon: the hat on a navy rounded tile, readable at small sizes.
tile = f'<rect x="0" y="0" width="256" height="256" rx="48" fill="{NAVY}"/>'
write("little_captains_hat_icon.svg", svg(256, 256, tile + symbol(SEAFOAM, 14, 6, 0.89), f"{NAME} icon"))


# Primary logo: the hat above the hand-lettered name.
def primary(wave, text_color):
    size = 132
    _, width = wordmark(NAME, size, 0.01, 0, 0)
    W = int(width + 120)
    H = 500
    x0 = (W - width) / 2
    paths, _ = wordmark(NAME, size, 0.01, x0, 470)
    body = symbol(wave, (W - 256 * 1.3) / 2, -6, 1.3)
    body += f'<path d="{paths}" fill="{text_color}"/>'
    return svg(W, H, body, NAME)


write("little_captains_hat_logo.svg", primary(SEAFOAM, CREAM))
write("little_captains_hat_logo_on_light.svg", primary(TEAL, NAVY))
print("ok")
