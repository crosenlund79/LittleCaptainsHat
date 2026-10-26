#!/usr/bin/env python3
"""Fine coastal raster for anchoring (Revision 0.105b).

Input:
  OpenStreetMap land polygons as packaged by geo-maps "earth-lands-100m" 0.6.0
  (npm @geo-maps/earth-lands-100m, file package/map.geo.json, package SHA-1
  bcee1e6ce052d9c57bc7a2aa3b39912aaaf43c41) - the same file the world chart is
  built from (tools/navigation/build_world.py). Map data (c) OpenStreetMap
  contributors, ODbL 1.0.

Output (data/navigation/coast/):
  coast.json  metadata: resolution, bounds, tile counts, source, licence
  coast.bin   the raster: an index of 1 x 1 degree tiles (water / land / mixed)
              and, for each mixed tile only, its 120 x 120 land bits (one per
              1/120 degree, about 0.5 nm north-south), bit-packed row by row
              and deflated (zlib) separately so the game decompresses only the
              tiles it visits.

The routing raster (about 5 nm cells on the world chart) says where routes may
go; this one says where the water really is near a coast, so anchoring can be
judged close to the shore. Same source, so the two agree.

Rules: plain latitude/longitude grid (EPSG:4326), latitudes -72..80 like the
world chart; a cell is land if its centre is inside a land polygon (holes -
lakes - filled, as on the chart). Not for navigation.

Usage: python3 tools/navigation/build_coast.py path/to/map.geo.json
"""

import json
import os
import struct
import sys
import time
import zlib

import numpy as np
from PIL import Image, ImageDraw

ROOT = os.path.join(os.path.dirname(__file__), "..", "..")
OUT_DIR = os.path.join(ROOT, "data", "navigation", "coast")
RES = 120  # cells per degree
SOUTH, NORTH = -72, 80
TILES_X = 360
TILES_Y = NORTH - SOUTH
MAGIC = b"LCHC"  # Little Captain's Hat coast
VERSION = 1


def main():
    if len(sys.argv) < 2:
        print(__doc__)
        sys.exit(1)
    t = time.time()
    data = json.load(open(sys.argv[1]))
    rings = []
    for poly in data["geometries"][0]["coordinates"]:
        exterior = poly[0]
        if len(exterior) >= 4:
            rings.append(exterior)
    print("land rings", len(rings), "%.1f s" % (time.time() - t), flush=True)

    width, height = TILES_X * RES, TILES_Y * RES
    image = Image.new("1", (width, height), 0)
    draw = ImageDraw.Draw(image)
    for ring in rings:
        # Pixel coordinates: x from -180 (west edge), y from NORTH (top). PIL
        # fills pixels whose centre is inside, so a cell is land when its
        # centre is.
        pts = [((lon + 180.0) * RES - 0.5, (NORTH - lat) * RES - 0.5) for lon, lat in ring]
        draw.polygon(pts, fill=1)
    print("rasterised %d x %d in %.1f s" % (width, height, time.time() - t), flush=True)

    index = np.zeros((TILES_Y, TILES_X), dtype=np.uint8)  # 0 water, 1 land, 2 mixed
    payloads = []
    for ty in range(TILES_Y):
        band = np.array(image.crop((0, ty * RES, width, (ty + 1) * RES)), dtype=bool)
        for tx in range(TILES_X):
            tile = band[:, tx * RES:(tx + 1) * RES]
            land = int(tile.sum())
            if land == 0:
                continue
            if land == RES * RES:
                index[ty, tx] = 1
                continue
            index[ty, tx] = 2
            packed = np.packbits(tile, axis=None).tobytes()  # rows north to south, bits west to east
            payloads.append(((ty, tx), zlib.compress(packed, 9)))
    del image
    mixed = len(payloads)
    print("tiles: water %d, land %d, mixed %d (%.1f s)" % (int((index == 0).sum()), int((index == 1).sum()), mixed, time.time() - t), flush=True)

    os.makedirs(OUT_DIR, exist_ok=True)
    header_size = 4 + 4 + 4 + 4 + TILES_X * TILES_Y + mixed * 8
    offsets = []
    position = header_size
    for _key, blob in payloads:
        offsets.append((position, len(blob)))
        position += len(blob)
    with open(os.path.join(OUT_DIR, "coast.bin"), "wb") as f:
        f.write(MAGIC)
        f.write(struct.pack("<III", VERSION, RES, mixed))
        f.write(index.tobytes())  # row 0 = the northernmost band (NORTH-1..NORTH)
        for offset, size in offsets:
            f.write(struct.pack("<II", offset, size))
        for _key, blob in payloads:
            f.write(blob)
    size = os.path.getsize(os.path.join(OUT_DIR, "coast.bin"))
    meta = {
        "id": "coast",
        "name": "Fine coastal raster (anchoring)",
        "source": "OpenStreetMap land polygons via geo-maps earth-lands-100m 0.6.0 (npm @geo-maps/earth-lands-100m, "
                  "package SHA-1 bcee1e6ce052d9c57bc7a2aa3b39912aaaf43c41, about 100 m accuracy). "
                  "Map data (c) OpenStreetMap contributors, ODbL 1.0, openstreetmap.org/copyright.",
        "licence": "ODbL 1.0 (derived database)",
        "crs": "WGS 84 longitude/latitude (EPSG:4326), plain latitude/longitude grid",
        "cells_per_degree": RES,
        "bounds": {"west": -180, "east": 180, "south": SOUTH, "north": NORTH},
        "tiles": {"columns": TILES_X, "rows": TILES_Y, "mixed": mixed,
                  "land": int((index == 1).sum()), "water": int((index == 0).sum())},
        "layout": "coast.bin: 'LCHC', uint32 version, uint32 cells_per_degree, uint32 mixed_count; "
                  "uint8 index[rows][columns] (row 0 = northernmost, column 0 = 180W; 0 water, 1 land, 2 mixed); "
                  "uint32 offset, uint32 size per mixed tile in index order; zlib-deflated payloads of "
                  "120 x 120 bits (rows north to south, bits west to east, MSB first; 1 = land).",
        "processing": "Land if the cell centre is inside a land polygon; lakes filled. Not for navigation.",
        "file_bytes": size,
        "built_seconds": round(time.time() - t, 1),
    }
    with open(os.path.join(OUT_DIR, "coast.json"), "w") as f:
        json.dump(meta, f, indent=1)
    print("coast.bin %d bytes; done in %.1f s" % (size, time.time() - t))


if __name__ == "__main__":
    main()
