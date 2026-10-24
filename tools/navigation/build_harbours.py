"""Builds the harbour catalogue of Next Harbor from tools/navigation/harbours.csv.

The CSV is the single source of the harbour list:
  id, name, country, latitude, longitude, importance (1-3), region, island (0/1), source, description

Rows whose source is "existing" are the original harbours (Iteration 002). Their
.tres files keep their name, country, coordinates and description; only importance,
region, island and source are (re)written. Every other row writes its own
data/navigation/ports/<id>.tres. Then data/navigation/port_catalog.tres is written
with every harbour, in CSV order.

Coordinates of the added harbours come from UN/LOCODE (UNECE), recorded per row in
"source" (the entry and its coordinate as published, to the arc-minute). To refresh
them from a UN/LOCODE code list:
    python3 tools/navigation/build_harbours.py --locode path/to/code-list.csv
(the datasets/un-locode "code-list.csv"). Without --locode the CSV is used as is.

Ids are stable: never rename or remove one that has shipped (saves refer to them).
Candidates that failed validation are kept, with the reason, in harbours_rejected.csv.
The game's test suite (test_harbours) validates every harbour: unique ids, a valid
position on the chart, a harbour approach to open water, and routes.

Usage:    python3 tools/navigation/build_harbours.py [--locode code-list.csv]
"""
import csv
import os
import re
import sys

ROOT = os.path.join(os.path.dirname(__file__), "..", "..")
CSV_PATH = os.path.join(os.path.dirname(__file__), "harbours.csv")
PORT_DIR = os.path.join(ROOT, "data", "navigation", "ports")
CATALOG = os.path.join(ROOT, "data", "navigation", "port_catalog.tres")
FIELDS = ["id", "name", "country", "latitude", "longitude", "importance", "region", "island", "source", "description"]


def quote(text):
    return '"' + text.replace("\\", "\\\\").replace('"', '\\"') + '"'


def locode_coordinates(path):
    """{"DKAAR": (lat, lon, "5609N 01013E")} for every entry with coordinates."""
    result = {}
    for row in csv.DictReader(open(path, encoding="utf-8")):
        value = row["Coordinates"].strip()
        match = re.fullmatch(r"(\d{2})(\d{2})([NS]) (\d{3})(\d{2})([EW])", value)
        if not match:
            continue
        lat = int(match[1]) + int(match[2]) / 60.0
        lon = int(match[4]) + int(match[5]) / 60.0
        result[row["Country"] + row["Location"]] = (-lat if match[3] == "S" else lat, -lon if match[6] == "W" else lon, value)
    return result


def read_rows():
    rows = list(csv.DictReader(open(CSV_PATH, encoding="utf-8")))
    ids = [row["id"] for row in rows]
    duplicates = {i for i in ids if ids.count(i) > 1}
    if duplicates:
        sys.exit("Duplicate harbour ids: %s" % sorted(duplicates))
    for row in rows:
        if not re.fullmatch(r"[a-z][a-z0-9_]*", row["id"]):
            sys.exit("Invalid harbour id: %r" % row["id"])
        if row["importance"] not in ("1", "2", "3"):
            sys.exit("%s: importance must be 1-3" % row["id"])
    return rows


def write_existing(row):
    path = os.path.join(PORT_DIR, row["id"] + ".tres")
    text = open(path, encoding="utf-8").read()
    text = re.sub(r"\n(importance|region|island|source) = .*", "", text)
    text = text.rstrip("\n") + "\nimportance = %s\nregion = %s\nisland = %s\nsource = %s\n" % (
        row["importance"], quote(row["region"]), "true" if row["island"] == "1" else "false",
        quote("Next Harbor original harbour (Iteration 002)"))
    open(path, "w", encoding="utf-8").write(text)


def write_new(row):
    lat, lon = float(row["latitude"]), float(row["longitude"])
    if not (-90.0 <= lat <= 90.0 and -180.0 <= lon <= 180.0):
        sys.exit("%s: coordinates out of range" % row["id"])
    text = ('[gd_resource type="Resource" script_class="PortData" format=3]\n\n'
            '[ext_resource type="Script" path="res://src/navigation/port_data.gd" id="1_port"]\n\n'
            "[resource]\n"
            'script = ExtResource("1_port")\n'
            "id = &%s\n"
            "display_name = %s\n"
            "country = %s\n"
            "latitude = %s\n"
            "longitude = %s\n"
            "description = %s\n"
            "importance = %s\n"
            "region = %s\n"
            "island = %s\n"
            "source = %s\n") % (quote(row["id"]), quote(row["name"]), quote(row["country"]), row["latitude"],
                                row["longitude"], quote(row["description"]), row["importance"], quote(row["region"]),
                                "true" if row["island"] == "1" else "false", quote(row["source"]))
    open(os.path.join(PORT_DIR, row["id"] + ".tres"), "w", encoding="utf-8").write(text)


def write_catalog(rows):
    lines = ['[gd_resource type="Resource" script_class="PortCatalog" format=3]', "",
             '[ext_resource type="Script" path="res://src/navigation/port_catalog.gd" id="1_catalog"]',
             '[ext_resource type="Script" path="res://src/navigation/port_data.gd" id="2_port"]']
    refs = []
    for index, row in enumerate(rows):
        ref = "%d_%s" % (index + 3, row["id"])
        lines.append('[ext_resource type="Resource" path="res://data/navigation/ports/%s.tres" id="%s"]' % (row["id"], ref))
        refs.append('ExtResource("%s")' % ref)
    lines += ["", "[resource]", 'script = ExtResource("1_catalog")',
              'ports = Array[ExtResource("2_port")]([%s])' % ", ".join(refs), ""]
    open(CATALOG, "w", encoding="utf-8").write("\n".join(lines))


def main():
    rows = read_rows()
    if len(sys.argv) == 3 and sys.argv[1] == "--locode":
        coordinates = locode_coordinates(sys.argv[2])
        for row in rows:
            match = re.match(r"UN/LOCODE (\w\w) (\w{3})", row["source"])
            if match and match[1] + match[2] in coordinates:
                lat, lon, raw = coordinates[match[1] + match[2]]
                row["latitude"], row["longitude"] = "%.4f" % lat, "%.4f" % lon
                row["source"] = "UN/LOCODE %s %s (%s)" % (match[1], match[2], raw)
        with open(CSV_PATH, "w", newline="", encoding="utf-8") as handle:
            writer = csv.DictWriter(handle, FIELDS, lineterminator="\n")
            writer.writeheader()
            writer.writerows(rows)
    for row in rows:
        (write_existing if row["source"] == "existing" else write_new)(row)
    write_catalog(rows)
    # Harbours no longer listed (e.g. moved to harbours_rejected.csv before
    # they ever shipped) lose their resource file.
    listed = {row["id"] + ".tres" for row in rows}
    for name in os.listdir(PORT_DIR):
        if name.endswith(".tres") and name not in listed:
            os.remove(os.path.join(PORT_DIR, name))
    print("%d harbours (%d original, %d added)" % (len(rows), sum(r["source"] == "existing" for r in rows),
                                                   sum(r["source"] != "existing" for r in rows)))


if __name__ == "__main__":
    main()
