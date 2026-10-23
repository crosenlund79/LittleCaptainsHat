class_name Hud
extends Control
## Gameplay overlay shared by both boat areas: area and location, game clock
## with time acceleration, voyage status (destination, speed, progress, ETA),
## weather warnings, the interaction prompt and a menu button.
##
## The HUD only reads state; it refreshes its text every frame from
## GameSession, so it can never drift from the simulation.

signal menu_requested
signal chart_requested

@onready var _area: Label = %AreaLabel
@onready var _location: Label = %LocationLabel
@onready var _clock: Label = %ClockLabel
@onready var _route_caption: Label = %RouteCaption
@onready var _route: Label = %RouteLabel
@onready var _route_detail: Label = %RouteDetail
@onready var _progress: ProgressBar = %VoyageProgress
@onready var _propulsion: Label = %PropulsionLabel
@onready var _wind: Label = %WindLabel
@onready var _prompt_panel: Control = %PromptPanel
@onready var _prompt: Label = %PromptLabel
@onready var _warning_panel: Control = %WarningPanel
@onready var _warning_text: Label = %WarningText


var _planned_key := ""
var _planned_estimated_at := -INF
var _planned_seconds := 0.0


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	%MenuButton.pressed.connect(menu_requested.emit)
	%WarningChartButton.pressed.connect(func() -> void:
		hide_warning()
		chart_requested.emit())
	%WarningDismissButton.pressed.connect(hide_warning)
	set_prompt("")
	hide_warning()


func _process(_delta: float) -> void:
	if is_visible_in_tree():
		refresh()


func set_area(area: StringName) -> void:
	_area.text = SessionState.get_area_display_name(area)


func set_prompt(text: String) -> void:
	_prompt.text = text
	_prompt_panel.visible = not text.is_empty()


func get_prompt() -> String:
	return _prompt.text if _prompt_panel.visible else ""


func show_warning(text: String) -> void:
	_warning_text.text = text
	_warning_panel.show()


func hide_warning() -> void:
	_warning_panel.hide()


func is_warning_visible() -> bool:
	return _warning_panel.visible


func get_route_text() -> String:
	return _route.text


func refresh() -> void:
	if not GameSession.is_active():
		return
	var catalog := PortCatalog.get_default()
	_clock.text = Simulation.format_game_time(GameSession.get_game_time())
	var wind := Simulation.get_wind_at(GameSession.get_vessel_position())
	_wind.text = describe_wind(wind)
	if GameSession.is_underway():
		var destination := catalog.get_display_name(GameSession.get_voyage_destination_id())
		var remaining := GameSession.get_voyage_remaining_nm()
		var total := GameSession.get_voyage_total_nm()
		var propulsion := GameSession.get_propulsion()
		_location.text = "Underway to %s" % destination
		_route_caption.text = "Underway  ·  %.1f kn" % GameSession.get_vessel_speed_kn()
		_route.text = "To %s  ·  %d nm to go" % [destination, roundi(remaining)]
		_route_detail.text = "ETA about %s (estimate)" % Simulation.format_game_time(Simulation.get_eta())
		_propulsion.text = propulsion.describe()
		_propulsion.visible = true
		var side := PropulsionState.wind_side(propulsion.true_wind_angle)
		_wind.text += "  ·  %d° %s" % [roundi(absf(propulsion.true_wind_angle)), side if side else "off the bow"]
		_progress.visible = true
		_progress.value = 100.0 * (1.0 - remaining / total) if total > 0.0 else 100.0
	else:
		var location := GameSession.get_location()
		var arrived := GameSession.get_vessel_status() == SessionState.STATUS_ARRIVED
		_location.text = "%s %s" % ["Arrived at" if arrived else "Moored at", location.display_name if location else "?"]
		var planned := GameSession.get_planned_route()
		_route_caption.text = "Planned route"
		_route.text = PlannedRoute.describe(planned, catalog)
		if planned and planned.has_path():
			var key := "%s|%d|%.3f" % [planned.destination_port_id, planned.path.size(), planned.get_distance_nm()]
			if key != _planned_key or GameSession.get_game_time() - _planned_estimated_at > 1800.0:
				_planned_key = key
				_planned_estimated_at = GameSession.get_game_time()
				_planned_seconds = Simulation.estimate_route_seconds(planned.path)
			_route_detail.text = "About %s with the expected wind  ·  set sail at the helm" % \
				Simulation.format_duration(_planned_seconds)
		else:
			_route_detail.text = "Plot a course at the chart table"
		_propulsion.visible = false
		_progress.visible = false


## "Wind WSW 14 kn" (where it blows from).
static func describe_wind(wind: WindField.Sample) -> String:
	if wind.speed_kn < 0.5:
		return "Wind calm"
	return "Wind %s %d kn" % [WindField.compass_name(wind.from_deg), roundi(wind.speed_kn)]
