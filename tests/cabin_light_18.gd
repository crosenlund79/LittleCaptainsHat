extends Node
## Iteration 18 (LIGHT-1): how the night cabin's light and shadow measure on
## all four boats - for comparing the lighting before and after a change on
## the same rendered frames. For each boat, moored at Copenhagen at local
## midnight in fair weather, it saves the cabin (HUD hidden) and prints:
## the mean brightness in the lamp pools (saloon table, galley, chart table),
## at the floor's four corners and their ratio, the 10th and 90th percentiles
## over the cabin's walkable area, and the captain's brightness.
##   xvfb-run godot --path . --rendering-driver opengl3 --resolution 1600x900 \
##     res://tests/cabin_light_18.tscn -- --out=DIR --label=before
const APP_SCENE := preload("res://src/app/app.tscn")
const BOATS: Array[StringName] = [&"arctic_wanderer_26", &"starling_33", &"petrel_36", &"halcyon_40"]
const POOLS := ["SaloonTable", "Table", "Galley", "GalleySide", "NavTable", "NavDesk"]
var app: Node


func _ready() -> void:
	SaveManager.save_dir = "user://test_saves"
	_run.call_deferred()


func _arg(name: String, fallback: String) -> String:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--%s=" % name):
			return a.get_slice("=", 1)
	return fallback


func _frames(n: int) -> void:
	for i in n:
		await get_tree().process_frame


func _run() -> void:
	var out := _arg("out", "user://cabin_light")
	var label := _arg("label", "now")
	DirAccess.make_dir_recursive_absolute(out)
	Simulation.auto_advance = false
	WindField.get_default().test_override = func(_geo: Vector2, _time: float) -> WindField.Sample:
		return WindField.Sample.make(200.0, 6.0)
	app = APP_SCENE.instantiate()
	add_child(app)
	await _frames(10)
	app.start_new_game()
	await _frames(10)
	for id in BOATS:
		var state := GameSession.get_state_snapshot()
		state.vessel_id = id
		# Local midnight at the boat.
		var geo := GameSession.get_vessel_position()
		state.game_time = 1777593600.0 + (24.0 - geo.x / 15.0) * 3600.0
		GameSession.replace_state(state)
		app.modals.clear()
		GameSession.enter_boat_area(SessionState.AREA_INTERIOR, &"start")
		app._show_current_boat_area()
		await _frames(20)
		var cabin := app.router.current_screen as BoatArea
		(cabin.get_node("Lighting") as BoatLighting).update_now()
		app.hud.visible = false
		app.toasts.clear()
		await _frames(6)
		var image := get_viewport().get_texture().get_image()
		app.hud.visible = true
		image.save_png("%s/cabin_%s_%s.png" % [out, label, id])
		var scale := Vector2(image.get_size()) / get_viewport().get_visible_rect().size
		var to_screen := cabin.get_global_transform_with_canvas()
		var pools: Array[float] = []
		for fixture in cabin.get_node("Layout/Collision").get_children():
			if String(fixture.name) in POOLS:
				pools.append(_mean(image, (to_screen * (fixture as Node2D).position) * scale, 26.0 * scale.x))
		var rect := Rect2(to_screen * cabin.walkable_bounds.position, cabin.walkable_bounds.size * to_screen.get_scale())
		rect = Rect2(rect.position * scale, rect.size * scale)
		var values: Array[float] = []
		var y := rect.position.y
		while y < rect.end.y:
			var x := rect.position.x
			while x < rect.end.x:
				if x >= 0 and y >= 0 and x < image.get_width() and y < image.get_height():
					values.append(_lum(image.get_pixel(int(x), int(y))))
				x += 4.0
			y += 4.0
		values.sort()
		var low := values[int(values.size() * 0.1)]
		var high := values[int(values.size() * 0.9)]
		var pool := 0.0
		for p in pools:
			pool += p / pools.size()
		# The floor's four corners, a little in from the walkable edge.
		var corners := 0.0
		var wb := cabin.walkable_bounds.grow(-28.0)
		for c in [wb.position, Vector2(wb.end.x, wb.position.y), wb.end, Vector2(wb.position.x, wb.end.y)]:
			corners += _mean(image, (to_screen * c) * scale, 14.0 * scale.x) / 4.0
		var player := cabin.get_node_or_null("Player") as Node2D
		var captain := _mean(image, (to_screen * player.position) * scale, 10.0 * scale.x) if player else -1.0
		print("CABIN %s %s pools %.3f floor-corners %.3f pool/corner %.2f | p10 %.3f p90 %.3f | captain %.3f" % [label, id, pool, corners, pool / maxf(corners, 0.001), low, high, captain])
	get_tree().quit()


func _lum(c: Color) -> float:
	return 0.2126 * c.r + 0.7152 * c.g + 0.0722 * c.b


func _mean(image: Image, at: Vector2, radius: float) -> float:
	var total := 0.0
	var n := 0
	for dy in range(-int(radius), int(radius) + 1, 2):
		for dx in range(-int(radius), int(radius) + 1, 2):
			var p := Vector2i(int(at.x) + dx, int(at.y) + dy)
			if Vector2(dx, dy).length() <= radius and p.x >= 0 and p.y >= 0 and p.x < image.get_width() and p.y < image.get_height():
				total += _lum(image.get_pixelv(p))
				n += 1
	return total / maxf(n, 1)
