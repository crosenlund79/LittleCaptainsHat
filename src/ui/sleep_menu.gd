class_name SleepMenu
extends ModalPanel
## Choose how long to sleep (1-12 hours, in one-hour steps with the arrow
## buttons or the Left/Right keys). Sleeping itself is done by the Simulation;
## this dialog only reports the chosen duration. It is the same dialog whether
## it was opened from the berth or from the chart.

signal sleep_requested(hours: float)

const MIN_HOURS := 1
const MAX_HOURS := 12
const DEFAULT_HOURS := 6

## Opens on the duration chosen last time (SettingsManager), or DEFAULT_HOURS.
var hours := DEFAULT_HOURS

@onready var _info: Label = %Info
@onready var _duration: Label = %DurationLabel
@onready var _wake: Label = %WakeLabel
@onready var _decrease: Button = %DecreaseButton
@onready var _increase: Button = %IncreaseButton
@onready var _sleep: Button = %SleepButton


func _ready() -> void:
	hours = clampi(SettingsManager.get_sleep_hours(), MIN_HOURS, MAX_HOURS)
	if GameSession.is_underway():
		_info.text = "The boat sails on while you sleep. You will be woken early on arrival or when a weather warning comes in."
	else:
		_info.text = "The boat is moored. Time passes while you sleep."
	if GameSession.is_paused():
		_info.text += Loc.t(" The game is paused: sleeping moves time on by the hours you choose, and it stays paused afterwards.")
	_decrease.pressed.connect(change_hours.bind(-1))
	_increase.pressed.connect(change_hours.bind(1))
	_sleep.pressed.connect(func() -> void:
		SettingsManager.set_sleep_hours(hours)  # remembered for next time (and after a restart)
		sleep_requested.emit(float(hours)))
	%CancelButton.pressed.connect(close)
	_update()


func _unhandled_key_input(event: InputEvent) -> void:
	if event.is_action_pressed(&"ui_left") or event.is_action_pressed(&"move_left"):
		change_hours(-1)
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed(&"ui_right") or event.is_action_pressed(&"move_right"):
		change_hours(1)
		get_viewport().set_input_as_handled()


## Changes the duration by `delta` hours, kept within MIN_HOURS..MAX_HOURS.
func change_hours(delta: int) -> void:
	hours = clampi(hours + delta, MIN_HOURS, MAX_HOURS)
	SettingsManager.set_sleep_hours(hours, false)
	_update()


func _update() -> void:
	_duration.text = Loc.n("%d hour", "%d hours", hours) % hours
	_decrease.disabled = hours <= MIN_HOURS
	_increase.disabled = hours >= MAX_HOURS
	_sleep.text = Loc.n("Sleep %d hour", "Sleep %d hours", hours) % hours
	_wake.text = Loc.t("Wake at about %s\nin the V-berth.") % Simulation.format_game_time(GameSession.get_game_time() + hours * 3600.0)


func focus_default() -> void:
	_sleep.grab_focus()
