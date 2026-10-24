"""Bootstraps the catamaran (halcyon_40) and trimaran (petrel_36) scenes.

Writes, per vessel, into src/vessels/<id>/:
  deck_visual.tscn   art only (VesselVisual with the named visual slots)
  deck.tscn          gameplay deck: Visual instance + Layout + SailRig + Player
  cabin_visual.tscn  art only (CabinBase, FurnitureVisual, CabinDetails)
  cabin.tscn         gameplay cabin: Visual instance + Layout + Companion + Player

This is a one-time starting point, not a build step: once generated, the
scenes are ordinary Godot scenes to be edited in the editor. The script
refuses to overwrite existing scenes unless --force is given.

    python3 tools/vessels/build_multihull_scenes.py [--force] [halcyon_40|petrel_36]

Coordinates (all scenes): +x forward (bow), -x aft, -y port, +y starboard,
origin at the middle of the boat. The procedural art and the collision are
derived from the same numbers here, so they line up; sprites drawn on the
art templates line up with them too.
"""
import math
import os
import sys

sys.path.insert(0, os.path.dirname(__file__))
from tscn import Scene, vec, rect, pva, color, string  # noqa: E402

ROOT = os.path.normpath(os.path.join(os.path.dirname(__file__), "..", ".."))

VISUAL = "res://src/boat/visuals/vessel_visual.gd"
SLOT = "res://src/boat/visuals/visual_slot.gd"
SHAPE = "res://src/boat/visuals/procedural_shape.gd"
FIXTURE = "res://src/boat/boat_fixture.gd"
INTERACTABLE = "res://src/interaction/interactable.gd"
AREA = "res://src/boat/boat_area.gd"
RIG = "res://src/boat/sail_rig.gd"
COMPANION = "res://src/companion/ship_companion.gd"
PLAYER = "res://src/player/player.tscn"
FONT = "res://assets/fonts/Barlow-SemiBold.ttf"

# Palette (the same as the starter sloop).
HULL = "#EFE5CC"
TEAK = "#8A6A4A"
TEAK_DARK = "#5E4733"
NONSKID = "#D4CCB4"
WELL = "#B4AB93"
ROOF = "#E6DFCB"
GLASS = "#3F7880"
METAL = "#5E6468"
METAL_DARK = "#3D3F41"
STEEL = "#C9D2D6"
NET = "#2E4A52"
SOLE = "#9A7A57"
CABIN_HULL = "#163240"
DARK = "#0A1C25"
WOOD = "#6E5440"
CUSHION = "#3F7880"
BLANKET = "#A8B4A0"
SAIL_COVER = "#3F7880"


def ellipse(cx, cy, rx, ry, steps=16):
    return [(cx + rx * math.cos(2 * math.pi * i / steps), cy + ry * math.sin(2 * math.pi * i / steps)) for i in range(steps)]


def mirror(points):
    """Port half (y <= 0, listed stern to bow) -> closed outline."""
    return points + [(x, -y) for x, y in reversed(points) if abs(y) > 1e-6]


def hull_outline(stern_x, bow_x, half_beam, stern_half, cy=0.0, steps=24, bluff=0.35):
    """A slender hull seen from above: flat transom, fullest a little aft of
    the middle, fine pointed bow. Returns a closed outline."""
    port = []
    for i in range(steps + 1):
        t = i / steps
        x = stern_x + (bow_x - stern_x) * t
        if t < bluff:
            w = stern_half + (half_beam - stern_half) * math.sin(t / bluff * math.pi / 2)
        else:
            u = (t - bluff) / (1 - bluff)
            w = half_beam * math.cos(u * math.pi / 2) ** 0.9
        port.append((x, -w))
    port[-1] = (bow_x, 0.0)
    outline = mirror(port)
    return [(x, y + cy) for x, y in outline]


class Builder:
    """Scene helpers shared by the four scenes."""

    def __init__(self):
        self.s = Scene()
        self.labels = {}

    def res(self, kind, path):
        return self.s.ext_res(kind, path)

    def label_settings(self, size, col, alpha):
        key = (size, col, alpha)
        if key not in self.labels:
            self.labels[key] = self.s.sub_res("LabelSettings", [
                f'font = {self.res("FontFile", FONT)}', f"font_size = {size}", f"font_color = {color(col, alpha)}"],
                rid=f"LabelSettings_{len(self.labels) + 1}")
        return self.labels[key]

    def node(self, name, kind, parent, lines=(), **kw):
        self.s.node(name, kind, parent, list(lines), **kw)

    def slot(self, name, parent=".", z=None):
        lines = [f"script = {self.res('Script', SLOT)}", f'slot = &"{name}"']
        if z is not None:
            lines.append(f"z_index = {z}")
        self.node(name, "Node2D", parent, lines)

    def poly(self, name, parent, points, col, alpha=1.0):
        self.node(name, "Polygon2D", parent, [f"color = {color(col, alpha)}", f"polygon = {pva(points)}"])

    def line(self, name, parent, points, width, col, alpha=1.0, closed=False, z=None):
        lines = [f"points = {pva(points)}", f"width = {width}", f"default_color = {color(col, alpha)}",
                 "joint_mode = 2", "begin_cap_mode = 2", "end_cap_mode = 2", "antialiased = true"]
        if closed:
            lines.append("closed = true")
        if z is not None:
            lines.append(f"z_index = {z}")
        self.node(name, "Line2D", parent, lines)

    def shape(self, name, parent, pos, fill, size=None, polygon=None, label=None, z=None):
        lines = [f"script = {self.res('Script', SHAPE)}", f"position = {vec(*pos)}"]
        if size:
            lines.append(f"size = {vec(*size)}")
        if polygon:
            lines.append(f"polygon = {pva(polygon)}")
        lines.append(f"fill_color = {color(fill)}")
        if label:
            lines.append(f"label = {string(label)}")
        if z is not None:
            lines.append(f"z_index = {z}")
        self.node(name, "Node2D", parent, lines)

    def label(self, name, parent, text, center, settings, width=240):
        x, y = center
        self.node(name, "Label", parent, [
            f"offset_left = {int(x - width / 2)}", f"offset_top = {int(y - 14)}",
            f"offset_right = {int(x + width / 2)}", f"offset_bottom = {int(y + 14)}",
            "mouse_filter = 2", f"text = {string(text)}", f"label_settings = {settings}",
            "horizontal_alignment = 1", "vertical_alignment = 1"])

    def fixture(self, name, pos, size=None, polygon=None, solid=True, parent="Layout/Collision"):
        lines = [f"script = {self.res('Script', FIXTURE)}", f"position = {vec(*pos)}"]
        if size:
            lines.append(f"size = {vec(*size)}")
        if polygon:
            lines.append(f"polygon = {pva(polygon)}")
        if not solid:
            lines.append("solid = false")
        self.node(name, "StaticBody2D", parent, lines)

    def boundary(self, name, outlines):
        """Static body whose CollisionPolygon2Ds are closed segment loops."""
        self.node(name, "StaticBody2D", "Layout/Collision", ["collision_layer = 1", "collision_mask = 0"])
        for i, points in enumerate(outlines):
            loop = points  # segment mode closes the loop itself
            self.node("CollisionPolygon2D" if i == 0 else f"CollisionPolygon2D{i + 1}", "CollisionPolygon2D",
                      f"Layout/Collision/{name}", ["build_mode = 1", f"polygon = {pva(loop)}"])

    def wall(self, name, a, b, thickness=12):
        """A straight solid wall from a to b (axis aligned)."""
        (ax, ay), (bx, by) = a, b
        cx, cy = (ax + bx) / 2, (ay + by) / 2
        size = (abs(bx - ax) or thickness, abs(by - ay) or thickness)
        self.fixture(name, (cx, cy), size=size)

    def station(self, name, pos, interaction_id, prompt, shape):
        kind, dims = shape
        if kind == "rect":
            sid = self.s.sub_res("RectangleShape2D", [f"size = {vec(*dims)}"], rid=f"RectangleShape2D_{name}")
        else:
            sid = self.s.sub_res("CircleShape2D", [f"radius = {float(dims)}"], rid=f"CircleShape2D_{name}")
        self.node(name, "Area2D", "Layout/Stations", [
            f"position = {vec(*pos)}", f"script = {self.res('Script', INTERACTABLE)}",
            f'interaction_id = &"{interaction_id}"', f"prompt = {string(prompt)}", 'highlight_target = NodePath("")'])
        self.node("CollisionShape2D", "CollisionShape2D", f"Layout/Stations/{name}", [f"shape = {sid}"])

    def markers(self, group, points):
        self.node(group, "Node2D", "Layout")
        for name, pos in points.items():
            self.node(name, "Marker2D", f"Layout/{group}", [f"position = {vec(*pos)}"])

    def write(self, path, force):
        if os.path.exists(path) and not force:
            print("exists, skipped (use --force):", os.path.relpath(path, ROOT))
            return
        self.s.write(path)


# ---------------------------------------------------------------- shared parts

def surroundings(b, pontoon_y, port_name, lines_from, cleats, sign_x, grocery_x):
    """Water, ripples and the pontoon (Mooring is shown only in port)."""
    b.node("Surroundings", "Node2D", ".")
    b.poly("Water", "Surroundings", [(-1700, -1000), (1700, -1000), (1700, 1000), (-1700, 1000)], "#1D4652")
    ripples = [(-700, -380, 60), (-220, -420, 45), (300, -370, 70), (700, -300, 40), (-780, 160, 50), (780, 180, 55)]
    for i, (x, y, w) in enumerate(ripples):
        b.line(f"Ripple{i}", "Surroundings", [(x - w, y), (x, y - 6), (x + w, y)], 3, "#A6C4C9", 0.18)
    b.node("Mooring", "Node2D", "Surroundings")
    top, bottom = pontoon_y, pontoon_y + 100
    b.poly("Pontoon", "Surroundings/Mooring", [(-820, top), (820, top), (820, bottom), (-820, bottom)], "#8A8170")
    for i in range(38):
        x = -800 + i * 44
        b.line(f"Plank{i}", "Surroundings/Mooring", [(x, top + 2), (x, bottom - 2)], 2, "#5F5749", 0.5)
    for i, x in enumerate(cleats):
        b.poly(f"Cleat{i}", "Surroundings/Mooring", [(x - 16, top + 11), (x + 16, top + 11), (x + 16, top + 21), (x - 16, top + 21)], "#3A3A38")
    for name, (start, cleat_x) in lines_from.items():
        b.line(name, "Surroundings/Mooring", [start, (cleat_x, top + 16)], 3, "#EFE5CC", 0.8)
    muted = b.label_settings(15, "#A6C4C9", 0.6)
    b.label("PontoonLabel", "Surroundings/Mooring", port_name, (0, top + 55), muted)
    b.label("BoatyardSign", "Surroundings/Mooring", "BOATYARD", (sign_x, top + 21), muted, width=280)
    b.label("GrocerySign", "Surroundings/Mooring", "GROCERY STORE", (grocery_x, top + 21), muted, width=280)


def deck_root(b, vessel_id, bounds):
    b.node("Exterior", "Node2D", None, [
        f"script = {b.res('Script', AREA)}", 'area_id = &"exterior"', 'companionway_target_area = &"interior"',
        'companionway_target_spawn = &"from_deck"', f"walkable_bounds = {rect(*bounds)}",
        f'ambience = {b.res("AudioStream", "res://assets/audio/placeholder/placeholder_ambience_deck.wav")}',
        f'interaction_sound = {b.res("AudioStream", "res://assets/audio/placeholder/test_sfx_blip.wav")}',
        'mooring = NodePath("Surroundings/Mooring")', 'mooring_label = NodePath("Surroundings/Mooring/PontoonLabel")'],
        extra='node_paths=PackedStringArray("mooring", "mooring_label")')


def deck_tail(b, vessel_id, camera_pos, zoom):
    b.node("SailRig", "Node2D", ".", ["z_index = 2", f"script = {b.res('Script', RIG)}"])
    b.node("Player", None, ".", ["z_index = 10"], instance=b.res("PackedScene", PLAYER))
    b.node("Camera2D", "Camera2D", ".", [f"position = {vec(*camera_pos)}", f"zoom = {vec(zoom, zoom)}"])


def cabin_root(b, bounds):
    b.node("Interior", "Node2D", None, [
        f"script = {b.res('Script', AREA)}", 'area_id = &"interior"', 'companionway_target_area = &"exterior"',
        'companionway_target_spawn = &"from_cabin"', f"walkable_bounds = {rect(*bounds)}",
        f'ambience = {b.res("AudioStream", "res://assets/audio/placeholder/placeholder_ambience_cabin.wav")}',
        f'interaction_sound = {b.res("AudioStream", "res://assets/audio/placeholder/test_sfx_blip.wav")}'])
    b.node("Backdrop", "Node2D", ".")
    b.poly("Darkness", "Backdrop", [(-1700, -1000), (1700, -1000), (1700, 1000), (-1700, 1000)], DARK)


def cabin_tail(b, camera_pos, zoom):
    b.node("Companion", "Node2D", ".", [f"script = {b.res('Script', COMPANION)}"])
    b.node("Player", None, ".", ["z_index = 10"], instance=b.res("PackedScene", PLAYER))
    b.node("Camera2D", "Camera2D", ".", [f"position = {vec(*camera_pos)}", f"zoom = {vec(zoom, zoom)}"])


PROVISION_DISPLAY = "res://src/boat/provision_display.gd"


def provision_display(b, pos):
    """The food and water stores drawn from the real quantities (on the counter)."""
    b.node("ProvisionDisplay", "Node2D", ".", [f"position = {vec(*pos)}", f"script = {b.res('Script', PROVISION_DISPLAY)}"])


def visual_root(b, canvas):
    b.node("Visual", "Node2D", None, [f"script = {b.res('Script', VISUAL)}", f"canvas = {rect(*canvas)}"])


def offset(points, dx, dy):
    return [(x + dx, y + dy) for x, y in points]


def wheel(b, parent, x, y, span=50):
    b.shape("Pedestal", parent, (x + 14, y), METAL, polygon=ellipse(0, 0, 11, 11, 12))
    b.shape("Wheel", parent, (x, y), METAL_DARK, size=(12, span))


# ================================================================ catamaran

CAT = {
    "id": "halcyon_40",
    "canvas": (-560, -330, 1120, 660),
    "hull_y": 218,          # hull centrelines at y = +-218
    "hull_half": 58,        # hull half beam (deck view)
    "stern": -500, "bow": 480,
    "bridge_aft": -420, "bridge_fwd": 130,   # bridgedeck (saloon + cockpit)
    "beam_x": 440,          # forward beam (trampoline ends here)
    "saloon": (-180, 130),  # saloon roof x range
    "saloon_half": 148,
    "mast": (150, 0), "tack": (440, 0), "boom_end": (-250, 0), "traveller": (-268, 0),
    "jib_lead": (-60, 150), "kite_lead": (-470, 250),
    "pontoon_y": 345,
}


def cat_hulls(c):
    outlines = []
    for side in (-1, 1):
        outlines.append(hull_outline(c["stern"], c["bow"], c["hull_half"], c["hull_half"] * 0.8, cy=side * c["hull_y"], bluff=0.55))
    return outlines


def cat_lifeline(c):
    """Closed walkable boundary: both hull decks, the bridgedeck and the net."""
    hy, inner, outer = c["hull_y"], c["hull_y"] - 50, c["hull_y"] + 48
    s, ba, bf = c["stern"] + 12, c["bridge_aft"], c["beam_x"]
    port = [(s, -inner), (s, -outer), (300, -outer), (390, -hy - 30), (455, -hy - 6), (450, -inner + 8), (bf, -inner)]
    star = [(x, -y) for x, y in reversed(port)]
    return port + star + [(ba, inner), (ba, -inner)]


def build_cat_deck_visual(c):
    b = Builder()
    visual_root(b, c["canvas"])
    hulls = cat_hulls(c)
    hy, sh = c["hull_y"], c["saloon_half"]
    ba, bf = c["bridge_aft"], c["bridge_fwd"]
    s0, s1 = c["saloon"]
    bridge = [(ba, -hy + 20), (bf + 10, -hy + 20), (bf + 10, hy - 20), (ba, hy - 20)]

    b.slot("ShadowVisual")
    for i, h in enumerate(hulls):
        b.poly(f"HullShadow{i}", "ShadowVisual", offset(h, 8, 12), "#000000", 0.25)
    b.poly("BridgeShadow", "ShadowVisual", offset(bridge, 8, 12), "#000000", 0.2)

    b.slot("HullBase")
    for i, h in enumerate(hulls):
        b.poly("PortHull" if i == 0 else "StarboardHull", "HullBase", h, HULL)
        b.line("PortToeRail" if i == 0 else "StarboardToeRail", "HullBase", h, 6, TEAK, closed=True)
    b.poly("Bridgedeck", "HullBase", bridge, HULL)
    b.poly("ForwardBeam", "HullBase", [(c["beam_x"] - 8, -hy), (c["beam_x"] + 8, -hy), (c["beam_x"] + 8, hy), (c["beam_x"] - 8, hy)], METAL)

    b.slot("DeckBase")
    for i, h in enumerate(hulls):
        inner = [(x * 0.97, (y - (-hy if i == 0 else hy)) * 0.72 + (-hy if i == 0 else hy)) for x, y in h]
        b.poly("PortDeck" if i == 0 else "StarboardDeck", "DeckBase", inner, NONSKID)
    b.poly("BridgedeckSurface", "DeckBase", [(ba + 6, -hy + 26), (bf, -hy + 26), (bf, hy - 26), (ba + 6, hy - 26)], NONSKID)
    b.poly("Trampoline", "DeckBase", [(bf + 12, -hy + 26), (c["beam_x"] - 10, -hy + 26), (c["beam_x"] - 10, hy - 26), (bf + 12, hy - 26)], NET, 0.85)
    for i in range(9):
        x = bf + 40 + i * 32
        b.line(f"Net{i}", "DeckBase", [(x, -hy + 28), (x, hy - 28)], 1, STEEL, 0.25)
    for i in range(10):
        y = -hy + 46 + i * 38
        b.line(f"NetCross{i}", "DeckBase", [(bf + 14, y), (c["beam_x"] - 12, y)], 1, STEEL, 0.25)
    b.poly("Cockpit", "DeckBase", [(ba + 14, -sh + 10), (s0 - 4, -sh + 10), (s0 - 4, sh - 10), (ba + 14, sh - 10)], WELL)
    b.shape("CockpitTable", "DeckBase", (-300, 0), TEAK, size=(70, 100))
    b.shape("BenchAft", "DeckBase", (ba + 30, 0), TEAK, size=(26, 220))
    for i, side in enumerate((-1, 1)):
        b.shape(f"Steps{i}", "DeckBase", (c["stern"] + 22, side * hy), TEAK_DARK, size=(26, 60))
    b.shape("SaloonDoor", "DeckBase", (s0 - 2, 0), TEAK_DARK, size=(14, 84))

    b.slot("Coachroof")
    roof = [(s0, -sh), (s1 - 40, -sh), (s1, -sh + 40), (s1, sh - 40), (s1 - 40, sh), (s0, sh)]
    b.poly("SaloonRoof", "Coachroof", roof, ROOF)
    b.line("RoofEdge", "Coachroof", roof, 3, TEAK, 0.6, closed=True)
    for i, y in enumerate((-110, -40, 40, 110)):
        b.poly(f"Window{i}", "Coachroof", [(s1 - 18, y - 26), (s1 - 6, y - 22), (s1 - 6, y + 22), (s1 - 18, y + 26)], GLASS, 0.75)
    b.poly("Hatch", "Coachroof", [(-40, -30), (20, -30), (20, 30), (-40, 30)], "#A6C4C9", 0.6)
    b.line("SolarPanels", "Coachroof", [(s0 + 30, -100), (s0 + 30, 100)], 3, GLASS, 0.5)

    b.slot("DeckDetails")
    wheel(b, "DeckDetails", -196, 132, 40)
    for i, (x, y) in enumerate([(-460, -250), (-460, 250), (420, -250), (420, 250), (-200, -275), (-200, 275)]):
        b.shape(f"Cleat{i}", "DeckDetails", (x, y), METAL, size=(20, 8))
    for i, side in enumerate((-1, 1)):
        b.shape(f"AnchorLocker{i}", "DeckDetails", (380, side * hy), WELL, size=(50, 40))
        b.shape(f"Winch{i}", "DeckDetails", (-240, side * 138), METAL_DARK, polygon=ellipse(0, 0, 9, 9, 10))
    life = cat_lifeline(c)
    b.line("Lifelines", "DeckDetails", life, 2, STEEL, 0.65, closed=True, z=6)
    for i, side in enumerate((-1, 1)):
        b.line(f"Pulpit{i}", "DeckDetails", [(400, side * (hy + 38)), (455, side * hy), (400, side * (hy - 38))], 4, STEEL, 0.9, z=6)
    b.node("Labels", "Node2D", "DeckDetails", ["z_index = 5"])
    big = b.label_settings(15, "#102D3B", 0.6)
    small = b.label_settings(13, "#102D3B", 0.55)
    for name, text, pos, st in [("Cockpit", "COCKPIT", (-320, -100), big), ("Helm", "HELM", (-200, 92), small),
                                ("Saloon", "SALOON ROOF", (-40, -70), small), ("Trampoline", "TRAMPOLINE", (290, -60), big),
                                ("PortHull", "PORT HULL", (-60, -hy), small), ("StarboardHull", "STARBOARD HULL", (-60, hy - 30), small),
                                ("Bow", "BOWS", (390, -hy - 60), big), ("Stern", "STERN", (-470, -hy - 70), small),
                                ("Mast", "MAST", (150, 40), big)]:
        b.label(name, "DeckDetails/Labels", text, pos, st)

    b.slot("RiggingVisual", z=2)
    mx, my = c["mast"]
    b.line("Shrouds", "RiggingVisual", [(mx - 30, -hy + 30), (mx, my), (mx - 30, hy - 30)], 2, STEEL, 0.8)
    b.line("Forestay", "RiggingVisual", [(mx, my), c["tack"]], 2, STEEL, 0.8)
    b.line("Bridle", "RiggingVisual", [(c["beam_x"] + 30, -hy + 6), c["tack"], (c["beam_x"] + 30, hy - 6)], 2, STEEL, 0.7)

    b.slot("MastVisual", z=3)
    b.shape("Mast", "MastVisual", c["mast"], "#B9C1C5", polygon=ellipse(0, 0, 14, 11, 16))
    return b


def build_cat_deck(c):
    b = Builder()
    deck_root(b, c["id"], (-520, -290, 1040, 580))
    hy = c["hull_y"]
    surroundings(b, c["pontoon_y"], "GUEST PONTOON · COPENHAGEN",
                 {"SternLine": ((-480, hy + 40), -440), "BowLine": ((430, hy + 30), 380)}, (-440, 380), -20, 220)
    b.node("Visual", None, ".", [], instance=b.res("PackedScene", f"res://src/vessels/{c['id']}/deck_visual.tscn"))
    b.node("Layout", "Node2D", ".")
    b.node("Collision", "Node2D", "Layout")
    b.boundary("Lifeline", [cat_lifeline(c)])
    s0, s1 = c["saloon"]
    sh = c["saloon_half"]
    b.fixture("Saloon", (0, 0), polygon=[(s0, -sh), (s1 - 40, -sh), (s1, -sh + 40), (s1, sh - 40), (s1 - 40, sh), (s0, sh)])
    b.fixture("CockpitTable", (-300, 0), size=(70, 100))
    b.fixture("BenchAft", (c["bridge_aft"] + 30, 0), size=(26, 220))
    b.fixture("Mast", c["mast"], polygon=ellipse(0, 0, 13, 13, 16))
    b.fixture("Wheel", (-196, 132), size=(12, 40))
    b.node("Stations", "Node2D", "Layout")
    b.station("Companionway", (s0 - 18, 0), "companionway", "Go below", ("rect", (36, 110)))
    b.station("Helm", (-226, 132), "helm", "Take the helm", ("circle", 30))
    b.station("Boatyard", (-20, hy + 32), "boatyard", "Visit the boatyard", ("rect", (200, 40)))
    b.station("Grocery", (220, hy + 32), "grocery", "Visit the grocery store", ("rect", (140, 40)))
    b.markers("SpawnPoints", {"start": (-330, -90), "from_cabin": (s0 - 45, 0), "from_boatyard": (-20, hy + 8)})
    b.markers("SailMarkers", {"Mast": c["mast"], "Tack": c["tack"], "BoomEnd": c["boom_end"], "Traveller": c["traveller"],
                              "JibSheetLead": c["jib_lead"], "SpinnakerSheetLead": c["kite_lead"]})
    deck_tail(b, c["id"], (0, 60), 1.22)
    return b


# Halcyon 40 cabin (Iteration 005b proportions). The cabin has its own
# numbers (CAB): the hull passages are 152 units wide (~1.9 m at the player's
# scale of ~80 units per metre) so a real double berth fits across each hull,
# and the furniture has realistic depths (counters and settees ~0.55 m).
# Port hull = owner's hull (aft double berth, wardrobe, desk, sofa, ensuite
# forward); starboard hull = guest hull (aft double berth, locker, heads and
# shower, forward bunk). Saloon: galley aft to port with the pantry
# (provisions), U-settee and table to starboard, nav desk forward to port,
# the saloon door (to the cockpit) in the middle of the aft wall. Steps lead
# down into the hulls through openings in the saloon side walls.
CAB = {
    "hull_y": 234,          # hull centreline in the cabin
    "inner": 158,           # saloon side wall / inner edge of the hull passages
    "outer": 310,           # outer edge of the hull passages
    "hull_half": 88,        # drawn hull half beam (dark hull around the passage)
    "stern": -470, "bow": 455,
    "saloon": (-200, 120),  # saloon x range (aft wall .. forward wall)
}
CAT_PORT_OPENING = (-60, 20)    # x range of the opening into the port hull
CAT_STBD_OPENING = (50, 115)    # ... into the starboard hull
CAT_DOOR_HALF = 46              # half width of the saloon door (aft wall)
# Furniture: name, centre, size or polygon (relative to centre), solid, colour.


def cat_cabin_hulls():
    return [hull_outline(CAB["stern"] - 6, CAB["bow"] + 6, CAB["hull_half"], CAB["hull_half"] * 0.9,
                         cy=side * CAB["hull_y"], bluff=0.6) for side in (-1, 1)]


def cat_cabin_outline(c):
    """Union of the saloon and the two hull passages (the walls between the
    saloon and the hulls are separate fixtures with openings)."""
    hi, ho, hy = CAB["inner"], CAB["outer"], CAB["hull_y"]
    s0, s1 = CAB["saloon"]
    port = [(-470, -hi), (-470, -ho), (300, -ho), (390, -ho + 30), (445, -hy), (410, -hi - 17), (330, -hi), (s1, -hi)]
    star = [(x, -y) for x, y in reversed(port)]
    return port + star + [(s0, hi), (s0, -hi)]


def cat_furniture(c):
    hy = CAB["hull_y"]
    return [
        # Saloon
        ("GalleyAft", (-178, -105), (44, 100), None, True, WOOD),
        ("GalleySide", (-110, -134), (100, 44), None, True, WOOD),
        ("Settee", (-60, 134), (200, 44), None, True, CUSHION),
        ("SetteeEnd", (-138, 84), (44, 60), None, True, CUSHION),
        ("SaloonTable", (-50, 70), (120, 56), None, True, WOOD),
        ("NavDesk", (96, -110), (44, 80), None, True, WOOD),
        ("NavSeat", (60, -110), None, ellipse(0, 0, 13, 13, 12), False, TEAK_DARK),
        # Port (owner's) hull
        ("OwnerBerth", (-385, -hy), None, [(-80, -66), (80, -66), (80, 66), (-80, 66)], True, BLANKET),
        ("Wardrobe", (-250, -hy - 50), (70, 44), None, True, WOOD),
        ("Desk", (-150, -hy - 50), (70, 44), None, True, WOOD),
        ("OwnerSofa", (190, -hy - 50), (120, 44), None, True, CUSHION),
        ("Ensuite", (0, 0), None, [(305, -hy - 66), (385, -hy - 42), (432, -hy), (400, -hy + 52), (305, -hy + 58)], True, "#7A8A8F"),
        # Starboard (guest) hull
        ("GuestBerth", (-392, hy), (146, 124), None, True, BLANKET),
        ("GuestLocker", (-270, hy + 50), (60, 44), None, True, WOOD),
        ("Heads", (210, hy + 48), (100, 44), None, True, "#7A8A8F"),
        ("Shower", (285, hy + 34), (50, 60), None, True, "#8FA3A8"),
        ("Bunk", (0, 0), None, [(335, hy - 58), (400, hy - 48), (430, hy), (385, hy + 38), (335, hy + 56)], True, BLANKET),
    ]


def cat_bulkheads(c):
    """Saloon side walls (y = +-inner) with the openings into the hulls."""
    hi = CAB["inner"]
    s0, s1 = CAB["saloon"]
    return [("BulkheadPortAft", (s0 - 6, -hi), (CAT_PORT_OPENING[0], -hi)),
            ("BulkheadPortFwd", (CAT_PORT_OPENING[1], -hi), (s1 + 6, -hi)),
            ("BulkheadStbdAft", (s0 - 6, hi), (CAT_STBD_OPENING[0], hi)),
            ("BulkheadStbdFwd", (CAT_STBD_OPENING[1], hi), (s1 + 6, hi))]


def build_cat_cabin_visual(c):
    b = Builder()
    visual_root(b, c["canvas"])
    hy = CAB["hull_y"]
    hi = CAB["inner"]
    s0, s1 = CAB["saloon"]
    outline = cat_cabin_outline(c)
    b.slot("CabinBase")
    for i, h in enumerate(cat_cabin_hulls()):
        b.poly(f"HullShape{i}", "CabinBase", h, CABIN_HULL)
    b.poly("SaloonShape", "CabinBase", [(s0 - 15, -hi - 10), (s1 + 15, -hi - 10), (s1 + 15, hi + 10), (s0 - 15, hi + 10)], CABIN_HULL)
    b.poly("CabinSole", "CabinBase", outline, SOLE)
    for i in range(7):
        y = -138 + i * 46
        b.line(f"Seam{i}", "CabinBase", [(s0 + 5, y), (s1 - 5, y)], 2, "#5E4733", 0.35)
    for i, side in enumerate((-1, 1)):
        for k, dy in enumerate((-38, 38)):
            b.line(f"HullSeam{i}{k}", "CabinBase", [(-465, side * hy + dy), (300, side * hy + dy)], 2, "#5E4733", 0.3)
    b.line("CabinSide", "CabinBase", outline, 12, "#5E4733", closed=True)
    # Saloon windows along the forward wall.
    for i, y in enumerate((-110, -40, 40, 110)):
        b.line(f"Window{i}", "CabinBase", [(s1 + 2, y - 26), (s1 + 2, y + 26)], 6, GLASS, 0.85)

    b.slot("FurnitureVisual")
    # The saloon door: an opening in the aft wall with the cockpit beyond, a
    # half-open sliding door, a step and chevrons pointing out to the deck.
    d = CAT_DOOR_HALF
    b.poly("CockpitBeyond", "FurnitureVisual", [(-262, -d - 8), (-203, -d - 8), (-203, d + 8), (-262, d + 8)], NONSKID)
    b.poly("CockpitShade", "FurnitureVisual", [(-262, -d - 8), (-252, -d - 8), (-252, d + 8), (-262, d + 8)], WELL)
    # A bright doorway frame and a lamp above it: the way out is seen at once.
    b.poly("DoorGlow", "FurnitureVisual", [(-212, -d - 4), (-200, -d - 4), (-200, d + 4), (-212, d + 4)], "#EFE5CC", 0.75)
    for i, side in enumerate((-1, 1)):
        b.poly(f"DoorPost{i}", "FurnitureVisual", [(-209, side * d - 5), (-195, side * d - 5), (-195, side * d + 5), (-209, side * d + 5)], TEAK_DARK)
    b.poly("SlidingDoor", "FurnitureVisual", [(-206, -d - 40), (-200, -d - 40), (-200, -4), (-206, -4)], GLASS, 0.55)
    b.line("DoorTrack", "FurnitureVisual", [(-203, -d - 40), (-203, d)], 2, TEAK_DARK, 0.8)
    b.shape("DoorStep", "FurnitureVisual", (-188, 0), "#7A5C40", size=(16, 2 * d - 8))
    b.line("StepNosing", "FurnitureVisual", [(-181, -d + 6), (-181, d - 6)], 3, "#4A3626", 0.8)
    for i in range(3):
        x = -218 - i * 12
        b.line(f"Chevron{i}", "FurnitureVisual", [(x + 9, -16), (x, 0), (x + 9, 16)], 4, "#102D3B", 0.85 - i * 0.2)
    # Steps down into each hull.
    for i, (side, (x0, x1)) in enumerate(((-1, CAT_PORT_OPENING), (1, CAT_STBD_OPENING))):
        cx = (x0 + x1) / 2
        b.shape(f"HullSteps{i}", "FurnitureVisual", (cx, side * (hi + 20)), "#7A5C40", size=(x1 - x0 - 6, 34))
        for k in range(3):
            y = -12 + k * 12
            b.line(f"Tread{i}{k}", f"FurnitureVisual/HullSteps{i}", [(-(x1 - x0) / 2 + 6, y), ((x1 - x0) / 2 - 6, y)], 2, "#4A3626", 0.7)
    for name, (x0, y0), (x1, y1) in cat_bulkheads(c):
        b.shape(name, "FurnitureVisual", ((x0 + x1) / 2, y0), "#5E4733", size=(abs(x1 - x0), 12))
    for name, pos, size, poly, solid, col in cat_furniture(c):
        b.shape(name, "FurnitureVisual", pos, col, size=size, polygon=poly)
    # Galley details.
    b.poly("Burner0", "FurnitureVisual/GalleySide", ellipse(-36, -4, 10, 10, 12), "#2A2F33")
    b.poly("Burner1", "FurnitureVisual/GalleySide", ellipse(-12, -4, 10, 10, 12), "#2A2F33")
    b.poly("Sink", "FurnitureVisual/GalleyAft", [(-14, -40), (14, -40), (14, -10), (-14, -10)], "#A6C4C9", 0.85)
    b.poly("Fridge", "FurnitureVisual/GalleyAft", [(-16, 14), (16, 14), (16, 44), (-16, 44)], "#C9D2D6", 0.8)
    # Saloon and nav station details.
    for i in range(3):
        b.line(f"Cushion{i}", "FurnitureVisual/Settee", [(-100 + 50 * (i + 1), -19), (-100 + 50 * (i + 1), 19)], 2, "#2E5A60", 0.8)
    b.poly("ChartPaper", "FurnitureVisual/NavDesk", [(-16, -34), (16, -34), (16, 8), (-16, 8)], "#EFE5CC", 0.9)
    b.poly("Instruments", "FurnitureVisual/NavDesk", [(-16, 14), (16, 14), (16, 34), (-16, 34)], "#2A2F33", 0.9)
    # Berths: blanket folded back, pillows at the aft end.
    for berth, half_x, half in (("OwnerBerth", 80, 66), ("GuestBerth", 73, 62)):
        for k, sign in enumerate((-1, 1)):
            b.poly(f"Pillow{k}", f"FurnitureVisual/{berth}", [(-half_x + 8, sign * 5), (-half_x + 34, sign * 5), (-half_x + 34, sign * (half - 8)), (-half_x + 8, sign * (half - 8))], "#EFE5CC", 0.9)
        b.poly("Fold", f"FurnitureVisual/{berth}", [(-half_x + 46, -half + 2), (-half_x + 60, -half + 2), (-half_x + 60, half - 2), (-half_x + 46, half - 2)], "#C9D1BE", 0.9)
    b.poly("BunkPillow", "FurnitureVisual/Bunk", [(341, hy - 44), (360, hy - 44), (360, hy + 42), (341, hy + 42)], "#EFE5CC", 0.9)
    b.poly("Toilet", "FurnitureVisual/Heads", ellipse(-26, 0, 12, 10, 12), "#EFE5CC")
    b.poly("Basin", "FurnitureVisual/Heads", ellipse(24, 0, 11, 9, 12), "#A6C4C9")
    b.poly("Drain", "FurnitureVisual/Shower", ellipse(0, 0, 4, 4, 8), "#4B5357")
    b.poly("EnsuiteToilet", "FurnitureVisual/Ensuite", ellipse(405, -hy, 11, 9, 12), "#EFE5CC")
    b.poly("EnsuiteShower", "FurnitureVisual/Ensuite", [(318, -hy - 44), (368, -hy - 44), (368, -hy + 44), (318, -hy + 44)], "#8FA3A8")

    b.slot("CabinDetails")
    b.node("Labels", "Node2D", "CabinDetails", ["z_index = 5"])
    big = b.label_settings(15, "#EFE5CC", 0.62)
    small = b.label_settings(13, "#EFE5CC", 0.55)
    dark = b.label_settings(13, "#102D3B", 0.7)
    for name, text, pos, st in [("Saloon", "SALOON", (-20, -10), big), ("Galley", "GALLEY · PANTRY", (-110, -86), small),
                                ("Chart", "NAV STATION", (40, -60), small), ("OwnerCabin", "OWNER'S CABIN", (-250, -hy + 20), small),
                                ("Ensuite", "ENSUITE", (360, -hy - 14), dark), ("GuestCabin", "GUEST CABIN", (-270, hy - 20), small),
                                ("Heads", "HEADS", (210, hy + 10), small), ("Bunk", "BUNK", (378, hy), dark),
                                ("PortSteps", "STEPS DOWN", (-20, -hi + 50), small), ("StbdSteps", "STEPS DOWN", (82, hi - 50), small),
                                ("Door", "TO DECK", (-232, 74), big)]:
        b.label(name, "CabinDetails/Labels", text, pos, st)
    return b


def build_cat_cabin(c):
    b = Builder()
    hy = CAB["hull_y"]
    cabin_root(b, (-480, -320, 960, 640))
    b.node("Visual", None, ".", [], instance=b.res("PackedScene", f"res://src/vessels/{c['id']}/cabin_visual.tscn"))
    provision_display(b, (-110, -134))
    b.node("Layout", "Node2D", ".")
    b.node("Collision", "Node2D", "Layout")
    b.boundary("Hull", [cat_cabin_outline(c)])
    for name, a, z in cat_bulkheads(c):
        b.wall(name, a, z)
    for name, pos, size, poly, solid, col in cat_furniture(c):
        b.fixture(name, pos, size=size, polygon=poly, solid=solid)
    b.node("Stations", "Node2D", "Layout")
    b.station("Companionway", (-185, 0), "companionway", "Go on deck", ("rect", (30, 2 * CAT_DOOR_HALF)))
    b.station("Chart", (58, -110), "nav_table", "Open chart", ("rect", (30, 80)))
    b.station("Berth", (-293, -hy), "bed", "Sleep", ("rect", (24, 120)))
    b.station("Provisions", (-110, -100), "provisions", "Check provisions", ("rect", (96, 24)))
    b.station("Work", (-150, -hy - 16), "work", "Work remotely", ("rect", (70, 24)))
    b.markers("SpawnPoints", {"start": (-40, -20), "from_deck": (-160, 0), "v_berth": (-278, -hy)})
    b.markers("CompanionSpots", {"settee": (-80, 134), "nav_station": (96, -140), "v_berth": (-322, -hy + 54),
                                 "cabin_floor": (0, 10), "companionway": (-140, -40), "seating": (30, 100)})
    cabin_tail(b, (-10, 0), 1.2)
    return b


# ================================================================ trimaran

TRI = {
    "id": "petrel_36",
    "canvas": (-600, -320, 1200, 640),
    "stern": -500, "bow": 500,
    "main_half": 120, "ama_y": 240, "ama_half": 34,
    "ama_aft": -330, "ama_fwd": 370,
    "aka": (-170, 170),
    "roof": (-130, 150), "roof_half": 44,
    "mast": (195, 0), "tack": (480, 0), "boom_end": (-200, 0), "traveller": (-250, 0),
    "jib_lead": (-60, 92), "kite_lead": (-470, 82),
    "pontoon_y": 310,
}


def tri_main(t, inset=0.0):
    return hull_outline(t["stern"] + inset, t["bow"] - inset * 1.5, t["main_half"] - inset, t["main_half"] * 0.78 - inset, bluff=0.45)


def tri_ama(t, side, inset=0.0):
    return hull_outline(t["ama_aft"] + inset, t["ama_fwd"] - inset * 1.5, t["ama_half"] - inset, t["ama_half"] * 0.5, cy=side * t["ama_y"], bluff=0.5)


def half_width_at(outline, x):
    """Port half width of a closed mirrored outline at x (linear)."""
    port = [p for p in outline if p[1] <= 0]
    port.sort()
    for (x0, y0), (x1, y1) in zip(port, port[1:]):
        if x0 <= x <= x1:
            f = (x - x0) / (x1 - x0) if x1 > x0 else 0
            return -(y0 + (y1 - y0) * f)
    return 0.0


def tri_lifeline(t):
    """Main hull deck, the nets between the akas and both amas."""
    main = [p for p in tri_main(t, 12) if p[1] <= 0]
    main.sort()
    a0, a1 = t["aka"]
    ay, ah = t["ama_y"], t["ama_half"] - 10
    aft = [p for p in main if p[0] < a0]
    fwd = [p for p in main if p[0] > a1]
    ama = [(t["ama_aft"] + 14, -ay - 6), (t["ama_aft"] + 30, -ay - ah), (t["ama_fwd"] - 80, -ay - ah), (t["ama_fwd"] - 14, -ay - 4)]
    port = aft + [(a0, -half_width_at(tri_main(t, 12), a0)), (a0, -ay + ah), (t["ama_aft"] + 30, -ay + ah)] + ama \
        + [(t["ama_fwd"] - 80, -ay + ah), (a1, -ay + ah), (a1, -half_width_at(tri_main(t, 12), a1))] + fwd
    port = [p for p in port if p[0] < t["bow"] - 20]
    tip = (t["bow"] - 20, 0.0)
    star = [(x, -y) for x, y in reversed(port)]
    return port + [tip] + star


def build_tri_deck_visual(t):
    b = Builder()
    visual_root(b, t["canvas"])
    main = tri_main(t)
    amas = [tri_ama(t, -1), tri_ama(t, 1)]
    a0, a1 = t["aka"]
    ay = t["ama_y"]

    b.slot("ShadowVisual")
    b.poly("HullShadow", "ShadowVisual", offset(main, 8, 12), "#000000", 0.25)
    for i, a in enumerate(amas):
        b.poly(f"AmaShadow{i}", "ShadowVisual", offset(a, 8, 12), "#000000", 0.22)

    b.slot("HullBase")
    for i, side in enumerate((-1, 1)):
        for j, x in enumerate((a0, a1)):
            b.poly(f"Aka{i}{j}", "HullBase", [(x - 16, 0), (x + 16, 0), (x + 16, side * ay), (x - 16, side * ay)], HULL)
    b.poly("MainHull", "HullBase", main, HULL)
    b.line("ToeRail", "HullBase", main, 6, TEAK, closed=True)
    for i, a in enumerate(amas):
        b.poly("PortAma" if i == 0 else "StarboardAma", "HullBase", a, HULL)
        b.line(f"AmaRail{i}", "HullBase", a, 4, TEAK, closed=True)

    b.slot("DeckBase")
    b.poly("DeckSurface", "DeckBase", tri_main(t, 14), NONSKID)
    for i, side in enumerate((-1, 1)):
        inner = half_width_at(main, a0)
        b.poly(f"Net{i}", "DeckBase", [(a0 + 16, side * (inner - 4)), (a1 - 16, side * (inner - 4)),
                                       (a1 - 16, side * (ay - t["ama_half"] + 6)), (a0 + 16, side * (ay - t["ama_half"] + 6))], NET, 0.85)
        for k in range(8):
            x = a0 + 40 + k * 38
            b.line(f"NetLine{i}{k}", "DeckBase", [(x, side * (inner)), (x, side * (ay - 30))], 1, STEEL, 0.25)
        b.poly(f"AmaDeck{i}", "DeckBase", tri_ama(t, side, 8), NONSKID)
    b.poly("Cockpit", "DeckBase", [(-470, -62), (-140, -62), (-140, 62), (-470, 62)], WELL)
    b.shape("BenchPort", "DeckBase", (-300, -72), TEAK, size=(220, 20))
    b.shape("BenchStarboard", "DeckBase", (-300, 72), TEAK, size=(220, 20))
    b.shape("Hatch", "DeckBase", (-142, 0), TEAK_DARK, size=(20, 60))

    b.slot("Coachroof")
    r0, r1 = t["roof"]
    rh = t["roof_half"]
    roof = [(r0, -rh), (r1 - 30, -rh), (r1, -rh + 20), (r1, rh - 20), (r1 - 30, rh), (r0, rh)]
    b.shape("Coachroof", "Coachroof", (0, 0), ROOF, polygon=roof)
    for i, x in enumerate((-70, 0, 70)):
        b.poly(f"Portlight{i}", "Coachroof/Coachroof", [(x - 20, -rh + 4), (x + 20, -rh + 4), (x + 20, -rh + 10), (x - 20, -rh + 10)], GLASS, 0.75)
        b.poly(f"PortlightS{i}", "Coachroof/Coachroof", [(x - 20, rh - 10), (x + 20, rh - 10), (x + 20, rh - 4), (x - 20, rh - 4)], GLASS, 0.75)
    b.poly("ForeHatch", "Coachroof/Coachroof", [(110, -22), (150, -22), (150, 22), (110, 22)], "#A6C4C9", 0.6)

    b.slot("DeckDetails")
    wheel(b, "DeckDetails", -410, 0, 100)
    for i, side in enumerate((-1, 1)):
        b.shape(f"Winch{i}", "DeckDetails", (-170, side * 62), METAL_DARK, polygon=ellipse(0, 0, 9, 9, 10))
        b.shape(f"AmaHatch{i}", "DeckDetails", (60, side * ay), WELL, size=(60, 30))
    b.shape("AnchorLocker", "DeckDetails", (400, 0), WELL, size=(54, 40))
    b.shape("BowRoller", "DeckDetails", (488, 0), METAL, size=(26, 10))
    life = tri_lifeline(t)
    b.line("Lifelines", "DeckDetails", life, 2, STEEL, 0.65, closed=True, z=6)
    b.line("Pulpit", "DeckDetails", [(430, -36), (470, 0), (430, 36)], 4, STEEL, 0.9, z=6)
    b.line("Pushpit", "DeckDetails", [(-470, -80), (-488, -60), (-488, 60), (-470, 80)], 4, STEEL, 0.9, z=6)
    b.node("Labels", "Node2D", "DeckDetails", ["z_index = 5"])
    big = b.label_settings(15, "#102D3B", 0.6)
    small = b.label_settings(13, "#102D3B", 0.55)
    for name, text, pos, st in [("Cockpit", "COCKPIT", (-320, 40), big), ("Helm", "HELM", (-430, -80), small),
                                ("Coachroof", "COACHROOF", (30, 0), small), ("NetPort", "NET", (0, -160), small),
                                ("NetStbd", "NET", (0, 160), small), ("PortAma", "PORT FLOAT", (-150, -ay), small),
                                ("StbdAma", "STARBOARD FLOAT", (-150, ay), small), ("Bow", "BOW", (420, -60), big),
                                ("Mast", "MAST", (200, -30), big)]:
        b.label(name, "DeckDetails/Labels", text, pos, st)

    b.slot("RiggingVisual", z=2)
    mx, my = t["mast"]
    b.line("Shrouds", "RiggingVisual", [(mx - 20, -ay + 10), (mx, my), (mx - 20, ay - 10)], 2, STEEL, 0.8)
    b.line("Forestay", "RiggingVisual", [(mx, my), t["tack"]], 2, STEEL, 0.8)

    b.slot("MastVisual", z=3)
    b.shape("Mast", "MastVisual", t["mast"], "#B9C1C5", polygon=[(16, 0), (6, 8), (-14, 6), (-14, -6), (6, -8)])
    return b


def build_tri_deck(t):
    b = Builder()
    deck_root(b, t["id"], (-520, -290, 1040, 580))
    ay = t["ama_y"]
    surroundings(b, t["pontoon_y"], "GUEST PONTOON · COPENHAGEN",
                 {"SternLine": ((-300, ay + 20), -380), "BowLine": ((340, ay + 20), 380)}, (-380, 380), 0, 210)
    b.node("Visual", None, ".", [], instance=b.res("PackedScene", f"res://src/vessels/{t['id']}/deck_visual.tscn"))
    b.node("Layout", "Node2D", ".")
    b.node("Collision", "Node2D", "Layout")
    b.boundary("Lifeline", [tri_lifeline(t)])
    r0, r1 = t["roof"]
    rh = t["roof_half"]
    b.fixture("Coachroof", (0, 0), polygon=[(r0, -rh), (r1 - 30, -rh), (r1, -rh + 20), (r1, rh - 20), (r1 - 30, rh), (r0, rh)])
    b.fixture("BenchPort", (-300, -72), size=(220, 20))
    b.fixture("BenchStarboard", (-300, 72), size=(220, 20))
    b.fixture("Mast", t["mast"], polygon=ellipse(0, 0, 13, 13, 16))
    b.fixture("Pedestal", (-396, 0), polygon=ellipse(0, 0, 11, 11, 12))
    b.fixture("Wheel", (-410, 0), size=(12, 100))
    b.node("Stations", "Node2D", "Layout")
    b.station("Companionway", (r0 - 18, 0), "companionway", "Go below", ("rect", (36, 100)))
    b.station("Helm", (-440, 0), "helm", "Take the helm", ("circle", 30))
    b.station("Boatyard", (0, ay + 6), "boatyard", "Visit the boatyard", ("rect", (200, 40)))
    b.station("Grocery", (210, ay + 6), "grocery", "Visit the grocery store", ("rect", (120, 40)))
    b.markers("SpawnPoints", {"start": (-300, 0), "from_cabin": (r0 - 45, 0), "from_boatyard": (0, ay - 4)})
    b.markers("SailMarkers", {"Mast": t["mast"], "Tack": t["tack"], "BoomEnd": t["boom_end"], "Traveller": t["traveller"],
                              "JibSheetLead": t["jib_lead"], "SpinnakerSheetLead": t["kite_lead"]})
    deck_tail(b, t["id"], (0, 45), 1.28)
    return b


def tri_cabin_outline(t):
    return [(-430, -78), (-300, -96), (-150, -106), (100, -106), (260, -88), (380, -50), (440, -14), (450, 0),
            (440, 14), (380, 50), (260, 88), (100, 106), (-150, 106), (-300, 96), (-430, 78)]


def build_tri_cabin_visual(t):
    b = Builder()
    visual_root(b, t["canvas"])
    outline = tri_cabin_outline(t)
    b.slot("CabinBase")
    b.poly("HullShape", "CabinBase", tri_main(t), CABIN_HULL)
    for i, side in enumerate((-1, 1)):
        b.poly(f"AmaHint{i}", "CabinBase", tri_ama(t, side), CABIN_HULL, 0.45)
    b.poly("CabinSole", "CabinBase", outline, SOLE)
    for i in range(5):
        y = -80 + i * 40
        b.line(f"Seam{i}", "CabinBase", [(-420, y), (420, y)], 2, "#5E4733", 0.35)
    b.line("CabinSide", "CabinBase", outline, 12, "#5E4733", closed=True)

    b.slot("FurnitureVisual")
    b.shape("EngineBox", "FurnitureVisual", (-412, 0), "#4B5357", size=(30, 70))
    b.shape("CompanionwaySteps", "FurnitureVisual", (-378, 0), "#7A5C40", size=(38, 80))
    for k in range(3):
        b.line(f"Step{k}", "FurnitureVisual/CompanionwaySteps", [(-12 + k * 12, -36), (-12 + k * 12, 36)], 3, "#4A3626", 0.8)
    b.shape("Galley", "FurnitureVisual", (-290, -80), WOOD, size=(110, 28))
    b.poly("Burner0", "FurnitureVisual/Galley", ellipse(-30, 0, 8, 8, 12), "#2A2F33")
    b.poly("Burner1", "FurnitureVisual/Galley", ellipse(-8, 0, 8, 8, 12), "#2A2F33")
    b.poly("Sink", "FurnitureVisual/Galley", [(18, -9), (42, -9), (42, 9), (18, 9)], "#A6C4C9", 0.8)
    b.shape("NavTable", "FurnitureVisual", (-290, 80), WOOD, size=(80, 28))
    b.poly("ChartPaper", "FurnitureVisual/NavTable", [(-30, -10), (26, -10), (26, 10), (-30, 10)], "#EFE5CC", 0.9)
    b.shape("SetteePort", "FurnitureVisual", (0, -88), CUSHION, size=(220, 28), label="SETTEE")
    b.shape("SetteeStbd", "FurnitureVisual", (0, 88), CUSHION, size=(220, 28))
    b.shape("Table", "FurnitureVisual", (0, 0), WOOD, size=(110, 30))
    b.shape("MastPost", "FurnitureVisual", (195, 0), METAL, polygon=ellipse(0, 0, 9, 9, 12))
    b.shape("VBerth", "FurnitureVisual", (0, 0), BLANKET, polygon=[(300, -66), (380, -46), (436, -10), (436, 10), (380, 46), (300, 66)], label="V-BERTH")
    b.poly("Pillow0", "FurnitureVisual/VBerth", [(392, -36), (424, -12), (424, -2), (392, -2)], "#EFE5CC", 0.85)
    b.poly("Pillow1", "FurnitureVisual/VBerth", [(392, 2), (424, 2), (424, 12), (392, 36)], "#EFE5CC", 0.85)
    b.shape("Locker", "FurnitureVisual", (160, 80), WOOD, size=(60, 26))

    b.slot("CabinDetails")
    b.node("Labels", "Node2D", "CabinDetails", ["z_index = 5"])
    big = b.label_settings(15, "#EFE5CC", 0.62)
    small = b.label_settings(13, "#EFE5CC", 0.55)
    for name, text, pos, st in [("Saloon", "SALOON", (90, -40), big), ("Galley", "GALLEY", (-290, -52), small),
                                ("Chart", "NAV STATION", (-290, 52), small), ("Floats", "FLOATS: STORAGE ONLY", (0, 200), small)]:
        b.label(name, "CabinDetails/Labels", text, pos, st)
    return b


def build_tri_cabin(t):
    b = Builder()
    cabin_root(b, (-440, -110, 900, 220))
    b.node("Visual", None, ".", [], instance=b.res("PackedScene", f"res://src/vessels/{t['id']}/cabin_visual.tscn"))
    provision_display(b, (-290, -82))
    b.node("Layout", "Node2D", ".")
    b.node("Collision", "Node2D", "Layout")
    b.boundary("Hull", [tri_cabin_outline(t)])
    b.fixture("EngineBox", (-412, 0), size=(30, 70))
    b.fixture("CompanionwaySteps", (-378, 0), size=(38, 80))
    b.fixture("Galley", (-290, -80), size=(110, 28))
    b.fixture("NavTable", (-290, 80), size=(80, 28))
    b.fixture("SetteePort", (0, -88), size=(220, 28))
    b.fixture("SetteeStbd", (0, 88), size=(220, 28))
    b.fixture("Table", (0, 0), size=(110, 30))
    b.fixture("MastPost", (195, 0), polygon=ellipse(0, 0, 9, 9, 12))
    b.fixture("VBerth", (0, 0), polygon=[(300, -66), (380, -46), (436, -10), (436, 10), (380, 46), (300, 66)])
    b.fixture("Locker", (160, 80), size=(60, 26))
    b.node("Stations", "Node2D", "Layout")
    b.station("Companionway", (-345, 0), "companionway", "Go on deck", ("rect", (30, 80)))
    b.station("Chart", (-290, 52), "nav_table", "Open chart", ("rect", (80, 26)))
    b.station("Provisions", (-290, -54), "provisions", "Check provisions", ("rect", (90, 20)))
    b.station("Work", (0, 26), "work", "Work remotely", ("rect", (100, 20)))
    b.station("Berth", (282, 0), "bed", "Sleep", ("rect", (30, 120)))
    b.markers("SpawnPoints", {"start": (-120, 40), "from_deck": (-322, 0), "v_berth": (258, 0)})
    b.markers("CompanionSpots", {"settee": (-40, -90), "nav_station": (-232, 86), "v_berth": (318, 48),
                                 "cabin_floor": (110, 40), "companionway": (-330, -50), "seating": (-90, 52)})
    cabin_tail(b, (0, 0), 1.5)
    return b


VESSELS = {
    "halcyon_40": (CAT, build_cat_deck_visual, build_cat_deck, build_cat_cabin_visual, build_cat_cabin),
    "petrel_36": (TRI, build_tri_deck_visual, build_tri_deck, build_tri_cabin_visual, build_tri_cabin),
}


def main(argv):
    force = "--force" in argv
    ids = [a for a in argv if not a.startswith("--")] or list(VESSELS)
    for vid in ids:
        spec, deck_visual, deck, cabin_visual, cabin = VESSELS[vid]
        out = os.path.join(ROOT, "src", "vessels", vid)
        os.makedirs(out, exist_ok=True)
        deck_visual(spec).write(os.path.join(out, "deck_visual.tscn"), force)
        deck(spec).write(os.path.join(out, "deck.tscn"), force)
        cabin_visual(spec).write(os.path.join(out, "cabin_visual.tscn"), force)
        cabin(spec).write(os.path.join(out, "cabin.tscn"), force)


if __name__ == "__main__":
    main(sys.argv[1:])
