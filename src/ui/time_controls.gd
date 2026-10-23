class_name TimeControls
extends HBoxContainer
## Compact 1× / 5× / 20× time-acceleration selector. Reads and writes
## GameSession's time scale; the buttons never take keyboard focus so they do
## not interfere with movement or interaction keys.

var _buttons := {}


func _ready() -> void:
	add_theme_constant_override("separation", 4)
	var group := ButtonGroup.new()
	for scale in SessionState.TIME_SCALES:
		var button := Button.new()
		button.name = "Speed%d" % scale
		button.text = "%d×" % scale
		button.toggle_mode = true
		button.button_group = group
		button.focus_mode = Control.FOCUS_NONE
		button.custom_minimum_size = Vector2(52, 0)
		button.tooltip_text = ["Normal time", "Accelerated time", "Fast time"][SessionState.TIME_SCALES.find(scale)]
		button.pressed.connect(GameSession.set_time_scale.bind(scale))
		add_child(button)
		_buttons[scale] = button
	GameSession.time_scale_changed.connect(_sync)
	GameSession.state_replaced.connect(func() -> void: _sync(GameSession.get_time_scale()))
	_sync(GameSession.get_time_scale())


func _sync(scale: int) -> void:
	if _buttons.has(scale):
		(_buttons[scale] as Button).set_pressed_no_signal(true)
