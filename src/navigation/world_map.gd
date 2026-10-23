class_name WorldMap
extends Node2D
## The chart screen: shows the map with the boat's position, lets the player
## select a port and plot or clear a route. Route changes go through
## GameSession, which owns the planned route.

signal close_requested

var _selected_port_id: StringName

@onready var _map: MapView = $MapView
@onready var _position_label: Label = %PositionLabel
@onready var _position_coords: Label = %PositionCoords
@onready var _selection_title: Label = %SelectionTitle
@onready var _selection_details: Label = %SelectionDetails
@onready var _plot_button: Button = %PlotButton
@onready var _route_label: Label = %RouteLabel
@onready var _clear_button: Button = %ClearButton
@onready var _cursor_label: Label = %CursorLabel


## Width of the side panel plus its margin, in unscaled UI pixels.
const SIDE_PANEL_WIDTH := 544.0


func _ready() -> void:
	_fit_map_to_free_area(SettingsManager.get_ui_scale())
	SettingsManager.ui_scale_changed.connect(_fit_map_to_free_area)
	_map.port_clicked.connect(select_port)
	_map.cursor_moved.connect(_on_cursor_moved)
	_plot_button.pressed.connect(plot_course)
	_clear_button.pressed.connect(clear_course)
	%BackButton.pressed.connect(close_requested.emit)
	%ZoomInButton.pressed.connect(_map.zoom_by.bind(MapView.ZOOM_STEP))
	%ZoomOutButton.pressed.connect(_map.zoom_by.bind(1.0 / MapView.ZOOM_STEP))
	%ResetViewButton.pressed.connect(_map.reset_view)
	%CenterBoatButton.pressed.connect(_center_on_boat)
	GameSession.route_changed.connect(_on_route_changed)
	var route := GameSession.get_planned_route()
	_selected_port_id = route.destination_port_id if route else &""
	_refresh()


## Called by the application when Esc is pressed on this screen.
func handle_back() -> void:
	close_requested.emit()


func select_port(port_id: StringName) -> void:
	_selected_port_id = port_id
	_refresh()


func get_selected_port_id() -> StringName:
	return _selected_port_id


func plot_course() -> void:
	GameSession.plan_route_to(_selected_port_id)


func clear_course() -> void:
	GameSession.clear_planned_route()


func get_map_view() -> MapView:
	return _map


func _fit_map_to_free_area(ui_scale: float) -> void:
	_map.occluded_right_px = SIDE_PANEL_WIDTH * ui_scale
	_map.reset_view()


func _center_on_boat() -> void:
	var location := GameSession.get_location()
	if location:
		_map.center_on_geo(location.get_geo_position())


func _refresh() -> void:
	var catalog := PortCatalog.get_default()
	var location := GameSession.get_location()
	var route := GameSession.get_planned_route()
	_map.set_markers(GameSession.get_location_id(), _selected_port_id, route)

	if location:
		_position_label.text = "Moored at %s, %s" % [location.display_name, location.country]
		_position_coords.text = GeoMath.format_position(location.get_geo_position())

	var selected := catalog.get_port(_selected_port_id)
	if selected == null:
		_selection_title.text = "No port selected"
		_selection_details.text = "Click a port on the chart to select it."
		_plot_button.disabled = true
	else:
		_selection_title.text = "%s, %s" % [selected.display_name, selected.country]
		var lines := [selected.description, GeoMath.format_position(selected.get_geo_position())]
		if location and selected.id != location.id:
			lines.append("Direct distance: %d nm" % roundi(
				GeoMath.distance_nm(location.get_geo_position(), selected.get_geo_position())))
		_selection_details.text = "\n".join(lines)
		var already_planned := route != null and route.destination_port_id == selected.id
		_plot_button.disabled = location == null or selected.id == location.id or already_planned
		if location and selected.id == location.id:
			_plot_button.text = "You are here"
		elif already_planned:
			_plot_button.text = "Course set for %s" % selected.display_name
		elif route:
			_plot_button.text = "Change course to %s" % selected.display_name
		else:
			_plot_button.text = "Plot course to %s" % selected.display_name

	_route_label.text = PlannedRoute.describe(route, catalog)
	_clear_button.disabled = route == null


func _on_route_changed(_route: PlannedRoute) -> void:
	_refresh()


func _on_cursor_moved(geo: Variant) -> void:
	_cursor_label.text = GeoMath.format_position(geo) if geo is Vector2 else ""
