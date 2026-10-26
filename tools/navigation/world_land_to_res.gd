extends SceneTree
## Converts data/navigation/world/land.json (written by build_world.py) into
## data/navigation/world/land.res: the same land, projected to the chart's map
## space and stored as a binary Godot resource, so the chart opens quickly.
## Run after build_world.py:
##   godot --headless --path . --script tools/navigation/world_land_to_res.gd

const SOURCE := "res://data/navigation/world/land.json"
const TARGET := "res://data/navigation/world/land.res"
const SCALE := 160.0  # MapView.units_per_degree


func _init() -> void:
	var raw: Variant = JSON.parse_string(FileAccess.get_file_as_string(SOURCE))
	if not raw is Dictionary:
		push_error("Cannot read %s" % SOURCE)
		quit(1)
		return
	var projection := MapProjection.new(SCALE)
	var land := WorldLand.new()
	land.scale = SCALE
	land.overview_fill = _rings(raw.overview.fill_tiles, projection)
	land.overview_coast = _rings(raw.overview.coast, projection)
	land.regional_fill = _rings(raw.regional.fill_tiles, projection)
	land.regional_coast = _rings(raw.regional.coast, projection)
	for p: Array in raw.get("islets", []):
		land.islets.append(projection.geo_to_map(Vector2(p[0], p[1])))
	land.labels = raw.get("labels", [])
	var error := ResourceSaver.save(land, TARGET, ResourceSaver.FLAG_COMPRESS)
	print("saved %s (%d)" % [TARGET, error])
	quit(0 if error == OK else 1)


static func _rings(source: Array, projection: MapProjection) -> Array[PackedVector2Array]:
	var result: Array[PackedVector2Array] = []
	for ring: Array in source:
		var points := PackedVector2Array()
		points.resize(ring.size())
		for i in ring.size():
			points[i] = projection.geo_to_map(Vector2(ring[i][0], ring[i][1]))
		result.append(points)
	return result
