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
## The Go Ashore sign on the pontoon (Iteration 12) was used.
signal go_ashore_requested
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

## Underway the deck camera eases out a little (0.100b) so more of the sea
## around the boat shows; in harbour it is as framed in the scene. Cosmetic.
const UNDERWAY_ZOOM_FACTOR := 0.86
const ZOOM_TRANSITION_S := 1.8

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
## The deck camera's zoom as framed in the scene (the harbour view).
var _base_zoom := Vector2.ONE
var _base_camera_position := Vector2.ZERO
var _base_walkable_bounds := Rect2()
var _camera_ready := false
var _logged_course_view := false
var _zoom_tween: Tween
## Presentation only (tests): draw the deck as if sailing this heading.
var view_heading_override := NAN
## The course view's smallest zoom (keeps the deck readable at N/S headings)
## and the screen room kept free for the HUD (pixels, both sides together).
const COURSE_MIN_ZOOM := 0.78
const COURSE_SCREEN_MARGIN := Vector2(120.0, 300.0)
## Walking ashore over the gangplank (decks in harbour, Iteration 12).
var _shore: ShoreAccess
## Shore stations, by facility id (grocery, boatyard, go_ashore).
var _shore_stations := {}
## How fast the camera follows the player ashore and back (per second).
const SHORE_CAMERA_RATE := 3.5
## The boat this area belongs to (its art follows the Artwork setting).
var _vessel: VesselDefinition

@onready var player: Player = $Player
@onready var _spawn_points: Node2D = $Layout/SpawnPoints


func _ready() -> void:
	_vessel = GameSession.get_vessel_definition()
	apply_visual_profile(_vessel.get_active_visual_profile())
	SettingsManager.art_style_changed.connect(_on_art_style_changed)
	_setup_shore()
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
	_setup_harbour_dressing()
	_setup_water_life()
	_setup_camera()
	_setup_hat_hook()
	_update_hat_station()
	_resolve_highlights.call_deferred()
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


## The illustrated harbour (art only) on the deck's mooring, if it has one.
func _setup_harbour_dressing() -> void:
	if mooring == null:
		return
	var dressing := HarbourDressing.new()
	dressing.name = "HarbourDressing"
	mooring.add_child(dressing)
	# Right above the pontoon's base shape, under the harbour's name sign.
	var pontoon := mooring.get_node_or_null(^"Pontoon")
	if pontoon:
		mooring.move_child(dressing, pontoon.get_index() + 1)
	dressing.setup(self, mooring)


## The animated water (art only) on decks, over the water, under everything else.
func _setup_water_life() -> void:
	var surroundings := get_node_or_null(^"Surroundings")
	var water := surroundings.get_node_or_null(^"Water") if surroundings else null
	if water == null:
		return
	var life := WaterLife.new()
	life.name = "WaterLife"
	surroundings.add_child(life)
	surroundings.move_child(life, water.get_index() + 1)
	life.setup(self)


func get_water_life() -> WaterLife:
	return get_node_or_null(^"Surroundings/WaterLife") as WaterLife


# --- Camera -------------------------------------------------------------------------

## Decks (the areas with a mooring) frame wider underway. The camera stays
## fixed on the boat; only its zoom changes, eased, so nothing jitters.
func _setup_camera() -> void:
	var camera := get_node_or_null(^"Camera2D") as Camera2D
	if camera == null or mooring == null:
		return
	_base_zoom = camera.zoom
	_base_camera_position = camera.position
	_base_walkable_bounds = _shore.get_boat_bounds() if _shore else walkable_bounds
	_camera_ready = true
	camera.ignore_rotation = false
	camera.zoom = get_target_zoom()
	camera.rotation = get_target_rotation()
	camera.set_meta(&"course_view", is_course_view())
	if is_course_view():
		camera.position = _boat_view_bounds().get_center()
	# Water wide enough to fill a turned view.
	var water := get_node_or_null(^"Surroundings/Water") as Polygon2D
	if water:
		water.polygon = PackedVector2Array([Vector2(-2600, -2600), Vector2(2600, -2600), Vector2(2600, 2600), Vector2(-2600, 2600)])
	GameSession.voyage_course_changed.connect(_update_camera)
	SettingsManager.course_view_changed.connect(func(_enabled: bool) -> void: _update_camera())
	GameSession.voyage_started.connect(_update_camera)
	GameSession.voyage_arrived.connect(func(_port: StringName) -> void: _update_camera())
	GameSession.state_replaced.connect(_update_camera)
	GameSession.rescued.connect(func(_info: Dictionary) -> void: _update_camera())


## The zoom the deck camera settles on: wider while underway; in the course
## view also small enough for the turned boat to fit, but never below
## COURSE_MIN_ZOOM, so the deck stays readable when sailing north or south.
func get_target_zoom() -> Vector2:
	var zoom := _base_zoom * (UNDERWAY_ZOOM_FACTOR if GameSession.is_underway() else 1.0)
	if not is_course_view():
		return zoom
	var bounds := _boat_view_bounds()
	var turned := Rect2(bounds.position.rotated(-get_target_rotation()), Vector2.ZERO)
	for corner in [Vector2(bounds.end.x, bounds.position.y), bounds.end, Vector2(bounds.position.x, bounds.end.y)]:
		turned = turned.expand(corner.rotated(-get_target_rotation()))
	var room := get_viewport_rect().size - COURSE_SCREEN_MARGIN
	var fit := minf(room.x / turned.size.x, room.y / turned.size.y)
	return Vector2.ONE * clampf(minf(zoom.x, fit), minf(COURSE_MIN_ZOOM, zoom.x), zoom.x)


## The course view (Iteration 12): underway, with the setting on, the deck
## turns so the bow points along the course on screen, north up.
func is_course_view() -> bool:
	return _camera_ready and SettingsManager.get_course_view() and GameSession.is_underway()


## The camera rotation for the course view (0 otherwise): the bow (+x) drawn
## towards the heading, with north up.
func get_target_rotation() -> float:
	return deg_to_rad(90.0 - get_view_heading()) if is_course_view() else 0.0


## The heading the deck is drawn for: the course of the voyage leg (a test can
## set view_heading_override to see the deck on any heading; presentation
## only, the simulation never reads it).
func get_view_heading() -> float:
	return view_heading_override if not is_nan(view_heading_override) else Simulation.get_current_heading()


## The boat's own extent (the deck without the shore), with room ahead for
## the spinnaker while it flies.
func _boat_view_bounds() -> Rect2:
	var bounds := _base_walkable_bounds.grow(30.0)
	var rig := get_node_or_null(^"SailRig") as SailRig
	if rig and rig.spinnaker_amount > 0.5:
		bounds.end.x += 140.0
	return bounds


func _update_camera() -> void:
	var camera := get_node_or_null(^"Camera2D") as Camera2D
	if camera == null or not is_inside_tree():
		return
	var course := is_course_view()
	camera.set_meta(&"course_view", course)
	if course:
		camera.offset.x = 0.0
	var zoom := get_target_zoom()
	camera.rotation = wrapf(camera.rotation, -PI, PI)
	var rotation_target := camera.rotation + wrapf(get_target_rotation() - camera.rotation, -PI, PI)
	var center := _boat_view_bounds().get_center() if course else _base_camera_position
	if _zoom_tween:
		_zoom_tween.kill()
	if camera.zoom.is_equal_approx(zoom) and is_equal_approx(camera.rotation, rotation_target) and camera.position.is_equal_approx(center):
		return
	_zoom_tween = create_tween().set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT).set_parallel()
	_zoom_tween.tween_property(camera, "zoom", zoom, ZOOM_TRANSITION_S)
	_zoom_tween.tween_property(camera, "rotation", rotation_target, ZOOM_TRANSITION_S)
	_zoom_tween.tween_property(camera, "position", center, ZOOM_TRANSITION_S)
	_zoom_tween.chain().tween_callback(func() -> void: camera.rotation = wrapf(camera.rotation, -PI, PI))
	if course and not _logged_course_view:
		_logged_course_view = true
		SessionLog.write("course_view", {"heading": roundi(get_view_heading()), "zoom": snappedf(zoom.x, 0.01),
			"min_zoom_reached": zoom.x <= COURSE_MIN_ZOOM + 0.001})


func get_harbour_dressing() -> HarbourDressing:
	return mooring.get_node_or_null(^"HarbourDressing") as HarbourDressing if mooring else null


## The Artwork setting changed: show the other art (and harbour) at once.
func _on_art_style_changed(_style: StringName) -> void:
	var life := get_water_life()
	if life:
		life.refresh()
	var dressing := get_harbour_dressing()
	if dressing:
		dressing.refresh()
	apply_visual_profile(_vessel.get_active_visual_profile())
	show_condition()
	var provisions := get_node_or_null(^"ProvisionDisplay")
	if provisions and provisions.has_method(&"refresh"):
		provisions.refresh()


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
	var camera := get_node_or_null(^"Camera2D") as Camera2D
	if camera:
		player.view_rotation = camera.rotation


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
		&"go_ashore":
			go_ashore_requested.emit()
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
	var life := get_water_life()
	if life:
		life.refresh()
	var dressing := get_harbour_dressing()
	if dressing:
		dressing.refresh()


## Shows the pontoon only in port; while underway the boat is at sea. The
## helm offers to set sail in port and to check the sails underway.
func _update_mooring() -> void:
	for node in find_children("*", "Interactable", true, false):
		var interactable := node as Interactable
		if interactable.interaction_id == &"helm":
			interactable.prompt = HELM_PROMPT_UNDERWAY if GameSession.is_underway() else HELM_PROMPT_IN_PORT
		elif interactable.interaction_id in HarbourFacilities.ALL and _shore == null:
			# Without a shore (no pontoon in the scene) the services stay where
			# the scene put them, offered only where the harbour has them.
			_set_station_available(interactable, GameSession.has_facility(interactable.interaction_id))
	_update_shore()
	if player and player.get_focused_interactable():
		interaction_prompt_changed.emit(player.get_focused_interactable().prompt)
	if mooring:
		mooring.visible = not GameSession.is_underway()
	if mooring_label and GameSession.get_location():
		mooring_label.text = "GUEST PONTOON · %s" % GameSession.get_location().display_name.to_upper()


# --- Ashore (Iteration 12) ----------------------------------------------------------

## Decks with a pontoon get the gangplank and the shore strip. Runs before the
## player is placed, so a position saved ashore is restored.
func _setup_shore() -> void:
	if mooring == null or area_id != SessionState.AREA_EXTERIOR:
		return
	var shore := ShoreAccess.new()
	shore.name = "ShoreAccess"
	add_child(shore)
	var visual := get_node_or_null(^"Visual")
	if visual:
		move_child(shore, visual.get_index() + 1)
	if not shore.setup(self):
		shore.queue_free()
		return
	_shore = shore
	var stations := get_node(^"Layout/Stations")
	for child in stations.get_children():
		var station := child as Interactable
		if station and station.interaction_id in HarbourFacilities.ALL:
			_shore_stations[station.interaction_id] = station
	if not _shore_stations.has(HarbourFacilities.GO_ASHORE):
		var go := Interactable.new()
		go.name = "GoAshore"
		go.interaction_id = HarbourFacilities.GO_ASHORE
		go.prompt = "Go ashore"
		go.highlight_target = ^""
		var shape := CollisionShape2D.new()
		shape.name = "CollisionShape2D"
		shape.shape = RectangleShape2D.new()
		go.add_child(shape)
		stations.add_child(go)
		_shore_stations[HarbourFacilities.GO_ASHORE] = go
	# A classic sign label for Go Ashore, like the scenes' grocery and boatyard ones.
	var yard_label := mooring.get_node_or_null(^"BoatyardSign") as Label
	if yard_label and mooring.get_node_or_null(^"GoAshoreSign") == null:
		var go_label := yard_label.duplicate() as Label
		go_label.name = "GoAshoreSign"
		go_label.text = "GO ASHORE"
		mooring.add_child(go_label)
	# The harbour's name is painted on the front of the pontoon, beside the
	# gangplank, out of the way of the signs at the back.
	if mooring_label:
		var pontoon := shore.get_pontoon_rect()
		mooring_label.position = Vector2(shore.get_plank_x() + ShoreAccess.SLOT_OFFSETS[0], pontoon.position.y + 24.0) \
			- mooring_label.size / 2.0
	_update_shore()


## In harbour: the gangplank is out and the services the harbour offers stand
## on the pontoon; otherwise the rail is closed and the services are gone.
func _update_shore() -> void:
	if _shore == null:
		return
	var in_port := GameSession.is_moored_in_harbour()
	var was_ashore := _shore.is_off_the_boat(player.position) if player else false
	_shore.set_active(in_port)
	var camera := get_node_or_null(^"Camera2D") as Camera2D
	if camera and not in_port:
		camera.offset.y = 0.0
	if was_ashore and not in_port:
		# Never leave the player on a pontoon that is no longer there.
		place_player_at_spawn(&"from_boatyard")
	var available := GameSession.get_harbour_facilities().get_ids() if in_port else ([] as Array[StringName])
	var slots := _shore.get_service_slots(available.size())
	var index := 0
	for id: StringName in HarbourFacilities.ALL:
		var station := _shore_stations.get(id) as Interactable
		if station == null:
			continue
		var offered := id in available and index < slots.size()
		if offered:
			var slot: Dictionary = slots[index]
			index += 1
			station.position = slot.station
			station.set_meta(&"sign_at", slot.sign)
			var shape := station.get_node(^"CollisionShape2D") as CollisionShape2D
			if not shape.has_meta(&"own_shape"):
				shape.shape = shape.shape.duplicate()
				shape.set_meta(&"own_shape", true)
			(shape.shape as RectangleShape2D).size = Vector2(180, 64)
			shape.position = Vector2.ZERO
		_set_station_available(station, offered)
		var label := mooring.get_node_or_null(NodePath(String(SIGN_LABELS[id]))) as Label
		if label:
			label.visible = offered
			if offered:
				label.position = Vector2(station.get_meta(&"sign_at")) - label.size / 2.0
	var dressing := get_harbour_dressing()
	if dressing:
		dressing.refresh()
	if is_inside_tree():
		_resolve_highlights.call_deferred()


func _set_station_available(station: Interactable, available: bool) -> void:
	station.enabled = available
	station.visible = available
	station.monitorable = available
	if not available:
		station.set_focused(false)


func get_shore_access() -> ShoreAccess:
	return _shore


## The shore station for a facility (tests), or null.
func get_shore_station(facility: StringName) -> Interactable:
	return _shore_stations.get(facility) as Interactable


func _process(delta: float) -> void:
	if _shore == null or not _shore.is_active() or _leaving:
		return
	_shore.update_player(player.position)
	var camera := get_node_or_null(^"Camera2D") as Camera2D
	if camera == null:
		return
	camera.offset.y = lerpf(camera.offset.y, get_shore_camera_target(), 1.0 - exp(-SHORE_CAMERA_RATE * delta))


## Walking ashore, the view glides down so the pontoon and its signs show
## (0 aboard, or when the pontoon is already in view).
func get_shore_camera_target() -> float:
	var camera := get_node_or_null(^"Camera2D") as Camera2D
	if camera == null or _shore == null or not _shore.is_off_the_boat(player.position):
		return 0.0
	var half_height := get_viewport_rect().size.y / 2.0
	var visible_bottom := camera.position.y + (half_height - SHORE_HUD_MARGIN) / camera.zoom.y
	return maxf(_shore.get_pontoon_rect().end.y + 24.0 - visible_bottom, 0.0)


## The mooring's sign label for each shore facility (classic art and text).
const SIGN_LABELS := {&"grocery": "GrocerySign", &"boatyard": "BoatyardSign", &"go_ashore": "GoAshoreSign"}
## Screen pixels at the bottom taken by the HUD's prompt and shortcuts.
const SHORE_HUD_MARGIN := 150.0


# --- Captain's hat ------------------------------------------------------------------

## Gives every station the outline of the object it belongs to (Iteration 12;
## see HighlightResolver). Deferred, so harbour and shore art exist first.
func _resolve_highlights() -> void:
	if not is_inside_tree():
		return
	for node in find_children("*", "Interactable", true, false):
		var station := node as Interactable
		if station.highlight_target.is_empty():
			station.set_highlight_outline_global(HighlightResolver.resolve(self, station))


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
	# Its outline follows the hook (the hat, or the empty plate); deferred so
	# the hook has seen the change first.
	_resolve_highlights.call_deferred()


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
	var heading := get_view_heading() if GameSession.is_underway() else 0.0
	return Vector2.from_angle(deg_to_rad(wind.from_deg + 180.0 - heading))


func _on_player_focus_changed(interactable: Interactable) -> void:
	interaction_prompt_changed.emit(interactable.prompt if interactable else "")
