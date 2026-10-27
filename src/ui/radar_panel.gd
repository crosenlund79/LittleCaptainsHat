class_name RadarPanel
extends PanelContainer
## The radar (I019, The Captain's Watch): a small north-up traffic display
## on deck. The boat at the centre, range rings, nearby vessels as small
## marks pointing where they are going, coloured by concern (nearby, caution,
## collision risk), and up to three lines on the vessels that matter most:
## what, where, how close it will pass and when, and what to do.
##
## Shown when the captain turns it on (action wheel), and by itself while a
## vessel is a caution or a collision risk underway. Light: the traffic is
## asked a few times a second (Simulation.traffic_risks), never every frame,
## and the scope is a handful of draw calls. Not a certified instrument.

const RANGES: Array[float] = [3.0, 6.0, 12.0]
const SCOPE_SIZE := 210.0
const REFRESH_SECONDS := 0.2
const SCOPE := Color("#12302C")
const RING := Color(0.75, 0.88, 0.8, 0.3)
const OWN := Color("#F2EEE3")
const NEARBY := Color("#BFD8CE")
const CAUTION := Color("#E9C46A")
const DANGER := Color("#E9654A")

## Turned on by the captain (kept for the game run, not saved).
static var shown := false
static var range_index := 1
## Whether the captain is on deck (set by the HUD).
var on_deck := Callable()

var _scope: Control
var _info: Label
var _risks: Array[Dictionary] = []
var _refresh := 0.0


func _ready() -> void:
	name = "RadarPanel"
	theme_type_variation = &"HudPanel"
	mouse_filter = Control.MOUSE_FILTER_STOP
	var box := VBoxContainer.new()
	box.add_theme_constant_override(&"separation", 4)
	add_child(box)
	var header := HBoxContainer.new()
	box.add_child(header)
	var title := Label.new()
	title.name = "Title"
	title.text = "Radar"
	title.theme_type_variation = &"HeaderLabel"
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_child(title)
	for spec in [["ZoomIn", "+", -1, "Closer"], ["ZoomOut", "–", 1, "Farther"]]:
		var button := Button.new()
		button.name = spec[0]
		button.text = spec[1]
		button.focus_mode = Control.FOCUS_NONE
		button.tooltip_text = spec[3]
		button.pressed.connect(change_range.bind(spec[2]))
		header.add_child(button)
	_scope = Control.new()
	_scope.name = "Scope"
	_scope.custom_minimum_size = Vector2(SCOPE_SIZE, SCOPE_SIZE)
	_scope.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_scope.draw.connect(_draw_scope)
	box.add_child(_scope)
	_info = Label.new()
	_info.name = "Info"
	_info.add_theme_font_size_override(&"font_size", 15)
	_info.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_info.custom_minimum_size = Vector2(SCOPE_SIZE + 60.0, 0)
	box.add_child(_info)
	visible = false


func get_range_nm() -> float:
	return RANGES[range_index]


func change_range(step: int) -> void:
	range_index = clampi(range_index + step, 0, RANGES.size() - 1)
	_refresh = 0.0


## The vessels the radar shows now (most urgent first), for tests.
func get_risks() -> Array[Dictionary]:
	return _risks


func get_info_text() -> String:
	return _info.text


## The highest concern among the vessels shown.
func get_concern() -> int:
	return _risks[0].risk if not _risks.is_empty() else Simulation.RISK_NONE


func should_show() -> bool:
	if not GameSession.is_active() or (on_deck.is_valid() and not on_deck.call()):
		return false
	return shown or (GameSession.is_underway() and get_concern() >= Simulation.RISK_CAUTION)


func _process(delta: float) -> void:
	_refresh -= delta
	if _refresh <= 0.0:
		_refresh = REFRESH_SECONDS
		var looking := GameSession.is_active() and (shown or GameSession.is_underway())
		_risks = Simulation.traffic_risks(get_range_nm()) if looking else ([] as Array[Dictionary])
		_info.text = describe(_risks)
		_scope.queue_redraw()
	visible = should_show()


## Up to three lines on the vessels that matter most, and what to do.
static func describe(risks: Array[Dictionary]) -> String:
	if risks.is_empty():
		return Loc.t("No vessels in range. A clear sea.")
	var lines := PackedStringArray()
	for info in risks.slice(0, 3):
		var where := Loc.t("%s %s nm %s") % [TrafficModel.kind_name(info.kind), Loc.decimal(float(info.distance_nm)),
			WindField.compass_name(float(info.bearing))]
		if float(info.tcpa_h) > 0.0 and float(info.tcpa_h) < 2.0:
			where += Loc.t(", passes %s nm off in %d min") % [Loc.decimal(float(info.cpa_nm)), maxi(roundi(float(info.tcpa_h) * 60.0), 1)]
		lines.append(where)
	match int(risks[0].risk):
		Simulation.RISK_DANGER:
			lines.append(Loc.t("Collision risk: keep a sharp lookout and give way if needed."))
		Simulation.RISK_CAUTION:
			lines.append(Loc.t("Keep an eye on it: it will pass close."))
	return "\n".join(lines)


static func colour_for(risk: int) -> Color:
	match risk:
		Simulation.RISK_DANGER:
			return DANGER
		Simulation.RISK_CAUTION:
			return CAUTION
	return NEARBY


func _draw_scope() -> void:
	var half := SCOPE_SIZE / 2.0
	var centre := Vector2(half, half)
	_scope.draw_circle(centre, half, SCOPE)
	for f in [0.5, 1.0]:
		_scope.draw_arc(centre, half * f - 1.0, 0.0, TAU, 48, RING, 1.0, true)
	_scope.draw_string(ThemeDB.fallback_font, Vector2(half - 4.0, 14.0), Loc.t("N", "compass"), HORIZONTAL_ALIGNMENT_LEFT, -1, 13, RING * 2.0)
	_scope.draw_string(ThemeDB.fallback_font, Vector2(half + 4.0, half - half * 0.5 + 12.0), Loc.t("%s nm") % Loc.decimal(get_range_nm() / 2.0, 1 if get_range_nm() < 4.0 else 0),
		HORIZONTAL_ALIGNMENT_LEFT, -1, 11, RING * 2.0)
	# Our boat, along its heading when underway.
	var heading := deg_to_rad(Simulation.get_current_heading()) if GameSession.is_underway() else 0.0
	_draw_mark(centre, heading, OWN, 8.0)
	for info in _risks:
		var offset: Vector2 = info.offset_nm
		var at := centre + Vector2(offset.x, -offset.y) / get_range_nm() * half
		if at.distance_to(centre) > half:
			continue
		_draw_mark(at, deg_to_rad(float(info.course)), colour_for(int(info.risk)), 6.0)
		if int(info.risk) >= Simulation.RISK_CAUTION:
			_scope.draw_arc(at, 9.0, 0.0, TAU, 20, colour_for(int(info.risk)), 1.5, true)


func _draw_mark(at: Vector2, angle: float, colour: Color, size: float) -> void:
	var forward := Vector2(sin(angle), -cos(angle))
	var side := Vector2(-forward.y, forward.x)
	_scope.draw_colored_polygon(PackedVector2Array([at + forward * size, at - forward * size * 0.6 + side * size * 0.55,
		at - forward * size * 0.6 - side * size * 0.55]), colour)
