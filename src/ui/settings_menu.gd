class_name SettingsMenu
extends ModalPanel
## Shared settings dialog, used from the main menu and the pause menu.
##
## Changes preview immediately (volumes, window mode, UI scale). "Apply"
## writes them to disk; leaving with unapplied changes asks before reverting
## to the last saved values.

const BUS_LABELS := {&"Master": "Master", &"Music": "Music", &"Ambience": "Ambience", &"SFX": "Sound Effects", &"UI": "UI Sounds"}
const WINDOW_MODE_LABELS := {
	SettingsManager.WINDOW_WINDOWED: "Windowed",
	SettingsManager.WINDOW_FULLSCREEN: "Fullscreen",
	SettingsManager.WINDOW_BORDERLESS: "Borderless fullscreen",
}
## Visual Identity V01: compare the illustrated prototype with the old art.
const ART_STYLE_LABELS := {
	SettingsManager.ART_ILLUSTRATED: "Illustrated (prototype)",
	SettingsManager.ART_CLASSIC: "Classic",
}

## Temporary test sounds used by the "Test" buttons to verify bus routing.
@export var music_test_stream: AudioStream
@export var ambience_test_stream: AudioStream
@export var sfx_test_stream: AudioStream
@export var ui_test_stream: AudioStream

var _saved: Dictionary
var _volume_sliders := {}
var _volume_labels := {}
var _art_style: OptionButton

@onready var _audio_grid: GridContainer = %AudioGrid
@onready var _window_mode: OptionButton = %WindowMode
@onready var _vsync: CheckButton = %VSync
@onready var _ui_scale: HSlider = %UiScale
@onready var _ui_scale_value: Label = %UiScaleValue
@onready var _status: Label = %Status
@onready var _back: Button = %BackButton


func _ready() -> void:
	_saved = SettingsManager.snapshot()
	_build_audio_rows()
	for mode: StringName in SettingsManager.WINDOW_MODES:
		_window_mode.add_item(WINDOW_MODE_LABELS[mode])
	_window_mode.item_selected.connect(_on_window_mode_selected)
	_vsync.toggled.connect(func(on: bool) -> void:
		SettingsManager.set_vsync(on)
		_refresh_status())
	_ui_scale.min_value = SettingsManager.UI_SCALE_MIN * 100.0
	_ui_scale.max_value = SettingsManager.UI_SCALE_MAX * 100.0
	_ui_scale.step = SettingsManager.UI_SCALE_STEP * 100.0
	_ui_scale.drag_ended.connect(func(_changed: bool) -> void: _apply_ui_scale())
	_ui_scale.value_changed.connect(_on_ui_scale_value_changed)
	_build_art_style_row()
	var logs := Button.new()
	logs.name = "LogsButton"
	logs.text = "Diagnostic logs…"
	logs.tooltip_text = "Opens the folder with the technical session logs (for bug reports): %s" % SessionLog.get_folder()
	logs.pressed.connect(func() -> void:
		if DisplayServer.get_name() != "headless":
			OS.shell_open(SessionLog.get_folder()))
	%DefaultsButton.add_sibling(logs)
	%DefaultsButton.pressed.connect(_on_defaults_pressed)
	%ApplyButton.pressed.connect(_on_apply_pressed)
	_back.pressed.connect(handle_back)
	_sync_controls()


func focus_default() -> void:
	(_volume_sliders[&"Master"] as Control).grab_focus()


func handle_back() -> void:
	if not _has_unapplied_changes():
		close()
		return
	var discard: bool = await stack.confirm("Discard changes?",
		"Some settings have not been applied. Leaving now restores the previous settings.",
		"Discard", "Keep editing")
	if discard:
		SettingsManager.restore_snapshot(_saved)
		close()


func _build_audio_rows() -> void:
	for bus: StringName in SettingsManager.AUDIO_BUSES:
		var name_label := Label.new()
		name_label.text = BUS_LABELS[bus]
		name_label.custom_minimum_size.x = 190
		var slider := HSlider.new()
		slider.min_value = 0
		slider.max_value = 100
		slider.step = 1
		slider.custom_minimum_size = Vector2(380, 32)
		slider.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		slider.value_changed.connect(_on_volume_changed.bind(bus))
		var value_label := Label.new()
		value_label.custom_minimum_size.x = 70
		value_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		var test := Button.new()
		test.text = "Test"
		test.tooltip_text = "Play a temporary test sound on the %s bus" % BUS_LABELS[bus]
		test.pressed.connect(_play_test_sound.bind(bus))
		for control: Control in [name_label, slider, value_label, test]:
			_audio_grid.add_child(control)
		_volume_sliders[bus] = slider
		_volume_labels[bus] = value_label


## "Artwork": the illustrated prototype (every boat and the harbours) or the
## classic placeholder art. Added below the interface scale.
func _build_art_style_row() -> void:
	var grid := _ui_scale.get_parent().get_parent() as GridContainer
	var label := Label.new()
	label.name = "ArtStyleLabel"
	label.text = "Artwork"
	grid.add_child(label)
	_art_style = OptionButton.new()
	_art_style.name = "ArtStyle"
	_art_style.tooltip_text = "The illustrated look is a prototype on every boat and in harbour; Classic shows the earlier art."
	for style: StringName in SettingsManager.ART_STYLES:
		_art_style.add_item(ART_STYLE_LABELS[style])
	_art_style.item_selected.connect(func(index: int) -> void:
		SettingsManager.set_art_style(SettingsManager.ART_STYLES[index])
		_refresh_status())
	grid.add_child(_art_style)


func _sync_controls() -> void:
	for bus: StringName in SettingsManager.AUDIO_BUSES:
		var percent := SettingsManager.get_volume(bus)
		(_volume_sliders[bus] as HSlider).set_value_no_signal(percent)
		_update_volume_label(bus, percent)
	_window_mode.select(SettingsManager.WINDOW_MODES.find(SettingsManager.get_window_mode()))
	_vsync.set_pressed_no_signal(SettingsManager.get_vsync())
	_ui_scale.set_value_no_signal(roundf(SettingsManager.get_ui_scale() * 100.0))
	_ui_scale_value.text = "%d%%" % roundi(_ui_scale.value)
	_art_style.select(SettingsManager.ART_STYLES.find(SettingsManager.get_art_style()))
	_refresh_status()


func _on_volume_changed(value: float, bus: StringName) -> void:
	SettingsManager.set_volume(bus, int(value))
	_update_volume_label(bus, int(value))
	_refresh_status()


func _update_volume_label(bus: StringName, percent: int) -> void:
	(_volume_labels[bus] as Label).text = "Muted" if percent == 0 else "%d%%" % percent


func _on_window_mode_selected(index: int) -> void:
	SettingsManager.set_window_mode(SettingsManager.WINDOW_MODES[index])
	_refresh_status()


## The scale is applied when the slider is released (or changed by keyboard),
## because rescaling the menu under the mouse while dragging is disorienting.
func _on_ui_scale_value_changed(value: float) -> void:
	_ui_scale_value.text = "%d%%" % roundi(value)
	if not Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT):
		_apply_ui_scale()


func _apply_ui_scale() -> void:
	SettingsManager.set_ui_scale(_ui_scale.value / 100.0)
	_refresh_status()


func _on_defaults_pressed() -> void:
	SettingsManager.restore_defaults()
	_sync_controls()


func _on_apply_pressed() -> void:
	if SettingsManager.save() == OK:
		_saved = SettingsManager.snapshot()
		_refresh_status()
		notify("Settings saved.")
	else:
		notify("Settings could not be saved.")


func _has_unapplied_changes() -> bool:
	return SettingsManager.snapshot() != _saved


func _refresh_status() -> void:
	_status.text = "Unapplied changes — press Apply to keep them." if _has_unapplied_changes() else ""


func _play_test_sound(bus: StringName) -> void:
	match bus:
		&"Music":
			AudioManager.play_music(music_test_stream, false)
		&"Ambience":
			AudioManager.play_one_shot(ambience_test_stream, AudioManager.BUS_AMBIENCE)
		&"SFX":
			AudioManager.play_sfx(sfx_test_stream)
		&"UI":
			AudioManager.play_ui(ui_test_stream)
		_:
			AudioManager.play_one_shot(sfx_test_stream, &"Master")
