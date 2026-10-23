class_name InteractionSensor
extends Area2D
## Detects interactables within range of its owner and keeps exactly one of
## them focused. When several are in range the closest wins; exact ties are
## broken by node name so the choice is always predictable.

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


func _update_focus() -> void:
	var best: Interactable = null
	var best_distance := INF
	for area in get_overlapping_areas():
		var candidate := area as Interactable
		if candidate == null or not candidate.enabled:
			continue
		var distance := global_position.distance_squared_to(candidate.get_interaction_position())
		if best == null or distance < best_distance - 0.5 \
				or (absf(distance - best_distance) <= 0.5 and String(candidate.name) < String(best.name)):
			best = candidate
			best_distance = distance
	_set_focus(best)


func _set_focus(interactable: Interactable) -> void:
	if interactable == focused:
		return
	if is_instance_valid(focused):
		focused.set_focused(false)
	focused = interactable
	if focused:
		focused.set_focused(true)
	focus_changed.emit(focused)
