"""Adds the Iteration 16 international cruising harbours to tools/navigation/harbours.csv and
writes their facility files (data/harbours/facilities/<id>.tres).

Positions: the UN/LOCODE coordinates (UNECE code list, to the arc-minute) of each place,
unchanged. On the coarse world chart (5 arc-minute cells) the harbour reaches open water
through its harbour approach (SeaRouter.find_port_approach), which allows for the chart's
resolution. These are gameplay positions, not berths or marina layouts.

Facilities are gameplay tiers (HarbourFacilities): small harbours have no boatyard,
larger ones a boatyard, major service harbours can haul out. Every harbour here has
groceries, so a crew is never left without food and water. Not claims about real
businesses.

Left out: Opua (NZ OPX), whose UN/LOCODE position lies deep in the Bay of Islands, more
than the approach limit from water on the coarse world chart.

Then run tools/navigation/build_harbours.py to write the port resources.

Usage: python3 tools/navigation/add_world_harbours.py path/to/code-list.csv
"""
import csv
import os
import sys

HERE = os.path.dirname(__file__)
ROOT = os.path.join(HERE, "..", "..")
CSV_PATH = os.path.join(HERE, "harbours.csv")
FACILITY_DIR = os.path.join(ROOT, "data", "harbours", "facilities")

# id, name, country, UN/LOCODE (country, location), importance, region, island, tier, description
HARBOURS = [
    ("funchal", "Funchal", "Portugal", ("PT", "FNC"), 1, "atlantic_islands", 1, "larger", "Funchal, the harbour of Madeira, at the foot of green mountains."),
    ("ponta_delgada", "Ponta Delgada", "Portugal", ("PT", "PDL"), 1, "atlantic_islands", 1, "larger", "Ponta Delgada on São Miguel, the largest harbour of the Azores."),
    ("horta", "Horta", "Portugal", ("PT", "HOR"), 2, "atlantic_islands", 1, "larger", "Horta on Faial in the Azores, a famous mid-Atlantic stop for sailors."),
    ("las_palmas", "Las Palmas", "Spain", ("ES", "LPA"), 1, "atlantic_islands", 1, "major", "Las Palmas de Gran Canaria, where many Atlantic crossings begin."),
    ("arrecife", "Arrecife", "Spain", ("ES", "ACE"), 3, "atlantic_islands", 1, "small", "Arrecife on Lanzarote, the easternmost of the Canary Islands."),
    ("mindelo", "Mindelo", "Cape Verde", ("CV", "MIN"), 1, "atlantic_islands", 1, "larger", "Mindelo on São Vicente, Cape Verde: a last stop before the trade winds."),
    ("st_george_bermuda", "St. George's", "Bermuda", ("BM", "SGE"), 1, "atlantic_islands", 1, "larger", "St. George's, the old harbour town of Bermuda, alone in the western Atlantic."),
    ("castries", "Castries", "Saint Lucia", ("LC", "CAS"), 1, "caribbean", 1, "larger", "Castries, the harbour of Saint Lucia in the Windward Islands."),
    ("le_marin", "Le Marin", "Martinique", ("MQ", "QMR"), 2, "caribbean", 1, "major", "Le Marin in the south of Martinique, a sheltered bay full of yachts."),
    ("fort_de_france", "Fort-de-France", "Martinique", ("MQ", "FDF"), 3, "caribbean", 1, "larger", "Fort-de-France, the capital of Martinique, on its wide bay."),
    ("bequia", "Port Elizabeth", "Saint Vincent and the Grenadines", ("VC", "BQU"), 3, "caribbean", 1, "small", "Port Elizabeth on Bequia, in the Grenadines."),
    ("falmouth_antigua", "Falmouth Harbour", "Antigua and Barbuda", ("AG", "FAM"), 2, "caribbean", 1, "larger", "Falmouth Harbour on the south coast of Antigua."),
    ("port_of_spain", "Port of Spain", "Trinidad and Tobago", ("TT", "POS"), 3, "caribbean", 1, "larger", "Port of Spain, Trinidad, at the southern end of the Antilles."),
    ("willemstad", "Willemstad", "Curaçao", ("CW", "WIL"), 2, "caribbean", 1, "larger", "Willemstad, Curaçao, behind its colourful waterfront."),
    ("san_juan", "San Juan", "Puerto Rico", ("PR", "SJU"), 2, "caribbean", 1, "larger", "San Juan, Puerto Rico, under the old fortress walls."),
    ("nassau", "Nassau", "Bahamas", ("BS", "NAS"), 2, "caribbean", 1, "larger", "Nassau, the harbour of New Providence in the Bahamas."),
    ("colon", "Colón", "Panama", ("PA", "ONX"), 1, "central_america", 0, "larger", "Colón, at the Caribbean end of the Panama Canal."),
    ("panama_city", "Panama City", "Panama", ("PA", "PTY"), 1, "central_america", 0, "major", "Panama City, at the Pacific end of the Panama Canal."),
    ("puerto_ayora", "Puerto Ayora", "Ecuador", ("EC", "AYO"), 2, "pacific", 1, "small", "Puerto Ayora on Santa Cruz, in the Galápagos Islands."),
    ("taiohae", "Taiohae", "French Polynesia", ("PF", "TAI"), 2, "pacific", 1, "small", "Taiohae on Nuku Hiva, the landfall in the Marquesas after the long Pacific crossing."),
    ("atuona", "Atuona", "French Polynesia", ("PF", "AUQ"), 3, "pacific", 1, "small", "Atuona on Hiva Oa in the Marquesas."),
    ("fakarava", "Fakarava", "French Polynesia", ("PF", "FAV"), 3, "pacific", 1, "small", "Fakarava, a coral atoll of the Tuamotu."),
    ("papeete", "Papeete", "French Polynesia", ("PF", "PPT"), 1, "pacific", 1, "major", "Papeete, the harbour town of Tahiti."),
    ("raiatea", "Uturoa", "French Polynesia", ("PF", "RFP"), 3, "pacific", 1, "larger", "Uturoa on Raiatea, in the Society Islands."),
    ("bora_bora", "Bora Bora", "French Polynesia", ("PF", "BOB"), 2, "pacific", 1, "small", "Bora Bora, its lagoon under the peak of Otemanu."),
    ("avarua", "Avarua", "Cook Islands", ("CK", "AVA"), 2, "pacific", 1, "small", "Avarua on Rarotonga, in the Cook Islands."),
    ("pago_pago", "Pago Pago", "American Samoa", ("AS", "PPG"), 3, "pacific", 1, "small", "Pago Pago, a deep harbour on Tutuila, American Samoa."),
    ("nukualofa", "Nuku'alofa", "Tonga", ("TO", "TBU"), 2, "pacific", 1, "small", "Nuku'alofa on Tongatapu, the capital of Tonga."),
    ("suva", "Suva", "Fiji", ("FJ", "SUV"), 1, "pacific", 1, "larger", "Suva, the capital of Fiji, on Viti Levu."),
    ("lautoka", "Lautoka", "Fiji", ("FJ", "LTK"), 3, "pacific", 1, "small", "Lautoka on the west coast of Viti Levu, Fiji."),
    ("noumea", "Nouméa", "New Caledonia", ("NC", "NOU"), 2, "pacific", 1, "larger", "Nouméa, New Caledonia, inside the great lagoon."),
    ("whangarei", "Whangarei", "New Zealand", ("NZ", "WRE"), 3, "pacific", 1, "larger", "Whangarei, up its harbour in Northland, New Zealand."),
    ("auckland", "Auckland", "New Zealand", ("NZ", "AKL"), 1, "pacific", 1, "major", "Auckland, the City of Sails, on the Hauraki Gulf."),
    ("wellington", "Wellington", "New Zealand", ("NZ", "WLG"), 2, "pacific", 1, "larger", "Wellington, New Zealand's capital, on Cook Strait."),
    ("nelson", "Nelson", "New Zealand", ("NZ", "NSN"), 3, "pacific", 1, "larger", "Nelson, at the top of New Zealand's South Island."),
    ("honolulu", "Honolulu", "United States", ("US", "HNL"), 1, "pacific", 1, "major", "Honolulu on O'ahu, in the middle of the North Pacific."),
]
TIERS = {"small": (True, False, True, False), "larger": (True, True, True, False), "major": (True, True, True, True)}


def parse_coords(text):
    """'1732S 14934W' -> (lat, lon) in degrees."""
    lat_part, lon_part = text.split()
    lat = int(lat_part[:2]) + int(lat_part[2:4]) / 60.0
    lon = int(lon_part[:3]) + int(lon_part[3:5]) / 60.0
    if lat_part[-1] == "S":
        lat = -lat
    if lon_part[-1] == "W":
        lon = -lon
    return lat, lon


def main():
    codes = {}
    for row in csv.reader(open(sys.argv[1], encoding="utf-8", errors="replace")):
        if len(row) > 10 and row[10]:
            codes[(row[1], row[2])] = row[10]
    rows = list(csv.DictReader(open(CSV_PATH, encoding="utf-8")))
    fields = list(rows[0].keys())
    known = {r["id"] for r in rows}
    added = 0
    for hid, name, country, locode, importance, region, island, tier, description in HARBOURS:
        coords = codes[locode]
        lat, lon = parse_coords(coords)
        source = "UN/LOCODE %s %s %s (UNECE code list), Iteration 16" % (locode[0], locode[1], coords)
        row = {"id": hid, "name": name, "country": country, "latitude": "%.4f" % lat, "longitude": "%.4f" % lon,
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
        print("%-18s %-7s %8.4f %9.4f %s" % (hid, tier, lat, lon, coords))
    with open(CSV_PATH, "w", newline="", encoding="utf-8") as f:
        writer = csv.DictWriter(f, fieldnames=fields, lineterminator="\n")
        writer.writeheader()
        writer.writerows(rows)
    print(added, "harbours added")


if __name__ == "__main__":
    main()
