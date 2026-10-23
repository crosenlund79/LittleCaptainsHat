class_name SleepMenu
extends ModalPanel
## Choose how long to sleep. Sleeping itself is done by the Simulation; this
## dialog only reports the chosen duration.

signal sleep_requested(hours: float)

const DURATIONS := [4, 6, 8]

@onready var _info: Label = %Info
@onready var _buttons: VBoxContainer = %Durations


func _ready() -> void:
	if GameSession.is_underway():
		_info.text = "The boat sails on while you sleep. You will be woken on arrival or when a weather warning comes in."
	else:
		_info.text = "The boat is moored. Time passes while you sleep."
	for hours in DURATIONS:
		var button := Button.new()
		button.name = "Sleep%d" % hours
		button.theme_type_variation = &"BigButton"
		button.text = "Sleep %d hours" % hours
		button.pressed.connect(func() -> void: sleep_requested.emit(float(hours)))
		_buttons.add_child(button)
	%CancelButton.pressed.connect(close)


func focus_default() -> void:
	(_buttons.get_child(0) as Button).grab_focus()
