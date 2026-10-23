class_name Hud
extends Control
## Gameplay overlay shared by both boat areas: current area and location,
## planned route, the interaction prompt and a menu button.

signal menu_requested

@onready var _area: Label = %AreaLabel
@onready var _location: Label = %LocationLabel
@onready var _route: Label = %RouteLabel
@onready var _prompt_panel: Control = %PromptPanel
@onready var _prompt: Label = %PromptLabel


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	%MenuButton.pressed.connect(menu_requested.emit)
	GameSession.route_changed.connect(func(_route_data: PlannedRoute) -> void: refresh())
	GameSession.state_replaced.connect(refresh)
	GameSession.session_started.connect(refresh)
	set_prompt("")


func set_area(area: StringName) -> void:
	_area.text = SessionState.get_area_display_name(area)


func set_prompt(text: String) -> void:
	_prompt.text = text
	_prompt_panel.visible = not text.is_empty()


func get_prompt() -> String:
	return _prompt.text if _prompt_panel.visible else ""


func refresh() -> void:
	if not GameSession.is_active():
		return
	var location := GameSession.get_location()
	_location.text = "Moored at %s" % (location.display_name if location else "?")
	_route.text = PlannedRoute.describe(GameSession.get_planned_route(), PortCatalog.get_default())
