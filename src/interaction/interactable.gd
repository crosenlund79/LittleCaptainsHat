class_name Interactable
extends Area2D
## Something the player can interact with when standing close to it.
##
## Its collision shape defines the interaction range. Interactables do not
## implement behaviour themselves: they emit `interacted`, and the scene that
## owns them decides what happens. Interactables that only need to show a
## short text can set `message` instead of needing any code.

signal interacted(interactable: Interactable, actor: Node)

## Physics layer 3 ("interactables") is the only layer interactables occupy.
const COLLISION_LAYER := 1 << 2

## Stable id the owning scene uses to route the interaction.
@export var interaction_id: StringName
## Verb shown in the prompt, e.g. "Open chart".
@export var prompt := "Interact"
## Optional text shown as a notification when used.
@export_multiline var message := ""
@export var enabled := true
## Node tinted while this interactable has focus.
@export var highlight_target: NodePath = ^".."

const HIGHLIGHT := Color(1.25, 1.18, 1.0)

var _focused := false


func _ready() -> void:
	collision_layer = COLLISION_LAYER
	collision_mask = 0
	monitoring = false
	monitorable = true


func interact(actor: Node) -> void:
	if enabled:
		interacted.emit(self, actor)


func set_focused(focused: bool) -> void:
	if _focused == focused:
		return
	_focused = focused
	var target := get_node_or_null(highlight_target) as CanvasItem
	if target:
		target.modulate = HIGHLIGHT if focused else Color.WHITE


func is_focused() -> bool:
	return _focused


## Point used to rank interactables by distance from the player.
func get_interaction_position() -> Vector2:
	return global_position
