class_name SailingPanel
extends PanelContainer
## The sailing panel (Iteration 17): on the right of the screen while
## underway, the numbers a skipper glances at.
## - Speed (over the ground, as the boat sails) and how it is driven.
## - Heading: the boat's actual heading, and whether it is on the planned
##   course (the autopilot follows the route's legs).
## - Wind at the boat now: direction, speed, angle to the boat.
## - Next leg: the course after the next turn and the wind forecast there
##   for when the boat gets there (a forecast made now: it only knows the
##   weather that has formed by now; labelled as an estimate).
## - Next course change: time and distance to the next turn, or a clear
##   "no more turns" before the destination; nothing invented.
## - Remaining distance and ETA (estimate): kept for tests and diagnostics but
##   not shown, since the route panel right above already says it.
## A course change of more than COURSE_CHANGE_DEG gets a short, restrained
## highlight of the new course (one gentle pulse with Reduce flashing on).
## Collapsible (its header button); reads state only.

const COURSE_CHANGE_DEG := 5.0
## Kept for the game run (not saved): collapsed or full.
static var collapsed := false

var _title: Label
var _toggle: Button
var _rows := {}
var _course_key := Vector2i(-1, -1)
var _last_course := -1.0
var _pulse: Tween
var _forecast_key := ""
var _forecast_text := ""


func _ready() -> void:
	name = "SailingPanel"
	theme_type_variation = &"HudPanel"
	mouse_filter = Control.MOUSE_FILTER_IGNORE  # clicks pass through, except on its button
	custom_minimum_size = Vector2(400, 0)
	var box := VBoxContainer.new()
	box.add_theme_constant_override(&"separation", 3)
	add_child(box)
	var header := HBoxContainer.new()
	box.add_child(header)
	_title = Label.new()
	_title.name = "Title"
	_title.theme_type_variation = &"HeaderLabel"
	_title.text = "Sailing"
	_title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_child(_title)
	_toggle = Button.new()
	_toggle.name = "Collapse"
	_toggle.focus_mode = Control.FOCUS_NONE
	_toggle.tooltip_text = "Show fewer or more details"
	_toggle.pressed.connect(func() -> void:
		collapsed = not collapsed
		refresh())
	header.add_child(_toggle)
	for key in ["speed", "heading", "wind", "trim", "next_leg", "turn", "remaining"]:
		var row := HBoxContainer.new()
		row.name = key.capitalize().replace(" ", "")
		row.add_theme_constant_override(&"separation", 10)
		var caption := Label.new()
		caption.name = "Caption"
		caption.custom_minimum_size = Vector2(84, 0)
		caption.theme_type_variation = &"MutedLabel"
		caption.add_theme_font_size_override(&"font_size", 16)
		caption.text = {"speed": "Speed", "heading": "Heading", "wind": "Wind now", "trim": "Sail trim", "next_leg": "Next leg",
			"turn": "Next turn", "remaining": "To go"}[key]
		row.add_child(caption)
		var value := Label.new()
		value.name = "Value"
		value.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		value.custom_minimum_size = Vector2(280, 0)
		value.add_theme_font_size_override(&"font_size", 18)
		row.add_child(value)
		box.add_child(row)
		_rows[key] = row
	for node in find_children("*", "Container", true, false):
		(node as Control).mouse_filter = Control.MOUSE_FILTER_IGNORE
	visible = false


func _process(_delta: float) -> void:
	visible = should_show()
	if visible:
		refresh()


static func should_show() -> bool:
	return GameSession.is_active() and GameSession.is_underway()


func get_value(key: String) -> String:
	return ((_rows[key] as Control).get_node("Value") as Label).text if _rows.has(key) else ""


func _show_row(key: String, text: String, shown := true) -> void:
	var row := _rows[key] as Control
	row.visible = shown
	var label := row.get_node("Value") as Label
	if label.text != text:
		label.text = text


func refresh() -> void:
	if not GameSession.is_underway():
		return
	_toggle.text = "+" if collapsed else "–"
	var catalog := PortCatalog.get_default()
	var speed := GameSession.get_vessel_speed_kn()
	var wind := Simulation.get_wind_at(GameSession.get_vessel_position())
	var turn := WorldMap.get_next_turn()
	if GameSession.is_anchored():
		_title.text = "At anchor"
		_show_row("speed", "0 kn  ·  at anchor")
		_show_row("heading", "—", false)
		_show_row("wind", Hud.describe_wind(wind).trim_prefix("Wind "))
		_show_row("trim", "", false)
		_show_row("next_leg", "", false)
		_show_row("turn", "Raise the anchor to sail on", true)
		_show_row("remaining", "", false)
		return
	if GameSession.is_holding_at_anchorage():
		_title.text = "At the anchorage"
		_show_row("speed", "0 kn  ·  waiting at the anchorage")
		_show_row("heading", "—", false)
		_show_row("wind", Hud.describe_wind(wind).trim_prefix("Wind "))
		_show_row("trim", "", false)
		_show_row("next_leg", "", false)
		_show_row("turn", "Drop the anchor, or sail on (Q)", true)
		_show_row("remaining", "", false)
		return
	_title.text = "Sailing to %s" % catalog.get_display_name(GameSession.get_voyage_destination_id())
	_show_row("speed", "%.1f kn  ·  %s" % [speed, "under engine" if GameSession.is_motoring() else "under sail"])
	var heading := Simulation.get_current_heading()
	_show_row("heading", "%03d°  ·  on the planned course" % roundi(heading))
	_check_course_change(turn, heading)
	var propulsion := GameSession.get_propulsion()
	var side := PropulsionState.wind_side(propulsion.true_wind_angle)
	var wind_text := Hud.describe_wind(wind).trim_prefix("Wind ")
	if wind.speed_kn >= 0.5:
		wind_text += "  ·  %d° %s" % [roundi(absf(propulsion.true_wind_angle)), side if side else "off the bow"]
	_show_row("wind", wind_text)
	_show_row("trim", describe_trim(propulsion))
	if turn.is_empty() or float(turn.next_course) < 0.0:
		_show_row("next_leg", "", false)
		var destination := catalog.get_display_name(GameSession.get_voyage_destination_id())
		var arrive := "No more turns: %s ahead" % destination
		if not turn.is_empty():
			arrive += ", %.1f nm" % float(turn.nm)
		_show_row("turn", arrive)
	elif not GameSession.get_next_anchorage().is_empty() and float(GameSession.get_next_anchorage().nm) <= float(turn.nm) + 1e-6:
		# The next waypoint is tonight's anchorage.
		_show_row("next_leg", "", false)
		var nm := float(GameSession.get_next_anchorage().nm)
		_show_row("turn", "Anchorage in %s, %.1f nm" % [Simulation.format_duration(nm / speed * 3600.0), nm] if speed > 0.3 else "Anchorage %.1f nm ahead" % nm)
	else:
		_show_row("next_leg", _next_leg_text(turn, speed), not collapsed)
		var eta_turn := "in %s, %.1f nm" % [Simulation.format_duration(float(turn.nm) / speed * 3600.0), float(turn.nm)] \
			if speed > 0.3 else "%.1f nm ahead" % float(turn.nm)
		_show_row("turn", "%s  →  %03d°" % [eta_turn, roundi(turn.next_course)])
	var remaining := GameSession.get_voyage_remaining_nm()
	_show_row("remaining", "%d nm  ·  ETA %s (estimate)" % [roundi(remaining), _short_time(Simulation.get_eta())], false)


## "Thu 21 May, 07:25" (the year and zone are in the clock bar).
## The sail trim row (Iteration 18): how the sails are trimmed, the effect,
## and the key that opens the trim.
static func describe_trim(propulsion: PropulsionState) -> String:
	if propulsion.is_motoring():
		return "under engine  ·  T to trim"
	var trim := GameSession.get_sail_trim()
	var word := SailTrim.feedback(trim.auto, trim.value, propulsion.true_wind_angle, propulsion.wind_speed_kn)
	if trim.auto:
		return "%s  ·  T to trim by hand" % word.to_lower()
	return "%s  ·  %+d %%  ·  T" % [word.to_lower(), SailTrim.percent(trim.auto, trim.value, propulsion.true_wind_angle, propulsion.wind_speed_kn)]


static func _short_time(unix_time: float) -> String:
	var text := Simulation.format_game_time(unix_time, false)
	var parts := text.split(" ")
	return "%s %s %s, %s" % [parts[0], parts[1], parts[2], parts[parts.size() - 1]] if parts.size() >= 5 else text


## "260°, forecast W 12 kn (estimate)": the course after the turn and the
## wind expected there when the boat arrives (refreshed per leg and half hour).
func _next_leg_text(turn: Dictionary, speed: float) -> String:
	var voyage := GameSession.get_voyage()
	var key := "%d|%s|%d" % [voyage.revision, turn.geo, floori(GameSession.get_game_time() / 1800.0)]
	if key != _forecast_key:
		_forecast_key = key
		var hours := float(turn.nm) / maxf(speed, 1.0)
		var now := GameSession.get_game_time()
		var at := Simulation.get_weather_at(turn.geo, now + hours * 3600.0, now)
		var wind := "calm" if at.speed_kn < 0.5 else "%s %d kn" % [WindField.compass_name(at.from_deg), roundi(at.speed_kn)]
		_forecast_text = "%03d°  ·  forecast %s (estimate)" % [roundi(turn.next_course), wind]
	return _forecast_text


## A new course from the autopilot (the next leg began, or a course change)
## by more than COURSE_CHANGE_DEG: a short highlight of the heading.
func _check_course_change(turn: Dictionary, heading: float) -> void:
	var voyage := GameSession.get_voyage()
	var key := Vector2i(voyage.revision, GeoMath.segment_index_at(voyage.get_cumulative(), voyage.progress_nm))
	if key == _course_key:
		return
	var first := _course_key.x < 0
	_course_key = key
	var changed := absf(angle_difference(deg_to_rad(_last_course), deg_to_rad(heading))) > deg_to_rad(COURSE_CHANGE_DEG)
	_last_course = heading
	if first or not changed:
		return
	pulse_heading()


## Tests: whether the heading highlight is running.
func is_pulsing() -> bool:
	return _pulse != null and _pulse.is_running()


func pulse_heading() -> void:
	var value := (_rows.heading as Control).get_node("Value") as Label
	if _pulse:
		_pulse.kill()
	_pulse = create_tween()
	var gentle := SettingsManager.get_reduce_flashing()
	var times := 1 if gentle else 2
	# The theme's highlight colour (rust by day, amber by night) and back to ink.
	var ink := UiTheme.color(&"ink")
	var accent := UiTheme.color(&"focus")
	var tint := func(c: Color) -> void: value.add_theme_color_override(&"font_color", c)
	for i in times:
		_pulse.tween_method(tint, ink, accent, 0.35 if not gentle else 0.8)
		_pulse.tween_method(tint, accent, ink, 0.45 if not gentle else 1.2)
	_pulse.tween_callback(value.remove_theme_color_override.bind(&"font_color"))
