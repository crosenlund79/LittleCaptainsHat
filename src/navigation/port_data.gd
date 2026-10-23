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


## Geographic position as Vector2(longitude, latitude) in degrees.
func get_geo_position() -> Vector2:
	return Vector2(longitude, latitude)
