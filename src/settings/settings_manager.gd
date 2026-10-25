extends Node
## Owns player preferences (audio volumes, display mode, VSync, UI scale,
## artwork style).
##
## Preferences are stored in user://settings.cfg via ConfigFile and are kept
## completely separate from game saves. Every setter applies its value to the
## engine immediately; nothing reaches disk until save() is called. This lets
## the settings menu preview changes and revert them with restore_snapshot().

signal settings_applied
signal ui_scale_changed(scale: float)
signal art_style_changed(style: StringName)

const DEFAULT_PATH := "user://settings.cfg"

const AUDIO_BUSES: Array[StringName] = [&"Master", &"Music", &"Ambience", &"SFX", &"UI"]
const DEFAULT_VOLUMES := {&"Master": 80, &"Music": 70, &"Ambience": 70, &"SFX": 80, &"UI": 70}

const WINDOW_WINDOWED := &"windowed"
const WINDOW_FULLSCREEN := &"fullscreen"
const WINDOW_BORDERLESS := &"borderless"
const WINDOW_MODES: Array[StringName] = [WINDOW_WINDOWED, WINDOW_FULLSCREEN, WINDOW_BORDERLESS]
const DEFAULT_WINDOW_MODE := WINDOW_WINDOWED
const DEFAULT_VSYNC := true

const UI_SCALE_MIN := 0.8
const UI_SCALE_MAX := 1.3
const UI_SCALE_STEP := 0.05
const DEFAULT_UI_SCALE := 1.0

## Artwork (Visual Identity V01): the illustrated prototype (the Starling 33
## and the harbour) or the classic placeholder art, to compare them.
const ART_ILLUSTRATED := &"illustrated"
const ART_CLASSIC := &"classic"
const ART_STYLES: Array[StringName] = [ART_ILLUSTRATED, ART_CLASSIC]
const DEFAULT_ART_STYLE := ART_ILLUSTRATED

## Window size used when (re)entering windowed mode. Clamped to the screen.
const WINDOWED_SIZE := Vector2i(1600, 900)

## Path is a variable so tests can point it at a scratch file.
var settings_path := DEFAULT_PATH

var _volumes: Dictionary = DEFAULT_VOLUMES.duplicate()
var _window_mode: StringName = DEFAULT_WINDOW_MODE
var _vsync := DEFAULT_VSYNC
var _ui_scale := DEFAULT_UI_SCALE
var _art_style: StringName = DEFAULT_ART_STYLE


func _ready() -> void:
	load_settings()


# --- Audio -----------------------------------------------------------------

func get_volume(bus: StringName) -> int:
	return _volumes.get(bus, 0)


## Sets a bus volume as a 0-100 percentage and applies it immediately.
func set_volume(bus: StringName, percent: int) -> void:
	if not DEFAULT_VOLUMES.has(bus):
		push_warning("Unknown audio bus setting: %s" % bus)
		return
	_volumes[bus] = clampi(percent, 0, 100)
	_apply_bus_volume(bus)
	settings_applied.emit()


## Converts a 0-100 slider percentage to decibels. Zero is handled as mute by
## the caller because linear_to_db(0) is -inf.
static func percent_to_db(percent: int) -> float:
	return linear_to_db(clampi(percent, 0, 100) / 100.0)


# --- Display ---------------------------------------------------------------

func get_window_mode() -> StringName:
	return _window_mode


func set_window_mode(mode: StringName) -> void:
	if mode not in WINDOW_MODES:
		push_warning("Unknown window mode: %s" % mode)
		return
	_window_mode = mode
	_apply_window_mode()
	settings_applied.emit()


func get_vsync() -> bool:
	return _vsync


func set_vsync(enabled: bool) -> void:
	_vsync = enabled
	_apply_vsync()
	settings_applied.emit()


func get_ui_scale() -> float:
	return _ui_scale


func set_ui_scale(value: float) -> void:
	_ui_scale = _sanitize_ui_scale(value)
	ui_scale_changed.emit(_ui_scale)
	settings_applied.emit()


func get_art_style() -> StringName:
	return _art_style


func set_art_style(style: StringName) -> void:
	if style not in ART_STYLES:
		push_warning("Unknown art style: %s" % style)
		return
	if style == _art_style:
		return
	_art_style = style
	art_style_changed.emit(style)
	settings_applied.emit()


# --- Snapshots, defaults and persistence ------------------------------------

## Returns a plain copy of the current values (used by the menu for Cancel).
func snapshot() -> Dictionary:
	return {
		"volumes": _volumes.duplicate(),
		"window_mode": _window_mode,
		"vsync": _vsync,
		"ui_scale": _ui_scale,
		"art_style": _art_style,
	}


func restore_snapshot(data: Dictionary) -> void:
	_volumes = (data.get("volumes", DEFAULT_VOLUMES) as Dictionary).duplicate()
	_window_mode = data.get("window_mode", DEFAULT_WINDOW_MODE)
	_vsync = data.get("vsync", DEFAULT_VSYNC)
	_ui_scale = data.get("ui_scale", DEFAULT_UI_SCALE)
	var style: StringName = data.get("art_style", DEFAULT_ART_STYLE)
	var style_changed := style != _art_style
	_art_style = style
	apply_all()
	if style_changed:
		art_style_changed.emit(_art_style)


## Resets every preference to its default and applies it (not saved yet).
func restore_defaults() -> void:
	restore_snapshot({})


func save() -> Error:
	var config := ConfigFile.new()
	for bus: StringName in AUDIO_BUSES:
		config.set_value("audio", String(bus).to_lower(), _volumes[bus])
	config.set_value("display", "window_mode", String(_window_mode))
	config.set_value("display", "vsync", _vsync)
	config.set_value("interface", "ui_scale", _ui_scale)
	config.set_value("display", "art_style", String(_art_style))
	var err := config.save(settings_path)
	if err != OK:
		push_error("Could not save settings to %s (error %d)" % [settings_path, err])
	return err


## Loads preferences from disk, replacing missing or invalid values with
## defaults, then applies everything. A missing file simply yields defaults.
func load_settings() -> void:
	var config := ConfigFile.new()
	var err := config.load(settings_path)
	if err != OK and err != ERR_FILE_NOT_FOUND:
		push_warning("Settings file unreadable (error %d); using defaults." % err)
	var loaded := {}
	var volumes := {}
	for bus: StringName in AUDIO_BUSES:
		var value: Variant = config.get_value("audio", String(bus).to_lower(), DEFAULT_VOLUMES[bus])
		volumes[bus] = clampi(int(value), 0, 100) if _is_number(value) else DEFAULT_VOLUMES[bus]
	loaded["volumes"] = volumes
	var mode := StringName(str(config.get_value("display", "window_mode", DEFAULT_WINDOW_MODE)))
	loaded["window_mode"] = mode if mode in WINDOW_MODES else DEFAULT_WINDOW_MODE
	var vsync: Variant = config.get_value("display", "vsync", DEFAULT_VSYNC)
	loaded["vsync"] = vsync if vsync is bool else DEFAULT_VSYNC
	var scale: Variant = config.get_value("interface", "ui_scale", DEFAULT_UI_SCALE)
	loaded["ui_scale"] = _sanitize_ui_scale(float(scale)) if _is_number(scale) else DEFAULT_UI_SCALE
	var style := StringName(str(config.get_value("display", "art_style", DEFAULT_ART_STYLE)))
	loaded["art_style"] = style if style in ART_STYLES else DEFAULT_ART_STYLE
	restore_snapshot(loaded)


func apply_all() -> void:
	for bus: StringName in AUDIO_BUSES:
		_apply_bus_volume(bus)
	_apply_window_mode()
	_apply_vsync()
	ui_scale_changed.emit(_ui_scale)
	settings_applied.emit()


# --- Engine application -----------------------------------------------------

func _apply_bus_volume(bus: StringName) -> void:
	var index := AudioServer.get_bus_index(bus)
	if index < 0:
		push_warning("Audio bus missing from layout: %s" % bus)
		return
	var percent: int = _volumes[bus]
	AudioServer.set_bus_mute(index, percent == 0)
	if percent > 0:
		AudioServer.set_bus_volume_db(index, percent_to_db(percent))


func _apply_window_mode() -> void:
	if not _can_control_window():
		return
	match _window_mode:
		WINDOW_FULLSCREEN:
			DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_EXCLUSIVE_FULLSCREEN)
		WINDOW_BORDERLESS:
			# Godot's non-exclusive fullscreen is a borderless, screen-sized window.
			DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN)
		_:
			var was_windowed := DisplayServer.window_get_mode() == DisplayServer.WINDOW_MODE_WINDOWED
			DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)
			if not was_windowed:
				_restore_windowed_size()


func _restore_windowed_size() -> void:
	var screen := DisplayServer.window_get_current_screen()
	var usable := DisplayServer.screen_get_usable_rect(screen)
	var size := Vector2i(
		mini(WINDOWED_SIZE.x, int(usable.size.x * 0.9)),
		mini(WINDOWED_SIZE.y, int(usable.size.y * 0.9)))
	DisplayServer.window_set_size(size)
	DisplayServer.window_set_position(usable.position + (usable.size - size) / 2)


func _apply_vsync() -> void:
	if not _can_control_window():
		return
	DisplayServer.window_set_vsync_mode(
		DisplayServer.VSYNC_ENABLED if _vsync else DisplayServer.VSYNC_DISABLED)


func _can_control_window() -> bool:
	# Headless runs (tests, CI) have no window; the editor's embedded game view
	# does not allow the game to change its own window mode either.
	return DisplayServer.get_name() != "headless" and not Engine.is_embedded_in_editor()


func _sanitize_ui_scale(value: float) -> float:
	return clampf(snappedf(value, UI_SCALE_STEP), UI_SCALE_MIN, UI_SCALE_MAX)


static func _is_number(value: Variant) -> bool:
	return value is int or value is float
