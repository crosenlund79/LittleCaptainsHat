class_name LoadingScreen
extends CanvasLayer
## The game's own start (Cozy Polish): after Godot's boot splash (an image
## the engine shows while it starts; nothing of the game can draw then), this
## screen shows the logo over a calm sea horizon - a small boat, a lighthouse,
## always in the main menu's deep navy (I022: it no longer follows the
## time of day, so the start looks like the menu it fades into) - while the
## game loads what it needs, naming each real step as it runs.
## The heaviest step (the routing charts) runs on a worker thread, so the
## screen keeps moving. It fades into the main menu as soon as the loading
## is done; there is no artificial wait. Purely visual: clicks and keys reach
## the menu under it. Shown once per launch, and not without a display.

signal finished

const FADE_SECONDS := 0.45
const LOGO := preload("res://assets/branding/png/little_captains_hat_logo_480.png")
## The main menu's sky and sea (src/ui/main_menu.tscn, Gradient_sky) and its horizon.
const SKY_TOP := Color(0.043, 0.133, 0.18)
const SKY_LOW := Color(0.075, 0.2, 0.26)
const SEA_TOP := Color(0.09, 0.235, 0.29)
const SEA_LOW := Color(0.063, 0.176, 0.231)
const HORIZON := 0.62

## Shown already in this run of the game.
static var shown := false

var _steps: Array[Dictionary] = []
var _step := -1
var _task := -1
var _done := false
var _time := 0.0
var _status: Label
var _canvas: Control
var _night := false


## True when there is a screen to show it on and it has not been shown yet.
static func wanted() -> bool:
	return not shown and DisplayServer.get_name() != "headless"


func _ready() -> void:
	shown = true
	layer = 100
	process_mode = Node.PROCESS_MODE_ALWAYS
	_night = true  # the main menu's night look, whatever the hour
	_canvas = Control.new()
	_canvas.name = "Canvas"
	_canvas.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_canvas.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_canvas.draw.connect(_draw_scene)
	add_child(_canvas)
	var column := VBoxContainer.new()
	column.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	column.mouse_filter = Control.MOUSE_FILTER_IGNORE
	column.alignment = BoxContainer.ALIGNMENT_CENTER
	column.add_theme_constant_override(&"separation", 10)
	column.grow_horizontal = Control.GROW_DIRECTION_BOTH
	column.grow_vertical = Control.GROW_DIRECTION_BOTH
	column.position.y -= 80.0
	_canvas.add_child(column)
	var logo := TextureRect.new()
	logo.texture = LOGO
	logo.custom_minimum_size = Vector2(400, 188)
	logo.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	logo.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	logo.mouse_filter = Control.MOUSE_FILTER_IGNORE
	column.add_child(logo)
	var tagline := Label.new()
	tagline.text = "Small boat. Wide world. Hold onto your hat."
	tagline.theme_type_variation = &"DisplayTagline"
	tagline.add_theme_color_override(&"font_color", UiTheme.color_at(&"ink_soft", 1.0))
	tagline.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	column.add_child(tagline)
	_status = Label.new()
	_status.name = "Status"
	_status.theme_type_variation = &"MutedLabel"
	_status.add_theme_color_override(&"font_color", Color(UiTheme.color_at(&"ink_soft", 1.0), 0.8))
	_status.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_status.custom_minimum_size = Vector2(520, 0)
	column.add_child(_status)
	# The real work, in order. Each is what the game would otherwise do the
	# first time it needs it.
	_steps = [
		{"text": Loc.t("Reading the harbour list…"), "work": func() -> void: PortCatalog.get_default()},
		{"text": Loc.t("Unrolling the charts of the world…"), "thread": func() -> void: SeaRouter.get_default()},
		{"text": Loc.t("Making the cabin ready…"), "work": func() -> void: VesselCatalog.get_default()},
	]
	_next_step()


func _next_step() -> void:
	_step += 1
	if _step >= _steps.size():
		_finish()
		return
	var step: Dictionary = _steps[_step]
	_status.text = Loc.t("%s  (%d of %d)") % [step.text, _step + 1, _steps.size()]
	if step.has("thread"):
		_task = WorkerThreadPool.add_task(step.thread, false, Loc.t("Loading: %s") % step.text)
	else:
		# Quick steps run on the next frame, after the text is shown.
		(func() -> void:
			(step.work as Callable).call()
			_next_step()).call_deferred()


func _process(delta: float) -> void:
	_time += delta
	_canvas.queue_redraw()
	if _task >= 0 and WorkerThreadPool.is_task_completed(_task):
		WorkerThreadPool.wait_for_task_completion(_task)
		_task = -1
		_next_step()


func _finish() -> void:
	if _done:
		return
	_done = true
	_status.text = "Ready. Welcome aboard."
	var tween := create_tween()
	tween.tween_property(_canvas, "modulate:a", 0.0, FADE_SECONDS)
	tween.tween_callback(func() -> void:
		finished.emit()
		queue_free())


func is_done() -> bool:
	return _done


## The scene behind the logo: sky, a sea horizon with slow waves, a small
## boat bobbing and a lighthouse whose light turns (brighter by night).
func _draw_scene() -> void:
	var size := _canvas.size
	var ink := UiTheme.color_at(&"ink", 1.0)
	var horizon := size.y * HORIZON
	_canvas.draw_polygon(PackedVector2Array([Vector2.ZERO, Vector2(size.x, 0), Vector2(size.x, horizon), Vector2(0, horizon)]),
		PackedColorArray([SKY_TOP, SKY_TOP, SKY_LOW, SKY_LOW]))
	_canvas.draw_polygon(PackedVector2Array([Vector2(0, horizon), Vector2(size.x, horizon), size, Vector2(0, size.y)]),
		PackedColorArray([SEA_TOP, SEA_TOP, SEA_LOW, SEA_LOW]))
	_canvas.draw_rect(Rect2(0, horizon, size.x, 2.0), Color(0.651, 0.769, 0.788, 0.18))
	# Slow waves.
	for row in 6:
		var y := horizon + 18.0 + row * 34.0
		var phase := _time * (0.35 + row * 0.05) + row
		for k in 14:
			var x := fposmod(k * 160.0 + row * 57.0 + phase * 24.0, size.x + 160.0) - 80.0
			var pts := PackedVector2Array()
			for i in 6:
				var t := i / 5.0
				pts.append(Vector2(x + t * 46.0, y - sin(t * PI) * 4.0))
			_canvas.draw_polyline(pts, Color(1, 1, 1, 0.18 - row * 0.02), 2.0, true)
	# The lighthouse on a little headland, left.
	var base := Vector2(size.x * 0.16, horizon + 6.0)
	_canvas.draw_colored_polygon(PackedVector2Array([base + Vector2(-90, 0), base + Vector2(-30, -26), base + Vector2(40, -30),
		base + Vector2(110, 0)]), Color(ink, 0.55))
	var tower := PackedVector2Array([base + Vector2(-12, -28), base + Vector2(12, -28), base + Vector2(8, -110), base + Vector2(-8, -110)])
	_canvas.draw_colored_polygon(tower, Color("#EFE5CC"))
	for band in [-50.0, -80.0]:
		_canvas.draw_rect(Rect2(base + Vector2(-10.5 + (-band - 50.0) * 0.03, band - 8.0), Vector2(21.0 - (-band - 50.0) * 0.06, 10.0)), Color("#A4513A"))
	_canvas.draw_rect(Rect2(base + Vector2(-9, -126), Vector2(18, 16)), Color("#2A2420"))
	var lamp := base + Vector2(0, -118)
	var beam := Vector2.from_angle(_time * 0.9)
	var glow := 0.55 if _night else 0.25
	_canvas.draw_colored_polygon(PackedVector2Array([lamp, lamp + beam.rotated(-0.08) * 420.0, lamp + beam.rotated(0.08) * 420.0]),
		Color(1.0, 0.86, 0.5, glow * 0.35))
	_canvas.draw_circle(lamp, 6.0, Color(1.0, 0.86, 0.5, 0.9))
	# A small boat under sail, right, bobbing on the swell.
	var boat := Vector2(size.x * 0.78, horizon + 26.0 + sin(_time * 1.3) * 3.0)
	var tilt := sin(_time * 1.1) * 0.04
	var hull := PackedVector2Array([Vector2(-46, 0), Vector2(46, 0), Vector2(34, 14), Vector2(-36, 14)])
	var sail := PackedVector2Array([Vector2(-4, -6), Vector2(-4, -86), Vector2(38, -8)])
	var jib := PackedVector2Array([Vector2(-8, -6), Vector2(-8, -74), Vector2(-40, -8)])
	var place := func(points: PackedVector2Array) -> PackedVector2Array:
		var out := PackedVector2Array()
		for p in points:
			out.append(boat + p.rotated(tilt))
		return out
	_canvas.draw_colored_polygon(place.call(hull), Color("#7A4E26"))
	_canvas.draw_colored_polygon(place.call(sail), Color("#F6EBD5"))
	_canvas.draw_colored_polygon(place.call(jib), Color("#EFE5CC"))
	_canvas.draw_line(boat + Vector2(-6, 0).rotated(tilt), boat + Vector2(-6, -92).rotated(tilt), ink, 2.0, true)
	if _night:
		_canvas.draw_circle(boat + Vector2(-6, -94).rotated(tilt), 3.0, Color(1.0, 0.9, 0.6))
