extends Node
## Plays music, ambience, one-shot sound effects and UI feedback sounds on the
## correct audio buses. It owns no gameplay state and never decides *what* to
## play; scenes and menus ask it to play streams they provide.
##
## Players are created once and reused: one music player, one ambience player
## and a small round-robin pool for one-shots, so nothing is allocated per sound.

const BUS_MUSIC := &"Music"
const BUS_AMBIENCE := &"Ambience"
const BUS_SFX := &"SFX"
const BUS_UI := &"UI"

const ONE_SHOT_POOL_SIZE := 8

var _music: AudioStreamPlayer
var _ambience: AudioStreamPlayer
var _music_loops := false
var _ambience_loops := false
var _music_tween: Tween
var _one_shots: Array[AudioStreamPlayer] = []
var _next_one_shot := 0


func _ready() -> void:
	# Menus and pause screens must keep their sound while the tree is paused.
	process_mode = Node.PROCESS_MODE_ALWAYS
	_music = _create_player("Music", BUS_MUSIC)
	_music.finished.connect(_on_music_finished)
	_ambience = _create_player("Ambience", BUS_AMBIENCE)
	_ambience.finished.connect(_on_ambience_finished)
	for i in ONE_SHOT_POOL_SIZE:
		_one_shots.append(_create_player("OneShot%d" % i, BUS_SFX))


## Stops every sound immediately (used before quitting).
func stop_all() -> void:
	_kill_music_tween()
	_music_loops = false
	_ambience_loops = false
	for child in get_children():
		(child as AudioStreamPlayer).stop()


# --- Music -------------------------------------------------------------------

func play_music(stream: AudioStream, loop := true, fade_in := 0.0) -> void:
	if stream == null:
		return
	_kill_music_tween()
	_music_loops = loop
	_music.stream = stream
	_music.volume_db = -40.0 if fade_in > 0.0 else 0.0
	_music.play()
	if fade_in > 0.0:
		_music_tween = create_tween()
		_music_tween.tween_property(_music, "volume_db", 0.0, fade_in)


func stop_music(fade_out := 0.0) -> void:
	_kill_music_tween()
	_music_loops = false
	if fade_out <= 0.0 or not _music.playing:
		_music.stop()
		return
	_music_tween = create_tween()
	_music_tween.tween_property(_music, "volume_db", -40.0, fade_out)
	_music_tween.tween_callback(_music.stop)


func is_music_playing() -> bool:
	return _music.playing


# --- Ambience ----------------------------------------------------------------

## Starts a looping ambience bed, replacing any current one. Requesting the
## stream that is already playing is a no-op so area changes do not restart it.
func play_ambience(stream: AudioStream, loop := true) -> void:
	if stream == null:
		stop_ambience()
		return
	if _ambience.playing and _ambience.stream == stream:
		_ambience_loops = loop
		return
	_ambience_loops = loop
	_ambience.stream = stream
	_ambience.play()


func stop_ambience() -> void:
	_ambience_loops = false
	_ambience.stop()


func get_ambience_stream() -> AudioStream:
	return _ambience.stream if _ambience.playing else null


# --- One-shots ---------------------------------------------------------------

func play_sfx(stream: AudioStream, volume_db := 0.0) -> void:
	play_one_shot(stream, BUS_SFX, volume_db)


func play_ui(stream: AudioStream, volume_db := 0.0) -> void:
	play_one_shot(stream, BUS_UI, volume_db)


## Plays a non-looping sound on any bus using the shared player pool. When all
## players are busy the oldest-started one is reused.
func play_one_shot(stream: AudioStream, bus: StringName, volume_db := 0.0) -> void:
	if stream == null:
		return
	var player := _take_one_shot_player()
	player.bus = bus
	player.stream = stream
	player.volume_db = volume_db
	player.play()


# --- Internals ---------------------------------------------------------------

func _take_one_shot_player() -> AudioStreamPlayer:
	for i in _one_shots.size():
		var index := (_next_one_shot + i) % _one_shots.size()
		if not _one_shots[index].playing:
			_next_one_shot = (index + 1) % _one_shots.size()
			return _one_shots[index]
	var player := _one_shots[_next_one_shot]
	_next_one_shot = (_next_one_shot + 1) % _one_shots.size()
	return player


func _create_player(player_name: String, bus: StringName) -> AudioStreamPlayer:
	var player := AudioStreamPlayer.new()
	player.name = player_name
	player.bus = bus
	add_child(player)
	return player


func _kill_music_tween() -> void:
	if _music_tween and _music_tween.is_valid():
		_music_tween.kill()
	_music_tween = null


# Looping is done here rather than on the stream resource so any stream format
# can be used as a loop without editing its import settings.
func _on_music_finished() -> void:
	if _music_loops:
		_music.play()


func _on_ambience_finished() -> void:
	if _ambience_loops:
		_ambience.play()
