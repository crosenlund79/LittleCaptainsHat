class_name BoatArea
extends Node2D
## One physical area of the boat (cabin or deck): places the player, routes
## interactions and reports what the UI should show.
##
## The area is presentation only. It reads the player's spawn or position
## from GameSession, writes the position back while active, and turns
## interactions into requests (signals) that the application flow handles.
## It never changes scenes or opens UI itself.

signal area_change_requested(area: StringName, spawn_point: StringName)
signal chart_requested
signal sleep_requested
signal helm_requested
signal message_requested(text: String)
## Prompt text for the focused interactable, or "" when nothing is in range.
signal interaction_prompt_changed(prompt: String)

@export var area_id: StringName
## Where the companionway in this area leads.
@export var companionway_target_area: StringName
@export var companionway_target_spawn: StringName
## Used when the requested spawn point does not exist in this area.
@export var default_spawn: StringName = &"start"
## Rectangle (in this node's coordinates) a restored player position must lie
## in; positions outside it fall back to the default spawn point.
@export var walkable_bounds := Rect2(-500, -200, 1000, 400)
@export var ambience: AudioStream
@export var interaction_sound: AudioStream
## Optional node shown only while the boat lies in a port (e.g. the pontoon),
## and a label inside it that names the port.
@export var mooring: Node2D
@export var mooring_label: Label

var _leaving := false

@onready var player: Player = $Player
@onready var _spawn_points: Node2D = $SpawnPoints


func _ready() -> void:
	_place_player()
	player.focus_changed.connect(_on_player_focus_changed)
	for node in find_children("*", "Interactable", true, false):
		(node as Interactable).interacted.connect(_on_interacted)
	AudioManager.play_ambience(ambience)
	_update_mooring()
	GameSession.voyage_started.connect(_update_mooring)
	GameSession.voyage_arrived.connect(_on_voyage_arrived)


func _physics_process(_delta: float) -> void:
	if not _leaving:
		GameSession.set_player_position(player.position)


## Stops gameplay in this area while a transition away from it runs.
func begin_exit() -> void:
	_leaving = true
	player.set_input_enabled(false)


func _place_player() -> void:
	var position := Vector2.ZERO
	if GameSession.has_player_position() and walkable_bounds.has_point(GameSession.get_player_position()):
		position = GameSession.get_player_position()
	else:
		var marker := _spawn_points.get_node_or_null(NodePath(String(GameSession.get_spawn_point()))) as Node2D
		if marker == null:
			marker = _spawn_points.get_node_or_null(NodePath(String(default_spawn))) as Node2D
		if marker:
			position = marker.position
	player.position = position
	GameSession.set_player_position(position)


func _on_interacted(interactable: Interactable, _actor: Node) -> void:
	if _leaving:
		return
	AudioManager.play_sfx(interaction_sound)
	match interactable.interaction_id:
		&"companionway":
			begin_exit()
			area_change_requested.emit(companionway_target_area, companionway_target_spawn)
		&"nav_table":
			begin_exit()
			chart_requested.emit()
		&"bed":
			sleep_requested.emit()
		&"helm":
			helm_requested.emit()
		_:
			if not interactable.message.is_empty():
				message_requested.emit(interactable.message)
			else:
				push_warning("Interactable '%s' has no behaviour." % interactable.interaction_id)


func _on_voyage_arrived(_port: StringName) -> void:
	_update_mooring()


## Shows the pontoon only in port; while underway the boat is at sea.
func _update_mooring() -> void:
	if mooring:
		mooring.visible = not GameSession.is_underway()
	if mooring_label and GameSession.get_location():
		mooring_label.text = "GUEST PONTOON · %s" % GameSession.get_location().display_name.to_upper()


func _on_player_focus_changed(interactable: Interactable) -> void:
	interaction_prompt_changed.emit(interactable.prompt if interactable else "")
