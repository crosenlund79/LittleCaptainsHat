class_name InteractionSensor
extends Area2D
## Detects interactables within range of its owner and keeps exactly one of
## them focused, and interacting always uses that same one, so the prompt
## shown is the action E performs.
##
## Choosing among several in range (choose()): the nearest wins, measured
## from the player to each interactable's centre, but every step of
## focus_priority below another's counts as PRIORITY_MARGIN more distance.
## Stations, doors and the berth all have priority 0, so among them the
## nearest wins as always; the ship's companion has -1, so it never takes the
## focus from a station the player is at unless the player stands clearly
## closer to the animal (walking round to its far side pets it). Exact ties
## are broken by node name, so the choice is always predictable.

signal focus_changed(interactable: Interactable)

var focused: Interactable


func _ready() -> void:
	collision_layer = 0
	collision_mask = Interactable.COLLISION_LAYER
	monitoring = true
	monitorable = false


func _physics_process(_delta: float) -> void:
	_update_focus()


## Interacts with the focused interactable. Returns true if there was one.
func interact(actor: Node) -> bool:
	_update_focus()
	if focused == null:
		return false
	focused.interact(actor)
	return true


func clear_focus() -> void:
	_set_focus(null)


## Extra distance (px) a lower-priority interactable must make up to win.
const PRIORITY_MARGIN := 60.0


func _update_focus() -> void:
	var candidates: Array[Interactable] = []
	for area in get_overlapping_areas():
		var candidate := area as Interactable
		if candidate != null and candidate.enabled:
			candidates.append(candidate)
	_set_focus(choose(candidates, global_position))


## The interactable a player at `from` (global) would use (see above).
static func choose(candidates: Array[Interactable], from: Vector2) -> Interactable:
	var best: Interactable = null
	var best_score := INF
	for candidate in candidates:
		var score := from.distance_to(candidate.get_interaction_position()) - candidate.focus_priority * PRIORITY_MARGIN
		if best == null or score < best_score - 0.5 \
				or (absf(score - best_score) <= 0.5 and String(candidate.name) < String(best.name)):
			best = candidate
			best_score = score
	return best


func _set_focus(interactable: Interactable) -> void:
	if interactable == focused:
		return
	if is_instance_valid(focused):
		focused.set_focused(false)
	focused = interactable
	if focused:
		focused.set_focused(true)
	focus_changed.emit(focused)
