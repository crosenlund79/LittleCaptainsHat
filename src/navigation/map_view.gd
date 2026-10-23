class_name MapView
extends Node2D
## Draws the navigation chart and turns mouse/keyboard input into chart events.
##
## Geography comes from `land_data` (longitude/latitude polygons), ports from
## the port catalog and weather from the weather catalog; MapProjection turns
## coordinates into map units and the Camera2D maps those to the screen.
## Nothing here stores screen or map-space positions in game data. MapView
## only displays courses and reports clicks/drags; WorldMap decides what they mean.
##
## Performance: land is pre-split into tiles (cheap triangulation), coastlines
## are drawn once as hairlines that never need redrawing, and only the light
## overlay (routes, markers, labels) is redrawn when the view changes.

signal port_clicked(port_id: StringName)
## A click on the chart that hit nothing in particular.
signal map_clicked(geo: Vector2)
## Pressed on the editable course, leg `leg_index`, at `geo`.
signal route_pressed(leg_index: int, geo: Vector2)
signal waypoint_pressed(index: int)
signal waypoint_dragged(index: int, geo: Vector2)
signal waypoint_released(index: int, geo: Vector2)
signal waypoint_remove_requested(index: int)
## Cursor position in geographic coordinates, or null when not over the map.
signal cursor_moved(geo: Variant)

@export var land_data: JSON
@export var units_per_degree := 160.0
@export var min_zoom := 0.02
@export var max_zoom := 10.0
@export var keyboard_pan_speed := 900.0
## Screen pixels on the right covered by UI (the chart's side panel). The view
## is centred and fitted within the remaining area.
@export var occluded_right_px := 0.0

const WATER := Color("#1D4A5A")
const WATER_EDGE := Color("#16394A")
const LAND := Color("#CDBF9E")
const COAST := Color("#8C7E5E")
const GRID := Color(0.651, 0.769, 0.788, 0.16)
const GRID_TEXT := Color(0.651, 0.769, 0.788, 0.6)
const PORT_FILL := Color("#EFE5CC")
const PORT_RIM := Color("#102D3B")
const BRASS := Color("#C79F6D")
const SEAFOAM := Color("#A6C4C9")
const HOVER := Color("#A6C4C9")
const INVALID := Color("#E06A4E")
const LABEL_COUNTRY := Color(0.36, 0.31, 0.22, 0.75)
const LABEL_SEA := Color(0.651, 0.769, 0.788, 0.55)
const WEATHER_COLORS := {0: Color("#7FB89A"), 1: Color("#E0A84E"), 2: Color("#E06A4E")}

const LABEL_FONT: Font = preload("res://assets/fonts/Barlow-SemiBold.ttf")
const PICK_RADIUS_PX := 18.0
const WAYPOINT_PICK_PX := 14.0
const ROUTE_PICK_PX := 8.0
const ZOOM_STEP := 1.25
const CLICK_SLOP_PX := 6.0
## Coastline drawing is split into runs of at most this many points, grouped
## into square tiles of this many map units, so off-screen tiles are culled.
const COAST_RUN_POINTS := 128
const COAST_TILE_UNITS := 400.0

enum Press { NONE, PENDING, PAN, WAYPOINT, REMOVE }

var projection: MapProjection
var catalog: PortCatalog

## Display state, set by WorldMap through set_display().
var boat_port_id: StringName
var selected_port_id: StringName
var destination_port_id: StringName
var vessel_geo := Vector2.INF
## Active voyage course: travelled part and part still ahead.
var travelled_path := PackedVector2Array()
var active_path := PackedVector2Array()
## The course being planned or edited: [{"path": PackedVector2Array, "ok": bool}].
var draft_legs: Array[Dictionary] = []
## True while the draft differs from the committed course (drawn differently).
var draft_is_proposal := false
var waypoints: Array[Vector2] = []
var invalid_waypoints := PackedInt32Array()
var selected_waypoint := -1
## Course legs and waypoints react to the mouse only when editing is enabled.
var editing_enabled := false

var _geo_bounds := Rect2()
var _map_bounds := Rect2()
var _labels: Array[Dictionary] = []
var _weather_shapes: Array[Dictionary] = []
var _hovered_port_id: StringName
var _press := Press.NONE
var _press_position := Vector2.ZERO
var _press_waypoint := -1
var _moved := false

@onready var camera: Camera2D = $Camera2D
@onready var _land: Node2D = $Land
@onready var _overlay: Node2D = $Overlay

## Wind arrows (above land) and tint (under the land fill).
var wind_layer := WindLayer.new()
var _wind_view_key := ""


func _ready() -> void:
	projection = MapProjection.new(units_per_degree)
	catalog = PortCatalog.get_default()
	_overlay.draw.connect(_draw_overlay)
	_build_land()
	_build_weather()
	wind_layer.name = "Wind"
	wind_layer.map_view = self
	wind_layer.map_bounds = _map_bounds
	add_child(wind_layer)
	move_child(wind_layer, _overlay.get_index())
	_land.add_child(wind_layer.tint)
	_land.move_child(wind_layer.tint, 1)  # just above the water, below the land fill
	reset_view()


# --- Public API ------------------------------------------------------------------------

func set_display(display: Dictionary) -> void:
	boat_port_id = display.get("boat_port_id", &"")
	selected_port_id = display.get("selected_port_id", &"")
	destination_port_id = display.get("destination_port_id", &"")
	vessel_geo = display.get("vessel_geo", Vector2.INF)
	travelled_path = display.get("travelled_path", PackedVector2Array())
	active_path = display.get("active_path", PackedVector2Array())
	draft_legs = display.get("draft_legs", [] as Array[Dictionary])
	draft_is_proposal = display.get("draft_is_proposal", false)
	waypoints = display.get("waypoints", [] as Array[Vector2])
	invalid_waypoints = display.get("invalid_waypoints", PackedInt32Array())
	selected_waypoint = display.get("selected_waypoint", -1)
	editing_enabled = display.get("editing_enabled", false)
	_overlay.queue_redraw()


## Shows the whole region in the visible chart area.
func reset_view() -> void:
	var free := _free_view_size()
	_set_zoom(minf(free.x / _map_bounds.size.x, free.y / _map_bounds.size.y) * 0.96)
	camera.position = _map_bounds.get_center()
	_clamp_camera()


func center_on_geo(geo: Vector2, zoom := -1.0) -> void:
	if zoom > 0.0:
		_set_zoom(zoom)
	camera.position = projection.geo_to_map(geo)
	_clamp_camera()
	_overlay.queue_redraw()


## Zooms so that all `points` are visible with some margin.
func frame_geo_points(points: PackedVector2Array) -> void:
	if points.is_empty():
		return
	var rect := Rect2(projection.geo_to_map(points[0]), Vector2.ZERO)
	for p in points:
		rect = rect.expand(projection.geo_to_map(p))
	var free := _free_view_size() * 0.8
	var zoom := minf(free.x / maxf(rect.size.x, 1.0), free.y / maxf(rect.size.y, 1.0))
	_set_zoom(minf(zoom, 2.0))
	camera.position = rect.get_center()
	_clamp_camera()


func zoom_by(factor: float, screen_point: Variant = null) -> void:
	var anchor: Vector2 = screen_point if screen_point is Vector2 else _view_center()
	var before := screen_to_map(anchor)
	_set_zoom(camera.zoom.x * factor)
	camera.position += before - screen_to_map(anchor)
	_clamp_camera()


func get_zoom() -> float:
	return camera.zoom.x


func screen_to_map(screen_point: Vector2) -> Vector2:
	return camera.position + (screen_point - _view_center()) / camera.zoom.x


func map_to_screen(map_point: Vector2) -> Vector2:
	return (map_point - camera.position) * camera.zoom.x + _view_center()


func screen_to_geo(screen_point: Vector2) -> Vector2:
	return projection.map_to_geo(screen_to_map(screen_point))


func geo_to_screen(geo: Vector2) -> Vector2:
	return map_to_screen(projection.geo_to_map(geo))


func get_port_screen_position(port_id: StringName) -> Vector2:
	var port := catalog.get_port(port_id)
	return geo_to_screen(port.get_geo_position()) if port else Vector2.INF


## Port id under a screen position, or &"" if none is within reach.
func pick_port(screen_point: Vector2) -> StringName:
	var best: StringName = &""
	var best_distance := PICK_RADIUS_PX
	for port in catalog.ports:
		var distance := geo_to_screen(port.get_geo_position()).distance_to(screen_point)
		if distance <= best_distance:
			best_distance = distance
			best = port.id
	return best


func pick_waypoint(screen_point: Vector2) -> int:
	var best := -1
	var best_distance := WAYPOINT_PICK_PX
	for i in waypoints.size():
		var distance := geo_to_screen(waypoints[i]).distance_to(screen_point)
		if distance <= best_distance:
			best_distance = distance
			best = i
	return best


## Leg index of the drawn course under a screen position, or -1.
func pick_route_leg(screen_point: Vector2) -> int:
	var best := -1
	var best_distance := ROUTE_PICK_PX
	for leg_index in draft_legs.size():
		var path: PackedVector2Array = draft_legs[leg_index].path
		for i in range(1, path.size()):
			var a := geo_to_screen(path[i - 1])
			var b := geo_to_screen(path[i])
			var closest := Geometry2D.get_closest_point_to_segment(screen_point, a, b)
			var distance := closest.distance_to(screen_point)
			if distance <= best_distance:
				best_distance = distance
				best = leg_index
	return best


## Called by WorldMap after inserting a waypoint on a route press, so the
## same mouse press continues as a drag of the new waypoint.
func begin_waypoint_drag(index: int) -> void:
	_press = Press.WAYPOINT
	_press_waypoint = index
	_moved = true


# --- Input -------------------------------------------------------------------------------

func _unhandled_input(event: InputEvent) -> void:
	var mouse_button := event as InputEventMouseButton
	if mouse_button:
		_handle_mouse_button(mouse_button)
		return
	var motion := event as InputEventMouseMotion
	if motion:
		_handle_mouse_motion(motion)
		return
	if event.is_action_pressed(&"map_zoom_in"):
		zoom_by(ZOOM_STEP)
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed(&"map_zoom_out"):
		zoom_by(1.0 / ZOOM_STEP)
		get_viewport().set_input_as_handled()


func _handle_mouse_button(event: InputEventMouseButton) -> void:
	match event.button_index:
		MOUSE_BUTTON_WHEEL_UP:
			if event.pressed:
				zoom_by(ZOOM_STEP, event.position)
		MOUSE_BUTTON_WHEEL_DOWN:
			if event.pressed:
				zoom_by(1.0 / ZOOM_STEP, event.position)
		MOUSE_BUTTON_LEFT:
			if event.pressed:
				_begin_left_press(event.position)
			else:
				_end_left_press(event.position)
		MOUSE_BUTTON_RIGHT, MOUSE_BUTTON_MIDDLE:
			if event.pressed:
				var waypoint := pick_waypoint(event.position) if editing_enabled and event.button_index == MOUSE_BUTTON_RIGHT else -1
				_press = Press.REMOVE if waypoint >= 0 else Press.PAN
				_press_waypoint = waypoint
				_press_position = event.position
				_moved = false
			else:
				if _press == Press.REMOVE and not _moved:
					waypoint_remove_requested.emit(_press_waypoint)
				_press = Press.NONE
		_:
			return
	get_viewport().set_input_as_handled()


func _begin_left_press(position: Vector2) -> void:
	_press_position = position
	_moved = false
	_press = Press.PENDING
	if not editing_enabled:
		return
	var waypoint := pick_waypoint(position)
	if waypoint >= 0:
		_press = Press.WAYPOINT
		_press_waypoint = waypoint
		waypoint_pressed.emit(waypoint)
		return
	if pick_port(position).is_empty():
		var leg := pick_route_leg(position)
		if leg >= 0:
			route_pressed.emit(leg, screen_to_geo(position))


func _end_left_press(position: Vector2) -> void:
	match _press:
		Press.WAYPOINT:
			if _moved:
				waypoint_released.emit(_press_waypoint, screen_to_geo(position))
		Press.PENDING:
			var port := pick_port(position)
			if not port.is_empty():
				port_clicked.emit(port)
			else:
				map_clicked.emit(screen_to_geo(position))
	_press = Press.NONE


func _handle_mouse_motion(event: InputEventMouseMotion) -> void:
	if _press != Press.NONE and not _moved and event.position.distance_to(_press_position) > CLICK_SLOP_PX:
		_moved = true
		if _press == Press.PENDING or _press == Press.REMOVE:
			_press = Press.PAN
	match _press:
		Press.PAN:
			camera.position -= event.relative / camera.zoom.x
			_clamp_camera()
			_overlay.queue_redraw()
		Press.WAYPOINT:
			if _moved:
				waypoint_dragged.emit(_press_waypoint, screen_to_geo(event.position))
	var hovered := pick_port(event.position)
	if hovered != _hovered_port_id:
		_hovered_port_id = hovered
		_overlay.queue_redraw()
	var map_point := screen_to_map(event.position)
	cursor_moved.emit(projection.map_to_geo(map_point) if _map_bounds.has_point(map_point) else null)


func _process(delta: float) -> void:
	if wind_layer.visible:
		wind_layer.update_time(GameSession.get_game_time())
		var key := "%s|%s|%s" % [camera.position, camera.zoom.x, get_viewport_rect().size]
		if key != _wind_view_key:
			_wind_view_key = key
			wind_layer.refresh_view()
	var direction := Input.get_vector(&"move_left", &"move_right", &"move_up", &"move_down")
	if direction != Vector2.ZERO:
		camera.position += direction * keyboard_pan_speed * delta / camera.zoom.x
		_clamp_camera()
		_overlay.queue_redraw()


# --- Building ----------------------------------------------------------------------------

func _build_land() -> void:
	var data: Dictionary = land_data.data if land_data and land_data.data is Dictionary else {}
	var bounds: Dictionary = data.get("bounds", {"west": -10.0, "south": 50.0, "east": 20.0, "north": 60.0})
	_geo_bounds = Rect2(bounds.west, bounds.south, bounds.east - bounds.west, bounds.north - bounds.south)
	var top_left := projection.geo_to_map(Vector2(bounds.west, bounds.north))
	var bottom_right := projection.geo_to_map(Vector2(bounds.east, bounds.south))
	_map_bounds = Rect2(top_left, bottom_right - top_left)

	var water := Polygon2D.new()
	water.name = "Water"
	water.color = WATER
	water.polygon = PackedVector2Array([_map_bounds.position, Vector2(_map_bounds.end.x, _map_bounds.position.y),
		_map_bounds.end, Vector2(_map_bounds.position.x, _map_bounds.end.y)])
	_land.add_child(water)

	# Land fill: polygons pre-clipped into tiles by the data builder.
	for ring: Array in data.get("fill_tiles", data.get("polygons", [])):
		var polygon := Polygon2D.new()
		polygon.color = LAND
		polygon.polygon = _project_ring(ring)
		_land.add_child(polygon)

	# Coastlines: drawn once as hairlines (constant 1 px at any zoom), split
	# into spatial tiles so the renderer can skip tiles outside the view.
	var tiles := {}
	for ring: Array in data.get("polygons", []):
		var points := _project_ring(ring)
		points.append(points[0])
		var start := 0
		while start < points.size() - 1:
			var end := mini(start + COAST_RUN_POINTS, points.size() - 1)
			var run := points.slice(start, end + 1)
			var key := Vector2i((run[0] / COAST_TILE_UNITS).floor())
			if not tiles.has(key):
				tiles[key] = [] as Array[PackedVector2Array]
			tiles[key].append(run)
			start = end
	for key: Vector2i in tiles:
		var tile := Node2D.new()
		tile.name = "Coast_%d_%d" % [key.x, key.y]
		var runs: Array[PackedVector2Array] = tiles[key]
		tile.draw.connect(func() -> void:
			for run in runs:
				tile.draw_polyline(run, COAST, -1.0))
		_land.add_child(tile)

	for label: Dictionary in data.get("labels", []):
		_labels.append({
			"text": label.get("text", ""),
			"position": projection.geo_to_map(Vector2(label.get("lon", 0.0), label.get("lat", 0.0))),
			"sea": label.get("kind", "") == "sea",
		})


func _project_ring(ring: Array) -> PackedVector2Array:
	var points := PackedVector2Array()
	points.resize(ring.size())
	for i in ring.size():
		points[i] = projection.geo_to_map(Vector2(ring[i][0], ring[i][1]))
	return points


## Weather areas as geographic circles projected to map space.
func _build_weather() -> void:
	for condition in WeatherCatalog.get_default().conditions:
		var outline := PackedVector2Array()
		for i in 48:
			var bearing := TAU * i / 48.0
			outline.append(projection.geo_to_map(_destination(condition.get_center(), bearing, condition.radius_nm)))
		_weather_shapes.append({"condition": condition, "outline": outline})


static func _destination(origin: Vector2, bearing: float, distance_nm: float) -> Vector2:
	var angular := distance_nm / GeoMath.EARTH_RADIUS_NM
	var lat1 := deg_to_rad(origin.y)
	var lon1 := deg_to_rad(origin.x)
	var lat2 := asin(sin(lat1) * cos(angular) + cos(lat1) * sin(angular) * cos(bearing))
	var lon2 := lon1 + atan2(sin(bearing) * sin(angular) * cos(lat1), cos(angular) - sin(lat1) * sin(lat2))
	return Vector2(rad_to_deg(lon2), rad_to_deg(lat2))


func _set_zoom(value: float) -> void:
	# Never zoom out further than showing the whole region.
	var free := _free_view_size()
	var whole_region := minf(free.x / _map_bounds.size.x, free.y / _map_bounds.size.y) * 0.8
	var zoom := clampf(value, maxf(min_zoom, whole_region), max_zoom)
	camera.zoom = Vector2(zoom, zoom)
	# Shift the camera so camera.position appears at the centre of the free area.
	camera.offset = Vector2(occluded_right_px / 2.0, 0.0) / zoom
	_overlay.queue_redraw()


func _free_view_size() -> Vector2:
	var view := get_viewport_rect().size
	return Vector2(maxf(view.x - occluded_right_px, 1.0), view.y)


func _view_center() -> Vector2:
	return _free_view_size() / 2.0


func _clamp_camera() -> void:
	camera.position = camera.position.clamp(_map_bounds.position, _map_bounds.end)


# --- Drawing -----------------------------------------------------------------------------

func _draw_overlay() -> void:
	var s := 1.0 / camera.zoom.x  # map units per screen pixel
	_draw_graticule(s)
	_overlay.draw_rect(_map_bounds, WATER_EDGE, false, 3.0 * s)
	for label in _labels:
		var size := 22 if not label.sea else 19
		_draw_text(label.text, label.position, size * s, LABEL_SEA if label.sea else LABEL_COUNTRY, true)
	_draw_weather(s)
	_draw_courses(s)
	for port in catalog.ports:
		_draw_port(port, s)
	_draw_waypoints(s)
	if vessel_geo != Vector2.INF:
		var at := projection.geo_to_map(vessel_geo)
		if not boat_port_id.is_empty():
			at += Vector2(-26, -26) * s
		_draw_boat(at, s, not boat_port_id.is_empty())


func _draw_graticule(s: float) -> void:
	# Keep grid lines at least ~90 px apart.
	var degree_px := units_per_degree / s
	var step := 1
	for candidate in [1, 2, 5, 10, 20]:
		step = candidate
		if candidate * degree_px >= 90.0:
			break
	var lon := ceili(_geo_bounds.position.x / step) * step
	while lon <= _geo_bounds.end.x:
		var a := projection.geo_to_map(Vector2(lon, _geo_bounds.position.y))
		var b := projection.geo_to_map(Vector2(lon, _geo_bounds.end.y))
		_overlay.draw_line(a, b, GRID, 1.0 * s)
		_draw_text("%d°%s" % [absi(lon), "E" if lon >= 0 else "W"], b + Vector2(6, 18) * s, 15 * s, GRID_TEXT, false)
		lon += step
	var lat := ceili(_geo_bounds.position.y / step) * step
	while lat <= _geo_bounds.end.y:
		var a := projection.geo_to_map(Vector2(_geo_bounds.position.x, lat))
		var b := projection.geo_to_map(Vector2(_geo_bounds.end.x, lat))
		_overlay.draw_line(a, b, GRID, 1.0 * s)
		_draw_text("%d°N" % lat, a + Vector2(6, -6) * s, 15 * s, GRID_TEXT, false)
		lat += step


func _draw_weather(s: float) -> void:
	for shape in _weather_shapes:
		var condition: WeatherCondition = shape.condition
		var color: Color = WEATHER_COLORS.get(condition.severity, SEAFOAM)
		var outline: PackedVector2Array = shape.outline
		_overlay.draw_colored_polygon(outline, Color(color, 0.16))
		for i in outline.size():
			var a := outline[i]
			var b := outline[(i + 1) % outline.size()]
			if condition.severity == WeatherCondition.Severity.NONE:
				_overlay.draw_line(a, b, Color(color, 0.7), 2.0 * s, true)
			else:
				_overlay.draw_dashed_line(a, b, Color(color, 0.9), 2.5 * s, 8.0 * s, true, true)
		var center := projection.geo_to_map(condition.get_center())
		var tag: String = ["FAIR", "CAUTION", "DANGER"][condition.severity]
		_draw_text(condition.display_name.to_upper(), center + Vector2(0, -4) * s, 17 * s, Color(color, 1.0), true, true)
		_draw_text(tag, center + Vector2(0, 16) * s, 13 * s, Color(color, 0.95), true, true)


func _draw_courses(s: float) -> void:
	if travelled_path.size() >= 2:
		_overlay.draw_polyline(_to_map(travelled_path), Color(PORT_FILL, 0.45), 2.0 * s, true)
	if active_path.size() >= 2:
		var points := _to_map(active_path)
		_overlay.draw_polyline(points, BRASS, 4.0 * s, true)
		_draw_arrowhead(points, BRASS, s)
	for leg in draft_legs:
		var points := _to_map(leg.path)
		if points.size() < 2:
			continue
		if not leg.ok:
			# Blocked leg: dashed red line with a cross, never only colour.
			for i in range(1, points.size()):
				_overlay.draw_dashed_line(points[i - 1], points[i], INVALID, 3.0 * s, 10.0 * s, true, true)
			var mid := (points[0] + points[points.size() - 1]) / 2.0
			var r := 9.0 * s
			_overlay.draw_line(mid + Vector2(-r, -r), mid + Vector2(r, r), INVALID, 4.0 * s, true)
			_overlay.draw_line(mid + Vector2(-r, r), mid + Vector2(r, -r), INVALID, 4.0 * s, true)
			_draw_text("BLOCKED", mid + Vector2(14, -10) * s, 15 * s, INVALID, false, true)
			continue
		var color := SEAFOAM if draft_is_proposal else BRASS
		for i in range(1, points.size()):
			_overlay.draw_dashed_line(points[i - 1], points[i], color, 3.5 * s, 12.0 * s, true, true)
	if not draft_legs.is_empty() and draft_legs.back().ok:
		_draw_arrowhead(_to_map(draft_legs.back().path), SEAFOAM if draft_is_proposal else BRASS, s)


func _draw_arrowhead(points: PackedVector2Array, color: Color, s: float) -> void:
	if points.size() < 2:
		return
	var end := points[points.size() - 1]
	var direction := (end - points[points.size() - 2]).normalized()
	var tip := end - direction * 14.0 * s
	var side := direction.orthogonal() * 9.0 * s
	_overlay.draw_colored_polygon(PackedVector2Array([tip, tip - direction * 18.0 * s + side,
		tip - direction * 18.0 * s - side]), color)


func _draw_port(port: PortData, s: float) -> void:
	var p := projection.geo_to_map(port.get_geo_position())
	if port.id == selected_port_id:
		_overlay.draw_circle(p, 15.0 * s, BRASS, false, 3.0 * s, true)
	elif port.id == _hovered_port_id:
		_overlay.draw_circle(p, 13.0 * s, HOVER, false, 2.0 * s, true)
	_overlay.draw_circle(p, 8.0 * s, PORT_RIM, true, -1.0, true)
	_overlay.draw_circle(p, 5.5 * s, BRASS if port.id == destination_port_id else PORT_FILL, true, -1.0, true)
	_draw_text(port.display_name, p + Vector2(16, 7) * s, 21 * s, PORT_FILL, false, true)


func _draw_waypoints(s: float) -> void:
	for i in waypoints.size():
		var p := projection.geo_to_map(waypoints[i])
		var r := 9.0 * s
		var diamond := PackedVector2Array([p + Vector2(0, -r), p + Vector2(r, 0), p + Vector2(0, r), p + Vector2(-r, 0)])
		if i == selected_waypoint:
			_overlay.draw_circle(p, 15.0 * s, BRASS, false, 3.0 * s, true)
		var closed := diamond.duplicate()
		closed.append(diamond[0])
		_overlay.draw_colored_polygon(diamond, SEAFOAM)
		_overlay.draw_polyline(closed, PORT_RIM, 2.5 * s, true)
		_draw_text(str(i + 1), p + Vector2(12, -8) * s, 16 * s, PORT_FILL, false, true)
		if i in invalid_waypoints:
			_overlay.draw_line(p + Vector2(-r, -r), p + Vector2(r, r), INVALID, 3.5 * s, true)
			_overlay.draw_line(p + Vector2(-r, r), p + Vector2(r, -r), INVALID, 3.5 * s, true)


func _draw_boat(at: Vector2, s: float, with_leader: bool) -> void:
	# Small sloop glyph echoing the logo, centred on the vessel's position
	# (offset with a leader line when it lies in a port).
	if with_leader:
		_overlay.draw_line(at + Vector2(10, 10) * s, at + Vector2(20, 20) * s, PORT_FILL, 2.0 * s, true)
	var main := PackedVector2Array([at + Vector2(-1, -22) * s, at + Vector2(-1, 2) * s, at + Vector2(-13, 2) * s])
	var jib := PackedVector2Array([at + Vector2(2, -17) * s, at + Vector2(11, 2) * s, at + Vector2(2, 2) * s])
	var hull := PackedVector2Array([at + Vector2(-16, 5) * s, at + Vector2(14, 5) * s,
		at + Vector2(9, 11) * s, at + Vector2(-11, 11) * s])
	if not with_leader:
		_overlay.draw_circle(at, 4.0 * s, BRASS, true, -1.0, true)
	for shape in [main, jib, hull]:
		var outline: PackedVector2Array = shape.duplicate()
		outline.append(shape[0])
		_overlay.draw_polyline(outline, PORT_RIM, 3.0 * s, true)
		_overlay.draw_colored_polygon(shape, BRASS if shape == hull else PORT_FILL)


func _to_map(path: PackedVector2Array) -> PackedVector2Array:
	return projection.geo_polygon_to_map(path)


func _draw_text(text: String, at: Vector2, size: float, color: Color, centered: bool, outlined := false) -> void:
	# Fonts are drawn at a fixed screen size: scale the canvas instead of the
	# font so text stays sharp at every zoom level.
	var font_size := 22
	var factor := size / font_size
	_overlay.draw_set_transform(at, 0.0, Vector2(factor, factor))
	var offset := Vector2.ZERO
	if centered:
		offset.x = -LABEL_FONT.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x / 2.0
	if outlined:
		_overlay.draw_string_outline(LABEL_FONT, offset, text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, 6, PORT_RIM)
	_overlay.draw_string(LABEL_FONT, offset, text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, color)
	_overlay.draw_set_transform(Vector2.ZERO)
