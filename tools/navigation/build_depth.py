#!/usr/bin/env python3
"""Bathymetry subset for the game (Revision 0.105b, tiers A/B of DepthService).

NOT RUN FOR 0.105b: no real bathymetry could be downloaded in the build
environment (GEBCO, EMODnet and NOAA were refused by its network policy). This
script is ready for when a bounded subset is available; it was tested only
with synthetic input (tests/suites/test_coastal_depth.gd).

Input: one or more Esri ASCII grids (.asc) of elevation in metres (negative
below sea level), WGS 84 longitude/latitude - e.g. GEBCO 2026 grid subsets
exported as "Esri ASCII" from https://download.gebco.net/ (choose a bounded
area; never the whole 15 arc-second world). GEBCO values are mostly
interpolated between soundings; the game labels them "global depth model
(mostly interpolated)", never as soundings. Attribution required: "GEBCO
Compilation Group (2026) GEBCO 2026 Grid"; licence: GEBCO terms of use
(public domain-like, attribution, not for navigation).

Output: data/navigation/depth/depth.bin (layout in src/navigation/depth_data.gd)
and depth.json (sources, licence, resolution, tiles). The grid is resampled to
RES cells per degree (default 60, about 1 nm) by block averaging.

Usage:
  python3 tools/navigation/build_depth.py [--res 60] [--source global|regional]
      [--out DIR] grid1.asc [grid2.asc ...]
"""

import argparse
import json
import os
import struct
import zlib

import numpy as np

NORTH = 80
TILES_X, TILES_Y = 360, 152


def read_asc(path):
    header = {}
    with open(path) as f:
        for _ in range(6):
            key, value = f.readline().split()
            header[key.lower()] = float(value)
        data = np.loadtxt(f, dtype=np.float32)
    nodata = header.get("nodata_value", -9999.0)
    data[data == nodata] = np.nan
    west = header["xllcorner"]
    south = header["yllcorner"]
    size = header["cellsize"]
    return data, west, south, size


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--res", type=int, default=60)
    parser.add_argument("--source", choices=["global", "regional"], default="global")
    parser.add_argument("--out", default=os.path.join(os.path.dirname(__file__), "..", "..", "data", "navigation", "depth"))
    parser.add_argument("grids", nargs="+")
    args = parser.parse_args()
    res = args.res
    tiles = {}
    for path in args.grids:
        data, west, south, size = read_asc(path)
        rows, cols = data.shape
        north = south + rows * size
        # Each output cell: mean of the input cells whose centres fall inside.
        for ty in range(TILES_Y):
            lat_top = NORTH - ty
            if lat_top - 1 >= north or lat_top <= south:
                continue
            for tx in range(TILES_X):
                lon_left = tx - 180
                if lon_left + 1 <= west or lon_left >= west + cols * size:
                    continue
                tile = tiles.setdefault((ty, tx), np.full((res, res), np.nan, dtype=np.float32))
                for r in range(res):
                    lat1 = lat_top - r / res
                    lat0 = lat1 - 1.0 / res
                    i0 = int(np.floor((north - lat1) / size))
                    i1 = int(np.ceil((north - lat0) / size))
                    if i1 <= 0 or i0 >= rows:
                        continue
                    for c in range(res):
                        lon0 = lon_left + c / res
                        lon1 = lon0 + 1.0 / res
                        j0 = int(np.floor((lon0 - west) / size))
                        j1 = int(np.ceil((lon1 - west) / size))
                        if j1 <= 0 or j0 >= cols:
                            continue
                        block = data[max(i0, 0):min(i1, rows), max(j0, 0):min(j1, cols)]
                        if block.size and not np.all(np.isnan(block)):
                            tile[r, c] = np.nanmean(block)
    os.makedirs(args.out, exist_ok=True)
    index = np.zeros((TILES_Y, TILES_X), dtype=np.uint8)
    blobs = []
    for (ty, tx), tile in sorted(tiles.items()):
        if np.all(np.isnan(tile)):
            continue
        filled = np.where(np.isnan(tile), 1.0, tile)  # no data: treated as land (+1 m)
        index[ty, tx] = 1
        blobs.append(((ty, tx), zlib.compress(np.clip(np.round(filled), -32768, 32767).astype("<i2").tobytes(), 9)))
    header = 20 + TILES_X * TILES_Y + 8 * len(blobs)
    out = os.path.join(args.out, "depth.bin")
    with open(out, "wb") as f:
        f.write(b"LCHD")
        f.write(struct.pack("<IIII", 1, res, 0 if args.source == "regional" else 1, len(blobs)))
        f.write(index.tobytes())
        position = header
        for _key, blob in blobs:
            f.write(struct.pack("<II", position, len(blob)))
            position += len(blob)
        for _key, blob in blobs:
            f.write(blob)
    with open(os.path.join(args.out, "depth.json"), "w") as f:
        json.dump({"inputs": [os.path.basename(p) for p in args.grids], "cells_per_degree": res,
                   "source": args.source, "tiles": len(blobs), "file_bytes": os.path.getsize(out),
                   "note": "Elevations in metres, negative below sea level. Not for navigation."}, f, indent=1)
    print("depth.bin: %d tiles, %d bytes" % (len(blobs), os.path.getsize(out)))


if __name__ == "__main__":
    main()
