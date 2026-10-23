"""Builds the European chart and navigation data for Next Harbor.

Input:  Natural Earth 1:10m land polygons (public domain), GeoJSON:
        https://raw.githubusercontent.com/nvkelso/natural-earth-vector/master/geojson/ne_10m_land.geojson
Output (in data/navigation/):
  europe_land.json      display polygons (lon/lat), plus a tiled copy for fast filling
  europe_navmask.png    raster in Mercator space: 255 = navigable water, 128 = water usable
                        only for harbour approaches, 0 = land
  europe_navmask.json   raster georeference (bounds, cells per Mercator degree)
  europe_route_graph.json  sparse sea-route graph (nodes = raster cells, edges = clear lines)

The raster and the graph are both derived from exactly the polygons that the
chart draws, so the game never routes across land it shows. Land is marked
conservatively: a cell counts as land if land covers any part of it (tested at
1/4-cell precision), so a straight line that only touches water cells never
touches a drawn coastline.

Every graph edge is checked with the same supercover line traversal that the
game uses at runtime (SeaRouter.is_segment_navigable), so the two always agree.

Requires: python3, numpy, scipy, shapely, pillow, scikit-image.
Usage:    python3 tools/navigation/build_navigation_data.py path/to/ne_10m_land.geojson
"""
import json
import math
import os
import sys

import numpy as np
from PIL import Image, ImageDraw
from scipy import ndimage
from scipy.spatial import cKDTree
from shapely.geometry import MultiPolygon, Polygon, box, shape
from shapely.ops import unary_union
from shapely.validation import make_valid
from skimage.morphology import skeletonize

# --- Region and resolution ------------------------------------------------------------
WEST, EAST, SOUTH, NORTH = -25.0, 37.0, 33.0, 72.0
CELLS_PER_DEGREE = 60          # per Mercator degree: ~1.9 km E-W everywhere, ~1.1 km N-S at 55 N
SUPERSAMPLE = 4                # land coverage tested at 1/4-cell precision
SIMPLIFY_DEG = 0.0035          # display/navigation polygon simplification
MIN_ISLAND_SQ_DEG = 0.0002     # islets smaller than ~1-2 km^2 are dropped (from chart AND raster)
TILE_DEG = 4.0                 # fill tiles keep Godot's polygon triangulation cheap

OUT_DIR = os.path.join(os.path.dirname(__file__), "..", "..", "data", "navigation")


def merc_y(lat):
    return math.degrees(math.log(math.tan(math.pi / 4.0 + math.radians(lat) / 2.0)))


MY_NORTH = merc_y(NORTH)
MY_SOUTH = merc_y(SOUTH)
COLS = int(round((EAST - WEST) * CELLS_PER_DEGREE))
ROWS = int(math.ceil((MY_NORTH - MY_SOUTH) * CELLS_PER_DEGREE))


def to_cell(lon, lat):
    return (lon - WEST) * CELLS_PER_DEGREE, (MY_NORTH - merc_y(lat)) * CELLS_PER_DEGREE


def to_geo(cx, cy):
    lon = WEST + cx / CELLS_PER_DEGREE
    my = math.radians(MY_NORTH - cy / CELLS_PER_DEGREE)
    lat = math.degrees(2.0 * math.atan(math.exp(my)) - math.pi / 2.0)
    return lon, lat


# --- 1. Polygons -------------------------------------------------------------------------
def load_land(path):
    region = box(WEST, SOUTH, EAST, NORTH)
    parts = []
    for feature in json.load(open(path))["features"]:
        geom = shape(feature["geometry"])
        if geom.intersects(region):
            parts.append(make_valid(geom).intersection(region))
    land = unary_union(parts).simplify(SIMPLIFY_DEG, preserve_topology=True)
    land = make_valid(land)
    polygons = []
    for geom in getattr(land, "geoms", [land]):
        for poly in getattr(geom, "geoms", [geom]):
            if isinstance(poly, Polygon) and poly.area >= MIN_ISLAND_SQ_DEG:
                polygons.append(Polygon(poly.exterior))  # lakes (holes) count as land
    return polygons


def ring_coords(poly):
    return [[round(x, 4), round(y, 4)] for x, y in list(poly.exterior.coords)[:-1]]


def tile(polygons):
    tiles = []
    lon = WEST
    while lon < EAST:
        lat = SOUTH
        while lat < NORTH:
            cell = box(lon, lat, min(lon + TILE_DEG, EAST), min(lat + TILE_DEG, NORTH))
            for poly in polygons:
                if not poly.intersects(cell):
                    continue
                piece = poly.intersection(cell)
                for g in getattr(piece, "geoms", [piece]):
                    if isinstance(g, Polygon) and g.area > 1e-7:
                        coords = ring_coords(g)
                        if len(coords) >= 3:
                            tiles.append(coords)
            lat += TILE_DEG
        lon += TILE_DEG
    return tiles


# --- 2. Raster -----------------------------------------------------------------------------
def rasterize(rings):
    """Returns (navigable, approach): navigable water is conservative (any land in
    the cell makes it land); approach water only needs a water majority and is
    used solely for bounded harbour approaches."""
    s = SUPERSAMPLE
    image = Image.new("1", (COLS * s, ROWS * s), 0)
    draw = ImageDraw.Draw(image)
    for ring in rings:
        pts = []
        for lon, lat in ring:
            cx, cy = to_cell(lon, lat)
            pts.append((cx * s, cy * s))
        draw.polygon(pts, fill=1, outline=1)
    fine = np.array(image, dtype=bool).reshape(ROWS, s, COLS, s)
    land = fine.any(axis=(1, 3))
    approach = fine.sum(axis=(1, 3)) * 2 <= s * s
    approach[0, :] = approach[-1, :] = False
    approach[:, 0] = approach[:, -1] = False
    # The region border is treated as land: routes stay inside the chart.
    land[0, :] = land[-1, :] = True
    land[:, 0] = land[:, -1] = True
    return ~land, approach | ~land


# --- 3. Supercover line traversal (mirrors SeaRouter.is_segment_navigable) ------------
def segment_clear(water, x0, y0, x1, y1):
    ix, iy = math.floor(x0), math.floor(y0)
    ex, ey = math.floor(x1), math.floor(y1)
    if not water[iy, ix]:
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
            # Passing exactly through a corner: both side cells must be water.
            if not water[iy, ix + step_x] or not water[iy + step_y, ix]:
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
        if not water[iy, ix]:
            return False
    return True


# --- 4. Graph -------------------------------------------------------------------------------
# Lattice spacings in cells, coarse to fine. A lattice point becomes a node when its
# clearance (distance to land, in cells) lies in its level's band, so open water
# gets a few coarse nodes and node density only increases close to land.
LATTICE = [128, 64, 32, 16, 8]
BAND_OVERLAP = 1.3
SKELETON_GAP = 4
MAX_EDGES_PER_NODE = 12


def build_graph(water):
    clearance = ndimage.distance_transform_edt(water)
    nodes = {}  # (cx, cy) -> spacing

    def add(cx, cy, spacing):
        if (cx, cy) not in nodes:
            nodes[(cx, cy)] = spacing

    for level, spacing in enumerate(LATTICE):
        offset = spacing // 2
        ys, xs = np.mgrid[offset:ROWS:spacing, offset:COLS:spacing]
        c = clearance[ys, xs]
        ok = c >= 0.6 * spacing
        if level > 0:
            ok &= c < 0.6 * LATTICE[level - 1] * BAND_OVERLAP
        for y, x in zip(ys[ok], xs[ok]):
            add(int(x), int(y), spacing)

    # Narrow water (straits, fjords, sounds): sample the medial axis.
    skeleton = skeletonize(water) & (clearance < 0.6 * LATTICE[-1] * BAND_OVERLAP)
    ys, xs = np.nonzero(skeleton)
    order = np.lexsort((xs, ys))
    min_gap = SKELETON_GAP
    grid = {}
    for idx in order:
        x, y = int(xs[idx]), int(ys[idx])
        key = (x // min_gap, y // min_gap)
        near = False
        for gx in (key[0] - 1, key[0], key[0] + 1):
            for gy in (key[1] - 1, key[1], key[1] + 1):
                for (px, py) in grid.get((gx, gy), ()):
                    if (px - x) ** 2 + (py - y) ** 2 < min_gap ** 2:
                        near = True
        if not near:
            grid.setdefault(key, []).append((x, y))
            add(x, y, SKELETON_GAP)

    keys = list(nodes.keys())
    pts = np.array([[x + 0.5, y + 0.5] for x, y in keys])
    spacing = np.array([nodes[k] for k in keys], dtype=float)
    tree = cKDTree(pts)
    edges = set()
    for i, (p, s) in enumerate(zip(pts, spacing)):
        radius = max(2.6 * s, 8.0)
        candidates = tree.query_ball_point(p, radius)
        candidates.sort(key=lambda j: (pts[j][0] - p[0]) ** 2 + (pts[j][1] - p[1]) ** 2)
        made = 0
        for j in candidates:
            if j == i:
                continue
            if made >= MAX_EDGES_PER_NODE:
                break
            a, b = (i, j) if i < j else (j, i)
            if (a, b) in edges:
                made += 1
                continue
            if segment_clear(water, p[0], p[1], pts[j][0], pts[j][1]):
                edges.add((a, b))
                made += 1
    keys, edges = stitch_components(water, keys, edges)
    return keys, sorted(edges), clearance


def stitch_components(water, keys, edges):
    """Joins graph pieces that lie in the same body of water, so the graph is
    connected exactly where the raster is. For each smaller piece, a
    breadth-first search through navigable cells finds the nearest node of
    another piece; the found channel is shortened with clear lines and added
    as new nodes and edges."""
    from collections import deque
    labels, _ = ndimage.label(water)
    index = {k: i for i, k in enumerate(keys)}
    keys = list(keys)
    edges = set(edges)
    parent = list(range(len(keys)))

    def find(a):
        while parent[a] != a:
            parent[a] = parent[parent[a]]
            a = parent[a]
        return a

    def union(a, b):
        parent[find(a)] = find(b)

    for a, b in edges:
        union(a, b)

    def add_node(cell):
        if cell in index:
            return index[cell]
        index[cell] = len(keys)
        keys.append(cell)
        parent.append(len(parent))
        return index[cell]

    stitched = 0
    while True:
        groups = {}
        for i, (x, y) in enumerate(keys):
            groups.setdefault((labels[y, x], find(i)), []).append(i)
        by_body = {}
        for (body, root), members in groups.items():
            by_body.setdefault(body, []).append(members)
        todo = [sorted(m, key=len)[0] for m in by_body.values() if len(m) > 1]
        if not todo:
            break
        for members in todo:
            root = find(members[0])
            if all(find(i) != root for i in members):
                continue
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
                for n in ((x + 1, y), (x - 1, y), (x, y + 1), (x, y - 1)):
                    if n not in prev and water[n[1], n[0]]:
                        prev[n] = c
                        queue.append(n)
            if target is None:
                continue
            chain = []
            c = target
            while c is not None:
                chain.append(c)
                c = prev[c]
            # chain: other piece ... this piece; shorten with clear lines.
            anchor = 0
            pts = [chain[0]]
            while anchor < len(chain) - 1:
                reach = anchor + 1
                while reach + 1 < len(chain) and segment_clear(
                        water, chain[anchor][0] + .5, chain[anchor][1] + .5, chain[reach + 1][0] + .5, chain[reach + 1][1] + .5):
                    reach += 1
                pts.append(chain[reach])
                anchor = reach
            ids = [add_node(c) for c in pts]
            for a, b in zip(ids, ids[1:]):
                if a != b:
                    edges.add((min(a, b), max(a, b)))
                    union(a, b)
            stitched += 1
    print("stitched", stitched, "graph pieces into their water bodies")
    return keys, edges


def main():
    source = sys.argv[1]
    print("loading", source)
    polygons = load_land(source)
    rings = [ring_coords(p) for p in polygons]
    print(len(rings), "polygons,", sum(len(r) for r in rings), "points")
    tiles = tile(polygons)
    print(len(tiles), "fill tiles,", sum(len(t) for t in tiles), "points")

    water, approach = rasterize(rings)
    print("raster", COLS, "x", ROWS, "water cells", int(water.sum()))
    labels, count = ndimage.label(water)  # 4-connected, matching the line traversal
    print(count, "separate water bodies")

    keys, edges, _ = build_graph(water)
    print(len(keys), "graph nodes,", len(edges), "edges")

    # Report graph connectivity per water body.
    parent = list(range(len(keys)))

    def find(a):
        while parent[a] != a:
            parent[a] = parent[parent[a]]
            a = parent[a]
        return a

    for a, b in edges:
        parent[find(a)] = find(b)
    comps = {}
    for i in range(len(keys)):
        comps.setdefault(find(i), []).append(i)
    sizes = sorted((len(v) for v in comps.values()), reverse=True)
    print("graph components (largest 10):", sizes[:10], "total", len(sizes))

    os.makedirs(OUT_DIR, exist_ok=True)
    meta = {
        "source": "Natural Earth 1:10m Land (ne_10m_land), public domain, naturalearthdata.com",
        "processing": ("Clipped to bounds, simplified %.4f deg, islets < %.4f sq deg removed, holes (lakes) "
                       "filled. Not for navigation." % (SIMPLIFY_DEG, MIN_ISLAND_SQ_DEG)),
        "bounds": {"west": WEST, "south": SOUTH, "east": EAST, "north": NORTH},
    }
    labels_data = json.load(open(os.path.join(os.path.dirname(__file__), "chart_labels.json")))
    land = dict(meta, name="Europe", labels=labels_data, polygons=rings, fill_tiles=tiles)
    with open(os.path.join(OUT_DIR, "europe_land.json"), "w") as f:
        json.dump(land, f, separators=(",", ":"), ensure_ascii=False)

    # One image, two meanings: 255 = navigable water, 128 = approach-only water.
    mask = np.where(water, 255, np.where(approach, 128, 0)).astype(np.uint8)
    Image.fromarray(mask, mode="L").save(os.path.join(OUT_DIR, "europe_navmask.png"), optimize=True)
    with open(os.path.join(OUT_DIR, "europe_navmask.json"), "w") as f:
        json.dump(dict(meta, cells_per_mercator_degree=CELLS_PER_DEGREE, columns=COLS, rows=ROWS,
                       mercator_north=MY_NORTH,
                       land_rule=("255: navigable, no land in any part of the cell (1/%d cell precision); "
                                  "128: approach-only, water covers at least half of the cell; 0: land") % SUPERSAMPLE),
                  f, indent=1)

    flat_nodes = []
    for x, y in keys:
        flat_nodes += [x, y]
    flat_edges = []
    for a, b in edges:
        flat_edges += [a, b]
    with open(os.path.join(OUT_DIR, "europe_route_graph.json"), "w") as f:
        json.dump({"note": "Nodes are raster cells (column, row); edges connect nodes with a clear line.",
                   "nodes": flat_nodes, "edges": flat_edges}, f, separators=(",", ":"))
    print("done")


if __name__ == "__main__":
    main()
