class_name WorldLand
extends Resource
## The world chart's drawn land (Iteration 16), already projected to map
## space, so the chart loads it without parsing or projecting anything.
## Written from data/navigation/world/land.json by
## tools/navigation/world_land_to_res.gd; MapView falls back to the JSON when
## this resource is missing or made for another map scale.

## Map units per degree of longitude the points are in (MapView.units_per_degree).
@export var scale := 160.0
## Coarse whole-world land (zoomed out): fill rings and coastlines.
@export var overview_fill: Array[PackedVector2Array] = []
@export var overview_coast: Array[PackedVector2Array] = []
## Regional land outside Europe (zoomed in).
@export var regional_fill: Array[PackedVector2Array] = []
@export var regional_coast: Array[PackedVector2Array] = []
## Islands too small to draw as land: dots.
@export var islets := PackedVector2Array()
## World labels as in land.json.
@export var labels: Array = []
