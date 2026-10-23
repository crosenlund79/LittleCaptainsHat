class_name WeatherCondition
extends Resource
## A simple, static, circular area of weather. Iteration 002 uses these only
## for warnings and chart display: they do not change speed or harm the boat.

enum Severity { NONE, CAUTION, DANGER }

## Stable id; used to de-duplicate warnings (also in saves).
@export var id: StringName
@export var display_name := ""
## Condition kind, e.g. &"fair", &"strong_wind", &"storm".
@export var kind: StringName = &"fair"
## NONE is shown on the chart but never warned about.
@export var severity := Severity.NONE
@export_range(-90.0, 90.0, 0.0001) var latitude := 0.0
@export_range(-180.0, 180.0, 0.0001) var longitude := 0.0
@export_range(1.0, 500.0, 0.5) var radius_nm := 20.0
@export_multiline var description := ""


func get_center() -> Vector2:
	return Vector2(longitude, latitude)


func contains(geo: Vector2) -> bool:
	return GeoMath.distance_nm(get_center(), geo) <= radius_nm


func is_noteworthy() -> bool:
	return severity != Severity.NONE
