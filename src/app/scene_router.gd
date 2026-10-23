class_name SceneRouter
extends Node
## Swaps the single active screen (main menu, a boat area, the world map)
## inside a host node, with a short fade. Only one screen exists at a time,
## so repeated transitions can never duplicate the player or other content.

signal screen_changed(screen: Node)

@export var host: Node
@export var fade_duration := 0.22

var current_screen: Node
var _busy := false

@onready var _fade: ColorRect = $FadeLayer/Fade


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_fade.color.a = 0.0
	_fade.mouse_filter = Control.MOUSE_FILTER_IGNORE


func is_busy() -> bool:
	return _busy


## Replaces the current screen with a new instance of `scene`. `setup` is
## called with the new instance before it enters the tree, so signal
## connections are in place before its _ready() runs.
func change_screen(scene: PackedScene, setup := Callable()) -> void:
	if _busy:
		push_warning("Screen change ignored: a transition is already running.")
		return
	_busy = true
	# Let the outgoing screen stop gameplay (e.g. player input) during the fade.
	if is_instance_valid(current_screen) and current_screen.has_method(&"begin_exit"):
		current_screen.begin_exit()
	_fade.mouse_filter = Control.MOUSE_FILTER_STOP
	await _fade_to(1.0)
	if is_instance_valid(current_screen):
		host.remove_child(current_screen)
		current_screen.queue_free()
	current_screen = scene.instantiate()
	if setup.is_valid():
		setup.call(current_screen)
	host.add_child(current_screen)
	screen_changed.emit(current_screen)
	await _fade_to(0.0)
	_fade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_busy = false


func _fade_to(alpha: float) -> void:
	if fade_duration <= 0.0:
		_fade.color.a = alpha
		await get_tree().process_frame
		return
	var tween := create_tween()
	tween.set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	tween.tween_property(_fade, "color:a", alpha, fade_duration)
	await tween.finished
