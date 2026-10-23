class_name WorldMap
extends Node2D
## The chart screen: shows Europe, the vessel's actual position, the active or
## planned course and weather areas, and lets the player plan and edit a course.
##
## Editing happens on a *draft*. The committed course (GameSession's planned
## route in port, or the active voyage at sea) is never touched until the
## player presses Apply, and only a fully valid draft can be applied. Discard
## returns to the committed course. All routes come from SeaRouter, so the
## course shown is exactly the course the vessel will sail.

signal close_requested
signal depart_requested

## Width of the side panel plus its margin, in unscaled UI pixels.
const SIDE_PANEL_WIDTH := 544.0
## Minimum real time between route recalculations while dragging a waypoint.
const DRAG_RECALC_INTERVAL := 0.1
const LIVE_REFRESH_INTERVAL := 0.25

var _selected_port_id: StringName
var _draft_destination: StringName
var _draft_waypoints: Array[Vector2] = []
## Legs of the draft as [{"path", "ok"}] and its validated route (or null).
var _draft_legs: Array[Dictionary] = []
var _draft_route: PlannedRoute
var _draft_error := ""
var _draft_dirty := false
var _selected_waypoint := -1
var _dragging_waypoint := -1
var _pending_drag_geo := Vector2.INF
var _drag_timer := 0.0
var _live_timer := 0.0
var _feedback := ""

@onready var _map: MapView = $MapView
@onready var _status: Label = %StatusLabel
@onready var _position: Label = %PositionLabel
@onready var _clock: Label = %ClockLabel
@onready var _voyage_box: Control = %VoyageBox
@onready var _voyage_bar: ProgressBar = %VoyageProgress
@onready var _voyage_label: Label = %VoyageLabel
@onready var _selection_title: Label = %SelectionTitle
@onready var _selection_details: Label = %SelectionDetails
@onready var _plot_button: Button = %PlotButton
@onready var _course_label: Label = %CourseLabel
@onready var _course_status: Label = %CourseStatus
@onready var _apply_button: Button = %ApplyButton
@onready var _discard_button: Button = %DiscardButton
@onready var _remove_button: Button = %RemoveWaypointButton
@onready var _clear_button: Button = %ClearButton
@onready var _sail_button: Button = %SetSailButton
@onready var _weather_label: Label = %WeatherLabel
@onready var _cursor_label: Label = %CursorLabel


func _ready() -> void:
	_fit_map_to_free_area(SettingsManager.get_ui_scale())
	SettingsManager.ui_scale_changed.connect(_fit_map_to_free_area)
	_map.port_clicked.connect(select_port)
	_map.map_clicked.connect(func(_geo: Vector2) -> void: _select_waypoint(-1))
	_map.route_pressed.connect(_on_route_pressed)
	_map.waypoint_pressed.connect(_select_waypoint)
	_map.waypoint_dragged.connect(_on_waypoint_dragged)
	_map.waypoint_released.connect(_on_waypoint_released)
	_map.waypoint_remove_requested.connect(remove_waypoint)
	_map.cursor_moved.connect(_on_cursor_moved)
	_plot_button.pressed.connect(func() -> void: plot_course_to(_selected_port_id))
	_apply_button.pressed.connect(apply_course)
	_discard_button.pressed.connect(discard_changes)
	_remove_button.pressed.connect(func() -> void: remove_waypoint(_selected_waypoint))
	_clear_button.pressed.connect(clear_course)
	_sail_button.pressed.connect(depart_requested.emit)
	%BackButton.pressed.connect(close_requested.emit)
	%ZoomInButton.pressed.connect(_map.zoom_by.bind(MapView.ZOOM_STEP))
	%ZoomOutButton.pressed.connect(_map.zoom_by.bind(1.0 / MapView.ZOOM_STEP))
	%ResetViewButton.pressed.connect(_map.reset_view)
	%CenterBoatButton.pressed.connect(center_on_vessel)
	GameSession.route_changed.connect(_on_committed_changed)
	GameSession.voyage_started.connect(_on_committed_changed)
	GameSession.voyage_course_changed.connect(_on_committed_changed)
	GameSession.voyage_arrived.connect(_on_committed_changed)
	_load_committed()
	_selected_port_id = _draft_destination
	_refresh()
	center_on_vessel()


func _process(delta: float) -> void:
	if _dragging_waypoint >= 0 and _pending_drag_geo != Vector2.INF:
		_drag_timer -= delta
		if _drag_timer <= 0.0:
			_move_waypoint(_dragging_waypoint, _pending_drag_geo)
			_pending_drag_geo = Vector2.INF
			_drag_timer = DRAG_RECALC_INTERVAL
	_live_timer -= delta
	if _live_timer <= 0.0:
		_live_timer = LIVE_REFRESH_INTERVAL
		# The vessel keeps sailing while the chart is open.
		if GameSession.is_underway() and not _draft_dirty and _dragging_waypoint < 0:
			_load_committed()
		_refresh()


func _unhandled_key_input(event: InputEvent) -> void:
	var key := event as InputEventKey
	if key and key.pressed and not key.echo and key.keycode in [KEY_DELETE, KEY_BACKSPACE] and _selected_waypoint >= 0:
		remove_waypoint(_selected_waypoint)
		get_viewport().set_input_as_handled()


## Called by the application when Esc is pressed on this screen.
func handle_back() -> void:
	close_requested.emit()


func has_unapplied_changes() -> bool:
	return _draft_dirty


# --- Planning actions (also used by tests) ------------------------------------------------

func select_port(port_id: StringName) -> void:
	_selected_port_id = port_id
	_refresh()


func get_selected_port_id() -> StringName:
	return _selected_port_id


## Starts a new draft: an automatic sea route from the vessel to the port.
func plot_course_to(port_id: StringName) -> void:
	if port_id.is_empty():
		return
	_draft_destination = port_id
	_draft_waypoints.clear()
	_selected_waypoint = -1
	_draft_dirty = true
	_feedback = ""
	_recalculate()


## Inserts a waypoint into leg `leg_index` (0 = before the first waypoint).
func insert_waypoint(leg_index: int, geo: Vector2) -> int:
	var index := clampi(leg_index, 0, _draft_waypoints.size())
	_draft_waypoints.insert(index, geo)
	_selected_waypoint = index
	_draft_dirty = true
	_recalculate()
	return index


func remove_waypoint(index: int) -> void:
	if index < 0 or index >= _draft_waypoints.size():
		return
	_draft_waypoints.remove_at(index)
	_selected_waypoint = -1
	_draft_dirty = true
	_recalculate()


## Moves a waypoint and recalculates the legs on either side of it.
func move_waypoint(index: int, geo: Vector2) -> void:
	_move_waypoint(index, geo)


## Makes the draft the committed course. In port it becomes the planned
## route; at sea the voyage changes course from the vessel's current position.
func apply_course() -> String:
	if _draft_route == null:
		return _set_feedback("This course cannot be used: %s" % _draft_error)
	var error := ""
	if GameSession.is_underway():
		error = GameSession.change_course(_draft_destination, _draft_waypoints)
	else:
		error = GameSession.set_planned_route(_draft_route)
	if not error.is_empty():
		return _set_feedback("Course not changed: %s Your current course is unchanged." % error)
	_draft_dirty = false
	_load_committed()
	_set_feedback("Course set for %s." % PortCatalog.get_default().get_display_name(_draft_destination))
	return ""


func discard_changes() -> void:
	_draft_dirty = false
	_load_committed()
	_set_feedback("Changes discarded.")


func clear_course() -> void:
	if GameSession.is_underway():
		return
	GameSession.clear_planned_route()
	_draft_dirty = false
	_load_committed()


func center_on_vessel() -> void:
	_map.center_on_geo(GameSession.get_vessel_position(), maxf(_map.get_zoom(), 0.6))


func get_map_view() -> MapView:
	return _map


func get_draft_route() -> PlannedRoute:
	return _draft_route


func get_draft_error() -> String:
	return _draft_error


func get_draft_waypoints() -> Array[Vector2]:
	return _draft_waypoints.duplicate()


func get_draft_legs() -> Array[Dictionary]:
	return _draft_legs


# --- Draft handling -------------------------------------------------------------------------

## Resets the draft to the committed course (planned route or active voyage).
func _load_committed() -> void:
	_draft_legs.clear()
	_draft_route = null
	_draft_error = ""
	_draft_waypoints.clear()
	_draft_destination = &""
	if GameSession.is_underway():
		var voyage := GameSession.get_voyage()
		_draft_destination = voyage.route.destination_port_id
		_draft_waypoints = voyage.get_remaining_waypoints()
		var remaining := voyage.get_remaining_path()
		for leg in _split_at_waypoints(remaining, _draft_waypoints):
			_draft_legs.append({"path": leg, "ok": true})
	else:
		var planned := GameSession.get_planned_route()
		if planned and planned.has_path():
			_draft_route = planned
			_draft_destination = planned.destination_port_id
			_draft_waypoints = planned.waypoints.duplicate()
			for leg_range in planned.get_leg_ranges():
				_draft_legs.append({"path": planned.path.slice(leg_range.x, leg_range.y + 1), "ok": true})
	if _selected_waypoint >= _draft_waypoints.size():
		_selected_waypoint = -1


func _recalculate() -> void:
	_feedback = ""  # A new edit makes earlier messages ("Course set…") stale.
	var location := GameSession.get_location()
	var origin_port: StringName = location.id if location and not GameSession.is_underway() else &""
	var result := SeaRouter.get_default().plan_route(origin_port, GameSession.get_vessel_position(),
		_draft_waypoints, _draft_destination)
	_draft_route = result.route
	_draft_error = result.error
	_draft_legs.clear()
	var stops: Array[Vector2] = [GameSession.get_vessel_position()]
	stops.append_array(_draft_waypoints)
	var destination := PortCatalog.get_default().get_port(_draft_destination)
	if destination:
		stops.append(destination.get_geo_position())
	for i in result.legs.size():
		var leg: SeaRouter.Leg = result.legs[i]
		if leg.ok:
			_draft_legs.append({"path": leg.path, "ok": true})
		elif i + 1 < stops.size():
			_draft_legs.append({"path": PackedVector2Array([stops[i], stops[i + 1]]), "ok": false})
	_refresh()


func _move_waypoint(index: int, geo: Vector2) -> void:
	if index < 0 or index >= _draft_waypoints.size():
		return
	_draft_waypoints[index] = geo
	_draft_dirty = true
	_recalculate()


func _select_waypoint(index: int) -> void:
	_selected_waypoint = index
	_refresh()


func _on_route_pressed(leg_index: int, geo: Vector2) -> void:
	var index := insert_waypoint(leg_index, geo)
	_dragging_waypoint = index
	_map.begin_waypoint_drag(index)


func _on_waypoint_dragged(index: int, geo: Vector2) -> void:
	_dragging_waypoint = index
	_selected_waypoint = index
	_pending_drag_geo = geo
	if index < _draft_waypoints.size():
		_draft_waypoints[index] = geo  # Marker follows the mouse; legs follow at a throttled rate.
		_refresh_map_only()


func _on_waypoint_released(index: int, geo: Vector2) -> void:
	_dragging_waypoint = -1
	_pending_drag_geo = Vector2.INF
	_move_waypoint(index, geo)


func _on_committed_changed(_value: Variant = null) -> void:
	if not _draft_dirty:
		_load_committed()
	_refresh()


## Splits a path into legs at the given waypoint positions (which are path points).
static func _split_at_waypoints(path: PackedVector2Array, points: Array[Vector2]) -> Array[PackedVector2Array]:
	var legs: Array[PackedVector2Array] = []
	var current := PackedVector2Array()
	var next := 0
	for p in path:
		current.append(p)
		if next < points.size() and p.is_equal_approx(points[next]) and current.size() > 1:
			legs.append(current)
			current = PackedVector2Array([p])
			next += 1
	if current.size() > 1:
		legs.append(current)
	return legs


func _set_feedback(text: String) -> String:
	_feedback = text
	_refresh()
	return text


# --- Presentation ----------------------------------------------------------------------------

func _refresh_map_only() -> void:
	var invalid := PackedInt32Array()
	var router := SeaRouter.get_default()
	for i in _draft_waypoints.size():
		if not router.is_point_navigable(_draft_waypoints[i]):
			invalid.append(i)
	var voyage := GameSession.get_voyage()
	var display := {
		"boat_port_id": GameSession.get_location_id(),
		"selected_port_id": _selected_port_id,
		"destination_port_id": _draft_destination,
		"vessel_geo": GameSession.get_vessel_position(),
		"draft_legs": _draft_legs,
		"draft_is_proposal": _draft_dirty,
		"waypoints": _draft_waypoints,
		"invalid_waypoints": invalid,
		"selected_waypoint": _selected_waypoint,
		"editing_enabled": not _draft_legs.is_empty(),
	}
	if voyage:
		var travelled := PackedVector2Array()
		var cumulative := voyage.get_cumulative()
		for i in voyage.route.path.size():
			if cumulative[i] <= voyage.progress_nm:
				travelled.append(voyage.route.path[i])
		travelled.append(voyage.get_position())
		display["travelled_path"] = travelled
		if _draft_dirty:
			display["active_path"] = voyage.get_remaining_path()
	_map.set_display(display)


func _refresh() -> void:
	_refresh_map_only()
	var catalog := PortCatalog.get_default()
	var speed := GameSession.get_vessel_speed_kn()
	var location := GameSession.get_location()

	# Status and clock.
	if GameSession.is_underway():
		_status.text = "Underway to %s  ·  %.1f kn" % [catalog.get_display_name(GameSession.get_voyage_destination_id()), speed]
	elif location:
		var verb := "Arrived at" if GameSession.get_vessel_status() == SessionState.STATUS_ARRIVED else "Moored at"
		_status.text = "%s %s, %s" % [verb, location.display_name, location.country]
	_position.text = GeoMath.format_position(GameSession.get_vessel_position())
	_clock.text = Simulation.format_game_time(GameSession.get_game_time())

	# Voyage progress.
	_voyage_box.visible = GameSession.is_underway()
	if GameSession.is_underway():
		var total := GameSession.get_voyage_total_nm()
		var remaining := GameSession.get_voyage_remaining_nm()
		_voyage_bar.value = 100.0 * (1.0 - remaining / total) if total > 0.0 else 100.0
		var eta := GameSession.get_game_time() + remaining / speed * 3600.0
		_voyage_label.text = "%d nm to go  ·  ETA %s" % [roundi(remaining), Simulation.format_game_time(eta)]

	# Selected port.
	var selected := catalog.get_port(_selected_port_id)
	if selected == null:
		_selection_title.text = "No port selected"
		_selection_details.text = "Click a port on the chart to choose a destination."
		_plot_button.disabled = true
		_plot_button.text = "Plot course"
	else:
		_selection_title.text = "%s, %s" % [selected.display_name, selected.country]
		_selection_details.text = "%s\n%s  ·  %d nm in a straight line" % [selected.description,
			GeoMath.format_position(selected.get_geo_position()),
			roundi(GeoMath.distance_nm(GameSession.get_vessel_position(), selected.get_geo_position()))]
		var here := location != null and selected.id == location.id and not GameSession.is_underway()
		_plot_button.disabled = here
		_plot_button.text = "You are here" if here else "Plot course to %s" % selected.display_name

	# Course.
	if _draft_destination.is_empty():
		_course_label.text = "No course planned."
	else:
		var distance := GeoMath.path_length_nm(_draft_route.path) if _draft_route else -1.0
		if _draft_route == null and not _draft_dirty and GameSession.is_underway():
			distance = GameSession.get_voyage_remaining_nm()
		var summary := "To %s" % catalog.get_display_name(_draft_destination)
		if distance >= 0.0:
			summary += "  ·  %d nm  ·  about %s at %.1f kn" % [roundi(distance),
				Simulation.format_duration(distance / speed * 3600.0), speed]
		if not _draft_waypoints.is_empty():
			summary += "\n%d waypoint%s" % [_draft_waypoints.size(), "" if _draft_waypoints.size() == 1 else "s"]
		_course_label.text = summary
	var valid := _draft_route != null or (not _draft_dirty and not _draft_legs.is_empty())
	if _draft_destination.is_empty():
		_course_status.text = ""
	elif not valid:
		_course_status.text = "NOT NAVIGABLE: %s" % _draft_error
	elif _draft_dirty:
		_course_status.text = "Sea route found. Press %s to use it." % ("Change course" if GameSession.is_underway() else "Apply course")
	else:
		_course_status.text = "Current course" + (" (being sailed)" if GameSession.is_underway() else "")
	if not _feedback.is_empty():
		_course_status.text += "\n" + _feedback
	_apply_button.text = "Change course" if GameSession.is_underway() else "Apply course"
	_apply_button.disabled = not _draft_dirty or _draft_route == null
	_discard_button.disabled = not _draft_dirty
	_remove_button.disabled = _selected_waypoint < 0
	_clear_button.disabled = GameSession.is_underway() or GameSession.get_planned_route() == null
	_sail_button.visible = not GameSession.is_underway()
	_sail_button.disabled = _draft_dirty or GameSession.get_planned_route() == null

	_weather_label.text = _describe_weather()


func _describe_weather() -> String:
	var path := PackedVector2Array()
	for leg in _draft_legs:
		if not leg.ok:
			return "Weather along the course is shown once the course is navigable."
		for p: Vector2 in leg.path:
			if path.is_empty() or not path[path.size() - 1].is_equal_approx(p):
				path.append(p)
	if path.size() < 2:
		return "Plot a course to see the weather along it."
	var encounters := WeatherCatalog.get_default().find_encounters(path, GeoMath.cumulative_distances(path), 0.0)
	if encounters.is_empty():
		return "No warnings along this course."
	var lines := PackedStringArray()
	var speed := GameSession.get_vessel_speed_kn()
	for encounter in encounters:
		var condition: WeatherCondition = encounter.condition
		lines.append("%s (%s) in %d nm, about %s" % [condition.display_name,
			"danger" if condition.severity == WeatherCondition.Severity.DANGER else "caution",
			roundi(encounter.at_nm), Simulation.format_duration(encounter.at_nm / speed * 3600.0)])
	return "\n".join(lines)


func _fit_map_to_free_area(ui_scale: float) -> void:
	_map.occluded_right_px = SIDE_PANEL_WIDTH * ui_scale
	_map.reset_view()


func _on_cursor_moved(geo: Variant) -> void:
	_cursor_label.text = GeoMath.format_position(geo) if geo is Vector2 else ""
