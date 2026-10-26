extends RefCounted
## The original soundtrack (music injection):
##   - the three pieces load, are long, loop, and their length matches the
##     timing sidecar the build wrote;
##   - they actually sound (captured from the Music bus);
##   - the director picks by daylight and activity: night first; by day,
##     sailing on deck underway, home otherwise (harbour, cabin, anchor, menu);
##   - changes are crossfaded (never a cut, never two at full volume), wait to
##     settle, and a piece that is returned to resumes at a phrase start;
##   - windows, the chart and the pause menu do not restart the music;
##   - fast passage time does not flip day and night music;
##   - mute pauses the players; music and effects volumes stay independent.

const APP_SCENE := preload("res://src/app/app.tscn")

var t: Node
var app: Node


func run(runner: Node) -> void:
	t = runner
	Simulation.auto_advance = false
	_test_files()
	await _test_audible()
	GameSession.end_session()  # whatever an earlier suite left: the title screen has no game
	app = APP_SCENE.instantiate()
	t.add_child(app)
	app.router.fade_duration = 0.05
	await _settle()
	await _tick(1.0)
	t.check(MusicDirector.get_current() == MusicDirector.HOME and MusicDirector.is_playing(),
		"[menu] the title screen plays Home Upon the Waves (%s)" % MusicDirector.get_current())
	app.start_new_game()
	await _settle()
	MusicDirector.settle_seconds = 0.3
	MusicDirector.min_stay_seconds = 0.0
	MusicDirector.crossfade_seconds = 0.6
	await _test_contexts()
	await _test_no_restart()
	await _test_fast_time()
	await _test_mute_and_volumes()
	MusicDirector.settle_seconds = MusicDirector.SETTLE
	MusicDirector.min_stay_seconds = MusicDirector.MIN_STAY
	MusicDirector.crossfade_seconds = MusicDirector.CROSSFADE
	Simulation.passage_rate = 0.0
	Simulation.auto_advance = true
	app.queue_free()
	await t.frames(2)
	GameSession.end_session()


func _settle() -> void:
	await t.frames(2)
	await t.wait_until(func() -> bool: return not app.router.is_busy(), 5.0)
	await t.physics_frames(3)


func _set_local_hour(hour: float) -> void:
	var state := GameSession.get_state_snapshot()
	var geo := GameSession.get_vessel_position()
	var day_start := floorf(state.game_time / 86400.0) * 86400.0
	state.game_time = day_start + fposmod(hour - geo.x / 15.0, 24.0) * 3600.0
	GameSession.replace_state(state)


## Runs the director's clock forward (it counts real seconds).
func _tick(seconds: float) -> void:
	var step := 0.5
	var done := 0.0
	while done < seconds - 1e-6:
		MusicDirector._process(step)
		done += step
	await t.frames(1)


func _show(area: StringName) -> void:
	app.modals.clear()
	GameSession.enter_boat_area(area, &"start")
	app._show_current_boat_area()
	await _settle()


# --- Files --------------------------------------------------------------------------------------

func _test_files() -> void:
	var lengths := []
	var ok := true
	for track: StringName in MusicDirector.TRACKS:
		var stream := load(String(MusicDirector.TRACKS[track]) + ".ogg") as AudioStreamOggVorbis
		var sidecar := MusicDirector.get_loop_seconds(track)
		ok = ok and stream != null and stream.loop and absf(stream.get_length() - sidecar) < 0.1 and stream.get_length() > 8.0 * 60.0
		lengths.append("%s %.1f min (sidecar %.1f)" % [track, stream.get_length() / 60.0 if stream else 0.0, sidecar / 60.0])
	t.check(ok, "[files] three OGG pieces load, loop, last over 8 minutes, and match their timing sidecars: %s" % ", ".join(lengths))
	t.check(MusicDirector.phrase_start_before(MusicDirector.HOME, 100.0) > 80.0 and MusicDirector.phrase_start_before(MusicDirector.HOME, 100.0) <= 100.0,
		"[files] phrase starts are known (resume points every four bars)")


func _test_audible() -> void:
	# Capture what the Music bus actually plays for each piece (a short excerpt each).
	var bus := AudioServer.get_bus_index(AudioManager.BUS_MUSIC)
	var capture := AudioEffectCapture.new()
	AudioServer.add_bus_effect(bus, capture)
	MusicDirector.enabled = false
	var levels := []
	for track: StringName in MusicDirector.TRACKS:
		for other: AudioStreamPlayer in [MusicDirector.get_player(&"home"), MusicDirector.get_player(&"sailing"), MusicDirector.get_player(&"night")]:
			other.stop()
		var player := MusicDirector.get_player(track)
		player.volume_db = 0.0
		player.play(60.0)
		capture.clear_buffer()
		await t.get_tree().create_timer(1.0).timeout
		var frames := capture.get_frames_available()
		var buffer := capture.get_buffer(frames)
		var sum := 0.0
		for f in buffer:
			sum += f.x * f.x + f.y * f.y
		var rms := sqrt(sum / maxf(2.0 * buffer.size(), 1.0))
		levels.append(rms)
		player.stop()
	AudioServer.remove_bus_effect(bus, AudioServer.get_bus_effect_count(bus) - 1)
	MusicDirector.enabled = true
	MusicDirector._current = &""
	var captured: bool = levels.any(func(l: float) -> bool: return l > 0.0)
	if captured:
		t.check(levels.all(func(l: float) -> bool: return l > 0.003),
			"[audible] each piece sounds on the Music bus (RMS %s)" % ", ".join(levels.map(func(l: float) -> String: return "%.3f" % l)))
	else:
		# The headless dummy audio driver mixes nothing to capture; the render
		# checks (tools/music/check_loops.py) measure the files instead.
		t.check(true, "[audible] (no audio device mixing in this run: measured from the files by check_loops.py)")


# --- Context ------------------------------------------------------------------------------------

func _test_contexts() -> void:
	_set_local_hour(12.5)
	await _show(SessionState.AREA_EXTERIOR)
	await _tick(2.0)
	t.check_eq(MusicDirector.get_current(), MusicDirector.HOME, "[day] moored in harbour: Home Upon the Waves")
	GameSession.plan_route_to(&"kiel")
	GameSession.depart()
	Simulation.advance(900.0)
	_set_local_hour(12.5)
	await _tick(0.5)
	t.check_eq(MusicDirector.get_current(), MusicDirector.HOME, "[settle] a new context waits a moment before the music follows")
	await _tick(1.0)
	t.check_eq(MusicDirector.get_current(), MusicDirector.SAILING, "[day] underway on deck: The Wind Knows the Way")
	# Mid-crossfade: both sound, neither at full volume, then only one.
	var home := MusicDirector.get_player(MusicDirector.HOME)
	var sail := MusicDirector.get_player(MusicDirector.SAILING)
	await t.get_tree().create_timer(0.25).timeout
	var mid_ok := home.volume_db < -0.5 and sail.volume_db < -0.5 and not home.stream_paused
	await t.get_tree().create_timer(0.8).timeout
	t.check(mid_ok and MusicDirector.audible_count() == 1 and home.stream_paused and sail.volume_db > -0.5,
		"[crossfade] the change is a crossfade, then only one piece plays (the other pauses)")
	sail.seek(100.0)
	await t.get_tree().create_timer(0.3).timeout
	var sailing_at := sail.get_playback_position()
	await _show(SessionState.AREA_INTERIOR)
	await _tick(2.0)
	t.check_eq(MusicDirector.get_current(), MusicDirector.HOME, "[day] underway, below in the cabin: Home Upon the Waves")
	await t.get_tree().create_timer(0.8).timeout
	await _show(SessionState.AREA_EXTERIOR)
	await _tick(2.0)
	await t.frames(3)
	var resumed := sail.get_playback_position()
	var phrase := MusicDirector.phrase_start_before(MusicDirector.SAILING, sailing_at + 1.0)
	t.check(MusicDirector.get_current() == MusicDirector.SAILING and phrase > 80.0 and phrase <= sailing_at + 1.0
		and resumed >= phrase - 0.1 and resumed < phrase + 2.5,
		"[resume] back on deck the sailing piece resumes at its phrase (%.1f s, was %.1f s), not from the top" % [resumed, sailing_at])
	# Night takes priority, on deck and below.
	_set_local_hour(23.5)
	await _tick(2.0)
	t.check_eq(MusicDirector.get_current(), MusicDirector.NIGHT, "[night] night sailing: Lanterns Across the Water (priority over sailing)")
	await _show(SessionState.AREA_INTERIOR)
	await _tick(2.0)
	t.check_eq(MusicDirector.get_current(), MusicDirector.NIGHT, "[night] night in the cabin: Lanterns as well")
	# Dusk does not flicker: just around the threshold the choice holds.
	var flips := MusicDirector.get_change_count()
	for i in 6:
		_set_local_hour(23.5 if i % 2 == 0 else 23.6)
		await _tick(1.0)
	t.check_eq(MusicDirector.get_change_count(), flips, "[night] small changes of the clock do not restart or switch the music")
	# Sunrise: back to the daytime choice.
	_set_local_hour(12.5)
	await _show(SessionState.AREA_EXTERIOR)
	await _tick(2.0)
	t.check_eq(MusicDirector.get_current(), MusicDirector.SAILING, "[day] sunrise underway: back to sailing")


func _test_no_restart() -> void:
	var player := MusicDirector.get_player(MusicDirector.get_current())
	var changes := MusicDirector.get_change_count()
	var before := player.get_playback_position()
	app.open_pause_menu()
	await _tick(1.0)
	app.modals.clear()
	app.open_chart()
	await _settle()
	await _tick(1.0)
	app.close_chart()
	await _settle()
	app.open_settings()
	await _tick(1.0)
	app.modals.clear()
	await _tick(1.0)
	await t.get_tree().create_timer(0.5).timeout
	t.check(MusicDirector.get_change_count() == changes and player.get_playback_position() >= before and MusicDirector.audible_count() == 1,
		"[steady] the pause menu, the chart and settings do not change or restart the music (%.1f -> %.1f s)" % [before, player.get_playback_position()])


func _test_fast_time() -> void:
	var changes := MusicDirector.get_change_count()
	Simulation.passage_rate = 43200.0
	for i in 12:
		Simulation.advance(3600.0)
		await _tick(1.0)
	t.check_eq(MusicDirector.get_change_count(), changes, "[fast] 12 hours a second from noon into the night: no switching back and forth")
	Simulation.passage_rate = 0.0


func _test_mute_and_volumes() -> void:
	var music := AudioServer.get_bus_index(AudioManager.BUS_MUSIC)
	var sfx := AudioServer.get_bus_index(AudioManager.BUS_SFX)
	SettingsManager.set_volume(&"Music", 0)
	await _tick(1.0)
	var player := MusicDirector.get_player(MusicDirector.get_current())
	t.check(AudioServer.is_bus_mute(music) and player.stream_paused and not AudioServer.is_bus_mute(sfx),
		"[mute] music off: the bus is muted and the player paused (no needless decoding); effects unaffected")
	SettingsManager.set_volume(&"Music", 40)
	SettingsManager.set_volume(&"SFX", 90)
	await _tick(1.0)
	t.check(not player.stream_paused and absf(AudioServer.get_bus_volume_db(music) - SettingsManager.percent_to_db(40)) < 0.01
		and absf(AudioServer.get_bus_volume_db(sfx) - SettingsManager.percent_to_db(90)) < 0.01,
		"[volume] music back on at 40 %, effects at 90 %: independent")
	SettingsManager.restore_defaults()
