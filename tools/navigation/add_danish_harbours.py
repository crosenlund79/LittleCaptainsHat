"""Adds the Iteration 14 Danish harbours to tools/navigation/harbours.csv and
writes their facility files (data/harbours/facilities/<id>.tres).

Positions: the town's coordinate from the GeoNames gazetteer (cities.json by
lutangar, GeoNames cities, CC BY 4.0). Town coordinates usually lie on land, so
the harbour is placed on the water just off the nearest coastline of the
region's OpenStreetMap land (build_region.py's land, ODbL), PLACE_OFFSET_NM
from the shore. Both are recorded in the CSV's "source" column. These are
gameplay positions for a cozy chart, not real berths or marina layouts.

Facilities are gameplay tiers (HarbourFacilities): small harbours have no
boatyard, larger ones a boatyard, major service harbours can haul out. They are
not claims about real businesses.

Then run tools/navigation/build_harbours.py to write the port resources.

Usage: python3 tools/navigation/add_danish_harbours.py path/to/cities.json path/to/region_land.pkl
"""
import csv
import json
import math
import os
import pickle
import sys

from shapely.geometry import Point
from shapely.ops import nearest_points

HERE = os.path.dirname(__file__)
ROOT = os.path.join(HERE, "..", "..")
CSV_PATH = os.path.join(HERE, "harbours.csv")
FACILITY_DIR = os.path.join(ROOT, "data", "harbours", "facilities")
PLACE_OFFSET_NM = 0.15

# id, name, town (GeoNames name), importance, region, island, tier, description
HARBOURS = [
    ("helsingor", "Helsingør", "Helsingør", 2, "baltic", 0, "larger", "Helsingør, at the narrowest point of the Øresund, under Kronborg."),
    ("gilleleje", "Gilleleje", "Gilleleje", 3, "baltic", 0, "small", "Gilleleje, a fishing harbour on Zealand's north coast, facing the Kattegat."),
    ("dragor", "Dragør", "Dragør", 3, "baltic", 0, "small", "Dragør, an old skipper town on Amager, on the Øresund."),
    ("rodvig", "Rødvig", "Rødvig", 3, "baltic", 0, "small", "Rødvig, a small harbour on the Stevns coast of Zealand."),
    ("stege", "Stege", "Stege", 3, "baltic", 1, "small", "Stege, the little town of the island of Møn."),
    ("vordingborg", "Vordingborg", "Vordingborg", 3, "baltic", 0, "larger", "Vordingborg, by the bridges to Falster and Møn."),
    ("nysted", "Nysted", "Nysted", 3, "baltic", 1, "small", "Nysted, a quiet harbour on Lolland's south coast."),
    ("korsor", "Korsør", "Korsør", 3, "baltic", 0, "larger", "Korsør, on Zealand's side of the Great Belt."),
    ("kalundborg", "Kalundborg", "Kalundborg", 3, "baltic", 0, "larger", "Kalundborg, at the head of its fjord on west Zealand."),
    ("nyborg", "Nyborg", "Nyborg", 3, "baltic", 1, "larger", "Nyborg, on Funen's side of the Great Belt."),
    ("kerteminde", "Kerteminde", "Kerteminde", 3, "baltic", 1, "small", "Kerteminde, a fishing town on Funen's east coast."),
    ("svendborg", "Svendborg", "Svendborg", 2, "baltic", 1, "major", "Svendborg, the sailing town of the South Funen Archipelago."),
    ("faaborg", "Faaborg", "Faaborg", 3, "baltic", 1, "larger", "Faaborg, on south Funen, looking out over the archipelago."),
    ("aeroskobing", "Ærøskøbing", "Ærøskøbing", 3, "baltic", 1, "small", "Ærøskøbing, a cobbled old town on the island of Ærø."),
    ("marstal", "Marstal", "Marstal", 3, "baltic", 1, "larger", "Marstal, Ærø's seafaring town."),
    ("rudkobing", "Rudkøbing", "Rudkøbing", 3, "baltic", 1, "larger", "Rudkøbing, on the west side of Langeland."),
    ("middelfart", "Middelfart", "Middelfart", 3, "baltic", 1, "larger", "Middelfart, on Funen at the narrows of the Little Belt."),
    ("juelsminde", "Juelsminde", "Juelsminde", 3, "baltic", 0, "small", "Juelsminde, a small harbour on Jutland's east coast."),
    ("ebeltoft", "Ebeltoft", "Ebeltoft", 3, "baltic", 0, "small", "Ebeltoft, on Djursland, home of the frigate Jylland."),
    ("grenaa", "Grenaa", "Grenaa", 3, "baltic", 0, "larger", "Grenaa, on Djursland's Kattegat coast."),
    ("skagen", "Skagen", "Skagen", 2, "scandinavia", 0, "major", "Skagen, at the very top of Jutland, where two seas meet."),
    ("ronne", "Rønne", "Rønne", 2, "baltic", 1, "larger", "Rønne, the main harbour of Bornholm."),
    ("sonderborg", "Sønderborg", "Sønderborg", 3, "baltic", 1, "larger", "Sønderborg, on Als by the castle."),
]
TIERS = {"small": (True, False, True, False), "larger": (True, True, True, False), "major": (True, True, True, True)}


def main():
    towns = {}
    for c in json.load(open(sys.argv[1])):
        if c["country"] == "DK":
            towns.setdefault(c["name"], (float(c["lng"]), float(c["lat"])))
    land = pickle.load(open(sys.argv[2], "rb"))
    rows = list(csv.DictReader(open(CSV_PATH, encoding="utf-8")))
    fields = list(rows[0].keys())
    known = {r["id"] for r in rows}
    added = 0
    for hid, name, town, importance, region, island, tier, description in HARBOURS:
        lon, lat = towns[town]
        point = Point(lon, lat)
        placed = point
        coslat = math.cos(math.radians(lat))
        step = PLACE_OFFSET_NM / 60.0
        shore = nearest_points(land.boundary, point)[0]
        on_land = land.contains(point)
        if on_land or point.distance(shore) < step:
            # From the shore, step out onto the water: past the shore when the
            # town point is on land, away from it when it is already afloat.
            dx, dy = (shore.x - lon, shore.y - lat) if on_land else (lon - shore.x, lat - shore.y)
            norm = math.hypot(dx * coslat, dy) or 1.0
            ux, uy = dx / norm / coslat, dy / norm
            placed = Point(shore.x + ux * step, shore.y + uy * step)
            tries = 0
            while land.contains(placed) and tries < 6:
                placed = Point(placed.x + ux * step * 0.5, placed.y + uy * step * 0.5)
                tries += 1
        source = ("GeoNames town position %.4fN %.4fE (cities.json, CC BY 4.0); harbour placed %.2f nm off the nearest "
                  "OpenStreetMap coastline (ODbL), Iteration 14") % (lat, lon, PLACE_OFFSET_NM)
        row = {"id": hid, "name": name, "country": "Denmark", "latitude": "%.4f" % placed.y, "longitude": "%.4f" % placed.x,
               "importance": str(importance), "region": region, "island": str(island), "source": source,
               "description": description}
        if hid in known:
            rows = [row if r["id"] == hid else r for r in rows]
        else:
            rows.append(row)
            added += 1
        grocery, boatyard, go_ashore, haul_out = TIERS[tier]
        with open(os.path.join(FACILITY_DIR, hid + ".tres"), "w") as f:
            f.write('[gd_resource type="Resource" script_class="HarbourFacilities" format=3]\n\n'
                    '[ext_resource type="Script" path="res://src/harbour/harbour_facilities.gd" id="1_fac"]\n\n'
                    '[resource]\nscript = ExtResource("1_fac")\ngrocery = %s\nboatyard = %s\ngo_ashore = %s\nhaul_out = %s\n' % (
                        str(grocery).lower(), str(boatyard).lower(), str(go_ashore).lower(), str(haul_out).lower()))
        print("%-12s %-12s %.4f %.4f (town %.4f %.4f) %s" % (hid, tier, placed.y, placed.x, lat, lon,
                                                           "%.2f nm" % (math.hypot((placed.x - lon) * math.cos(math.radians(lat)), placed.y - lat) * 60.0)))
    with open(CSV_PATH, "w", newline="", encoding="utf-8") as f:
        writer = csv.DictWriter(f, fieldnames=fields)
        writer.writeheader()
        writer.writerows(rows)
    print(added, "harbours added")


if __name__ == "__main__":
    main()
