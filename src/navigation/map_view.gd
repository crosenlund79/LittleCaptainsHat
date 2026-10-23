class_name MapView
extends Node2D
## Draws the navigation chart and handles zooming, panning and port picking.
##
## Geography comes from `land_data` (longitude/latitude polygons) and the port
## catalog; MapProjection turns it into map-space units and the Camera2D maps
## those to the screen. Nothing here stores screen or map-space positions in
## game data. The view only displays the route; WorldMap edits it.

signal port_clicked(port_id: StringName)
signal port_hovered(port_id: StringName)
## Cursor position in geographic coordinates, or null when not over the map.
signal cursor_moved(geo: Variant)

@export var land_data: JSON
@export var units_per_degree := 160.0
@export var min_zoom := 0.55
@export var max_zoom := 8.0
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
const ROUTE := Color("#C79F6D")
const SELECT := Color("#C79F6D")
const HOVER := Color("#A6C4C9")
const LABEL_COUNTRY := Color(0.36, 0.31, 0.22, 0.75)
const LABEL_SEA := Color(0.651, 0.769, 0.788, 0.55)

const LABEL_FONT: Font = preload("res://assets/fonts/Barlow-SemiBold.ttf")
const PICK_RADIUS_PX := 22.0
const ZOOM_STEP := 1.2
const CLICK_SLOP_PX := 6.0

var projection: MapProjection
var catalog: PortCatalog

var boat_port_id: StringName
var selected_port_id: StringName
var route_path := PackedVector2Array()

var _geo_bounds := Rect2()
var _map_bounds := Rect2()
var _coastlines: Array[PackedVector2Array] = []
var _labels: Array[Dictionary] = []
var _hovered_port_id: StringName
var _press_position := Vector2.ZERO
var _left_pressed := false
var _dragging := false

@onready var camera: Camera2D = $Camera2D
@onready var _land: Node2D = $Land
@onready var _overlay: Node2D = $Overlay


func _ready() -> void:
	projection = MapProjection.new(units_per_degree)
	catalog = PortCatalog.get_default()
	_overlay.draw.connect(_draw_overlay)
	_build_land()
	reset_view()


# --- Public API --------------------------------------------------------------------

func set_markers(boat_port: StringName, selected: StringName, route: PlannedRoute) -> void:
	boat_port_id = boat_port
	selected_port_id = selected
	route_path = route.get_geo_path(catalog) if route else PackedVector2Array()
	_overlay.queue_redraw()


## Fills the visible chart area with the whole region.
func reset_view() -> void:
	var free := _free_view_size()
	_set_zoom(maxf(free.x / _map_bounds.size.x, free.y / _map_bounds.size.y))
	camera.position = _map_bounds.get_center()
	_clamp_camera()


func center_on_geo(geo: Vector2) -> void:
	camera.position = projection.geo_to_map(geo)
	_clamp_camera()
	_overlay.queue_redraw()


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


func get_port_screen_position(port_id: StringName) -> Vector2:
	var port := catalog.get_port(port_id)
	return map_to_screen(projection.geo_to_map(port.get_geo_position())) if port else Vector2.INF


## Port id under a screen position, or &"" if none is within reach.
func pick_port(screen_point: Vector2) -> StringName:
	var best: StringName = &""
	var best_distance := PICK_RADIUS_PX
	for port in catalog.ports:
		var distance := map_to_screen(projection.geo_to_map(port.get_geo_position())).distance_to(screen_point)
		if distance <= best_distance:
			best_distance = distance
			best = port.id
	return best


# --- Input -------------------------------------------------------------------------

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
				_left_pressed = true
				_dragging = false
				_press_position = event.position
			elif _left_pressed:
				_left_pressed = false
				if not _dragging:
					port_clicked.emit(pick_port(event.position))
				_dragging = false
		MOUSE_BUTTON_RIGHT, MOUSE_BUTTON_MIDDLE:
			_dragging = event.pressed
		_:
			return
	get_viewport().set_input_as_handled()


func _handle_mouse_motion(event: InputEventMouseMotion) -> void:
	if _left_pressed and not _dragging and event.position.distance_to(_press_position) > CLICK_SLOP_PX:
		_dragging = true
	if _dragging and (_left_pressed or event.button_mask & (MOUSE_BUTTON_MASK_RIGHT | MOUSE_BUTTON_MASK_MIDDLE)):
		camera.position -= event.relative / camera.zoom.x
		_clamp_camera()
		_overlay.queue_redraw()
	elif _dragging and not _left_pressed and event.button_mask == 0:
		_dragging = false
	var hovered := pick_port(event.position)
	if hovered != _hovered_port_id:
		_hovered_port_id = hovered
		port_hovered.emit(hovered)
		_overlay.queue_redraw()
	var map_point := screen_to_map(event.position)
	cursor_moved.emit(projection.map_to_geo(map_point) if _map_bounds.has_point(map_point) else null)


func _process(delta: float) -> void:
	var direction := Input.get_vector(&"move_left", &"move_right", &"move_up", &"move_down")
	if direction != Vector2.ZERO:
		camera.position += direction * keyboard_pan_speed * delta / camera.zoom.x
		_clamp_camera()
		_overlay.queue_redraw()


# --- Internals ---------------------------------------------------------------------

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

	for ring: Array in data.get("polygons", []):
		var geo := PackedVector2Array()
		for point: Array in ring:
			geo.append(Vector2(point[0], point[1]))
		var points := projection.geo_polygon_to_map(geo)
		var polygon := Polygon2D.new()
		polygon.color = LAND
		polygon.antialiased = true
		polygon.polygon = points
		_land.add_child(polygon)
		var closed := points.duplicate()
		closed.append(points[0])
		_coastlines.append(closed)
	for label: Dictionary in data.get("labels", []):
		_labels.append({
			"text": label.get("text", ""),
			"position": projection.geo_to_map(Vector2(label.get("lon", 0.0), label.get("lat", 0.0))),
			"sea": label.get("kind", "") == "sea",
		})


func _set_zoom(value: float) -> void:
	# Never zoom out further than showing the whole region.
	var free := _free_view_size()
	var whole_region := minf(free.x / _map_bounds.size.x, free.y / _map_bounds.size.y) * 0.9
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


func _draw_overlay() -> void:
	var s := 1.0 / camera.zoom.x  # map units per screen pixel
	_draw_graticule(s)
	for line in _coastlines:
		_overlay.draw_polyline(line, COAST, 1.4 * s, true)
	_overlay.draw_rect(_map_bounds, WATER_EDGE, false, 3.0 * s)
	for label in _labels:
		var size := 22 if not label.sea else 19
		_draw_text(label.text, label.position, size * s, LABEL_SEA if label.sea else LABEL_COUNTRY, true)
	_draw_route(s)
	for port in catalog.ports:
		_draw_port(port, s)


func _draw_graticule(s: float) -> void:
	for lon in range(ceili(_geo_bounds.position.x), floori(_geo_bounds.end.x) + 1):
		var a := projection.geo_to_map(Vector2(lon, _geo_bounds.position.y))
		var b := projection.geo_to_map(Vector2(lon, _geo_bounds.end.y))
		_overlay.draw_line(a, b, GRID, 1.0 * s)
		_draw_text("%d°E" % lon, b + Vector2(6, 18) * s, 15 * s, GRID_TEXT, false)
	for lat in range(ceili(_geo_bounds.position.y), floori(_geo_bounds.end.y) + 1):
		var a := projection.geo_to_map(Vector2(_geo_bounds.position.x, lat))
		var b := projection.geo_to_map(Vector2(_geo_bounds.end.x, lat))
		_overlay.draw_line(a, b, GRID, 1.0 * s)
		_draw_text("%d°N" % lat, a + Vector2(6, -6) * s, 15 * s, GRID_TEXT, false)


func _draw_route(s: float) -> void:
	if route_path.size() < 2:
		return
	var points := projection.geo_polygon_to_map(route_path)
	for i in range(1, points.size()):
		_overlay.draw_dashed_line(points[i - 1], points[i], ROUTE, 4.0 * s, 14.0 * s, true, true)
	# Arrowhead just short of the destination marker.
	var end := points[points.size() - 1]
	var direction := (end - points[points.size() - 2]).normalized()
	var tip := end - direction * 14.0 * s
	var side := direction.orthogonal() * 9.0 * s
	_overlay.draw_colored_polygon(PackedVector2Array([tip, tip - direction * 18.0 * s + side,
		tip - direction * 18.0 * s - side]), ROUTE)


func _draw_port(port: PortData, s: float) -> void:
	var p := projection.geo_to_map(port.get_geo_position())
	if port.id == selected_port_id:
		_overlay.draw_circle(p, 15.0 * s, SELECT, false, 3.0 * s, true)
	elif port.id == _hovered_port_id:
		_overlay.draw_circle(p, 13.0 * s, HOVER, false, 2.0 * s, true)
	var is_destination := route_path.size() >= 2 and port.id != boat_port_id \
			and projection.geo_to_map(route_path[route_path.size() - 1]).is_equal_approx(p)
	_overlay.draw_circle(p, 8.0 * s, PORT_RIM, true, -1.0, true)
	_overlay.draw_circle(p, 5.5 * s, ROUTE if is_destination else PORT_FILL, true, -1.0, true)
	_draw_text(port.display_name, p + Vector2(16, 7) * s, 21 * s, PORT_FILL, false, true)
	if port.id == boat_port_id:
		_draw_boat(p + Vector2(-26, -26) * s, s)


func _draw_boat(at: Vector2, s: float) -> void:
	# Small sloop glyph echoing the logo, with a leader to its port.
	_overlay.draw_line(at + Vector2(10, 10) * s, at + Vector2(20, 20) * s, PORT_FILL, 2.0 * s, true)
	var main := PackedVector2Array([at + Vector2(-1, -22) * s, at + Vector2(-1, 2) * s, at + Vector2(-13, 2) * s])
	var jib := PackedVector2Array([at + Vector2(2, -17) * s, at + Vector2(11, 2) * s, at + Vector2(2, 2) * s])
	var hull := PackedVector2Array([at + Vector2(-16, 5) * s, at + Vector2(14, 5) * s,
		at + Vector2(9, 11) * s, at + Vector2(-11, 11) * s])
	for shape in [main, jib, hull]:
		var outline: PackedVector2Array = shape.duplicate()
		outline.append(shape[0])
		_overlay.draw_polyline(outline, PORT_RIM, 3.0 * s, true)
		_overlay.draw_colored_polygon(shape, ROUTE if shape == hull else PORT_FILL)


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
