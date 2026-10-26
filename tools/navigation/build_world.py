"""Builds the worldwide chart (Iteration 16): a coarse navigation raster and route graph
for the whole navigable planet, linked to the existing European chart, plus the drawn land.

Hierarchy (one coordinate system everywhere: WGS 84 longitude/latitude, Mercator rows):

    world  (this script)        12 cells per Mercator degree (5 arc-minutes, ~5 nm), wraps at 180°
      europe (unchanged files)  60 cells per degree, a region of the world (factor 5)
        denmark (unchanged)     360 cells per degree, a region of Europe (factor 6)

The world grid is aligned to the European grid (its west edge at -180°, its Mercator north
a whole number of world rows above Europe's), so Europe is exactly 744 x 847 world cells.
Inside that rectangle the game navigates on the European data; this script leaves Europe's
files untouched and only writes the world level and its link to Europe.

Input:
  OpenStreetMap land polygons as packaged by geo-maps "earth-lands-100m" 0.6.0
  (npm @geo-maps/earth-lands-100m, file package/map.geo.json, package SHA-1
  bcee1e6ce052d9c57bc7a2aa3b39912aaaf43c41). Map data (c) OpenStreetMap contributors, ODbL 1.0.
  UN/LOCODE (UNECE) coordinates for the two ends of the Panama Canal abstraction (below).
  The European chart in data/navigation/ (europe_navmask.*, europe_route_graph.json).

Output, data/navigation/world/:
  world.json      grid metadata, sources, licence, the Europe link geometry, processing notes
  navmask.png     4320 columns x N rows: 255 navigable, 128 approach-only, 0 land
  graph.json      the world route graph outside Europe (nodes as world cells, edges)
  europe_link.json  seam edges between world nodes and European graph nodes
  land.json       drawn land: "overview" (whole world, coarse) and "regional" (outside Europe)

Processing: polygons rasterised at 4x4 subsamples per cell; a cell is land if any subsample
is land, approach-only if land covers at most half of it (the European chart's rule); holes
are filled (lakes are land). Latitudes are limited to 72 S .. 80 N (Mercator rows beyond are
land): no polar navigation. The Panama Canal is not in the land data as water at this scale;
it is represented by a straight two-cell navigable channel between the UN/LOCODE positions
of Colon (PA ONX) and Panama City (PA PTY), extended a few cells into each sea. This is a
deliberate gameplay abstraction of the real canal, not its geometry.

Requires: python3, numpy, scipy, shapely 2, pillow, scikit-image.
Usage: python3 tools/navigation/build_world.py path/to/map.geo.json
"""
import json
import math
import os
import sys
import time
from collections import deque

import numpy as np
from PIL import Image, ImageDraw
from scipy import ndimage
from scipy.spatial import cKDTree
from shapely import make_valid
from shapely.geometry import LineString, Polygon, box
from skimage.morphology import skeletonize

ROOT = os.path.join(os.path.dirname(__file__), "..", "..")
NAV_DIR = os.path.join(ROOT, "data", "navigation")
OUT_DIR = os.path.join(NAV_DIR, "world")

CPD = 12
WEST = -180.0
COLS = 360 * CPD
NORTH_LAT = 80.0
SOUTH_LAT = -72.0
SUPERSAMPLE = 4
EUROPE_FACTOR = 5
# Graph lattice in world cells (coarse to fine) and narrow-water skeleton spacing.
LATTICE = [96, 48, 24, 12]
BAND_OVERLAP = 1.3
SKELETON_GAP = 5
MAX_EDGES_PER_NODE = 10
SEAM_BAND = 12          # world nodes this close (cells) to Europe are linked to it
SEAM_LINKS = 6
NUDGE = 0.01            # float32-safe, as in build_region.py
# Panama Canal abstraction: UN/LOCODE positions (degrees), see the module doc.
CANAL_ATLANTIC = (-(79 + 52 / 60), 9 + 21 / 60)   # Colon, PA ONX 0921N 07952W
CANAL_PACIFIC = (-(79 + 32 / 60), 8 + 58 / 60)    # Panama City, PA PTY 0858N 07932W
CANAL_EXTEND_CELLS = 6
# Drawn land.
OVERVIEW_SIMPLIFY = 0.08
OVERVIEW_MIN_AREA = 0.004
REGIONAL_SIMPLIFY = 0.02
REGIONAL_MIN_AREA = 0.0005
# Islands smaller than that are drawn as dots (display only; the raster keeps them).
ISLET_MIN_AREA = 0.00002
TILE_DEG = 10.0


def merc_y(lat):
    lat = max(min(lat, 85.0), -85.0)
    return math.degrees(math.log(math.tan(math.pi / 4.0 + math.radians(lat) / 2.0)))


def inv_merc(y):
    return math.degrees(2.0 * math.atan(math.exp(math.radians(y))) - math.pi / 2.0)


class World:
    def __init__(self):
        meta = json.load(open(os.path.join(NAV_DIR, "europe_navmask.json")))
        self.e_west = meta["bounds"]["west"]
        self.e_cpd = meta["cells_per_mercator_degree"]
        self.e_north = meta["mercator_north"]
        self.e_cols = meta["columns"]
        self.e_rows = meta["rows"]
        assert self.e_cpd == CPD * EUROPE_FACTOR
        k = math.ceil((merc_y(NORTH_LAT) - self.e_north) * CPD)
        self.north = self.e_north + k / CPD
        self.rows = int(math.ceil((self.north - merc_y(SOUTH_LAT)) * CPD))
        self.cols = COLS
        self.eu_c0 = int(round((self.e_west - WEST) * CPD))
        self.eu_r0 = k
        self.eu_cw = self.e_cols // EUROPE_FACTOR
        self.eu_rh = self.e_rows // EUROPE_FACTOR  # whole world cells only (the last Europe row stays world)
        assert abs((self.e_west - WEST) * CPD - self.eu_c0) < 1e-9

    def cell(self, lon, lat):
        return (lon - WEST) * CPD, (self.north - merc_y(lat)) * CPD

    def geo(self, cx, cy):
        return WEST + cx / CPD, inv_merc(self.north - cy / CPD)

    def in_europe(self, x, y):
        return self.eu_c0 <= x < self.eu_c0 + self.eu_cw and self.eu_r0 <= y < self.eu_r0 + self.eu_rh


# --- Land ------------------------------------------------------------------------------------

def load_land(path):
    t = time.time()
    data = json.load(open(path))
    polys = []
    for poly in data["geometries"][0]["coordinates"]:
        exterior = poly[0]  # holes filled: lakes are land
        if len(exterior) >= 4:
            p = Polygon(exterior)
            if not p.is_valid:
                p = p.buffer(0)
                p = max(getattr(p, "geoms", [p]), key=lambda g: g.area) if not p.is_empty else p
            if isinstance(p, Polygon) and not p.is_empty:
                polys.append(p)
    print("land polygons", len(polys), "loaded in %.1f s" % (time.time() - t), flush=True)
    return polys


def rasterize(world, polygons):
    s = SUPERSAMPLE
    w, h = world.cols * s, world.rows * s
    image = Image.new("1", (w, h), 0)
    draw = ImageDraw.Draw(image)
    for poly in polygons:
        pts = []
        for lon, lat in poly.exterior.coords:
            x, y = world.cell(lon, lat)
            pts.append((x * s, y * s))
        if len(pts) >= 3:
            draw.polygon(pts, fill=1, outline=1)
    fine = np.array(image, dtype=bool)
    del image
    land_count = fine.reshape(world.rows, s, world.cols, s).sum(axis=(1, 3), dtype=np.uint8)
    del fine
    mask = np.full((world.rows, world.cols), 255, dtype=np.uint8)
    land_any = land_count > 0
    approach = land_any & (land_count * 2 <= s * s)
    mask[land_any] = 0
    mask[approach] = 128
    return mask


def carve_canal(world, mask):
    """The Panama Canal abstraction: a two-cell navigable channel between the UN/LOCODE positions."""
    ax, ay = world.cell(*CANAL_ATLANTIC)
    bx, by = world.cell(*CANAL_PACIFIC)
    dx, dy = bx - ax, by - ay
    length = math.hypot(dx, dy)
    ux, uy = dx / length, dy / length
    ax -= ux * CANAL_EXTEND_CELLS
    ay -= uy * CANAL_EXTEND_CELLS
    bx += ux * CANAL_EXTEND_CELLS
    by += uy * CANAL_EXTEND_CELLS
    steps = int(math.hypot(bx - ax, by - ay) * 8) + 1
    carved = set()
    for i in range(steps + 1):
        t = i / steps
        x = int(math.floor(ax + (bx - ax) * t))
        y = int(math.floor(ay + (by - ay) * t))
        for cx, cy in ((x, y), (x + 1, y), (x, y + 1), (x + 1, y + 1)):
            carved.add((cx % world.cols, cy))
    for cx, cy in carved:
        mask[cy, cx] = 255
    print("canal cells carved", len(carved), flush=True)
    return [(round(CANAL_ATLANTIC[0], 4), round(CANAL_ATLANTIC[1], 4)), (round(CANAL_PACIFIC[0], 4), round(CANAL_PACIFIC[1], 4))]


# --- Line checks (mirror NavGrid.is_line_clear with wrapping columns) ----------------------

def segment_clear(ok, x0, y0, x1, y1, wrap):
    rows, cols = ok.shape

    def at(x, y):
        if wrap:
            x %= cols
        return 0 <= x < cols and 0 <= y < rows and ok[y, x]
    ix, iy = math.floor(x0), math.floor(y0)
    ex, ey = math.floor(x1), math.floor(y1)
    if not at(ix, iy):
        return False
    dx, dy = x1 - x0, y1 - y0
    step_x = 1 if dx > 0 else (-1 if dx < 0 else 0)
    step_y = 1 if dy > 0 else (-1 if dy < 0 else 0)
    t_delta_x = abs(1.0 / dx) if dx != 0 else math.inf
    t_delta_y = abs(1.0 / dy) if dy != 0 else math.inf
    t_max_x = ((ix + 1 - x0) if dx > 0 else (x0 - ix)) * t_delta_x if dx != 0 else math.inf
    t_max_y = ((iy + 1 - y0) if dy > 0 else (y0 - iy)) * t_delta_y if dy != 0 else math.inf
    guard = abs(ex - ix) + abs(ey - iy) + 2
    while (ix != ex or iy != ey) and guard > 0:
        guard -= 1
        if abs(t_max_x - t_max_y) < 1e-9:
            if not at(ix + step_x, iy) or not at(ix, iy + step_y):
                return False
            ix += step_x
            iy += step_y
            t_max_x += t_delta_x
            t_max_y += t_delta_y
        elif t_max_x < t_max_y:
            ix += step_x
            t_max_x += t_delta_x
        else:
            iy += step_y
            t_max_y += t_delta_y
        if not at(ix, iy):
            return False
    return True


def clip_t(ax, ay, bx, by, x0, y0, x1, y1):
    t0, t1 = 0.0, 1.0
    dx, dy = bx - ax, by - ay
    for p, q in ((-dx, ax - x0), (dx, x1 - ax), (-dy, ay - y0), (dy, y1 - ay)):
        if p == 0:
            if q < 0:
                return None
            continue
        r = q / p
        if p < 0:
            t0 = max(t0, r)
        else:
            t1 = min(t1, r)
        if t0 > t1:
            return None
    return t0, t1


def composite_clear(world, world_ok, europe_ok, ax, ay, bx, by):
    """A line in world cells: the part inside Europe on the European raster (whole Europe cells,
    as NavGrid.is_geo_line_clear does), the rest on the world raster. The start point is taken
    in [0, cols) so the Europe rectangle is found without wrapping."""
    shift = math.floor(ax / world.cols) * world.cols
    ax, bx = ax - shift, bx - shift
    x0, y0 = world.eu_c0, world.eu_r0
    x1, y1 = x0 + world.eu_cw, y0 + world.eu_rh
    clip = clip_t(ax, ay, bx, by, x0, y0, x1, y1)
    if clip is None or clip[1] - clip[0] <= 1e-12:
        return segment_clear(world_ok, ax, ay, bx, by, True)
    t0, t1 = clip
    length = math.hypot(bx - ax, by - ay)
    ux, uy = (bx - ax) / length, (by - ay) / length

    def point(t):
        return ax + (bx - ax) * t, ay + (by - ay) * t
    if t0 > 0.0:
        px, py = point(t0)
        if not segment_clear(world_ok, ax, ay, px - ux * NUDGE, py - uy * NUDGE, True):
            return False
    if t1 < 1.0:
        px, py = point(t1)
        if not segment_clear(world_ok, px + ux * NUDGE, py + uy * NUDGE, bx, by, True):
            return False
    rows, cols = europe_ok.shape
    lim_x = world.eu_cw * EUROPE_FACTOR - 0.001
    lim_y = world.eu_rh * EUROPE_FACTOR - 0.001
    p0, p1 = point(t0), point(t1)
    f0 = (min(max((p0[0] - x0) * EUROPE_FACTOR + ux * NUDGE, 0.0), lim_x), min(max((p0[1] - y0) * EUROPE_FACTOR + uy * NUDGE, 0.0), lim_y))
    f1 = (min(max((p1[0] - x0) * EUROPE_FACTOR - ux * NUDGE, 0.0), lim_x), min(max((p1[1] - y0) * EUROPE_FACTOR - uy * NUDGE, 0.0), lim_y))
    return segment_clear(europe_ok, f0[0], f0[1], f1[0], f1[1], False)


# --- Graph -----------------------------------------------------------------------------------

def wrapped_edt(water):
    pad = 256
    padded = np.concatenate([water[:, -pad:], water, water[:, :pad]], axis=1)
    return ndimage.distance_transform_edt(padded)[:, pad:-pad]


def build_graph(world, water, world_ok, europe_ok):
    rows, cols = water.shape
    clearance = wrapped_edt(water)
    nodes = {}

    def add(cx, cy, spacing):
        if (cx, cy) not in nodes:
            nodes[(cx, cy)] = spacing

    for level, spacing in enumerate(LATTICE):
        offset = spacing // 2
        ys, xs = np.mgrid[offset:rows:spacing, offset:cols:spacing]
        c = clearance[ys, xs]
        ok = c >= 0.6 * spacing
        if level > 0:
            ok &= c < 0.6 * LATTICE[level - 1] * BAND_OVERLAP
        for y, x in zip(ys[ok], xs[ok]):
            add(int(x), int(y), spacing)
    pad = 64
    padded = np.concatenate([water[:, -pad:], water, water[:, :pad]], axis=1)
    skeleton = skeletonize(padded)[:, pad:-pad] & (clearance < 0.6 * LATTICE[-1] * BAND_OVERLAP)
    ys, xs = np.nonzero(skeleton)
    grid = {}
    for idx in np.lexsort((xs, ys)):
        x, y = int(xs[idx]), int(ys[idx])
        key = (x // SKELETON_GAP, y // SKELETON_GAP)
        near = False
        for gx in (key[0] - 1, key[0], key[0] + 1):
            for gy in (key[1] - 1, key[1], key[1] + 1):
                for (px, py) in grid.get((gx % (cols // SKELETON_GAP + 1), gy), ()):
                    ddx = min(abs(px - x), cols - abs(px - x))
                    if ddx * ddx + (py - y) ** 2 < SKELETON_GAP ** 2:
                        near = True
        if not near:
            grid.setdefault(key, []).append((x, y))
            add(x, y, SKELETON_GAP)
    print("graph nodes", len(nodes), flush=True)
    keys = list(nodes.keys())
    pts = np.array([[x + 0.5, y + 0.5] for x, y in keys])
    spacing = np.array([nodes[k] for k in keys], dtype=float)
    # KD-tree over the points and their copies one world width either side (wrapping).
    copies = np.concatenate([pts, pts + [cols, 0], pts - [cols, 0]])
    tree = cKDTree(copies)
    n = len(pts)
    edges = set()
    t = time.time()
    for i, (p, s) in enumerate(zip(pts, spacing)):
        candidates = tree.query_ball_point(p, max(2.6 * s, 8.0))
        candidates.sort(key=lambda j: (copies[j][0] - p[0]) ** 2 + (copies[j][1] - p[1]) ** 2)
        made = 0
        for j in candidates:
            k = j % n
            if k == i:
                continue
            if made >= MAX_EDGES_PER_NODE:
                break
            a, b = (i, k) if i < k else (k, i)
            if (a, b) in edges:
                made += 1
                continue
            q = copies[j]
            if composite_clear(world, world_ok, europe_ok, p[0], p[1], q[0], q[1]):
                edges.add((a, b))
                made += 1
        if i % 5000 == 0:
            print("  edges for", i, "nodes, %.0f s" % (time.time() - t), flush=True)
    print("graph edges", len(edges), flush=True)
    return stitch(world, water, keys, edges, world_ok, europe_ok)


def stitch(world, water, keys, edges, world_ok, europe_ok):
    """Joins graph pieces lying in the same body of water (as build_region.stitch, wrapping)."""
    rows, cols = water.shape
    pad = 2
    padded = np.concatenate([water[:, -pad:], water, water[:, :pad]], axis=1)
    lab, _ = ndimage.label(padded)
    lab = lab[:, pad:-pad]
    # Bodies touching at the wrap seam are one body.
    alias = {}

    def body(v):
        while v in alias:
            v = alias[v]
        return v
    for y in range(rows):
        a, b = lab[y, 0], lab[y, cols - 1]
        if a and b and body(a) != body(b):
            alias[body(a)] = body(b)
    index = {k: i for i, k in enumerate(keys)}
    keys = list(keys)
    edges = set(edges)
    parent = list(range(len(keys)))

    def find(a):
        while parent[a] != a:
            parent[a] = parent[parent[a]]
            a = parent[a]
        return a

    for a, b in edges:
        parent[find(a)] = find(b)

    def add_node(c):
        if c in index:
            return index[c]
        index[c] = len(keys)
        keys.append(c)
        parent.append(len(parent))
        return index[c]
    stitched = 0
    for _round in range(20):
        groups = {}
        for i, (x, y) in enumerate(keys):
            groups.setdefault((body(lab[y, x]), find(i)), []).append(i)
        by_body = {}
        for (bd, root), members in groups.items():
            by_body.setdefault(bd, []).append(members)
        todo = [sorted(m, key=len)[0] for m in by_body.values() if len(m) > 1]
        if not todo:
            break
        progressed = False
        for members in todo:
            root = find(members[0])
            start = [keys[i] for i in members]
            prev = {c: None for c in start}
            queue = deque(start)
            target = None
            while queue:
                c = queue.popleft()
                j = index.get(c)
                if j is not None and find(j) != root:
                    target = c
                    break
                x, y = c
                for nx, ny in ((x + 1, y), (x - 1, y), (x, y + 1), (x, y - 1)):
                    nx %= cols
                    if 0 <= ny < rows and (nx, ny) not in prev and water[ny, nx]:
                        prev[(nx, ny)] = c
                        queue.append((nx, ny))
            if target is None:
                continue
            chain = []
            c = target
            while c is not None:
                chain.append(c)
                c = prev[c]
            # Nodes along the chain, as far apart (up to 3 cells) as a line between them
            # stays clear by the same check the game uses (no cutting a land corner).
            picked = [chain[0]]
            i = 0
            while i < len(chain) - 1:
                step = 1
                for k in (3, 2):
                    if i + k < len(chain) and composite_clear(world, world_ok, europe_ok, chain[i][0] + 0.5, chain[i][1] + 0.5,
                                                              chain[i + k][0] + 0.5, chain[i + k][1] + 0.5):
                        step = k
                        break
                i += step
                picked.append(chain[i])
            ids = [add_node(c) for c in picked]
            for a, b in zip(ids, ids[1:]):
                if a != b:
                    edges.add((min(a, b), max(a, b)))
                    parent[find(a)] = find(b)
            stitched += 1
            progressed = True
        if not progressed:
            break
    print("stitched", stitched, "graph pieces", flush=True)
    return keys, edges


def europe_seams(world, keys, world_ok, europe_ok):
    graph = json.load(open(os.path.join(NAV_DIR, "europe_route_graph.json")))
    en = graph["nodes"]
    epts = np.array([[world.eu_c0 + (en[i] + 0.5) / EUROPE_FACTOR, world.eu_r0 + (en[i + 1] + 0.5) / EUROPE_FACTOR]
                     for i in range(0, len(en), 2)])
    tree = cKDTree(epts)
    x0, y0 = world.eu_c0, world.eu_r0
    x1, y1 = x0 + world.eu_cw, y0 + world.eu_rh
    seams = []
    for i, (x, y) in enumerate(keys):
        px, py = x + 0.5, y + 0.5
        dx = max(x0 - px, 0.0, px - x1)
        dy = max(y0 - py, 0.0, py - y1)
        if math.hypot(dx, dy) > SEAM_BAND:
            continue
        made = 0
        for d, j in zip(*tree.query([px, py], k=40, distance_upper_bound=SEAM_BAND * 2.0)):
            if not math.isfinite(d) or made >= SEAM_LINKS:
                break
            if composite_clear(world, world_ok, europe_ok, px, py, epts[j][0], epts[j][1]):
                seams.append([x, y, int(j)])
                made += 1
    print("europe seam links", len(seams), flush=True)
    return seams


# --- Display ---------------------------------------------------------------------------------

def ring(coords, nd=4):
    out = [[round(x, nd), round(y, nd)] for x, y in coords]
    if len(out) > 1 and out[0] == out[-1]:
        out.pop()
    return out


def fill_rings(polygon, nd):
    """Rounded rings of a polygon that stay valid (rounding can make a ring cross itself,
    which the game cannot triangulate): invalid ones are repaired and split."""
    r = ring(polygon.exterior.coords, nd)
    if len(r) < 3:
        return []
    if Polygon(r).area < 1e-7:
        return []  # a sliver after rounding: nothing to draw
    if Polygon(r).is_valid:
        return [r]
    result = []
    for q in _polygons_of(make_valid(Polygon(r))):
        rr = ring(q.exterior.coords, nd)
        if len(rr) >= 3 and Polygon(rr).is_valid and Polygon(rr).area >= 1e-7:
            result.append(rr)
    return result


def layer(polygons, tolerance, min_area, clip_out=None, tile_deg=TILE_DEG, nd=4, floor=0.002):
    """Simplified land, tiled for cheap drawing; `clip_out` (a box) is cut away. Small islands
    are simplified less (tolerance at most a tenth of their size), so they keep their shape;
    coastlines never include the cut edge."""
    fill, coast = [], []
    for poly in polygons:
        if poly.area < min_area:
            continue
        tol = min(tolerance, max(math.sqrt(poly.area) * 0.08, floor))
        p = poly.simplify(tol, preserve_topology=True)
        if not p.is_valid:
            p = make_valid(p)
        if p.is_empty:
            continue
        lines = [LineString(g.exterior.coords) for g in getattr(p, "geoms", [p]) if isinstance(g, Polygon)]
        if clip_out is not None and p.intersects(clip_out):
            p = p.difference(clip_out)
            lines = [line.difference(clip_out) for line in lines]
        for line in lines:
            for part in getattr(line, "geoms", [line]):
                if isinstance(part, LineString) and len(part.coords) >= 2:
                    coast.append(ring(part.coords, nd) if not part.is_closed else ring(part.coords, nd) + [ring(part.coords, nd)[0]])
        for g in getattr(p, "geoms", [p]):
            if not isinstance(g, Polygon) or g.area < min_area * 0.5:
                continue
            if len(g.exterior.coords) < 4:
                continue
            minx, miny, maxx, maxy = g.bounds
            if maxx - minx <= tile_deg and maxy - miny <= tile_deg:
                fill.extend(fill_rings(g, nd))
                continue
            x = math.floor(minx / tile_deg) * tile_deg
            while x < maxx:
                y = math.floor(miny / tile_deg) * tile_deg
                while y < maxy:
                    piece = make_valid(g).intersection(box(x, y, x + tile_deg, y + tile_deg))
                    for q in _polygons_of(piece):
                        if q.area > 1e-9:
                            fill.extend(fill_rings(q, nd))
                    y += tile_deg
                x += tile_deg
    points = sum(len(r) for r in fill)
    print("  layer: %d fill rings, %d points; %d coast lines" % (len(fill), points, len(coast)), flush=True)
    return {"fill_tiles": fill, "coast": coast}


def _polygons_of(geom):
    if isinstance(geom, Polygon):
        return [geom]
    result = []
    for g in getattr(geom, "geoms", []):
        result.extend(_polygons_of(g))
    return result


def islets(polygons, clip_out):
    """Centres of the islands too small to draw as land (shown as dots)."""
    dots = []
    for poly in polygons:
        if ISLET_MIN_AREA <= poly.area < REGIONAL_MIN_AREA:
            c = poly.centroid
            if not clip_out.contains(c):
                dots.append([round(c.x, 3), round(c.y, 3)])
    print("  islets:", len(dots), flush=True)
    return dots


def main():
    t0 = time.time()
    os.makedirs(OUT_DIR, exist_ok=True)
    world = World()
    print("world grid %d x %d, Europe at %d,%d size %dx%d" % (world.cols, world.rows, world.eu_c0, world.eu_r0,
                                                              world.eu_cw, world.eu_rh), flush=True)
    polygons = load_land(sys.argv[1])
    mask = rasterize(world, polygons)
    canal = carve_canal(world, mask)
    Image.fromarray(mask, mode="L").save(os.path.join(OUT_DIR, "navmask.png"), optimize=True)
    europe_mask = np.array(Image.open(os.path.join(NAV_DIR, "europe_navmask.png")).convert("L"))
    europe_ok = europe_mask == 255
    world_ok = mask == 255
    water = world_ok.copy()
    water[world.eu_r0:world.eu_r0 + world.eu_rh, world.eu_c0:world.eu_c0 + world.eu_cw] = False
    keys, edges = build_graph(world, water, world_ok, europe_ok)
    seams = europe_seams(world, keys, world_ok, europe_ok)
    flat_nodes = [v for k in keys for v in k]
    flat_edges = [v for e in sorted(edges) for v in e]
    json.dump({"nodes": flat_nodes, "edges": flat_edges}, open(os.path.join(OUT_DIR, "graph.json"), "w"), separators=(",", ":"))
    json.dump({"seam": seams}, open(os.path.join(OUT_DIR, "europe_link.json"), "w"), separators=(",", ":"))
    # Drawn land.
    europe_box = box(world.e_west, inv_merc(world.e_north - world.e_rows / world.e_cpd),
                     world.e_west + world.e_cols / world.e_cpd, inv_merc(world.e_north))
    labels = json.load(open(os.path.join(os.path.dirname(__file__), "world_labels.json")))["labels"]
    land = {
        "overview": layer(polygons, OVERVIEW_SIMPLIFY, OVERVIEW_MIN_AREA, nd=3, floor=0.01),
        "regional": layer(polygons, REGIONAL_SIMPLIFY, REGIONAL_MIN_AREA, clip_out=europe_box),
        "islets": islets(polygons, europe_box),
        "labels": labels,
    }
    json.dump(land, open(os.path.join(OUT_DIR, "land.json"), "w"), separators=(",", ":"))
    meta = {
        "id": "world", "name": "The world",
        "source": "OpenStreetMap land polygons via geo-maps earth-lands-100m 0.6.0 (npm @geo-maps/earth-lands-100m, "
                  "about 100 m accuracy). Map data (c) OpenStreetMap contributors, ODbL 1.0, "
                  "openstreetmap.org/copyright. Package code MIT.",
        "retrieved": "2026-10-25",
        "licence": "ODbL 1.0 (derived database: the world raster, graph and land are ODbL too)",
        "canal": {"note": "Panama Canal abstraction: a straight two-cell navigable channel between the UN/LOCODE "
                          "positions of Colon (PA ONX) and Panama City (PA PTY), not the canal's geometry. "
                          "UN/LOCODE: UNECE.", "ends": canal},
        "crs": "WGS 84 longitude/latitude (EPSG:4326); raster in Mercator rows aligned to the European chart",
        "processing": ("4x4 subsamples per cell; land if any subsample is land, approach-only if land covers at most "
                       "half the cell; holes filled; latitudes %g..%g; drawn land simplified %.3f deg (overview) and "
                       "%.3f deg (regional). Not for navigation.") % (SOUTH_LAT, NORTH_LAT, OVERVIEW_SIMPLIFY, REGIONAL_SIMPLIFY),
        "columns": world.cols, "rows": world.rows, "cells_per_mercator_degree": CPD,
        "bounds": {"west": WEST, "east": WEST + 360.0, "south": SOUTH_LAT, "north": NORTH_LAT},
        "mercator_north": world.north, "wraps": True,
        "europe": {"base_cells": {"column": world.eu_c0, "row": world.eu_r0, "columns": world.eu_cw, "rows": world.eu_rh},
                   "factor": EUROPE_FACTOR},
        "europe_detail_from_px_per_degree": 9.0,
        "graph": {"nodes": len(keys), "edges": len(edges), "europe_seams": len(seams)},
    }
    json.dump(meta, open(os.path.join(OUT_DIR, "world.json"), "w"), indent=1)
    print("done in %.0f s" % (time.time() - t0), flush=True)


if __name__ == "__main__":
    main()
