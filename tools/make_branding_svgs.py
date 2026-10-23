"""Generates the Next Harbor branding SVGs. Wordmark letters are converted to
outline paths (Barlow SemiBold, OFL) so the SVGs render identically everywhere,
including Godot's SVG importer which does not render <text>."""
import sys
from fontTools.ttLib import TTFont
from fontTools.pens.svgPathPen import SVGPathPen
from fontTools.pens.transformPen import TransformPen

FONT = sys.argv[1]
OUT = sys.argv[2]

NAVY, TEAL, SEAFOAM, CREAM, BRASS = "#102D3B", "#3F7880", "#A6C4C9", "#EFE5CC", "#C79F6D"

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

def symbol(sail, hull, line, dot, ox=0, oy=0, s=1.0):
    """The Harbor Line symbol drawn in a 256x256 box: a sloop above a single
    course line that sweeps towards a waypoint (the next harbor)."""
    g = f'<g transform="translate({ox} {oy}) scale({s})">'
    # Mainsail (aft of the mast, bow faces right) with a gently curved leech.
    g += f'<path d="M132 34 L132 164 L70 164 Q 98 104 132 34 Z" fill="{sail}"/>'
    # Headsail.
    g += f'<path d="M142 58 L190 164 L142 164 Z" fill="{sail}"/>'
    # Hull: straight sheer, rounded underbody, raked bow on the right.
    g += f'<path d="M58 174 L204 174 Q 194 194 172 198 L 86 198 Q 66 194 58 174 Z" fill="{hull}"/>'
    # Course line from astern, curving like a harbor approach to a waypoint.
    g += (f'<path d="M26 226 Q 120 240 200 214" fill="none" stroke="{line}" '
          f'stroke-width="9" stroke-linecap="round"/>')
    g += f'<circle cx="216" cy="207" r="11" fill="{dot}"/>'
    return g + "</g>"

def svg(w, h, body, title):
    return (f'<svg xmlns="http://www.w3.org/2000/svg" width="{w}" height="{h}" '
            f'viewBox="0 0 {w} {h}"><title>{title}</title>{body}</svg>\n')

def write(name, content):
    with open(f"{OUT}/{name}", "w") as f:
        f.write(content)

# Compact symbol, transparent background (for dark surfaces).
write("next_harbor_symbol.svg", svg(256, 256, symbol(CREAM, SEAFOAM, TEAL, BRASS), "Next Harbor symbol"))
# App icon: the symbol on a navy rounded tile, readable at small sizes.
tile = f'<rect x="0" y="0" width="256" height="256" rx="48" fill="{NAVY}"/>'
write("next_harbor_icon.svg", svg(256, 256, tile + symbol(CREAM, SEAFOAM, SEAFOAM, BRASS, 18, 12, 0.86), "Next Harbor icon"))

# Primary logo: symbol above a tracked wordmark, plus a thin horizon rule.
def primary(sail, hull, line, dot, text_color, rule_color):
    size = 104
    _, width = wordmark("NEXT HARBOR", size, 0.16, 0, 0)
    W = int(width + 120)
    H = 480
    x0 = (W - width) / 2
    paths, _ = wordmark("NEXT HARBOR", size, 0.16, x0, 456)
    body = symbol(sail, hull, line, dot, (W - 256 * 1.38) / 2, -20, 1.38)
    body += f'<path d="{paths}" fill="{text_color}"/>'
    return svg(W, H, body, "Next Harbor")

write("next_harbor_logo.svg", primary(CREAM, SEAFOAM, TEAL, BRASS, CREAM, SEAFOAM))
write("next_harbor_logo_on_light.svg", primary(NAVY, TEAL, TEAL, BRASS, NAVY, TEAL))
print("ok")
