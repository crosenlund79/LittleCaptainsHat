extends Node
## The soundtrack (music injection): chooses one of three pieces from the
## game's own daylight and activity, and moves between them gently.
##
## - Night (the sun at the boat below NIGHT_BELOW, by the game's clock):
##   "Lanterns Across the Water", whatever the captain is doing.
## - Day, underway on deck (sailing, Long Passage): "The Wind Knows the Way".
## - Day otherwise (harbour, cabin, at anchor, the title screen): "Home Upon
##   the Waves".
##
## Each piece has its own player on the Music bus. A piece that is left is
## faded out and paused, not stopped: coming back to it resumes at the start
## of the phrase where it was, instead of from the top. Changes are crossfaded
## over CROSSFADE seconds, only after the new context has held for SETTLE real
## seconds, and no sooner than MIN_STAY after the previous change. Day/night
## changes wait while fast passage time runs, so 12 h/s never flips the music
## back and forth. Menus, petting the cat or opening a window change nothing.
## With the music muted (volume 0) the players are paused, costing nothing.

const TRACKS := {
	&"home": "res://assets/audio/music/home_upon_the_waves",
	&"sailing": "res://assets/audio/music/the_wind_knows_the_way",
	&"night": "res://assets/audio/music/lanterns_across_the_water",
}
const HOME := &"home"
const SAILING := &"sailing"
const NIGHT := &"night"

## Sun elevation (degrees) below which it is night for the music, and above
## which it is day again (a margin, so dusk does not flicker).
const NIGHT_BELOW := -4.0
const DAY_ABOVE := -1.0
const CROSSFADE := 5.0
const SETTLE := 3.0
const MIN_STAY := 25.0
const CHECK_SECONDS := 0.5
const SILENT_DB := -50.0

## Emitted when a crossfade to another piece starts (tests, diagnostics).
signal track_changed(track: StringName)

var enabled := true
## Real-time pacing (tests may shorten it).
var settle_seconds := SETTLE
var min_stay_seconds := MIN_STAY
var crossfade_seconds := CROSSFADE

var _players := {}
var _phrases := {}
var _loop_seconds := {}
var _current: StringName = &""
var _candidate: StringName = &""
var _candidate_since := 0.0
var _since_change := INF
var _night := false
var _check := 0.0
var _clock := 0.0
var _tweens := {}
var _paused_for_mute := false
var _changes := 0


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	# "--no-music" (after "--" on the command line): silence, for comparisons.
	enabled = not OS.get_cmdline_user_args().has("--no-music")
	for track: StringName in TRACKS:
		var player := AudioStreamPlayer.new()
		player.name = "Music_" + String(track)
		player.bus = AudioManager.BUS_MUSIC
		player.volume_db = SILENT_DB
		var stream := load(String(TRACKS[track]) + ".ogg") as AudioStream
		if stream is AudioStreamOggVorbis:
			(stream as AudioStreamOggVorbis).loop = true
		player.stream = stream
		add_child(player)
		_players[track] = player
		_read_sidecar(track)


func _read_sidecar(track: StringName) -> void:
	var text := FileAccess.get_file_as_string(String(TRACKS[track]) + ".json")
	var data: Variant = JSON.parse_string(text) if not text.is_empty() else null
	var phrases := PackedFloat32Array([0.0])
	if data is Dictionary:
		for t: Variant in data.get("phrases", []):
			phrases.append(float(t))
		_loop_seconds[track] = float(data.get("loop_seconds", 0.0))
	phrases.sort()
	_phrases[track] = phrases


func _process(delta: float) -> void:
	_clock += delta
	_since_change += delta
	_check -= delta
	if _check > 0.0:
		return
	_check = CHECK_SECONDS
	if _muted():
		_pause_all_for_mute()
		return
	if _paused_for_mute:
		_paused_for_mute = false
		if _current != &"":
			(_players[_current] as AudioStreamPlayer).stream_paused = false
	if not enabled:
		return
	update(false)


## Works out the wanted piece and changes to it when it has settled. `now`
## skips the waiting (tests, and the very first piece).
func update(now: bool) -> void:
	var wanted := context_for_game()
	if wanted == _current:
		_candidate = &""
		return
	if _current == &"" or now:
		_change_to(wanted)
		return
	# Day/night must wait for normal time: fast passage time would flip it.
	if Simulation.passage_rate > 0.0 and (wanted == NIGHT or _current == NIGHT):
		_candidate = &""
		return
	if wanted != _candidate:
		_candidate = wanted
		_candidate_since = _clock
		return
	if _clock - _candidate_since >= settle_seconds and _since_change >= min_stay_seconds:
		_change_to(wanted)


## The piece the game wants right now.
func context_for_game() -> StringName:
	if not GameSession.is_active():
		return HOME
	var elevation := Daylight.sun_elevation(GameSession.get_vessel_position(), GameSession.get_game_time())
	if _night:
		_night = elevation < DAY_ABOVE
	else:
		_night = elevation < NIGHT_BELOW
	if _night:
		return NIGHT
	var sailing := GameSession.is_underway() and not GameSession.is_anchored() and not GameSession.is_holding_at_anchorage()
	if sailing and GameSession.get_boat_area() == SessionState.AREA_EXTERIOR:
		return SAILING
	return HOME


func _change_to(track: StringName) -> void:
	var previous := _current
	_current = track
	_candidate = &""
	_since_change = 0.0
	_changes += 1
	if previous != &"":
		_fade(previous, SILENT_DB, true)
	var player := _players[track] as AudioStreamPlayer
	if player.stream_paused:
		# Back to a piece that was paused: from the start of its phrase.
		var at := phrase_start_before(track, player.get_playback_position())
		player.stream_paused = false
		player.seek(at)
	elif not player.playing:
		player.play(0.0)
	player.stream_paused = false
	player.volume_db = SILENT_DB if previous != &"" else -18.0
	_fade(track, 0.0, false)
	track_changed.emit(track)


## The start of the musical phrase at or before `seconds` (a 4-bar boundary).
func phrase_start_before(track: StringName, seconds: float) -> float:
	var phrases: PackedFloat32Array = _phrases.get(track, PackedFloat32Array([0.0]))
	var best := 0.0
	for t in phrases:
		if t <= seconds + 0.01:
			best = t
	return best


func _fade(track: StringName, to_db: float, pause_after: bool) -> void:
	var old: Tween = _tweens.get(track)
	if old and old.is_valid():
		old.kill()
	var player := _players[track] as AudioStreamPlayer
	var tween := create_tween()
	tween.set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	# Fading out takes the whole crossfade; fading in eases in over the same time.
	tween.tween_property(player, "volume_db", to_db, crossfade_seconds) \
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT if pause_after else Tween.EASE_IN_OUT)
	if pause_after:
		tween.tween_callback(func() -> void: player.stream_paused = true)
	_tweens[track] = tween


func _muted() -> bool:
	var index := AudioServer.get_bus_index(AudioManager.BUS_MUSIC)
	return index < 0 or AudioServer.is_bus_mute(index)


func _pause_all_for_mute() -> void:
	if _paused_for_mute:
		return
	_paused_for_mute = true
	for player: AudioStreamPlayer in _players.values():
		player.stream_paused = true


# --- For tests and diagnostics --------------------------------------------------------------

func get_current() -> StringName:
	return _current


func get_player(track: StringName) -> AudioStreamPlayer:
	return _players.get(track)


func get_loop_seconds(track: StringName) -> float:
	return _loop_seconds.get(track, 0.0)


func get_change_count() -> int:
	return _changes


## How many pieces are audible (above -30 dB and not paused).
func audible_count() -> int:
	var count := 0
	for player: AudioStreamPlayer in _players.values():
		if player.playing and not player.stream_paused and player.volume_db > -30.0:
			count += 1
	return count


func is_playing() -> bool:
	return _current != &"" and (_players[_current] as AudioStreamPlayer).playing \
		and not (_players[_current] as AudioStreamPlayer).stream_paused
