class_name BoatArea
extends Node2D
## One physical area of the boat (cabin or deck): places the player, routes
## interactions and reports what the UI should show.
##
## The area is presentation only. It reads the player's spawn or position
## from GameSession, writes the position back while active, and turns
## interactions into requests (signals) that the application flow handles.
## It never changes scenes or opens UI itself.
##
## Scene structure (every vessel, deck and cabin alike):
##   Visual   - the art (VesselVisual: procedural slots or sprites), no physics
##   Layout   - gameplay: Collision, Stations (interactables), SpawnPoints,
##              CompanionSpots (cabin) and SailMarkers (deck)
##   SailRig  - the dynamic sails (deck), Companion (cabin), Player, Camera2D
## On entering, the active vessel's visual profile is applied to Visual and
## the SailRig, so replacing art never touches the layout.

signal area_change_requested(area: StringName, spawn_point: StringName)
signal chart_requested
signal sleep_requested
signal helm_requested
signal boatyard_requested
## The provisions station (cabin) was used.
signal provisions_requested
## The work station (cabin) was used.
signal work_requested
## The grocery store on the pontoon (deck, in harbour) was used.
signal grocery_requested
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

const HELM_PROMPT_IN_PORT := "Take the helm"
const HELM_PROMPT_UNDERWAY := "Check sail configuration"
## The cabin's hat hook (station id `hat`), by hat state.
const HAT_PROMPTS := {
	HatState.STORED: "Put on captain's hat",
	HatState.WORN: "Hang up captain's hat",
	HatState.CARRIED: "Hang up captain's hat",
	HatState.LOST: "Look at the empty hat hook",
}

var _leaving := false

@onready var player: Player = $Player
@onready var _spawn_points: Node2D = $Layout/SpawnPoints


func _ready() -> void:
	apply_visual_profile(GameSession.get_vessel_definition().visual_profile)
	_place_player()
	player.focus_changed.connect(_on_player_focus_changed)
	for node in find_children("*", "Interactable", true, false):
		(node as Interactable).interacted.connect(_on_interacted)
	AudioManager.play_ambience(ambience)
	show_condition()
	GameSession.condition_changed.connect(func(_percent: float) -> void: show_condition())
	_update_mooring()
	GameSession.voyage_started.connect(_update_mooring)
	GameSession.voyage_arrived.connect(_on_voyage_arrived)
	_setup_hat_hook()
	_update_hat_station()
	GameSession.hat_changed.connect(func(_status: StringName) -> void: _update_hat_station())
	GameSession.state_replaced.connect(_update_hat_station)
	GameSession.hat_lost.connect(_on_hat_lost)


## Shows the vessel's art: sprites where the profile has them, procedural
## placeholder art elsewhere.
func apply_visual_profile(profile: VesselVisualProfile) -> void:
	var visual := get_node_or_null("Visual") as VesselVisual
	if visual:
		visual.apply(profile)
	var rig := get_node_or_null("SailRig") as SailRig
	if rig:
		rig.apply_profile(profile)


## Shows the boat's wear and damage over its art (VesselVisual.set_condition).
func show_condition() -> void:
	var visual := get_node_or_null("Visual") as VesselVisual
	if visual:
		visual.set_condition(GameSession.get_condition(), "%s/%s" % [GameSession.get_vessel_id(), area_id])


## A spawn point's position, or Vector2.INF when it does not exist.
func get_spawn_position(spawn_point: StringName) -> Vector2:
	var marker := _spawn_points.get_node_or_null(NodePath(String(spawn_point))) as Node2D
	return marker.position if marker else Vector2.INF


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


## Moves the player to a spawn marker without reloading the scene (waking up
## in the cabin when already there).
func place_player_at_spawn(spawn_point: StringName) -> void:
	var marker := _spawn_points.get_node_or_null(NodePath(String(spawn_point))) as Node2D
	if marker == null:
		return
	player.position = marker.position
	player.velocity = Vector2.ZERO
	GameSession.set_player_position(marker.position)


func _on_interacted(interactable: Interactable, _actor: Node) -> void:
	if _leaving:
		return
	if interactable.interaction_id != &"pet":  # the companion makes its own sound
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
		&"boatyard":
			boatyard_requested.emit()
		&"provisions":
			provisions_requested.emit()
		&"work":
			work_requested.emit()
		&"grocery":
			grocery_requested.emit()
		&"hat":
			message_requested.emit(GameSession.use_hat_hook())
		&"pet":
			var companion := interactable.get_parent() as ShipCompanion
			if companion:
				companion.pet()
		_:
			if not interactable.message.is_empty():
				message_requested.emit(interactable.message)
			else:
				push_warning("Interactable '%s' has no behaviour." % interactable.interaction_id)


func _on_voyage_arrived(_port: StringName) -> void:
	_update_mooring()


## Shows the pontoon only in port; while underway the boat is at sea. The
## helm offers to set sail in port and to check the sails underway.
func _update_mooring() -> void:
	for node in find_children("*", "Interactable", true, false):
		var interactable := node as Interactable
		if interactable.interaction_id == &"helm":
			interactable.prompt = HELM_PROMPT_UNDERWAY if GameSession.is_underway() else HELM_PROMPT_IN_PORT
		elif interactable.interaction_id in [&"boatyard", &"grocery"]:
			# The boatyard and the grocery store are only reachable in harbour.
			interactable.enabled = GameSession.can_change_vessel()
			interactable.visible = interactable.enabled
			interactable.monitorable = interactable.enabled
	if player and player.get_focused_interactable():
		interaction_prompt_changed.emit(player.get_focused_interactable().prompt)
	if mooring:
		mooring.visible = not GameSession.is_underway()
	if mooring_label and GameSession.get_location():
		mooring_label.text = "GUEST PONTOON · %s" % GameSession.get_location().display_name.to_upper()


# --- Captain's hat ------------------------------------------------------------------

## The cabin's hat hook (art) at Layout/HatSpot, drawn under the player.
func _setup_hat_hook() -> void:
	var spot := get_node_or_null(^"Layout/HatSpot") as Node2D
	if spot == null:
		return
	var hook := HatHook.new()
	hook.name = "HatHook"
	hook.position = spot.position
	add_child(hook)
	move_child(hook, $Layout.get_index())


func get_hat_hook() -> HatHook:
	return get_node_or_null(^"HatHook") as HatHook


## The hat station's prompt follows the hat (put on, hang up, empty hook).
func _update_hat_station() -> void:
	var station := get_node_or_null(^"Layout/Stations/Hat") as Interactable
	if station == null:
		return
	station.prompt = HAT_PROMPTS.get(GameSession.get_hat_status(), "Captain's hat")
	if player and player.get_focused_interactable() == station:
		interaction_prompt_changed.emit(station.prompt)


## The hat blew away: on deck it is seen tumbling downwind.
func _on_hat_lost(_info: Dictionary) -> void:
	if area_id != SessionState.AREA_EXTERIOR or _leaving:
		return
	var effect := HatBlowAway.new()
	effect.name = "HatBlowAway"
	add_child(effect)
	effect.setup(player.position, wind_direction_on_deck())


## Where the wind blows towards in this deck's coordinates (+x is the bow,
## +y starboard), from the WeatherModel at the boat and the course heading
## (north while moored).
func wind_direction_on_deck() -> Vector2:
	var wind := Simulation.get_weather_at_vessel()
	var heading := Simulation.get_current_heading() if GameSession.is_underway() else 0.0
	return Vector2.from_angle(deg_to_rad(wind.from_deg + 180.0 - heading))


func _on_player_focus_changed(interactable: Interactable) -> void:
	interaction_prompt_changed.emit(interactable.prompt if interactable else "")
