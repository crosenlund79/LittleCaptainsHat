class_name PortData
extends Resource
## A port or anchorage the player can select on the world map.
##
## Coordinates are geographic (WGS84 degrees). They are never screen or map
## pixels; MapProjection converts them for display.

## Stable identifier used in saves and routes. Never rename once shipped.
@export var id: StringName
@export var display_name := ""
@export var country := ""
@export_range(-90.0, 90.0, 0.0001) var latitude := 0.0
@export_range(-180.0, 180.0, 0.0001) var longitude := 0.0
@export_multiline var description := ""
## How prominent the harbour is on the chart: 1 = major (shown at every zoom
## level), 2 = shown from a regional zoom, 3 = shown only when zoomed in.
## Selection, search, routing and saves treat all harbours the same.
@export_range(1, 3) var importance := 1
## Sea area for coverage reports (e.g. "baltic", "adriatic"; see
## tools/navigation/harbours.csv).
@export var region := ""
@export var island := false
## Where the coordinates come from (e.g. a UN/LOCODE entry).
@export var source := ""


## Geographic position as Vector2(longitude, latitude) in degrees.
func get_geo_position() -> Vector2:
	return Vector2(longitude, latitude)
